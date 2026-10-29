import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/app_update/rebecca/zip_delta.dart';

void main() {
  final base = File('test/fixtures/rebecca_delta/base.bin');
  final target = File('test/fixtures/rebecca_delta/target.bin');
  final patch = File('test/fixtures/rebecca_delta/patch.bin');
  test(
    'Python publisher and Dart updater reconstruct the exact target APK bytes',
    () async {
      final temp = await Directory.systemTemp.createTemp('rebecca-delta-test-');
      addTearDown(() => temp.delete(recursive: true));
      final output = File('${temp.path}/new.apk');
      await applyRebeccaDelta(
        base,
        patch,
        output,
        expectedTargetSha256: await fileSha256(target),
        expectedTargetSize: await target.length(),
      );
      expect(await output.readAsBytes(), await target.readAsBytes());
      expect(await patch.length(), lessThan((await target.length()) ~/ 3));
    },
  );
  test('a wrong installed APK cannot be used to apply a delta', () async {
    final temp = await Directory.systemTemp.createTemp('rebecca-delta-test-');
    addTearDown(() => temp.delete(recursive: true));
    final output = File('${temp.path}/new.apk');
    await expectLater(
      applyRebeccaDelta(
        target,
        patch,
        output,
        expectedTargetSha256: await fileSha256(target),
        expectedTargetSize: await target.length(),
      ),
      throwsFormatException,
    );
    expect(await output.exists(), false);
  });
  test('an out-of-bounds copy is rejected before producing an APK', () async {
    final temp = await Directory.systemTemp.createTemp('rebecca-delta-test-');
    addTearDown(() => temp.delete(recursive: true));
    final metadata = utf8.encode(
      jsonEncode({
        'format': 1,
        'base_sha256': await fileSha256(base),
        'target_sha256': await fileSha256(target),
        'target_size': await target.length(),
        'ops': [
          ['copy', await base.length(), await target.length()],
        ],
      }),
    );
    final length = ByteData(4)..setUint32(0, metadata.length);
    final malicious = File('${temp.path}/bad.patch');
    await malicious.writeAsBytes([
      ...utf8.encode('RBKZIP1\n'),
      ...length.buffer.asUint8List(),
      ...metadata,
      ...gzip.encode([]),
    ]);
    await expectLater(
      applyRebeccaDelta(
        base,
        malicious,
        File('${temp.path}/out.apk'),
        expectedTargetSha256: await fileSha256(target),
        expectedTargetSize: await target.length(),
      ),
      throwsFormatException,
    );
  });
  test('corruption never leaves an installable output behind', () async {
    final temp = await Directory.systemTemp.createTemp('rebecca-delta-test-');
    addTearDown(() => temp.delete(recursive: true));
    final broken = File('${temp.path}/broken.patch');
    final bytes = await patch.readAsBytes();
    await broken.writeAsBytes(bytes.sublist(0, bytes.length - 12));
    final output = File('${temp.path}/out.apk');
    await expectLater(
      applyRebeccaDelta(
        base,
        broken,
        output,
        expectedTargetSha256: await fileSha256(target),
        expectedTargetSize: await target.length(),
      ),
      throwsA(anything),
    );
    expect(await output.exists(), false);
  });
}
