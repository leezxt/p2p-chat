[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]+$')]
    [string]$Device
)

Set-StrictMode -Version Latest
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

$connected = & $adb devices | Select-Object -Skip 1 | ForEach-Object {
    if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] }
}
if ($connected -notcontains $Device) {
    throw "Android device is not online: $Device"
}

$previousPath = $env:PATH
$previousGradleOpts = $env:GRADLE_OPTS
$hadNixSkip = Test-Path Env:NIX_SKIP_SODIUM_BUILD_HOOKS
$previousNixSkip = $env:NIX_SKIP_SODIUM_BUILD_HOOKS
try {
    $env:PATH = "$(Split-Path -Parent $gitBash);$(Split-Path -Parent $make);$env:PATH"
    $env:GRADLE_OPTS = '-Dorg.gradle.workers.max=2 -Dkotlin.compiler.execution.strategy=in-process'
    # Android native runtime 必須使用正式 sodium 原生載入，不能沿用 host static
    # analysis 的 NIX_SKIP_SODIUM_BUILD_HOOKS 逃生開關。
    Remove-Item Env:NIX_SKIP_SODIUM_BUILD_HOOKS -ErrorAction SilentlyContinue

    Push-Location $appRoot
    try {
        & $flutter test 'integration_test/android_sticker_runtime_test.dart' '-d' $Device
        if ($LASTEXITCODE -ne 0) {
            throw "Android sticker runtime test failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
} finally {
    $env:PATH = $previousPath
    $env:GRADLE_OPTS = $previousGradleOpts
    if ($hadNixSkip) {
        $env:NIX_SKIP_SODIUM_BUILD_HOOKS = $previousNixSkip
    } else {
        Remove-Item Env:NIX_SKIP_SODIUM_BUILD_HOOKS -ErrorAction SilentlyContinue
    }
}
