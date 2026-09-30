import 'dart:async';
import '../../core/api/api_exception.dart';
import 'package:employer_kariger_app/core/analytics/meta_analytics.dart';
import '../../core/billing/billing.dart';
import '../../models/api_models.dart';
import 'profile_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/profile/invoice_screen.dart';

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
  List<Map<String, dynamic>> invoices = const [];
  Json payment = {};
  Json? jobPosts;
  bool checkingOut = false;
  bool verifyingPayment = false;
  String? pendingSubscriptionId;
  String? pendingOrderId;

  @override
  void initState() {
    super.initState();
    unawaited(
      MetaAnalytics.instance.viewContent('plan_catalog', 'employer_plans'),
    );
    _initializeRazorpay();
  }

  Future<void> _initializeRazorpay() async {
    try {
      final recovered = await const MethodChannel(
        'razorpay_flutter',
      ).invokeMapMethod<String, dynamic>('resync');
      if (!mounted) return;
      razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _paymentSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _paymentError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _externalWallet);
      final recoveredData = recovered?['data'];
      if (recovered?['type'] == 0 && recoveredData is Map) {
        await _paymentSuccess(PaymentSuccessResponse.fromMap(recoveredData));
      }
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
        payment = response['payment'] is Map
            ? Json.from(response['payment'])
            : {};
        jobPosts = response['job_posts'] is Map
            ? Json.from(response['job_posts'])
            : null;
        plans = _maps(response['plans']);
        packs = _maps(response['credit_packs']);
        invoices = _maps(response['invoices']);
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
    if (checkingOut ||
        pendingSubscriptionId != null ||
        pendingOrderId != null) {
      return;
    }
    final checkout = razorpay;
    if (checkout == null) {
      _checkoutUnavailable();
      return;
    }
    try {
      setState(() => checkingOut = true);
      final response = await AppScope.of(
        context,
      ).api.subscribe((plan['id'] as num).toInt());
      if (!mounted) return;
      if (!await _confirmCheckout(response) || !mounted) {
        return;
      }
      final subscriptionId =
          response['razorpay_subscription_id'] ?? response['subscription_id'];
      if (subscriptionId is! String ||
          !subscriptionId.startsWith('sub_') ||
          response['razorpay_key'] == null) {
        throw const FormatException(
          'Payment details are missing. Please try again.',
        );
      }
      pendingOrderId = null;
      pendingSubscriptionId = subscriptionId;
      unawaited(
        AppScope.of(context).api.analytics.checkoutStarted(subscriptionId),
      );
      checkout.open({
        'key': response['razorpay_key'],
        'subscription_id': pendingSubscriptionId,
        'name': 'Karigar',
        'description': '${plan['name'] ?? 'Employer plan'} subscription',
        'theme': {'color': '#F97316'},
      });
    } catch (exception) {
      pendingSubscriptionId = null;
      pendingOrderId = null;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  Future<bool> _confirmCheckout(Json response) async {
    final raw = response['amounts'];
    if (raw is! Map || raw['total'] == null) {
      throw const FormatException(
        'Checkout amount is unavailable. Please try again.',
      );
    }
    final amounts = Json.from(raw);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm payment'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (asDouble(amounts['discount']) > 0)
                    Text('Discount: −${money(amounts['discount'])}'),
                  Text('Taxable subtotal: ${money(amounts['subtotal'])}'),
                  ...taxLines(
                    amounts,
                  ).map((line) => Text('${line.label}: ${money(line.amount)}')),
                  if (amounts['place_of_supply'] != null)
                    Text('Place of supply: ${amounts['place_of_supply']}'),
                  const Divider(),
                  Text(
                    'Total payable: ${money(amounts['total'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue to payment'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _usageLabel(BuildContext context) {
    final usage = jobPosts!;
    final reset = DateTime.tryParse('${usage['resets_at'] ?? ''}');
    return '${usage['used'] ?? 0} of ${usage['limit'] ?? 0} job posts used this month'
        '${reset == null ? '' : ' · resets ${MaterialLocalizations.of(context).formatShortDate(reset.toLocal())}'}';
  }

  Future<void> _topUp(Map<String, dynamic> pack) async {
    if (checkingOut ||
        pendingSubscriptionId != null ||
        pendingOrderId != null) {
      return;
    }
    final checkout = razorpay;
    if (checkout == null) {
      _checkoutUnavailable();
      return;
    }
    try {
      setState(() => checkingOut = true);
      final response = await AppScope.of(context).api.topUp('${pack['key']}');
      if (!mounted) return;
      pendingSubscriptionId = null;
      pendingOrderId = '${response['razorpay_order_id']}';
      unawaited(
        AppScope.of(context).api.analytics.checkoutStarted(pendingOrderId!),
      );
      checkout.open({
        'key': response['razorpay_key'],
        'order_id': pendingOrderId,
        'name': 'Karigar',
        'description': '${response['credits'] ?? ''} contact credits',
        'theme': {'color': '#F97316'},
      });
    } catch (exception) {
      pendingSubscriptionId = null;
      pendingOrderId = null;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) setState(() => checkingOut = false);
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
    if (!mounted || verifyingPayment) return;
    verifyingPayment = true;
    pendingSubscriptionId ??= response.data?['razorpay_subscription_id']
        ?.toString();
    if (pendingSubscriptionId == null) pendingOrderId ??= response.orderId;
    try {
      if (response.paymentId == null ||
          response.signature == null ||
          (pendingSubscriptionId == null && pendingOrderId == null)) {
        throw const FormatException(
          'Payment details are incomplete. Refresh plans to check payment status.',
        );
      }
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
      verifyingPayment = false;
      pendingSubscriptionId = null;
      pendingOrderId = null;
    }
  }

  void _paymentError(PaymentFailureResponse response) {
    pendingSubscriptionId = null;
    pendingOrderId = null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readableMessage(
              response.message,
              fallback: 'Payment was not completed. Please try again.',
            ),
          ),
        ),
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
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.gradientEnd],
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
                              credits['unmetered'] == true
                                  ? 'Unlimited unlocks'
                                  : '${credits['balance'] ?? 0} credits',
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
                if (DateTime.tryParse('${credits['unlocks_reset_at'] ?? ''}')
                    case final DateTime reset)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Contact unlocks renew on ${MaterialLocalizations.of(context).formatMediumDate(reset.toLocal())}',
                    ),
                  ),
                if (jobPosts != null && jobPosts!['unlimited'] != true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_usageLabel(context)),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Billing profile'),
                  subtitle: const Text(
                    'Add GSTIN and state for correct GST, and your email to receive invoices.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen(),
                    ),
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
                      gstPercent: asDouble(payment['gst_percent']),
                      onChoose: plan['purchasable'] == true && !checkingOut
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
                              onPressed:
                                  checkingOut || payment['configured'] != true
                                  ? null
                                  : () => _topUp(pack),
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
                if (invoices.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Invoices',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...invoices.map(
                    (invoice) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.receiptText),
                      title: Text('${invoice['invoice_number'] ?? 'Invoice'}'),
                      subtitle: Text(
                        '${invoice['plan'] ?? ''} · ${invoice['date'] ?? ''}',
                      ),
                      trailing: Text('₹${invoice['total'] ?? 0}'),
                      onTap: () {
                        final id = (invoice['id'] as num?)?.toInt();
                        if (id == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceScreen(subscriptionId: id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
  );
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.plan,
    required this.onChoose,
    required this.gstPercent,
  });
  final double gstPercent;
  final Map<String, dynamic> plan;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final featureLabels = (plan['feature_list'] as List? ?? const [])
        .whereType<String>();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
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
          if (plan['recommended'] == true)
            const Chip(label: Text('Recommended')),
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
              Expanded(
                child: Text(
                  '${plan['name'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
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
          if (gstPercent > 0 &&
              asDouble(plan['price_with_gst']) > asDouble(plan['price']))
            Text(
              '+ ${percent(gstPercent)}% GST · ${money(plan['price_with_gst'])} total',
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
                  Expanded(child: Text(feature)),
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
