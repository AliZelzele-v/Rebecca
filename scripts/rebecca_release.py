"""Prepare per-ABI APK assets and verified optional deltas for a GitHub release."""
import argparse
import json
from pathlib import Path
import shutil
from rebecca_delta import create_patch, digest

ABIS = ['arm64-v8a', 'armeabi-v7a', 'x86_64']

def prepare(apks, previous, output, version, build, repository):
    output.mkdir(parents=True, exist_ok=True)
    root = f'https://github.com/{repository}/releases/download/v{version}/'
    manifest = {'format': 1, 'package': 'app.rebecca.vpn', 'version': version, 'build': build, 'assets': {}}
    for abi in ABIS:
        source = apks / f'Rebecca-{version}-{abi}.apk'
        if not source.is_file(): raise SystemExit(f'Missing APK for {abi}')
        apk = output / source.name; shutil.copyfile(source, apk)
        info = {'url': root + apk.name, 'size': apk.stat().st_size, 'sha256': digest(apk), 'deltas': []}
        for base in sorted(previous.glob(f'Rebecca-*-{abi}.apk')):
            patch = output / f'Rebecca-{version}-{abi}-{digest(base)[:12]}.rbkpatch'
            metadata = create_patch(base, apk, patch)
            if patch.stat().st_size < apk.stat().st_size:
                info['deltas'].append({'url': root + patch.name, 'size': patch.stat().st_size, 'sha256': digest(patch), 'from_sha256': metadata['base_sha256']})
            else: patch.unlink()
        manifest['assets'][abi] = info
    (output / 'update.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    for flag in ['apks', 'previous', 'output', 'version', 'repository']: p.add_argument('--' + flag, required=True)
    p.add_argument('--build', type=int, required=True)
    a = p.parse_args()
    prepare(Path(a.apks), Path(a.previous), Path(a.output), a.version, a.build, a.repository)
