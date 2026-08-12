$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run-production-monitor.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "p2p-chat-monitor-$([Guid]::NewGuid().ToString('N'))"
$fakeMonitor = Join-Path $testRoot 'fake-monitor.ps1'
$envFile = Join-Path $testRoot 'production.env'
$stateFile = Join-Path $testRoot 'monitor-state.json'
$previousTestStatus = $env:P2P_TEST_MONITOR_STATUS
$testJobs = [Collections.Generic.List[object]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Set-TestEnvironment {
    param([string]$WebhookUrl, [string]$BearerToken = '')

    @(
        'PUBLIC_HOST=localhost'
        'WEBSOCKET_ALLOWED_ORIGINS=https://localhost'
        "PRODUCTION_ALERT_WEBHOOK_URL=$WebhookUrl"
        "PRODUCTION_ALERT_BEARER_TOKEN=$BearerToken"
    ) | Set-Content -LiteralPath $envFile -Encoding utf8NoBOM
}

function Invoke-TestRunner {
    param([switch]$ProductionMode)

    $arguments = @{
        EnvFile = $envFile
        MonitorScript = $fakeMonitor
        StateFile = $stateFile
        TimeoutSeconds = 5
    }
    if (-not $ProductionMode) { $arguments['AllowLocalVerification'] = $true }
    $output = & $runner @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { [string]$_ }) -join "`n"
    [pscustomobject]@{
        exitCode = $exitCode
        result = $text | ConvertFrom-Json -Depth 10
    }
}

function Start-TestWebhook {
    param([int]$StatusCode = 204)

    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $probe.Start()
    $port = ([Net.IPEndPoint]$probe.LocalEndpoint).Port
    $probe.Stop()
    $readyPath = Join-Path $testRoot "webhook-$port.ready"
    $resultPath = Join-Path $testRoot "webhook-$port.json"
    $job = Start-Job -ArgumentList $port, $StatusCode, $readyPath, $resultPath -ScriptBlock {
        param($Port, $Status, $ReadyPath, $ResultPath)

        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
        try {
            $listener.Start()
            Set-Content -LiteralPath $ReadyPath -Value 'ready' -Encoding utf8NoBOM
            $client = $listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $false, 1024, $true)
                $contentLength = 0
                $authorization = ''
                while ($true) {
                    $line = $reader.ReadLine()
                    if ([string]::IsNullOrEmpty($line)) { break }
                    if ($line -match '^(?i)Content-Length:\s*([0-9]+)$') { $contentLength = [int]$Matches[1] }
                    if ($line -match '^(?i)Authorization:\s*(.+)$') { $authorization = $Matches[1] }
                }
                $buffer = [char[]]::new($contentLength)
                $read = 0
                while ($read -lt $contentLength) {
                    $count = $reader.Read($buffer, $read, $contentLength - $read)
                    if ($count -le 0) { break }
                    $read += $count
                }
                [ordered]@{
                    body = [string]::new($buffer, 0, $read)
                    authorization = $authorization
                } | ConvertTo-Json -Compress | Set-Content -LiteralPath $ResultPath -Encoding utf8NoBOM
                $reason = if ($Status -ge 200 -and $Status -lt 300) { 'No Content' } else { 'Server Error' }
                $responseText = "HTTP/1.1 $Status $reason`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                $responseBytes = [Text.Encoding]::ASCII.GetBytes($responseText)
                $stream.Write($responseBytes, 0, $responseBytes.Length)
                $stream.Flush()
                $reader.Dispose()
            } finally {
                $client.Dispose()
            }
        } finally {
            $listener.Stop()
        }
    }
    $testJobs.Add($job)

    $deadline = (Get-Date).AddSeconds(10)
    while (-not (Test-Path -LiteralPath $readyPath) -and (Get-Date) -lt $deadline) {
        if ($job.State -eq 'Failed') { Receive-Job -Job $job; throw 'Test webhook failed to start.' }
        Start-Sleep -Milliseconds 50
    }
    if (-not (Test-Path -LiteralPath $readyPath)) { throw 'Test webhook did not become ready.' }
    [pscustomobject]@{
        job = $job
        uri = "http://127.0.0.1:$port/alert"
        resultPath = $resultPath
    }
}

