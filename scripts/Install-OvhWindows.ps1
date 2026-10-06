$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$status=Join-Path (Get-Location) 'work/phase-05/windows-status.json'
try {
    $folder=Join-Path $env:ProgramData 'BagageOvhWireGuard'
    New-Item -ItemType Directory -Force $folder | Out-Null
    & icacls $folder /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' | Out-Null
    if($LASTEXITCODE -ne 0){throw 'ACL du profil VPN impossible'}
    Copy-Item work/phase-05/wireguard/windows.conf "$folder/bagage-ovh.conf" -Force
    $service='WireGuardTunnel$bagage-ovh'
    $old=Get-Service 'WireGuardTunnel$bagage-kube' -ErrorAction SilentlyContinue
    if($old -and $old.Status -eq 'Running'){Stop-Service $old.Name}
    if(!(Get-Service $service -ErrorAction SilentlyContinue)){
        & 'C:\Program Files\WireGuard\wireguard.exe' /installtunnelservice "$folder/bagage-ovh.conf"
        if($LASTEXITCODE -ne 0){throw 'Installation du tunnel OVH impossible'}
    }
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    while(!(Get-Service $service -ErrorAction SilentlyContinue)){
        if([DateTime]::UtcNow -gt $deadline){throw 'Service VPN OVH indisponible après installation'}
        Start-Sleep -Milliseconds 500
    }
    Set-Service $service -StartupType Manual
    Start-Service $service
    $certificate=Import-Certificate -FilePath work/phase-05/pki/ca.crt -CertStoreLocation Cert:\CurrentUser\Root
    @{etat='reussi';service=$service;certificat=$certificate.Thumbprint;dateUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content $status
} catch {
    @{etat='echec';erreur=$_.Exception.Message} | ConvertTo-Json | Set-Content $status
    exit 1
}
