import 'dart:async';

import 'package:employer_kariger_app/app.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    expect(find.text('Super Karigar Employer'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Super Karigar Employer'), findsOneWidget);
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

    expect(find.text('Super Karigar Employer'), findsOneWidget);
    expect(find.text('Kaam. Hunar. Bharosa.'), findsOneWidget);

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
