param([string]$DockerContext = 'desktop-linux')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (!(Test-Path .env)) { throw 'Initialiser la phase 1 avec Initialize-Docker.ps1.' }
docker --context $DockerContext compose up -d --build --wait --wait-timeout 180 public agents
if ($LASTEXITCODE -ne 0) { throw 'Démarrage des interfaces impossible.' }
Write-Host 'Passagers : http://127.0.0.1:14200'
Write-Host 'Agents : http://127.0.0.1:14201'
