"""Configuration OVH séparée du laboratoire ; secrets créés seulement sur le serveur."""
import json, secrets
from pathlib import Path
root = Path(__file__).resolve().parents[1]
out = root / 'work/phase-05'
out.mkdir(parents=True, exist_ok=True)
credential = out / 'credentials.json'
if not credential.exists():
    credential.write_text(json.dumps({k: secrets.token_hex(32) for k in ('owner','app','jwt','password')} | {'login': 'admin.ovh'}))
s = json.loads(credential.read_text())
(out/'login').mkdir(exist_ok=True)
(out/'login/admin.json').write_text(json.dumps({'login':s['login'],'password':'Aa1!'+s['password']}))
(out/'db.env').write_text(f'POSTGRES_DB=bagage\nPOSTGRES_USER=bagage_owner\nPOSTGRES_PASSWORD={s["owner"]}\nBAGAGE_APP_PASSWORD={s["app"]}\n')
(out/'api.env').write_text(f'ConnectionStrings__Bagage=Host=db;Database=bagage;Username=bagage_app;Password={s["app"]}\nJwt__Key={s["jwt"]}\n')
(out/'migration.env').write_text(f'ConnectionStrings__Bagage=Host=db;Database=bagage;Username=bagage_owner;Password={s["owner"]}\nJwt__Key={s["jwt"]}\nBootstrap__Login={s["login"]}\nBootstrap__Password=Aa1!{s["password"]}\n')
config = json.loads((root/'infra/kubernetes/00-config.json').read_text(encoding='utf-8-sig'))
for item in config['items']:
    if item['metadata']['name'] == 'public-nginx':
        item['data']['default.conf'] = item['data']['default.conf'].replace('localhost:15443', 'vps-8e16b3fe.vps.ovh.net').replace('server_name localhost 127.0.0.1;', 'server_name vps-8e16b3fe.vps.ovh.net;')
(out/'00-config.json').write_text(json.dumps(config))
init = (root/'infra/network/init-secrets.sh').read_text().replace('Endpoint = 127.0.0.1:51820', 'Endpoint = 141.94.20.50:52820').replace('Endpoint = 172.26.41.2:51820', 'Endpoint = 141.94.20.50:52820')
(out/'init-secrets.sh').write_text(init)
