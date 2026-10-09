import 'dart:async';
import 'dart:developer' as developer;
import '../../core/api/api_exception.dart';
import 'package:employer_kariger_app/core/analytics/meta_analytics.dart';
import '../../core/billing/billing.dart';
import '../../models/api_models.dart';
import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/profile/payment_success_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, this.focusDatabase = false});
  final bool focusDatabase;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  Razorpay? razorpay;
  bool loading = true;
  String? error;
  Map<String, dynamic> unlocks = const {};
  List<Map<String, dynamic>> plans = const [];
  Json? database;
  Json payment = {};
  Json? jobPosts;
  String? billingEmail;
  bool checkingOut = false;
  int? checkoutPlanId;
  bool verifyingPayment = false;
  String? pendingSubscriptionId;

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
        unlocks = response['unlocks'] is Map
            ? Map<String, dynamic>.from(response['unlocks'])
            : {};
        database = response['database'] is Map
            ? Json.from(response['database'])
            : null;
        payment = response['payment'] is Map
            ? Json.from(response['payment'])
            : {};
        jobPosts = response['job_posts'] is Map
            ? Json.from(response['job_posts'])
            : null;
        billingEmail = response['billing_email']?.toString();
        plans = _maps(response['plans'])
          ..sort((a, b) {
            if (!widget.focusDatabase) return 0;
            final aDatabase = a['type'] == 'database';
            final bDatabase = b['type'] == 'database';
            return aDatabase == bDatabase ? 0 : (aDatabase ? -1 : 1);
          });
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
    if (checkingOut || pendingSubscriptionId != null) {
      return;
    }
    final planId = (plan['id'] as num?)?.toInt();
    if (planId == null) return;
    final checkout = razorpay;
    if (checkout == null) {
      _checkoutUnavailable();
      return;
    }
    final email = await _invoiceEmail();
    if (!mounted || email == null) return;
    try {
      setState(() {
        checkingOut = true;
        checkoutPlanId = planId;
      });
      final response = await AppScope.of(
        context,
      ).api.subscribe(planId, email: email.isEmpty ? null : email);
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
      pendingSubscriptionId = subscriptionId;
      unawaited(
        AppScope.of(context).api.analytics.checkoutStarted(subscriptionId),
      );
      checkout.open({
        // Razorpay subscription checkout must receive its subscription ID. Do
        // not pass an amount here: the server-created subscription is the
        // source of truth for the recurring amount.
        'key': response['razorpay_key'],
        'subscription_id': pendingSubscriptionId,
        'name': 'Karigar',
        'description': '${plan['name'] ?? 'Employer plan'} subscription',
        'theme': {'color': '#F97316'},
        'retry': {'enabled': true, 'max_count': 3},
        'prefill': {
          if (email.isNotEmpty) 'email': email,
          if (_checkoutPhone.isNotEmpty) 'contact': _checkoutPhone,
        },
      });
    } catch (exception) {
      pendingSubscriptionId = null;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) {
        setState(() {
          checkingOut = false;
          checkoutPlanId = null;
        });
      }
    }
  }

  String get _checkoutPhone {
    final source =
        AppScope.of(context).profile.profile?.phone ??
        AppScope.of(context).auth.user?['phone']?.toString() ??
        '';
    return source.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<String?> _invoiceEmail() async {
    final existing = billingEmail?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Email for your GST invoice'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'accounts@company.com',
            helperText: 'We will email each tax invoice to this address.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid email address.')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
    try {
      if (response.paymentId == null ||
          response.signature == null ||
          pendingSubscriptionId == null) {
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
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaymentSuccessScreen(),
          fullscreenDialog: true,
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      verifyingPayment = false;
      pendingSubscriptionId = null;
    }
  }

  void _paymentError(PaymentFailureResponse response) {
    developer.log(
      'Razorpay payment failed: code=${response.code}, '
      'message=${response.message}, details=${response.error}',
      name: 'SuperKarigar.Payment',
    );
    pendingSubscriptionId = null;
    if (mounted) {
      final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
      final detail =
          response.error?['reason'] ??
          response.error?['description'] ??
          response.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancelled
                ? 'Payment cancelled.'
                : readableMessage(
                    '$detail',
                    fallback:
                        'Payment could not be completed. Please try again.',
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
    appBar: AppBar(title: const Text('Plans & Worker Database')),
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
                  padding: const EdgeInsets.all(16),
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
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              database?['title']?.toString() ??
                                  (unlocks['unmetered'] == true
                                      ? 'Unlimited unlocks'
                                      : '${unlocks['plan_remaining'] ?? 0} unlocks'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              database?['subtitle']?.toString() ??
                                  'Choose a plan to unlock worker contacts',
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
                if (DateTime.tryParse('${unlocks['unlocks_reset_at'] ?? ''}')
                    case final DateTime reset)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Contact unlocks renew on ${MaterialLocalizations.of(context).formatMediumDate(reset.toLocal())}',
                    ),
                  ),
                if (jobPosts != null && jobPosts!['unlimited'] != true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12,bottom: 12),
                    child: Text(_usageLabel(context)),
                  ),
                _ActivePlanBanner(plans: plans),
                const SizedBox(height: 26),
                _PlanSection(
                  title: 'Job plans',
                  subtitle:
                      'Post jobs, see applicants and open the Worker Database.',
                  plans: plans
                      .where((plan) => plan['type'] != 'database')
                      .toList(),
                  gstPercent: asDouble(payment['gst_percent']),
                  checkoutPlanId: checkoutPlanId,
                  onChoose: _subscribe,
                ),
                if (plans.any((plan) => plan['type'] == 'database')) ...[
                  const SizedBox(height: 28),
                  _PlanSection(
                    title: 'Database plans',
                    subtitle:
                        'Get worker contacts on their own or alongside a job plan.',
                    plans: plans
                        .where((plan) => plan['type'] == 'database')
                        .toList(),
                    gstPercent: asDouble(payment['gst_percent']),
                    checkoutPlanId: checkoutPlanId,
                    onChoose: _subscribe,
                  ),
                ],
              ],
            ),
          ),
  );
}

