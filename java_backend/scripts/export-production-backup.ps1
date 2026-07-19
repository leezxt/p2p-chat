[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,

    [string]$ReceiptDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'target\production-backup-receipts'),

    [Parameter(Mandatory = $true)]
    [string]$StorageReferencePrefix
)

$ErrorActionPreference = 'Stop'

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)][IO.FileSystemInfo]$Item)
    return ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Assert-DirectChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullParent = [IO.Path]::GetFullPath($Parent).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if ([IO.Path]::GetDirectoryName($fullPath) -cne $fullParent) {
        throw "Refusing path outside the expected directory: $fullPath"
    }
    return $fullPath
}

function Copy-VerifiedFile {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        $existing = Get-Item -LiteralPath $DestinationPath
        if (-not $existing.PSIsContainer -and -not (Test-ReparsePoint -Item $existing)) {
            $existingHash = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($existingHash -ceq $ExpectedSha256) { return $true }
        }
        throw "Destination already exists with a different SHA-256: $DestinationPath"
    }

    $temporaryPath = "$DestinationPath.partial-$([Guid]::NewGuid().ToString('N'))"
    try {
        Copy-Item -LiteralPath $SourcePath -Destination $temporaryPath -ErrorAction Stop
        $temporary = Get-Item -LiteralPath $temporaryPath
        if ($temporary.PSIsContainer -or (Test-ReparsePoint -Item $temporary)) {
            throw 'Temporary export is not a regular file.'
        }
        $temporaryHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($temporaryHash -cne $ExpectedSha256) { throw 'Exported file SHA-256 verification failed.' }
        Move-Item -LiteralPath $temporaryPath -Destination $DestinationPath -ErrorAction Stop
        return $false
    } finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}

$resolvedBackupPath = (Resolve-Path -LiteralPath $BackupPath -ErrorAction Stop).Path
$backupFile = Get-Item -LiteralPath $resolvedBackupPath
if ($backupFile.PSIsContainer -or $backupFile.Extension -cne '.dump' -or (Test-ReparsePoint -Item $backupFile)) {
    throw 'BackupPath must be a regular .dump file and cannot be a reparse point.'
}

