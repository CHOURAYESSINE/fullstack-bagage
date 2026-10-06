function Get-TestCredentials {
    param([ValidateSet('Local','Docker')][string]$Environment)
    if ($Environment -eq 'Local') {
        $local = Get-Content work/local-secrets.json -Raw | ConvertFrom-Json
        return @{ AdminLogin=$local.AdminLogin; AdminPassword=$local.AdminPassword }
    }
    $values = @{}
    foreach ($line in Get-Content .env) {
        if ($line -match '^([A-Z_]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    if (!$values.BOOTSTRAP_LOGIN -or !$values.BOOTSTRAP_PASSWORD) {
        throw 'Identifiants Docker manquants dans .env.'
    }
    return @{ AdminLogin=$values.BOOTSTRAP_LOGIN; AdminPassword=$values.BOOTSTRAP_PASSWORD }
}
