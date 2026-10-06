"""Sonde externe pour l'adresse du VPS appartenant au projet ; aucune clé/JWT imprimée."""
import datetime,json,pathlib,socket,ssl,subprocess,sys,time,urllib.request,urllib.error
mode=sys.argv[1]; checks=[]
public='https://vps-8e16b3fe.vps.ovh.net'; private='https://10.77.0.1:8443'
ctx=ssl.create_default_context();ctx.load_verify_locations('/tls/ca.crt')
def check(name,ok):
    checks.append({'test':name,'resultat':'OK' if ok else 'ECHEC'})
    print(('OK' if ok else 'ECHEC')+' - '+name,flush=True)
    if not ok:raise RuntimeError(name)
def req(base,route,token=None,body=None):
    r=urllib.request.Request(base+route,data=json.dumps(body).encode() if body else None,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
    try:
        with urllib.request.urlopen(r,context=ctx,timeout=5) as response:return response.status,response.read()
    except urllib.error.HTTPError as error:return error.code,error.read()
def closed(host,port):
    try:
        with socket.create_connection((host,port),timeout=3):return False
    except (TimeoutError,OSError):return True
try:
    check('Site public HTTPS avec certificat reconnu',req(public,'/')[0]==200)
    if mode=='vpn':
        cred=json.loads(pathlib.Path('/login/admin.json').read_text())
        status,body=req(private,'/api/auth/login',body=cred)
        check('Connexion administrateur via WireGuard Internet direct',status==200)
        token=json.loads(body)['accessToken'];pathlib.Path('/exchange/jwt').write_text(token)
        check('API privee avec JWT autorise',req(private,'/api/users',token)[0]==200)
        check('Faux JWT refuse dans le VPN',req(private,'/api/users','invalide')[0]==401)
        check('Sans JWT refuse dans le VPN',req(private,'/api/users')[0]==401)
        handshake=int(subprocess.check_output(['wg','show','wg0','latest-handshakes']).decode().split()[1])
        check('Handshake WireGuard recent',handshake>0 and time.time()-handshake<180)
        check('Endpoint WireGuard direct OVH',subprocess.check_output(['wg','show','wg0','endpoints']).decode().split()[1]=='141.94.20.50:52820')
    else:
        token=pathlib.Path('/exchange/jwt').read_text()
        if mode=='unknown':
            check('Pair WireGuard inconnu : API privee inaccessible',closed('10.77.0.1',8443))
            handshake=int(subprocess.check_output(['wg','show','wg0','latest-handshakes']).decode().split()[1])
            check('Pair WireGuard inconnu : aucun handshake',handshake==0)
        if mode=='off':check('API privee inaccessible hors VPN avec le meme JWT',closed('10.77.0.1',8443))
        if mode=='restored':check('Meme JWT accepte apres retablissement du VPN',req(private,'/api/users',token)[0]==200)
    for route in ('users','bagages','vols','auth/login'):
        check('Route publique privee refusee '+route,req(public,'/api/'+route,token)[0]==404)
    if mode=='off':
        for port in (5432,8080,8443,5005,6443,16443,31443,31820):check('Port TCP OVH ferme '+str(port),closed('141.94.20.50',port))
        status,body=req(public,'/swagger/index.html')
        check('Swagger non publie',status==404 or (status==200 and b'app-root' in body and b'swagger-ui' not in body))
finally:
    pathlib.Path('/evidence/ovh-internet-'+mode+'.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'perimetre':'VPS OVH distant reel ; client Docker sur PC Windows','checks':checks},indent=2))
