import http.client,ssl,json,pathlib,socket,sys,urllib.parse
base=pathlib.Path(sys.argv[2] if len(sys.argv)>2 else '/home/yessine/bagage-validation');mode=sys.argv[1]
host=sys.argv[3] if len(sys.argv)>3 else '10.182.160.74'
public_url=sys.argv[4] if len(sys.argv)>4 else None
ctx=ssl.create_default_context(cafile=str(base/'ca.crt'));checks=[]
def check(label,ok):
 checks.append({'test':label,'resultat':'OK' if ok else 'ECHEC'});print(('OK' if ok else 'ECHEC')+' - '+label,flush=True)
 if not ok:raise RuntimeError(label)
def req(route,token=None,payload=None):
 c=http.client.HTTPSConnection('10.77.0.1',8443,context=ctx,timeout=5);headers={}
 if token:headers['Authorization']='Bearer '+token
 if payload:headers['Content-Type']='application/json'
 c.request('POST' if payload else 'GET',route,body=json.dumps(payload) if payload else None,headers=headers);r=c.getresponse();status=r.status;body=r.read();c.close();return status,body
try:
 if mode=='vpn':
  status,body=req('/');check('VM : interface agents accessible avec TLS verifie',status==200 and b'app-root' in body)
  credentials=json.loads((base/'credentials.json').read_text(encoding='utf-8-sig'));status,body=req('/api/auth/login',payload={'login':credentials['login'],'password':credentials['password']})
  check('VM : authentification dans le tunnel',status==200);data=json.loads(body);token=data.get('token') or data.get('accessToken');assert token
  (base/'jwt').write_text(token);(base/'jwt').chmod(0o600)
  check('VM : JWT accepte sur API privee',req('/api/users',token)[0]==200)
  check('VM : sans JWT acces prive refuse',req('/api/users')[0]==401)
 elif mode=='off':
  token=(base/'jwt').read_text();blocked=False
  try:req('/api/users',token)
  except (TimeoutError,ConnectionError,OSError) as error:
   if isinstance(error,ssl.SSLError):raise
   blocked=True
  check('VM : meme JWT inaccessible apres coupure VPN',blocked)
  class PublicConnection(http.client.HTTPSConnection):
   def connect(self):
    self.sock=ctx.wrap_socket(socket.create_connection((host,15443),timeout=5),server_hostname='localhost')
  for route in ('/','/api/users','/api/vols','/api/bagages','/api/auth/login'):
   c=http.client.HTTPSConnection(urllib.parse.urlsplit(public_url).hostname,context=ssl.create_default_context(),timeout=15) if public_url else PublicConnection('localhost',15443,context=ctx)
   c.request('GET',route,headers={'Authorization':'Bearer '+token});r=c.getresponse();body=r.read();check('VM sans VPN : '+route+' avec meme JWT',r.status==(200 if route=='/' else 404));c.close()
 elif mode=='restored':
  check('VM : meme JWT accepte apres retablissement',req('/api/users',(base/'jwt').read_text())[0]==200)
finally:
 (base/('vpn-'+mode+'.json')).write_text(json.dumps({'client':'VMware Ubuntu reelle','mode':mode,'checks':checks},indent=2))
