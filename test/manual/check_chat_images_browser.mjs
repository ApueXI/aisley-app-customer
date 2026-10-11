// Synthetic Flutter widget checks only. No real accounts or backend traffic.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
const origin=process.env.FIXTURE_ORIGIN??'http://127.0.0.1:8885';
const cdp=process.env.CDP_ORIGIN??'http://127.0.0.1:9337';
const out=process.env.MEDIA_ARTIFACTS??'build/chat-images-evidence';
const buyer=process.env.MEDIA_BUYER==='1';
await mkdir(out,{recursive:true});
const page=await(await fetch(`${cdp}/json/new?about:blank`,{method:'PUT'})).json();
const ws=new WebSocket(page.webSocketDebuggerUrl);await new Promise(r=>ws.addEventListener('open',r,{once:true}));
let id=0;const pending=new Map(),errors=[],results=[],external=[];
ws.addEventListener('message',({data})=>{const m=JSON.parse(data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p?.reject(Error(m.error.message)):p?.resolve(m.result);}if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.text);if(m.method==='Network.requestWillBeSent'&&!m.params.request.url.startsWith(origin)&&/^https?:/.test(m.params.request.url))external.push(m.params.request.url);});
const send=(method,params={})=>new Promise((resolve,reject)=>{pending.set(++id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,returnByValue:true});assert.equal(r.exceptionDetails,undefined);return r.result.value;}
async function text(){return evaluate('(document.body?.textContent ?? "") + [...document.querySelectorAll("[aria-label]")].map(n=>n.getAttribute("aria-label")).join("\\n")');}
async function waitText(label){for(let i=0;i<80;i++){if((await text()).includes(label))return;if(i>5&&i%8===0)await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:150,y:600,deltaY:180,deltaX:0});await delay(150);}throw Error(`Missing ${label}: ${await text()}`);}
async function click(label){const expression=`(()=>{const n=[...document.querySelectorAll('[role=button],flt-semantics[flt-tappable]')].find(n=>n.textContent.trim()===${JSON.stringify(label)}||n.getAttribute('aria-label')===${JSON.stringify(label)});if(!n)return false;n.scrollIntoView({block:'center'});n.click();return true})()`;for(let i=0;i<10;i++){if(await evaluate(expression)){await delay(200);return;}await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:150,y:600,deltaY:350,deltaX:0});await delay(150);}throw Error(`Missing control ${label}: ${await text()}`);}
async function screenshot(name){const r=await send('Page.captureScreenshot',{format:'png'});await writeFile(`${out}/${name}.png`,Buffer.from(r.data,'base64'));}
async function navigate(scenario,width=390,theme='light',large=false,role='shop'){
 await send('Emulation.setDeviceMetricsOverride',{width,height:844,deviceScaleFactor:1,mobile:false});
 await send('Page.navigate',{url:`${origin}/?scenario=${scenario}&theme=${theme}&text=${large?'large':'normal'}&role=${role}`});
 await waitText(scenario==='dashboard'?'Courier dashboard':'Private chat images');await delay(250);
 assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth'),true);
}
await send('Page.enable');await send('Runtime.enable');await send('Network.enable');
try{
 for(const theme of buyer?['light']:['light','dark'])for(const width of [320,390,768,1440]){
  await navigate('normal',width,theme);await click('Add image');await waitText('Ready to send');
  await screenshot(`selected-${width}-${theme}`);await click('Send message');await waitText('Confirmed sends: 1');
  results.push({width,theme,images:'selected/sent'});
 }
 await navigate('normal',320,'light',true);await click('Add image');await waitText('Ready to send');await screenshot('large-text');results.push({largeText:true});
 await navigate('normal');await click('View Chat photo.png');await waitText('Close');await screenshot('image-viewer');await click('Close');results.push({viewer:'opened/closed'});
 for(const role of buyer?['shop','logistics','courier']:['logistics','seller','customer']){
  await navigate('lost',390,'light',false,role);await click('Add image');await waitText('Ready to send');await click('Send message');await waitText('Message unconfirmed');await click('Retry exact message');await waitText('Confirmed sends: 1');results.push({role,lostResponse:'frozen exact retry controls'});
 }
 await navigate('disabled');await click('Add image');await waitText('Image uploads are unavailable');results.push({disabled:'text remains available'});
 await navigate('upload_lost');await click('Add image');await waitText('Upload unconfirmed');await click('Retry / check image');await waitText('Ready to send');results.push({uploadRetry:true});
 await navigate('checking');await click('Add image');await waitText('Checking image');await waitText('Ready to send');results.push({processing:true});
 await navigate('offline');await waitText('Image unavailable');results.push({offlinePlaceholder:true});
 if(!buyer)for(const theme of ['light','dark'])for(const width of [320,390,768,1440]){await navigate('dashboard',width,theme);await waitText('Available work');await screenshot(`dashboard-${width}-${theme}`);results.push({dashboard:true,width,theme});}
 if(!buyer){await navigate('dashboard',320,'dark',true);await waitText('Available work');await screenshot('dashboard-large-text');results.push({dashboard:true,largeText:true});}
 assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
 await writeFile(`${out}/results.json`,JSON.stringify({passed:true,results,externalRequests:external,errors},null,2));
 process.stdout.write(JSON.stringify({passed:true,checks:results.length,externalRequests:external.length})+'\n');
}finally{await send('Page.close');ws.close();}