class _ActivePlanBanner extends StatelessWidget {
  const _ActivePlanBanner({required this.plans});
  final List<Map<String, dynamic>> plans;

  @override
  Widget build(BuildContext context) {
    final current = plans
        .where((plan) => plan['is_current'] == true)
        .firstOrNull;
    if (current == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleCheck, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Active plan: ${current['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Active', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.title,
    required this.subtitle,
    required this.plans,
    required this.gstPercent,
    required this.checkoutPlanId,
    required this.onChoose,
  });
  final String title, subtitle;
  final List<Map<String, dynamic>> plans;
  final double gstPercent;
  final int? checkoutPlanId;
  final ValueChanged<Map<String, dynamic>> onChoose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 4
          : constraints.maxWidth >= 680
          ? 2
          : 1;
      final gap = 16.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: plans
                .map(
                  (plan) => SizedBox(
                    width: width,
                    child: _Plan(
                      plan: plan,
                      gstPercent: gstPercent,
                      available: plan['purchasable'] == true,
                      canPurchase: plan['can_purchase'] is bool
                          ? plan['can_purchase'] == true
                          : plan['purchasable'] == true &&
                                plan['is_current'] != true,
                      selected: checkoutPlanId == (plan['id'] as num?)?.toInt(),
                      onChoose:
                          (plan['can_purchase'] is bool
                              ? plan['can_purchase'] == true
                              : plan['purchasable'] == true &&
                                    plan['is_current'] != true)
                          ? () => onChoose(plan)
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );
    },
  );
}

class _Plan extends StatefulWidget {
  const _Plan({
    required this.plan,
    required this.onChoose,
    required this.gstPercent,
    required this.available,
    required this.canPurchase,
    required this.selected,
  });
  final double gstPercent;
  final Map<String, dynamic> plan;
  final VoidCallback? onChoose;
  final bool available, canPurchase, selected;

  @override
  State<_Plan> createState() => _PlanState();
}

class _PlanState extends State<_Plan> {
  bool showAllFeatures = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final plan = widget.plan;
    final featureLabels = (plan['feature_list'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final visibleFeatures = showAllFeatures
        ? featureLabels
        : featureLabels.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan['is_current'] == true
              ? AppColors.primary
              : colors.outlineVariant,
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
          if (plan['recommended'] == true && plan['is_current'] != true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brand50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.brandDark,
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
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '${plan['interval'] ?? ''}',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (widget.gstPercent > 0 &&
              asDouble(plan['price_with_gst']) > asDouble(plan['price']))
            Text(
              '+ ${percent(widget.gstPercent)}% GST · ${money(plan['price_with_gst'])} total',
            ),
          const SizedBox(height: 12),
          ...visibleFeatures.map(
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
          if (featureLabels.length > 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    setState(() => showAllFeatures = !showAllFeatures),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                ),
                child: Text(
                  showAllFeatures
                      ? 'Show fewer features'
                      : '+ ${featureLabels.length - 3} more features',
                ),
              ),
            ),
          const SizedBox(height: 14),
          if (plan['already_purchased'] == true) ...[
            Text(
              '${plan['purchase_note'] ?? 'You already have this plan.'}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.selected || !widget.canPurchase
                  ? null
                  : widget.onChoose,
              child: widget.selected
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      plan['is_current'] == true &&
                              plan['already_purchased'] != true
                          ? 'Current plan'
                          : plan['already_purchased'] == true
                          ? 'Already purchased'
                          : !widget.available
                          ? 'Unavailable'
                          : 'Choose ${plan['name'] ?? ''}',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
