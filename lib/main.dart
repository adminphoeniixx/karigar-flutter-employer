import 'dart:async';
import 'core/analytics/meta_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(MetaAnalytics.instance.initialize());
  runApp(const KarigarEmployerApp(onInitialize: _initializeFirebase));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('[Firebase] Initialization failed: $error');
  }
}
