import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../services/employer_api_service.dart';
import '../../screens/dashboard/notifications_screen.dart';
import 'push_router.dart';

/// Push notifications from the server (FCM, Firebase project kariger-da3ac).
///
/// The server sends each push with a title and body, which Android shows by
/// itself while the app is closed or in the background. This class:
/// - registers the phone's FCM token with `POST /device-tokens` once signed
///   in, and again whenever Firebase rotates it;
/// - removes it with `DELETE /device-tokens` before signing out, so the next
///   person on this phone does not get this account's pushes;
/// - shows a push that arrives while the app is open as a bar with "Open";
/// - opens the matching screen when a push is tapped ([screenForNotification]).
class PushNotifications {
  PushNotifications({
    required this.api,
    required this.navigatorKey,
    required this.messengerKey,
  });

  final EmployerApiService api;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  String? _registeredToken;
  bool _listening = false;

  /// Bumped by [stop]: a registration still in flight when the user signs
  /// out is undone as soon as it lands.
  int _session = 0;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Firebase may have failed to start (no network on first launch, a broken
  /// config): push is then simply off for this run.
  bool get _available => Firebase.apps.isNotEmpty;

  /// Called once signed in: asks for permission (Android 13+ and iOS show a
  /// prompt the first time), registers the token and starts listening.
  Future<void> start() async {
    if (!_available) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _listen(messaging);
      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (error) {
      debugPrint('[Push] could not start: $error');
    }
  }

  /// Called before signing out, while the API still accepts this login.
  Future<void> stop() async {
    _session++;
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await api.removeDeviceToken(token);
    } catch (error) {
      // The server also drops a token when FCM reports it gone.
      debugPrint('[Push] could not remove the token: $error');
    }
  }

  /// A push tapped while the app was closed opened it: go to its screen
  /// once the signed-in home is on screen.
  Future<void> openLaunchMessage() async {
    if (!_available) return;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) _open(message.data);
    } catch (error) {
      debugPrint('[Push] could not read the launch message: $error');
    }
  }

  void _listen(FirebaseMessaging messaging) {
    if (_listening) return;
    _listening = true;
    _subscriptions
      ..add(messaging.onTokenRefresh.listen(_register))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data)))
      ..add(FirebaseMessaging.onMessage.listen(_showWhileOpen));
  }

  @visibleForTesting
  Future<void> register(String token) => _register(token);

  Future<void> _register(String token) async {
    if (token == _registeredToken) return;
    final session = _session;
    try {
      await api.registerDeviceToken(token, Platform.isIOS ? 'ios' : 'android');
      if (session != _session) {
        // Signed out meanwhile: take it back off that account.
        await api.removeDeviceToken(token);
        return;
      }
      _registeredToken = token;
    } catch (error) {
      debugPrint('[Push] could not register the token: $error');
    }
  }

  /// Android does not show a push while the app is open, so show it here.
  void _showWhileOpen(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          [title, body].where((part) => part.isNotEmpty).join('\n'),
        ),
        duration: const Duration(seconds: 6),
        // A SnackBar with an action stays up until tapped unless told
        // otherwise; this one sat over the Call / Chat buttons for minutes.
        persist: false,
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _open(message.data),
        ),
      ),
    );
  }

  /// Opens the push's screen, or the notifications list when it has none.
  Future<void> _open(Map<String, dynamic> data) async {
    final screen =
        await screenForNotification(data, api) ?? const NotificationsScreen();
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => screen));
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }
}
