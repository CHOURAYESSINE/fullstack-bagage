param([string]$DockerContext = 'desktop-linux')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (!(Test-Path .env)) {
    $owner = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $appPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $jwt = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
    $bootstrap = 'Aa1!' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    @("POSTGRES_PASSWORD=$owner", "BAGAGE_APP_PASSWORD=$appPassword", "JWT_KEY=$jwt", 'BOOTSTRAP_LOGIN=admin.local', "BOOTSTRAP_PASSWORD=$bootstrap") | Set-Content .env
    & icacls .env /inheritance:r /grant:r "${env:USERNAME}:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Restriction des permissions .env impossible.' }
}
docker --context $DockerContext compose up -d --wait --wait-timeout 120 db
if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL Docker indisponible.' }
docker --context $DockerContext compose --profile tools run --build --rm migrate
if ($LASTEXITCODE -ne 0) { throw 'Migration Docker impossible.' }
docker --context $DockerContext compose exec -T db psql -U bagage_owner -d bagage -v ON_ERROR_STOP=1 -f /setup/permissions.sql
if ($LASTEXITCODE -ne 0) { throw 'Permissions Docker impossibles.' }
$admin = docker --context $DockerContext compose exec -T db psql -U bagage_owner -d bagage -tAc 'SELECT 1 FROM users WHERE "Role"=''Administrateur'' LIMIT 1'
if ($LASTEXITCODE -ne 0) { throw 'Lecture administrateur impossible.' }
if ($admin -ne '1') {
    docker --context $DockerContext compose --profile tools run --rm migrate --bootstrap-admin
    if ($LASTEXITCODE -ne 0) { throw 'Initialisation administrateur Docker impossible.' }
}
docker --context $DockerContext compose up -d --build --wait --wait-timeout 120 api
if ($LASTEXITCODE -ne 0) { throw 'Démarrage API Docker impossible.' }
