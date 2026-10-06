param([string]$PgBin = 'C:\Program Files\PostgreSQL\16\bin')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $root 'back/Bagage.Api/bin/Debug/net8.0/Bagage.Api.exe'
Get-CimInstance Win32_Process -Filter "name='Bagage.Api.exe'" |
    Where-Object { $_.ExecutablePath -eq $exe } | ForEach-Object { Stop-Process -Id $_.ProcessId }
$data = Join-Path $root 'work/pgdata'
if (Test-Path (Join-Path $data 'postmaster.pid')) {
    & "$PgBin\pg_ctl.exe" -D $data -m fast -w stop
    if ($LASTEXITCODE -ne 0) { throw 'Arrêt PostgreSQL incomplet.' }
}
Write-Host 'Services du projet arrêtés ; données conservées.'
