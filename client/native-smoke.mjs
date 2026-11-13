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
  // Runner-only verifier stub: never modifies the packaged app or its trust keys.
  // Signature validation itself is covered separately with real RSA test keys.
  await app.evaluate(async () => {
    const { createRequire, syncBuiltinESMExports } = process.getBuiltinModule('module');
    const require = createRequire(process.execPath);
    require('node:crypto').verify = () => true;
    syncBuiltinESMExports();
  });
  const payload=Buffer.from(JSON.stringify({v:1,product:'vn.dinhduoc.voicestudio',kid:'cd5595bf4155492c',machine:displayed,iat:Math.floor(Date.now()/1000),exp:null,note:'CI only',nonce:'a'.repeat(32)})).toString('base64url');
  await page.locator('#key').fill(`DDVS1.${payload}.${Buffer.alloc(384).toString('base64url')}`);
  const uiErrors=[];
  app.on('window',window=>{window.on('pageerror',e=>{uiErrors.push(e.message);console.log('RENDERER ERROR',e.stack)});window.on('console',m=>{if(m.type()==='error')console.log('RENDERER CONSOLE',m.text())});});
  await page.locator('#activate').click();
  let main;
  for(let n=0;n<60;n++){main=app.windows().find(w=>w!==page&&!w.isClosed());if(main)break;await new Promise(r=>setTimeout(r,500));}
  assert.ok(main,'Main window did not open after activation');
  await main.waitForFunction(()=>document.querySelector('#root')?.childElementCount>0,{timeout:60000});
  assert.deepEqual(uiErrors,[]);
  await main.screenshot({path:screenshot.replace('.png','-MAIN.png')});
  console.log('Native Windows main renderer mounted after activation.');
} finally {await app.close();}
