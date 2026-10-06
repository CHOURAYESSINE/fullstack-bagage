param([switch]$PublicOnly)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$node='C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
if(!(Test-Path $node)){$node=(Get-Command node -ErrorAction Stop).Source}
function Probe($Mode){
    & $node scripts/Probe-Windows.cjs $Mode | Tee-Object "docs/preuves/phase-04-windows-$Mode.txt"
    if($LASTEXITCODE -ne 0){throw "Validation Windows $Mode échouée."}
}
Probe public
if($PublicOnly){return}
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Administrateur requis pour arrêter et rétablir le tunnel pendant la validation.'}
$service='WireGuardTunnel$bagage-kube'
$initial=(Get-Service -Name $service -ErrorAction Stop).Status
try{
    Start-Service $service
    Start-Sleep -Seconds 4
    Probe vpn
    $handshakes=& 'C:\Program Files\WireGuard\wg.exe' show bagage-kube latest-handshakes
    if($LASTEXITCODE -ne 0 -or !($handshakes -match '\s[1-9][0-9]*$')){throw 'Handshake Windows non confirmé.'}
    'OK - Handshake WireGuard Windows non nul ; cles masquees.' | Set-Content docs/preuves/phase-04-windows-handshake.txt
    Stop-Service $service
    Start-Sleep -Seconds 2
    if(Get-NetRoute -DestinationPrefix '10.77.0.1/32' -ErrorAction SilentlyContinue){throw 'La route VPN reste presente après arrêt.'}
    'OK - Route privee WireGuard retiree de Windows apres coupure.' | Set-Content docs/preuves/phase-04-windows-route.txt
    Probe off
    Start-Service $service
    Start-Sleep -Seconds 3
    Probe restored
}finally{
    Remove-Item -LiteralPath work/phase-04/windows/jwt -ErrorAction SilentlyContinue
    if($initial -eq 'Running'){Start-Service $service}else{Stop-Service $service -ErrorAction SilentlyContinue}
}
