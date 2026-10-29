import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/features/app_update/rebecca/rebecca_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _label(BuildContext context, String fa, String en) =>
    Localizations.localeOf(context).languageCode == 'fa' ? fa : en;
String _megabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Checks when the app opens or resumes; never downloads or installs in the background.
class RebeccaUpdateGate extends StatefulWidget {
  const RebeccaUpdateGate({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  State<RebeccaUpdateGate> createState() => _RebeccaUpdateGateState();
}

class _RebeccaUpdateGateState extends State<RebeccaUpdateGate>
    with WidgetsBindingObserver {
  DateTime? lastCheck;
  bool checking = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> check() async {
    if (!mounted ||
        !Platform.isAndroid ||
        checking ||
        (lastCheck != null &&
            DateTime.now().difference(lastCheck!) < const Duration(hours: 6)))
      return;
    checking = true;
    lastCheck = DateTime.now();
    final service = RebeccaUpdateService();
    try {
      final plan = await service.check();
      if (!mounted || plan == null) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('rebecca_update_prompt') == plan.version) return;
      final navigatorContext = widget.navigatorKey.currentContext;
      if (!mounted || navigatorContext == null || !navigatorContext.mounted)
        return;
      await prefs.setString('rebecca_update_prompt', plan.version);
      if (navigatorContext.mounted)
        await showDialog<void>(
          context: navigatorContext,
          builder: (_) => RebeccaUpdateDialog(plan: plan),
        );
    } catch (_) {
      /* Offline startup must not interrupt the VPN UI. */
    } finally {
      service.close();
      checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> checkRebeccaUpdate(BuildContext context) async {
  final service = RebeccaUpdateService();
  try {
    final plan = await service.check();
    if (!context.mounted) return;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              context,
              'نسخهٔ جدیدی موجود نیست',
              'You are using the latest version',
            ),
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => RebeccaUpdateDialog(plan: plan),
      );
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              context,
              'بررسی به‌روزرسانی انجام نشد؛ دوباره تلاش کنید',
              'Could not check for updates. Please retry.',
            ),
          ),
        ),
      );
  } finally {
    service.close();
  }
}

class RebeccaUpdateDialog extends StatefulWidget {
  const RebeccaUpdateDialog({super.key, required this.plan});
  final RebeccaUpdatePlan plan;
  @override
  State<RebeccaUpdateDialog> createState() => _RebeccaUpdateDialogState();
}

class _RebeccaUpdateDialogState extends State<RebeccaUpdateDialog> {
  final service = RebeccaUpdateService();
  CancelToken? token;
  File? prepared;
  bool busy = false, applying = false, full = false;
  double? progress;
  String? message;
  Future<void> update({bool downloadFull = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      full = downloadFull;
    });
    token = CancelToken();
    try {
      prepared ??= await service.prepare(
        widget.plan,
        fullDownload: full,
        cancelToken: token!,
        onProgress: (got, total) {
          if (mounted) setState(() => progress = got / total);
        },
        onApplying: () {
          if (mounted)
            setState(() {
              applying = true;
              progress = null;
            });
        },
      );
      if (!mounted) return;
      final started = await service.install(prepared!);
      if (!mounted) return;
      if (started) {
        Navigator.of(context).pop();
      } else {
        setState(
          () => message = _label(
            context,
            'اجازهٔ نصب را در تنظیمات فعال کنید، سپس دوباره «نصب» را بزنید.',
            'Allow installation in Settings, then tap Install again.',
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted)
        setState(
          () =>
              message = (error.message?.contains('SIGNATURE_MISMATCH') ?? false)
              ? _label(
                  context,
                  'امضای نسخهٔ نصب‌شده با این نسخه متفاوت است. پیش از نصب مجدد از اشتراک‌ها نسخهٔ پشتیبان بگیرید.',
                  'The installed app has a different signing key. Back up subscriptions before reinstalling.',
                )
              : _label(
                  context,
                  'نصب آغاز نشد؛ دوباره تلاش کنید.',
                  'Could not start installation. Please retry.',
                ),
        );
    } catch (_) {
      if (mounted)
        setState(
          () => message = _label(
            context,
            'دریافت یا تأیید فایل ناموفق بود. بدون تأیید شما دانلود کامل آغاز نمی‌شود.',
            'Download or verification failed. A full download will not start without your choice.',
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          applying = false;
        });
    }
  }

  @override
  void dispose() {
    token?.cancel();
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(_label(context, 'به‌روزرسانی ربکا', 'Update Rebecca')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rebecca ${plan.version}'),
            const SizedBox(height: 12),
            Text(
              plan.delta != null && !full
                  ? _label(
                      context,
                      'دانلود تغییرات: ${_megabytes(plan.transferBytes)}',
                      'Download changes: ${_megabytes(plan.transferBytes)}',
                    )
                  : _label(
                      context,
                      'حجم دانلود: ${_megabytes(plan.apk.size)}',
                      'Download size: ${_megabytes(plan.apk.size)}',
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              _label(
                context,
                'برای پایان نصب، تأیید اندروید نمایش داده می‌شود.',
                'Android will ask you to confirm installation.',
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
              if (applying)
                Text(
                  _label(
                    context,
                    'در حال آماده‌سازی به‌روزرسانی…',
                    'Preparing update…',
                  ),
                ),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(_label(context, 'بعداً', 'Later')),
          ),
          if (!busy &&
              message != null &&
              plan.delta != null &&
              prepared == null)
            TextButton(
              onPressed: () => update(downloadFull: true),
              child: Text(_label(context, 'دانلود کامل', 'Full download')),
            ),
          FilledButton(
            onPressed: busy ? null : update,
            child: Text(
              prepared != null
                  ? _label(context, 'نصب', 'Install')
                  : _label(context, 'به‌روزرسانی', 'Update'),
            ),
          ),
        ],
      ),
    );
  }
}
