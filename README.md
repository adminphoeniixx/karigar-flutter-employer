# employer_kariger_app

## API setup

The latest supplied backend contract is included in [docs/employer-app-api.md](docs/employer-app-api.md).
Contact unlocks, contact lists and plan changes are described in
[docs/employer-app-contacts-and-plans.md](docs/employer-app-contacts-and-plans.md).
Import [the Postman collection](docs/karigar-employer-app.postman_collection.json) to exercise these endpoints.
The supplied release notes mark the new contact lists and plan updates as dependent on the next server deployment. The API base URL
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

## Verification

Run `flutter pub get`, `flutter analyze`, and `flutter test`. Contact actions use
`url_launcher`, so rebuild and restart the native app after updating dependencies.
Call, WhatsApp, email and Razorpay checkout should also be tested on a signed-in
device with the corresponding apps/payment configuration available.
