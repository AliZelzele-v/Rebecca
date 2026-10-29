import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/router/go_router/routing_config_notifier.dart';
void main() {
  test('mobile destinations map to the matching branch and back', () {
    for (final name in ['home','profiles','settings']) {
      final index = getIndexOfBranch(true,true,name);
      expect(getNameOfBranch(true,true,index), name);
    }
    expect(getIndexOfBranch(true,true,'settings'), 2);
  });
  test('desktop conditional profiles branch retains existing indices', () {
    expect(getIndexOfBranch(false,false,'settings'),1);
    expect(getIndexOfBranch(false,true,'settings'),2);
  });
}
