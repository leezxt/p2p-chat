[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]+$')]
    [string]$Device,

    [ValidateNotNullOrEmpty()]
    [string]$PackageId = 'com.p2pchat.p2p_chat_app',

    [string]$ApkPath,

    [ValidateRange(3, 10)]
    [int]$ColdStartRuns = 5,

    [ValidateRange(5, 120)]
    [int]$IdleSeconds = 10,

    [ValidateRange(60, 600)]
    [int]$BackgroundSeconds = 65,

    [ValidateRange(500, 10000)]
    [int]$ColdStartLimitMs = 3000,

    [ValidateRange(32, 1024)]
    [int]$IdleMemoryLimitMb = 150,

    [string]$OutputDirectory,

    [switch]$ClearAppData,

    [switch]$DoNotEnforceThresholds
)

$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $appRoot
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$activity = "$PackageId/.MainActivity"
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $appRoot 'build\v1-android-resources'
}

function Invoke-Adb {
    param(
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $adb -s $Device @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "adb failed ($exitCode): $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return ($output -join "`n").Trim()
}

function Get-Median {
    param([int[]]$Values)

    $sorted = @($Values | Sort-Object)
    $middle = [Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) { return [double]$sorted[$middle] }
    return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
}

function Wait-ForAppProcess {
    param([TimeSpan]$Timeout)

    $deadline = (Get-Date).Add($Timeout)
    do {
        $pidValue = Invoke-Adb -Arguments @('shell', 'pidof', '-s', $PackageId) -AllowFailure
        if ($pidValue -match '^\d+$') { return [int]$pidValue }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    throw "App process did not start: $PackageId"
}

function Get-PssMb {
    $raw = Invoke-Adb -Arguments @('shell', 'dumpsys', 'meminfo', $PackageId)
    $match = [regex]::Match($raw, '(?m)^\s*TOTAL PSS:\s*(\d+)')
    if (-not $match.Success) {
        $match = [regex]::Match($raw, '(?m)^\s*TOTAL\s+(\d+)')
    }
    if (-not $match.Success) {
        throw "Unable to parse TOTAL PSS from dumpsys meminfo for $PackageId."
    }
    return [Math]::Round(([int64]$match.Groups[1].Value / 1024.0), 2)
}

function Get-EstablishedTcpCount {
    param([int]$Uid)

    $raw = Invoke-Adb `
        -Arguments @('shell', 'cat', '/proc/net/tcp', '/proc/net/tcp6') `
        -AllowFailure
    if ($raw -match 'Permission denied|No such file|not found') { return $null }

    $count = 0
    foreach ($line in $raw -split "`r?`n") {
        $columns = @($line.Trim() -split '\s+' | Where-Object { $_ })
        if ($columns.Count -lt 8 -or $columns[0] -notmatch '^\d+:$') { continue }
        if ($columns[3] -eq '01' -and $columns[7] -eq "$Uid") { $count++ }
    }
    return $count
}

function Get-NetworkBytes {
    param([int]$Uid)

    $raw = Invoke-Adb -Arguments @('shell', 'dumpsys', 'netstats', 'detail') -AllowFailure
    if (-not $raw -or $raw -match 'Permission denied|not found|Can.t find service') {
        return $null
    }

    [int64]$received = 0
    [int64]$transmitted = 0
    $matched = $false
    foreach ($line in $raw -split "`r?`n") {
        if ($line -notmatch "\buid=$Uid\b") { continue }
        $rx = [regex]::Match($line, '\brb=(\d+)')
        $tx = [regex]::Match($line, '\btb=(\d+)')
        if (-not $rx.Success -or -not $tx.Success) { continue }
        $received += [int64]$rx.Groups[1].Value
        $transmitted += [int64]$tx.Groups[1].Value
        $matched = $true
    }
    if (-not $matched) {
        return [pscustomobject]@{
            received = 0
            transmitted = 0
            total = 0
        }
    }
    return [pscustomobject]@{
        received = $received
        transmitted = $transmitted
        total = $received + $transmitted
    }
}

if (-not (Test-Path $adb)) { throw "adb was not found at $adb." }
$connected = & $adb devices | Select-Object -Skip 1 | ForEach-Object {
    if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
}
if ($connected -notcontains $Device) { throw "Android device is not online: $Device" }

if ($ApkPath) {
    $resolvedApk = (Resolve-Path $ApkPath -ErrorAction Stop).Path
    Invoke-Adb -Arguments @('install', '-r', $resolvedApk) | Out-Null
}
if ($ClearAppData) {
    Invoke-Adb -Arguments @('shell', 'pm', 'clear', $PackageId) | Out-Null
}

$package = Invoke-Adb -Arguments @('shell', 'cmd', 'package', 'list', 'packages', '-U', $PackageId)
if ($package -notmatch 'uid:(\d+)') { throw "Unable to resolve package UID: $PackageId" }
$uid = [int]$Matches[1]
$model = Invoke-Adb -Arguments @('shell', 'getprop', 'ro.product.model')
$sdk = [int](Invoke-Adb -Arguments @('shell', 'getprop', 'ro.build.version.sdk'))
$isEmulator = (Invoke-Adb -Arguments @('shell', 'getprop', 'ro.kernel.qemu')) -eq '1'
$versionRaw = Invoke-Adb -Arguments @('shell', 'dumpsys', 'package', $PackageId)
$versionName = [regex]::Match($versionRaw, '(?m)^\s*versionName=(\S+)').Groups[1].Value
$versionCode = [regex]::Match($versionRaw, '(?m)^\s*versionCode=(\d+)').Groups[1].Value

$coldStarts = [System.Collections.Generic.List[int]]::new()
for ($run = 1; $run -le $ColdStartRuns; $run++) {
    $launch = Invoke-Adb -Arguments @('shell', 'am', 'start', '-W', '-S', '-n', $activity)
    $match = [regex]::Match($launch, '(?m)^TotalTime:\s*(\d+)')
    if (-not $match.Success) { throw "Unable to parse TotalTime from launch run $run.`n$launch" }
    $coldStarts.Add([int]$match.Groups[1].Value)
    Wait-ForAppProcess -Timeout ([TimeSpan]::FromSeconds(15)) | Out-Null
    Start-Sleep -Seconds 1
}

Start-Sleep -Seconds $IdleSeconds
$foregroundPid = Wait-ForAppProcess -Timeout ([TimeSpan]::FromSeconds(5))
$foregroundPssMb = Get-PssMb
$foregroundTcp = Get-EstablishedTcpCount -Uid $uid
$networkBefore = Get-NetworkBytes -Uid $uid

Invoke-Adb -Arguments @('shell', 'input', 'keyevent', 'KEYCODE_HOME') | Out-Null
Start-Sleep -Seconds $BackgroundSeconds
$backgroundPidRaw = Invoke-Adb -Arguments @('shell', 'pidof', '-s', $PackageId) -AllowFailure
$backgroundAlive = $backgroundPidRaw -match '^\d+$'
$backgroundPssMb = if ($backgroundAlive) { Get-PssMb } else { 0.0 }
$backgroundTcp = Get-EstablishedTcpCount -Uid $uid
$networkAfter = Get-NetworkBytes -Uid $uid

$networkDelta = if ($null -ne $networkBefore -and $null -ne $networkAfter) {
    [Math]::Max(0, $networkAfter.total - $networkBefore.total)
} else {
    $null
}
$medianColdStartMs = Get-Median -Values $coldStarts.ToArray()
$coldStartPassed = $medianColdStartMs -le $ColdStartLimitMs
$idleMemoryPassed = $foregroundPssMb -le $IdleMemoryLimitMb
$backgroundP2pPassed = $null -ne $backgroundTcp -and $backgroundTcp -eq 0
$overallPassed = $coldStartPassed -and $idleMemoryPassed -and $backgroundP2pPassed

$result = [ordered]@{
    schemaVersion = 1
    measuredAt = (Get-Date).ToString('o')
    device = [ordered]@{
        serial = $Device
        model = $model
        androidSdk = $sdk
        emulator = $isEmulator
    }
    app = [ordered]@{
        packageId = $PackageId
        versionName = $versionName
        versionCode = $versionCode
        uid = $uid
    }
    thresholds = [ordered]@{
        coldStartMs = $ColdStartLimitMs
        idleMemoryMb = $IdleMemoryLimitMb
        backgroundEstablishedTcp = 0
    }
    measurements = [ordered]@{
        coldStartRunsMs = $coldStarts.ToArray()
        coldStartMedianMs = $medianColdStartMs
        coldStartMaximumMs = ($coldStarts | Measure-Object -Maximum).Maximum
        foregroundPssMb = $foregroundPssMb
        backgroundPssMb = $backgroundPssMb
        foregroundPid = $foregroundPid
        backgroundProcessAlive = $backgroundAlive
        foregroundEstablishedTcp = $foregroundTcp
        backgroundEstablishedTcp = $backgroundTcp
        backgroundNetworkDeltaBytes = $networkDelta
        backgroundDurationSeconds = $BackgroundSeconds
        battery = if ($isEmulator) { 'NOT_MEANINGFUL_ON_EMULATOR' } else { 'REQUIRES_LONG_RUNNING_MANUAL_SCENARIO' }
    }
    checks = [ordered]@{
        coldStartPassed = $coldStartPassed
        idleMemoryPassed = $idleMemoryPassed
        backgroundP2pPassed = $backgroundP2pPassed
        overallPassed = $overallPassed
    }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonPath = Join-Path $OutputDirectory "android-resources-$stamp.json"
$markdownPath = Join-Path $OutputDirectory "android-resources-$stamp.md"
$result | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding utf8NoBOM

$networkText = if ($null -eq $networkDelta) { 'unavailable' } else { "$networkDelta bytes" }
$tcpText = if ($null -eq $backgroundTcp) { 'unavailable' } else { "$backgroundTcp" }
$markdown = @(
    '# Android V1 Resource Measurement',
    '',
    "- Device: $model ($Device), Android API $sdk, emulator=$isEmulator",
    "- App: $PackageId $versionName ($versionCode)",
    "- Cold start median: $medianColdStartMs ms (limit: $ColdStartLimitMs ms, pass=$coldStartPassed)",
    "- Cold start runs: $($coldStarts -join ', ') ms",
    "- Foreground idle PSS: $foregroundPssMb MB (limit: $IdleMemoryLimitMb MB, pass=$idleMemoryPassed)",
    "- Background PSS after $BackgroundSeconds seconds: $backgroundPssMb MB",
    "- Background established TCP: $tcpText (expected: 0, pass=$backgroundP2pPassed)",
    "- Background network delta: $networkText",
    "- Battery: $($result.measurements.battery)",
    "- Overall automated checks passed: $overallPassed"
)
$markdown | Set-Content -Path $markdownPath -Encoding utf8NoBOM

Write-Host "Resource report: $jsonPath"
Write-Host "Resource summary: $markdownPath"
Write-Host "Cold start median: $medianColdStartMs ms; idle PSS: $foregroundPssMb MB; background TCP: $tcpText"

if (-not $DoNotEnforceThresholds -and -not $overallPassed) {
    throw 'One or more Android V1 resource checks failed.'
}
