$ErrorActionPreference = 'Stop'
$exportScript = Join-Path $PSScriptRoot 'export-production-backup.ps1'
$pruneScript = Join-Path $PSScriptRoot 'prune-production-backups.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "p2p-chat-offhost-$([Guid]::NewGuid().ToString('N'))"
$backupDirectory = Join-Path $testRoot 'backups'
$destinationDirectory = Join-Path $testRoot 'mounted-offhost'
$receiptDirectory = Join-Path $testRoot 'receipts'
$referenceTime = [DateTimeOffset]::UtcNow

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern, [string]$Message)

    $matched = $false
    try { & $Action | Out-Null } catch { $matched = $_.Exception.Message -match $Pattern }
    Assert-True $matched $Message
}

function New-BackupFixture {
    param([string]$Name, [DateTimeOffset]$GeneratedAt)

    $dumpPath = Join-Path $backupDirectory "$Name.dump"
    [IO.File]::WriteAllBytes($dumpPath, [Text.Encoding]::UTF8.GetBytes("fixture-$Name"))
    $hash = (Get-FileHash -LiteralPath $dumpPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [ordered]@{
        schemaVersion = 1
        generatedAt = $GeneratedAt.ToUniversalTime().ToString('o')
        database = [ordered]@{ name = 'p2p_chat'; postgresToolVersion = 'fixture' }
        backup = [ordered]@{
            fileName = [IO.Path]::GetFileName($dumpPath)
            sizeBytes = (Get-Item -LiteralPath $dumpPath).Length
            sha256 = $hash
            format = 'PostgreSQL custom'
        }
        verification = [ordered]@{ pgRestoreListPassed = $true }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$dumpPath.manifest.json" -Encoding utf8NoBOM
    return $dumpPath
}

try {
    New-Item -ItemType Directory -Path $backupDirectory, $destinationDirectory, $receiptDirectory | Out-Null
    $oldBackup = New-BackupFixture -Name 'old-verified' -GeneratedAt $referenceTime.AddDays(-60)
    $recentBackup = New-BackupFixture -Name 'recent-local' -GeneratedAt $referenceTime.AddDays(-1)

    $first = & $exportScript `
        -BackupPath $oldBackup `
        -DestinationDirectory $destinationDirectory `
        -ReceiptDirectory $receiptDirectory `
        -StorageReferencePrefix 's3://backup-vault/p2p-chat' | ConvertFrom-Json
    Assert-True ($first.status -eq 'EXPORTED') 'First export did not return EXPORTED.'
    Assert-True (-not $first.idempotent) 'First export was incorrectly reported as idempotent.'
    Assert-True ($first.storageReference -eq 's3://backup-vault/p2p-chat/old-verified.dump') 'Storage reference is incorrect.'

    $destinationBackup = Join-Path $destinationDirectory 'old-verified.dump'
    $destinationManifest = "$destinationBackup.manifest.json"
    $receiptPath = Join-Path $receiptDirectory 'old-verified.dump.offhost-receipt.json'
    Assert-True (Test-Path -LiteralPath $destinationBackup) 'Destination dump is missing.'
    Assert-True (Test-Path -LiteralPath $destinationManifest) 'Destination manifest is missing.'
    Assert-True (Test-Path -LiteralPath $receiptPath) 'Off-host receipt is missing.'
    Assert-True (
        (Get-FileHash -LiteralPath $oldBackup -Algorithm SHA256).Hash -ceq
        (Get-FileHash -LiteralPath $destinationBackup -Algorithm SHA256).Hash
    ) 'Destination dump hash differs from the source.'

    $receipt = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json
    Assert-True ($receipt.schemaVersion -eq 2) 'Receipt schemaVersion is incorrect.'
    Assert-True ($receipt.backupSha256 -ceq $first.backupSha256) 'Receipt backup hash is incorrect.'
    Assert-True ($receipt.manifestSha256 -ceq $first.manifestSha256) 'Receipt manifest hash is incorrect.'

    $second = & $exportScript `
        -BackupPath $oldBackup `
        -DestinationDirectory $destinationDirectory `
        -ReceiptDirectory $receiptDirectory `
        -StorageReferencePrefix 's3://backup-vault/p2p-chat' | ConvertFrom-Json
    Assert-True $second.idempotent 'Repeated export was not idempotent.'

    $plan = & $pruneScript `
        -BackupDirectory $backupDirectory `
        -OffHostReceiptDirectory $receiptDirectory `
        -MaxAgeDays 30 `
        -MinimumBackups 1 `
        -ReferenceTimeUtc $referenceTime | ConvertFrom-Json
    Assert-True ($plan.candidates.Count -eq 1) 'Retention did not select exactly one exported old backup.'
    Assert-True ($plan.candidates -contains 'old-verified.dump') 'Retention did not accept the generated receipt.'
    Assert-True (Test-Path -LiteralPath $oldBackup) 'Retention dry-run deleted the local backup.'
    Assert-True (Test-Path -LiteralPath $recentBackup) 'Retention dry-run deleted the recent backup.'

    $oldManifestPath = "$oldBackup.manifest.json"
    $oldManifest = Get-Content -Raw -LiteralPath $oldManifestPath | ConvertFrom-Json -Depth 10
    $oldManifest.generatedAt = $referenceTime.AddDays(-90).ToString('o')
    $oldManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $oldManifestPath -Encoding utf8NoBOM
    $tamperedManifestPlan = & $pruneScript `
        -BackupDirectory $backupDirectory `
        -OffHostReceiptDirectory $receiptDirectory `
        -MaxAgeDays 30 `
        -MinimumBackups 1 `
        -ReferenceTimeUtc $referenceTime | ConvertFrom-Json
    Assert-True ($tamperedManifestPlan.candidates.Count -eq 0) 'Manifest changed after export remained eligible.'
    Assert-True (
        @($tamperedManifestPlan.protected | Where-Object { $_.fileName -eq 'old-verified.dump' }).Count -eq 1
    ) 'Manifest changed after export was not protected.'

    $applyBackup = New-BackupFixture -Name 'apply-verified' -GeneratedAt $referenceTime.AddDays(-45)
    & $exportScript `
        -BackupPath $applyBackup `
        -DestinationDirectory $destinationDirectory `
        -ReceiptDirectory $receiptDirectory `
        -StorageReferencePrefix 's3://backup-vault/p2p-chat' | Out-Null
    $applied = & $pruneScript `
        -BackupDirectory $backupDirectory `
        -OffHostReceiptDirectory $receiptDirectory `
        -MaxAgeDays 30 `
        -MinimumBackups 1 `
        -ReferenceTimeUtc $referenceTime `
        -Apply `
        -Confirmation 'DELETE-VERIFIED-LOCAL-BACKUPS' | ConvertFrom-Json
    Assert-True ($applied.deleted.Count -eq 1) 'Schema 2 Apply did not delete exactly one eligible backup.'
    Assert-True ($applied.deleted -contains 'apply-verified.dump') 'Schema 2 Apply deleted the wrong backup.'
    Assert-True (-not (Test-Path -LiteralPath $applyBackup)) 'Schema 2 Apply retained the local dump.'
    Assert-True (Test-Path -LiteralPath (Join-Path $destinationDirectory 'apply-verified.dump')) 'Apply deleted the off-host dump.'

    $tampered = New-BackupFixture -Name 'tampered' -GeneratedAt $referenceTime.AddDays(-10)
    Add-Content -LiteralPath $tampered -Value 'tampered'
    Assert-Throws -Action {
        & $exportScript `
            -BackupPath $tampered `
            -DestinationDirectory $destinationDirectory `
            -ReceiptDirectory $receiptDirectory `
            -StorageReferencePrefix 's3://backup-vault/p2p-chat'
    } -Pattern 'size|SHA-256' -Message 'Tampered source backup was not rejected.'

    $collision = New-BackupFixture -Name 'collision' -GeneratedAt $referenceTime.AddDays(-10)
    Set-Content -LiteralPath (Join-Path $destinationDirectory 'collision.dump') -Value 'different' -Encoding utf8NoBOM
    Assert-Throws -Action {
        & $exportScript `
            -BackupPath $collision `
            -DestinationDirectory $destinationDirectory `
            -ReceiptDirectory $receiptDirectory `
            -StorageReferencePrefix 's3://backup-vault/p2p-chat'
    } -Pattern 'different SHA-256' -Message 'Destination collision was not rejected.'

    $queryBackup = New-BackupFixture -Name 'query-secret' -GeneratedAt $referenceTime.AddDays(-10)
    Assert-Throws -Action {
        & $exportScript `
            -BackupPath $queryBackup `
            -DestinationDirectory $destinationDirectory `
            -ReceiptDirectory $receiptDirectory `
            -StorageReferencePrefix 's3://backup-vault/p2p-chat?token=secret'
    } -Pattern 'must not contain' -Message 'Credential-like storage reference was not rejected.'

    [pscustomobject]@{
        status = 'PASS'
        exported = 1
        idempotent = $true
        retentionCompatible = $true
        manifestBindingVerified = $true
        schema2ApplyVerified = $true
        tamperedSourceRejected = $true
        destinationCollisionRejected = $true
        credentialReferenceRejected = $true
    } | ConvertTo-Json -Depth 5
} finally {
    $fullTestRoot = [IO.Path]::GetFullPath($testRoot)
    $fullTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($fullTestRoot.StartsWith($fullTemp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($fullTestRoot) -match '^p2p-chat-offhost-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $fullTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
