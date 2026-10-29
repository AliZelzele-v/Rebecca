import 'dart:convert';

/// Only presentation metadata is retained; credentials never leave the config.
class ProfileNode {
  const ProfileNode(this.tag, this.type);
  final String tag;
  final String type;
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
        ProfileNode(outbound['tag'] as String, outbound['type'] as String),
  ];
}
