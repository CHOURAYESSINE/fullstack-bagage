param([switch]$Internet)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$node='C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
if(!(Test-Path $node)){$node=(Get-Command node -ErrorAction Stop).Source}
# Ordre requis : déploiement déjà prêt -> réseau -> métier -> sauvegarde -> durcissement.
./scripts/Test-Phase04.ps1
./scripts/Test-FinalBusiness.ps1
./scripts/Test-BackupRestore.ps1
./scripts/Test-FinalInfrastructure.ps1
if($Internet){
 try {
  ./scripts/Start-InternetDemo.ps1
  & $node scripts/Test-Internet.cjs
  if($LASTEXITCODE){throw 'Validation URL Internet échouée'}
 } finally {./scripts/Stop-InternetDemo.ps1}
}
Write-Host 'Recette automatique terminée. Windows/VMware et navigateur : preuves séparées, voir AVANCEMENT.md.'
