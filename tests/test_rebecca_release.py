import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from rebecca_release import prepare, ABIS
from rebecca_delta import apply_reference, digest
from test_rebecca_delta import fixtures

class ReleaseTest(unittest.TestCase):
    def test_release_manifest_hashes_and_deltas_match_published_apks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory);fixtures(root)
            apks=root/'apks';previous=root/'previous';out=root/'release'
            apks.mkdir();previous.mkdir()
            for abi in ABIS:
                shutil.copy(root/'target.bin',apks/f'Rebecca-0.0.3-{abi}.apk')
                shutil.copy(root/'base.bin',previous/f'Rebecca-0.0.2-{abi}.apk')
            manifest=prepare(apks,previous,out,'0.0.3',3,'AliZelzele-v/Rebecca')
            self.assertEqual(manifest['package'],'app.rebecca.vpn')
            for abi, asset in manifest['assets'].items():
                self.assertEqual(asset['sha256'],digest(out/f'Rebecca-0.0.3-{abi}.apk'))
                delta=asset['deltas'][0]
                self.assertTrue(delta['url'].startswith('https://github.com/AliZelzele-v/Rebecca/releases/download/v0.0.3/'))
                self.assertEqual(delta['from_sha256'],digest(previous/f'Rebecca-0.0.2-{abi}.apk'))
                patch=out/delta['url'].rsplit('/',1)[-1]
                self.assertEqual(delta['sha256'],digest(patch))
                apply_reference(previous/f'Rebecca-0.0.2-{abi}.apk',patch,root/'result.apk')
                self.assertEqual(digest(root/'result.apk'),asset['sha256'])

if __name__=='__main__':unittest.main()
