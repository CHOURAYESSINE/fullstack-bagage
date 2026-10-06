"""Lecture HTTPS publique via Internet depuis une VM, CA système vérifiée."""
import datetime, json, pathlib, platform, ssl, sys, urllib.request, urllib.error
base=pathlib.Path('/home/bagagetest/bagage-validation')
target=json.loads((base/'internet-target.json').read_text(encoding='utf-8-sig'))
url=target['url']; checks=[]; ctx=ssl.create_default_context()
if hasattr(ssl,'TLSVersion'): ctx.minimum_version=ssl.TLSVersion.TLSv1_2
else: ctx.options |= ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1
def get(route):
    try:
        with urllib.request.urlopen(url+route,context=ctx,timeout=20) as response:
            return response.status,response.read()
    except urllib.error.HTTPError as error: return error.code,error.read()
def check(label,ok):
    checks.append({'test':label,'resultat':'OK' if ok else 'ECHEC'})
    print(('OK' if ok else 'ECHEC')+' - '+label,flush=True)
    if not ok: raise RuntimeError(label)
try:
    print('VM Ubuntu '+platform.node()+' : HTTPS public via Internet, sans WireGuard',flush=True)
    status,body=get('/')
    check('Interface Angular Internet avec certificat systeme verifie',status==200 and b'app-root' in body)
    status,body=get('/api/track/'+target['trackingId']); data=json.loads(body)
    check('Suivi reel Kubernetes via Internet',status==200 and data['statut']=='trie' and len(data['historique'])==2)
    check('Suivi Internet sans identite personnelle','nomPassager' not in data and 'volId' not in data)
    for route in ('users','vols','bagages','auth/login'):
        check('Internet : route privee refusee '+route,get('/api/'+route)[0]==404)
finally:
    (base/'internet.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'client':platform.node(),'url':url,'portee':'HTTPS public via Internet ; VM sur meme hote physique','checks':checks},indent=2))
