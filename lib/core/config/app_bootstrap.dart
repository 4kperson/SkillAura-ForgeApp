import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_env.dart';

abstract final class AppBootstrap {
  static Future<void> initialize() async {
    if (AppEnv.hasSupabaseConfig) {
      await Supabase.initialize(
        url: AppEnv.supabaseUrl,
        publishableKey: AppEnv.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: true,
        ),
      );
    }

    // Firebase initialization is enabled after google-services.json and
    // GoogleService-Info.plist are added with FlutterFire CLI.
    try {
      await Firebase.initializeApp();
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    } catch (_) {
      // Local development remains runnable before Firebase setup.
    }
  }

  static Future<void> recordFatalError(Object error, StackTrace stack) async {
    if (kDebugMode) {
      debugPrint('Uncaught error: $error');
      debugPrintStack(stackTrace: stack);
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Avoid recursive failures while reporting an application crash.
    }
  }
}
