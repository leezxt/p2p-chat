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
$artifactRoot = Join-Path $appRoot 'build\v1-android-e2e'
$backendOut = Join-Path $artifactRoot 'backend.stdout.log'
$backendErr = Join-Path $artifactRoot 'backend.stderr.log'
$senderOut = Join-Path $artifactRoot 'sender.stdout.log'
$senderErr = Join-Path $artifactRoot 'sender.stderr.log'
$receiverOut = Join-Path $artifactRoot 'receiver.stdout.log'
$receiverErr = Join-Path $artifactRoot 'receiver.stderr.log'

$userA = '11111111-1111-4111-8111-111111111111'
$userB = '22222222-2222-4222-8222-222222222222'
$localDevKey = 'test-local-dev-key'
$backendBaseUrl = "http://127.0.0.1:$BackendPort"
$backendProcess = $null
$senderProcess = $null
$receiverProcess = $null
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
        return @{
            Backend = "http://10.0.2.2:$BackendPort"
            Signaling = "ws://10.0.2.2:$BackendPort/ws/signaling"
        }
    }

    & $adb -s $Device reverse "tcp:$BackendPort" "tcp:$BackendPort" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to configure adb reverse for $Device." }
    $reversedDevices.Add($Device)
    return @{
        Backend = "http://127.0.0.1:$BackendPort"
        Signaling = "ws://127.0.0.1:$BackendPort/ws/signaling"
    }
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

function Wait-ForLocalToken {
    param(
        [string]$UserId,
        [System.Diagnostics.Process]$DeviceProcess
    )

    $headers = @{ 'X-Local-Dev-Key' = $localDevKey }
    $body = @{ userId = $UserId } | ConvertTo-Json -Compress
    $deadline = (Get-Date).AddMinutes(8)
    do {
        if ($DeviceProcess.HasExited) {
            throw "Device test exited before registration with code $($DeviceProcess.ExitCode)."
        }
        try {
            $response = Invoke-RestMethod `
                -Uri "$backendBaseUrl/api/v1/auth/local-token" `
                -Method Post `
                -Headers $headers `
                -ContentType 'application/json' `
                -Body $body `
                -TimeoutSec 3
            return $response.token
        } catch {
            Start-Sleep -Seconds 1
        }
    } while ((Get-Date) -lt $deadline)
    throw "Registration timed out for user $UserId."
}

function Start-DeviceTest {
    param(
        [string]$Role,
        [string]$Device,
        [hashtable]$Endpoint,
        [string]$StdOut,
        [string]$StdErr
    )

    $arguments = @(
        'test',
        'integration_test/android_two_device_e2e_test.dart',
        '-d', $Device,
        "--dart-define=E2E_ROLE=$Role",
        "--dart-define=E2E_BACKEND_URL=$($Endpoint.Backend)",
        "--dart-define=E2E_SIGNALING_URL=$($Endpoint.Signaling)"
    )
    return Start-Process `
        -FilePath $flutter `
        -ArgumentList $arguments `
        -WorkingDirectory $appRoot `
        -Environment @{ PATH = $nativeBuildPath } `
        -RedirectStandardOutput $StdOut `
        -RedirectStandardError $StdErr `
        -WindowStyle Hidden `
        -PassThru
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

function Wait-ForDeviceTests {
    $deadline = (Get-Date).AddMinutes(5)
    do {
        if ($senderProcess.HasExited -and $receiverProcess.HasExited) { return }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    throw 'Android E2E device tests timed out.'
}

function Write-LogTail {
    param([string]$Path)

    if (Test-Path $Path) {
        Write-Host "--- $Path"
        Get-Content $Path -Tail 80
    }
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
Remove-Item $backendOut, $backendErr, $senderOut, $senderErr, $receiverOut, $receiverErr `
    -Force -ErrorAction SilentlyContinue

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

    $receiverEndpoint = Get-DeviceEndpoint $ReceiverDevice
    $senderEndpoint = Get-DeviceEndpoint $SenderDevice

    $receiverProcess = Start-DeviceTest `
        -Role 'receiver' `
        -Device $ReceiverDevice `
        -Endpoint $receiverEndpoint `
        -StdOut $receiverOut `
        -StdErr $receiverErr
    $receiverToken = Wait-ForLocalToken -UserId $userB -DeviceProcess $receiverProcess

    $senderProcess = Start-DeviceTest `
        -Role 'sender' `
        -Device $SenderDevice `
        -Endpoint $senderEndpoint `
        -StdOut $senderOut `
        -StdErr $senderErr
    $senderToken = Wait-ForLocalToken -UserId $userA -DeviceProcess $senderProcess

    Add-TestContact -SenderToken $senderToken -ReceiverToken $receiverToken
    Wait-ForDeviceTests

    if ($senderProcess.ExitCode -ne 0 -or $receiverProcess.ExitCode -ne 0) {
        throw "Android E2E failed (sender=$($senderProcess.ExitCode), receiver=$($receiverProcess.ExitCode))."
    }
    Write-Host "Android encrypted P2P E2E passed on $SenderDevice and $ReceiverDevice."
} catch {
    Write-LogTail $senderOut
    Write-LogTail $senderErr
    Write-LogTail $receiverOut
    Write-LogTail $receiverErr
    Write-LogTail $backendOut
    Write-LogTail $backendErr
    throw
} finally {
    Stop-ProcessTree $senderProcess
    Stop-ProcessTree $receiverProcess
    Stop-ProcessTree $backendProcess
    foreach ($device in $reversedDevices) {
        & $adb -s $device reverse --remove "tcp:$BackendPort" | Out-Null
    }
}
