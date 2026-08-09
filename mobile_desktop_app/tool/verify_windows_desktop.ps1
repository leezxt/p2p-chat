[CmdletBinding()]
param(
    [switch]$Build,

    [switch]$Runtime,

    [switch]$VerifyClipboard
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$appRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $appRoot
$flutter = Join-Path $repoRoot '.tools\flutter\bin\flutter.bat'
$cryptoRuntimeTest = Join-Path $appRoot 'integration_test\android_crypto_runtime_test.dart'
$desktopLinkRuntimeTest = Join-Path $appRoot 'integration_test\desktop_link_companion_runtime_test.dart'
$artifactRoot = Join-Path $appRoot 'build\windows-desktop-runtime'

function Write-OutputFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $Content | Set-Content -LiteralPath $Path -Encoding utf8
}

function Invoke-Flutter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $logPath = Join-Path $artifactRoot "$Name.log"
    Write-Host "Running flutter $($Arguments -join ' ')"
    & $flutter @Arguments 2>&1 | Tee-Object -FilePath $logPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "flutter $Name failed with exit code $exitCode. Inspect $logPath."
    }
}

function Test-WindowsDesktopPreflight {
    if (-not (Test-Path -LiteralPath $flutter)) {
        throw "Repository-local Flutter was not found at $flutter."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $appRoot 'windows\runner\main.cpp'))) {
        throw 'The Flutter Windows runner is missing from this checkout.'
    }
    foreach ($testPath in @($cryptoRuntimeTest, $desktopLinkRuntimeTest)) {
        if (-not (Test-Path -LiteralPath $testPath)) {
            throw "The native runtime integration test is missing at $testPath."
        }
    }

    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null

    $doctorOutput = & $flutter doctor -v 2>&1 | Out-String
    $doctorExitCode = $LASTEXITCODE
    $doctorLog = Join-Path $artifactRoot 'flutter-doctor.log'
    Write-OutputFile -Path $doctorLog -Content $doctorOutput
    if ($doctorExitCode -ne 0) {
        throw "flutter doctor failed with exit code $doctorExitCode. Inspect $doctorLog."
    }

    $deviceOutput = & $flutter devices 2>&1 | Out-String
    $deviceExitCode = $LASTEXITCODE
    $deviceLog = Join-Path $artifactRoot 'flutter-devices.log'
    Write-OutputFile -Path $deviceLog -Content $deviceOutput
    if ($deviceExitCode -ne 0) {
        throw "flutter devices failed with exit code $deviceExitCode. Inspect $deviceLog."
    }

    # Flutter owns the exact Visual Studio/CMake/Windows SDK compatibility test.
    # Match only its healthy Windows entries rather than guessing a VS component ID.
    $hasWindowsSdk = $doctorOutput -match '(?m)^\[√\] Windows Version'
    $hasVisualStudio =
        $doctorOutput -match '(?m)^\[√\] Visual Studio - develop Windows apps'
    $hasWindowsDevice = $deviceOutput -match 'Windows \(desktop\)'

    if ($hasWindowsSdk -and $hasVisualStudio -and $hasWindowsDevice) {
        return $true
    }

    Write-Host 'Windows desktop preflight is not ready.' -ForegroundColor Yellow
    if (-not $hasVisualStudio) {
        Write-Host (
            'Install Visual Studio Desktop development with C++, including MSVC, ' +
            'CMake tools, and a Windows SDK; then rerun this command.'
        ) -ForegroundColor Yellow
    }
    if (-not $hasWindowsDevice) {
        Write-Host 'Flutter did not expose the Windows desktop device.' -ForegroundColor Yellow
    }
    Write-Host "Flutter diagnostics: $doctorLog"
    Write-Host "Flutter devices: $deviceLog"
    return $false
}

if (-not (Test-WindowsDesktopPreflight)) {
    exit 2
}

$needsNativeBuild = $Build -or $Runtime
if (-not $needsNativeBuild) {
    Write-Host 'Windows desktop preflight passed. Use -Build -Runtime for native validation.'
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($env:NIX_SKIP_SODIUM_BUILD_HOOKS)) {
    throw (
        'NIX_SKIP_SODIUM_BUILD_HOOKS is set. Native Windows validation must build ' +
        'the real sodium asset, so remove this variable before using -Build or -Runtime.'
    )
}

Invoke-Flutter -Name 'pub-get' -Arguments @('pub', 'get', '--enforce-lockfile')
Invoke-Flutter -Name 'windows-debug-build' -Arguments @(
    'build', 'windows', '--debug', '--no-pub'
)

if (-not $Runtime) {
    Write-Host 'Windows debug build passed. Use -Runtime to run native runtime phases.'
    exit 0
}

# Separate invocations create separate Windows app processes. The write/verify
# phases prove that the secure-store key survives process restart; full also
# covers real sodium crypto_box and the local WebRTC DataChannel path.
foreach ($phase in @('write', 'verify', 'full')) {
    Invoke-Flutter -Name "runtime-$phase" -Arguments @(
        'test',
        '--no-pub',
        '-d', 'windows',
        '--dart-define=RUNTIME_PLATFORM=Windows',
        "--dart-define=SECURE_STORAGE_PHASE=$phase",
        'integration_test/android_crypto_runtime_test.dart'
    )
}

$desktopLinkArguments = @(
    'test',
    '--no-pub',
    '-d', 'windows',
    '--dart-define=RUNTIME_PLATFORM=Windows'
)
if ($VerifyClipboard) {
    $desktopLinkArguments += '--dart-define=VERIFY_CLIPBOARD=true'
}
$desktopLinkArguments += 'integration_test/desktop_link_companion_runtime_test.dart'
Invoke-Flutter -Name 'desktop-link-companion-runtime' -Arguments $desktopLinkArguments

Write-Host 'Windows native desktop runtime verification passed.' -ForegroundColor Green
