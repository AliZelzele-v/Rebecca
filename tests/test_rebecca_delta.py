import importlib.util
from pathlib import Path
import random
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('delta', Path(__file__).resolve().parents[1] / 'scripts/rebecca_delta.py')
delta = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delta)

def fixtures(folder):
    random_bytes = random.Random(104).randbytes(32768)
    for version in ['base', 'target']:
        with zipfile.ZipFile(folder / f'{version}.bin', 'w', compression=zipfile.ZIP_STORED) as archive:
            archive.writestr('lib/arm64-v8a/libcore.so', random_bytes)
            archive.writestr('assets/app.data', ('Rebecca ' + version).encode() * 700)
            archive.comment = b'APK signing/alignment fixture ' + version.encode()
    delta.create_patch(folder / 'base.bin', folder / 'target.bin', folder / 'patch.bin')

class DeltaTest(unittest.TestCase):
    def test_signed_zip_bytes_are_reconstructed_exactly_with_small_transfer(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory); fixtures(folder)
            delta.apply_reference(folder/'base.bin',folder/'patch.bin',folder/'result.bin')
            self.assertEqual((folder/'result.bin').read_bytes(), (folder/'target.bin').read_bytes())
            self.assertLess((folder/'patch.bin').stat().st_size, (folder/'target.bin').stat().st_size // 3)

    def test_wrong_base_and_truncated_payload_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory); fixtures(folder)
            with self.assertRaises(ValueError):
                delta.apply_reference(folder/'target.bin',folder/'patch.bin',folder/'result.bin')
            p=folder/'patch.bin';p.write_bytes(p.read_bytes()[:-20])
            with self.assertRaises((ValueError,EOFError,OSError)):
                delta.apply_reference(folder/'base.bin',p,folder/'result.bin')

if __name__ == '__main__': unittest.main()
