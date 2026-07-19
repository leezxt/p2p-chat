[CmdletBinding()]
param(
    [string]$EnvFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'production.env'),

    [string]$MonitorScript = (Join-Path $PSScriptRoot 'monitor-production.ps1'),

    [string]$StateFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'target\production-monitor-state.json'),

    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 10,

    [switch]$AllowLocalVerification
)

$ErrorActionPreference = 'Stop'
$alertAttempted = $false
$alertSent = $false
$stateUpdated = $false
$transition = 'NONE'
$monitorStatus = $null
$monitorExitCode = 1
$failedCheck = $null
$lockStream = $null
$lockPath = $null
$lockAcquired = $false
$finalExitCode = 1

function Read-EnvironmentFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([A-Z][A-Z0-9_]*)=(.*)$') {
            throw 'Invalid production environment line. Expected NAME=value.'
        }
        if ($values.ContainsKey($Matches[1])) { throw "Duplicate production environment key: $($Matches[1])" }
        $values[$Matches[1]] = $Matches[2]
    }
    return $values
}

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)][IO.FileSystemInfo]$Item)
    return ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Send-AlertWebhook {
    param(
        [Parameter(Mandatory = $true)][Uri]$Uri,
        [Parameter(Mandatory = $true)][string]$JsonBody,
        [string]$BearerToken,
        [int]$Timeout
    )

    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, $Uri)
    try {
        $client.Timeout = [TimeSpan]::FromSeconds($Timeout)
        if (-not [string]::IsNullOrWhiteSpace($BearerToken)) {
            $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $BearerToken)
        }
        $request.Content = [Net.Http.StringContent]::new($JsonBody, [Text.Encoding]::UTF8, 'application/json')
        try {
            $response = $client.Send($request)
        } catch {
            throw 'Alert webhook delivery failed.'
        }
        try {
            if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
                throw "Alert webhook rejected the event with HTTP $([int]$response.StatusCode)."
            }
        } finally {
            $response.Dispose()
        }
    } finally {
        $request.Dispose()
        $client.Dispose()
        $handler.Dispose()
    }
}

