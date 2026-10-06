import datetime, json, pathlib, socket, ssl, subprocess, sys, urllib.error, urllib.request

mode = sys.argv[1]
checks = []
context = ssl.create_default_context(cafile='/tls/ca.crt')
context.minimum_version = ssl.TLSVersion.TLSv1_2
private = 'https://10.77.0.1:8443'
public = 'https://172.26.41.3:8443'

def check(label, condition):
    checks.append({'test': label, 'resultat': 'OK' if condition else 'ECHEC'})
    print(('OK' if condition else 'ECHEC') + ' - ' + label, flush=True)
    if not condition:
        raise RuntimeError(label)

def request(url, token=None, body=None, tls=context):
    headers = {'Content-Type': 'application/json'}
    if token: headers['Authorization'] = 'Bearer ' + token
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, context=tls, timeout=4) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()

def blocked(url, token):
    try:
        request(url, token)
        return False
    except (TimeoutError, ConnectionRefusedError):
        return True
    except urllib.error.URLError as e:
        # Un certificat invalide ne compte jamais comme preuve de filtrage réseau.
        return isinstance(e.reason, (TimeoutError, ConnectionRefusedError))

def tls_version(host):
    with socket.create_connection((host,8443),timeout=4) as s:
        with context.wrap_socket(s,server_hostname=host) as secure:
            return secure.version()

try:
    print('VALIDATION RESEAU - ' + mode.upper() + ' - ' + datetime.datetime.now(datetime.timezone.utc).isoformat(), flush=True)
    if mode == 'vpn':
        status, page = request(private)
        check('Interface agents HTTPS joignable par WireGuard', status == 200 and b'app-root' in page)
        check('Origine Angular limitee au VPN', json.loads(request(private+'/segment.json')[1])['allowedOrigins'] == [private])
        status, body = request(private+'/api/auth/login', body=json.loads(pathlib.Path('/login/admin.json').read_text(encoding='utf-8-sig')))
        check('Connexion JWT a travers le tunnel chiffre', status == 200)
        token = json.loads(body)['accessToken']
        pathlib.Path('/exchange/jwt').write_text(token)
        check('JWT valide : liste comptes autorisee sur VPN', request(private+'/api/users',token)[0] == 200)
        check('Sans JWT : API privee refusee en 401 meme sur VPN',request(private+'/api/users')[0] == 401)
        version = tls_version('10.77.0.1')
        check('Certificat agents verifie avec CA locale et TLS moderne',version in ('TLSv1.2','TLSv1.3'))
        handshake = subprocess.check_output(['wg','show','wg0','latest-handshakes'],text=True).split()
        check('Handshake WireGuard non nul',len(handshake)>=2 and int(handshake[1])>0)
        transfer = subprocess.check_output(['wg','show','wg0','transfer'],text=True).split()
        check('Octets WireGuard recus et emis',len(transfer)>=3 and int(transfer[1])>0 and int(transfer[2])>0)
        print('Transport TLS : '+version+' ; handshake actif ; cles et JWT masques.',flush=True)
    elif mode in ('outside','off'):
        token = pathlib.Path('/exchange/jwt').read_text()
        check('Meme JWT valide : API privee injoignable hors VPN',blocked(private+'/api/users',token))
        check('Frontend agents injoignable hors VPN, route forcee incluse',blocked(private,token))
        check('API directe privee inaccessible depuis edge',blocked('http://172.26.42.10:8080/api/users',token))
        check('API directe cote public inaccessible depuis edge',blocked('http://172.26.43.10:8080/api/users',token))
        check('HTTPS public disponible hors VPN',request(public)[0] == 200)
        for route in ('users','vols','bagages','auth/login'):
            check('Proxy public refuse /api/'+route+' avec JWT valide',request(public+'/api/'+route,token)[0] == 404)
        demo=json.loads(pathlib.Path('/evidence/phase-02-navigateur.json').read_text(encoding='utf-8-sig'))
        data=json.loads(request(public+'/api/track/'+demo['demonstration']['trackingId'])[1])
        check('Suivi public conserve sans identite personnelle', bool(data['historique']) and 'nomPassager' not in data and 'volId' not in data)
        check('Certificat public verifie et TLS moderne',tls_version('172.26.41.3') in ('TLSv1.2','TLSv1.3'))
        if mode=='outside':
            try:
                request(public,tls=ssl.create_default_context())
                rejected=False
            except urllib.error.URLError as e:
                rejected=isinstance(e.reason,ssl.SSLCertVerificationError)
            check('CA non approuvee : verification TLS refusee normalement',rejected)
            try:
                with socket.create_connection((sys.argv[2],5432),timeout=4): accessible=True
            except (TimeoutError,ConnectionRefusedError): accessible=False
            check('PostgreSQL injoignable depuis le reseau externe simule',not accessible)
    elif mode=='restored':
        token=pathlib.Path('/exchange/jwt').read_text()
        check('Tunnel retabli : le meme JWT redevient utilisable',request(private+'/api/users',token)[0]==200)
    else: raise ValueError('Mode inconnu')
finally:
    pathlib.Path('/evidence/phase-03-'+mode+'.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checks':checks},indent=2),encoding='utf8')
