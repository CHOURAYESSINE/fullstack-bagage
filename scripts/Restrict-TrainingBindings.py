"""Reconstitue les trois services actifs dans un compose privé, ports locaux."""
import json, pathlib, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
names=['training_pfe-frontend-1','training_pfe-backend-1','training_pfe-db-1']
items=json.loads(subprocess.check_output(['docker','inspect',*names]))
document={'services':{},'volumes':{},'networks':{}}
for item in items:
    c=item['Config']; h=item['HostConfig']; name=c['Labels']['com.docker.compose.service']
    service={'image':c['Image'],'container_name':item['Name'].lstrip('/'),'environment':c.get('Env',[]),'networks':{},'volumes':[],'ports':[]}
    for source,target in [('Cmd','command'),('Entrypoint','entrypoint'),('User','user'),('WorkingDir','working_dir')]:
        if c.get(source): service[target]=c[source]
    if c.get('Healthcheck'):
        hc=c['Healthcheck']; service['healthcheck']={'test':hc['Test']}
        for source,target in [('Interval','interval'),('Timeout','timeout'),('StartPeriod','start_period')]:
            if hc.get(source): service['healthcheck'][target]=str(hc[source])+'ns'
        if hc.get('Retries'):service['healthcheck']['retries']=hc['Retries']
    restart=h.get('RestartPolicy',{}).get('Name')
    if restart and restart!='no':service['restart']=restart
    for network,info in item['NetworkSettings']['Networks'].items():
        document['networks'][network]={'external':True,'name':network}
        service['networks'][network]={'aliases':info.get('Aliases') or [name]}
    for mount in item['Mounts']:
        if mount['Type']=='volume':
            key=mount['Name']; document['volumes'][key]={'external':True,'name':key}; source=key
        elif mount['Type']=='bind':source=mount['Source']
        else:raise RuntimeError('Type montage non pris en charge')
        service['volumes'].append(source+':'+mount['Destination']+('' if mount['RW'] else ':ro'))
    for target,bindings in (h.get('PortBindings') or {}).items():
        for binding in bindings or []:
            service['ports'].append('127.0.0.1:'+binding['HostPort']+':'+target)
    document['services'][name]=service
output=root/'work/phase-04/training-loopback.compose.json'
output.write_text(json.dumps(document,indent=2),encoding='utf-8')
print('Compose prive cree depuis les conteneurs actifs ; volumes et configuration conserves.')
