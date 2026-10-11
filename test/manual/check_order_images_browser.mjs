// Actual Flutter Order screens with synthetic transport; no live API/account.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';

const origin = process.env.FIXTURE_ORIGIN ?? 'http://127.0.0.1:8766';
const cdp = process.env.CDP_ORIGIN ?? 'http://127.0.0.1:9345';
const out = process.env.ORDER_IMAGE_ARTIFACTS ?? 'build/order-images-evidence';
await mkdir(out, { recursive: true });
const page = await (await fetch(`${cdp}/json/new?about:blank`, { method: 'PUT' })).json();
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(resolve => ws.addEventListener('open', resolve, { once: true }));
let id = 0;
const pending = new Map(), errors = [], external = [], results = [];
ws.addEventListener('message', ({ data }) => {
  const message = JSON.parse(data);
  if (message.id) {
    const task = pending.get(message.id);
    pending.delete(message.id);
    message.error ? task?.reject(Error(message.error.message)) : task?.resolve(message.result);
  }
  if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails.text);
  if (message.method === 'Runtime.consoleAPICalled') {
    const text = message.params.args.map(arg => arg.value ?? arg.description ?? '').join(' ');
    if (/overflowed by|EXCEPTION CAUGHT BY WIDGETS|EXCEPTION CAUGHT BY RENDERING/.test(text)) errors.push(text);
  }
  if (message.method === 'Network.requestWillBeSent') {
    const url = message.params.request.url;
    if (/^https?:/.test(url) && !url.startsWith(origin)) external.push(url);
  }
});
const send = (method, params = {}) => new Promise((resolve, reject) => {
  pending.set(++id, { resolve, reject });
  ws.send(JSON.stringify({ id, method, params }));
});
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function evaluate(expression) {
  const response = await send('Runtime.evaluate', { expression, returnByValue: true });
  assert.equal(response.exceptionDetails, undefined);
  return response.result.value;
}
async function text() {
  return evaluate(String.raw`(document.body?.textContent ?? '') + [...document.querySelectorAll('[aria-label]')].map(node => node.getAttribute('aria-label')).join('\n')`);
}
async function waitText(label) {
  for (let i = 0; i < 100; i++) {
    if ((await text()).includes(label)) return;
    if (i > 10 && i % 10 === 0) {
      await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 150, y: 600, deltaY: 200, deltaX: 0 });
    }
    await delay(100);
  }
  throw Error(`Missing ${label}: ${await text()}`);
}
async function click(label) {
  const result = await evaluate(`(() => {
    const node = [...document.querySelectorAll('[role=button],flt-semantics[flt-tappable]')]
      .find(node => node.textContent.trim() === ${JSON.stringify(label)} || node.getAttribute('aria-label') === ${JSON.stringify(label)});
    if (!node) return false;
    node.scrollIntoView({block:'center'}); node.click(); return true;
  })()`);
  assert.equal(result, true, `Control ${label}`);
  await delay(250);
}
async function screenshot(name) {
  const response = await send('Page.captureScreenshot', { format: 'png' });
  await writeFile(`${out}/${name}.png`, Buffer.from(response.data, 'base64'));
}
async function navigate(kind, screen, width = 390, large = false) {
  await send('Emulation.setDeviceMetricsOverride', { width, height: 844, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url: `${origin}/?scenario=${kind}&page=${screen}&text=${large ? 'large' : 'normal'}` });
  await waitText(kind === 'loading' ? 'Purchased Product' : 'Product image:');
  await delay(400);
  assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth'), true);
}
await send('Page.enable');
await send('Runtime.enable');
await send('Network.enable');
try {
  for (const screen of ['history', 'detail']) {
    for (const width of [320, 390, 768, 1440]) {
      await navigate('normal', screen, width);
      await screenshot(`${screen}-${width}`);
      results.push({ screen, width, state: 'image' });
    }
    await navigate('long', screen, 320, true);
    await screenshot(`${screen}-large-long`);
    results.push({ screen, width: 320, largeText: true, longName: true });
    for (const kind of ['missing', 'broken', 'corrupt', 'foreign']) {
      await navigate(kind, screen);
      await screenshot(`${screen}-${kind}`);
      results.push({ screen, fallback: kind });
    }
    await navigate('loading', screen);
    await screenshot(`${screen}-loading`);
    await click('Release image');
    await waitText('Product image:');
    await screenshot(`${screen}-released`);
    results.push({ screen, loading: 'released' });
    await navigate('loading', screen);
    await click('Clear session');
    await waitText('Session cleared');
    await click('Release image');
    assert.equal((await text()).includes('Product image:'), false);
    results.push({ screen, delayedAfterLogout: 'cleared' });
  }
  await navigate('normal', 'history');
  await evaluate(`document.activeElement?.blur()`);
  let focused = false;
  for (let i = 0; i < 12; i++) {
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
    await delay(100);
    focused = await evaluate(`(document.activeElement?.textContent ?? '') === 'Show detail' || document.activeElement?.getAttribute('aria-label') === 'Show detail'`);
    if (focused) break;
  }
  assert.equal(focused, true, 'Keyboard focus reaches Show detail');
  await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
  await waitText('Purchased items');
  results.push({ keyboard: 'focus and navigation', semantics: 'Product image labels' });
  assert.deepEqual(errors, []);
  assert.deepEqual(external, []);
  await writeFile(`${out}/results.json`, JSON.stringify({ passed: true, results, errors, externalRequests: external }, null, 2));
  process.stdout.write(JSON.stringify({ passed: true, checks: results.length, externalRequests: external.length }) + '\n');
} finally {
  await send('Page.close');
  ws.close();
}
