import 'package:flutter/material.dart';

/// Reference-style protocol rail; the caller keeps upstream selection/actions.
class RebeccaServerContent extends StatelessWidget {
  const RebeccaServerContent({super.key, required this.protocol, required this.child, this.selected = false});
  final String protocol;
  final Widget child;
  final bool selected;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(width: 46, alignment: Alignment.center,
        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: RotatedBox(quarterTurns: 3, child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(protocol.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold,
              color: selected ? Theme.of(context).colorScheme.onPrimary : null)),
        )),
      ),
      Expanded(child: child),
    ],
  ));
}
