"""Contrôles des seuls points d'entrée publics alloués au projet."""
import datetime,http.client,ipaddress,json,pathlib,socket,ssl,subprocess,sys,urllib.parse
base=pathlib.Path('/home/bagagetest/bagage-validation'); mode=sys.argv[1];checks=[]
def check(label,ok):
    checks.append({'test':label,'resultat':'OK' if ok else 'ECHEC'})
    print(('OK' if ok else 'ECHEC')+' - '+label,flush=True)
    if not ok:raise RuntimeError(label)
def req(host,port,route,ctx,token=None):
    c=http.client.HTTPSConnection(host,port,context=ctx,timeout=5)
    c.request('GET',route,headers={'Authorization':'Bearer '+token} if token else {})
    r=c.getresponse();data=r.read();status=r.status;c.close();return status,data
ctx=ssl.create_default_context(cafile=str(base/'ca.crt'))
try:
    handshake=subprocess.check_output(['wg','show','bagage-vm','latest-handshakes']).decode().split()[1]
    if mode=='unknown':
        check('Pair WireGuard inconnu : aucun handshake Internet',int(handshake)==0)
        blocked=False
        try:req('10.77.0.1',8443,'/api/users',ctx)
        except (TimeoutError,ConnectionError,OSError) as error:
            if isinstance(error,ssl.SSLError):raise
            blocked=True
        check('Pair inconnu : HTTPS prive inaccessible',blocked)
    else:
        status,_=req('10.77.0.1',8443,'/api/users',ctx,token='jeton-de-test-invalide')
        check('VPN Internet valide : faux JWT refuse',status==401)
        endpoint=subprocess.check_output(['wg','show','bagage-vm','endpoints']).decode().split()[1]
        remote,port=endpoint.rsplit(':',1); remote=remote.strip('[]')
        allocated=json.loads((base/'public-wg-endpoint.json').read_text())['urls'][0]
        uri=urllib.parse.urlsplit(allocated)
        addresses={v[4][0] for v in socket.getaddrinfo(uri.hostname,uri.port,type=socket.SOCK_DGRAM)}
        check('Endpoint WireGuard : adresse publique du relais alloue',remote in addresses and ipaddress.ip_address(remote).is_global and int(port)==uri.port)
        check('Pair autorise : handshake Internet recent',int(subprocess.check_output(['wg','show','bagage-vm','latest-handshakes']).decode().split()[1])>0)
        rx,tx=map(int,subprocess.check_output(['wg','show','bagage-vm','transfer']).decode().split()[1:])
        check('WireGuard Internet : octets recus et envoyes',rx>0 and tx>0)
        target=json.loads((base/'internet-target.json').read_text(encoding='utf-8-sig')); public=urllib.parse.urlsplit(target['url']).hostname
        public_ctx=ssl.create_default_context()
        for route in ('/api/users','/api/vols','/api/bagages','/api/auth/login'):
            check('Scan HTTPS public : refus '+route,req(public,443,route,public_ctx)[0]==404)
        status,body=req(public,443,'/swagger/index.html',public_ctx)
        check('Scan HTTPS public : Swagger API non publie',status==404 or (status==200 and b'app-root' in body and b'SwaggerUIBundle' not in body and b'"openapi"' not in body))
finally:
    (base/('public-security-'+mode+'.json')).write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'mode':mode,'portee':'UDP alloue au projet et URL HTTPS du projet ; aucun scan autres ports fournisseur','checks':checks},indent=2))
