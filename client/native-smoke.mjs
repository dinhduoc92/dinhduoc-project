import { _electron } from '../tooling/node_modules/playwright/index.mjs';
import assert from 'node:assert/strict';
import { createConnection } from 'node:net';
const executablePath=process.argv[2];
const screenshot=process.argv[3];
const app=await _electron.launch({executablePath,args:['--disable-gpu'],timeout:60000});
try {
  const page=await app.firstWindow();
  await page.waitForSelector('#machine');
  await page.waitForFunction(()=>/^[A-F0-9]{4}(?:-[A-F0-9]{4}){3}$/.test(document.querySelector('#machine').textContent));
  assert.match(await page.title(),/ĐÌNH ĐƯỢC- VOICE STUDIO/);
  assert.deepEqual(await page.evaluate(()=>Object.keys(window.deviceActivation).sort()),['activate','copy','info']);
  await page.locator('#copy').click();
  const displayed=await page.locator('#machine').textContent();
  assert.equal(await app.evaluate(({clipboard})=>clipboard.readText()),displayed);
  await page.locator('#key').fill('invalid-activation-code');
  await page.locator('#activate').click();
  await page.locator('#status').filter({hasText:'Mã kích hoạt không hợp lệ.'}).waitFor();
  assert.equal(await page.locator('[data-clone-script]').count(),0);
  const listening=await new Promise(resolve=>{
    const socket=createConnection({host:'127.0.0.1',port:43900});
    socket.on('connect',()=>{socket.destroy();resolve(true)});
    socket.on('error',()=>resolve(false));socket.setTimeout(2000,()=>{socket.destroy();resolve(false)});
  });
  assert.equal(listening,false,'The backend started before activation');
  await page.screenshot({path:screenshot});
  console.log('Native Windows activation gate passed: machine ID, clipboard, invalid-code lock and backend blocked.');
} finally {await app.close();}
