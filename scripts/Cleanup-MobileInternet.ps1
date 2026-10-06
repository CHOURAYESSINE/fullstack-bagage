$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$mobile=(Get-Content (Join-Path $root 'work/phase-04/mobile-public-ip.txt') -Raw).Trim()
Get-NetFirewallRule -Name BagageMobileInternetUdp -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Get-NetRoute -DestinationPrefix ($mobile+'/32') -InterfaceAlias 'Wi-Fi' -NextHop 192.168.1.1 -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false
'OK' | Set-Content (Join-Path $root 'work/phase-04/vm-scan/cleanup-status.txt')
