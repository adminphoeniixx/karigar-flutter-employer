import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_scope.dart';
import '../../core/billing/billing.dart';
import '../../core/theme.dart';
import '../../widgets/localized_text.dart';
import 'invoice_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> orders = const [];
  final Set<int> downloadingInvoices = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.orders();
      final raw = response['orders'] ?? response['data'];
      if (!mounted) return;
      setState(() {
        orders = (raw as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _download(Map<String, dynamic> payment) async {
    final id = (payment['invoice_id'] as num?)?.toInt();
    if (id == null || downloadingInvoices.contains(id)) return;
    setState(() => downloadingInvoices.add(id));
    try {
      final result = await AppScope.of(
        context,
      ).api.invoicePdf(id, url: payment['pdf_url']?.toString());
      if (result.bytes.length < 5 ||
          String.fromCharCodes(result.bytes.take(5)) != '%PDF-') {
        throw const FormatException('The server did not return a PDF.');
      }
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save invoice PDF',
        fileName: (result.filename ?? 'Invoice-$id.pdf')
            .split(RegExp(r'[/\\]'))
            .last,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: Uint8List.fromList(result.bytes),
      );
      if (path != null && !Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(result.bytes, flush: true);
      }
      if (mounted && path != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invoice saved.')));
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) setState(() => downloadingInvoices.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Order history')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: orders.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 170),
                      Icon(LucideIcons.receiptText, size: 42),
                      SizedBox(height: 12),
                      Center(child: Text('No orders yet')),
                      SizedBox(height: 5),
                      Center(
                        child: Text(
                          'Your plan checkouts and invoices will appear here.',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _OrderCard(
                      order: orders[index],
                      downloadingInvoices: downloadingInvoices,
                      onView: (id) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceScreen(invoiceId: id),
                        ),
                      ),
                      onDownload: _download,
                    ),
                  ),
          ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.downloadingInvoices,
    required this.onView,
    required this.onDownload,
  });

  final Map<String, dynamic> order;
  final Set<int> downloadingInvoices;
  final ValueChanged<int> onView;
  final ValueChanged<Map<String, dynamic>> onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = '${order['payment_status'] ?? ''}';
    final payments = (order['payments'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order['plan'] ?? 'Plan'} · ${order['plan_type'] == 'database' ? 'Database plan' : 'Job plan'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                _StatusBadge(
                  label: '${order['payment_label'] ?? status}',
                  status: status,
                ),
                if (status == 'paid' &&
                    '${order['plan_label'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _StatusBadge(
                    label: '${order['plan_label']}',
                    status: '${order['plan_status'] ?? ''}',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order['order_number'] ?? ''} · ${order['ordered_label'] ?? ''}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if ('${order['period_label'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                '${order['period_label']}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              money(order['amount']),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (status == 'pending')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Waiting for the payment to finish.'),
              ),
            if (status == 'not_completed')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No plan started. If money was deducted, Razorpay refunds it in 5–7 days.',
                ),
              ),
            if (status == 'renewal_failed')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Check your card / UPI mandate, or buy a plan again.',
                ),
              ),
            ...payments.map(
              (payment) => _PaymentRow(
                payment: payment,
                downloading: downloadingInvoices.contains(
                  (payment['invoice_id'] as num?)?.toInt(),
                ),
                onView: onView,
                onDownload: onDownload,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.downloading,
    required this.onView,
    required this.onDownload,
  });
  final Map<String, dynamic> payment;
  final bool downloading;
  final ValueChanged<int> onView;
  final ValueChanged<Map<String, dynamic>> onDownload;

  @override
  Widget build(BuildContext context) {
    final id = (payment['invoice_id'] as num?)?.toInt();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${payment['renewal'] == true ? 'Renewal' : 'First payment'} · ${payment['paid_label'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            '${payment['invoice_number'] ?? 'Invoice'} · ${money(payment['amount'])}',
          ),
          if ('${payment['period_label'] ?? ''}'.isNotEmpty)
            Text(
              '${payment['period_label']}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          if (id != null)
            Row(
              children: [
                TextButton(
                  onPressed: () => onView(id),
                  child: const Text('View'),
                ),
                TextButton.icon(
                  onPressed: downloading ? null : () => onDownload(payment),
                  icon: downloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.download, size: 16),
                  label: const Text('PDF'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.status});
  final String label, status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'paid' || 'active' || 'completed' => AppColors.green,
      'pending' => Colors.orange.shade800,
      _ => Theme.of(context).colorScheme.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
