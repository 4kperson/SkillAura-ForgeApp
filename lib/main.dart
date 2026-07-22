import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_bootstrap.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppBootstrap.initialize();
    runApp(const ForgeApp());
  }, AppBootstrap.recordFatalError);
}
