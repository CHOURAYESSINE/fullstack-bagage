$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$config='C:\Program Files\PostgreSQL\16\data\postgresql.conf'
$backup=Join-Path $root 'work/phase-04/postgresql-original.conf'
try {
    if(!(Test-Path $backup)){Copy-Item -LiteralPath $config -Destination $backup}
    $original=[IO.File]::ReadAllText($config)
    $changed=[regex]::Replace($original,"(?m)^\s*listen_addresses\s*=.*$","listen_addresses = 'localhost' # acces local uniquement, validation bagage")
    if($changed -eq $original){throw 'Directive listen_addresses non modifiee'}
    [IO.File]::WriteAllText($config,$changed,[Text.UTF8Encoding]::new($false))
    try {Restart-Service postgresql-x64-16} catch {Copy-Item -LiteralPath $backup -Destination $config -Force; Restart-Service postgresql-x64-16; throw}
    @{succes=$true;ecoute='localhost';service=(Get-Service postgresql-x64-16).Status.ToString()} | ConvertTo-Json | Set-Content (Join-Path $root 'work/phase-04/postgresql-bind-status.json')
} catch {@{succes=$false;erreur=$_.Exception.Message} | ConvertTo-Json | Set-Content (Join-Path $root 'work/phase-04/postgresql-bind-status.json'); throw}
