param([string]$DockerContext='desktop-linux')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$kc=@('--kubeconfig',"$((Get-Location).Path)/work/phase-04/kubeconfig.yaml",'--context','k3d-bagage')
$dc=@('--context',$DockerContext,'compose','-f','docker-compose.kube-validation.yml')
function Assert-Command([string]$Step){if($LASTEXITCODE -ne 0){throw $Step}}
function Probe($Service,$Mode){
    $command="python /test/probe.py $Mode > /tmp/result.log 2>&1; result=`$?; cat /tmp/result.log; cat /tmp/result.log > /proc/1/fd/1; exit `$result"
    docker @dc exec -T $Service sh -c $command | Tee-Object "docs/preuves/phase-04-$Mode.txt"
    Assert-Command "Validation $Mode échouée."
}
$targets=@{}
foreach($name in @('api','agents','db')){
    $targets[$name]=kubectl @kc -n bagage get pod -l app=$name -o 'jsonpath={.items[0].status.podIP}'
    Assert-Command 'Adresse pod absente.'
}
$targets.apiService=kubectl @kc -n bagage get service api -o 'jsonpath={.spec.clusterIP}'
$targets | ConvertTo-Json | Set-Content docs/preuves/phase-04-targets.json
$nodeIp=docker --context $DockerContext inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k3d-bagage-server-0
if($nodeIp -notmatch '^\d+\.\d+\.\d+\.\d+$'){throw 'Adresse du nœud inconnue.'}
docker --context $DockerContext exec k3d-bagage-server-0 ip route replace 10.77.0.1/32 via $targets.agents
Assert-Command 'Route de validation vers le pod VPN impossible.'
docker @dc up -d
Assert-Command 'Clients externes impossibles.'
# Routes forcées : un refus ne doit pas provenir seulement de l'absence de route.
foreach($client in @('outside','vpn-client')){
    docker @dc exec -T $client sh -c "ip route replace 10.42.0.0/16 via $nodeIp; ip route replace 10.43.0.0/16 via $nodeIp"
    Assert-Command 'Routes de test impossibles.'
}
docker @dc exec -T outside ip route replace 10.77.0.1/32 via $nodeIp
Assert-Command 'Route hors VPN impossible.'
try {
    Probe vpn-client vpn
    Probe outside outside
    try {
        docker @dc exec -T vpn-client sh -c "ip link delete wg0 && ip route replace 10.77.0.1/32 via $nodeIp"
        Assert-Command 'Coupure VPN impossible.'
        Probe vpn-client off
    } finally {
        docker @dc exec -T vpn-client /lab/client-up.sh
        Assert-Command 'Rétablissement VPN impossible.'
    }
    Probe vpn-client restored
} finally {
    Remove-Item -LiteralPath work/phase-04/exchange/jwt -ErrorAction SilentlyContinue
}

# Contrôle positif/négatif des policies : même pod, même URL, seule son étiquette change.
$pod=@{apiVersion='v1';kind='Pod';metadata=@{name='policy-probe';namespace='bagage';labels=@{app='public'}};spec=@{automountServiceAccountToken=$false;restartPolicy='Never';securityContext=@{runAsNonRoot=$true;runAsUser=1000;seccompProfile=@{type='RuntimeDefault'}};containers=@(@{name='probe';image='fullstack-bagage-network-tools:latest';imagePullPolicy='IfNotPresent';command=@('sleep','3600');securityContext=@{allowPrivilegeEscalation=$false;readOnlyRootFilesystem=$true;capabilities=@{drop=@('ALL')}}})}}
$pod | ConvertTo-Json -Depth 12 | kubectl @kc apply -f -
Assert-Command 'Pod de contrôle impossible.'
kubectl @kc -n bagage wait --for=condition=Ready pod/policy-probe --timeout=90s
Assert-Command 'Pod de contrôle non prêt.'
$policy=@()
try {
    $status=kubectl @kc -n bagage exec policy-probe -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://api:8080/health/ready
    Assert-Command 'Contrôle positif API impossible.'
    if($status -ne '200'){throw 'Le chemin autorisé ne fonctionne pas.'}
    $policy+='OK - Etiquette public autorisee : API repond 200.'
    kubectl @kc -n bagage label pod policy-probe app=unauthorized --overwrite | Out-Null
    Assert-Command 'Changement étiquette impossible.'
    Start-Sleep -Seconds 3
    $status=kubectl @kc -n bagage exec policy-probe -- curl -sS --max-time 4 -o /dev/null -w '%{http_code}' "http://$($targets.api):8080/health/ready" 2>$null
    if($LASTEXITCODE -eq 0 -or $status -ne '000'){throw 'Le chemin interdit répond : policy ineffective.'}
    $policy+='OK - Meme pod sans autorisation : API bloquee par NetworkPolicy.'
    kubectl @kc -n bagage label pod policy-probe app=public --overwrite | Out-Null
    Start-Sleep -Seconds 3
    $status=kubectl @kc -n bagage exec policy-probe -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://api:8080/health/ready
    Assert-Command 'Rétablissement du contrôle positif impossible.'
    if($status -ne '200'){throw 'Chemin autorisé non rétabli.'}
    $policy+='OK - Etiquette retablie : API repond de nouveau 200.'
} finally {
    kubectl @kc -n bagage delete pod policy-probe --ignore-not-found --wait=false | Out-Null
}
$policy | Tee-Object docs/preuves/phase-04-networkpolicy.txt

