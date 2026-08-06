# employer_kariger_app

## API setup

The complete backend contract is included in [API.md](API.md). The API base URL
and endpoint paths are centralized in
`lib/constants/api_constants.dart`. The configured backend is
`https://projects-karigar.rmsiry.easypanel.host/api/v1`.

Authentication tokens are persisted with `shared_preferences`. All API calls
send `Accept: application/json`, JSON requests send `Content-Type:
application/json`, and authenticated calls automatically include the Sanctum
bearer token.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
