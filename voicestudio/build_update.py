"""Rebuild the custom Windows update from public, hash-verified upstream artifacts."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'build-work'
SOURCE = WORK / 'VoiceStudio'
TOOLS = ROOT / 'tooling'
OUT = ROOT / 'dist'
PACKAGE = WORK / 'VoiceStudio-TXT-SRT-Update'
BASE_COMMIT = 'c1050c16d9b3881e5d4161ee58ccc0582b3f20f9'
BASE_SHA = '11238cb8b08ea38b9b4e8e3050cd950ee2a2d3af1856d54e5ce6fb877444ad34'


def run(*args, cwd=ROOT):
    subprocess.run([str(arg) for arg in args], cwd=cwd, check=True)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=SOURCE, text=True).strip()


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as file:
        for chunk in iter(lambda: file.read(1048576), b''):
            result.update(chunk)
    return result.hexdigest()


WORK.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)
run('git', '-c', 'core.longpaths=true', 'clone', '--config', 'core.autocrlf=false',
    '--config', 'core.longpaths=true', '--depth', '1', '--branch', 'v0.5.8',
    'https://github.com/debpalash/VoiceStudio.git', SOURCE)
assert git('rev-parse', 'HEAD') == BASE_COMMIT, 'Unexpected upstream tag commit'
run('git', 'apply', ROOT / 'voicestudio/source.patch', cwd=SOURCE)
run(TOOLS / 'node_modules/bun/bin/bun.exe', 'install', '--frozen-lockfile', cwd=SOURCE)
run(TOOLS / 'node_modules/bun/bin/bun.exe', 'run', '--cwd', 'electron', 'typecheck', cwd=SOURCE)
run(TOOLS / 'node_modules/bun/bin/bun.exe', 'run', '--cwd', 'electron', 'build', cwd=SOURCE)
for test in ['test_line_subtitles.py', 'test_line_subtitle_finalize.py', 'test_txt_srt_updater.py']:
    run(sys.executable, SOURCE / 'tests' / test, '-v', cwd=SOURCE)

installer = WORK / 'VoiceStudio-0.5.8-win-x64.exe'
urllib.request.urlretrieve('https://github.com/debpalash/VoiceStudio/releases/download/v0.5.8/VoiceStudio-0.5.8-win-x64.exe', installer)
assert digest(installer) == BASE_SHA, 'Upstream installer checksum mismatch'
seven = TOOLS / 'node_modules/7zip-bin/win/x64/7za.exe'
base = WORK / 'official'
run(seven, 'x', '-y', f'-o{base}', installer, 'resources/*')
base_resources = base / 'resources'
asar_tool = TOOLS / 'node_modules/@electron/asar/bin/asar.mjs'
app = WORK / 'app-source'
run('node', asar_tool, 'extract', base_resources / 'app.asar', app)
shutil.rmtree(app / 'out')
shutil.copytree(SOURCE / 'electron/out', app / 'out')
payload = PACKAGE / 'payload'
payload.mkdir(parents=True)
run('node', asar_tool, 'pack', app, payload / 'app.asar')
for relative in ['api/routers/generation.py', 'core/csrf.py', 'services/line_subtitles.py']:
    target = payload / 'backend' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE / 'backend' / relative, target)
for name in ['UPDATE.cmd', 'RESTORE.cmd', 'Update-VoiceStudio.ps1']:
    data = (SOURCE / 'packaging/txt-srt' / name).read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    (PACKAGE / name).write_bytes(data)
for name in ['LICENSE', 'LICENSE-NOTICE.md']:
    shutil.copy2(SOURCE / name, PACKAGE / name)
shutil.copy2(ROOT / 'voicestudio/HUONG-DAN.txt', PACKAGE / 'HUONG-DAN.txt')
shutil.copy2(ROOT / 'voicestudio/source.patch', PACKAGE / 'source.patch')
entries = []
for relative in ['app.asar', 'backend/api/routers/generation.py', 'backend/core/csrf.py', 'backend/services/line_subtitles.py']:
    original = base_resources / relative
    entries.append(dict(path=relative, original=digest(original) if original.exists() else None,
                        patched=digest(payload / relative)))
(PACKAGE / 'manifest.json').write_text(json.dumps(dict(base_version='0.5.8', platform='win-x64', files=entries), indent=2), encoding='utf-8')
(PACKAGE / 'SOURCE-COMMIT.txt').write_text(f'Upstream: {BASE_COMMIT} (v0.5.8)\nhttps://github.com/debpalash/VoiceStudio/tree/{BASE_COMMIT}\nSOURCE.zip is the corresponding source with source.patch applied.\nInstaller SHA256: {BASE_SHA}\n', encoding='utf-8')
run('pwsh', '-NoProfile', '-File', PACKAGE / 'Update-VoiceStudio.ps1', '-VerifyOnly')

tracked = git('ls-files').splitlines()
untracked = git('ls-files', '--others', '--exclude-standard').splitlines()
files = sorted(set(tracked + untracked))
attrs = subprocess.check_output(['git', 'check-attr', '--stdin', 'export-ignore'], cwd=SOURCE,
                                input='\n'.join(files) + '\n', text=True)
ignored = {line.rsplit(': export-ignore: ', 1)[0] for line in attrs.splitlines() if line.endswith(': export-ignore: set')}
with zipfile.ZipFile(OUT / 'SOURCE.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for relative in files:
        if relative in ignored:
            continue
        path = SOURCE / relative
        if path.is_symlink():
            info = zipfile.ZipInfo('VoiceStudio-TXT-SRT/' + relative)
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, os.readlink(path))
        elif path.is_file():
            archive.write(path, 'VoiceStudio-TXT-SRT/' + relative)
checks = [digest(path) + '  ' + path.relative_to(PACKAGE).as_posix()
          for path in sorted(PACKAGE.rglob('*')) if path.is_file()]
(PACKAGE / 'SHA256SUMS.txt').write_text('\n'.join(checks) + '\n', encoding='ascii')
update = OUT / 'VoiceStudio-0.5.8-TXT-Audio-SRT-win-x64-update.zip'
with zipfile.ZipFile(update, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(PACKAGE.rglob('*')):
        if path.is_file():
            archive.write(path, 'VoiceStudio-TXT-SRT-Update/' + path.relative_to(PACKAGE).as_posix())
with zipfile.ZipFile(update) as archive:
    assert archive.testzip() is None, 'Corrupt update ZIP'
shutil.copy2(PACKAGE / 'HUONG-DAN.txt', OUT / 'HUONG-DAN-VoiceStudio-TXT-SRT.txt')
checks = [digest(path) + '  ' + path.name for path in sorted(OUT.iterdir()) if path.is_file()]
(OUT / 'VoiceStudio-TXT-SRT-SHA256.txt').write_text('\n'.join(checks) + '\n', encoding='ascii')
print('Windows update ready:', update.stat().st_size, 'bytes')
