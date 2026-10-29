"""Sign already-verified CI APKs with the owner's private key (never log it)."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
secret = json.loads(os.environ['REBECCA_ANDROID_SIGNING'])
subprocess.run([sys.executable, str(root/'scripts/prepare_rebecca_signing.py')], check=True)
sdk = Path(os.environ.get('ANDROID_HOME', os.environ.get('ANDROID_SDK_ROOT', '')))
tools = list((sdk/'build-tools').glob('*/apksigner'))
if not tools: raise SystemExit('Android apksigner is unavailable')
def version(path): return tuple(int(v) for v in re.findall(r'\d+',path.parent.name))
signer = max(tools,key=version)
source=Path('out/source');output=Path('out/apks');output.mkdir(parents=True,exist_ok=True)
env=dict(os.environ);env['REBECCA_STORE_PASSWORD']=secret['password']
expected=json.loads((root/'dependencies/rebecca-signing.json').read_text())['certificate_sha256']
for apk in source.glob('Rebecca-*.apk'):
    target=output/apk.name
    subprocess.run([str(signer),'sign','--ks',str(root/'android/rebecca-release.p12'),'--ks-type','PKCS12','--ks-key-alias','rebecca','--ks-pass','env:REBECCA_STORE_PASSWORD','--key-pass','env:REBECCA_STORE_PASSWORD','--out',str(target),str(apk)],check=True,env=env)
    result=subprocess.run([str(signer),'verify','--print-certs',str(target)],check=True,capture_output=True,text=True)
    fingerprints=re.findall(r'certificate SHA-256 digest: ([a-fA-F0-9]+)',result.stdout)
    if not fingerprints or fingerprints[0].lower()!=expected:raise SystemExit('APK signing certificate does not match the owner key')
    print('Verified owner-signed APK:',target.name)
if len(list(output.glob('*.apk')))!=3: raise SystemExit('Expected all three architecture APKs')
