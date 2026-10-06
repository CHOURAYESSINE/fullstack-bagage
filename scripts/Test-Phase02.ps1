param([string]$PublicUrl='http://127.0.0.1:14200',[string]$AgentsUrl='http://127.0.0.1:14201',[string]$DockerContext='desktop-linux')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
. ./scripts/Test-Helpers.ps1
$checks=[Collections.Generic.List[object]]::new()
function Check($Name,$Condition) {
  $checks.Add([pscustomobject]@{test=$Name;resultat=$(if($Condition){'OK'}else{'ECHEC'})})
  if(!$Condition){throw "ECHEC - $Name"}; Write-Host "OK - $Name"
}
function Request($Method,$Url,$Body=$null,$Token=$null) {
  $args=@{Method=$Method;Uri=$Url;SkipHttpErrorCheck=$true;TimeoutSec=20}
  if($null -ne $Body){$args.Body=$Body|ConvertTo-Json;$args.ContentType='application/json'}
  if($Token){$args.Headers=@{Authorization="Bearer $Token"}}
  Invoke-WebRequest @args
}
try {
  foreach($service in @('public','agents')) {
    $id=docker --context $DockerContext compose ps -q $service
    $state=docker --context $DockerContext inspect --format '{{.State.Health.Status}}|{{.Config.User}}|{{.HostConfig.ReadonlyRootfs}}' $id
    Check "$service : healthy, non-root, lecture seule" ($LASTEXITCODE -eq 0 -and $state -match '^healthy\|[^|]+\|true$' -and $state -notmatch '\|(0|root)\|')
  }
  $public=Request GET $PublicUrl
  Check 'Interface publique accessible' ($public.StatusCode -eq 200 -and $public.Content -match '<app-root>')
  Check 'CSP et absence de mise en cache' ($public.Headers['Content-Security-Policy'] -match "connect-src 'self'" -and $public.Headers['Cache-Control'] -match 'no-store')
  Check 'Interface agents accessible localement' ((Request GET $AgentsUrl).StatusCode -eq 200)
  Check 'Route Angular profonde disponible' ((Request GET "$AgentsUrl/bagages").StatusCode -eq 200)
  $badHost=Invoke-WebRequest $AgentsUrl -Headers @{Host='externe.invalid'} -SkipHttpErrorCheck
  Check 'Hote agents non autorise refuse par Nginx' ($badHost.StatusCode -eq 403)
  $segment=(Request GET "$AgentsUrl/segment.json").Content | ConvertFrom-Json
  Check 'Origines agents explicitement limitees' ($segment.allowedOrigins.Count -eq 2 -and $segment.allowedOrigins -contains $AgentsUrl -and $segment.allowedOrigins -notcontains '*')
  Check 'API agents sans JWT refusee' ((Request GET "$AgentsUrl/api/bagages").StatusCode -eq 401)
  $credentials=Get-TestCredentials Docker
  $login=Request POST "$AgentsUrl/api/auth/login" @{login=$credentials.AdminLogin;password=$credentials.AdminPassword}
  Check 'Connexion administrateur via proxy agents' ($login.StatusCode -eq 200)
  $admin=($login.Content|ConvertFrom-Json).accessToken
  foreach($path in @('auth/login','users','vols','bagages')) {
    $method=if($path -eq 'auth/login'){'POST'}else{'GET'}
    Check "Proxy public interdit /api/$path avec JWT valide" ((Request $method "$PublicUrl/api/$path" $null $admin).StatusCode -eq 404)
  }
  $stamp=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $demo=@{}
  $tokens=@{}
  foreach($role in @('Superviseur','AgentEnregistrement','AgentTri','Administrateur')) {
    $password='Demo1!'+[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16))
    $name="ui.$($role.ToLowerInvariant()).$stamp"
    $created=Request POST "$AgentsUrl/api/users" @{login=$name;password=$password;role=$role} $admin
    Check "Compte fictif $role cree" ($created.StatusCode -eq 201)
    $connected=Request POST "$AgentsUrl/api/auth/login" @{login=$name;password=$password}
    Check "Connexion $role via proxy" ($connected.StatusCode -eq 200)
    $tokens[$role]=($connected.Content|ConvertFrom-Json).accessToken
    $demo[$role]=@{login=$name;password=$password}
  }
  $demo | ConvertTo-Json | Set-Content work/phase-02-demo-secrets.json
  & icacls work/phase-02-demo-secrets.json /inheritance:r /grant:r "${env:USERNAME}:(F)" | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Permissions du fichier prive impossibles'}
  $flight=Request POST "$AgentsUrl/api/vols" @{numero="UI$($stamp.ToString().Substring(6))";origine='TUN';destination='CDG';departPrevu=[DateTimeOffset]::UtcNow.AddDays(1).ToString('o')} $tokens.Superviseur
  Check 'Creation vol par superviseur via interface agents' ($flight.StatusCode -eq 201)
  $flightData=$flight.Content|ConvertFrom-Json
  $bag=Request POST "$AgentsUrl/api/bagages" @{volId=$flightData.id;nomPassager='Passager fictif Phase 2';poidsKg=18.5} $tokens.AgentEnregistrement
  Check 'Enregistrement via proxy avec role autorise' ($bag.StatusCode -eq 201)
  $bagData=$bag.Content|ConvertFrom-Json
  Check 'Agent tri sans droit de creation de vol' ((Request POST "$AgentsUrl/api/vols" @{numero='REFUS';origine='TUN';destination='CDG';departPrevu=[DateTimeOffset]::UtcNow.ToString('o')} $tokens.AgentTri).StatusCode -eq 403)
  Check 'Administrateur sans permission metier' ((Request GET "$AgentsUrl/api/bagages" $null $tokens.Administrateur).StatusCode -eq 403)
  Check 'Agent enregistrement sans liste globale' ((Request GET "$AgentsUrl/api/bagages" $null $tokens.AgentEnregistrement).StatusCode -eq 403)
  Check 'Superviseur sans gestion des comptes' ((Request GET "$AgentsUrl/api/users" $null $tokens.Superviseur).StatusCode -eq 403)
  Check 'Tri vers etape normale accepte' ((Request PATCH "$AgentsUrl/api/bagages/$($bagData.id)/statut" @{statut='trie'} $tokens.AgentTri).StatusCode -eq 200)
  Check 'Saut etape sans superviseur refuse' ((Request PATCH "$AgentsUrl/api/bagages/$($bagData.id)/statut" @{statut='livre'} $tokens.AgentTri).StatusCode -eq 409)
  $tracking=Request GET "$PublicUrl/api/track/$($bagData.trackingId)"
  $publicData=$tracking.Content|ConvertFrom-Json
  Check 'Suivi public relie a PostgreSQL' ($tracking.StatusCode -eq 200 -and $publicData.statut -eq 'trie' -and $publicData.historique.Count -eq 2)
  Check 'Suivi sans identite ni identifiant interne' (!$publicData.PSObject.Properties['nomPassager'] -and !$publicData.PSObject.Properties['volId'] -and !$publicData.historique[0].PSObject.Properties['agentId'])
  Check 'Modification interdite par le proxy public' ((Request PATCH "$PublicUrl/api/track/$($bagData.trackingId)" @{statut='livre'} $tokens.Superviseur).StatusCode -eq 403)
  @{publicUrl=$PublicUrl;agentsUrl=$AgentsUrl;trackingId=$bagData.trackingId;bagageId=$bagData.id;volId=$flightData.id;numeroVol=$flightData.numero} | ConvertTo-Json | Set-Content docs/preuves/phase-02-demo.json
  $publicData | ConvertTo-Json -Depth 6 | Set-Content docs/preuves/phase-02-tracking.json
  docker --context $DockerContext compose ps | Set-Content docs/preuves/phase-02-conteneurs.txt
} finally {
  $checks | ConvertTo-Json | Set-Content docs/preuves/phase-02-integration.json
  @("Tests phase 2 - $([DateTime]::UtcNow.ToString('o'))")+@($checks|ForEach-Object{"$($_.resultat) - $($_.test)"}) | Set-Content docs/preuves/phase-02-integration.txt
}
