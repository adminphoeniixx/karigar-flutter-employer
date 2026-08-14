import 'package:flutter/material.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = const {};
  List<Map<String, dynamic>> items = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && items.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.reviews();
      if (!mounted) return;
      setState(() {
        summary = response['summary'] is Map
            ? Map<String, dynamic>.from(response['summary'])
            : {};
        items = (response['data'] as List? ?? const [])
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
    appBar: AppBar(title: const Text('Reviews')),
    body: loading && items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && items.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Text(
                          '${summary['average'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '★★★★★',
                                style: TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Based on ${summary['count'] ?? 0} worker reviews',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const Center(child: Text('No reviews yet'))
                else
                  ...items.map((item) {
                    final reviewer = item['reviewer'] is Map
                        ? Map<String, dynamic>.from(item['reviewer'])
                        : const <String, dynamic>{};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Review(
                        '${reviewer['name'] ?? 'Worker'}',
                        '${item['comment'] ?? ''}',
                        '${item['created_ago'] ?? ''}',
                        (item['rating'] as num?)?.toInt() ?? 0,
                      ),
                    );
                  }),
              ],
            ),
          ),
  );
}

class _Review extends StatelessWidget {
  const _Review(this.name, this.text, this.date, this.stars);
  final String name, text, date;
  final int stars;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${'★' * stars}${'☆' * (5 - stars)}',
                style: const TextStyle(color: Color(0xFFFBBF24)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 8),
          Text(
            date,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
