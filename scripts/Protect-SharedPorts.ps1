$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
try {
    if(!(Get-NetFirewallRule -Name BagageSharedPortsBlock -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name BagageSharedPortsBlock -DisplayName 'Bagage : fermer les ports partages au reseau' -Direction Inbound -Action Block -Protocol TCP -LocalPort 80,5432,8080,5005 -Profile Any | Out-Null
    }
    $rule=Get-NetFirewallRule -Name BagageSharedPortsBlock
    if($rule.Enabled -ne 'True' -or $rule.Action -ne 'Block'){throw 'Regle de blocage non active'}
    @{succes=$true;ports=@(80,5432,8080,5005);profil='Any';action='Block'} | ConvertTo-Json | Set-Content (Join-Path $root 'work/phase-04/shared-ports-status.json')
} catch {
    @{succes=$false;erreur=$_.Exception.Message} | ConvertTo-Json | Set-Content (Join-Path $root 'work/phase-04/shared-ports-status.json')
    throw
}
