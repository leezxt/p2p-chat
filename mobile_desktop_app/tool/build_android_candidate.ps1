[CmdletBinding()]
param(
    [ValidateSet('Profile', 'Release')]
    [string]$Mode = 'Profile',

    [ValidateSet('android-arm64', 'android-x64')]
    [string]$TargetPlatform = 'android-arm64',

    [ValidatePattern('^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$')]
    [string]$ApplicationId,

    [string]$OutputDirectory,

    [string]$FlutterPath,

    [switch]$AllowDirtyWorkingTree
)

$ErrorActionPreference = 'Stop'

$appRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $appRoot
$defaultApplicationId = 'com.p2pchat.p2p_chat_app'
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $appRoot 'build\v1-release-candidate'
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $Command $($Arguments -join ' ')"
    }
}

if (-not $FlutterPath) {
    $bundledFlutter = Join-Path $repoRoot '.tools\flutter\bin\flutter.bat'
    if (Test-Path -LiteralPath $bundledFlutter) {
        $FlutterPath = $bundledFlutter
    } else {
        $flutterCommand = Get-Command flutter -ErrorAction Stop
        $FlutterPath = $flutterCommand.Source
    }
}
$FlutterPath = (Resolve-Path -LiteralPath $FlutterPath -ErrorAction Stop).Path

$gitStatus = (& git -C $repoRoot status --porcelain --untracked-files=normal) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the Git working tree.' }
$workingTreeDirty = -not [string]::IsNullOrWhiteSpace($gitStatus)
if ($workingTreeDirty -and -not $AllowDirtyWorkingTree) {
    throw 'Candidate artifacts require a clean Git working tree. Use -AllowDirtyWorkingTree only for internal profile verification.'
}
if ($Mode -eq 'Release' -and $workingTreeDirty) {
    throw 'Release candidate artifacts cannot be built from a dirty Git working tree.'
}

$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw 'Unable to resolve the source Git commit.'
}
$shortCommit = $commit.Substring(0, 8)

if ($Mode -eq 'Release') {
    if ([string]::IsNullOrWhiteSpace($ApplicationId) -or $ApplicationId -eq $defaultApplicationId) {
        throw 'Release mode requires a unique -ApplicationId.'
    }
    $keyProperties = Join-Path $appRoot 'android\key.properties'
    if (-not (Test-Path -LiteralPath $keyProperties)) {
        throw 'Release mode requires mobile_desktop_app/android/key.properties.'
    }
}

$previousApplicationId = $env:P2P_APPLICATION_ID
$previousPath = $env:PATH
try {
    if ($ApplicationId) { $env:P2P_APPLICATION_ID = $ApplicationId }
    if ($IsWindows) {
        $gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
        if (-not (Test-Path -LiteralPath $gitBash)) {
            throw "Git Bash was not found: $gitBash"
        }
        $makeCommand = Get-Command make.exe -ErrorAction Stop
        $env:PATH = "$(Split-Path -Parent $gitBash);$(Split-Path -Parent $makeCommand.Source);$previousPath"
    }
    Push-Location $appRoot
    try {
        if ($Mode -eq 'Release') {
            Invoke-CheckedCommand -Command $FlutterPath -Arguments @('build', 'appbundle', '--release')
            $metadataPath = Join-Path $appRoot 'build\app\outputs\bundle\release\output-metadata.json'
            $artifactType = 'AAB'
        } else {
            Invoke-CheckedCommand -Command $FlutterPath -Arguments @(
                'build', 'apk', '--profile', '--target-platform', $TargetPlatform
            )
            $metadataPath = Join-Path $appRoot 'build\app\outputs\apk\profile\output-metadata.json'
            $artifactType = 'APK'
        }
    } finally {
        Pop-Location
    }
} finally {
    $env:P2P_APPLICATION_ID = $previousApplicationId
    $env:PATH = $previousPath
}

if (-not (Test-Path -LiteralPath $metadataPath)) {
    throw "Gradle output metadata was not found: $metadataPath"
}
$metadata = Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json -Depth 20
$element = @($metadata.elements)[0]
if ($null -eq $element -or [string]::IsNullOrWhiteSpace($element.outputFile)) {
    throw "Gradle output metadata does not contain an artifact: $metadataPath"
}
if ($Mode -eq 'Release' -and $metadata.applicationId -ne $ApplicationId) {
    throw "Built application ID '$($metadata.applicationId)' does not match '$ApplicationId'."
}

$artifactSource = Join-Path (Split-Path -Parent $metadataPath) $element.outputFile
if (-not (Test-Path -LiteralPath $artifactSource)) {
    throw "Built artifact was not found: $artifactSource"
}
$version = "$($element.versionName)+$($element.versionCode)"
$safeVersion = $version -replace '[^A-Za-z0-9._+-]', '_'
$extension = if ($artifactType -eq 'AAB') { 'aab' } else { 'apk' }
$artifactName = "p2p-messenger-android-$($Mode.ToLowerInvariant())-$safeVersion-$shortCommit.$extension"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$artifactPath = Join-Path $resolvedOutputDirectory $artifactName
Copy-Item -LiteralPath $artifactSource -Destination $artifactPath -Force

$artifactFile = Get-Item -LiteralPath $artifactPath
$sha256 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
$flutterInfo = (& $FlutterPath --version --machine | ConvertFrom-Json -Depth 20)
if ($LASTEXITCODE -ne 0) { throw 'Unable to read the Flutter version.' }

$releaseStatus = if ($Mode -eq 'Release') { 'RELEASE_CANDIDATE' } else { 'INTERNAL_PROFILE' }
$manifest = [ordered]@{
    schemaVersion = 1
    releaseStatus = $releaseStatus
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = [ordered]@{
        commit = $commit
        workingTreeDirty = $workingTreeDirty
    }
    app = [ordered]@{
        applicationId = $metadata.applicationId
        versionName = [string]$element.versionName
        versionCode = [int64]$element.versionCode
        variant = [string]$metadata.variantName
    }
    build = [ordered]@{
        mode = $Mode
        targetPlatform = if ($Mode -eq 'Profile') { $TargetPlatform } else { 'android-app-bundle' }
        flutterVersion = [string]$flutterInfo.frameworkVersion
        dartVersion = [string]$flutterInfo.dartSdkVersion
        distributionSigningRequired = $Mode -eq 'Release'
    }
    artifact = [ordered]@{
        type = $artifactType
        fileName = $artifactFile.Name
        sizeBytes = $artifactFile.Length
        sha256 = $sha256
    }
}

$manifestPath = Join-Path $resolvedOutputDirectory "$artifactName.manifest.json"
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM

$manifestText = Get-Content -Raw -LiteralPath $manifestPath
if ($manifestText -match '(?i)storePassword|keyPassword|private.?key|replace-with-secret') {
    Remove-Item -LiteralPath $manifestPath -Force
    throw 'Generated manifest contains a forbidden secret marker.'
}

Write-Host "Android artifact: $artifactPath"
Write-Host "Artifact manifest: $manifestPath"
Write-Host "SHA-256: $sha256"
Write-Host "Release status: $releaseStatus"
