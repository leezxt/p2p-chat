[CmdletBinding()]
param(
    [string]$EnvFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'production.env'),

    [string]$ComposeFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'compose.production.yml'),

    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'target\production-backups')
)

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $backendRoot
$dockerPath = (Get-Command docker -ErrorAction Stop).Source
$resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile -ErrorAction Stop).Path
$resolvedComposeFile = (Resolve-Path -LiteralPath $ComposeFile -ErrorAction Stop).Path

$configJson = & $dockerPath compose --env-file $resolvedEnvFile -f $resolvedComposeFile config --format json
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the production Compose configuration.' }
$config = $configJson | ConvertFrom-Json -Depth 40
$database = [string]$config.services.postgres.environment.POSTGRES_DB
$databaseUser = [string]$config.services.postgres.environment.POSTGRES_USER
if ($database -notmatch '^[A-Za-z][A-Za-z0-9_]{0,62}$') { throw 'Configured POSTGRES_DB is invalid.' }
if ($databaseUser -notmatch '^[A-Za-z][A-Za-z0-9_]{0,62}$') { throw 'Configured POSTGRES_USER is invalid.' }

$containerId = (& $dockerPath compose --env-file $resolvedEnvFile -f $resolvedComposeFile ps -q postgres).Trim()
if ($LASTEXITCODE -ne 0 -or $containerId -notmatch '^[0-9a-f]{12,64}$') {
    throw 'The production PostgreSQL container is not running.'
}
$container = @(& $dockerPath inspect $containerId | ConvertFrom-Json -Depth 30)[0]
if ($container.State.Status -ne 'running' -or $container.State.Health.Status -ne 'healthy') {
    throw 'The production PostgreSQL container must be running and healthy.'
}

$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to resolve the source Git commit.' }
$gitStatus = (& git -C $repoRoot status --porcelain --untracked-files=normal) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the Git working tree.' }
$workingTreeDirty = -not [string]::IsNullOrWhiteSpace($gitStatus)

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmssZ')
$safeDatabase = $database.ToLowerInvariant()
$fileName = "$safeDatabase-$stamp-$($commit.Substring(0, 8)).dump"
$containerPath = "/tmp/$fileName"

try {
    & $dockerPath exec $containerId pg_dump --format=custom --compress=9 --no-owner --no-privileges --file=$containerPath --username=$databaseUser $database
    if ($LASTEXITCODE -ne 0) { throw 'pg_dump failed.' }
    & $dockerPath exec $containerId pg_restore --list $containerPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'pg_restore could not read the generated dump.' }

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    $backupPath = Join-Path $resolvedOutputDirectory $fileName
    & $dockerPath cp "${containerId}:$containerPath" $backupPath
    if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the database dump from the container.' }
} finally {
    & $dockerPath exec $containerId rm -f $containerPath 2>$null | Out-Null
}

$backupFile = Get-Item -LiteralPath $backupPath
$sha256 = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash.ToLowerInvariant()
$postgresVersion = (& $dockerPath exec $containerId pg_dump --version).Trim()
$manifest = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = [ordered]@{
        commit = $commit
        workingTreeDirty = $workingTreeDirty
    }
    database = [ordered]@{
        name = $database
        postgresToolVersion = $postgresVersion
    }
    backup = [ordered]@{
        fileName = $backupFile.Name
        sizeBytes = $backupFile.Length
        sha256 = $sha256
        format = 'PostgreSQL custom'
        compressed = $true
        ownerExcluded = $true
        privilegesExcluded = $true
    }
    verification = [ordered]@{
        pgRestoreListPassed = $true
    }
}
$manifestPath = "$backupPath.manifest.json"
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM

$manifestText = Get-Content -Raw -LiteralPath $manifestPath
if ($manifestText -match '(?i)password|jwt.?secret|encryption.?key|credential|private.?key') {
    Remove-Item -LiteralPath $manifestPath -Force
    throw 'Generated backup manifest contains a forbidden secret marker.'
}

Write-Host "Database backup: $backupPath"
Write-Host "Backup manifest: $manifestPath"
Write-Host "SHA-256: $sha256"
Write-Warning 'The dump contains application data. Move it to encrypted storage with restricted access.'
