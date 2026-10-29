"""Fetch the official core matching upstream main, verifying its pinned digest.

The upstream main Android bridge is newer than core.version's stable release.
Never remove bridge methods to make an older AAR compile. Update this manifest
alongside upstream source updates after checking the new artifact's interfaces.
"""
from pathlib import Path
import hashlib
import json
import tarfile
import tempfile
import urllib.request

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'dependencies/rebecca-android-core.json').read_text())
destination = root / 'android/app/libs'
destination.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='rebecca-core-') as temp:
    archive = Path(temp) / 'core.tar.gz'
    digest = hashlib.sha256()
    with urllib.request.urlopen(manifest['url'], timeout=120) as response, archive.open('wb') as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
            digest.update(chunk)
    if digest.hexdigest() != manifest['sha256']:
        raise SystemExit('Core checksum changed. Review the upstream artifact before updating the pinned manifest.')
    with tarfile.open(archive) as package:
        package.extractall(destination, filter='data')
print('Verified official Android core:', manifest['sha256'])
