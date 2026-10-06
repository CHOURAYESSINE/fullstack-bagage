param([string]$DockerContext = 'desktop-linux')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Read-Counts {
    $counts = docker --context $DockerContext compose exec -T db psql -U bagage_owner -d bagage -tAc 'SELECT (SELECT count(*) FROM bagages), (SELECT count(*) FROM historique_statuts);'
    if ($LASTEXITCODE -ne 0) { throw 'Lecture des compteurs impossible.' }
    return ($counts -join '').Trim()
}
$urls = Get-Content docs/preuves/phase-01-docker-capture-urls.json -Raw | ConvertFrom-Json
$before = Read-Counts
if ($before -notmatch '^[1-9][0-9]*\|[1-9][0-9]*$') { throw 'Exécuter les tests fonctionnels Docker avant ce test.' }
docker --context $DockerContext compose stop api db
if ($LASTEXITCODE -ne 0) { throw 'Arrêt des conteneurs impossible.' }
docker --context $DockerContext compose up -d --wait --wait-timeout 120 db api
if ($LASTEXITCODE -ne 0) { throw 'Redémarrage des conteneurs impossible.' }
$after = Read-Counts
if ($before -ne $after) { throw 'Les compteurs diffèrent après le redémarrage.' }
$response = Invoke-RestMethod $urls.trackingUrl -TimeoutSec 15
if ($response.statut -ne 'livre' -or $response.historique.Count -ne 5) { throw 'Historique de démonstration non retrouvé.' }
@(
    "Test persistance Docker - $([DateTime]::UtcNow.ToString('o'))",
    "Avant (bagages|historique) : $before",
    "Apres (bagages|historique) : $after",
    'OK - Compteurs conserves apres arret et redemarrage des conteneurs.',
    'OK - Tracking public livre et cinq etapes retrouves dans PostgreSQL.'
) | Tee-Object docs/preuves/phase-01-docker-persistance.txt
