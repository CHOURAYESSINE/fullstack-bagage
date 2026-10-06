"""Scan Internet autorisé du routeur domestique, via la sortie mobile vérifiée."""
import json,pathlib,socket,urllib.request,datetime,ipaddress,sys
base=pathlib.Path('/home/bagagetest')
target=json.loads((base/'internet-private-target.json').read_text())
home=target['home']; mobile=target['mobile']; checks=[]
def check(label,ok,fatal=True):
    checks.append({'test':label,'resultat':'OK' if ok else 'ECHEC'})
    print(('OK' if ok else 'ECHEC')+' - '+label,flush=True)
    if not ok and fatal:raise RuntimeError(label)
try:
    with urllib.request.urlopen('https://api.ipify.org',timeout=15) as response: source=response.read().decode().strip()
    check('Adresse cible domestique publique',ipaddress.ip_address(home).is_global)
    check('Sortie VM identique a la sortie mobile observee',source==mobile)
    check('Sortie mobile differente de la sortie domestique',source!=home)
    for port in (80,5432,8080,5005):
        try:
            with socket.create_connection((home,port),timeout=5): closed=False
        except (ConnectionRefusedError,TimeoutError,OSError):closed=True
        check('Port TCP '+str(port)+' inaccessible via Internet mobile',closed,fatal=False)
finally:
    (base/'internet-scan.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'portee':'Scan TCP limite du point entree domestique depuis sortie Internet mobile verifiee','adressesPubliquesMasquees':True,'checks':checks},indent=2))
sys.exit(0 if all(c['resultat']=='OK' for c in checks) else 1)
