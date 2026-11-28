import 'dart:async';

import '../../core/api/api_exception.dart';

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
import 'package:employer_kariger_app/core/dialog_controllers.dart';
import '../../core/billing/billing.dart';

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
  Map<String, dynamic> _credits = const {};
  Map<String, dynamic> _totals = const {};
  List<Map<String, dynamic>> _packs = const [];
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

  /// Balance, totals and packs. The credit history lives on its own page,
  /// Settings → AI credit history ([AiCreditHistoryScreen]).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await AppScope.of(context).api.aiCredits();
      if (!mounted) return;
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
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _email() async {
    final catalogEmail = (_billingEmail ?? '').trim();
    if (_isValidInvoiceEmail(catalogEmail)) return catalogEmail;
    final savedEmail =
        AppScope.of(context).profile.profile?.email?.trim() ?? '';
    if (_isValidInvoiceEmail(savedEmail)) {
      _billingEmail = savedEmail;
      return savedEmail;
    }
    // The AI catalog does not always carry billing_email. Reuse the employer's
    // saved email before interrupting a purchase with a manual prompt.
    try {
      final api = AppScope.of(context).api;
      final profile = await api.profile();
      if (!mounted) return null;
      final profileEmail = (profile.email ?? '').trim();
      if (_isValidInvoiceEmail(profileEmail)) {
        _billingEmail = profileEmail;
        return profileEmail;
      }
    } catch (_) {
      // Fall through to the invoice email prompt.
    }
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
              if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                Navigator.pop(context, email);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    disposeAfterClose([controller]);
    return value;
  }

  bool _isValidInvoiceEmail(String email) =>
      email.isNotEmpty &&
      !email.endsWith('@phone.karigar') &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

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
          order['amount_paise'] == null) {
        throw const FormatException(
          'Payment details are missing. Please try again.',
        );
      }
      _pendingOrder = orderId;
      checkout.open({
        'key': order['razorpay_key'],
        'order_id': orderId,
        'amount': order['amount_paise'],
        'currency': 'INR',
        'name': 'Super Karigar',
        'description': '${pack['name'] ?? 'AI call credits'}',
        'theme': {'color': '#BF3A16'},
        'prefill': {'email': email},
      });
    } catch (e) {
      _pendingOrder = null;
      if (mounted) _snack(errorText(e));
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
          _pendingOrder == null) {
        throw const FormatException(
          'Payment verification details are incomplete. Refresh to check your credits.',
        );
      }
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
      if (mounted) _snack(errorText(e));
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
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
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
                if (_credits['enabled'] != false) ...[
                  _CreditTotals(totals: _totals),
                  const SizedBox(height: 20),
                ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: entries
              .map(
                (entry) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: entry == entries.last ? 0 : 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          entry.$3,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
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
        ),
        if ((totals['recharged_amount'] as num? ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${money(totals['recharged_amount'])} paid for recharges',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

String _creditHistoryEmptyText(String filter) => switch (filter) {
  'added' => 'No credits added yet',
  'spent' => 'No AI calls charged yet',
  _ => 'No credit activity yet',
};

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
                    color: context.brandTint,
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
                    // The credits above already include the bonus; "+ 14 bonus"
                    // read as 14 more than that.
                    '${bonus > 0 ? 'incl. $bonus bonus · ' : ''}about ${pack['minutes'] ?? 0} min',
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
              '${money(pack['price'])} + ${money(pack['gst_amount'])} GST = ${money(pack['price_with_gst'])}',
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
    final icon = switch ('${row['type']}') {
      'call' => LucideIcons.phoneCall,
      'recharge' => LucideIcons.creditCard,
      'bonus' || 'welcome' => LucideIcons.gift,
      'refund' => LucideIcons.rotateCcw,
      'admin_credit' || 'admin_debit' => LucideIcons.shieldCheck,
      _ => LucideIcons.receiptText,
    };
    final invoiceNumber = invoice is Map ? '${invoice['number'] ?? ''}' : '';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: added ? colors.tertiaryContainer : colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: added ? colors.tertiary : colors.error,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${row['type_label'] ?? row['type'] ?? 'Credit activity'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${added ? '+' : '−'}${amount.abs()}',
                        style: TextStyle(
                          color: added ? colors.tertiary : colors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if ('${row['description'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${row['description']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (paid is num || invoiceNumber.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      children: [
                        if (paid is num)
                          Text(
                            'Paid ${money(paid)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        if (invoiceNumber.isNotEmpty)
                          InkWell(
                            onTap: () {
                              final id = (invoice['id'] as num?)?.toInt();
                              if (id != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InvoiceScreen(invoiceId: id),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Invoice $invoiceNumber',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${row['created_label'] ?? ''}   Balance ${row['balance_after'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
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

/// Settings → AI credit history: every credit added and spent, on a page of
/// its own (it used to sit at the bottom of the Plans page).
class AiCreditHistoryScreen extends StatelessWidget {
  const AiCreditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI credit history')),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: AiCreditHistory(),
      ),
    ),
  );
}

/// The credit ledger: All / Added / Spent, with paging, on
/// [AiCreditHistoryScreen]. (The recharge page lists the ledger with its own
/// code.)
class AiCreditHistory extends StatefulWidget {
  const AiCreditHistory({super.key, this.initialCredits});
  final Map<String, dynamic>? initialCredits;

  @override
  State<AiCreditHistory> createState() => _AiCreditHistoryState();
}

class _AiCreditHistoryState extends State<AiCreditHistory> {
  String _filter = 'all';
  Map<String, dynamic> _credits = const {};
  Map<String, dynamic> _totals = const {};
  Map<String, dynamic> _meta = const {};
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  bool _loadingMore = false;
  ScrollPosition? _scrollPosition;

  bool _requested = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _credits = widget.initialCredits ?? const {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first load needs AppScope, which initState may not read: started
    // there, it threw, the catch hid it and the history stayed empty.
    if (!_requested) {
      _requested = true;
      _refresh();
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _scrollPosition) return;
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = position;
    _scrollPosition?.addListener(_onScroll);
  }

  void _onScroll() {
    final position = _scrollPosition;
    if (position != null && position.maxScrollExtent - position.pixels < 240) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AppScope.of(context).api.aiCredits(),
        AppScope.of(context).api.aiCreditsLedger(filter: _filter),
      ]);
      if (!mounted) return;
      final catalog = results[0];
      final history = results[1];
      final data = history['data'];
      setState(() {
        _credits = catalog['credits'] is Map
            ? Map<String, dynamic>.from(catalog['credits'])
            : _credits;
        _totals = catalog['totals'] is Map
            ? Map<String, dynamic>.from(catalog['totals'])
            : _totals;
        _rows = _maps(data);
        _meta = history['meta'] is Map
            ? Map<String, dynamic>.from(history['meta'])
            : const {};
      });
    } catch (exception) {
      // The rest of the Plans page still works; say why the history is empty.
      if (mounted) setState(() => _error = errorText(exception));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final current = (_meta['current_page'] as num?)?.toInt() ?? 1;
    final last = (_meta['last_page'] as num?)?.toInt() ?? 1;
    if (_loadingMore || current >= last) return;
    setState(() => _loadingMore = true);
    try {
      final history = await AppScope.of(
        context,
      ).api.aiCreditsLedger(filter: _filter, page: current + 1);
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ..._maps(history['data'])];
        _meta = history['meta'] is Map
            ? Map<String, dynamic>.from(history['meta'])
            : _meta;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_credits['enabled'] == false) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        if (_totals.isNotEmpty) ...[
          _CreditTotals(totals: _totals),
          const SizedBox(height: 22),
        ],
        const Text(
          'Credit history',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
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
                      setState(() => _filter = tab.key);
                      _refresh();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          )
        else if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              _creditHistoryEmptyText(_filter),
              style: const TextStyle(color: AppColors.muted),
            ),
          )
        else ...[
          ..._rows.map(_LedgerRow.new),
          if ((_meta['current_page'] as num? ?? 1) <
              (_meta['last_page'] as num? ?? 1))
            Center(
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Loading…' : 'Load more history'),
              ),
            ),
        ],
      ],
    );
  }
}
