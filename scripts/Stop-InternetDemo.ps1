$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$binary=Join-Path (Get-Location) work/tools/cloudflared.exe
if(Test-Path work/phase-04/cloudflared.pid){
 $p=Get-Process -Id ([int](Get-Content work/phase-04/cloudflared.pid)) -ErrorAction SilentlyContinue
 if($p){if($p.Path -ne $binary){throw 'PID réutilisé par un autre processus ; arrêt refusé'};Stop-Process -Id $p.Id}
 Remove-Item -LiteralPath work/phase-04/cloudflared.pid
}
@{dateUtc=[DateTime]::UtcNow.ToString('o');tunnelPublicTemporaireArrete=$true;portPublicHoteAjoute=$false} | ConvertTo-Json | Set-Content docs/preuves/recette-internet-nettoyage.json
