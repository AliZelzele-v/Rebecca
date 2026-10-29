import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';

import 'package:hiddify/features/profile/notifier/profiles_update_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_group_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfilesPage extends HookConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final sortPing = ref.watch(profilePingSortProvider);
    final asyncProfiles = ref.watch(profilesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.profiles.title),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: t.pages.profiles.add, onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile()),
          IconButton(
            onPressed: () => ref
                .read(foregroundProfilesUpdateNotifierProvider.notifier)
                .trigger(),
            icon: const Icon(Icons.sync_rounded),
            tooltip: t.pages.profiles.updateSubscriptions,
          ),
          IconButton(
            onPressed: () =>
                ref.read(dialogNotifierProvider.notifier).showSortProfiles(),
            icon: const Icon(Icons.sort_rounded),
            tooltip: t.common.sort,
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => await ref
            .read(bottomSheetsNotifierProvider.notifier)
            .showAddProfile(),
        label: Text(t.pages.profiles.add),
        icon: const Icon(Icons.add_rounded),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          Expanded(child: Text(t.pages.profiles.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          FilterChip(label: Text(Localizations.localeOf(context).languageCode == 'fa' ? 'پینگ' : 'Ping'),
            avatar: const Icon(Icons.speed, size: 18), selected: sortPing,
            onSelected: (value) => ref.read(profilePingSortProvider.notifier).state = value),
        ])),
        const SizedBox(height: 12),
        Expanded(child: asyncProfiles.when(
        data: (data) => ListView.separated(
          padding: const EdgeInsets.all(12).copyWith(bottom: 84),
          separatorBuilder: (context, index) => const Gap(12),
          itemBuilder: (context, index) => ProfileGroupCard(
            key: ValueKey(data[index].id),
            profile: data[index],
          ),
          itemCount: data.length,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(t.presentShortError(error)),
      )),
      ]),
    );
  }
}
