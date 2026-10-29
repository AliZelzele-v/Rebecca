import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/model/profile_nodes.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final profileNodesProvider = FutureProvider.autoDispose
    .family<List<ProfileNode>, ProfileEntity>((ref, profile) async {
      final repository = await ref.watch(profileRepositoryProvider.future);
      final config = await repository
          .generateConfig(profile.id)
          .getOrElse((error) => throw error)
          .run();
      return profileNodesFromJson(config);
    });

/// A subscription and its nodes stay together, including while disconnected.
class ProfileGroupCard extends ConsumerStatefulWidget {
  const ProfileGroupCard({super.key, required this.profile});
  final ProfileEntity profile;

  @override
  ConsumerState<ProfileGroupCard> createState() => _ProfileGroupCardState();
}

class _ProfileGroupCardState extends ConsumerState<ProfileGroupCard> {
  bool expanded = false;
  bool busy = false;

  Future<void> choose(ProfileNode node) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final switched =
          ref.read(activeProfileProvider).value?.id != widget.profile.id;
      if (switched) {
        await ref
            .read(profilesNotifierProvider.notifier)
            .selectActiveProfile(widget.profile.id);
        // Let the upstream active-profile listener perform its normal reconnect.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) return;
      if (!ref.read(serviceRunningProvider) &&
          !(ref.read(connectionNotifierProvider).value?.isSwitching ?? false)) {
        await ref.read(connectionNotifierProvider.notifier).toggleConnection();
      }
      if (!mounted) return;
      ref.invalidate(proxiesOverviewNotifierProvider);
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (mounted && DateTime.now().isBefore(deadline)) {
        if (ref.read(activeProfileProvider).value?.id != widget.profile.id) {
          throw StateError('The active subscription changed');
        }
        final liveProxies = ref.read(proxiesOverviewNotifierProvider);
        final group = liveProxies.isLoading ? null : liveProxies.value;
        if (ref.read(serviceRunningProvider) &&
            group != null &&
            group.items.any((item) => item.tag == node.tag)) {
          await ref
              .read(proxyRepositoryProvider)
              .selectProxy(group.tag, node.tag)
              .getOrElse((error) => throw error)
              .run();
          if (mounted) ref.invalidate(proxiesOverviewNotifierProvider);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (mounted)
        throw TimeoutException('The VPN core did not provide this server');
    } catch (error) {
      if (mounted) {
        final t = ref.read(translationsProvider).requireValue;
        ref
            .read(inAppNotificationControllerProvider)
            .showErrorToast(t.presentShortError(error));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final t = ref.watch(translationsProvider).requireValue;
    final nodes = ref.watch(profileNodesProvider(profile));
    final group = ref.watch(proxiesOverviewNotifierProvider).value;
    final active = ref.watch(activeProfileProvider).value?.id == profile.id;
    final info = switch (profile) {
      RemoteProfileEntity(:final subInfo) => subInfo,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  profile is RemoteProfileEntity
                      ? Icons.sync
                      : Icons.folder_outlined,
                ),
                title: Text(
                  '${profile.name}${nodes.value == null ? "" : " (${nodes.value!.length})"}',
                ),
                subtitle: active ? const Icon(Icons.check, size: 16) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active && group != null)
                      IconButton(
                        tooltip: t.pages.proxies.testDelay,
                        icon: const Icon(Icons.speed),
                        onPressed: busy
                            ? null
                            : () async {
                                await ref
                                    .read(
                                      proxiesOverviewNotifierProvider.notifier,
                                    )
                                    .urlTest(group.tag);
                              },
                      ),
                    ProfileActionButton(profile, true),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
                onTap: () => setState(() => expanded = !expanded),
              ),
              if (info != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    children: [
                      RemainingTrafficIndicator(info.ratio.clamp(0.0, 1.0)),
                      const SizedBox(height: 8),
                      ProfileSubscriptionInfo(info),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (expanded)
          nodes.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(t.presentShortError(error))),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        ref.invalidate(profileNodesProvider(profile)),
                  ),
                ],
              ),
            ),
            data: (items) => Column(
              children: [
                for (final node in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: RotatedBox(
                          quarterTurns: 3,
                          child: Text(node.type.toUpperCase()),
                        ),
                        title: Text(node.tag, overflow: TextOverflow.ellipsis),
                        selected: active && group?.selected == node.tag,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        trailing: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: busy ? null : () => choose(node),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
