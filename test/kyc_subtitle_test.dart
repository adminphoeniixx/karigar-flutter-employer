import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/profile/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

EmployerProfile profile(Map<String, dynamic> json) =>
    EmployerProfile.fromJson({'id': 1, 'name': 'A', 'company_name': 'B', ...json});

void main() {
  test('an individual is told Aadhaar, never GST & PAN', () {
    expect(
      kycSubtitle(profile({'verified': true, 'hiring_as': 'individual'})),
      'Aadhaar & address verified',
    );
  });

  test('a business with a GST number is told GST', () {
    expect(
      kycSubtitle(
        profile({
          'verified': true,
          'hiring_as': 'business',
          'gstin': '22ABCDE1234F1ZA',
        }),
      ),
      'GST verified',
    );
  });

  test('a business without GST is told business verified', () {
    expect(
      kycSubtitle(profile({'verified': true, 'hiring_as': 'contractor'})),
      'Business verified',
    );
  });

  test('not verified yet asks to finish it', () {
    expect(
      kycSubtitle(profile({'verified': false, 'hiring_as': 'individual'})),
      'Complete your business verification',
    );
    expect(kycSubtitle(null), 'Complete your business verification');
  });
}
