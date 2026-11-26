import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_sip/src/app.dart';
import 'package:shadow_sip/src/services/sip_controller.dart';

void main() {
  testWidgets('shows the Shadow-SIP dialer shell', (tester) async {
    final controller = SipController();
    await tester.pumpWidget(ShadowSipApp(controller: controller));

    expect(find.text('Shadow-SIP'), findsOneWidget);
    expect(find.text('Dialer'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
