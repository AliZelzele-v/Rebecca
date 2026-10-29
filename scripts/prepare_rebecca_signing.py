"""Provision a private owner-controlled keystore from an Actions secret only."""
import base64
import json
import os
from pathlib import Path

root = Path(__file__).resolve().parents[1]
secret = os.environ.get('REBECCA_ANDROID_SIGNING', '')
if not secret:
    if os.environ.get('REBECCA_PUBLISH') == 'true':
        raise SystemExit('Publishing requires the owner-controlled REBECCA_ANDROID_SIGNING repository secret.')
    print('Testing build: no persistent release signing key has been configured.')
else:
    data = json.loads(secret)
    password = data['password']
    # Properties metacharacters are not accepted; generated passwords use hex.
    if not password or any(c not in '0123456789abcdef' for c in password):
        raise SystemExit('Invalid signing secret format')
    keystore = root / 'android/rebecca-release.p12'
    fd = os.open(keystore, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'wb') as file: file.write(base64.b64decode(data['keystore_base64'], validate=True))
    properties = root / 'android/key.properties'
    fd = os.open(properties, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as file:
        file.write(f'storeFile={keystore}\nstorePassword={password}\nkeyPassword={password}\nkeyAlias=rebecca\nstoreType=PKCS12\n')
    print('Owner-controlled release signing configured.')