try {
    $resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile -ErrorAction Stop).Path
    $resolvedMonitorScript = (Resolve-Path -LiteralPath $MonitorScript -ErrorAction Stop).Path
    $values = Read-EnvironmentFile -Path $resolvedEnvFile

    $resolvedStateFile = [IO.Path]::GetFullPath($StateFile)
    $stateDirectory = [IO.Path]::GetDirectoryName($resolvedStateFile)
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    $stateDirectoryItem = Get-Item -LiteralPath $stateDirectory
    if (-not $stateDirectoryItem.PSIsContainer -or (Test-ReparsePoint -Item $stateDirectoryItem)) {
        throw 'Monitor state directory must be a regular directory.'
    }

    $lockPath = "$resolvedStateFile.lock"
    try {
        $lockStream = [IO.File]::Open(
            $lockPath,
            [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None
        )
        $lockAcquired = $true
    } catch {
        throw 'Another production monitor run is already active.'
    }

    $monitorArguments = @{
        EnvFile = $resolvedEnvFile
        TimeoutSeconds = $TimeoutSeconds
    }
    if ($AllowLocalVerification) { $monitorArguments['AllowLocalVerification'] = $true }
    $monitorOutput = & $resolvedMonitorScript @monitorArguments 2>&1
    $monitorExitCode = $LASTEXITCODE
    $monitorText = ($monitorOutput | ForEach-Object { [string]$_ }) -join "`n"
    try {
        $monitorResult = $monitorText | ConvertFrom-Json -Depth 10
    } catch {
        throw 'Production monitor returned invalid JSON.'
    }

    $monitorStatus = [string]$monitorResult.status
    $failedCheck = [string]$monitorResult.failedCheck
    if ($monitorStatus -notin @('PASS', 'FAIL')) { throw 'Production monitor returned an unsupported status.' }
    if (($monitorStatus -eq 'PASS' -and $monitorExitCode -ne 0) -or
        ($monitorStatus -eq 'FAIL' -and $monitorExitCode -eq 0)) {
        throw 'Production monitor status and exit code disagree.'
    }

    $previousStatus = $null
    if (Test-Path -LiteralPath $resolvedStateFile) {
        $stateFileItem = Get-Item -LiteralPath $resolvedStateFile
        if ($stateFileItem.PSIsContainer -or (Test-ReparsePoint -Item $stateFileItem)) {
            throw 'Production monitor state is not a regular file.'
        }
        try {
            $previousState = Get-Content -Raw -LiteralPath $resolvedStateFile | ConvertFrom-Json -Depth 10
        } catch {
            throw 'Production monitor state is invalid JSON.'
        }
        if ([int]$previousState.schemaVersion -ne 1 -or [string]$previousState.status -notin @('PASS', 'FAIL')) {
            throw 'Production monitor state has an unsupported schema or status.'
        }
        $previousStatus = [string]$previousState.status
    }

    if ($monitorStatus -eq 'FAIL' -and $previousStatus -ne 'FAIL') {
        $transition = 'PRODUCTION_HEALTH_FAILED'
    } elseif ($monitorStatus -eq 'PASS' -and $previousStatus -eq 'FAIL') {
        $transition = 'PRODUCTION_HEALTH_RECOVERED'
    }

    if ($transition -ne 'NONE') {
        $alertAttempted = $true
        $webhookValue = [string]$values['PRODUCTION_ALERT_WEBHOOK_URL']
        if ([string]::IsNullOrWhiteSpace($webhookValue)) { throw 'Production alert webhook is not configured.' }
        if ($webhookValue -match '(?i)example\.com|replace-with|placeholder') {
            throw 'Production alert webhook is still a placeholder.'
        }
        $webhookUri = $null
        if (-not [Uri]::TryCreate($webhookValue, [UriKind]::Absolute, [ref]$webhookUri)) {
            throw 'Production alert webhook URL is invalid.'
        }
        if (-not [string]::IsNullOrEmpty($webhookUri.UserInfo)) {
            throw 'Production alert webhook URL must not contain user information.'
        }
        if ($AllowLocalVerification) {
            if ($webhookUri.Scheme -notin @('http', 'https') -or
                (-not $webhookUri.IsLoopback -and $webhookUri.Host -cne 'localhost')) {
                throw 'Local alert verification requires a loopback HTTP or HTTPS webhook.'
            }
        } elseif ($webhookUri.Scheme -cne 'https') {
            throw 'Production alert webhook must use HTTPS.'
        }

        $bearerToken = [string]$values['PRODUCTION_ALERT_BEARER_TOKEN']
        if ($bearerToken -match '(?i)replace-with|placeholder') {
            throw 'Production alert bearer token is still a placeholder.'
        }
        if (-not [string]::IsNullOrWhiteSpace($bearerToken) -and $bearerToken -notmatch '^[\x21-\x7e]{1,4096}$') {
            throw 'Production alert bearer token contains invalid characters.'
        }

        $alertPayload = [ordered]@{
            schemaVersion = 1
            eventType = $transition
            observedAt = if ([string]::IsNullOrWhiteSpace([string]$monitorResult.checkedAt)) {
                [DateTimeOffset]::UtcNow.ToString('o')
            } else {
                [string]$monitorResult.checkedAt
            }
            endpoint = [string]$monitorResult.endpoint
            failedCheck = if ($monitorStatus -eq 'FAIL') { $failedCheck } else { $null }
            checks = $monitorResult.checks
        }
        Send-AlertWebhook `
            -Uri $webhookUri `
            -JsonBody ($alertPayload | ConvertTo-Json -Depth 8 -Compress) `
            -BearerToken $bearerToken `
            -Timeout $TimeoutSeconds
        $alertSent = $true
    }

    $state = [ordered]@{
        schemaVersion = 1
        status = $monitorStatus
        observedAt = if ([string]::IsNullOrWhiteSpace([string]$monitorResult.checkedAt)) {
            [DateTimeOffset]::UtcNow.ToString('o')
        } else {
            [string]$monitorResult.checkedAt
        }
        updatedAt = [DateTimeOffset]::UtcNow.ToString('o')
        lastEvent = $transition
    }
    $temporaryStateFile = "$resolvedStateFile.partial-$([Guid]::NewGuid().ToString('N'))"
    try {
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporaryStateFile -Encoding utf8NoBOM
        [IO.File]::Move($temporaryStateFile, $resolvedStateFile, $true)
    } finally {
        Remove-Item -LiteralPath $temporaryStateFile -Force -ErrorAction SilentlyContinue
    }
    $stateUpdated = $true
    $finalExitCode = $monitorExitCode

    [pscustomobject]@{
        status = $monitorStatus
        monitorExitCode = $monitorExitCode
        transition = $transition
        failedCheck = if ($monitorStatus -eq 'FAIL') { $failedCheck } else { $null }
        alertAttempted = $alertAttempted
        alertSent = $alertSent
        stateUpdated = $stateUpdated
    } | ConvertTo-Json -Depth 5
} catch {
    [pscustomobject]@{
        status = 'ERROR'
        monitorStatus = $monitorStatus
        transition = $transition
        failedCheck = if ([string]::IsNullOrWhiteSpace($failedCheck)) { 'scheduledMonitor' } else { $failedCheck }
        error = $_.Exception.Message
        alertAttempted = $alertAttempted
        alertSent = $alertSent
        stateUpdated = $stateUpdated
    } | ConvertTo-Json -Depth 5
    $finalExitCode = 1
} finally {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    if ($lockAcquired -and $null -ne $lockPath) {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }
}

exit $finalExitCode
