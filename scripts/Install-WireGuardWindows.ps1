$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Ouvrir PowerShell avec les droits administrateur pour installer le pilote et le service VPN.'}
$msi=Join-Path (Get-Location) 'work/phase-04/windows/wireguard-amd64-1.1.1.msi'
$sig=Get-AuthenticodeSignature $msi
if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'WireGuard'){throw 'Signature installateur WireGuard incorrecte.'}
$folder=Join-Path $env:ProgramData 'BagageLabWireGuard'
New-Item -ItemType Directory -Force $folder | Out-Null
& icacls $folder /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' | Out-Null
if($LASTEXITCODE -ne 0){throw 'ACL du tunnel impossible.'}
# Windows Installer exécute aussi sous SYSTEM : il ne peut pas lire le dossier
# work limité au compte utilisateur. Le package signé est copié dans ce dossier protégé.
$stagedMsi=Join-Path $folder 'wireguard-amd64-1.1.1.msi'
Copy-Item -LiteralPath $msi -Destination $stagedMsi -Force
$wireguard='C:\Program Files\WireGuard\wireguard.exe'
if(!(Test-Path $wireguard)){
    $p=Start-Process msiexec.exe -ArgumentList @('/i',('"'+$stagedMsi+'"'),'/qn','/norestart','DO_NOT_LAUNCH=1') -WindowStyle Hidden -Wait -PassThru
    if($p.ExitCode -notin @(0,3010)){throw "Installation WireGuard échouée : $($p.ExitCode)"}
}
Copy-Item work/phase-04/wireguard/windows.conf "$folder/bagage-kube.conf" -Force
$service='WireGuardTunnel$bagage-kube'
if(!(Get-Service -Name $service -ErrorAction SilentlyContinue)){
    & $wireguard /installtunnelservice "$folder/bagage-kube.conf"
    if($LASTEXITCODE -ne 0){throw 'Création du service VPN impossible.'}
}
$deadline=[DateTime]::UtcNow.AddSeconds(30)
while(!(Get-Service -Name $service -ErrorAction SilentlyContinue)){
    if([DateTime]::UtcNow -gt $deadline){throw 'Service VPN non disponible après installation.'}
    Start-Sleep -Milliseconds 500
}
Set-Service -Name $service -StartupType Manual
Stop-Service -Name $service -ErrorAction Stop
Write-Host 'WireGuard installé ; tunnel bagage-kube préparé et arrêté. Aucun certificat ajouté au magasin Windows.'
Write-Host 'Exécuter maintenant ./scripts/Test-WindowsNative.ps1 dans cette même fenêtre administrateur.'
