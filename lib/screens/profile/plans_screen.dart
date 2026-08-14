import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  Razorpay? razorpay;
  bool loading = true;
  String? error;
  Map<String, dynamic> credits = const {};
  List<Map<String, dynamic>> plans = const [];
  List<Map<String, dynamic>> packs = const [];
  String? pendingSubscriptionId;
  String? pendingOrderId;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
  }

  Future<void> _initializeRazorpay() async {
    try {
      await const MethodChannel(
        'razorpay_flutter',
      ).invokeMethod<void>('resync');
      if (!mounted) return;
      razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _paymentSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _paymentError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _externalWallet);
    } on MissingPluginException {
      // A full restart registers newly added native plugins.
    } on PlatformException {
      // Checkout will remain disabled until the native SDK is available.
    }
  }

  @override
  void dispose() {
    razorpay?.clear();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && plans.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.plans();
      if (!mounted) return;
      setState(() {
        credits = response['credits'] is Map
            ? Map<String, dynamic>.from(response['credits'])
            : {};
        plans = _maps(response['plans']);
        packs = _maps(response['credit_packs']);
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  Future<void> _subscribe(Map<String, dynamic> plan) async {
    final checkout = razorpay;
    if (checkout == null) {
      _checkoutUnavailable();
      return;
    }
    try {
      final response = await AppScope.of(
        context,
      ).api.subscribe((plan['id'] as num).toInt());
      if (!mounted) return;
      pendingOrderId = null;
      pendingSubscriptionId = '${response['razorpay_subscription_id']}';
      checkout.open({
        'key': response['razorpay_key'],
        'subscription_id': pendingSubscriptionId,
        'name': 'Karigar',
        'description': '${plan['name'] ?? 'Employer plan'} subscription',
        'theme': {'color': '#F97316'},
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  Future<void> _topUp(Map<String, dynamic> pack) async {
    final checkout = razorpay;
    if (checkout == null) {
      _checkoutUnavailable();
      return;
    }
    try {
      final response = await AppScope.of(context).api.topUp('${pack['key']}');
      if (!mounted) return;
      pendingSubscriptionId = null;
      pendingOrderId = '${response['razorpay_order_id']}';
      checkout.open({
        'key': response['razorpay_key'],
        'order_id': pendingOrderId,
        'name': 'Karigar',
        'description': '${response['credits'] ?? ''} contact credits',
        'theme': {'color': '#F97316'},
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  void _checkoutUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payment service is initializing. Fully restart the app and try again.',
        ),
      ),
    );
  }

  Future<void> _paymentSuccess(PaymentSuccessResponse response) async {
    try {
      if (pendingSubscriptionId != null) {
        await AppScope.of(context).api.subscriptionCallback({
          'razorpay_payment_id': response.paymentId,
          'razorpay_subscription_id': pendingSubscriptionId,
          'razorpay_signature': response.signature,
        });
      } else if (pendingOrderId != null) {
        await AppScope.of(context).api.topUpCallback({
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': pendingOrderId,
          'razorpay_signature': response.signature,
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment successful.')));
      await _load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      pendingSubscriptionId = null;
      pendingOrderId = null;
    }
  }

  void _paymentError(PaymentFailureResponse response) {
    pendingSubscriptionId = null;
    pendingOrderId = null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Payment failed.')),
      );
    }
  }

  void _externalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected wallet: ${response.walletName}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Credits & Plans')),
    body: loading && plans.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && plans.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.brandDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.walletCards,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${credits['balance'] ?? 0} credits',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${credits['plan_label'] ?? 'Free plan · unlock worker numbers'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Choose a plan',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ...plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _Plan(
                      plan: plan,
                      onChoose: plan['purchasable'] == true
                          ? () => _subscribe(plan)
                          : null,
                    ),
                  ),
                ),
                if (packs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Credit top-ups',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  ...packs.map(
                    (pack) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${pack['label'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₹${pack['price'] ?? 0}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: () => _topUp(pack),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(64, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: const Text('Buy'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
  );
}

class _Plan extends StatelessWidget {
  const _Plan({required this.plan, required this.onChoose});
  final Map<String, dynamic> plan;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final features = plan['features'] is Map
        ? Map<String, dynamic>.from(plan['features'])
        : const <String, dynamic>{};
    final featureLabels = features.entries
        .where(
          (item) =>
              item.value == true || item.value is num || item.value is String,
        )
        .map((item) => item.key.replaceAll('_', ' '))
        .toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan['is_current'] == true
              ? AppColors.primary
              : AppColors.line,
          width: plan['is_current'] == true ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan['is_current'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'CURRENT PLAN',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${plan['name'] ?? ''}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₹${plan['price'] ?? 0}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '${plan['interval'] ?? ''}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          ...featureLabels.map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.check,
                    size: 18,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(feature),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: plan['is_current'] == true ? null : onChoose,
            child: Text(
              plan['is_current'] == true
                  ? 'Current plan'
                  : onChoose == null
                  ? 'Unavailable'
                  : 'Choose ${plan['name'] ?? ''}',
            ),
          ),
        ],
      ),
    );
  }
}
