// Run only against the synthetic Flutter fixture and an isolated Chromium
// debugging profile. Never attach this driver to a signed-in user browser.
import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

const debuggerOrigin = 'http://localhost:9334';
const page = await (await fetch(`${debuggerOrigin}/json/new?about:blank`, { method: 'PUT' })).json();
assert.ok(page, 'The isolated browser must have a page');
const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolve) => socket.addEventListener('open', resolve, { once: true }));
const pending = new Map();
const errors = [];
let sequence = 0, apiRequests = 0, credentialRequests = 0;
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const operation = pending.get(message.id);
    if (operation) {
      pending.delete(message.id);
      if (message.error) operation.reject(message.error);
      else operation.resolve(message.result);
    }
  }
  if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails.text);
  if (message.method === 'Network.requestWillBeSent') {
    const request = message.params.request;
    if (request.url.startsWith('https://api.example')) apiRequests++;
    if (Object.keys(request.headers).some((key) => key.toLowerCase() === 'authorization')) credentialRequests++;
  }
});
function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const result = await send('Runtime.evaluate', { expression, returnByValue: true });
  assert.equal(result.exceptionDetails, undefined, 'Fixture inspection must succeed');
  return result.result.value;
}
const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
async function click(x, y) {
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
}

async function labels() {
  return evaluate("document.body.innerText + '\\n' + [...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\\n')");
}
async function waitFor(check) {
  for (let i=0;i<100;i++) {
    if (await check()) return;
    await delay(300);
  }
  throw new Error('Timed out: '+await labels());
}
async function action(label) {
  const found=await evaluate(`(() => {
    const node=[...document.querySelectorAll('[role=button],button,[aria-label]')].find(e=>(e.getAttribute('aria-label')||e.textContent||'').trim()===${JSON.stringify(label)});
    if(!node) return false;
    node.click(); return true;
  })()`);
  assert.ok(found, 'Missing action: '+label);
  await delay(500);
}
try {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {width:390,height:844,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate', {url:'http://localhost:8766'});
  await waitFor(async()=> (await labels()).includes('Open pin'));
  await action('Open pin');
  await waitFor(()=>evaluate("!!document.querySelector('.maplibregl-canvas')"));
  const state=await evaluate(`(() => {
    const map=document.querySelector('.maplibregl-map');
    const style=getComputedStyle(map);
    const b=map.getBoundingClientRect();
    return {isolation:style.isolation,zIndex:style.zIndex,height:b.height,width:b.width};
  })()`);
  assert.equal(state.isolation,'isolate');
  assert.equal(state.zIndex,'0');
  assert.equal(state.height,300);
  assert.ok(state.width<=390);
  assert.ok(!(await labels()).match(/latitude|longitude|14\.6|121|coordinates/i));
  // Real map click must remain usable with Flutter semantics enabled.
  const bounds=await evaluate(`(() => {const b=document.querySelector('.maplibregl-map').getBoundingClientRect();return {x:b.x,y:b.y,width:b.width,height:b.height};})()`);
  await waitFor(async()=>!(await labels()).includes('Loading address map'));
  await click(bounds.x+bounds.width/2+15,bounds.y+bounds.height/2+15);
  await waitFor(async()=> (await labels()).includes('Adjusted pin'));
  const screenshot = await send('Page.captureScreenshot', {format:'png'});
  await writeFile('build/address-pin-browser.png', Buffer.from(screenshot.data, 'base64'));
  await action('Confirm pin');
  await waitFor(async()=> (await labels()).includes('Pin confirmed'));
  assert.equal(await evaluate("document.querySelectorAll('.maplibregl-canvas').length"),0);
  await action('Open pin');
  await waitFor(()=>evaluate("!!document.querySelector('.maplibregl-canvas')"));
  await action('Cancel pin');
  await waitFor(async()=> (await labels()).includes('Pin cancelled'));
  assert.equal(await evaluate("document.querySelectorAll('.maplibregl-canvas').length"),0);
  assert.deepEqual(errors,[]);
  console.log(JSON.stringify({state,hiddenCoordinates:true,mapTap:true,confirm:true,cancel:true}));
} finally {
  socket.close();
  await fetch(`${debuggerOrigin}/json/close/${page.id}`);
}
