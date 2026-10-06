param([switch]$Documentation)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$s = Get-Content work/local-secrets.json -Raw | ConvertFrom-Json
$env:ConnectionStrings__Bagage = "Host=127.0.0.1;Port=55432;Database=bagage;Username=bagage_app;Password=$($s.AppPassword)"
$env:Jwt__Key = $s.JwtKey
$env:ASPNETCORE_ENVIRONMENT = if ($Documentation) { 'Development' } else { 'Production' }
try {
    dotnet run --project back/Bagage.Api --no-launch-profile --urls http://127.0.0.1:5080
    if ($LASTEXITCODE -ne 0) { throw 'API arrêtée avec une erreur.' }
} finally {
    'ConnectionStrings__Bagage','Jwt__Key','ASPNETCORE_ENVIRONMENT' | ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
}
