import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hiddify/features/app_update/rebecca/rebecca_update_service.dart';
import 'package:hiddify/features/app_update/rebecca/zip_delta.dart';

class _ReleaseAdapter implements HttpClientAdapter {
  _ReleaseAdapter(this.manifest);
  final Map<String, dynamic> manifest;
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    final body = options.uri.host == 'api.github.com'
        ? {
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'update.json',
                'browser_download_url':
                    'https://github.com/AliZelzele-v/Rebecca/releases/download/v0.0.3/update.json',
              },
            ],
          }
        : manifest;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Rebecca',
      packageName: 'app.rebecca.vpn',
      version: '0.0.2',
      buildNumber: '2',
      buildSignature: '',
    );
  });
  test('only the exact installed APK receives a smaller delta plan', () async {
    final base = File('test/fixtures/rebecca_delta/base.bin');
    final target = File('test/fixtures/rebecca_delta/target.bin');
    final patch = File('test/fixtures/rebecca_delta/patch.bin');
    final cache = await Directory.systemTemp.createTemp('rebecca-plan-');
    addTearDown(() => cache.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          rebeccaUpdateChannel,
          (call) async => {
            'path': base.absolute.path,
            'cache': cache.path,
            'abis': ['arm64-v8a'],
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(rebeccaUpdateChannel, null),
    );
    final entry = {
      'url':
          'https://github.com/AliZelzele-v/Rebecca/releases/download/v0.0.3/arm64.apk',
      'sha256': await fileSha256(target),
      'size': await target.length(),
      'deltas': [
        {
          'url':
              'https://github.com/AliZelzele-v/Rebecca/releases/download/v0.0.3/arm64.rbkpatch',
          'sha256': await fileSha256(patch),
          'size': await patch.length(),
          'from_sha256': await fileSha256(base),
        },
      ],
    };
    final manifest = {
      'format': 1,
      'package': 'app.rebecca.vpn',
      'version': '0.0.3',
      'build': 3,
      'assets': {'arm64-v8a': entry},
    };
    final adapter = _ReleaseAdapter(manifest);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = RebeccaUpdateService(client: dio);
    addTearDown(service.close);
    final plan = await service.check();
    expect(plan, isNotNull);
    expect(plan!.delta, isNotNull);
    expect(plan.transferBytes, await patch.length());
    (entry['deltas'] as List).first['from_sha256'] = '0' * 64;
    final incompatible = await service.check();
    expect(incompatible!.delta, isNull);
    expect(incompatible.transferBytes, await target.length());
    manifest['version'] = '0.0.2';
    manifest['build'] = 2;
    expect(await service.check(), isNull);
  });
  test('invalid update hosts and hashes cannot become download plans', () {
    for (final url in [
      'http://github.com/AliZelzele-v/Rebecca/releases/download/v1/a.apk',
      'https://evil.example/a.apk',
      'https://github.com/someone/other/releases/download/v1/a.apk',
    ]) {
      expect(
        () => RebeccaUpdateAsset.fromJson({
          'url': url,
          'sha256': '0' * 64,
          'size': 10,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => RebeccaUpdateAsset.fromJson({
        'url':
            'https://github.com/AliZelzele-v/Rebecca/releases/download/v1/a.apk',
        'sha256': 'bad',
        'size': 10,
      }),
      throwsFormatException,
    );
  });
}