# Le PVC doit conserver les données lors du remplacement du pod PostgreSQL.
$before=kubectl @kc -n bagage get pod db-0 -o 'jsonpath={.metadata.uid}'
kubectl @kc -n bagage rollout restart statefulset/db
kubectl @kc -n bagage rollout status statefulset/db --timeout=180s
Assert-Command 'Redémarrage PostgreSQL impossible.'
$after=kubectl @kc -n bagage get pod db-0 -o 'jsonpath={.metadata.uid}'
if($before -eq $after){throw 'Le pod DB est identique : remplacement non constate.'}
kubectl @kc -n bagage rollout status deployment/api --timeout=90s
Assert-Command 'API indisponible après redémarrage DB.'
Probe outside persistence
'OK - Pod PostgreSQL remplace, PVC et donnees conserves.' | Set-Content docs/preuves/phase-04-pvc.txt

$services=kubectl @kc -n bagage get services -o json | ConvertFrom-Json
Assert-Command 'Services indisponibles.'
$infra=@()
foreach($name in @('api','agents','db')){
    $svc=$services.items | Where-Object {$_.metadata.name -eq $name}
    if($svc.spec.type -ne 'ClusterIP' -or $svc.spec.externalIPs){throw "Service privé publié : $name"}
    $infra+="OK - Service $name en ClusterIP sans IP externe."
}
$encryption=docker --context $DockerContext exec k3d-bagage-server-0 k3s secrets-encrypt status
Assert-Command 'Lecture du chiffrement des secrets impossible.'
if(($encryption -join "`n") -notmatch 'Encryption Status: Enabled'){throw 'Chiffrement des secrets non actif.'}
$infra+='OK - Chiffrement au repos des Secrets k3s actif.'
$infra | Tee-Object docs/preuves/phase-04-infrastructure.txt
$encryption | Set-Content docs/preuves/phase-04-chiffrement.txt
kubectl @kc get nodes -o wide | Set-Content docs/preuves/phase-04-cluster.txt
kubectl @kc -n bagage get pods,services,pvc,networkpolicies -o wide | Set-Content docs/preuves/phase-04-ressources.txt
docker @dc exec -T outside python -c 'import socket,json,pathlib; result={}; host="k3d-bagage-server-0"; ports=[5432,8080,8443,18080,14201,31443]; [(result.update({str(p):s.connect_ex((host,p))==0}),s.close()) for p in ports for s in [socket.socket()] if not s.settimeout(2)]; pathlib.Path("/evidence/phase-04-scan.json").write_text(json.dumps({"cible":host,"portsTcpOuverts":result},indent=2)); print(result); assert result["31443"] and not any(v for k,v in result.items() if k!="31443")' | Tee-Object docs/preuves/phase-04-scan.txt
Assert-Command 'Scan externe ciblé incohérent.'
docker @dc exec -T outside sh -c 'cat /evidence/phase-04-networkpolicy.txt /evidence/phase-04-pvc.txt /evidence/phase-04-infrastructure.txt > /proc/1/fd/1'
Write-Host 'Validation Kubernetes terminée. Résultats et preuves dans docs/preuves/phase-04-*.'
