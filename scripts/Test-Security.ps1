param([string]$BaseUrl = 'http://127.0.0.1:5080', [ValidateSet('Local','Docker')][string]$Environment = 'Local')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
. ./scripts/Test-Helpers.ps1
$s = Get-TestCredentials $Environment
$prefix = if ($Environment -eq 'Docker') { 'docs/preuves/phase-01-docker' } else { 'docs/preuves/phase-01' }
$lines = [Collections.Generic.List[string]]::new()
function Send($Path, $Body, $Token=$null) {
    $p = @{Uri="$BaseUrl$Path";Method='POST';Body=($Body | ConvertTo-Json);ContentType='application/json';SkipHttpErrorCheck=$true;TimeoutSec=15}
    if ($Token) { $p.Headers=@{Authorization="Bearer $Token"} }
    Invoke-WebRequest @p
}
function Verify($Name, $Condition) {
    if (!$Condition) { $lines.Add("ECHEC - $Name"); throw "ECHEC - $Name" }
    $lines.Add("OK - $Name"); Write-Host "OK - $Name"
}
try {
    $admin = Send '/api/auth/login' @{login=$s.AdminLogin;password=$s.AdminPassword}
    if ($admin.StatusCode -eq 429) { throw 'Attendre 60 secondes après les autres tests avant ce script.' }
    Verify 'Authentification initiale' ($admin.StatusCode -eq 200)
    $token=($admin.Content | ConvertFrom-Json).accessToken
    $login='lockout.'+[Guid]::NewGuid().ToString('N')
    $password='Aa1!'+[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16))
    Verify 'Compte fictif pour test verrouillage' ((Send '/api/users' @{login=$login;password=$password;role='AgentTri'} $token).StatusCode -eq 201)
    foreach ($i in 1..5) {
        Verify "Mot de passe incorrect tentative $i : 401" ((Send '/api/auth/login' @{login=$login;password='incorrect'}).StatusCode -eq 401)
    }
    Verify 'Compte verrouille meme avec mot de passe correct : 401' ((Send '/api/auth/login' @{login=$login;password=$password}).StatusCode -eq 401)
    $limited=$false
    foreach ($i in 1..12) {
        if ((Send '/api/auth/login' @{login='test.inexistant';password='incorrect'}).StatusCode -eq 429) { $limited=$true; break }
    }
    Verify 'Limitation du debit de connexion : 429' $limited
} finally { $lines | Set-Content "$prefix-securite.txt" }
