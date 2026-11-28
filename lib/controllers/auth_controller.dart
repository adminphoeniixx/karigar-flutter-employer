import '../core/api/api_exception.dart';
import '../models/api_models.dart';
import '../services/employer_api_service.dart';
import 'base_controller.dart';

class AuthController extends BaseController {
  AuthController(this.api);
  final EmployerApiService api;

  bool get authenticated => api.client.isAuthenticated;
  Json? user;

  Future<bool> sendOtp(String phone) async =>
      await run(() => api.sendOtp(phone)) != null;

  Future<Json?> verifyOtp(String phone, String otp) => run(() async {
    final response = await api.verifyOtp(phone, otp);
    final token = response['token']?.toString();
    await api.client.setToken(token);
    user = response['user'] is Map
        ? Map<String, dynamic>.from(response['user'])
        : null;
    return response;
  });

  /// Restores the saved session on app start. Only a 401 (the server no
  /// longer accepts the token) signs the user out. No internet, a slow or
  /// failing server keep the session: the screens retry their own calls, and
  /// signing out there would make an offline user log in again.
  Future<bool> restore() async {
    await api.client.initialize();
    if (!authenticated) return false;
    try {
      final response = await api.me().timeout(const Duration(seconds: 10));
      user = response['user'] is Map
          ? Map<String, dynamic>.from(response['user'])
          : null;
    } on ApiException catch (exception) {
      if (exception.statusCode == 401) {
        await api.client.setToken(null);
        user = null;
        notifyListeners();
        return false;
      }
    } catch (_) {
      // Timeout or anything unexpected: keep the session.
    }
    notifyListeners();
    return true;
  }

  /// Runs before the server logout, while the API still accepts this login
  /// (the app removes this phone's push token here).
  Future<void> Function()? beforeLogout;

  Future<void> logout() async {
    try {
      await beforeLogout?.call();
    } catch (_) {
      // Signing out must never fail because of this.
    }
    await run(api.logout);
    await api.client.setToken(null);
    clearSession();
  }

  /// Clears local authentication after the server has already deleted the
  /// account. This deliberately does not call the logout endpoint.
  void clearSession() {
    user = null;
    notifyListeners();
  }
}

/// Whether this employer still has to finish sign-up. The server's
/// `hiring_as` is set once step 5 is finished or skipped; builds of the
/// server without it fall back to "no company name", which is wrong for an
/// individual (they have none) and kept sending them back to sign-up.
bool employerNeedsRegistration(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (user.containsKey('hiring_as')) {
    return '${user['hiring_as'] ?? ''}'.trim().isEmpty;
  }
  return '${user['company_name'] ?? ''}'.trim().isEmpty;
}
