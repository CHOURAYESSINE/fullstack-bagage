"""Complément Windows : tous les ports ciblés, connexion liée à l'interface USB."""
import datetime,http.client,json,pathlib,socket,ssl,sys
root=pathlib.Path(__file__).resolve().parents[1]
target=(root/'work/phase-04/home-public-ip.txt').read_text().strip()
mobile=(root/'work/phase-04/mobile-public-ip.txt').read_text().strip()
source=sys.argv[1];checks=[]
c=http.client.HTTPSConnection('api.ipify.org',context=ssl.create_default_context(),source_address=(source,0),timeout=12)
c.request('GET','/');response=c.getresponse();observed=response.read().decode().strip();c.close()
if observed!=mobile or observed==target: raise RuntimeError('Sortie mobile non confirmee ; aucun scan effectue')
for port in (80,5432,8080,5005):
    s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.settimeout(5);s.bind((source,0))
    try:s.connect((target,port));closed=False
    except (TimeoutError,ConnectionRefusedError,OSError):closed=True
    finally:s.close()
    result={'port':port,'resultat':'OK' if closed else 'ECHEC','test':'Port inaccessible via Internet mobile'}
    checks.append(result);print(result['resultat']+' - TCP '+str(port)+' inaccessible via Internet mobile',flush=True)
(root/'docs/preuves/mobile-windows-scan-complet.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'client':'Windows socket lie a interface USB mobile','sortieMobileVerifiee':True,'adressesPubliquesMasquees':True,'checks':checks},indent=2))
sys.exit(0 if all(c['resultat']=='OK' for c in checks) else 1)
