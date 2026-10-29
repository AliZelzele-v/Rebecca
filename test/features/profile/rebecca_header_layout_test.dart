import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/widget/profile_group_header.dart';

void main() {
  for (final width in [320.0, 360.0, 600.0]) {
    for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
      testWidgets(
        'subscription stays compact at $width / $direction with large text',
        (tester) async {
          tester.view.resetPhysicalSize();
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1000),
                  textScaler: const TextScaler.linear(1.5),
                ),
                child: Directionality(
                  textDirection: direction,
                  child: Scaffold(
                    body: ListView(
                      children: [
                        ProfileGroupHeader(
                          title:
                              'Subscription / اشتراک آزمایشی با نام بلند (۱۲)',
                          icon: Icons.sync,
                          active: true,
                          expanded: true,
                          onToggle: () {},
                          // Reproduce the expanding Stack in upstream ProfileActionButton.
                          action: Stack(
                            fit: StackFit.expand,
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                          testAction: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.speed),
                          ),
                          details: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LinearProgressIndicator(value: .4),
                              SizedBox(height: 8),
                              Text('۱۲ روز باقی‌مانده · 4 GB / 50 GB'),
                            ],
                          ),
                        ),
                        const ListTile(title: Text('Germany - TCP')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(ProfileGroupHeader)).height,
            lessThan(230),
          );
          expect(
            tester.getTopLeft(find.text('Germany - TCP')).dy,
            lessThan(300),
          );
        },
      );
    }
  }
}
