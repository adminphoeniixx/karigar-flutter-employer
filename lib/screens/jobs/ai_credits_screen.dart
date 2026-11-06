import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../widgets/localized_text.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/jobs/applicant_features_screen.dart';
import 'package:employer_kariger_app/screens/jobs/ai_credits_success_screen.dart';
import 'package:employer_kariger_app/screens/profile/invoice_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class AiCreditsScreen extends StatefulWidget {
  const AiCreditsScreen({super.key});
  @override
  State<AiCreditsScreen> createState() => _AiCreditsScreenState();
}

class _AiCreditsScreenState extends State<AiCreditsScreen> {
  Razorpay? _razorpay;
  bool _loading = true, _verifying = false;
  String? _buyingPackKey;
  String? _error, _pendingOrder;
  String _filter = 'all';
  Map<String, dynamic> _credits = const {};
  Map<String, dynamic> _totals = const {}, _ledgerMeta = const {};
  List<Map<String, dynamic>> _packs = const [], _ledger = const [];
  int _ledgerPage = 1;
  bool _loadingMore = false;
  List<String> _rules = const [];
  String? _billingEmail;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
  }

  Future<void> _initRazorpay() async {
    try {
      final recovered = await const MethodChannel(
        'razorpay_flutter',
      ).invokeMapMethod<String, dynamic>('resync');
      if (!mounted) return;
      _razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _success)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _failure);
      if (recovered?['type'] == 0 && recovered?['data'] is Map) {
        await _success(
          PaymentSuccessResponse.fromMap(
            Map<String, dynamic>.from(recovered!['data'] as Map),
          ),
        );
      }
    } catch (_) {
      /* The screen remains usable after a full native restart. */
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  List<Map<String, dynamic>> _maps(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AppScope.of(context).api.aiCredits(),
        AppScope.of(
          context,
        ).api.aiCreditsLedger(filter: _filter, page: _ledgerPage),
      ]);
      if (!mounted) return;
      final catalog = results[0];
      final history = results[1];
      setState(() {
        _credits = catalog['credits'] is Map
            ? Map<String, dynamic>.from(catalog['credits'] as Map)
            : const {};
        _totals = catalog['totals'] is Map
            ? Map<String, dynamic>.from(catalog['totals'] as Map)
            : const {};
        _packs = _maps(catalog['packs']);
        _rules = (catalog['rules'] as List? ?? const [])
            .map((rule) => '$rule')
            .where((rule) => rule.isNotEmpty)
            .toList();
        _billingEmail = catalog['billing_email']?.toString();
        final rows = history['data'] ?? history['ledger'];
        _ledger = _maps(rows is Map ? rows['data'] : rows);
        _ledgerMeta = history['meta'] is Map
            ? Map<String, dynamic>.from(history['meta'] as Map)
            : rows is Map && rows['meta'] is Map
            ? Map<String, dynamic>.from(rows['meta'] as Map)
            : const {};
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final current = (_ledgerMeta['current_page'] as num?)?.toInt() ?? 1;
    final last = (_ledgerMeta['last_page'] as num?)?.toInt() ?? 1;
    if (_loadingMore || current >= last) return;
    setState(() => _loadingMore = true);
    try {
      final history = await AppScope.of(
        context,
      ).api.aiCreditsLedger(filter: _filter, page: current + 1);
      if (!mounted) return;
      final rows = history['data'] ?? history['ledger'];
      setState(() {
        _ledger.addAll(_maps(rows is Map ? rows['data'] : rows));
        _ledgerMeta = history['meta'] is Map
            ? Map<String, dynamic>.from(history['meta'] as Map)
            : rows is Map && rows['meta'] is Map
            ? Map<String, dynamic>.from(rows['meta'] as Map)
            : _ledgerMeta;
      });
    } catch (error) {
      _snack('$error');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<String?> _email() async {
    if ((_billingEmail ?? '').trim().isNotEmpty) return _billingEmail;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email for your GST invoice'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'accounts@company.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = controller.text.trim();
              if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))
                Navigator.pop(context, email);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _buy(Map<String, dynamic> pack) async {
    final id = (pack['id'] as num?)?.toInt();
    final packKey = '${pack['id'] ?? pack['slug'] ?? pack['name'] ?? ''}';
    if (id == null || packKey.isEmpty || _buyingPackKey != null) return;
    final checkout = _razorpay;
    if (checkout == null) {
      _snack(
        'Payment service is initializing. Please restart the app and try again.',
      );
      return;
    }
    final email = await _email();
    if (!mounted || email == null) return;
    try {
      setState(() => _buyingPackKey = packKey);
      final order = await AppScope.of(
        context,
      ).api.aiCreditsCheckout(id, email: email);
      final orderId = order['razorpay_order_id']?.toString();
      if (orderId == null ||
          order['razorpay_key'] == null ||
          order['amount_paise'] == null)
        throw const FormatException(
          'Payment details are missing. Please try again.',
        );
      _pendingOrder = orderId;
      checkout.open({
        'key': order['razorpay_key'],
        'order_id': orderId,
        'amount': order['amount_paise'],
        'currency': 'INR',
        'name': 'Karigar',
        'description': '${pack['name'] ?? 'AI call credits'}',
        'theme': {'color': '#F97316'},
        'prefill': {'email': email},
      });
    } catch (e) {
      _pendingOrder = null;
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _buyingPackKey = null);
    }
  }

  Future<void> _success(PaymentSuccessResponse payment) async {
    if (_verifying || !mounted) return;
    _verifying = true;
    _pendingOrder ??= payment.data?['razorpay_order_id']?.toString();
    try {
      if (payment.paymentId == null ||
          payment.signature == null ||
          _pendingOrder == null)
        throw const FormatException(
          'Payment verification details are incomplete. Refresh to check your credits.',
        );
      final result = await AppScope.of(context).api.aiCreditsCallback({
        'razorpay_payment_id': payment.paymentId,
        'razorpay_order_id': _pendingOrder,
        'razorpay_signature': payment.signature,
      });
      if (mounted) {
        final returnedCredits = result['credits'] is Map
            ? Map<String, dynamic>.from(result['credits'] as Map)
            : _credits;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AiCreditsSuccessScreen(
              message: '${result['message'] ?? 'AI call credits added.'}',
              credits: returnedCredits,
            ),
          ),
        );
        if (mounted) await _load();
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      _verifying = false;
      _pendingOrder = null;
    }
  }

  void _failure(PaymentFailureResponse _) {
    _pendingOrder = null;
    _snack('Payment cancelled or could not be completed.');
  }

  void _snack(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Credits')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _BalanceCard(credits: _credits),
                const SizedBox(height: 12),
                _CreditTotals(totals: _totals),
                const SizedBox(height: 20),
                const SectionTitle('Recharge packs'),
                ..._packs.map(
                  (pack) => _PackCard(
                    pack: pack,
                    buying:
                        _buyingPackKey ==
                        '${pack['id'] ?? pack['slug'] ?? pack['name'] ?? ''}',
                    onBuy: () => _buy(pack),
                  ),
                ),
                if (_rules.isNotEmpty) ...[
                  const SectionTitle('How credits work'),
                ],
                if (_rules.isNotEmpty)
                  ..._rules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '• $rule',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                const SectionTitle('Credit history'),
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 10),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      for (final tab in const {
                        'all': 'All',
                        'added': 'Added',
                        'spent': 'Spent',
                      }.entries)
                        Expanded(
                          child: _CreditHistoryTab(
                            label: tab.value,
                            selected: _filter == tab.key,
                            onTap: () {
                              setState(() {
                                _filter = tab.key;
                                _ledgerPage = 1;
                              });
                              _load();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (_ledger.isEmpty)
                  const Text(
                    'No credit activity yet.',
                    style: TextStyle(color: AppColors.muted),
                  )
                else
                  ..._ledger.map(_LedgerRow.new),
                if ((_ledgerMeta['current_page'] as num? ?? 1) <
                    (_ledgerMeta['last_page'] as num? ?? 1))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: _loadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Load more history'),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _CreditHistoryTab extends StatelessWidget {
  const _CreditHistoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _CreditTotals extends StatelessWidget {
  const _CreditTotals({required this.totals});
  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = [
      ('Added', '+${totals['added'] ?? 0}', LucideIcons.plus),
      ('Spent', '${totals['spent'] ?? 0}', LucideIcons.minus),
      ('Calls', '${totals['calls'] ?? 0}', LucideIcons.phoneCall),
    ];
    return Row(
      children: entries
          .map(
            (entry) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: entry == entries.last ? 0 : 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(entry.$3, size: 16, color: colors.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      entry.$2,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      entry.$1,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.credits});
  final Map<String, dynamic> credits;
  @override
  Widget build(BuildContext context) {
    final free = credits['enabled'] == false;
    final balance = credits['balance'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0x20FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    LucideIcons.botMessageSquare,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI CALL CREDITS',
                    style: TextStyle(
                      color: Color(0xFFFBECE5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (!free)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x18FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PREPAID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              free ? 'AI calls are free right now' : '$balance credits',
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (!free)
              Text(
                'about ${credits['minutes'] ?? 0} min of calling',
                style: const TextStyle(color: Color(0xFFFBECE5)),
              ),
            if (!free && (credits['held'] as num? ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${credits['held']} held by calls on the line right now',
                  style: const TextStyle(
                    color: Color(0xFFFBECE5),
                    fontSize: 12,
                  ),
                ),
              ),
            if (!free && credits['low'] == true)
              Container(
                margin: const EdgeInsets.only(top: 13),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 16,
                      color: Color(0xFF573B00),
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Your credit balance is running low.',
                        style: TextStyle(
                          color: Color(0xFF573B00),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.buying,
    required this.onBuy,
  });
  final Map<String, dynamic> pack;
  final bool buying;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) {
    final bonus = (pack['bonus_credits'] as num?)?.toInt() ?? 0;
    final canBuy = pack['can_buy'] != false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: pack['popular'] == true ? AppColors.primary : AppColors.line,
          width: pack['popular'] == true ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${pack['name'] ?? 'Credit pack'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (pack['popular'] == true) const BrandChip('Most popular'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand50,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${pack['total_credits'] ?? 0} credits',
                    style: const TextStyle(
                      color: AppColors.brandDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${bonus > 0 ? '+ $bonus bonus · ' : ''}about ${pack['minutes'] ?? 0} min',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '₹${pack['price'] ?? 0} + ₹${pack['gst_amount'] ?? 0} GST = ₹${pack['price_with_gst'] ?? 0}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canBuy && !buying ? onBuy : null,
                icon: buying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.plus, size: 17),
                label: Text(
                  canBuy
                      ? 'Buy credits'
                      : 'Only the account owner can recharge',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow(this.row);
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final amount = (row['credits'] as num?)?.toInt() ?? 0;
    final invoice = row['invoice'];
    final callId = (row['screening_call_id'] as num?)?.toInt();
    final added =
        row['direction'] == 'credit' ||
        (row['direction'] == null && amount >= 0);
    final paid = row['amount_paid'];
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: added ? colors.tertiaryContainer : colors.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            added ? LucideIcons.plus : LucideIcons.phoneCall,
            size: 18,
            color: added ? colors.onTertiaryContainer : colors.onErrorContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${row['description'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            BrandChip(
              '${row['type_label'] ?? row['type'] ?? ''}',
              neutral: true,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${row['created_label'] ?? ''}\nBalance ${row['balance_after'] ?? ''}${paid is num ? ' · Paid ₹${paid.toStringAsFixed(2)}' : ''}',
          ),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${added ? '+' : '−'}${amount.abs()}',
              style: TextStyle(
                color: added ? colors.tertiary : colors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (invoice is Map)
              TextButton(
                onPressed: () {
                  final id = (invoice['id'] as num?)?.toInt();
                  if (id != null)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceScreen(invoiceId: id),
                      ),
                    );
                },
                child: const Text('Invoice'),
              ),
          ],
        ),
        onTap: callId == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreeningConversationScreen(
                    callId: callId,
                    workerName: 'Karigar',
                  ),
                ),
              ),
      ),
    );
  }
}
