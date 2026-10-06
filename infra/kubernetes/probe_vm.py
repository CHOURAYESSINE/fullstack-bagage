"""Tests depuis une vraie VM Linux, sans dÃ©sactiver la vÃ©rification TLS."""
import argparse, datetime, http.client, json, pathlib, platform, socket, ssl

p=argparse.ArgumentParser()
p.add_argument('--host',default='10.0.2.2')
p.add_argument('--port',type=int,default=15443)
p.add_argument('--ca',default='ca.crt')
p.add_argument('--demo',default='demo.json')
p.add_argument('--output',default='validation-vm.json')
p.add_argument('--jwt-file')
p.add_argument('--vpn',action='store_true')
p.add_argument('--host-ports',default='5432,8080,8443,18080,14201',help='Ports hote a verifier ; liste vide autorisee pour un hote partage, documenter les exclusions')
a=p.parse_args()
checks=[]
context=ssl.create_default_context(cafile=a.ca)
if hasattr(ssl, 'TLSVersion'):
    context.minimum_version=ssl.TLSVersion.TLSv1_2
else:
    context.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1

def check(label,value):
    checks.append(dict(test=label,resultat='OK' if value else 'ECHEC'))
    print(('OK' if value else 'ECHEC')+' - '+label,flush=True)
    if not value: raise RuntimeError(label)

class Connection(http.client.HTTPSConnection):
    def connect(self):
        s=socket.create_connection((a.host,a.port),timeout=5)
        # La connexion NAT vise l'hÃ´te Windows, identifiÃ© par le certificat localhost.
        self.sock=self._context.wrap_socket(s,server_hostname='localhost')

def public(route='/',token=None,ctx=context):
    c=Connection('localhost',a.port,context=ctx,timeout=5)
    headers={'Authorization':'Bearer '+token} if token else {}
    c.request('GET',route,headers=headers)
    protocol=c.sock.version()
    r=c.getresponse();body=r.read();status=r.status;c.close()
    return status,body,protocol

def closed(host,port):
    try:
        with socket.create_connection((host,port),timeout=3): return False
    except (TimeoutError,ConnectionRefusedError,OSError): return True

try:
    print('VALIDATION VM REELLE - '+platform.node()+' - '+platform.system(),flush=True)
    status,body,version=public()
    check('Interface publique Angular joignable depuis la VM',status==200 and b'app-root' in body)
    check('Certificat public verifie et TLS moderne',version in ('TLSv1.2','TLSv1.3'))
    try:
        public(ctx=ssl.create_default_context());rejected=False
    except ssl.SSLError as error:
        # Python 3.6 (Ubuntu 18.04) n'expose pas SSLCertVerificationError.
        if getattr(error, 'reason', '') != 'CERTIFICATE_VERIFY_FAILED': raise
        rejected=True
    check('Sans CA explicite : certificat refuse',rejected)
    demo=json.loads(pathlib.Path(a.demo).read_text(encoding='utf-8-sig'))
    status,body,_=public('/api/track/'+demo['trackingId'])
    data=json.loads(body)
    check('Bagage Kubernetes suivi depuis la VM',status==200 and data['statut']=='trie' and len(data['historique'])==2)
    check('Aucune identite personnelle dans le suivi','nomPassager' not in data and 'volId' not in data)
    token=pathlib.Path(a.jwt_file).read_text().strip() if a.jwt_file else None
    for route in ('users','vols','bagages','auth/login'):
        check('Proxy public refuse /api/'+route+(' avec JWT' if token else ''),public('/api/'+route,token)[0]==404)
    for port in (int(value) for value in a.host_ports.split(',') if value):
        check('Port prive hote '+str(port)+' ferme depuis VM',closed(a.host,port))
    if not a.vpn:
        check('HTTPS agents inaccessible sans VPN',closed('10.77.0.1',8443))
    else:
        c=http.client.HTTPSConnection('10.77.0.1',8443,context=context,timeout=5)
        c.request('GET','/');r=c.getresponse()
        check('Interface agents joignable avec WireGuard dans la VM',r.status==200 and b'app-root' in r.read());c.close()
        if token:
            c=http.client.HTTPSConnection('10.77.0.1',8443,context=context,timeout=5)
            c.request('GET','/api/users',headers={'Authorization':'Bearer '+token});r=c.getresponse()
            check('JWT valide accepte sur le tunnel VM',r.status==200);r.read();c.close()
finally:
    pathlib.Path(a.output).write_text(json.dumps(dict(dateUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),machine=platform.node(),systeme=platform.system(),client='VM reelle',jwtFourni=bool(a.jwt_file),vpnActifDeclare=a.vpn,portsHoteVerifies=a.host_ports,checks=checks),indent=2))
