import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-up is pending until hiring_as is set', () {
    expect(employerNeedsRegistration({'hiring_as': null}), isTrue);
    expect(employerNeedsRegistration({'hiring_as': ''}), isTrue);
    expect(employerNeedsRegistration({'hiring_as': 'business'}), isFalse);
  });

  test('an individual with no company name is registered', () {
    expect(
      employerNeedsRegistration({
        'hiring_as': 'individual',
        'company_name': null,
      }),
      isFalse,
    );
  });

  test('older servers without hiring_as fall back to the company name', () {
    expect(employerNeedsRegistration({'company_name': null}), isTrue);
    expect(employerNeedsRegistration({'company_name': 'Sri Sai'}), isFalse);
  });

  test('no user (offline start) never blocks the app', () {
    expect(employerNeedsRegistration(null), isFalse);
  });
}
