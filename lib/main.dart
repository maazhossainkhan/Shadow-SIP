import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/sip_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sip = SipController();
  await sip.initialize();
  runApp(ShadowSipApp(controller: sip));
}
