[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]+$')]
    [string]$Device,

    [ValidateSet('skip', 'notEnrolled', 'success', 'cancel')]
    [string]$BiometricExpectation = 'skip',

    [switch]$ExpectUnenrolledBiometrics
)

$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $appRoot
$flutter = Join-Path $repoRoot '.tools\flutter\bin\flutter.bat'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
$make = (Get-Command make.exe -ErrorAction Stop).Source

if (-not (Test-Path $flutter)) { throw "Flutter was not found at $flutter." }
if (-not (Test-Path $adb)) { throw "adb was not found at $adb." }
if (-not (Test-Path $gitBash)) { throw "Git Bash was not found at $gitBash." }
if ($ExpectUnenrolledBiometrics) {
    if ($BiometricExpectation -ne 'skip') {
        throw 'Do not combine ExpectUnenrolledBiometrics with BiometricExpectation.'
    }
    $BiometricExpectation = 'notEnrolled'
}
if ($BiometricExpectation -ne 'skip' -and -not $Device.StartsWith('emulator-')) {
    throw 'Automated biometric assertions are restricted to a controlled emulator.'
}

$connected = & $adb devices | Select-Object -Skip 1 | ForEach-Object {
    if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] }
}
if ($connected -notcontains $Device) {
    throw "Android device is not online: $Device"
}

$arguments = @(
    'test',
    'integration_test/android_app_lock_runtime_test.dart',
    '-d', $Device
)
if ($BiometricExpectation -ne 'skip') {
    $arguments += "--dart-define=BIOMETRIC_EXPECTATION=$BiometricExpectation"
}

$previousPath = $env:PATH
$previousGradleOpts = $env:GRADLE_OPTS
try {
    $env:PATH = "$(Split-Path -Parent $gitBash);$(Split-Path -Parent $make);$env:PATH"
    $env:GRADLE_OPTS = '-Dorg.gradle.workers.max=2 -Dkotlin.compiler.execution.strategy=in-process'

    if ($BiometricExpectation -notin @('success', 'cancel')) {
        & $flutter @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Android App Lock runtime test failed with exit code $LASTEXITCODE."
        }
        return
    }

    $artifactRoot = Join-Path $appRoot 'build\app-lock-runtime'
    $stdout = Join-Path $artifactRoot "$BiometricExpectation.stdout.log"
    $stderr = Join-Path $artifactRoot "$BiometricExpectation.stderr.log"
    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
    Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue
    $process = Start-Process `
        -FilePath $flutter `
        -ArgumentList $arguments `
        -WorkingDirectory $appRoot `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -WindowStyle Hidden `
        -PassThru
    $deadline = (Get-Date).AddMinutes(10)
    $interactionApplied = $false
    do {
        if ($process.HasExited) { break }
        & $adb -s $Device shell uiautomator dump /sdcard/app-lock-window.xml 2>$null | Out-Null
        $window = & $adb -s $Device shell cat /sdcard/app-lock-window.xml 2>$null
        if (($window -join '') -match 'Verify App Lock runtime') {
            if ($BiometricExpectation -eq 'success') {
                & $adb -s $Device emu finger touch 1 | Out-Null
            } else {
                & $adb -s $Device shell input keyevent 4 | Out-Null
            }
            $interactionApplied = $true
            break
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    if (-not $interactionApplied) {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        throw 'The Android biometric prompt did not appear before the timeout.'
    }
    if (-not $process.WaitForExit(120000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'The Android App Lock runtime test did not finish after biometric interaction.'
    }
    Get-Content $stdout
    Get-Content $stderr
    if ($process.ExitCode -ne 0) {
        throw "Android App Lock runtime test failed with exit code $($process.ExitCode)."
    }
} finally {
    $env:PATH = $previousPath
    $env:GRADLE_OPTS = $previousGradleOpts
}
