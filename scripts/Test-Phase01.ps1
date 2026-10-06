param([string]$BaseUrl = 'http://127.0.0.1:5080', [ValidateSet('Local','Docker')][string]$Environment = 'Local')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
. ./scripts/Test-Helpers.ps1
$s = Get-TestCredentials $Environment
$prefix = if ($Environment -eq 'Docker') { 'docs/preuves/phase-01-docker' } else { 'docs/preuves/phase-01' }
$results = [Collections.Generic.List[object]]::new()
function Call-Api($Method, $Path, $Body = $null, $Token = $null) {
    $params = @{ Uri = "$BaseUrl$Path"; Method = $Method; SkipHttpErrorCheck = $true; TimeoutSec = 20 }
    if ($Token) { $params.Headers = @{ Authorization = "Bearer $Token" } }
    if ($null -ne $Body) { $params.Body = $Body | ConvertTo-Json -Depth 8; $params.ContentType = 'application/json' }
    $r = Invoke-WebRequest @params
    $data = if ($r.Content) { try { $r.Content | ConvertFrom-Json } catch { $null } } else { $null }
    return @{ Status = [int]$r.StatusCode; Data = $data; Raw = $r.Content }
}
function Check($Name, $Condition) {
    $results.Add([pscustomobject]@{ test = $Name; resultat = $(if ($Condition) { 'OK' } else { 'ECHEC' }) })
    if (!$Condition) { throw "Échec : $Name" }
    Write-Host "OK - $Name"
}
try {
    Check 'API et PostgreSQL disponibles' ((Call-Api GET '/health/ready').Status -eq 200)
    Check 'Vols sans JWT : 401' ((Call-Api GET '/api/vols').Status -eq 401)
    Check 'Bagages sans JWT : 401' ((Call-Api GET '/api/bagages').Status -eq 401)
    Check 'JWT falsifie : 401' ((Call-Api GET '/api/vols' $null 'invalid.jwt.signature').Status -eq 401)
    Check 'Tracking inconnu : 404' ((Call-Api GET '/api/track/inconnu').Status -eq 404)
    $a = Call-Api POST '/api/auth/login' @{ login = $s.AdminLogin; password = $s.AdminPassword }
    Check 'Authentification administrateur' ($a.Status -eq 200)
    $admin = $a.Data.accessToken
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0,10)
    $tokens = @{}
    foreach ($role in 'Superviseur','AgentEnregistrement','AgentTri') {
        $pw = 'Aa1!' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(18))
        $login = "$role.$suffix".ToLowerInvariant()
        $u = Call-Api POST '/api/users' @{ login = $login; password = $pw; role = $role } $admin
        Check "Creation compte $role" ($u.Status -eq 201)
        $auth = Call-Api POST '/api/auth/login' @{ login = $login; password = $pw }
        Check "Connexion $role" ($auth.Status -eq 200)
        $tokens[$role] = $auth.Data.accessToken
    }
    $super = $tokens.Superviseur; $tri = $tokens.AgentTri; $enreg = $tokens.AgentEnregistrement
    Check 'Superviseur sans gestion des comptes : 403' ((Call-Api GET '/api/users' $null $super).Status -eq 403)
    $flight = @{ numero = "TU$suffix"; origine = 'SFA'; destination = 'CDG'; departPrevu = [DateTime]::UtcNow.AddDays(1).ToString('o') }
    Check 'Administrateur sans creation de vol : 403' ((Call-Api POST '/api/vols' $flight $admin).Status -eq 403)
    Check 'Agent tri sans creation de vol : 403' ((Call-Api POST '/api/vols' $flight $tri).Status -eq 403)
    $v = Call-Api POST '/api/vols' $flight $super
    Check 'Creation vol superviseur' ($v.Status -eq 201)
    Check 'Vol duplique : 409' ((Call-Api POST '/api/vols' $flight $super).Status -eq 409)
    $payload = @{ volId = $v.Data.id; nomPassager = 'PASSAGER FICTIF TEST'; poidsKg = 21.5 }
    Check 'Agent tri sans enregistrement : 403' ((Call-Api POST '/api/bagages' $payload $tri).Status -eq 403)
    $bad = @{ volId = [Guid]::NewGuid().ToString(); nomPassager = 'TEST'; poidsKg = 20 }
    Check 'Vol inexistant refuse : 400' ((Call-Api POST '/api/bagages' $bad $enreg).Status -eq 400)
    $bad.volId = $v.Data.id; $bad.poidsKg = -1
    Check 'Poids negatif refuse : 400' ((Call-Api POST '/api/bagages' $bad $enreg).Status -eq 400)
    $b = Call-Api POST '/api/bagages' $payload $enreg
    Check 'Enregistrement bagage' ($b.Status -eq 201)
    $id = $b.Data.id; $tracking = $b.Data.trackingId
    Check 'Enregistrement sans liste globale : 403' ((Call-Api GET '/api/bagages' $null $enreg).Status -eq 403)
    Check 'Filtrage des bagages' ((Call-Api GET "/api/bagages?volId=$($v.Data.id)&statut=enregistre" $null $tri).Data.Count -eq 1)
    Check 'Saut de statut agent refuse : 409' ((Call-Api PATCH "/api/bagages/$id/statut" @{statut='livre'} $tri).Status -eq 409)
    Check 'Saut superviseur sans motif refuse : 409' ((Call-Api PATCH "/api/bagages/$id/statut" @{statut='livre'} $super).Status -eq 409)
    foreach ($status in 'trie','charge','en_vol','livre') {
        Check "Transition normale $status" ((Call-Api PATCH "/api/bagages/$id/statut" @{statut=$status} $tri).Status -eq 200)
    }
    Check 'Statut identique refuse : 409' ((Call-Api PATCH "/api/bagages/$id/statut" @{statut='livre'} $tri).Status -eq 409)
    $history = Call-Api GET "/api/bagages/$id/historique" $null $super
    Check 'Historique : 5 evenements avec agent et date' ($history.Data.Count -eq 5 -and @($history.Data | Where-Object { !$_.agentId -or !$_.horodatage }).Count -eq 0)
    $track = Call-Api GET "/api/track/$tracking"
    Check 'Tracking public sans authentification' ($track.Status -eq 200 -and $track.Data.statut -eq 'livre')
    Check 'Tracking sans donnees personnelles ou internes' ($track.Raw -notmatch 'nomPassager|PASSAGER|agentId|motif|volId|password|login')
    $second = Call-Api POST '/api/bagages' $payload $enreg
    $id2 = $second.Data.id
    $anomaly = Call-Api PATCH "/api/bagages/$id2/statut" @{statut='livre';motif='Correction superviseur pour demonstration fictive'} $super
    Check 'Exception motivee superviseur tracee' ($anomaly.Status -eq 200 -and $anomaly.Data.anomalie)
    $h2 = Call-Api GET "/api/bagages/$id2/historique" $null $super
    Check 'Anomalie persistee dans historique' ($h2.Data.Count -eq 2 -and $h2.Data[1].anomalie -and $h2.Data[1].motif)
    $third = Call-Api POST '/api/bagages' $payload $enreg
    Check 'Declaration perdu depuis enregistre' ((Call-Api PATCH "/api/bagages/$($third.Data.id)/statut" @{statut='perdu'} $tri).Status -eq 200)
    $concurrent = Call-Api POST '/api/bagages' $payload $enreg
    Check 'Bagage de test concurrence cree' ($concurrent.Status -eq 201)
    $client = [Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(20)
    $client.DefaultRequestHeaders.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $tri)
    $req1 = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Patch, "$BaseUrl/api/bagages/$($concurrent.Data.id)/statut")
    $req2 = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Patch, "$BaseUrl/api/bagages/$($concurrent.Data.id)/statut")
    $req1.Content = [Net.Http.StringContent]::new('{"statut":"trie"}', [Text.Encoding]::UTF8, 'application/json')
    $req2.Content = [Net.Http.StringContent]::new('{"statut":"trie"}', [Text.Encoding]::UTF8, 'application/json')
    try {
        $task1 = $client.SendAsync($req1)
        $task2 = $client.SendAsync($req2)
        $resp1 = $task1.GetAwaiter().GetResult()
        $resp2 = $task2.GetAwaiter().GetResult()
        $codes = @([int]$resp1.StatusCode, [int]$resp2.StatusCode) | Sort-Object
        Check 'Deux modifications simultanees : une reussite et un conflit' (($codes -join ',') -eq '200,409')
        $hc = Call-Api GET "/api/bagages/$($concurrent.Data.id)/historique" $null $super
        Check 'Concurrence : historique sans doublon' ($hc.Data.Count -eq 2 -and $hc.Data[1].nouveauStatut -eq 'trie')
    } finally {
        if ($resp1) { $resp1.Dispose() }; if ($resp2) { $resp2.Dispose() }
        $req1.Dispose(); $req2.Dispose(); $client.Dispose()
    }
    $track.Raw | Set-Content "$prefix-tracking.json"
    @{ trackingUrl = "$BaseUrl/api/track/$tracking"; readinessUrl = "$BaseUrl/health/ready"; environment = $Environment } | ConvertTo-Json | Set-Content "$prefix-capture-urls.json"
} finally {
    $results | ConvertTo-Json -Depth 4 | Set-Content "$prefix-tests.json"
    @("Phase 01 - Tests HTTP reels - $Environment", "Date UTC : $([DateTime]::UtcNow.ToString('o'))", "API : $BaseUrl", '') +
        @($results | ForEach-Object { "$($_.resultat) - $($_.test)" }) | Set-Content "$prefix-tests.txt"
}
