import 'package:flutter/material.dart' hide Text;

import '../../core/app_scope.dart';
import '../../core/billing/billing.dart';
import '../../widgets/localized_text.dart';
import 'invoice_screen.dart';

/// A profile-facing list of tax invoices, independent of the plan catalogue.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> invoices = const [];

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
      final response = await AppScope.of(context).api.plans();
      if (!mounted) return;
      setState(() {
        invoices = (response['invoices'] as List? ?? const [])
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoices')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: invoices.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 170),
                      Center(child: Text('No invoices yet')),
                      SizedBox(height: 6),
                      Center(
                        child: Text('Tax invoices for paid plans appear here.'),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: invoices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final invoice = invoices[index];
                      final id = (invoice['id'] as num?)?.toInt();
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${invoice['invoice_number'] ?? 'Tax invoice'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              invoice['plan'],
                              invoice['date'],
                            ].where((value) => '$value'.isNotEmpty).join(' · '),
                          ),
                          trailing: Text(
                            money(invoice['total']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: id == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InvoiceScreen(invoiceId: id),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
  );
}
