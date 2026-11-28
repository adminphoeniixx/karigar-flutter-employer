import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/screens/auth/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding does not promise free job posts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.textContaining('free', findRichText: true), findsNothing);
    expect(
      find.textContaining('Talk to them directly', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the new lines read in Hindi', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: const [Locale('en'), Locale('hi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      AppStrings.text(captured, 'Post a job — reach karigars near you instantly'),
      'जॉब पोस्ट करें — पास के कारीगरों तक तुरंत पहुंचें',
    );
    expect(
      AppStrings.text(
        captured,
        'Post your job and reach thousands of work-ready karigars near you. '
        'Talk to them directly — no middlemen.',
      ),
      contains('कोई बिचौलिया नहीं'),
    );
  });
}