function Complete-TestWebhook {
    param([Parameter(Mandatory = $true)]$Receiver)

    try {
        $completed = Wait-Job -Job $Receiver.job -Timeout 10
        if ($null -eq $completed -or $Receiver.job.State -ne 'Completed') {
            throw 'Test webhook did not receive a request.'
        }
        Receive-Job -Job $Receiver.job | Out-Null
        return Get-Content -Raw -LiteralPath $Receiver.resultPath | ConvertFrom-Json
    } finally {
        Stop-Job -Job $Receiver.job -ErrorAction SilentlyContinue
        Remove-Job -Job $Receiver.job -Force -ErrorAction SilentlyContinue
        [void]$testJobs.Remove($Receiver.job)
    }
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    @'
[CmdletBinding()]
param(
    [string]$EnvFile,
    [int]$TimeoutSeconds,
    [switch]$AllowLocalVerification
)

$status = $env:P2P_TEST_MONITOR_STATUS
if ($status -eq 'PASS') {
    [pscustomobject]@{
        status = 'PASS'
        checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
        endpoint = 'https://localhost:18443'
        checks = [ordered]@{ readiness = $true; websocketUpgrade = $true }
    } | ConvertTo-Json -Depth 5
    exit 0
}
[pscustomobject]@{
    status = 'FAIL'
    checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
    endpoint = 'https://localhost:18443'
    failedCheck = 'readiness'
    error = 'fixture detail must not enter the alert payload'
    checks = [ordered]@{ readiness = $false; websocketUpgrade = $false }
} | ConvertTo-Json -Depth 5
exit 1
'@ | Set-Content -LiteralPath $fakeMonitor -Encoding utf8NoBOM

    Set-TestEnvironment -WebhookUrl ''
    $env:P2P_TEST_MONITOR_STATUS = 'PASS'
    $initial = Invoke-TestRunner
    Assert-True ($initial.exitCode -eq 0) 'Initial PASS returned a nonzero exit code.'
    Assert-True ($initial.result.transition -eq 'NONE') 'Initial PASS emitted an alert transition.'
    Assert-True (-not $initial.result.alertAttempted) 'Initial PASS attempted an alert.'

    $lockPath = "$stateFile.lock"
    $heldLock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $overlap = Invoke-TestRunner
        Assert-True ($overlap.exitCode -eq 1) 'Overlapping monitor run returned a zero exit code.'
        Assert-True ($overlap.result.status -eq 'ERROR') 'Overlapping monitor run was not rejected.'
        Assert-True ($overlap.result.error -match 'already active') 'Overlapping monitor error is incorrect.'
        Assert-True (Test-Path -LiteralPath $lockPath) 'Rejected monitor run removed another process lock.'
    } finally {
        $heldLock.Dispose()
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }

    $failureReceiver = Start-TestWebhook
    Set-TestEnvironment -WebhookUrl $failureReceiver.uri -BearerToken 'fixture-bearer-token'
    $env:P2P_TEST_MONITOR_STATUS = 'FAIL'
    $failure = Invoke-TestRunner
    Assert-True ($failure.exitCode -eq 1) 'Monitor failure did not propagate a nonzero exit code.'
    Assert-True ($failure.result.transition -eq 'PRODUCTION_HEALTH_FAILED') 'Failure transition is incorrect.'
    Assert-True ($failure.result.alertSent) 'Failure alert was not sent.'
    $failureRequest = Complete-TestWebhook -Receiver $failureReceiver
    $failurePayload = $failureRequest.body | ConvertFrom-Json
    Assert-True ($failurePayload.eventType -eq 'PRODUCTION_HEALTH_FAILED') 'Failure webhook event is incorrect.'
    Assert-True ($failurePayload.failedCheck -eq 'readiness') 'Failure webhook check is incorrect.'
    Assert-True ($failureRequest.authorization -eq 'Bearer fixture-bearer-token') 'Bearer token was not sent as a header.'
    Assert-True ($failureRequest.body -notmatch 'fixture-bearer-token|fixture detail') 'Failure payload leaked sensitive or verbose details.'

    Set-TestEnvironment -WebhookUrl 'http://127.0.0.1:1/unreachable'
    $repeatedFailure = Invoke-TestRunner
    Assert-True ($repeatedFailure.exitCode -eq 1) 'Repeated failure did not preserve monitor exit code.'
    Assert-True ($repeatedFailure.result.transition -eq 'NONE') 'Repeated failure emitted a duplicate transition.'
    Assert-True (-not $repeatedFailure.result.alertAttempted) 'Repeated failure attempted a duplicate alert.'

    $recoveryReceiver = Start-TestWebhook
    Set-TestEnvironment -WebhookUrl $recoveryReceiver.uri
    $env:P2P_TEST_MONITOR_STATUS = 'PASS'
    $recovery = Invoke-TestRunner
    Assert-True ($recovery.exitCode -eq 0) 'Recovery returned a nonzero exit code.'
    Assert-True ($recovery.result.transition -eq 'PRODUCTION_HEALTH_RECOVERED') 'Recovery transition is incorrect.'
    Assert-True ($recovery.result.alertSent) 'Recovery alert was not sent.'
    $recoveryRequest = Complete-TestWebhook -Receiver $recoveryReceiver
    $recoveryPayload = $recoveryRequest.body | ConvertFrom-Json
    Assert-True ($recoveryPayload.eventType -eq 'PRODUCTION_HEALTH_RECOVERED') 'Recovery webhook event is incorrect.'
    Assert-True ($null -eq $recoveryPayload.failedCheck) 'Recovery payload retained a failed check.'

    Set-TestEnvironment -WebhookUrl 'http://127.0.0.1:1/insecure'
    $env:P2P_TEST_MONITOR_STATUS = 'FAIL'
    $insecure = Invoke-TestRunner -ProductionMode
    Assert-True ($insecure.exitCode -eq 1) 'Production HTTP webhook returned a zero exit code.'
    Assert-True ($insecure.result.status -eq 'ERROR') 'Production HTTP webhook was not rejected.'
    Assert-True ($insecure.result.error -match 'must use HTTPS') 'Production HTTP webhook error is incorrect.'
    $stateAfterInsecure = Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json
    Assert-True ($stateAfterInsecure.status -eq 'PASS') 'Rejected insecure webhook advanced monitor state.'

    Set-TestEnvironment -WebhookUrl 'https://alerts.example.com/hooks/p2p-chat'
    $placeholder = Invoke-TestRunner -ProductionMode
    Assert-True ($placeholder.exitCode -eq 1) 'Placeholder webhook returned a zero exit code.'
    Assert-True ($placeholder.result.error -match 'still a placeholder') 'Placeholder webhook was not rejected.'

    $rejectedReceiver = Start-TestWebhook -StatusCode 500
    Set-TestEnvironment -WebhookUrl $rejectedReceiver.uri
    $env:P2P_TEST_MONITOR_STATUS = 'FAIL'
    $rejected = Invoke-TestRunner
    Assert-True ($rejected.exitCode -eq 1) 'Rejected alert returned a zero exit code.'
    Assert-True ($rejected.result.status -eq 'ERROR') 'Rejected alert did not fail the scheduled runner.'
    Assert-True (-not $rejected.result.stateUpdated) 'Rejected alert advanced monitor state.'
    Complete-TestWebhook -Receiver $rejectedReceiver | Out-Null
    $stateAfterRejection = Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json
    Assert-True ($stateAfterRejection.status -eq 'PASS') 'Rejected alert changed the persisted state.'

    $retryReceiver = Start-TestWebhook
    Set-TestEnvironment -WebhookUrl $retryReceiver.uri
    $retry = Invoke-TestRunner
    Assert-True ($retry.exitCode -eq 1) 'Retried failure did not preserve monitor exit code.'
    Assert-True ($retry.result.transition -eq 'PRODUCTION_HEALTH_FAILED') 'Rejected alert was not retried.'
    Assert-True ($retry.result.alertSent) 'Retried failure alert was not sent.'
    Complete-TestWebhook -Receiver $retryReceiver | Out-Null

    [pscustomobject]@{
        status = 'PASS'
        failureAlertSent = $true
        overlapRejected = $true
        duplicateSuppressed = $true
        recoveryAlertSent = $true
        insecureWebhookRejected = $true
        placeholderRejected = $true
        rejectedDeliveryRetried = $true
        payloadRedacted = $true
    } | ConvertTo-Json -Depth 5
} finally {
    $env:P2P_TEST_MONITOR_STATUS = $previousTestStatus
    @($testJobs) | ForEach-Object {
        Stop-Job -Job $_ -ErrorAction SilentlyContinue
        Remove-Job -Job $_ -Force -ErrorAction SilentlyContinue
    }
    $fullTestRoot = [IO.Path]::GetFullPath($testRoot)
    $fullTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($fullTestRoot.StartsWith($fullTemp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($fullTestRoot) -match '^p2p-chat-monitor-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $fullTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit 0
