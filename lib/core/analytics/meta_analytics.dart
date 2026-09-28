import 'dart:async';
import 'dart:convert';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only fixed event names and non-personal parameters belong in this service.
/// Analytics failures must never interrupt authentication, hiring or payment.
class MetaAnalytics {
  MetaAnalytics({FacebookAppEvents? sdk, bool? supported})
    : _sdk = sdk ?? FacebookAppEvents(),
      _supported =
          supported ??
          (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS));

  static final instance = MetaAnalytics();
  final FacebookAppEvents _sdk;
  final bool _supported;
  Future<void> _purchaseQueue = Future.value();
  final Map<String, Map<String, dynamic>> _checkouts = {};
  final Set<String> _reportedPayments = {};
  static const _paymentsKey = 'meta_reported_payments';
  static const _checkoutKey = 'meta_pending_checkouts';

  static const _allowedEvents = {
    FacebookAppEvents.eventNameCompletedRegistration,
    FacebookAppEvents.eventNameViewedContent,
    'job_published',
    'worker_contact_unlocked',
    'worker_hired',
  };
  static const _allowedParameters = {
    'status',
    'fb_content_type',
    'fb_content_id',
    'fb_currency',
    'fb_num_items',
    'fb_order_id',
    'fb_registration_method',
  };

  Future<void> _safe(Future<void> Function() action) async {
    if (!_supported) return;
    try {
      await action();
    } catch (_) {
      // Do not print SDK payloads, credentials or user data.
      if (kDebugMode) debugPrint('[Meta] Event could not be queued.');
    }
  }

  Future<void> initialize() => _safe(() async {
    // Native SDK handles installs and foreground activation automatically.
    // Do not manually activate as well, which would count launches twice.
    await _sdk.setAdvertiserIdCollectionEnabled(false);
  });

  Future<void> event(
    String name, {
    Map<String, dynamic> parameters = const {},
  }) async {
    if (!_allowedEvents.contains(name)) return;
    await _safe(
      () => _sdk.logEvent(
        name: name,
        parameters: {
          for (final entry in parameters.entries)
            if (_allowedParameters.contains(entry.key) &&
                (entry.value is String ||
                    entry.value is num ||
                    entry.value is bool))
              entry.key: entry.value,
        },
      ),
    );
  }

  Future<void> registrationCompleted() => event(
    FacebookAppEvents.eventNameCompletedRegistration,
    parameters: {'fb_registration_method': 'phone_otp'},
  );
  Future<void> viewContent(String type, String id) => event(
    FacebookAppEvents.eventNameViewedContent,
    parameters: {'fb_content_type': type, 'fb_content_id': id},
  );

  /// Record server-priced checkout context for verified callbacks, including
  /// callbacks recovered by Razorpay after the app has restarted.
  Future<void> rememberCheckout({
    required String checkoutId,
    required String kind,
    required String contentId,
    double? amount,
    String currency = 'INR',
  }) async {
    if (!_supported) return;
    final context = <String, dynamic>{
      'kind': kind,
      'content_id': contentId,
      'currency': currency,
      if (amount != null && amount.isFinite && amount >= 0) 'amount': amount,
    };
    _checkouts[checkoutId] = context;
    await _safe(() async {
      final prefs = await SharedPreferences.getInstance();
      final stored = _readCheckouts(prefs);
      stored[checkoutId] = context;
      while (stored.length > 10) {
        stored.remove(stored.keys.first);
      }
      await prefs.setString(_checkoutKey, jsonEncode(stored));
    });
  }

  Map<String, dynamic> _readCheckouts(SharedPreferences prefs) {
    final raw = prefs.getString(_checkoutKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<void> checkoutStarted(String checkoutId) => _safe(() async {
    final context = _checkouts[checkoutId];
    if (context == null) return;
    await _sdk.logInitiatedCheckout(
      totalPrice: (context['amount'] as num?)?.toDouble(),
      currency: context['currency'] as String,
      contentType: context['kind'] as String,
      contentId: context['content_id'] as String,
      numItems: 1,
    );
  });

  /// Call only after our backend verifies the Razorpay signature successfully.
  /// Serialize and persist deduplication so repeated callbacks do not inflate ROAS.
  Future<void> verifiedPayment(String paymentId, String checkoutId) {
    final next = _purchaseQueue.then(
      (_) => _safe(() async {
        if (paymentId.isEmpty || _reportedPayments.contains(paymentId)) return;
        final prefs = await SharedPreferences.getInstance();
        final reported = prefs.getStringList(_paymentsKey) ?? [];
        if (reported.contains(paymentId)) return;
        final stored = _readCheckouts(prefs);
        final raw = _checkouts[checkoutId] ?? stored[checkoutId];
        if (raw is! Map) return; // Never invent an unknown payment value.
        final context = Map<String, dynamic>.from(raw);
        final amount = (context['amount'] as num?)?.toDouble();
        final parameters = <String, dynamic>{
          'fb_content_type': context['kind'],
          'fb_content_id': context['content_id'],
          'fb_order_id': paymentId,
        };
        if (amount != null && amount.isFinite && amount >= 0) {
          await _sdk.logPurchase(
            amount: amount,
            currency: context['currency'] as String,
            parameters: parameters,
          );
        } else {
          // Legacy top-up responses don't specify whether amount is in paise.
          // Track completion without guessing revenue.
          await _sdk.logEvent(
            name: context['kind'] == 'credit_pack'
                ? 'credit_topup_completed'
                : 'subscription_payment_completed',
            parameters: parameters,
          );
        }
        _reportedPayments.add(paymentId);
        reported.add(paymentId);
        await prefs.setStringList(
          _paymentsKey,
          reported.length > 100
              ? reported.sublist(reported.length - 100)
              : reported,
        );
        if (context['kind'] == 'subscription') {
          // Purchase owns revenue; Subscribe identifies the conversion only.
          await _sdk.logSubscribe(orderId: paymentId, parameters: parameters);
        }
        stored.remove(checkoutId);
        _checkouts.remove(checkoutId);
        await prefs.setString(_checkoutKey, jsonEncode(stored));
      }),
    );
    _purchaseQueue = next;
    return next;
  }
}
