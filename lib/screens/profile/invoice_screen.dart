import 'package:flutter/material.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key, required this.subscriptionId});
  final int subscriptionId;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> invoice = const {};
  Map<String, dynamic> seller = const {};
  Map<String, dynamic> buyer = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && invoice.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    try {
      final response = await AppScope.of(
        context,
      ).api.invoice(widget.subscriptionId);
      if (!mounted) return;
      setState(() {
        invoice = _map(response['invoice']);
        seller = _map(response['seller']);
        buyer = _map(response['buyer']);
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final plan = _map(invoice['plan']);
    final period = _map(invoice['period']);
    return Scaffold(
      appBar: AppBar(title: const Text('Tax invoice')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: OutlinedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${invoice['number'] ?? 'Invoice'}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${invoice['date'] ?? ''}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                _Party(title: 'Seller', values: seller),
                const SizedBox(height: 12),
                _Party(title: 'Billed to', values: buyer),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _line('Plan', '${plan['name'] ?? ''}'),
                        _line(
                          'Period',
                          '${period['from'] ?? ''} – ${period['to'] ?? ''}',
                        ),
                        _line('Subtotal', '₹${invoice['subtotal'] ?? 0}'),
                        if (invoice['discount'] != null)
                          _line('Discount', '-₹${invoice['discount']}'),
                        _line(
                          'GST (${invoice['gst_percent'] ?? 0}%)',
                          '₹${invoice['gst_amount'] ?? 0}',
                        ),
                        const Divider(),
                        _line(
                          'Total',
                          '₹${invoice['total'] ?? 0}',
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _line(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _Party extends StatelessWidget {
  const _Party({required this.title, required this.values});
  final String title;
  final Map<String, dynamic> values;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      Text(
        '${values['name'] ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if ('${values['address'] ?? ''}'.isNotEmpty) Text('${values['address']}'),
      if ('${values['gstin'] ?? ''}'.isNotEmpty)
        Text('GSTIN: ${values['gstin']}'),
      if ('${values['email'] ?? ''}'.isNotEmpty) Text('${values['email']}'),
      if ('${values['phone'] ?? ''}'.isNotEmpty) Text('${values['phone']}'),
    ],
  );
}
