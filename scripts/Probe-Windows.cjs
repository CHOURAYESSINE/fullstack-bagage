// Client natif Windows : chaîne et nom TLS vérifiés avec la CA locale explicite.
const fs=require('node:fs');
const path=require('node:path');
const https=require('node:https');
const net=require('node:net');
const root=path.resolve(__dirname,'..');
const mode=process.argv[2]||'public';
const ca=fs.readFileSync(path.join(root,'work/phase-04/pki/ca.crt'));
const checks=[];
const publicUrl='https://localhost:15443';
const privateUrl='https://10.77.0.1:8443';
const tokenFile=path.join(root,'work/phase-04/windows/jwt');
function check(test,ok){checks.push({test,resultat:ok?'OK':'ECHEC'});console.log(`${ok?'OK':'ECHEC'} - ${test}`);if(!ok)throw new Error(test);}
function request(url,token,body,trust=ca){return new Promise((resolve,reject)=>{
  const payload=body?JSON.stringify(body):undefined;
  const headers={};if(token)headers.Authorization='Bearer '+token;
  if(payload){headers['Content-Type']='application/json';headers['Content-Length']=Buffer.byteLength(payload);}
  const req=https.request(url,{ca:trust,method:payload?'POST':'GET',headers,timeout:5000},res=>{
    const protocol=res.socket.getProtocol();const authorized=res.socket.authorized;
    const chunks=[];res.on('data',c=>chunks.push(c));res.on('end',()=>resolve({status:res.statusCode,body:Buffer.concat(chunks).toString(),protocol,authorized}));
  });req.on('error',reject);req.on('timeout',()=>req.destroy(Object.assign(new Error('Timeout réseau'),{code:'ETIMEDOUT'})));req.end(payload);
});}
async function inaccessible(url,token){try{await request(url,token);return false;}catch(e){return ['ETIMEDOUT','ECONNREFUSED','ECONNRESET','EHOSTUNREACH','ENETUNREACH'].includes(e.code);}}
function closed(port){return new Promise(resolve=>{const s=net.connect({host:'127.0.0.1',port});s.setTimeout(1500);s.once('connect',()=>{s.destroy();resolve(false);});s.once('error',()=>resolve(true));s.once('timeout',()=>{s.destroy();resolve(true);});});}
async function publicChecks(){
  const page=await request(publicUrl);check('HTTPS public natif Windows : interface Angular disponible',page.status===200&&page.body.includes('app-root'));
  check('Certificat et nom verifies avec CA explicite',page.authorized);
  check('Negociation TLS moderne depuis Windows',['TLSv1.2','TLSv1.3'].includes(page.protocol));
  let rejected=false;try{await request(publicUrl,null,null,null);}catch(e){rejected=['UNABLE_TO_VERIFY_LEAF_SIGNATURE','UNABLE_TO_GET_ISSUER_CERT_LOCALLY','SELF_SIGNED_CERT_IN_CHAIN','DEPTH_ZERO_SELF_SIGNED_CERT'].includes(e.code);}
  check('Sans CA locale : certificat refuse normalement',rejected);
  const demo=JSON.parse(fs.readFileSync(path.join(root,'docs/preuves/phase-04-demo.json'),'utf8').replace(/^\uFEFF/,''));
  const track=await request(publicUrl+'/api/track/'+demo.trackingId);const data=JSON.parse(track.body);
  check('Suivi reel depuis Windows : trie et deux evenements',track.status===200&&data.statut==='trie'&&data.historique.length===2);
  check('Suivi sans identite personnelle',!('nomPassager' in data)&&!('volId' in data));
  check('Proxy public refuse la connexion privee',(await request(publicUrl+'/api/auth/login')) .status===404);
  for(const port of [18080,14200,14201])check(`Ancien port HTTP ${port} ferme sur Windows`,await closed(port));
}
(async()=>{
  try{
    if(mode==='public'){await publicChecks();}
    else if(mode==='vpn'){
      const page=await request(privateUrl);check('Interface agents accessible par VPN Windows',page.status===200&&page.authorized&&page.body.includes('app-root'));
      const s=JSON.parse(fs.readFileSync(path.join(root,'work/phase-04/credentials.json'),'utf8').replace(/^\uFEFF/,''));
      const login=await request(privateUrl+'/api/auth/login',null,{login:s.login,password:s.password});
      check('Authentification depuis Windows dans le tunnel',login.status===200);
      const token=JSON.parse(login.body).accessToken;fs.writeFileSync(tokenFile,token);
      check('JWT valide accepte sur VPN Windows',(await request(privateUrl+'/api/users',token)).status===200);
      check('Sans JWT : refus 401 meme sur VPN Windows',(await request(privateUrl+'/api/users')).status===401);
    }else if(mode==='off'){
      const token=fs.readFileSync(tokenFile,'utf8');
      check('Meme JWT : API privee inaccessible VPN Windows coupe',await inaccessible(privateUrl+'/api/users',token));
      check('Interface agents inaccessible VPN Windows coupe',await inaccessible(privateUrl));
      check('Suivi public reste accessible sans VPN',(await request(publicUrl)).status===200);
      for(const route of ['users','vols','bagages','auth/login'])check(`Proxy public refuse ${route} avec le meme JWT`,(await request(publicUrl+'/api/'+route,token)).status===404);
    }else if(mode==='restored'){
      check('VPN Windows retabli : meme JWT accepte',(await request(privateUrl+'/api/users',fs.readFileSync(tokenFile,'utf8'))).status===200);
    }else throw new Error('Mode inconnu');
  }finally{fs.writeFileSync(path.join(root,'docs/preuves/phase-04-windows-'+mode+'.json'),JSON.stringify({dateUtc:new Date().toISOString(),client:process.platform+' / Node '+process.version,checks},null,2));}
})().catch(e=>{console.error('Validation interrompue : '+e.message);process.exitCode=1;});
