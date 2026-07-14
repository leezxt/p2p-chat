[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]{0,62}$')]
    [string]$TargetDatabase,

    [string]$EnvFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'production.env'),

    [string]$ComposeFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'compose.production.yml'),

    [switch]$CreateTargetDatabase,

    [switch]$ReplaceExistingTarget,

    [switch]$AllowSourceDatabaseReplacement,

    [string]$Confirmation
)

$ErrorActionPreference = 'Stop'
$dockerPath = (Get-Command docker -ErrorAction Stop).Source
$resolvedBackupPath = (Resolve-Path -LiteralPath $BackupPath -ErrorAction Stop).Path
$resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile -ErrorAction Stop).Path
$resolvedComposeFile = (Resolve-Path -LiteralPath $ComposeFile -ErrorAction Stop).Path

$manifestPath = "$resolvedBackupPath.manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Backup manifest was not found: $manifestPath" }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 20
$actualHash = (Get-FileHash -LiteralPath $resolvedBackupPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($manifest.backup.sha256 -ne $actualHash) { throw 'Backup SHA-256 does not match its manifest.' }
if ($manifest.backup.format -ne 'PostgreSQL custom' -or -not $manifest.verification.pgRestoreListPassed) {
    throw 'Backup manifest does not describe a verified PostgreSQL custom dump.'
}

$configJson = & $dockerPath compose --env-file $resolvedEnvFile -f $resolvedComposeFile config --format json
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the production Compose configuration.' }
$config = $configJson | ConvertFrom-Json -Depth 40
$sourceDatabase = [string]$config.services.postgres.environment.POSTGRES_DB
$databaseUser = [string]$config.services.postgres.environment.POSTGRES_USER
if ($databaseUser -notmatch '^[A-Za-z][A-Za-z0-9_]{0,62}$') { throw 'Configured POSTGRES_USER is invalid.' }
if ($TargetDatabase -eq $sourceDatabase -and -not $AllowSourceDatabaseReplacement) {
    throw 'Refusing to replace the configured production database without -AllowSourceDatabaseReplacement.'
}

$containerId = (& $dockerPath compose --env-file $resolvedEnvFile -f $resolvedComposeFile ps -q postgres).Trim()
if ($LASTEXITCODE -ne 0 -or $containerId -notmatch '^[0-9a-f]{12,64}$') {
    throw 'The production PostgreSQL container is not running.'
}
$container = @(& $dockerPath inspect $containerId | ConvertFrom-Json -Depth 30)[0]
if ($container.State.Status -ne 'running' -or $container.State.Health.Status -ne 'healthy') {
    throw 'The production PostgreSQL container must be running and healthy.'
}

$existsOutput = & $dockerPath exec $containerId psql --username=$databaseUser --dbname=$sourceDatabase --tuples-only --no-align --command="SELECT 1 FROM pg_database WHERE datname = '$TargetDatabase'"
$exists = ($existsOutput -join "`n").Trim()
if ($exists -eq '1') {
    if (-not $ReplaceExistingTarget -or $Confirmation -cne "REPLACE:$TargetDatabase") {
        throw "Target database exists. Replacement requires -ReplaceExistingTarget -Confirmation 'REPLACE:$TargetDatabase'."
    }
    & $dockerPath exec $containerId dropdb --force --username=$databaseUser $TargetDatabase
    if ($LASTEXITCODE -ne 0) { throw 'Unable to drop the existing target database.' }
} elseif (-not $CreateTargetDatabase) {
    throw 'Target database does not exist. Use -CreateTargetDatabase to create it explicitly.'
}

& $dockerPath exec $containerId createdb --username=$databaseUser $TargetDatabase
if ($LASTEXITCODE -ne 0) { throw 'Unable to create the target database.' }

$containerPath = "/tmp/$([IO.Path]::GetFileName($resolvedBackupPath))"
try {
    & $dockerPath cp $resolvedBackupPath "${containerId}:$containerPath"
    if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the dump into the PostgreSQL container.' }
    & $dockerPath exec $containerId pg_restore --list $containerPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'pg_restore could not read the dump.' }
    & $dockerPath exec $containerId pg_restore --exit-on-error --no-owner --no-privileges --username=$databaseUser --dbname=$TargetDatabase $containerPath
    if ($LASTEXITCODE -ne 0) { throw 'pg_restore failed.' }
} catch {
    & $dockerPath exec $containerId dropdb --force --if-exists --username=$databaseUser $TargetDatabase 2>$null | Out-Null
    throw
} finally {
    & $dockerPath exec $containerId rm -f $containerPath 2>$null | Out-Null
}

$migrations = (& $dockerPath exec $containerId psql --username=$databaseUser --dbname=$TargetDatabase --tuples-only --no-align --command="SELECT string_agg(version, ',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success").Trim()
$tableCount = [int]((& $dockerPath exec $containerId psql --username=$databaseUser --dbname=$TargetDatabase --tuples-only --no-align --command="SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'").Trim())

[pscustomobject]@{
    status = 'RESTORED'
    sourceDatabase = [string]$manifest.database.name
    targetDatabase = $TargetDatabase
    backupSha256 = $actualHash
    flywayVersions = $migrations
    publicTableCount = $tableCount
} | ConvertTo-Json -Depth 5
