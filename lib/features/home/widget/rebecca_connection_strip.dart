import 'package:flutter/material.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A persistent control backed exclusively by the original connection notifier.
class RebeccaConnectionStrip extends ConsumerWidget {
  const RebeccaConnectionStrip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final status = ref.watch(connectionNotifierProvider);
    final state = status.valueOrNull;
    final running = state?.isRunning ?? false;
    final proxy = running ? ref.watch(activeProxyNotifierProvider).valueOrNull : null;
    final delay = proxy?.urlTestDelay;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          SizedBox(width: 148, child: FilledButton.icon(
            onPressed: status.isLoading || state is Disconnecting ? null : () async {
              final dialogs = ref.read(dialogNotifierProvider.notifier);
              if (ref.read(activeProfileProvider).valueOrNull == null) {
                await dialogs.showNoActiveProfile();
                await ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
                return;
              }
              if ((state is Disconnected || status.hasError) && !await dialogs.showExperimentalFeatureNotice()) return;
              try {
                await ref.read(connectionNotifierProvider.notifier).toggleConnection();
              } catch (error) {
                ref.read(inAppNotificationControllerProvider).showErrorToast(t.presentShortError(error));
              }
            },
            icon: Icon(running ? Icons.power_settings_new : Icons.power),
            label: Text(state?.present(t) ?? t.connection.connecting, maxLines: 1, overflow: TextOverflow.ellipsis),
          )),
          const SizedBox(width: 12),
          Expanded(child: Text(
            running && delay != null && ConnectionConst.isValidDelay(delay)
              ? '${proxy!.tagDisplay} · $delay ms'
              : state?.present(t) ?? t.connection.connecting,
            maxLines: 2, overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    );
  }
}
