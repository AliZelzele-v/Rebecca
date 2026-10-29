"""Exact APK deltas: reuse unchanged compressed ZIP entries; gzip the rest.

Android APK signatures and zip alignment are retained byte for byte. The client
copies ranges from its installed APK and never trusts a reconstructed file until
its complete SHA-256 matches the release manifest. No executable patch code.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import struct
import tempfile
import zipfile

MAGIC = b'RBKZIP1\n'

def digest(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()

def entry_ranges(path):
    with zipfile.ZipFile(path) as archive, Path(path).open('rb') as file:
        for entry in archive.infolist():
            if entry.compress_size < 4096:
                continue
            file.seek(entry.header_offset)
            header = file.read(30)
            if len(header) != 30 or header[:4] != b'PK\x03\x04':
                raise ValueError('Invalid local ZIP header')
            name_len, extra_len = struct.unpack_from('<HH', header, 26)
            start = entry.header_offset + 30 + name_len + extra_len
            file.seek(start)
            data = file.read(entry.compress_size)
            if len(data) != entry.compress_size:
                raise ValueError('Truncated ZIP entry')
            yield start, len(data), hashlib.sha256(data).hexdigest()

def create_patch(base, target, output):
    base, target, output = map(Path, (base, target, output))
    old = {(size, sha): offset for offset, size, sha in entry_ranges(base)}
    matches = [(offset, size, old[(size, sha)]) for offset, size, sha in entry_ranges(target) if (size, sha) in old]
    matches.sort()
    ops, cursor = [], 0
    for offset, size, old_offset in matches:
        if offset < cursor:
            raise ValueError('Overlapping ZIP entries')
        if offset > cursor:
            ops.append(['data', offset - cursor])
        ops.append(['copy', old_offset, size])
        cursor = offset + size
    if cursor < target.stat().st_size:
        ops.append(['data', target.stat().st_size - cursor])
    metadata = dict(format=1, base_sha256=digest(base), target_sha256=digest(target), target_size=target.stat().st_size, ops=ops)
    encoded = json.dumps(metadata, separators=(',', ':')).encode()
    if len(encoded) > 4 * 1024 * 1024:
        raise ValueError('Patch manifest too large')
    output.parent.mkdir(parents=True, exist_ok=True)
    with target.open('rb') as source, output.open('wb') as dest:
        dest.write(MAGIC + struct.pack('>I', len(encoded)) + encoded)
        with gzip.GzipFile(fileobj=dest, mode='wb', filename='', mtime=0) as payload:
            position = 0
            for op in ops:
                length = op[-1]
                if op[0] == 'data':
                    source.seek(position)
                    remaining = length
                    while remaining:
                        chunk = source.read(min(remaining, 1024 * 1024))
                        if not chunk: raise ValueError('Truncated target APK')
                        payload.write(chunk)
                        remaining -= len(chunk)
                position += length
    return metadata

def apply_reference(base, patch, output):
    """Reference reader used for cross-language fixture and publisher tests."""
    with Path(patch).open('rb') as stream:
        if stream.read(8) != MAGIC: raise ValueError('Invalid patch')
        size = struct.unpack('>I', stream.read(4))[0]
        if size > 4 * 1024 * 1024: raise ValueError('Oversized manifest')
        data = json.loads(stream.read(size))
        if digest(base) != data['base_sha256']: raise ValueError('Wrong base')
        with gzip.GzipFile(fileobj=stream) as payload, Path(base).open('rb') as old, Path(output).open('wb') as new:
            for op in data['ops']:
                if op[0] == 'copy':
                    old.seek(op[1]); source = old
                else: source = payload
                remaining = op[-1]
                while remaining:
                    chunk = source.read(min(remaining, 1024 * 1024))
                    if not chunk: raise ValueError('Truncated data')
                    new.write(chunk); remaining -= len(chunk)
        if Path(output).stat().st_size != data['target_size'] or digest(output) != data['target_sha256']:
            raise ValueError('Target verification failed')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('base'); parser.add_argument('target'); parser.add_argument('output')
    args = parser.parse_args()
    create_patch(args.base, args.target, args.output)
    print(json.dumps({'patch_bytes': Path(args.output).stat().st_size, 'target_bytes': Path(args.target).stat().st_size}))
