import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/widget/rebecca_server_content.dart';
void main() {
  for (final width in [320.0, 360.0, 600.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('protocol rail fits $width $direction with large text', (tester) async {
        tester.view.physicalSize = Size(width,800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(size: Size(width,800),textScaler: const TextScaler.linear(1.5)),
          child: Directionality(textDirection: direction, child: Scaffold(body: Align(
            alignment: Alignment.topCenter, child: Card(child: RebeccaServerContent(protocol: 'VLESS',selected: true,
              child: ListTile(title: const Text('Germany server with a very long name',maxLines: 1,overflow: TextOverflow.ellipsis),
                subtitle: const Text('example.***.org',maxLines: 1),
                trailing: Row(mainAxisSize: MainAxisSize.min,children: const [Text('137 ms'),Icon(Icons.chevron_right)])),
            )),
          ))),
        )));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('VLESS'), findsOneWidget);
      });
    }
  }
}
