import assert from 'node:assert/strict';
import {mkdir, mkdtemp, readFile, readdir, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';

const origin = process.env.FIXTURE_ORIGIN;
const out = resolve(process.env.MEDIA_ARTIFACTS);
const cdp = process.env.MEDIA_CDP ?? 'http://127.0.0.1:9348';
const expectedDocument = process.env.MEDIA_EXPECTED_DOCUMENT;
assert.match(origin, /^http:\/\/localhost:876[56]$/);
await mkdir(out, {recursive: true});
const downloads = await mkdtemp(`${out}/downloads-`);
const page = await (await fetch(`${cdp}/json/new?about:blank`, {method: 'PUT'})).json();
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r, {once: true}));
let id = 0;
const pending = new Map(), errors = [], results = [];
const network = {authorizedApi: 0, unauthenticatedApi: 0, preflights: 0, leakedAuthorization: 0, responses: {}};
ws.addEventListener('message', ({data}) => {
  const m = JSON.parse(data);
  if (m.id) {
    const p = pending.get(m.id); pending.delete(m.id);
    m.error ? p?.reject(Error(m.error.message)) : p?.resolve(m.result);
  }
  if (m.method === 'Runtime.exceptionThrown') errors.push(m.params.exceptionDetails.text);
  if (m.method === 'Network.requestWillBeSent') {
    const r = m.params.request;
    const bearer = Object.keys(r.headers).some(k => k.toLowerCase() === 'authorization');
    if (r.url.startsWith('http://localhost:18026/api/v1/')) {
      if (r.method === 'OPTIONS') network.preflights++;
      else network[bearer ? 'authorizedApi' : 'unauthenticatedApi']++;
    } else if (bearer) network.leakedAuthorization++;
  }
  if (m.method === 'Network.responseReceived' && m.params.response.url.startsWith('http://localhost:18026/api/v1/')) {
    const status = m.params.response.status;
    network.responses[status] = (network.responses[status] ?? 0) + 1;
  }
});
const send = (method, params = {}) => new Promise((resolve, reject) => {
  pending.set(++id, {resolve, reject}); ws.send(JSON.stringify({id, method, params}));
});
const delay = ms => new Promise(r => setTimeout(r, ms));
async function evaluate(expression) {
  const r = await send('Runtime.evaluate', {expression, returnByValue: true, userGesture: true});
  assert.equal(r.exceptionDetails, undefined, 'Browser evaluation failed');
  return r.result.value;
}
async function text() {
  return evaluate('(document.body?.textContent ?? "") + [...document.querySelectorAll("[aria-label]")].map(n=>n.getAttribute("aria-label")).join("\\n")');
}
async function waitText(label) {
  for (let i = 0; i < 400; i++) {
    if ((await text()).includes(label)) return;
    await delay(100);
  }
  throw Error(`Missing fixture state: ${label}`);
}
async function click(label) {
  await waitText(label);
  const ok = await evaluate(`(()=>{const n=[...document.querySelectorAll('[role=button],flt-semantics[flt-tappable]')].find(n=>n.textContent.trim()===${JSON.stringify(label)}||n.getAttribute('aria-label')===${JSON.stringify(label)});if(!n)return false;n.scrollIntoView({block:'center'});n.click();return true})()`);
  assert.equal(ok, true, `Missing fixture control: ${label}`);
  await delay(200);
}
const videos = '(()=>{const roots=[document];for(const root of roots)for(const n of root.querySelectorAll("*"))if(n.shadowRoot)roots.push(n.shadowRoot);return roots.flatMap(r=>[...r.querySelectorAll("video")]);})()';
async function screenshot(name) {
  const r = await send('Page.captureScreenshot', {format: 'png'});
  await writeFile(`${out}/${name}.png`, Buffer.from(r.data, 'base64'));
}
try {
  await send('Page.enable'); await send('Runtime.enable'); await send('Network.enable');
  await send('Browser.setDownloadBehavior', {behavior: 'allow', downloadPath: downloads});
  for (const width of [320, 390, 768, 1440]) {
    await send('Emulation.setDeviceMetricsOverride', {width, height: 844, deviceScaleFactor: 1, mobile: false});
    await send('Page.navigate', {url: origin});
    await waitText('Authenticated runtime ready'); await waitText('View video'); await waitText('Download');
    await screenshot(`runtime-${width}`);
    results.push({width, authenticatedCards: true});
  }
  await click('Verify image send'); await waitText('Image sent and replay verified');
  results.push({realImageUploadSendReplay: true});
  await click('View video'); await waitText('Play');
  assert.equal(await evaluate(`${videos}.length`), 1);
  assert.equal(await evaluate(`${videos}.every(v=>v.paused)`), true);
  await screenshot('runtime-player');
  await click('Play'); await delay(400);
  assert.equal(await evaluate(`${videos}.some(v=>v.currentTime>0)`), true);
  await click('Pause');
  const beforeSeek = await evaluate(`${videos}[0].currentTime`);
  // Seek through the production Flutter Slider's accessibility action.
  const focused = await evaluate(`(()=>{const n=document.querySelector('[role=slider]');if(!n)return false;n.focus();return true})()`);
  assert.equal(focused, true, 'Video seek slider unavailable');
  for (const type of ['keyDown', 'keyUp']) await send('Input.dispatchKeyEvent', {type, key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39});
  await delay(200);
  assert.ok(await evaluate(`${videos}[0].currentTime`) > beforeSeek, 'Keyboard seek did not advance playback position');
  for (const type of ['keyDown', 'keyUp']) await send('Input.dispatchKeyEvent', {type, key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27});
  await delay(300);
  assert.equal(await evaluate(`${videos}.length`), 0);
  results.push({video: 'real received MP4, no autoplay, play/pause/seek/Escape disposal'});
  const existingDownloads = new Set(await readdir(downloads));
  await click('Download'); await waitText('Download requested');
  let saved;
  for (let i = 0; i < 100 && !saved; i++) {
    saved = (await readdir(downloads)).find(n => n.endsWith('.pdf') && !existingDownloads.has(n));
    if (!saved) await delay(100);
  }
  assert.ok(saved, 'Browser download did not finish');
  assert.deepEqual(await readFile(`${downloads}/${saved}`), await readFile(expectedDocument));
  results.push({realDocumentDownloadByteMatch: true});
  await click('Sign out'); await waitText('Runtime signed out');
  // The live-region announcement can outlast its removed source widget briefly.
  for (let i = 0; i < 30 && (await text()).includes('details.pdf'); i++) await delay(100);
  assert.equal((await text()).includes('View video'), false);
  assert.equal((await text()).includes('details.pdf'), false);
  assert.equal(await evaluate(`${videos}.length`), 0);
  results.push({actualBearerLogoutAndPrivateScopeCleanup: true});
  assert.deepEqual(errors, []);
  assert.ok(network.authorizedApi > 0);
  assert.equal(network.unauthenticatedApi, 0);
  assert.equal(network.leakedAuthorization, 0);
  await writeFile(`${out}/results.json`, JSON.stringify({passed: true, results, network, errors}, null, 2) + '\n');
  process.stdout.write(JSON.stringify({passed: true, checks: results.length, network}) + '\n');
} catch (error) {
  await screenshot('failure');
  const leaves = await evaluate(`([...document.querySelectorAll('*')].filter(n=>n.childElementCount===0 && ((n.textContent??'').includes('details.pdf') || (n.getAttribute('aria-label')??'').includes('details.pdf'))).map(n=>({tag:n.tagName,role:n.getAttribute('role'),text:n.textContent,aria:n.getAttribute('aria-label')})))`);
  await writeFile(`${out}/cleanup-diagnostic.json`, JSON.stringify(leaves, null, 2));
  throw error;
} finally {
  await send('Page.close'); ws.close();
}
