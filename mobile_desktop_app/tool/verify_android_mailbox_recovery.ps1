[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]+$')]
    [string]$SenderDevice,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]+$')]
    [string]$ReceiverDevice,

    [ValidateRange(1024, 65535)]
    [int]$BackendPort = 8081
)

$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $appRoot
$backendRoot = Join-Path $repoRoot 'java_backend'
$flutter = Join-Path $repoRoot '.tools\flutter\bin\flutter.bat'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$maven = (Get-Command mvn.cmd -ErrorAction Stop).Source
$gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
$make = (Get-Command make.exe -ErrorAction Stop).Source
$nativeBuildPath = "$(Split-Path -Parent $gitBash);$(Split-Path -Parent $make);$env:PATH"
$artifactRoot = Join-Path $appRoot 'build\v1-android-mailbox-recovery'
$backendOut = Join-Path $artifactRoot 'backend.stdout.log'
$backendErr = Join-Path $artifactRoot 'backend.stderr.log'

$userA = '11111111-1111-4111-8111-111111111111'
$userB = '22222222-2222-4222-8222-222222222222'
$localDevKey = 'test-local-dev-key'
$backendBaseUrl = "http://127.0.0.1:$BackendPort"
$applicationId = 'com.p2pchat.p2p_chat_app'
$backendProcess = $null
$activeTestProcess = $null
$senderUploadRun = $null
$reversedDevices = [System.Collections.Generic.List[string]]::new()

function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Process)

    if ($null -eq $Process -or $Process.HasExited) { return }
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $($Process.Id)"
    foreach ($child in $children) {
        try {
            Stop-ProcessTree -Process (Get-Process -Id $child.ProcessId -ErrorAction Stop)
        } catch {
            # The child may exit between discovery and cleanup.
        }
    }
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
}

function Get-DeviceEndpoint {
    param([string]$Device)

    if ($Device.StartsWith('emulator-')) {
        return "http://10.0.2.2:$BackendPort"
    }

    & $adb -s $Device reverse "tcp:$BackendPort" "tcp:$BackendPort" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to configure adb reverse for $Device." }
    $reversedDevices.Add($Device)
    return "http://127.0.0.1:$BackendPort"
}

