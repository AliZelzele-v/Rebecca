import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/model/profile_nodes.dart';
void main() {
  test('valid measurements first, stable ties, failed and unknown last', () {
    const nodes = [ProfileNode('unknown','vless'), ProfileNode('slow','vless'), ProfileNode('failed','vless'), ProfileNode('fast','vless'), ProfileNode('tie','vless')];
    final result = sortProfileNodesByPing(nodes, {'slow': 200, 'failed': 65000, 'fast': 25, 'tie': 25});
    expect(result.map((n) => n.tag), ['fast','tie','slow','unknown','failed']);
    expect(nodes.first.tag, 'unknown');
  });
  test('no measurements preserves subscription order', () {
    const nodes = [ProfileNode('a','vless'),ProfileNode('b','trojan')];
    expect(sortProfileNodesByPing(nodes, {}).map((n) => n.tag), ['a','b']);
  });
}
