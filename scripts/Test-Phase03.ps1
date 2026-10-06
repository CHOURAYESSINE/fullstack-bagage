param([string]$DockerContext='desktop-linux')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$compose=@('--context',$DockerContext,'compose','-f','docker-compose.yml','-f','docker-compose.secure.yml','--profile','validation')
function Probe($Service,$Mode,$Extra='') {
    # La sortie est également envoyée aux vrais journaux Docker pour les captures.
    $command="python /lab/probe.py $Mode $Extra > /tmp/probe.log 2>&1; result=`$?; cat /tmp/probe.log; cat /tmp/probe.log > /proc/1/fd/1; exit `$result"
    docker @compose exec -T $Service sh -c $command | Tee-Object "docs/preuves/phase-03-$Mode.txt"
    if($LASTEXITCODE -ne 0){throw "Validation $Mode échouée."}
}
Probe vpn-client vpn
$db=docker @compose ps -q db
$dbIp=docker --context $DockerContext inspect --format '{{(index .NetworkSettings.Networks "fullstack-bagage_database").IPAddress}}' $db
if($dbIp -notmatch '^\d+\.\d+\.\d+\.\d+$'){throw 'Adresse DB inconnue.'}
Probe outside outside $dbIp
try {
    docker @compose exec -T vpn-client sh -c 'ip link delete wg0 && ip route add 10.77.0.1/32 via 172.26.41.2'
    if($LASTEXITCODE -ne 0){throw 'Coupure du tunnel impossible.'}
    Probe vpn-client off
} finally {
    docker @compose exec -T vpn-client /lab/client-up.sh
    if($LASTEXITCODE -ne 0){throw 'Rétablissement du tunnel impossible.'}
}
Probe vpn-client restored
docker @compose exec -T vpn-server iptables -L INPUT -n -v | Set-Content docs/preuves/phase-03-firewall.txt
docker @compose ps | Set-Content docs/preuves/phase-03-conteneurs.txt
$ports=@()
foreach($service in @('api','agents','db')) {
    $id=docker @compose ps -q $service
    $published=docker --context $DockerContext inspect --format '{{json .HostConfig.PortBindings}}' $id
    if($published -notin @('{}','null')){throw "Port privé publié : $service"}
    $ports+="OK - $service : aucun port publie sur Windows."
}
$ports | Tee-Object docs/preuves/phase-03-ports.txt
$hostChecks=@()
foreach($port in @(18080,14200,14201)) {
    $client=[Net.Sockets.TcpClient]::new()
    try { $task=$client.ConnectAsync('127.0.0.1',$port); $connected=$task.Wait(700) -and $client.Connected }
    catch { $connected=$false } finally { $client.Dispose() }
    if($connected){throw "Ancien port encore ouvert : $port"}
    $hostChecks+="OK - Ancien port HTTP $port ferme sur Windows."
}
$redirect=curl.exe -sS -o NUL -w '%{http_code}' http://127.0.0.1:14080
if($LASTEXITCODE -ne 0 -or $redirect -ne '308'){throw 'Redirection HTTPS absente.'}
$hostChecks+='OK - HTTP public redirige vers HTTPS (308).'
$hostChecks | Tee-Object docs/preuves/phase-03-hote.txt
Remove-Item -LiteralPath 'work/phase-03/exchange/jwt' -ErrorAction SilentlyContinue
