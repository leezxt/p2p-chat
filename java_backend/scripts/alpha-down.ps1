$ErrorActionPreference = 'Stop'

$env:POSTGRES_PASSWORD = 'p2p-alpha-db-local-only'
$env:JWT_SECRET = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes('p2p-alpha-jwt-local-only-32-bytes-minimum')
)
$env:PUSH_TOKEN_ENCRYPTION_KEYS = 'alpha-v1=' + [Convert]::ToBase64String([byte[]](0..31))
$env:LOCAL_DEV_AUTH_KEY = 'p2p-alpha-local-only'

docker compose down
