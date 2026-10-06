param([string]$DockerContext='desktop-linux')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$root=(Get-Location).Path
$env:DOCKER_CONTEXT=$DockerContext
$private=Join-Path $root 'work/phase-04'
New-Item -ItemType Directory -Force $private,work/tools | Out-Null
& icacls $private /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)(F)" | Out-Null
if($LASTEXITCODE -ne 0){throw 'ACL des secrets impossible.'}
function Assert-Command([string]$Step){if($LASTEXITCODE -ne 0){throw $Step}}
$k3d=Join-Path $root 'work/tools/k3d.exe'
if(!(Test-Path $k3d)){
    Invoke-WebRequest https://github.com/k3d-io/k3d/releases/download/v5.9.0/k3d-windows-amd64.exe -OutFile $k3d
    Invoke-WebRequest https://github.com/k3d-io/k3d/releases/download/v5.9.0/checksums.txt -OutFile work/tools/k3d-checksums.txt
}
$checksum=Get-Content work/tools/k3d-checksums.txt | Where-Object {$_ -match 'k3d-windows-amd64.exe$'}
if(!$checksum -or (Get-FileHash $k3d).Hash -ne ($checksum -split '\s+')[0]){throw 'Empreinte k3d incorrecte.'}
$clusters=& $k3d cluster list -o json | ConvertFrom-Json
Assert-Command 'Lecture des clusters impossible.'
if('bagage' -notin @($clusters.name)){
    & $k3d cluster create bagage --image rancher/k3s:v1.35.5-k3s1 --servers 1 --agents 0 --api-port 127.0.0.1:16443 --port '127.0.0.1:15443:31443@server:0' --port '127.0.0.1:52820:31820/udp@server:0' --k3s-arg '--disable=traefik@server:0' --k3s-arg '--disable=servicelb@server:0' --k3s-arg '--secrets-encryption@server:0' --kubeconfig-update-default=false --kubeconfig-switch-context=false --wait --timeout 300s
    Assert-Command 'Création du cluster impossible.'
}
& $k3d kubeconfig get bagage | Set-Content -Encoding utf8 "$private/kubeconfig.yaml"
Assert-Command 'Kubeconfig indisponible.'
$kc=@('--kubeconfig',"$private/kubeconfig.yaml",'--context','k3d-bagage')
kubectl @kc wait --for=condition=Ready node --all --timeout=180s
Assert-Command 'Nœud non prêt.'
docker --context $DockerContext build -t fullstack-bagage-api:phase04 -f back/Bagage.Api/Dockerfile .
Assert-Command 'Construction API phase 4 impossible.'
foreach($image in @('fullstack-bagage-api:phase04','fullstack-bagage-public:latest','fullstack-bagage-agents:latest','fullstack-bagage-network-tools:latest','postgres:16')){
    & $k3d image import $image -c bagage
    Assert-Command "Import impossible : $image"
}
# Secrets indépendants du laboratoire Compose ; aucune valeur dans les arguments des processus.
if(!(Test-Path "$private/credentials.json")){
    function Random-Secret { [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)) }
    @{owner=(Random-Secret);app=(Random-Secret);jwt=(Random-Secret);login='admin.kube';password=('Aa1!'+(Random-Secret))} | ConvertTo-Json | Set-Content "$private/credentials.json"
}
$s=Get-Content "$private/credentials.json" -Raw | ConvertFrom-Json
@('POSTGRES_DB=bagage','POSTGRES_USER=bagage_owner',"POSTGRES_PASSWORD=$($s.owner)","BAGAGE_APP_PASSWORD=$($s.app)") | Set-Content "$private/db.env"
@("ConnectionStrings__Bagage=Host=db;Database=bagage;Username=bagage_app;Password=$($s.app)","Jwt__Key=$($s.jwt)") | Set-Content "$private/api.env"
@("ConnectionStrings__Bagage=Host=db;Database=bagage;Username=bagage_owner;Password=$($s.owner)","Jwt__Key=$($s.jwt)","Bootstrap__Login=$($s.login)","Bootstrap__Password=$($s.password)") | Set-Content "$private/migration.env"
$init=Get-Content infra/network/init-secrets.sh -Raw
$init=$init.Replace('DNS:localhost,IP:127.0.0.1,IP:172.26.41.3','DNS:localhost,DNS:public,DNS:public.bagage.svc,DNS:k3d-bagage-server-0,IP:127.0.0.1').Replace('Endpoint = 172.26.41.2:51820','Endpoint = k3d-bagage-server-0:31820').Replace('Endpoint = 127.0.0.1:51820','Endpoint = 127.0.0.1:52820')
[IO.File]::WriteAllText("$private/init-secrets.sh",$init.Replace("`r`n","`n"))
docker --context $DockerContext run --rm --mount "type=bind,source=$private,target=/secrets" fullstack-bagage-network-tools sh /secrets/init-secrets.sh
Assert-Command 'Initialisation WireGuard/TLS impossible.'
@{login=$s.login;password=$s.password} | ConvertTo-Json | Set-Content "$private/login/admin.json"
kubectl @kc apply -f infra/kubernetes/00-config.json
Assert-Command 'ConfigMaps impossibles.'
foreach($name in @('db','api','migration')){
    kubectl @kc -n bagage create secret generic "$name-secret" --from-env-file="$private/$name.env" --dry-run=client -o json | kubectl @kc apply -f -
    Assert-Command 'Secret applicatif impossible.'
}
foreach($name in @('public','agents')){
    kubectl @kc -n bagage create secret generic "$name-tls" --from-file="$name.crt=$private/pki/$name.crt" --from-file="$name.key=$private/pki/$name.key" --dry-run=client -o json | kubectl @kc apply -f -
    Assert-Command 'Secret TLS impossible.'
}
kubectl @kc -n bagage create secret generic wireguard-server --from-file="server.conf=$private/wireguard/server.conf" --dry-run=client -o json | kubectl @kc apply -f -
Assert-Command 'Secret WireGuard impossible.'
kubectl @kc apply -f infra/kubernetes/05-network-policies.json -f infra/kubernetes/10-database.json
Assert-Command 'Déploiement DB/politiques impossible.'
kubectl @kc -n bagage rollout status statefulset/db --timeout=180s
Assert-Command 'Base non prête.'
# Les Jobs existants ont un template immuable. La migration est idempotente et
# rejouée explicitement ; seul le Job terminé est remplacé, jamais les données.
kubectl @kc -n bagage delete job migrate --ignore-not-found --wait=true
Assert-Command 'Remplacement du Job de migration impossible.'
kubectl @kc apply -f infra/kubernetes/20-migrate.json
kubectl @kc -n bagage wait --for=condition=complete job/migrate --timeout=120s
Assert-Command 'Migration impossible.'
kubectl @kc -n bagage exec db-0 -- psql -U bagage_owner -d bagage -v ON_ERROR_STOP=1 -f /setup/permissions.sql
Assert-Command 'Permissions PostgreSQL impossibles.'
$admin=kubectl @kc -n bagage exec db-0 -- psql -U bagage_owner -d bagage -tAc 'SELECT 1 FROM users WHERE "Role"=''Administrateur'' LIMIT 1'
Assert-Command 'Lecture administrateur impossible.'
if($admin -ne '1'){
    kubectl @kc apply -f infra/kubernetes/20-bootstrap.json
    kubectl @kc -n bagage wait --for=condition=complete job/bootstrap --timeout=120s
    Assert-Command 'Bootstrap impossible.'
}
kubectl @kc apply -f infra/kubernetes/30-applications.json
Assert-Command 'Déploiement applicatif impossible.'
foreach($name in @('api','agents','public')){
    kubectl @kc -n bagage rollout status deployment/$name --timeout=180s
    Assert-Command "Service $name non prêt."
}
Write-Host 'Cluster de démonstration prêt. HTTPS public : https://localhost:15443 (CA locale).'
Write-Host 'Validation : ./scripts/Test-Phase04.ps1. Les secrets et le kubeconfig restent dans work/phase-04.'
