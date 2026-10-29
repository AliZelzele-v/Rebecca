import 'package:flutter/material.dart';

/// A bounded subscription header. Upstream action animations expand to their
/// constraints, so every action slot must have an explicit size in a ListTile.
class ProfileGroupHeader extends StatelessWidget {
  const ProfileGroupHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.action,
    this.testAction,
    this.details,
    this.active = false,
  });
  final String title;
  final IconData icon;
  final bool expanded, active;
  final VoidCallback onToggle;
  final Widget action;
  final Widget? testAction, details;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
          leading: Icon(icon),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: active
              ? const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Icon(Icons.check, size: 14),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (testAction != null)
                SizedBox.square(dimension: 44, child: testAction),
              SizedBox.square(dimension: 44, child: action),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
          onTap: onToggle,
        ),
        if (details != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: details,
          ),
      ],
    ),
  );
}
