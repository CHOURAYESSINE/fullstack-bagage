"""Construit des manifests Kubernetes JSON sans secret, à partir des configurations du projet."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = Path(__file__).parent
ns = 'bagage'
def obj(kind, name, **fields):
    version = 'apps/v1' if kind in ('Deployment','StatefulSet') else 'batch/v1' if kind == 'Job' else 'networking.k8s.io/v1' if kind == 'NetworkPolicy' else 'v1'
    return dict(apiVersion=version, kind=kind, metadata=dict(name=name, namespace=ns), **fields)
def write(name, items):
    (out/name).write_text(json.dumps(dict(apiVersion='v1',kind='List',items=items),indent=2)+'\n',encoding='utf8')
def cm(name, data): return obj('ConfigMap',name,data=data)
def read(path): return (root/path).read_text(encoding='utf-8-sig')
def volume(name, typ, source): return dict(name=name, **{typ:source})
def mount(name, path, sub=None):
    return dict(name=name,mountPath=path,**({'subPath':sub} if sub else {}))
def secret_env(name): return [dict(secretRef=dict(name=name))]
def hardened(uid): return dict(runAsNonRoot=True,runAsUser=uid,runAsGroup=uid,allowPrivilegeEscalation=False,readOnlyRootFilesystem=True,capabilities=dict(drop=['ALL']))
def container(name,image,uid,**extra):
    return dict(name=name,image=image,imagePullPolicy='IfNotPresent',securityContext=hardened(uid),resources=dict(requests=dict(cpu='50m',memory='64Mi'),limits=dict(cpu='1000m',memory='512Mi')),**extra)
def deployment(name, containers, volumes, **extra):
    return obj('Deployment',name,spec=dict(replicas=1, strategy=dict(type='Recreate'),selector=dict(matchLabels=dict(app=name)),template=dict(metadata=dict(labels=dict(app=name)),spec=dict(automountServiceAccountToken=False,securityContext=dict(seccompProfile=dict(type='RuntimeDefault')),containers=containers,volumes=volumes,**extra))))
def service(name, app, port, target=None, node=None, protocol='TCP'):
    p=dict(name=protocol.lower(),port=port,targetPort=target or port,protocol=protocol)
    if node: p['nodePort']=node
    return obj('Service',name,spec=dict(type='NodePort' if node else 'ClusterIP',selector=dict(app=app),ports=[p]))
def probe(command): return dict(exec=dict(command=command),initialDelaySeconds=5,periodSeconds=10,timeoutSeconds=4,failureThreshold=12)

server = read('infra/network/server.sh').split("echo 'WireGuard")[0]
public = read('infra/network/public-tls.conf').replace('localhost:14443','localhost:15443')
configs = [cm('db-init',{'010-app-role.sh':read('database/docker-init.sh'),'permissions.sql':read('database/002_runtime_permissions.sql')}),cm('public-nginx',{'default.conf':public}),cm('agents-nginx',{'default.conf':read('infra/network/agents-tls.conf'),'segment.json':read('infra/network/segment-vpn.json')}),cm('vpn-init',{'setup.sh':server})]
namespace=dict(apiVersion='v1',kind='Namespace',metadata=dict(name=ns,labels={'project':'fullstack-bagage'}))
write('00-config.json',[namespace]+configs)

db=container('db','postgres:16',999,envFrom=secret_env('db-secret'),env=[dict(name='PGDATA',value='/var/lib/postgresql/data/pgdata')],volumeMounts=[mount('data','/var/lib/postgresql/data'),mount('tmp','/tmp'),mount('run','/var/run/postgresql'),mount('init','/docker-entrypoint-initdb.d/010-app-role.sh','010-app-role.sh'),mount('init','/setup/permissions.sql','permissions.sql')],readinessProbe=probe(['pg_isready','-U','bagage_owner','-d','bagage']))
database=obj('StatefulSet','db',spec=dict(serviceName='db',replicas=1,selector=dict(matchLabels=dict(app='db')),template=dict(metadata=dict(labels=dict(app='db')),spec=dict(automountServiceAccountToken=False,securityContext=dict(fsGroup=999,seccompProfile=dict(type='RuntimeDefault')),containers=[db],volumes=[volume('tmp','emptyDir',{}),volume('run','emptyDir',{}),volume('init','configMap',dict(name='db-init',defaultMode=365))])),volumeClaimTemplates=[dict(metadata=dict(name='data'),spec=dict(accessModes=['ReadWriteOnce'],storageClassName='local-path',resources=dict(requests=dict(storage='2Gi'))))]))
write('10-database.json',[service('db','db',5432),database])
for name, arg in [('migrate','--migrate'),('bootstrap','--bootstrap-admin')]:
    c=container(name,'fullstack-bagage-api:phase04',1654,args=[arg],envFrom=secret_env('migration-secret'),volumeMounts=[mount('tmp','/tmp')])
    write('20-'+name+'.json',[obj('Job',name,spec=dict(backoffLimit=0,template=dict(metadata=dict(labels=dict(app=name)),spec=dict(restartPolicy='Never',automountServiceAccountToken=False,securityContext=dict(seccompProfile=dict(type='RuntimeDefault')),containers=[c],volumes=[volume('tmp','emptyDir',{})]))))])

api=container('api','fullstack-bagage-api:phase04',1654,envFrom=secret_env('api-secret'),env=[dict(name='ASPNETCORE_ENVIRONMENT',value='Production'),dict(name='ASPNETCORE_HTTP_PORTS',value='8080')],volumeMounts=[mount('tmp','/tmp')],readinessProbe=dict(httpGet=dict(path='/health/ready',port=8080),periodSeconds=5),livenessProbe=dict(httpGet=dict(path='/health/live',port=8080),periodSeconds=15,initialDelaySeconds=20))
items=[service('api','api',8080),deployment('api',[api],[volume('tmp','emptyDir',{})])]
for name in ('public','agents'):
    vols=[volume('tmp','emptyDir',{}),volume('config','configMap',dict(name=name+'-nginx')),volume('tls','secret',dict(secretName=name+'-tls',defaultMode=288))]
    mounts=[mount('tmp','/tmp'),mount('config','/etc/nginx/conf.d/default.conf','default.conf'),mount('tls','/tls')]
    if name=='agents': mounts.append(mount('config','/usr/share/nginx/html/segment.json','segment.json'))
    c=container(name,'fullstack-bagage-'+name+':latest',101,volumeMounts=mounts,readinessProbe=probe(['wget','-q','-O','/dev/null','http://127.0.0.1:8080/healthz']))
    extra={}
    if name=='agents':
        vols += [volume('wg','secret',dict(secretName='wireguard-server',defaultMode=256)),volume('setup','configMap',dict(name='vpn-init',defaultMode=365))]
        extra['initContainers']=[dict(name='wireguard',image='fullstack-bagage-network-tools:latest',imagePullPolicy='IfNotPresent',command=['sh','/setup/setup.sh'],securityContext=dict(runAsUser=0,allowPrivilegeEscalation=False,readOnlyRootFilesystem=True,capabilities=dict(drop=['ALL'],add=['NET_ADMIN'])),volumeMounts=[mount('wg','/wireguard'),mount('setup','/setup'),mount('tmp','/tmp')])]
    d=deployment(name,[c],vols,**extra)
    d['spec']['template']['spec']['securityContext']['fsGroup']=101
    items += [d,service(name,name,8443,node=31443 if name=='public' else None)]
items.append(service('wireguard','agents',51820,node=31820,protocol='UDP'))
write('30-applications.json',items)

policies=[obj('NetworkPolicy','deny-by-default',spec=dict(podSelector={},policyTypes=['Ingress','Egress']))]
policies.append(obj('NetworkPolicy','dns',spec=dict(podSelector={},policyTypes=['Egress'],egress=[dict(to=[dict(namespaceSelector=dict(matchLabels={'kubernetes.io/metadata.name':'kube-system'}),podSelector=dict(matchLabels={'k8s-app':'kube-dns'}))],ports=[dict(protocol=p,port=53) for p in ('UDP','TCP')])])))
def ingress(name, app, ports, peers=None):
    rule=dict(ports=[dict(protocol=proto,port=p) for p,proto in ports])
    if peers is not None: rule['from']=[dict(podSelector=dict(matchLabels=dict(app=a))) for a in peers]
    return obj('NetworkPolicy',name,spec=dict(podSelector=dict(matchLabels=dict(app=app)),policyTypes=['Ingress'],ingress=[rule]))
policies += [ingress('public-https','public',[(8443,'TCP')]),ingress('vpn-udp','agents',[(51820,'UDP')]),ingress('api-from-proxies','api',[(8080,'TCP')],['public','agents']),ingress('database-from-api-and-migrations','db',[(5432,'TCP')],['api','migrate','bootstrap'])]
for source,target,port in [('public','api',8080),('agents','api',8080),('api','db',5432),('migrate','db',5432),('bootstrap','db',5432)]:
    policies.append(obj('NetworkPolicy',source+'-to-'+target,spec=dict(podSelector=dict(matchLabels=dict(app=source)),policyTypes=['Egress'],egress=[dict(to=[dict(podSelector=dict(matchLabels=dict(app=target)))],ports=[dict(protocol='TCP',port=port)])])))
write('05-network-policies.json',policies)
print('Manifests sans secrets générés : ConfigMap, StatefulSet/PVC, Jobs, Deployments, Services et NetworkPolicy.')
