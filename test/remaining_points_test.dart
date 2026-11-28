import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/dashboard/notifications_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('41: list times are short enough to show in full', () {
    expect(shortAgo('2 weeks ago'), '2w');
    expect(shortAgo('1 month ago'), '1mo');
    expect(shortAgo('41 minutes ago'), '41m');
    expect(shortAgo('Just now'), 'now');
    expect(shortAgo('yesterday'), 'yesterday');
  });

  test('49: one distance format everywhere', () {
    expect(formatKm(2.34), '2.3 km');
    expect(formatKm(1453.1), '1,453 km');
    expect(formatKm(544.7), '545 km');
    expect(roleLabel('recruiter'), 'Recruiter');
  });

  test('43: untitled alerts get readable titles', () {
    expect(notificationTitles['kyc.reviewed'], 'KYC reviewed');
    expect(notificationTitles['screening.completed'], 'AI call finished');
  });

  test('33, 50: the dashboard carries unread counts and the plan state', () {
    final data = DashboardData.fromJson({
      'greeting': 'Test',
      'hiring_paused': true,
      'stats': {'unread_notifications': 0, 'unread_messages': 3},
    });
    expect(data.hiringPaused, isTrue);
    expect(data.unreadNotifications, 0);
    expect(data.unreadMessages, 3);
    expect(DashboardData.fromJson({'greeting': 'x'}).hiringPaused, isFalse);
  });
}
