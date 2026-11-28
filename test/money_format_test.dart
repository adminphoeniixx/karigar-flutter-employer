import 'package:employer_kariger_app/core/billing/billing.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('indianDigits groups by lakh and crore', () {
    expect(indianDigits(0), '0');
    expect(indianDigits(999), '999');
    expect(indianDigits(1178), '1,178');
    expect(indianDigits(150000), '1,50,000');
    expect(indianDigits(12345678), '1,23,45,678');
    expect(indianDigits(-1178), '-1,178');
  });

  test('money keeps paise and adds the commas', () {
    expect(money(1178.82), '₹1,178.82');
    expect(money('588.82'), '₹588.82');
    expect(money(null), '₹0.00');
    expect(money(150000), '₹1,50,000.00');
  });

  test('monthlyWage still reads per month', () {
    expect(monthlyWage(15000), '₹15,000/month');
    expect(monthlyWage(0), '—');
  });
}
