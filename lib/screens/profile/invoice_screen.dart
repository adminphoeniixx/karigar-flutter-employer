import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../core/billing/billing.dart';
import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';

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
  bool downloading = false;
  String? pdfUrl;
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(
        context,
      ).api.invoice(widget.subscriptionId);
      if (!mounted) return;
      setState(() {
        pdfUrl = response['pdf_url']?.toString();
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

  Future<void> _download() async {
    if (downloading) return;
    setState(() => downloading = true);
    try {
      final file = await AppScope.of(
        context,
      ).api.invoicePdf(widget.subscriptionId, url: pdfUrl);
      if (!mounted) return;
      if (file.bytes.length < 5 ||
          String.fromCharCodes(file.bytes.take(5)) != '%PDF-') {
        throw const FormatException(
          'The server did not return a PDF. Please try again.',
        );
      }
      final name = (file.filename ?? 'Invoice-${widget.subscriptionId}.pdf')
          .split(RegExp(r'[/\\]'))
          .last;
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save invoice PDF',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: Uint8List.fromList(file.bytes),
      );
      if (path == null) return;
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(file.bytes, flush: true);
      }

      if (mounted) {
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
      if (mounted) setState(() => downloading = false);
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
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: downloading ? null : _download,
                  icon: const Icon(Icons.download),
                  label: Text(downloading ? 'Downloading...' : 'Download PDF'),
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
                        ...taxLines(
                          invoice,
                          invoice: true,
                        ).map((line) => _line(line.label, money(line.amount))),
                        _line(
                          'Place of supply',
                          '${invoice['place_of_supply'] ?? 'Not available'}',
                        ),
                        _line(
                          'SAC',
                          '${invoice['sac'] ?? seller['sac'] ?? 'Not available'}',
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
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
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
