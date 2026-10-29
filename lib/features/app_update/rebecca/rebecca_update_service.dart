import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/app_update/rebecca/zip_delta.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

const rebeccaUpdateChannel = MethodChannel('app.rebecca.vpn/updates');
const _maximumApkBytes = 1024 * 1024 * 1024;

Uri _releaseAsset(dynamic value) {
  final uri = Uri.parse(value as String);
  if (uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      !uri.path.startsWith('/AliZelzele-v/Rebecca/releases/download/')) {
    throw const FormatException('Untrusted update source');
  }
  return uri;
}

class RebeccaUpdateAsset {
  RebeccaUpdateAsset.fromJson(Map<String, dynamic> json)
    : url = _releaseAsset(json['url']),
      sha256 = json['sha256'] as String,
      size = json['size'] as int {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        size <= 0 ||
        size > _maximumApkBytes)
      throw const FormatException('Invalid update asset');
  }
  final Uri url;
  final String sha256;
  final int size;
}

class RebeccaUpdatePlan {
  const RebeccaUpdatePlan({
    required this.version,
    required this.apk,
    required this.base,
    required this.cache,
    this.delta,
  });
  final String version;
  final RebeccaUpdateAsset apk;
  final RebeccaUpdateAsset? delta;
  final File base;
  final Directory cache;
  int get transferBytes => delta?.size ?? apk.size;
}

class RebeccaUpdateService {
  RebeccaUpdateService({Dio? client})
    : dio =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'User-Agent': 'Rebecca',
                'Accept': 'application/vnd.github+json',
              },
            ),
          );
  final Dio dio;

  Future<Map<String, dynamic>> _json(String url) async {
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );
    final data = <int>[];
    await for (final chunk in response.data!.stream) {
      if (data.length + chunk.length > 2 * 1024 * 1024)
        throw const FormatException('Update metadata is too large');
      data.addAll(chunk);
    }
    return jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
  }

  Future<RebeccaUpdatePlan?> check() async {
    final current = await PackageInfo.fromPlatform();
    late Map<String, dynamic> release;
    try {
      release = await _json('${Constants.githubReleasesApiUrl}/latest');
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
    if (release['draft'] == true || release['prerelease'] == true) return null;
    final assets = release['assets'] as List;
    final manifests = assets.where((entry) => entry['name'] == 'update.json');
    if (manifests.isEmpty) return null;
    final manifest = await _json(
      _releaseAsset(manifests.first['browser_download_url']).toString(),
    );
    if (manifest['format'] != 1 || manifest['package'] != current.packageName)
      throw const FormatException('Wrong update package');
    final nextVersion = manifest['version'] as String;
    final remoteVersion = Version.parse(nextVersion),
        localVersion = Version.parse(current.version);
    final remoteBuild = manifest['build'] as int;
    if (remoteVersion < localVersion ||
        (remoteVersion == localVersion &&
            remoteBuild <= (int.tryParse(current.buildNumber) ?? 0)))
      return null;
    final platform = Map<String, dynamic>.from(
      (await rebeccaUpdateChannel.invokeMapMethod<String, dynamic>(
        'installedApk',
      ))!,
    );
    final variants = manifest['assets'] as Map<String, dynamic>;
    final abis = (platform['abis'] as List).cast<String>();
    final compatible = abis.where(variants.containsKey);
    if (compatible.isEmpty)
      throw const FormatException('No update for this device');
    final entry = Map<String, dynamic>.from(variants[compatible.first] as Map);
    final apk = RebeccaUpdateAsset.fromJson(entry);
    final base = File(platform['path'] as String);
    RebeccaUpdateAsset? delta;
    final deltas = entry['deltas'] as List? ?? const [];
    if (deltas.isNotEmpty) {
      final installedHash = await fileSha256(base);
      for (final item in deltas) {
        if (item['from_sha256'] == installedHash) {
          final candidate = RebeccaUpdateAsset.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          if (candidate.size < apk.size) delta = candidate;
          break;
        }
      }
    }
    return RebeccaUpdatePlan(
      version: nextVersion,
      apk: apk,
      delta: delta,
      base: base,
      cache: Directory(platform['cache'] as String),
    );
  }

  Future<File> prepare(
    RebeccaUpdatePlan plan, {
    required CancelToken cancelToken,
    required void Function(int, int) onProgress,
    bool fullDownload = false,
    void Function()? onApplying,
  }) async {
    await plan.cache.create(recursive: true);
    final asset = fullDownload ? plan.apk : plan.delta ?? plan.apk;
    final download = File('${plan.cache.path}/download.part');
    final output = File('${plan.cache.path}/rebecca-update.apk');
    if (await output.exists()) await output.delete();
    try {
      await dio.download(
        asset.url.toString(),
        download.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, _) {
          if (received > asset.size) {
            cancelToken.cancel('Update exceeds declared size');
            return;
          }
          onProgress(received, asset.size);
        },
      );
      if (cancelToken.isCancelled) throw StateError('Update cancelled');
      if (await download.length() != asset.size ||
          await fileSha256(download) != asset.sha256)
        throw const FormatException('Download verification failed');
      if (!fullDownload && plan.delta != null) {
        onApplying?.call();
        await _reconstruct((
          base: plan.base.path,
          patch: download.path,
          output: output.path,
          sha: plan.apk.sha256,
          size: plan.apk.size,
        ));
      } else {
        await download.rename(output.path);
      }
      if (cancelToken.isCancelled) throw StateError('Update cancelled');
      return output;
    } finally {
      if (await download.exists()) await download.delete();
    }
  }

  Future<bool> install(File apk) async =>
      (await rebeccaUpdateChannel.invokeMethod<bool>('install', {
        'path': apk.path,
      })) ??
      false;
  void close() => dio.close();
}

Future<void> _reconstruct(
  ({String base, String patch, String output, String sha, int size}) input,
) => Isolate.run(
  () => applyRebeccaDelta(
    File(input.base),
    File(input.patch),
    File(input.output),
    expectedTargetSha256: input.sha,
    expectedTargetSize: input.size,
  ),
);
