[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9]+(?:[._/-][a-z0-9]+)*$')]
    [string]$ImageRepository = 'p2p-chat-backend',

    [string]$OutputDirectory,

    [string]$MavenPath,

    [switch]$SkipTests,

    [switch]$AllowDirtyWorkingTree
)

$ErrorActionPreference = 'Stop'

$backendRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $backendRoot
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $backendRoot 'target\v1-release-candidate'
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

if (-not $MavenPath) {
    $MavenPath = (Get-Command mvn.cmd -ErrorAction Stop).Source
}
$MavenPath = (Resolve-Path -LiteralPath $MavenPath -ErrorAction Stop).Path
$dockerPath = (Get-Command docker -ErrorAction Stop).Source

$gitStatus = (& git -C $repoRoot status --porcelain --untracked-files=normal) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the Git working tree.' }
$workingTreeDirty = -not [string]::IsNullOrWhiteSpace($gitStatus)
if ($workingTreeDirty -and -not $AllowDirtyWorkingTree) {
    throw 'Backend candidate artifacts require a clean Git working tree.'
}

$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw 'Unable to resolve the source Git commit.'
}
$shortCommit = $commit.Substring(0, 8)

[xml]$pom = Get-Content -Raw -LiteralPath (Join-Path $backendRoot 'pom.xml')
$namespace = [System.Xml.XmlNamespaceManager]::new($pom.NameTable)
$namespace.AddNamespace('m', 'http://maven.apache.org/POM/4.0.0')
$versionNode = $pom.SelectSingleNode('/m:project/m:version', $namespace)
if ($null -eq $versionNode -or [string]::IsNullOrWhiteSpace($versionNode.InnerText)) {
    throw 'Unable to resolve the backend version from pom.xml.'
}
$version = $versionNode.InnerText.Trim()
$safeVersion = ($version.ToLowerInvariant() -replace '[^a-z0-9._-]', '-')
$imageTag = "$ImageRepository`:$safeVersion-$shortCommit"

Push-Location $backendRoot
try {
    if (-not $SkipTests) {
        Invoke-CheckedCommand -Command $MavenPath -Arguments @('-q', 'test')
    }
    Invoke-CheckedCommand -Command $MavenPath -Arguments @('-q', 'package', '-DskipTests')
    Invoke-CheckedCommand -Command $dockerPath -Arguments @(
        'build',
        '--label', 'org.opencontainers.image.title=p2p-chat-backend',
        '--label', "org.opencontainers.image.version=$version",
        '--label', "org.opencontainers.image.revision=$commit",
        '--tag', $imageTag,
        '.'
    )
} finally {
    Pop-Location
}

$jarSource = Join-Path $backendRoot "target\p2p-chat-backend-$version.jar"
if (-not (Test-Path -LiteralPath $jarSource)) {
    throw "Backend JAR was not found: $jarSource"
}

$imageJson = & $dockerPath image inspect $imageTag
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect Docker image: $imageTag" }
$image = @($imageJson | ConvertFrom-Json -Depth 30)[0]
if ($null -eq $image -or $image.Id -notmatch '^sha256:[0-9a-f]{64}$') {
    throw "Docker image inspection returned an invalid image ID: $imageTag"
}
$labels = $image.Config.Labels
if ($labels.'org.opencontainers.image.revision' -ne $commit) {
    throw 'Docker image revision label does not match the source commit.'
}
if ($labels.'org.opencontainers.image.version' -ne $version) {
    throw 'Docker image version label does not match pom.xml.'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$jarName = "p2p-chat-backend-$safeVersion-$shortCommit.jar"
$jarPath = Join-Path $resolvedOutputDirectory $jarName
Copy-Item -LiteralPath $jarSource -Destination $jarPath -Force
$jarFile = Get-Item -LiteralPath $jarPath
$jarSha256 = (Get-FileHash -LiteralPath $jarPath -Algorithm SHA256).Hash.ToLowerInvariant()
$repoDigests = @($image.RepoDigests | Where-Object { $_ })

$manifest = [ordered]@{
    schemaVersion = 1
    releaseStatus = if ($workingTreeDirty) { 'INTERNAL_BACKEND_CANDIDATE' } else { 'BACKEND_CANDIDATE' }
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = [ordered]@{
        commit = $commit
        workingTreeDirty = $workingTreeDirty
    }
    backend = [ordered]@{
        groupId = 'com.p2pchat'
        artifactId = 'p2p-chat-backend'
        version = $version
        javaVersion = 21
    }
    tests = [ordered]@{
        mavenTestsExecuted = -not $SkipTests
    }
    jar = [ordered]@{
        fileName = $jarFile.Name
        sizeBytes = $jarFile.Length
        sha256 = $jarSha256
    }
    image = [ordered]@{
        tag = $imageTag
        imageId = [string]$image.Id
        sizeBytes = [int64]$image.Size
        localRepoDigests = $repoDigests
        registryDigest = $null
        registryDigestRequiredForRelease = $true
        ociLabels = [ordered]@{
            title = [string]$labels.'org.opencontainers.image.title'
            version = [string]$labels.'org.opencontainers.image.version'
            revision = [string]$labels.'org.opencontainers.image.revision'
        }
    }
}

$manifestPath = Join-Path $resolvedOutputDirectory "p2p-chat-backend-$safeVersion-$shortCommit.manifest.json"
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
$manifestText = Get-Content -Raw -LiteralPath $manifestPath
if ($manifestText -match '(?i)password|jwt.?secret|encryption.?key|credential|private.?key') {
    Remove-Item -LiteralPath $manifestPath -Force
    throw 'Generated backend manifest contains a forbidden secret marker.'
}

Write-Host "Backend JAR: $jarPath"
Write-Host "JAR SHA-256: $jarSha256"
Write-Host "Docker image: $imageTag"
Write-Host "Docker image ID: $($image.Id)"
Write-Host "Candidate manifest: $manifestPath"
Write-Warning 'Local RepoDigests do not prove registry publication; record a registry-verified digest after pushing.'
