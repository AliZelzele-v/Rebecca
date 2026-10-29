import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RebeccaTunnelDashboard extends ConsumerWidget {
  const RebeccaTunnelDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final running = ref.watch(serviceRunningProvider);
    final stats = ref.watch(statsNotifierProvider).valueOrNull;
    final proxy = running ? ref.watch(activeProxyNotifierProvider).valueOrNull : null;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    Widget row(IconData icon, String title, Widget value, {VoidCallback? onTap}) => ListTile(
      leading: Icon(icon), title: Text(title), trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 175), child: value), onTap: onTap,
    );
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (profile != null) ProfileTile(profile: profile, isMain: true),
      const SizedBox(height: 16),
      Card(child: Column(mainAxisSize: MainAxisSize.min, children: [
        row(Icons.upload, fa ? 'آپلود' : 'Upload', Text(running ? (stats?.uplinkTotal.toInt() ?? 0).size() : '—')),
        const Divider(height: 1, indent: 16, endIndent: 16),
        row(Icons.download, fa ? 'دانلود' : 'Download', Text(running ? (stats?.downlinkTotal.toInt() ?? 0).size() : '—')),
        const Divider(height: 1, indent: 16, endIndent: 16),
        row(Icons.public, fa ? 'تونل' : 'Tunnel',
          proxy != null && proxy.ipinfo.ip.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IPCountryFlag(countryCode: proxy.ipinfo.countryCode, size: 28),
                const SizedBox(width: 6),
                Flexible(child: IPText(ip: proxy.ipinfo.ip, constrained: true,
                  onLongPress: () => ref.read(ipInfoNotifierProvider.notifier).refresh())),
              ])
            : Text(fa ? 'نامشخص' : 'Unknown'),
          onTap: running ? () => ref.read(ipInfoNotifierProvider.notifier).refresh() : null),
        const Divider(height: 1, indent: 16, endIndent: 16),
        row(Icons.route, fa ? 'سرور فعال' : 'Active server', Text(proxy?.tagDisplay ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => context.pushNamed('proxies')),
        const Divider(height: 1, indent: 16, endIndent: 16),
        row(Icons.tune, fa ? 'مسیریابی و تنظیمات تونل' : 'Routing and tunnel settings', const Icon(Icons.chevron_right), onTap: () => context.goNamed('settings')),
      ])),
    ]);
  }
}
