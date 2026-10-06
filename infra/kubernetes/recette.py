"""Recette métier réelle sur le déploiement Kubernetes, via le VPN de validation."""
import datetime,json,pathlib,secrets,ssl,urllib.request,urllib.error,time
checks=[]
ctx=ssl.create_default_context(cafile='/tls/ca.crt')
private='https://10.77.0.1:8443'
public='https://k3d-bagage-server-0:31443'
def check(name,ok):
    checks.append({'test':name,'resultat':'OK' if ok else 'ECHEC'})
    print(('OK' if ok else 'ECHEC')+' - '+name,flush=True)
    if not ok: raise RuntimeError(name)
def req(route,token=None,body=None,method=None,base=private):
    headers={'Content-Type':'application/json'}
    if token: headers['Authorization']='Bearer '+token
    r=urllib.request.Request(base+route,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
    try:
        with urllib.request.urlopen(r,context=ctx,timeout=10) as response:return response.status,response.read()
    except urllib.error.HTTPError as error:return error.code,error.read()
def login(data):
    status,body=req('/api/auth/login',body=data)
    check('Connexion '+data['role'] if 'role' in data else 'Connexion administrateur initial',status==200)
    return json.loads(body)['accessToken']
def patch(bag,status,token,motif=None):
    body={'statut':status}
    if motif:body['motif']=motif
    return req('/api/bagages/'+bag['id']+'/statut',token,body,'PATCH')
try:
    admin=login(json.loads(pathlib.Path('/login/admin.json').read_text(encoding='utf-8-sig')))
    tokens={}
    for role in ('Superviseur','AgentEnregistrement','AgentTri','Administrateur'):
        account={'login':'recette.'+secrets.token_hex(8),'password':'Aa1!'+secrets.token_hex(20),'role':role}
        check('Creation compte fictif '+role,req('/api/users',admin,account)[0]==201)
        tokens[role]=login(account)
    supervisor=tokens['Superviseur'];tri=tokens['AgentTri'];agent=tokens['AgentEnregistrement']
    flight={'numero':'RF'+secrets.token_hex(4).upper(),'origine':'SFA','destination':'CDG','departPrevu':(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=2)).isoformat()}
    status,body=req('/api/vols',supervisor,flight);check('Superviseur cree vol',status==201);vol=json.loads(body)
    check('Agent tri ne cree pas de vol',req('/api/vols',tri,flight)[0]==403)
    check('Administrateur sans droits metier',req('/api/bagages',tokens['Administrateur'])[0]==403)
    check('Superviseur sans gestion des comptes',req('/api/users',supervisor)[0]==403)
    check('Agent enregistrement sans liste globale',req('/api/bagages',agent)[0]==403)
    check('Sans JWT : API privee refusee',req('/api/bagages')[0]==401)
    forged=supervisor.rsplit('.',1)[0]+'.'+('A'*43)
    check('JWT signature falsifiee refuse',req('/api/bagages',forged)[0]==401)
    def create():
        status,body=req('/api/bagages',agent,{'volId':vol['id'],'nomPassager':'Passager Recette Fictif','poidsKg':20})
        check('Enregistrement bagage par role autorise',status==201);return json.loads(body)
    bag=create()
    check('Agent enregistrement sans mise a jour statut',patch(bag,'trie',agent)[0]==403)
    check('Saut etape agent tri refuse',patch(bag,'livre',tri)[0]==409)
    for state in ('trie','charge','en_vol','livre'):
        check('Cycle normal vers '+state,patch(bag,state,tri)[0]==200)
    check('Repetition meme statut refusee',patch(bag,'livre',tri)[0]==409)
    status,body=req('/api/bagages/'+bag['id']+'/historique',supervisor);history=json.loads(body)
    check('Historique complet : cinq evenements',status==200 and len(history)==5)
    check('Tracabilite : agent et date sur chaque evenement',all(row.get('agentId') and row.get('horodatage') for row in history))
    status,body=req('/api/track/'+bag['trackingId'],base=public);data=json.loads(body)
    check('Suivi public livre et cinq evenements',status==200 and data['statut']=='livre' and len(data['historique'])==5)
    check('Suivi public sans identite, motif ou agent',not any(key in body for key in (b'nomPassager',b'agentId',b'volId',b'motif',b'Passager Recette')))
    lost=create();check('Declaration perdu depuis enregistre',patch(lost,'perdu',tri)[0]==200)
    check('Recuperation sans motif superviseur refusee',patch(lost,'trie',supervisor)[0]==409)
    check('Recuperation motivee par superviseur',patch(lost,'trie',supervisor,'Correction fictive de recette')[0]==200)
    status,body=req('/api/bagages/'+lost['id']+'/historique',supervisor);history=json.loads(body)
    check('Anomalie conservee avec motif dans historique prive',status==200 and len(history)==3 and history[-1]['anomalie'] and history[-1]['motif']=='Correction fictive de recette')
    check('Filtrage par vol et statut',req('/api/bagages?volId='+vol['id']+'&statut=livre',tri)[0]==200)
    check('Poids invalide refuse',req('/api/bagages',agent,{'volId':vol['id'],'nomPassager':'Fictif','poidsKg':101})[0]==400)
    for route in ('users','vols','bagages','auth/login'):
        check('Public refuse '+route+' avec JWT valide',req('/api/'+route,supervisor,base=public)[0]==404)
    check('Ecriture suivi public interdite',req('/api/track/'+bag['trackingId'],supervisor,{'statut':'perdu'},'PATCH',public)[0]==403)
    check('Tracking malforme retourne 404',req('/api/track/invalide',base=public)[0]==404)
    print('Attente du renouvellement de la fenetre de limitation avant le test de verrouillage.',flush=True)
    time.sleep(30);time.sleep(30)
    locked={'login':'recette.lock.'+secrets.token_hex(8),'password':'Aa1!'+secrets.token_hex(20),'role':'AgentTri'}
    check('Compte fictif de verrouillage cree',req('/api/users',admin,locked)[0]==201)
    for attempt in range(5):check('Echec connexion '+str(attempt+1),req('/api/auth/login',body={'login':locked['login'],'password':'incorrect'})[0]==401)
    check('Verrouillage refuse mot de passe correct',req('/api/auth/login',body=locked)[0]==401)
    check('Limitation debit connexion',any(req('/api/auth/login',body={'login':'absent','password':'incorrect'})[0]==429 for _ in range(12)))
finally:
    pathlib.Path('/evidence/recette-metier.json').write_text(json.dumps({'dateUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'perimetre':'Kubernetes via vrai tunnel WireGuard Docker','checks':checks},indent=2))
