import 'package:flutter/material.dart';

import 'app_services.dart';
import 'love21_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LoveBackend.initialize();
  runApp(const Love21App());
}
