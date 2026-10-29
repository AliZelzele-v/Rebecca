import 'dart:convert';
import 'package:hiddify/core/model/constants.dart';

/// Only presentation metadata is retained; credentials never leave the config.
class ProfileNode {
  const ProfileNode(this.tag, this.type, {this.server = ""});
  final String tag;
  final String type;
  final String server;
}

List<ProfileNode> profileNodesFromJson(String source) {
  final document = jsonDecode(source);
  if (document is! Map<String, dynamic>)
    throw const FormatException('Expected a configuration object');
  final outbounds = document['outbounds'];
  if (outbounds is! List) throw const FormatException('Missing outbounds');
  const excluded = {'direct', 'block', 'dns', 'selector', 'urltest'};
  final tags = <String>{};
  return [
    for (final outbound in outbounds)
      if (outbound is Map<String, dynamic> &&
          outbound['tag'] is String &&
          (outbound['tag'] as String).isNotEmpty &&
          outbound['type'] is String &&
          !excluded.contains(outbound['type']) &&
          tags.add(outbound['tag'] as String))
        ProfileNode(outbound['tag'] as String, outbound['type'] as String, server: outbound['server'] is String ? outbound['server'] as String : ''),
  ];
}

/// Stable presentation sort: valid measured nodes first; unknown/failed stay last.
List<ProfileNode> sortProfileNodesByPing(List<ProfileNode> nodes, Map<String, int> delays) {
  final indexed = nodes.asMap().entries.toList();
  int rank(ProfileNode node) {
    final delay = delays[node.tag];
    return delay != null && ConnectionConst.isValidDelay(delay) ? delay : 0x7fffffff;
  }
  indexed.sort((a,b) {
    final order = rank(a.value).compareTo(rank(b.value));
    return order != 0 ? order : a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}
