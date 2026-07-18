[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]+$')]
    [string]$Device,

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
if ($ExpectUnenrolledBiometrics -and -not $Device.StartsWith('emulator-')) {
    throw 'The unenrolled biometric assertion is restricted to a controlled emulator.'
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
if ($ExpectUnenrolledBiometrics) {
    $arguments += '--dart-define=EXPECT_UNENROLLED_BIOMETRICS=true'
}

$previousPath = $env:PATH
$previousGradleOpts = $env:GRADLE_OPTS
try {
    $env:PATH = "$(Split-Path -Parent $gitBash);$(Split-Path -Parent $make);$env:PATH"
    $env:GRADLE_OPTS = '-Dorg.gradle.workers.max=2 -Dkotlin.compiler.execution.strategy=in-process'
    & $flutter @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Android App Lock runtime test failed with exit code $LASTEXITCODE."
    }
} finally {
    $env:PATH = $previousPath
    $env:GRADLE_OPTS = $previousGradleOpts
}
