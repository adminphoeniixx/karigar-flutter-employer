import 'package:employer_kariger_app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows employer onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KarigarEmployerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Hire skilled\nworkers, fast.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
