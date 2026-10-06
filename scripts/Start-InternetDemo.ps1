$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$root=(Get-Location).Path
$binary=Join-Path $root work/tools/cloudflared.exe
if(!(Test-Path $binary)){throw 'cloudflared officiel vérifié requis ; voir recette-cloudflared.json'}
$proof=Get-Content docs/preuves/recette-cloudflared.json -Raw | ConvertFrom-Json
if((Get-FileHash $binary).Hash.ToLowerInvariant() -ne $proof.sha256){throw 'Empreinte cloudflared incorrecte'}
if(Test-Path work/phase-04/cloudflared.pid){
 $existing=Get-Process -Id ([int](Get-Content work/phase-04/cloudflared.pid)) -ErrorAction SilentlyContinue
 if($existing -and $existing.Path -eq $binary){throw 'Tunnel déjà actif'}
}
$ca=Join-Path $root work/phase-04/pki/ca.crt
$p=Start-Process -FilePath $binary -WindowStyle Hidden -ArgumentList @('tunnel','--url','https://localhost:15443','--origin-ca-pool',('"'+$ca+'"'),'--origin-server-name','localhost','--http-host-header','localhost','--protocol','http2','--no-autoupdate') -PassThru -RedirectStandardOutput work/phase-04/cloudflared-out.log -RedirectStandardError work/phase-04/cloudflared.log
$p.Id | Set-Content work/phase-04/cloudflared.pid
for($i=0;$i -lt 30;$i++){
 Start-Sleep -Seconds 2
 $log=Get-Content work/phase-04/cloudflared.log -Raw -ErrorAction SilentlyContinue
 $url=[regex]::Match($log,'https://[a-z-]+\.trycloudflare\.com').Value
 if($url -and $log -match 'Registered tunnel connection'){
  $demo=Get-Content docs/preuves/phase-04-demo.json -Raw | ConvertFrom-Json
  @{url=$url;trackingId=$demo.trackingId} | ConvertTo-Json | Set-Content work/phase-04/internet-target.json
  Write-Host "Site public temporaire : $url"
  return
 }
}
throw 'Tunnel non prêt ; consulter les logs privés puis Stop-InternetDemo.ps1'
