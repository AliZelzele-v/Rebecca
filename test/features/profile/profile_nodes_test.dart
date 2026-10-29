import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/model/profile_nodes.dart';

void main() {
  test(
    'subscription rows contain servers, not routing helpers or duplicate tags',
    () {
      final nodes = profileNodesFromJson('''{"outbounds":[
      {"tag":"select","type":"selector","outbounds":["Germany"]},
      {"tag":"direct","type":"direct"},
      {"tag":"Germany","type":"vless","uuid":"private"},
      {"tag":"Germany","type":"vless"},
      {"tag":"Finland","type":"trojan","password":"private"},
      {"tag":"dns","type":"dns"},
      {"tag":"auto","type":"urltest"},
      {"type":"vmess"},null
    ]}''');
      expect(nodes.map((node) => node.tag), ['Germany', 'Finland']);
      expect(nodes.map((node) => node.type), ['vless', 'trojan']);
    },
  );
  test(
    'malformed configurations are reported instead of looking like an empty subscription',
    () {
      expect(() => profileNodesFromJson('not json'), throwsFormatException);
      expect(() => profileNodesFromJson('[]'), throwsFormatException);
      expect(() => profileNodesFromJson('{}'), throwsFormatException);
      expect(profileNodesFromJson('{"outbounds":[]}'), isEmpty);
    },
  );
}
