$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
Get-Content infra/kubernetes/recette.py -Raw | docker compose -f docker-compose.kube-validation.yml exec -T vpn-client python -
if($LASTEXITCODE -ne 0){throw 'Recette métier échouée'}
$result=Get-Content docs/preuves/recette-metier.json -Raw | ConvertFrom-Json
@("Recette métier Kubernetes - $($result.dateUtc)")+@($result.checks | ForEach-Object {"$($_.resultat) - $($_.test)"}) | Set-Content docs/preuves/recette-metier.txt
