const fs=require('node:fs');
const https=require('node:https');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const ca=fs.readFileSync(path.join(root,'work/phase-05/pki/ca.crt'));
const demo=JSON.parse(fs.readFileSync(path.join(root,'docs/preuves/ovh-demo.json')));
const checks=[];
function check(test,ok){checks.push({test,resultat:ok?'OK':'ECHEC'});console.log(`${ok?'OK':'ECHEC'} - ${test}`);if(!ok)throw Error(test);}
function request(url,body,trust){return new Promise((resolve,reject)=>{
 const payload=body?JSON.stringify(body):null;
 const req=https.request(url,{ca:trust,method:payload?'POST':'GET',timeout:8000,headers:payload?{'Content-Type':'application/json'}:{}},res=>{
  const authorized=res.socket.authorized;const protocol=res.socket.getProtocol();let data='';
  res.on('data',c=>data+=c);res.on('end',()=>resolve({status:res.statusCode,data,authorized,protocol}));
 });req.on('timeout',()=>req.destroy(Error('Timeout')));req.on('error',reject);req.end(payload);
});}
(async()=>{
 try {
  const publicResult=await request('https://vps-8e16b3fe.vps.ovh.net/api/track/'+demo.trackingId);
  check('HTTPS public reconnu apres redemarrage',publicResult.authorized&&publicResult.status===200);
  const data=JSON.parse(publicResult.data);
  check('Bagage et historique conserves apres redemarrage',data.statut==='trie'&&data.historique.length===2);
  check('Suivi public sans identite du passager',!publicResult.data.includes('nomPassager'));
  const privateResult=await request('https://10.77.0.1:8443/api/users',null,ca);
  check('TLS prive verifie via VPN Windows',privateResult.authorized&&privateResult.status===401);
  const admin=JSON.parse(fs.readFileSync(path.join(root,'work/phase-05/login/admin.json')));
  const login=await request('https://10.77.0.1:8443/api/auth/login',admin,ca);
  check('Connexion administrateur native Windows apres redemarrage',login.status===200&&!!JSON.parse(login.data).accessToken);
 } finally { fs.writeFileSync(path.join(root,'docs/preuves/ovh-windows.json'),JSON.stringify({dateUtc:new Date().toISOString(),checks},null,2)); }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
