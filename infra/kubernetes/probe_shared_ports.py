"""Scan TCP limité aux ports autorisés du poste partagé depuis une vraie VM."""
import socket, pathlib, json, datetime, sys, platform
host=sys.argv[1]; checks=[]
for port in (80,5432,8080,5005):
    try:
        with socket.create_connection((host,port),timeout=4): closed=False
    except (ConnectionRefusedError,TimeoutError,OSError): closed=True
    checks.append({'port':port,'test':'Port partage inaccessible depuis VM','resultat':'OK' if closed else 'ECHEC'})
    print(('OK' if closed else 'ECHEC')+' - '+host+':'+str(port)+' inaccessible depuis VM',flush=True)
pathlib.Path('/home/bagagetest/shared-ports.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':platform.node(),'destination':host,'portee':'IPv4 depuis NAT VMware, pas scan Internet distant','checks':checks},indent=2))
sys.exit(0 if all(c['resultat']=='OK' for c in checks) else 1)
