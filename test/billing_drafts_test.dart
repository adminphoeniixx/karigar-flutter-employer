import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:employer_kariger_app/core/billing/billing.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:employer_kariger_app/screens/profile/invoice_screen.dart';

Widget harness(EmployerApiService api, Widget child) => AppScope(
  api: api,
  auth: AuthController(api),
  dashboard: DashboardController(api),
  jobs: JobsController(api),
  workers: WorkersController(api),
  profile: ProfileController(api),
  child: MaterialApp(home: child),
);
http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
EmployerApiService service(
  Future<http.Response> Function(http.Request) handler,
) => EmployerApiService(
  ApiClient(client: MockClient(handler), baseUrl: 'https://example.com/api/v1'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'GST uses server split, IGST, zero tax, and legacy invoice fallback',
    () {
      final sameState = taxLines({
        'gst': '89.82',
        'gst_percent': 18,
        'cgst': '44.91',
        'sgst': 44.91,
        'igst': 0,
      });
      expect(sameState.map((line) => line.label), ['CGST (9%)', 'SGST (9%)']);
      expect(sameState.map((line) => line.amount), [44.91, 44.91]);
      expect(
        taxLines({'gst': 89.82, 'gst_percent': 18, 'igst': 89.82}).single.label,
        'IGST (18%)',
      );
      expect(taxLines({'gst': 0, 'gst_percent': 0}), isEmpty);
      expect(
        taxLines({
          'gst_amount': 89.82,
          'gst_percent': 18,
          'cgst_amount': null,
          'igst_amount': null,
        }, invoice: true).single.label,
        'GST (18%)',
      );
      expect(percent(0), '0');
    },
  );

  test('PDF uses bearer auth and rejects external download hosts', () async {
    SharedPreferences.setMockInitialValues({});
    final api = service((request) async {
      expect(request.url.path, '/api/v1/employer/invoices/12/pdf');
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers['accept'], contains('application/pdf'));
      return http.Response(
        '%PDF-1.4 test',
        200,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition': 'attachment; filename="Invoice-KRG-12.pdf"',
        },
      );
    });
    await api.client.setToken('test-token');
    final pdf = await api.invoicePdf(
      12,
      url: 'https://example.com/api/v1/employer/invoices/12/pdf',
    );
    expect(pdf.filename, 'Invoice-KRG-12.pdf');
    expect(String.fromCharCodes(pdf.bytes), startsWith('%PDF-'));
    await expectLater(
      api.invoicePdf(12, url: 'https://other.example/invoice.pdf'),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'job draft create and publish use POST then PUT and retain server message',
    () async {
      final requests = <http.Request>[];
      final api = service((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map;
        return jsonResponse({
          'message': body['status'] == 'draft' ? 'Draft saved.' : 'Job posted.',
          'job': {
            'id': 12,
            ...body,
            'is_draft': body['status'] == 'draft',
            'published_at': body['status'] == 'draft'
                ? null
                : '2026-09-28T09:00:00Z',
          },
        });
      });
      expect(
        (await api.saveJob({'title': 'Mason', 'status': 'draft'}))['message'],
        'Draft saved.',
      );
      final result = await api.saveJob({
        'title': 'Mason',
        'description': 'Build a villa',
        'vacancies': 2,
        'status': 'active',
      }, id: 12);
      expect(result['message'], 'Job posted.');
      expect(requests.map((r) => r.method), ['POST', 'PUT']);
      expect(EmployerJob.fromJson(Json.from(result['job'])).isDraft, isFalse);
      expect(
        EmployerJob.fromJson(Json.from(result['job'])).publishedAt,
        isNotNull,
      );
    },
  );

  testWidgets('title-only draft saves without publish validation', (
    tester,
  ) async {
    Json? saved;
    final api = service((request) async {
      if (request.method == 'POST') {
        saved = Json.from(jsonDecode(request.body));
        return jsonResponse({
          'message': 'Draft saved.',
          'job': {'id': 1, ...saved!},
        }, 201);
      }
      return jsonResponse({});
    });
    await tester.pumpWidget(harness(api, const PostJobScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mason for villa');
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.tap(find.text('Post job'));
    await tester.pump();
    expect(saved, isNull);
    await tester.tap(find.text('Save as draft'));
    await tester.pumpAndSettle();
    expect(saved?['title'], 'Mason for villa');
    expect(saved?['status'], 'draft');
    expect(saved!.containsKey('description'), isFalse);
    expect(saved!.containsKey('vacancies'), isFalse);
  });

  final draft = EmployerJob.fromJson({
    'id': 12,
    'title': 'Mason',
    'description': 'Build villa',
    'category': 'Masonry',
    'state': 'Haryana',
    'city': 'Gurugram',
    'wage_min': 800,
    'vacancies': 2,
    'contact_mode': 'apply',
    'status': 'draft',
    'is_draft': true,
  });
  testWidgets(
    'existing live job has only active/closed status and saves with PUT',
    (tester) async {
      Json? saved;
      final api = service((request) async {
        if (request.method == 'PUT') {
          saved = Json.from(jsonDecode(request.body));
          return jsonResponse({'message': 'Job updated.', 'job': saved});
        }
        return jsonResponse({});
      });
      final live = EmployerJob.fromJson({
        'id': 14,
        'title': 'Live mason',
        'description': 'Build villa',
        'category': 'Masonry',
        'state': 'Haryana',
        'city': 'Gurugram',
        'wage_min': 800,
        'vacancies': 2,
        'contact_mode': 'apply',
        'status': 'active',
        'is_draft': false,
      });
      await tester.pumpWidget(harness(api, PostJobScreen(job: live)));
      await tester.pumpAndSettle();
      expect(find.text('Save draft'), findsNothing);
      expect(find.text('Publish'), findsNothing);
      await tester.tap(find.text('closed'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(saved?['status'], 'closed');
      expect(saved?['title'], 'Live mason');
    },
  );

  testWidgets('posting limit preserves form and can save draft with PUT', (
    tester,
  ) async {
    final statuses = <String>[];
    const message =
        'You have used all 5 job posts in your plan for this billing period. Save it as a draft, or upgrade your plan.';
    final api = service((request) async {
      if (request.method == 'PUT') {
        final body = Json.from(jsonDecode(request.body));
        statuses.add(body['status']);
        return body['status'] == 'active'
            ? jsonResponse({'message': message}, 422)
            : jsonResponse({'message': 'Draft saved.', 'job': body});
      }
      return jsonResponse({});
    });
    await tester.pumpWidget(harness(api, PostJobScreen(job: draft)));
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsOneWidget);
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.text('See plans'), findsOneWidget);
    await tester.tap(find.text('Save as draft'));
    await tester.pumpAndSettle();
    expect(statuses, ['active', 'draft']);
  });

  testWidgets('Razorpay resync verifies a recovered subscription callback', (
    tester,
  ) async {
    var recovered = false;
    Json? callback;
    const channel = MethodChannel('razorpay_flutter');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'resync' && !recovered) {
        recovered = true;
        return {
          'type': 0,
          'data': {
            'razorpay_payment_id': 'pay_recovered',
            'razorpay_subscription_id': 'sub_recovered',
            'razorpay_signature': 'sig_recovered',
          },
        };
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final api = service((request) async {
      if (request.url.path.endsWith('/callback')) {
        callback = Json.from(jsonDecode(request.body));
        return jsonResponse({'message': 'Payment verified.'});
      }
      return jsonResponse({'plans': []});
    });
    await tester.pumpWidget(harness(api, const PlansScreen()));
    await tester.pumpAndSettle();
    expect(callback?['razorpay_subscription_id'], 'sub_recovered');
    expect(callback?['razorpay_payment_id'], 'pay_recovered');
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan labels and GST confirmation precede native checkout', (
    tester,
  ) async {
    final nativeCalls = <MethodCall>[];
    Json? callback;
    const channel = MethodChannel('razorpay_flutter');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeCalls.add(call);
      if (call.method == 'open') {
        return {
          'type': 0,
          'data': {
            'razorpay_payment_id': 'pay_test',
            'razorpay_signature': 'sig_test',
          },
        };
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final api = service((request) async {
      if (request.url.path.endsWith('/callback')) {
        callback = Json.from(jsonDecode(request.body));
        return jsonResponse({'message': 'Payment verified.'});
      }
      if (request.method == 'POST') {
        return jsonResponse({
          'razorpay_key': 'test-key',
          'razorpay_subscription_id': 'sub_test',
          'amounts': {
            'subtotal': 499,
            'gst_percent': 18,
            'gst': 89.82,
            'cgst': 44.91,
            'sgst': 44.91,
            'total': 588.82,
          },
        });
      }
      return jsonResponse({
        'payment': {'gst_percent': 18},
        'job_posts': {'used': 3, 'limit': 5, 'unlimited': false},
        'plans': [
          {
            'id': 1,
            'name': 'Basic',
            'price': 499,
            'price_with_gst': 588.82,
            'purchasable': true,
            'recommended': true,
            'feature_list': ['5 job posts per month'],
            'features': {'job_post_limit': 5, 'featured': true},
          },
        ],
      });
    });
    await tester.pumpWidget(harness(api, const PlansScreen()));
    await tester.pumpAndSettle();
    expect(find.text('3 of 5 job posts used this month'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choose Basic'), 220);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('5 job posts per month'), findsOneWidget);
    expect(find.text('job post limit'), findsNothing);
    expect(find.text('+ 18% GST · ₹588.82 total'), findsOneWidget);
    await tester.tap(find.text('Choose Basic'));
    await tester.pumpAndSettle();
    expect(find.text('CGST (9%): ₹44.91'), findsOneWidget);
    expect(find.text('SGST (9%): ₹44.91'), findsOneWidget);
    expect(find.text('Total payable: ₹588.82'), findsOneWidget);
    expect(nativeCalls.where((c) => c.method == 'open'), isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(nativeCalls.where((c) => c.method == 'open'), isEmpty);
    await tester.tap(find.text('Choose Basic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    final opened = nativeCalls.singleWhere((c) => c.method == 'open');
    expect(opened.arguments['subscription_id'], 'sub_test');
    expect(callback?['razorpay_subscription_id'], 'sub_test');
    expect(callback?['razorpay_payment_id'], 'pay_test');
    expect(callback?['razorpay_signature'], 'sig_test');
  });

  testWidgets('invoice displays legacy GST, SAC, supply and PDF action', (
    tester,
  ) async {
    final api = service(
      (_) async => jsonResponse({
        'invoice': {
          'number': 'KRG-12',
          'gst_amount': 89.82,
          'gst_percent': 18,
          'place_of_supply': 'Haryana (06)',
          'sac': '998365',
          'total': 588.82,
        },
        'pdf_url': 'https://example.com/api/v1/employer/invoices/12/pdf',
      }),
    );
    await tester.pumpWidget(
      harness(api, const InvoiceScreen(subscriptionId: 12)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('GST (18%)'), findsOneWidget);
    expect(find.text('Haryana (06)'), findsOneWidget);
    expect(find.text('998365'), findsOneWidget);
  });
}
