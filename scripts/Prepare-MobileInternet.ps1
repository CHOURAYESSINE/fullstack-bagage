# À lire puis lancer manuellement dans PowerShell administrateur.
# Réglages temporaires limités au test WireGuard Internet autorisé.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$mobile=(Get-Content (Join-Path $root 'work/phase-04/mobile-public-ip.txt') -Raw).Trim()
$parsed=$null
if(![Net.IPAddress]::TryParse($mobile,[ref]$parsed) -or $parsed.AddressFamily -ne 'InterNetwork'){throw 'Adresse mobile IPv4 invalide'}
if(!(Get-NetFirewallRule -Name BagageMobileInternetUdp -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name BagageMobileInternetUdp -DisplayName 'Bagage : test UDP mobile temporaire' -Direction Inbound -Action Allow -Protocol UDP -LocalAddress 192.168.1.123 -LocalPort 52820 -Profile Any | Out-Null
}
if(!(Get-NetRoute -DestinationPrefix ($mobile+'/32') -InterfaceAlias 'Wi-Fi' -ErrorAction SilentlyContinue)) {
    New-NetRoute -DestinationPrefix ($mobile+'/32') -InterfaceAlias 'Wi-Fi' -NextHop 192.168.1.1 -PolicyStore ActiveStore | Out-Null
}
'OK' | Set-Content (Join-Path $root 'work/phase-04/vm-scan/udp-admin-status.txt')
Write-Host 'Entree UDP et route temporaire preparees.'
