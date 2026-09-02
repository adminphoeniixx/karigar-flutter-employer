import 'dart:convert';

import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
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
  });
}
