param([string]$PgBin = 'C:\Program Files\PostgreSQL\16\bin')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
New-Item -ItemType Directory -Force work | Out-Null
$secretPath = Join-Path $root 'work/local-secrets.json'
if (!(Test-Path $secretPath)) {
    $secrets = @{
        OwnerPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        AppPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        JwtKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
        AdminLogin = 'admin.local'
        AdminPassword = 'Aa1!' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    }
    $secrets | ConvertTo-Json | Set-Content $secretPath
    # Secrets de développement uniquement, exclus de Git. Ne pas les capturer.
    & icacls $secretPath /inheritance:r /grant:r "${env:USERNAME}:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Impossible de restreindre les permissions des secrets.' }
}
$s = Get-Content $secretPath -Raw | ConvertFrom-Json
$data = Join-Path $root 'work/pgdata'
if (!(Test-Path (Join-Path $data 'PG_VERSION'))) {
    $pwfile = Join-Path $root 'work/initdb-password.tmp'
    try {
        [IO.File]::WriteAllText($pwfile, $s.OwnerPassword)
        & "$PgBin\initdb.exe" -D $data -U bagage_owner --auth=scram-sha-256 --encoding=UTF8 --locale=C --pwfile=$pwfile
        if ($LASTEXITCODE -ne 0) { throw 'initdb a échoué.' }
        Add-Content (Join-Path $data 'postgresql.conf') "`nlisten_addresses = '127.0.0.1'`nport = 55432"
    } finally { Remove-Item -LiteralPath $pwfile -ErrorAction SilentlyContinue }
}
& "$PgBin\pg_ctl.exe" -D $data status *> $null
if ($LASTEXITCODE -ne 0) {
    $pgStart = Start-Process -FilePath "$PgBin\pg_ctl.exe" -ArgumentList @('-D', ('"' + $data + '"'), '-l', ('"' + (Join-Path $root 'work/postgres.log') + '"'), '-w', 'start') -WindowStyle Hidden -PassThru
    if (!$pgStart.WaitForExit(30000)) { throw 'PostgreSQL ne termine pas son démarrage dans les 30 secondes.' }
    if ($pgStart.ExitCode -ne 0) { throw 'Démarrage PostgreSQL impossible (port 55432 disponible ?).' }
}
$env:PGPASSWORD = $s.OwnerPassword
try {
    $exists = & "$PgBin\psql.exe" -h 127.0.0.1 -p 55432 -U bagage_owner -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='bagage'"
    if ($LASTEXITCODE -ne 0) { throw 'Connexion PostgreSQL impossible.' }
    if ($exists -ne '1') {
        & "$PgBin\createdb.exe" -h 127.0.0.1 -p 55432 -U bagage_owner bagage
        if ($LASTEXITCODE -ne 0) { throw 'Création de la base impossible.' }
    }
    $role = & "$PgBin\psql.exe" -h 127.0.0.1 -p 55432 -U bagage_owner -d bagage -tAc "SELECT 1 FROM pg_roles WHERE rolname='bagage_app'"
    if ($LASTEXITCODE -ne 0) { throw 'Lecture des rôles impossible.' }
    if ($role -ne '1') {
        # Mot de passe généré exclusivement en hexadécimal, pas une entrée utilisateur.
        "CREATE ROLE bagage_app LOGIN PASSWORD '$($s.AppPassword)' NOSUPERUSER NOCREATEDB NOCREATEROLE;" |
            & "$PgBin\psql.exe" -h 127.0.0.1 -p 55432 -U bagage_owner -d bagage -v ON_ERROR_STOP=1
        if ($LASTEXITCODE -ne 0) { throw 'Création du rôle applicatif impossible.' }
    }
    $env:ConnectionStrings__Bagage = "Host=127.0.0.1;Port=55432;Database=bagage;Username=bagage_owner;Password=$($s.OwnerPassword)"
    $env:Jwt__Key = $s.JwtKey
    dotnet run --project back/Bagage.Api --no-launch-profile -- --migrate
    if ($LASTEXITCODE -ne 0) { throw 'Migration impossible.' }
    & "$PgBin\psql.exe" -h 127.0.0.1 -p 55432 -U bagage_owner -d bagage -v ON_ERROR_STOP=1 -f database/002_runtime_permissions.sql
    if ($LASTEXITCODE -ne 0) { throw 'Attribution des droits impossible.' }
    $admin = & "$PgBin\psql.exe" -h 127.0.0.1 -p 55432 -U bagage_owner -d bagage -tAc 'SELECT 1 FROM users WHERE "Role"=''Administrateur'' LIMIT 1'
    if ($LASTEXITCODE -ne 0) { throw 'Lecture administrateur impossible.' }
    if ($admin -ne '1') {
        $env:Bootstrap__Login = $s.AdminLogin
        $env:Bootstrap__Password = $s.AdminPassword
        dotnet run --project back/Bagage.Api --no-build --no-launch-profile -- --bootstrap-admin
        if ($LASTEXITCODE -ne 0) { throw 'Création administrateur impossible.' }
    }
} finally {
    'PGPASSWORD','ConnectionStrings__Bagage','Jwt__Key','Bootstrap__Login','Bootstrap__Password' |
        ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
}
Write-Host 'Base bagage initialisée sur 127.0.0.1:55432. Secrets privés dans work/local-secrets.json.'
