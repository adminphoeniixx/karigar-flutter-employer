import 'dart:async';

import 'package:employer_kariger_app/app.dart';
import 'package:employer_kariger_app/screens/auth/onboarding_screen.dart';
import 'package:employer_kariger_app/screens/dashboard/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests answer every real HTTP call with a 400, so the launch checks
/// and `/auth/me` all fail: like a server that is having a bad day.
Future<void> launch(WidgetTester tester, Future<void> Function() firebase) async {
  SharedPreferences.setMockInitialValues({'employer_auth_token': 'saved'});
  await tester.pumpWidget(KarigarEmployerApp(onInitialize: firebase));
  // Past the splash and every startup timeout.
  for (var second = 0; second < 15; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('a Firebase start that never finishes still restores the login', (
    tester,
  ) async {
    await launch(tester, () => Completer<void>().future);

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('a Firebase start that fails still restores the login', (
    tester,
  ) async {
    await launch(tester, () async => throw Exception('no google services'));

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
