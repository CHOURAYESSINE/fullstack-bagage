param([string]$DockerContext='desktop-linux')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (!(Test-Path .env)) { throw 'Initialiser la phase 1 avant le laboratoire réseau.' }
$secretRoot=Join-Path (Get-Location) 'work/phase-03'
New-Item -ItemType Directory -Force $secretRoot | Out-Null
& icacls $secretRoot /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)(F)" | Out-Null
if($LASTEXITCODE -ne 0){throw 'Restriction des droits des secrets impossible.'}
docker --context $DockerContext build -t fullstack-bagage-network-tools infra/network
if($LASTEXITCODE -ne 0){throw 'Construction des outils réseau impossible.'}
docker --context $DockerContext run --rm --mount "type=bind,source=$secretRoot,target=/secrets" fullstack-bagage-network-tools /lab/init-secrets.sh
if($LASTEXITCODE -ne 0){throw 'Initialisation des secrets réseau impossible.'}
. ./scripts/Test-Helpers.ps1
$credentials=Get-TestCredentials Docker
@{login=$credentials.AdminLogin;password=$credentials.AdminPassword} | ConvertTo-Json | Set-Content work/phase-03/login/admin.json
docker --context $DockerContext compose -f docker-compose.yml -f docker-compose.secure.yml --profile validation up -d --wait --wait-timeout 180
if($LASTEXITCODE -ne 0){throw 'Laboratoire réseau incomplet.'}
Write-Host 'HTTPS public : https://localhost:14443 (CA locale à approuver explicitement dans le navigateur).'
Write-Host 'HTTPS agents : https://10.77.0.1:8443 (VPN obligatoire).'
Write-Host 'Tests : ./scripts/Test-Phase03.ps1'
