$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$kc=@('--kubeconfig','work/phase-04/kubeconfig.yaml','--context','k3d-bagage','-n','bagage')
Get-Content infra/kubernetes/test_restore.sh -Raw | kubectl @kc exec -i db-0 -- sh -c 'tr -d "\r" > /tmp/test_restore.sh; sh /tmp/test_restore.sh' | Tee-Object docs/preuves/recette-restauration.txt
if($LASTEXITCODE -ne 0){throw 'Restauration de sauvegarde échouée'}
New-Item -ItemType Directory -Force work/phase-04/backups | Out-Null
kubectl @kc cp db-0:/tmp/bagage-recette.dump work/phase-04/backups/bagage-recette.dump
if($LASTEXITCODE -ne 0){throw 'Export privé de la sauvegarde échoué'}
$file=Get-Item work/phase-04/backups/bagage-recette.dump
@{dateUtc=[DateTime]::UtcNow.ToString('o');octets=$file.Length;sha256=(Get-FileHash $file.FullName).Hash;restauration='Base temporaire distincte dans PostgreSQL Kubernetes';donneesActivesRemplacees=$false} | ConvertTo-Json | Set-Content docs/preuves/recette-sauvegarde.json
kubectl @kc exec db-0 -- rm -f /tmp/bagage-recette.dump /tmp/test_restore.sh
