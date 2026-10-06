param([string]$DockerContext = 'desktop-linux', [string]$BaseUrl = 'http://127.0.0.1:18080')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$results = [Collections.Generic.List[object]]::new()
function Check($Name, $Condition) {
    $results.Add([pscustomobject]@{test=$Name;resultat=$(if ($Condition) {'OK'} else {'ECHEC'})})
    if (!$Condition) { throw "ECHEC - $Name" }
    Write-Host "OK - $Name"
}
function Inspect-Container($Id, $Template) {
    $value = docker --context $DockerContext inspect --format $Template $Id
    if ($LASTEXITCODE -ne 0) { throw 'Inspection du conteneur impossible.' }
    return ($value -join "`n")
}
try {
    $api = docker --context $DockerContext compose ps -q api
    $db = docker --context $DockerContext compose ps -q db
    Check 'Deux conteneurs du projet presents' ($api -and $db)
    Check 'API healthy' ((Inspect-Container $api '{{.State.Health.Status}}') -eq 'healthy')
    Check 'PostgreSQL healthy' ((Inspect-Container $db '{{.State.Health.Status}}') -eq 'healthy')
    $user = Inspect-Container $api '{{.Config.User}}'
    Check 'API executee sans root' ($user -and $user -notin @('0','root','0:0'))
    Check 'Systeme de fichiers API en lecture seule' ((Inspect-Container $api '{{.HostConfig.ReadonlyRootfs}}') -eq 'true')
    Check 'Toutes les capabilities Linux retirees' ((Inspect-Container $api '{{json .HostConfig.CapDrop}}') -match 'ALL')
    Check 'Acquisition de nouveaux privileges interdite' ((Inspect-Container $api '{{json .HostConfig.SecurityOpt}}') -match 'no-new-privileges')
    $ports = (Inspect-Container $api '{{json .HostConfig.PortBindings}}') | ConvertFrom-Json
    Check "API publiee seulement sur 127.0.0.1:$(([uri]$BaseUrl).Port)" ($ports.'8080/tcp'.Count -eq 1 -and $ports.'8080/tcp'[0].HostIp -eq '127.0.0.1' -and $ports.'8080/tcp'[0].HostPort -eq [string]([uri]$BaseUrl).Port)
    $dbPorts = Inspect-Container $db '{{json .HostConfig.PortBindings}}'
    Check 'Aucun port PostgreSQL publie' ($dbPorts -in @('{}','null'))
    $internal = docker --context $DockerContext network inspect fullstack-bagage_database --format '{{.Internal}}'
    Check 'Reseau base de donnees interne' ($LASTEXITCODE -eq 0 -and $internal -eq 'true')
    $health = Invoke-WebRequest "$BaseUrl/health/ready" -TimeoutSec 15
    Check 'API conteneur connectee a PostgreSQL' ($health.StatusCode -eq 200 -and ($health.Content | ConvertFrom-Json).baseDeDonnees -eq 'connectee')
    $swagger = Invoke-WebRequest "$BaseUrl/swagger/index.html" -SkipHttpErrorCheck -TimeoutSec 15
    Check 'Swagger absent en Production : 404' ($swagger.StatusCode -eq 404)
    $permissions = @'
SELECT NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole FROM pg_roles WHERE rolname='bagage_app';
SELECT has_table_privilege('bagage_app','historique_statuts','INSERT') AND NOT has_table_privilege('bagage_app','historique_statuts','UPDATE') AND NOT has_table_privilege('bagage_app','historique_statuts','DELETE') AND NOT has_schema_privilege('bagage_app','public','CREATE');
'@
    $rights = $permissions | docker --context $DockerContext compose exec -T db psql -U bagage_owner -d bagage -v ON_ERROR_STOP=1 -tA
    Check 'Role PostgreSQL limite et historique protege' ($LASTEXITCODE -eq 0 -and ($rights -join ',') -eq 't,t')
    # La capture n'inclut ni les variables d'environnement ni les secrets.
    docker --context $DockerContext version --format '{{json .}}' | Set-Content docs/preuves/phase-01-docker-versions.json
    docker --context $DockerContext compose ps | Set-Content docs/preuves/phase-01-docker-conteneurs.txt
    Check 'Evidence des versions et services sauvegardee' ($LASTEXITCODE -eq 0)
} finally {
    $results | ConvertTo-Json | Set-Content docs/preuves/phase-01-docker-infrastructure.json
    @("Validation Docker - $([DateTime]::UtcNow.ToString('o'))") + @($results | ForEach-Object { "$($_.resultat) - $($_.test)" }) | Set-Content docs/preuves/phase-01-docker-infrastructure.txt
}

