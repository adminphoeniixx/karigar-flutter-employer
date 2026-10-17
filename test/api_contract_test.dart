import 'dart:convert';

import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Employer API response contract', () {
    test('unwraps single-resource data envelopes', () async {
      final client = MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/v1/employer/profile' => {
            'data': {'id': 3, 'name': 'Anil', 'company_name': 'Sri Sai'},
          },
          '/api/v1/employer/jobs/12' => {
            'data': {
              'id': 12,
              'title': 'Plumber',
              'category': 'Plumbing',
              'status': 'active',
              'wage_label': '₹800 / daily',
            },
          },
          '/api/v1/employer/applicants/14' => {
            'data': {
              'id': 14,
              'stage': 'interview',
              'worker': {'id': 9, 'name': 'Suresh'},
            },
          },
          _ => <String, dynamic>{},
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = EmployerApiService(
        ApiClient(client: client, baseUrl: 'https://example.com/api/v1'),
      );

      expect((await api.profile()).id, 3);
      expect((await api.job(12)).title, 'Plumber');
      expect((await api.applicant(14)).worker.name, 'Suresh');
    });

    test('encodes AI suggestion list query using bracket notation', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'suggestions': ['Draft one'],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = EmployerApiService(
        ApiClient(client: client, baseUrl: 'https://example.com/api/v1'),
      );

      final suggestions = await api.suggestJobDescription(
        title: 'Apartment plumber',
        skills: const ['Plumbing', 'Pipe Fitting'],
      );

      expect(suggestions, ['Draft one']);
      expect(requested.queryParametersAll['skills[]'], [
        'Plumbing',
        'Pipe Fitting',
      ]);
      expect(requested.queryParameters['title'], 'Apartment plumber');
    });

    test(
      'reads the newest screening call and fetches its conversation',
      () async {
        late Uri requested;
        final client = MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'call': {
                'id': 79,
                'has_conversation': true,
                'conversation': [
                  {'speaker': 'agent', 'text': 'नमस्ते'},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final api = EmployerApiService(
          ApiClient(client: client, baseUrl: 'https://example.com/api/v1'),
        );
        final applicant = Applicant.fromJson({
          'id': 14,
          'worker': {'id': 9, 'name': 'Atul'},
          'ai': {'score': 82, 'recommendation_label': 'Strong match'},
          'screening_call': {
            'id': 79,
            'outcome_label': 'Interested',
            'has_conversation': true,
          },
        });

        expect(applicant.ai?['recommendation_label'], 'Strong match');
        expect(applicant.screeningCall?['outcome_label'], 'Interested');
        expect((await api.screeningCall(79))['call'], isA<Map>());
        expect(requested.path, '/api/v1/employer/screening-calls/79');
      },
    );

    test(
      'returns the shortlist call message and applicant call state',
      () async {
        late Uri requested;
        final client = MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'message':
                  'Applicant shortlisted — AI call booked for 17 Oct, 10:00 AM.',
              'applicant': {
                'id': 412,
                'screening_call': {
                  'id': 88,
                  'status': 'scheduled',
                  'status_label': 'Scheduled',
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final api = EmployerApiService(
          ApiClient(client: client, baseUrl: 'https://example.com/api/v1'),
        );

        final response = await api.shortlist(412);

        expect(requested.path, '/api/v1/employer/applicants/412/shortlist');
        expect(response['message'], contains('AI call booked'));
        expect((response['applicant'] as Map)['screening_call'], isA<Map>());
      },
    );
  });
}
