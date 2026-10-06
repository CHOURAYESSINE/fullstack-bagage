"""Relais UDP public temporaire ; seul le port WireGuard local est transmis."""
import datetime,json,pathlib,sys,time
root=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'work/tools/pinggy-sdk'))
import pinggy
base=root/'work/phase-04/public-wg';base.mkdir(parents=True,exist_ok=True)
stop=base/'stop'; stop.unlink(missing_ok=True)
pinggy.set_log_path(str(base/'native.log'))
tunnel=pinggy.start_udptunnel(forwardto='127.0.0.1:52820',webdebuggerport=0,serveraddress='free.pinggy.io:443',autoreconnect=False)
try:
    (base/'endpoint.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'urls':tunnel.urls,'localDestination':'127.0.0.1:52820','sdk':'pinggy 0.3.1'},indent=2))
    print('Relais UDP WireGuard pret',flush=True)
    deadline=time.monotonic()+900
    while tunnel.is_active() and time.monotonic()<deadline and not stop.exists():time.sleep(1)
finally:tunnel.stop()
