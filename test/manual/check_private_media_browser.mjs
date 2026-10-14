import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
const origin=process.env.FIXTURE_ORIGIN;
const out=process.env.MEDIA_ARTIFACTS;
const cdp='http://127.0.0.1:9348';
await mkdir(out,{recursive:true});
const page=await(await fetch(`${cdp}/json/new?about:blank`,{method:'PUT'})).json();
const ws=new WebSocket(page.webSocketDebuggerUrl);
await new Promise(r=>ws.addEventListener('open',r,{once:true}));
let id=0;const pending=new Map(),errors=[],external=[],results=[];
ws.addEventListener('message',({data})=>{const m=JSON.parse(data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p?.reject(Error(m.error.message)):p?.resolve(m.result);}if(m.method==='Runtime.exceptionThrown') errors.push(m.params.exceptionDetails.text);if(m.method==='Network.requestWillBeSent'&&!m.params.request.url.startsWith(origin)&&/^https?:/.test(m.params.request.url)) external.push(m.params.request.url);});
const send=(method,params={})=>new Promise((resolve,reject)=>{pending.set(++id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,returnByValue:true,userGesture:true});assert.equal(r.exceptionDetails,undefined,JSON.stringify(r.exceptionDetails));return r.result.value;}
async function text(){return evaluate('(document.body?.textContent ?? "") + [...document.querySelectorAll("[aria-label]")].map(n=>n.getAttribute("aria-label")).join("\\n")');}
async function waitText(label){for(let i=0;i<100;i++){if((await text()).includes(label))return;await delay(100);}throw Error(`Missing ${label}: ${await text()}`);}
async function click(label){await waitText(label);const ok=await evaluate(`(()=>{const n=[...document.querySelectorAll('[role=button],flt-semantics[flt-tappable]')].find(n=>n.textContent.trim()===${JSON.stringify(label)}||n.getAttribute('aria-label')===${JSON.stringify(label)});if(!n)return false;n.scrollIntoView({block:'center'});n.click();return true})()`);assert.equal(ok,true,`Missing button ${label}: ${await text()}`);await delay(150);}
async function screenshot(name){const r=await send('Page.captureScreenshot',{format:'png'});await writeFile(`${out}/${name}.png`,Buffer.from(r.data,'base64'));}
async function navigate(width=390,theme='light',large=false){await send('Emulation.setDeviceMetricsOverride',{width,height:844,deviceScaleFactor:1,mobile:false});await send('Page.navigate',{url:`${origin}/?theme=${theme}&text=${large?'large':'normal'}`});await waitText('G26 private media fixture');await delay(200);}
await send('Page.enable');await send('Runtime.enable');await send('Network.enable');
await send('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:'/tmp/g26-downloads'});
try{
 for(const theme of process.env.MEDIA_BUYER==='1'?['light']:['light','dark']) for(const width of [320,390,768,1440]){
  await navigate(width,theme);await waitText('View video');await waitText('Download');await screenshot(`cards-${width}-${theme}`);results.push({width,theme,cards:true});
 }
 await navigate(320,'light',true);await screenshot('large-text');await click('View video');await waitText('Play');await screenshot('large-text-viewer');results.push({largeText:true});
 assert.equal(await evaluate('(()=>{const roots=[document];for(const root of roots)for(const n of root.querySelectorAll("*"))if(n.shadowRoot)roots.push(n.shadowRoot);return roots.flatMap(r=>[...r.querySelectorAll("video")]);})().every(v=>v.paused)'),true);
 await click('Play');await delay(350);assert.equal(await evaluate('(()=>{const roots=[document];for(const root of roots)for(const n of root.querySelectorAll("*"))if(n.shadowRoot)roots.push(n.shadowRoot);return roots.flatMap(r=>[...r.querySelectorAll("video")]);})().some(v=>v.currentTime>0)'),true);await click('Pause');
 await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
 await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
 await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
 await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});await delay(200);
 assert.equal(await evaluate('(()=>{const roots=[document];for(const root of roots)for(const n of root.querySelectorAll("*"))if(n.shadowRoot)roots.push(n.shadowRoot);return roots.flatMap(r=>[...r.querySelectorAll("video")]);})().length'),0);results.push({playback:'no autoplay/play/pause/Escape disposal'});
 await navigate();await send('Emulation.setDeviceMetricsOverride',{width:390,height:400,deviceScaleFactor:1,mobile:false});await click('View video');await waitText('Play');await screenshot('short-viewer');await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:195,y:225,deltaY:150,deltaX:0});await delay(200);await screenshot('short-viewer-controls');await click('Play');await delay(200);await click('Pause');await click('Close');results.push({shortViewport:true,scrollableControls:true});
 await navigate();await click('Download');await waitText('Download requested');results.push({download:true});
 await click('Probe oversized');await waitText('Probe safely rejected');results.push({boundedStream:true});
 await navigate();await click('Probe redirect');await waitText('Probe safely rejected');results.push({redirectDenied:true});
 await navigate();await click('View video');await waitText('Play');await click('Close');await click('End access');assert.equal((await text()).includes('View video'),false);assert.equal((await text()).includes('Download requested'),false);results.push({scopeCleanup:true});
 const stats=await(await fetch(`${origin}/fixture-stats`)).json();assert.equal(stats.trap,0);assert.equal(stats.unauthorized,0);assert.ok(stats.authorized>0);
 assert.deepEqual(errors,[]);assert.ok(external.every(url => /^https:\/\/(?:www|fonts)\.gstatic\.com\/(?:flutter-canvaskit|s\/roboto)\//.test(url)), JSON.stringify(external));
 await writeFile(`${out}/results.json`,JSON.stringify({passed:true,results,stats,errors,rendererAssets:external,externalMediaRequests:0},null,2));
 process.stdout.write(JSON.stringify({passed:true,checks:results.length,stats,rendererAssetRequests:external.length})+'\n');
}finally{await send('Page.close');ws.close();}
