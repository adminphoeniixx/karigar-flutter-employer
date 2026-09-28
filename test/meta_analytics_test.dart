import 'dart:convert';

import 'package:employer_kariger_app/core/analytics/meta_analytics.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(channelName);
  late List<MethodCall> calls;
  late MetaAnalytics analytics;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    analytics = MetaAnalytics(supported: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'SDK config does not double-log activation or collect advertiser IDs',
    () async {
      await analytics.initialize();
      expect(calls.single.method, 'setAdvertiserIdCollectionEnabled');
      expect(calls.single.arguments, false);
    },
  );

  test(
    'essential events discard personal fields and unnecessary metadata',
    () async {
      await analytics.event(
        'job_published',
        parameters: {
          'fb_content_type': 'job',
          'has_query': true,
          'result_count': 3,
          'phone': 'private phone',
          'otp': 'private otp',
          'email': 'private email',
          'gstin': 'private gstin',
          'description': 'private description',
          'message': 'private message',
          'fb_content_id': ['not a scalar'],
        },
      );
      expect(calls.single.arguments['parameters'], {'fb_content_type': 'job'});
    },
  );

  test(
    'nonessential events are blocked even if a caller tries to send them',
    () async {
      for (final name in [
        'screen_view',
        'otp_requested',
        'login_completed',
        'job_draft_saved',
        'job_updated',
        'message_sent',
        'invoice_downloaded',
        'fb_mobile_search',
        'payment_failed',
      ]) {
        await analytics.event(name);
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'only publish, unlock and hire emit service conversion events',
    () async {
      final api = EmployerApiService(
        ApiClient(
          baseUrl: 'https://example.com/api/v1',
          client: MockClient((request) async {
            final body = request.body.isEmpty
                ? <String, dynamic>{}
                : jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'message': request.method == 'POST'
                    ? 'Job posted.'
                    : 'Job updated.',
                'job': {'id': 7, ...body},
              }),
              200,
            );
          }),
        ),
        analytics: analytics,
      );
      await api.saveJob({'title': 'private', 'status': 'active'});
      await api.saveJob({'title': 'private', 'status': 'active'}, id: 7);
      await api.sendOtp('9876543210');
      await api.shortlist(4);
      await api.sendMessage(4, 'private message');
      await api.unlock(4);
      await api.applicantStatus(4, 'rejected');
      await api.applicantStatus(4, 'hired');
      expect(calls.map((call) => call.arguments['name']), [
        'job_published',
        'worker_contact_unlocked',
        'worker_hired',
      ]);
    },
  );

  test('missing plugin does not interrupt app actions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );
    await expectLater(analytics.event('job_published'), completes);
    await expectLater(analytics.initialize(), completes);
    await expectLater(
      MetaAnalytics(supported: false).registrationCompleted(),
      completes,
    );
  });

  test(
    'verified payment recovers persisted total and deduplicates callbacks',
    () async {
      await analytics.rememberCheckout(
        checkoutId: 'sub_1',
        kind: 'subscription',
        contentId: 'basic',
        amount: 588.82,
      );
      expect(calls, isEmpty);
      await analytics.checkoutStarted('sub_1');
      expect(
        calls.single.arguments['name'],
        FacebookAppEvents.eventNameInitiatedCheckout,
      );
      final restarted = MetaAnalytics(supported: true);
      await Future.wait([
        restarted.verifiedPayment('pay_1', 'sub_1'),
        restarted.verifiedPayment('pay_1', 'sub_1'),
      ]);
      final purchases = calls.where((c) => c.method == 'logPurchase').toList();
      expect(purchases, hasLength(1));
      expect(purchases.single.arguments['amount'], 588.82);
      expect(purchases.single.arguments['currency'], 'INR');
      expect(purchases.single.arguments['parameters']['fb_order_id'], 'pay_1');
      final subscriptions = calls.where(
        (c) => c.method == 'logEvent' && c.arguments['name'] == 'Subscribe',
      );
      expect(subscriptions, hasLength(1));
      expect(
        subscriptions.single.arguments.containsKey('_valueToSum'),
        isFalse,
      );
      await MetaAnalytics(supported: true).verifiedPayment('pay_1', 'sub_1');
      expect(calls.where((c) => c.method == 'logPurchase'), hasLength(1));
    },
  );

  test(
    'unknown top-up amount never becomes invented purchase revenue',
    () async {
      await analytics.rememberCheckout(
        checkoutId: 'order_1',
        kind: 'credit_pack',
        contentId: 'topup_25',
      );
      await analytics.verifiedPayment('pay_2', 'order_1');
      expect(calls.where((c) => c.method == 'logPurchase'), isEmpty);
      expect(calls.single.arguments['name'], 'credit_topup_completed');
    },
  );

  test(
    'backend failure never emits purchase or successful hiring events',
    () async {
      final api = EmployerApiService(
        ApiClient(
          baseUrl: 'https://example.com/api/v1',
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'message': 'Rejected'}), 422),
          ),
        ),
        analytics: analytics,
      );
      await analytics.rememberCheckout(
        checkoutId: 'sub_1',
        kind: 'subscription',
        contentId: 'basic',
        amount: 588.82,
      );
      await expectLater(
        api.subscriptionCallback({
          'razorpay_payment_id': 'pay_1',
          'razorpay_subscription_id': 'sub_1',
        }),
        throwsA(isA<ApiException>()),
      );
      await expectLater(api.unlock(2), throwsA(isA<ApiException>()));
      await expectLater(
        api.saveJob({'title': 'Private title', 'status': 'active'}),
        throwsA(isA<ApiException>()),
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'backend-verified purchase logs once while draft saving emits no event',
    () async {
      final api = EmployerApiService(
        ApiClient(
          baseUrl: 'https://example.com/api/v1',
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.endsWith('/jobs')
                    ? {
                        'message': 'Draft saved.',
                        'job': {
                          'id': 7,
                          'status': 'draft',
                          'title': 'Private title',
                        },
                      }
                    : {'message': 'Subscription activated!'},
              ),
              200,
            ),
          ),
        ),
        analytics: analytics,
      );
      await analytics.rememberCheckout(
        checkoutId: 'sub_1',
        kind: 'subscription',
        contentId: 'basic',
        amount: 588.82,
      );
      await api.saveJob({'title': 'Private title', 'status': 'draft'});
      await api.subscriptionCallback({
        'razorpay_payment_id': 'pay_1',
        'razorpay_subscription_id': 'sub_1',
      });
      // Wait behind the API's fire-and-forget analytics operation.
      await analytics.verifiedPayment('pay_1', 'sub_1');
      expect(calls.where((c) => c.method == 'logPurchase'), hasLength(1));
      expect(
        calls.where(
          (c) =>
              c.method == 'logEvent' &&
              c.arguments['name'] == 'job_draft_saved',
        ),
        isEmpty,
      );
      expect(
        jsonEncode(calls.map((c) => c.arguments).toList()),
        isNot(contains('Private title')),
      );
    },
  );
}
