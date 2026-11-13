"""Build the separately branded, machine-activated Windows app."""
from pathlib import Path
import hashlib,json,os,shutil,stat,subprocess,sys,urllib.request,zipfile
ROOT=Path(__file__).resolve().parent.parent
WORK=ROOT/'client-work';SOURCE=WORK/'source';TOOLS=ROOT/'tooling';OUT=ROOT/'dist'
BASE_COMMIT='c1050c16d9b3881e5d4161ee58ccc0582b3f20f9'
BASE_SHA='11238cb8b08ea38b9b4e8e3050cd950ee2a2d3af1856d54e5ce6fb877444ad34'
def run(*args,cwd=ROOT):subprocess.run([str(a) for a in args],cwd=cwd,check=True)
def git(*args):return subprocess.check_output(['git',*args],cwd=SOURCE,text=True).strip()
def digest(path):
 h=hashlib.sha256()
 with Path(path).open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):h.update(block)
 return h.hexdigest()
WORK.mkdir(exist_ok=True);OUT.mkdir(exist_ok=True)
run('git','-c','core.longpaths=true','clone','--config','core.autocrlf=false','--config','core.longpaths=true','--depth','1','--branch','v0.5.8','https://github.com/debpalash/VoiceStudio.git',SOURCE)
assert git('rev-parse','HEAD')==BASE_COMMIT
run('git','apply',ROOT/'client/source.patch',cwd=SOURCE)
authority=json.loads((SOURCE/'config/license-authority.json').read_text())
assert authority['enabled'] is True and authority['authority']['keyId']=='cd5595bf4155492c'
assert set(authority['authority']['publicKey'])=={'kty','n','e'}
bun=TOOLS/'node_modules/bun/bin/bun.exe'
run(bun,'install','--frozen-lockfile',cwd=SOURCE)
run(bun,'run','--cwd','electron','typecheck',cwd=SOURCE)
run('node',SOURCE/'electron/node_modules/vitest/vitest.mjs','run','src/main/device-license.test.ts','src/main/device-activation.test.ts','src/renderer/src/lib/api/generate.test.ts','src/renderer/src/hooks/use-generate.test.tsx','src/renderer/src/lib/store/takes.test.ts','src/renderer/src/features/clone/script-panel.test.tsx',cwd=SOURCE/'electron')
run(bun,'run','--cwd','electron','build',cwd=SOURCE)
for test in ['test_line_subtitles.py','test_line_subtitle_finalize.py']:
 run(sys.executable,SOURCE/'tests'/test,'-v',cwd=SOURCE)
installer=WORK/'official.exe'
urllib.request.urlretrieve('https://github.com/debpalash/VoiceStudio/releases/download/v0.5.8/VoiceStudio-0.5.8-win-x64.exe',installer)
assert digest(installer)==BASE_SHA
base=WORK/'DINH-DUOC-VOICE-STUDIO'
run(TOOLS/'node_modules/7zip-bin/win/x64/7za.exe','x','-y',f'-o{base}',installer)
resources=base/'resources'
asar=TOOLS/'node_modules/@electron/asar/bin/asar.mjs'
app_source=WORK/'app-source'
run('node',asar,'extract',resources/'app.asar',app_source)
shutil.rmtree(app_source/'out');shutil.copytree(SOURCE/'electron/out',app_source/'out')
run('node',asar,'pack',app_source,resources/'app.asar')
for relative in ['api/routers/generation.py','core/csrf.py','services/line_subtitles.py']:
 shutil.copy2(SOURCE/'backend'/relative,resources/'backend'/relative)
shutil.copy2(SOURCE/'config/app.json',resources/'config/app.json')
shutil.copy2(SOURCE/'config/license-authority.json',resources/'config/license-authority.json')
(resources/'app-update.yml').unlink(missing_ok=True)
exe=base/'DINH-DUOC-VOICE-STUDIO.exe';(base/'VoiceStudio.exe').rename(exe)
shutil.copy2(ROOT/'client/HUONG-DAN.txt',base/'HUONG-DAN.txt')
shutil.copy2(ROOT/'client/HUONG-DAN.txt',OUT/'HUONG-DAN-DINH-DUOC.txt')
assert not any(p.name in ['owner-key.dpapi','Issuer.Core.ps1','DinhDuoc-Key-Manager.ps1'] for p in base.rglob('*'))
# Real packaged Windows app must stay at activation and must not start the AI backend.
run('node',ROOT/'client/native-smoke.mjs',exe,OUT/'MAN-HINH-KICH-HOAT.png')
files=sorted(set(git('ls-files').splitlines()+git('ls-files','--others','--exclude-standard').splitlines()))
attrs=subprocess.check_output(['git','check-attr','--stdin','export-ignore'],cwd=SOURCE,input='\n'.join(files)+'\n',text=True)
ignored={s.rsplit(': export-ignore: ',1)[0] for s in attrs.splitlines() if s.endswith(': export-ignore: set')}
with zipfile.ZipFile(OUT/'SOURCE-DINH-DUOC.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
 for rel in files:
  if rel in ignored:continue
  p=SOURCE/rel
  if p.is_symlink():
   info=zipfile.ZipInfo('DINH-DUOC-VOICE-STUDIO-SOURCE/'+rel);info.create_system=3;info.external_attr=(stat.S_IFLNK|0o777)<<16;archive.writestr(info,os.readlink(p))
  elif p.is_file():archive.write(p,'DINH-DUOC-VOICE-STUDIO-SOURCE/'+rel)
app_zip=OUT/'DINH-DUOC-VOICE-STUDIO-Windows-x64.zip'
with zipfile.ZipFile(app_zip,'w',zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as archive:
 for p in sorted(base.rglob('*')):
  if p.is_file():archive.write(p,'DINH-DUOC-VOICE-STUDIO/'+p.relative_to(base).as_posix())
with zipfile.ZipFile(app_zip) as archive:assert archive.testzip() is None
checks=[digest(p)+'  '+p.name for p in sorted(OUT.iterdir()) if p.is_file()]
(OUT/'SHA256SUMS-DINH-DUOC.txt').write_text('\n'.join(checks)+'\n',encoding='ascii')
print('Branded activated Windows app ZIP ready:',app_zip.stat().st_size,'bytes')
