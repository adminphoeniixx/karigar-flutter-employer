import 'auth_controller.dart';

/// Every way out of an account (log out, signing out this device from
/// Sessions, deleting the account, a wrong-role OTP login) ends with the
/// token gone. When that happens this drops the previous account's data held
/// in memory (jobs, karigars, dashboard, profile), or the next account to log
/// in would see it.
class AccountDataReset {
  AccountDataReset(this.auth, this.clears)
    : _wasAuthenticated = auth.authenticated {
    auth.addListener(_check);
  }

  final AuthController auth;
  final List<void Function()> clears;
  bool _wasAuthenticated;

  void _check() {
    final authenticated = auth.authenticated;
    if (_wasAuthenticated && !authenticated) {
      for (final clear in clears) {
        clear();
      }
    }
    _wasAuthenticated = authenticated;
  }

  void dispose() => auth.removeListener(_check);
}
