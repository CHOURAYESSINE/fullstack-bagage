const net=require('node:net'),dgram=require('node:dgram'),fs=require('node:fs');
const host=process.argv[2];
if(!net.isIPv4(host)||host==='0.0.0.0') throw new Error('Adresse IPv4 précise requise');
net.createServer(client=>{const upstream=net.connect(15443,'127.0.0.1');client.pipe(upstream);upstream.pipe(client);client.on('error',()=>upstream.destroy());upstream.on('error',()=>client.destroy());client.on('close',()=>upstream.destroy());}).listen(15443,host);
const udp=dgram.createSocket('udp4'),peers=new Map();
udp.on('message',(data,source)=>{if(process.argv[3])fs.writeFileSync(process.argv[3],JSON.stringify({address:source.address,port:source.port,dateUtc:new Date().toISOString()}));const key=source.address+':'+source.port;let peer=peers.get(key);if(!peer){peer=dgram.createSocket('udp4');peer.on('message',reply=>udp.send(reply,source.port,source.address));peer.on('error',()=>{});peers.set(key,peer);}peer.send(data,52820,'127.0.0.1');});
udp.bind(52820,host);
