import datetime,json,pathlib,subprocess
checks=[]
def run(*args):return subprocess.check_output(args,text=True).strip()
def kube(*args):return run('docker','exec','k3d-bagage-server-0','kubectl',*args)
def check(name,ok):
    checks.append({'test':name,'resultat':'OK' if ok else 'ECHEC'})
    print(('OK' if ok else 'ECHEC')+' - '+name,flush=True)
    if not ok:raise RuntimeError(name)
try:
    pods=json.loads(kube('-n','bagage','get','pods','-o','json'))['items']
    for app in ('api','public','agents','db'):
        p=next(p for p in pods if p['metadata']['labels'].get('app')==app)
        check(app+' : pod pret',any(c['type']=='Ready' and c['status']=='True' for c in p['status']['conditions']))
        check(app+' : conteneurs applicatifs non-root',all(c['securityContext'].get('runAsNonRoot') for c in p['spec']['containers']))
        check(app+' : systeme de fichiers applicatif en lecture seule',all(c['securityContext'].get('readOnlyRootFilesystem') for c in p['spec']['containers']))
        check(app+' : aucun jeton de service account monte',p['spec'].get('automountServiceAccountToken') is False)
    services=json.loads(kube('-n','bagage','get','services','-o','json'))['items']
    for name in ('api','db','agents'):
        check(name+' : service ClusterIP prive',next(s for s in services if s['metadata']['name']==name)['spec']['type']=='ClusterIP')
    policy=json.loads(kube('-n','bagage','get','networkpolicy','deny-by-default','-o','json'))
    check('Policy refuse par defaut ingress et egress presente',set(policy['spec']['policyTypes'])=={'Ingress','Egress'} and not policy['spec'].get('ingress') and not policy['spec'].get('egress'))
    ssh=run('sshd','-T')
    check('SSH par cle uniquement et root interdit','passwordauthentication no' in ssh and 'permitrootlogin no' in ssh and 'kbdinteractiveauthentication no' in ssh)
    for timer in ('bagage-backup.timer','certbot.timer'):check(timer+' actif',run('systemctl','is-active',timer)=='active')
    check('Sauvegarde privee presente',any(p.stat().st_size>0 for p in pathlib.Path('/opt/fullstack-bagage/work/phase-05/backups').glob('*.dump')))
    check('Pare-feu UFW actif','Status: active' in run('ufw','status'))
    sql="SELECT NOT has_database_privilege('bagage_app','bagage','CREATE') AND NOT has_table_privilege('bagage_app','historique_statuts','UPDATE') AND NOT has_table_privilege('bagage_app','historique_statuts','DELETE') AND has_table_privilege('bagage_app','historique_statuts','INSERT');"
    check('Droits DB : historique ajout seul, sans CREATE',kube('-n','bagage','exec','db-0','--','psql','-U','bagage_owner','-d','bagage','-tAc',sql)=='t')
finally:
    pathlib.Path('/opt/fullstack-bagage/ovh-infrastructure.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checks':checks},indent=2))
