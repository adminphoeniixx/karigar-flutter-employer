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
    await api.client.setToken(response['token']?.toString());
    user = response['user'] is Map
        ? Map<String, dynamic>.from(response['user'])
        : null;
    return response;
  });

  Future<bool> restore() async {
    await api.client.initialize();
    if (!authenticated) return false;
    final response = await run(api.me);
    user = response?['user'] is Map
        ? Map<String, dynamic>.from(response!['user'])
        : null;
    if (response == null) await api.client.setToken(null);
    return response != null;
  }

  Future<void> logout() async {
    await run(api.logout);
    await api.client.setToken(null);
    user = null;
    notifyListeners();
  }
}