function Wait-ForBackend {
    $deadline = (Get-Date).AddMinutes(2)
    do {
        if ($backendProcess.HasExited) {
            throw "Backend exited with code $($backendProcess.ExitCode)."
        }
        try {
            $health = Invoke-RestMethod "$backendBaseUrl/actuator/health" -TimeoutSec 3
            if ($health.status -eq 'UP') { return }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)
    throw 'Backend readiness timed out.'
}

function Get-LocalToken {
    param([string]$UserId)

    $response = Invoke-RestMethod `
        -Uri "$backendBaseUrl/api/v1/auth/local-token" `
        -Method Post `
        -Headers @{ 'X-Local-Dev-Key' = $localDevKey } `
        -ContentType 'application/json' `
        -Body (@{ userId = $UserId } | ConvertTo-Json -Compress) `
        -TimeoutSec 5
    return $response.token
}

function Add-TestContact {
    param(
        [string]$SenderToken,
        [string]$ReceiverToken
    )

    $invite = Invoke-RestMethod `
        -Uri "$backendBaseUrl/api/v1/invites" `
        -Method Post `
        -Headers @{ Authorization = "Bearer $SenderToken" } `
        -ContentType 'application/json' `
        -TimeoutSec 5
    Invoke-RestMethod `
        -Uri "$backendBaseUrl/api/v1/invites/redeem" `
        -Method Post `
        -Headers @{ Authorization = "Bearer $ReceiverToken" } `
        -ContentType 'application/json' `
        -Body (@{ code = $invite.code } | ConvertTo-Json -Compress) `
        -TimeoutSec 5 | Out-Null
}

function Start-DevicePhase {
    param(
        [string]$Phase,
        [string]$Device,
        [string]$Endpoint
    )

    $stdout = Join-Path $artifactRoot "$Phase.stdout.log"
    $stderr = Join-Path $artifactRoot "$Phase.stderr.log"
    Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue
    $arguments = @(
        'test',
        'integration_test/android_mailbox_restart_e2e_test.dart',
        '-d', $Device,
        "--dart-define=E2E_MAILBOX_PHASE=$Phase",
        "--dart-define=E2E_BACKEND_URL=$Endpoint"
    )
    $process = Start-Process `
        -FilePath $flutter `
        -ArgumentList $arguments `
        -WorkingDirectory $appRoot `
        -Environment @{ PATH = $nativeBuildPath } `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -WindowStyle Hidden `
        -PassThru
    return @{
        Process = $process
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Wait-ForProcessExit {
    param(
        [System.Diagnostics.Process]$Process,
        [TimeSpan]$Timeout
    )

    $deadline = (Get-Date).Add($Timeout)
    while (-not $Process.HasExited) {
        if ((Get-Date) -ge $deadline) { return $false }
        Start-Sleep -Milliseconds 500
    }
    return $true
}

function Wait-ForDeviceReady {
    param([string]$Device)

    & $adb start-server | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to restart the ADB server.' }
    $deadline = (Get-Date).AddMinutes(1)
    do {
        $state = & $adb -s $Device get-state 2>$null
        $bootCompleted = & $adb -s $Device shell getprop sys.boot_completed 2>$null
        if ($state -eq 'device' -and $bootCompleted -match '1') { return }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    throw "Android device did not recover after force-stop: $Device"
}

function Write-LogTail {
    param([string]$Path)

    if (Test-Path $Path) {
        Write-Host "--- $Path"
        Get-Content $Path -Tail 100
    }
}

function Wait-ForLogPattern {
    param(
        [hashtable]$Run,
        [string]$Pattern,
        [TimeSpan]$Timeout
    )

    $deadline = (Get-Date).Add($Timeout)
    while ((Get-Date) -lt $deadline) {
        if ($Run.Process.HasExited) {
            Write-LogTail $Run.StdOut
            Write-LogTail $Run.StdErr
            throw "Device phase exited before checkpoint: $Pattern"
        }
        if ((Test-Path $Run.StdOut) -and
            (Select-String -Path $Run.StdOut -Pattern $Pattern -Quiet)) {
            return
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Device phase checkpoint timed out: $Pattern"
}

function Invoke-DevicePhase {
    param(
        [string]$Phase,
        [string]$Device,
        [string]$Endpoint
    )

    $run = Start-DevicePhase -Phase $Phase -Device $Device -Endpoint $Endpoint
    $script:activeTestProcess = $run.Process
    if (-not (Wait-ForProcessExit -Process $run.Process -Timeout ([TimeSpan]::FromMinutes(8)))) {
        throw "Android mailbox phase timed out: $Phase"
    }
    if ($run.Process.ExitCode -ne 0) {
        Write-LogTail $run.StdOut
        Write-LogTail $run.StdErr
        throw "Android mailbox phase failed: $Phase (exit $($run.Process.ExitCode))"
    }
    $script:activeTestProcess = $null
}

function Invoke-AckLossAndForceStop {
    param(
        [string]$Device,
        [string]$Endpoint
    )

    $run = Start-DevicePhase `
        -Phase 'receiver_ack_loss' `
        -Device $Device `
        -Endpoint $Endpoint
    $script:activeTestProcess = $run.Process
    Wait-ForLogPattern `
        -Run $run `
        -Pattern 'E2E_MAILBOX_ACK_LOSS_READY' `
        -Timeout ([TimeSpan]::FromMinutes(8))

    & $adb -s $Device shell am force-stop $applicationId
    if ($LASTEXITCODE -ne 0) { throw "Failed to force-stop $applicationId on $Device." }
    if (-not (Wait-ForProcessExit -Process $run.Process -Timeout ([TimeSpan]::FromSeconds(20)))) {
        Stop-ProcessTree $run.Process
    }
    Wait-ForDeviceReady $Device
    $script:activeTestProcess = $null
}

if ($SenderDevice -eq $ReceiverDevice) {
    throw 'SenderDevice and ReceiverDevice must be different.'
}
if (-not (Test-Path $flutter)) { throw "Flutter was not found at $flutter." }
if (-not (Test-Path $adb)) { throw "adb was not found at $adb." }
if (-not (Test-Path $gitBash)) { throw "Git Bash was not found at $gitBash." }

$connected = & $adb devices | Select-Object -Skip 1 | ForEach-Object {
    if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
}
foreach ($device in @($SenderDevice, $ReceiverDevice)) {
    if ($connected -notcontains $device) { throw "Android device is not online: $device" }
}
if (Get-NetTCPConnection -LocalPort $BackendPort -State Listen -ErrorAction SilentlyContinue) {
    throw "Backend port is already in use: $BackendPort"
}

New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
Remove-Item $backendOut, $backendErr -Force -ErrorAction SilentlyContinue

try {
    $backendArguments = @(
        '-q',
        '-Dspring-boot.run.profiles=test',
        '-Dspring-boot.run.useTestClasspath=true',
        "-Dspring-boot.run.arguments=--server.port=$BackendPort",
        'spring-boot:run'
    )
    $backendProcess = Start-Process `
        -FilePath $maven `
        -ArgumentList $backendArguments `
        -WorkingDirectory $backendRoot `
        -Environment @{
            JWT_SECRET = 'dGVzdC1qd3Qtc2VjcmV0LW11c3QtYmUtYXQtbGVhc3QtMzItYnl0ZXMtbG9uZw=='
            APP_SECURITY_LOCAL_DEV_KEY = $localDevKey
            PUSH_TOKEN_ENCRYPTION_KEYS = 'test-v1=AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8='
            SERVER_ADDRESS = '127.0.0.1'
        } `
        -RedirectStandardOutput $backendOut `
        -RedirectStandardError $backendErr `
        -WindowStyle Hidden `
        -PassThru
    Wait-ForBackend

    $senderEndpoint = Get-DeviceEndpoint $SenderDevice
    $receiverEndpoint = Get-DeviceEndpoint $ReceiverDevice
    Invoke-DevicePhase 'register_sender' $SenderDevice $senderEndpoint
    Invoke-DevicePhase 'register_receiver' $ReceiverDevice $receiverEndpoint
    Add-TestContact `
        -SenderToken (Get-LocalToken $userA) `
        -ReceiverToken (Get-LocalToken $userB)

    $senderUploadRun = Start-DevicePhase `
        -Phase 'sender_upload' `
        -Device $SenderDevice `
        -Endpoint $senderEndpoint
    Wait-ForLogPattern `
        -Run $senderUploadRun `
        -Pattern 'E2E_MAILBOX_UPLOAD_READY' `
        -Timeout ([TimeSpan]::FromMinutes(8))
    Invoke-AckLossAndForceStop $ReceiverDevice $receiverEndpoint
    Invoke-DevicePhase 'receiver_restart' $ReceiverDevice $receiverEndpoint
    if (-not (Wait-ForProcessExit `
        -Process $senderUploadRun.Process `
        -Timeout ([TimeSpan]::FromMinutes(2)))) {
        throw 'Sender did not finish after the receiver sent READ.'
    }
    if ($senderUploadRun.Process.ExitCode -ne 0) {
        Write-LogTail $senderUploadRun.StdOut
        Write-LogTail $senderUploadRun.StdErr
        throw "Sender upload/status phase failed (exit $($senderUploadRun.Process.ExitCode))."
    }

    Write-Host "Android mailbox restart recovery passed on $SenderDevice and $ReceiverDevice."
} catch {
    Write-LogTail $backendOut
    Write-LogTail $backendErr
    throw
} finally {
    Stop-ProcessTree $activeTestProcess
    Stop-ProcessTree $senderUploadRun.Process
    Stop-ProcessTree $backendProcess
    foreach ($device in $reversedDevices) {
        & $adb -s $device reverse --remove "tcp:$BackendPort" | Out-Null
    }
}
