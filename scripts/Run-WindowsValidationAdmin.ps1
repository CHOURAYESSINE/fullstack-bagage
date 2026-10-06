$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$statusFile=Join-Path (Get-Location) 'work/phase-04/windows/admin-status.json'
try {
    @{etat='en_cours';dateUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content $statusFile
    & ./scripts/Install-WireGuardWindows.ps1 *> work/phase-04/windows/admin-install.log
    & ./scripts/Test-WindowsNative.ps1 *> work/phase-04/windows/admin-test.log
    @{etat='reussi';dateUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content $statusFile
} catch {
    @{etat='echec';dateUtc=[DateTime]::UtcNow.ToString('o');erreur=$_.Exception.Message} | ConvertTo-Json | Set-Content $statusFile
    exit 1
}
