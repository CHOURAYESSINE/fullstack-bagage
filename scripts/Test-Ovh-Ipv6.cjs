const https=require('node:https'),net=require('node:net'),fs=require('node:fs'),path=require('node:path');
const host='2001:41d0:305:2100::1:80c6',server='vps-8e16b3fe.vps.ovh.net';const checks=[];
function check(test,ok){checks.push({test,resultat:ok?'OK':'ECHEC'});console.log(`${ok?'OK':'ECHEC'} - ${test}`);if(!ok)throw Error(test);}
function request(route){return new Promise((resolve,reject)=>{const r=https.get({hostname:host,servername:server,port:443,path:route,headers:{Host:server},timeout:8000},res=>{const trusted=res.socket.authorized;res.resume();res.on('end',()=>resolve({trusted,status:res.statusCode}));});r.on('timeout',()=>r.destroy(Error('IPv6 inaccessible')));r.on('error',reject);});}
function closed(port){return new Promise(resolve=>{const s=net.connect({host,port,family:6});s.setTimeout(1500);s.once('connect',()=>{s.destroy();resolve(false);});s.once('error',()=>resolve(true));s.once('timeout',()=>{s.destroy();resolve(true);});});}
(async()=>{try{
 const r=await request('/');check('Site public accessible en IPv6 avec TLS reconnu',r.trusted&&r.status===200);
 for(const port of [5432,8080,8443,5005,6443,16443,31443,31820])check('Port TCP IPv6 ferme '+port,await closed(port));
 for(const route of ['users','bagages','vols','auth/login'])check('Route privee refusee sur IPv6 '+route,(await request('/api/'+route)).status===404);
}finally{fs.writeFileSync(path.resolve(__dirname,'../docs/preuves/ovh-ipv6.json'),JSON.stringify({dateUtc:new Date().toISOString(),checks},null,2));}})().catch(e=>{console.error(e.message);process.exitCode=1;});
