import 'dart:async';

import 'package:employer_kariger_app/app.dart';
import 'package:employer_kariger_app/screens/splash_screen.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/core/app_theme_controller.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dark theme selection is applied and persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppThemeController();
    await controller.restore();

    await controller.setDark(true);

    expect(controller.mode, ThemeMode.dark);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('employer_theme_mode'), 'dark');
    controller.dispose();
  });

  testWidgets('theme can change while an outlined button is visible', (
    tester,
  ) async {
    Widget app(ThemeMode mode) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: Scaffold(
        body: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.card,
            foregroundColor: const Color(0xFFE11D48),
          ),
          child: const Text('Log out'),
        ),
      ),
    );

    await tester.pumpWidget(app(ThemeMode.light));
    await tester.pumpWidget(app(ThemeMode.dark));

    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(360, 800),
    const Size(430, 932),
    const Size(390, 844),
    const Size(412, 915),
    const Size(768, 1024),
    const Size(844, 390),
  ]) {
    testWidgets('splash fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/splash.png'),
          tester.element(find.byType(SplashScreen)),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SplashScreen)), size);
      final image = tester.widget<Image>(find.byType(Image));
      final fitted = applyBoxFit(
        image.fit!,
        const Size(1080, 1920),
        tester.getSize(find.byType(Image)),
      );
      // The artwork fills the display, including behind both system bars.
      expect(fitted.destination.width, closeTo(size.width, .001));
      expect(fitted.destination.height, closeTo(size.height, .001));
      expect(tester.getRect(find.byType(Image)), Offset.zero & size);
      if (size.width / size.height < .65) {
        final visible = Alignment.center.inscribe(
          fitted.source,
          const Rect.fromLTWH(0, 0, 1080, 1920),
        );
        expect(visible.contains(const Offset(210, 1040)), isTrue);
        expect(visible.contains(const Offset(870, 1530)), isTrue);
      }
    });
  }

  testWidgets('original splash stays visible while initialization is pending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final initialization = Completer<void>();
    var started = false;
    await tester.pumpWidget(
      KarigarEmployerApp(
        onInitialize: () {
          started = true;
          return initialization.future;
        },
      ),
    );
    expect(started, isTrue);
    expect(
      find.bySemanticsLabel('Super Karigar Employer. Kaam. Hunar. Bharosa.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.bySemanticsLabel('Super Karigar Employer. Kaam. Hunar. Bharosa.'),
      findsOneWidget,
    );
    expect(find.text('Get Started'), findsNothing);
    initialization.complete();
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows employer onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KarigarEmployerApp());
    await tester.pump();

    expect(
      find.bySemanticsLabel('Super Karigar Employer. Kaam. Hunar. Bharosa.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Hire skilled\nworkers, fast.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('filled button can render inside a row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('25 credits')),
              FilledButton(onPressed: () {}, child: const Text('Buy')),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets('key UI does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KarigarEmployerApp());
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    const worker = Worker(
      'A very long worker name for responsive testing',
      'Commercial Electrician',
      12,
      4.9,
      18.5,
      1250,
      ['Electrical wiring', 'Commercial maintenance'],
      status: 'Shortlisted',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(8),
            child: WorkerCard(worker: worker),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
