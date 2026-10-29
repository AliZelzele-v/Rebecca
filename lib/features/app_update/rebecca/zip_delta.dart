import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Future<String> fileSha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Reconstruct the exact signed APK using bounded IO buffers, never executable patches.
Future<void> applyRebeccaDelta(
  File base,
  File patch,
  File output, {
  required String expectedTargetSha256,
  required int expectedTargetSize,
}) async {
  const limit = 1024 * 1024 * 1024;
  if (expectedTargetSize <= 0 || expectedTargetSize > limit)
    throw const FormatException('Invalid APK size');
  final input = await patch.open();
  late Map<String, dynamic> metadata;
  late int payloadOffset;
  try {
    if (utf8.decode(await input.read(8)) != 'RBKZIP1\n')
      throw const FormatException('Invalid delta format');
    final lengthBytes = await input.read(4);
    if (lengthBytes.length != 4)
      throw const FormatException('Truncated delta header');
    final length = ByteData.sublistView(
      Uint8List.fromList(lengthBytes),
    ).getUint32(0);
    if (length <= 0 || length > 4 * 1024 * 1024)
      throw const FormatException('Invalid delta manifest');
    final bytes = await input.read(length);
    if (bytes.length != length)
      throw const FormatException('Truncated delta manifest');
    metadata = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    payloadOffset = 12 + length;
  } finally {
    await input.close();
  }
  if (metadata['format'] != 1 ||
      metadata['target_sha256'] != expectedTargetSha256 ||
      metadata['target_size'] != expectedTargetSize) {
    throw const FormatException('Delta does not match the release');
  }
  final oldSize = await base.length();
  final ops = metadata['ops'];
  if (ops is! List || ops.length > 100000)
    throw const FormatException('Invalid delta operations');
  var total = 0;
  for (final op in ops) {
    if (op is! List ||
        op.isEmpty ||
        (op[0] != 'copy' && op[0] != 'data') ||
        op.length != (op[0] == 'copy' ? 3 : 2)) {
      throw const FormatException('Invalid delta operation');
    }
    final length = op.last;
    if (length is! int || length <= 0 || total + length > expectedTargetSize)
      throw const FormatException('Invalid delta length');
    if (op[0] == 'copy' &&
        (op[1] is! int ||
            (op[1] as int) < 0 ||
            (op[1] as int) + length > oldSize)) {
      throw const FormatException('Delta range outside installed APK');
    }
    total += length;
  }
  if (total != expectedTargetSize ||
      await fileSha256(base) != metadata['base_sha256'])
    throw const FormatException('Installed APK does not match delta');
  final old = await base.open();
  final dest = await output.open(mode: FileMode.write);
  final payload = _PayloadReader(
    patch.openRead(payloadOffset).transform(gzip.decoder),
  );
  var verified = false;
  try {
    for (final op in ops) {
      var remaining = op.last as int;
      if (op[0] == 'copy') {
        await old.setPosition(op[1] as int);
        while (remaining > 0) {
          final chunk = await old.read(remaining > 262144 ? 262144 : remaining);
          if (chunk.isEmpty)
            throw const FormatException('Truncated installed APK');
          await dest.writeFrom(chunk);
          remaining -= chunk.length;
        }
      } else {
        await payload.copyTo(dest, remaining);
      }
    }
    await payload.finish();
    await dest.flush();
    if (await output.length() != expectedTargetSize ||
        await fileSha256(output) != expectedTargetSha256)
      throw const FormatException('Reconstructed APK failed verification');
    verified = true;
  } finally {
    await payload.close();
    await old.close();
    await dest.close();
    if (!verified && await output.exists()) await output.delete();
  }
}

class _PayloadReader {
  _PayloadReader(Stream<List<int>> stream) : iterator = StreamIterator(stream);
  final StreamIterator<List<int>> iterator;
  List<int> chunk = const [];
  int offset = 0;
  Future<void> copyTo(RandomAccessFile dest, int remaining) async {
    while (remaining > 0) {
      if (offset == chunk.length) {
        if (!await iterator.moveNext())
          throw const FormatException('Truncated delta payload');
        chunk = iterator.current;
        offset = 0;
        if (chunk.isEmpty) continue;
      }
      final count = remaining < chunk.length - offset
          ? remaining
          : chunk.length - offset;
      await dest.writeFrom(chunk, offset, offset + count);
      offset += count;
      remaining -= count;
    }
  }

  Future<void> finish() async {
    if (offset != chunk.length)
      throw const FormatException('Unexpected delta data');
    while (await iterator.moveNext()) {
      if (iterator.current.isNotEmpty)
        throw const FormatException('Unexpected delta data');
    }
  }

  Future<void> close() => iterator.cancel();
}
