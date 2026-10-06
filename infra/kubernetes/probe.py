"""Validation Kubernetes depuis des clients Docker externes au cluster. Aucune donnée privée affichée."""
import datetime, json, pathlib, secrets, socket, ssl, subprocess, sys, urllib.error, urllib.request

mode=sys.argv[1]
checks=[]
config=json.loads(pathlib.Path('/evidence/phase-04-targets.json').read_text(encoding='utf-8-sig'))
ctx=ssl.create_default_context(cafile='/tls/ca.crt')
ctx.minimum_version=ssl.TLSVersion.TLSv1_2
private='https://10.77.0.1:8443'
public='https://k3d-bagage-server-0:31443'
def check(label,condition):
    checks.append(dict(test=label,resultat='OK' if condition else 'ECHEC'))
    print(('OK' if condition else 'ECHEC')+' - '+label,flush=True)
    if not condition: raise RuntimeError(label)
def request(url,token=None,body=None,method=None):
    headers={'Content-Type':'application/json'}
    if token: headers['Authorization']='Bearer '+token
    req=urllib.request.Request(url,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
    try:
        with urllib.request.urlopen(req,context=ctx,timeout=4) as r: return r.status,r.read()
    except urllib.error.HTTPError as e: return e.code,e.read()
def blocked(host,port):
    try:
        with socket.create_connection((host,port),timeout=3): return False
    except (TimeoutError,ConnectionRefusedError): return True
def blocked_http(url,token):
    try: request(url,token); return False
    except (TimeoutError,ConnectionRefusedError): return True
    except urllib.error.URLError as e: return isinstance(e.reason,(TimeoutError,ConnectionRefusedError))
def tracking():
    demo=json.loads(pathlib.Path('/evidence/phase-04-demo.json').read_text())
    status,body=request(public+'/api/track/'+demo['trackingId'])
    data=json.loads(body)
    check('Suivi public reel : statut trie et historique conserves',status==200 and data['statut']=='trie' and len(data['historique'])==2)
    check('Suivi public sans identite du passager', 'nomPassager' not in data and 'volId' not in data and b'Passager Kube' not in body)

try:
    print('KUBERNETES - '+mode.upper()+' - '+datetime.datetime.now(datetime.timezone.utc).isoformat(),flush=True)
    if mode=='vpn':
        status,page=request(private)
        check('Interface Angular agents servie par le pod via WireGuard',status==200 and b'app-root' in page)
        check('Origine Angular reservee au VPN',json.loads(request(private+'/segment.json')[1])['allowedOrigins']==[private])
        status,body=request(private+'/api/auth/login',body=json.loads(pathlib.Path('/login/admin.json').read_text(encoding='utf-8-sig')))
        check('Connexion administrateur dans Kubernetes',status==200)
        token=json.loads(body)['accessToken']
        pathlib.Path('/exchange/jwt').write_text(token)
        check('JWT valide accepte via VPN',request(private+'/api/users',token)[0]==200)
        check('Sans JWT : refus applicatif 401 meme avec VPN',request(private+'/api/users')[0]==401)
        check('Administrateur sans privileges metier : creation vol refusee 403',request(private+'/api/vols',token,dict(numero='REFUS',origine='SFA',destination='CDG',departPrevu=datetime.datetime.now(datetime.timezone.utc).isoformat()))[0]==403)
        username='super.kube.'+secrets.token_hex(4)
        password='Aa1!'+secrets.token_hex(20)
        check('Creation superviseur avec role explicite',request(private+'/api/users',token,dict(login=username,password=password,role='Superviseur'))[0]==201)
        status,body=request(private+'/api/auth/login',body=dict(login=username,password=password))
        check('Connexion superviseur',status==200)
        supervisor=json.loads(body)['accessToken']
        status,body=request(private+'/api/vols',supervisor,dict(numero='K4'+secrets.token_hex(4).upper(),origine='SFA',destination='CDG',departPrevu=(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=1)).isoformat()))
        check('Creation vol persiste dans PostgreSQL Kubernetes',status==201)
        vol=json.loads(body)
        status,body=request(private+'/api/bagages',supervisor,dict(volId=vol['id'],nomPassager='Passager Kube Fictif',poidsKg=19))
        check('Enregistrement bagage et code aleatoire',status==201)
        bag=json.loads(body)
        check('Transition enregistre vers trie',request(private+'/api/bagages/'+bag['id']+'/statut',supervisor,dict(statut='trie'),method='PATCH')[0]==200)
        check('Historique prive accessible au superviseur',request(private+'/api/bagages/'+bag['id']+'/historique',supervisor)[0]==200)
        pathlib.Path('/evidence/phase-04-demo.json').write_text(json.dumps(bag,indent=2))
        tracking()
        handshake=subprocess.check_output(['wg','show','wg0','latest-handshakes'],text=True).split()
        check('Handshake WireGuard reel avec le pod Kubernetes',len(handshake)>1 and int(handshake[1])>0)
        with socket.create_connection(('10.77.0.1',8443),timeout=4) as s:
            with ctx.wrap_socket(s,server_hostname='10.77.0.1') as t:
                check('Certificat agents valide et TLS 1.2 ou 1.3',t.version() in ('TLSv1.2','TLSv1.3'))
    elif mode in ('outside','off'):
        token=pathlib.Path('/exchange/jwt').read_text()
        check('Meme JWT : API agents inaccessible sans tunnel',blocked_http(private+'/api/users',token))
        check('Pod agents inaccessible directement sur HTTPS',blocked(config['agents'],8443))
        check('Pod API inaccessible directement avec JWT',blocked_http('http://'+config['api']+':8080/api/users',token))
        check('Service ClusterIP API inaccessible avec JWT',blocked_http('http://'+config['apiService']+':8080/api/users',token))
        check('PostgreSQL inaccessible depuis le client externe',blocked(config['db'],5432))
        check('Frontend public accessible en HTTPS sans VPN',request(public)[0]==200)
        for route in ('users','vols','bagages','auth/login'):
            check('Proxy public refuse /api/'+route+' meme avec JWT',request(public+'/api/'+route,token)[0]==404)
        tracking()
        with socket.create_connection(('k3d-bagage-server-0',31443),timeout=4) as s:
            with ctx.wrap_socket(s,server_hostname='k3d-bagage-server-0') as t:
                check('Certificat public verifie avec la CA du cluster',t.version() in ('TLSv1.2','TLSv1.3'))
    elif mode=='restored':
        token=pathlib.Path('/exchange/jwt').read_text()
        check('Tunnel retabli : meme JWT accepte a nouveau',request(private+'/api/users',token)[0]==200)
    elif mode=='persistence':
        tracking()
    else: raise ValueError('Mode inconnu')
finally:
    pathlib.Path('/evidence/phase-04-'+mode+'.json').write_text(json.dumps(dict(dateUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),checks=checks),indent=2))