$manifestPath = "$resolvedBackupPath.manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Backup manifest is missing.' }
$manifestFile = Get-Item -LiteralPath $manifestPath
if (Test-ReparsePoint -Item $manifestFile) { throw 'Backup manifest cannot be a reparse point.' }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 20
if ([int]$manifest.schemaVersion -ne 1) { throw 'Backup manifest schemaVersion must be 1.' }
if ([string]$manifest.backup.fileName -cne $backupFile.Name) { throw 'Backup manifest fileName does not match.' }
if ([long]$manifest.backup.sizeBytes -ne $backupFile.Length) { throw 'Backup manifest size does not match.' }
if ([string]$manifest.backup.format -cne 'PostgreSQL custom' -or -not [bool]$manifest.verification.pgRestoreListPassed) {
    throw 'Backup manifest does not describe a verified PostgreSQL custom dump.'
}
$backupSha256 = (Get-FileHash -LiteralPath $resolvedBackupPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ([string]$manifest.backup.sha256 -cne $backupSha256) { throw 'Backup SHA-256 does not match its manifest.' }
$manifestSha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

$storagePrefixUri = $null
if (-not [Uri]::TryCreate($StorageReferencePrefix, [UriKind]::Absolute, [ref]$storagePrefixUri)) {
    throw 'StorageReferencePrefix must be an absolute URI.'
}
if (-not [string]::IsNullOrEmpty($storagePrefixUri.UserInfo) -or
    -not [string]::IsNullOrEmpty($storagePrefixUri.Query) -or
    -not [string]::IsNullOrEmpty($storagePrefixUri.Fragment)) {
    throw 'StorageReferencePrefix must not contain credentials, a query, or a fragment.'
}
$storageReference = "$($StorageReferencePrefix.TrimEnd('/'))/$([Uri]::EscapeDataString($backupFile.Name))"

$resolvedDestinationDirectory = (Resolve-Path -LiteralPath $DestinationDirectory -ErrorAction Stop).Path
$destinationDirectoryItem = Get-Item -LiteralPath $resolvedDestinationDirectory
if (-not $destinationDirectoryItem.PSIsContainer -or (Test-ReparsePoint -Item $destinationDirectoryItem)) {
    throw 'DestinationDirectory must be an existing regular directory.'
}
$sourceDirectory = [IO.Path]::GetDirectoryName($resolvedBackupPath).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
$destinationRoot = $resolvedDestinationDirectory.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
$sourcePrefix = $sourceDirectory + [IO.Path]::DirectorySeparatorChar
if ([string]::Equals($sourceDirectory, $destinationRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $destinationRoot.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'DestinationDirectory must be outside the local backup staging directory.'
}

New-Item -ItemType Directory -Path $ReceiptDirectory -Force | Out-Null
$resolvedReceiptDirectory = (Resolve-Path -LiteralPath $ReceiptDirectory).Path
$receiptDirectoryItem = Get-Item -LiteralPath $resolvedReceiptDirectory
if (-not $receiptDirectoryItem.PSIsContainer -or (Test-ReparsePoint -Item $receiptDirectoryItem)) {
    throw 'ReceiptDirectory must be a regular directory.'
}

$destinationBackupPath = Assert-DirectChildPath `
    -Path (Join-Path $resolvedDestinationDirectory $backupFile.Name) `
    -Parent $resolvedDestinationDirectory
$destinationManifestPath = Assert-DirectChildPath `
    -Path (Join-Path $resolvedDestinationDirectory $manifestFile.Name) `
    -Parent $resolvedDestinationDirectory
$receiptPath = Assert-DirectChildPath `
    -Path (Join-Path $resolvedReceiptDirectory "$($backupFile.Name).offhost-receipt.json") `
    -Parent $resolvedReceiptDirectory

$backupAlreadyPresent = Copy-VerifiedFile `
    -SourcePath $resolvedBackupPath `
    -DestinationPath $destinationBackupPath `
    -ExpectedSha256 $backupSha256
$manifestAlreadyPresent = Copy-VerifiedFile `
    -SourcePath $manifestPath `
    -DestinationPath $destinationManifestPath `
    -ExpectedSha256 $manifestSha256

$destinationBackupSha256 = (Get-FileHash -LiteralPath $destinationBackupPath -Algorithm SHA256).Hash.ToLowerInvariant()
$destinationManifestSha256 = (Get-FileHash -LiteralPath $destinationManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($destinationBackupSha256 -cne $backupSha256 -or $destinationManifestSha256 -cne $manifestSha256) {
    throw 'Destination verification failed after export.'
}

$receiptAlreadyPresent = $false
if (Test-Path -LiteralPath $receiptPath) {
    $receiptFile = Get-Item -LiteralPath $receiptPath
    if ($receiptFile.PSIsContainer -or (Test-ReparsePoint -Item $receiptFile)) {
        throw 'Existing off-host receipt is not a regular file.'
    }
    $existingReceipt = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json -Depth 10
    if ([int]$existingReceipt.schemaVersion -ne 2 -or
        [string]$existingReceipt.backupSha256 -cne $backupSha256 -or
        [string]$existingReceipt.manifestSha256 -cne $manifestSha256 -or
        [long]$existingReceipt.sizeBytes -ne $backupFile.Length -or
        [string]$existingReceipt.storageReference -cne $storageReference) {
        throw 'Existing off-host receipt does not match the verified export.'
    }
    $receiptAlreadyPresent = $true
} else {
    $receipt = [ordered]@{
        schemaVersion = 2
        backupSha256 = $backupSha256
        manifestSha256 = $manifestSha256
        sizeBytes = $backupFile.Length
        verifiedAt = [DateTimeOffset]::UtcNow.ToString('o')
        storageReference = $storageReference
    }
    $temporaryReceiptPath = "$receiptPath.partial-$([Guid]::NewGuid().ToString('N'))"
    try {
        $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporaryReceiptPath -Encoding utf8NoBOM
        Move-Item -LiteralPath $temporaryReceiptPath -Destination $receiptPath -ErrorAction Stop
    } finally {
        Remove-Item -LiteralPath $temporaryReceiptPath -Force -ErrorAction SilentlyContinue
    }
}

[pscustomobject]@{
    status = 'EXPORTED'
    backupFileName = $backupFile.Name
    backupSha256 = $backupSha256
    manifestSha256 = $manifestSha256
    sizeBytes = $backupFile.Length
    storageReference = $storageReference
    receiptPath = $receiptPath
    idempotent = $backupAlreadyPresent -and $manifestAlreadyPresent -and $receiptAlreadyPresent
} | ConvertTo-Json -Depth 5
