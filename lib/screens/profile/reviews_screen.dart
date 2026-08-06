import 'package:flutter/material.dart';
import 'package:employer_kariger_app/core/theme.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reviews')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Text(
                  '4.6',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '★★★★★',
                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 20),
                    ),
                    Text(
                      'Based on 18 worker reviews',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14),
        _Review(
          'Ramesh Kumar',
          'Clear work details and payment was on time. Great employer.',
          '2 days ago',
          5,
        ),
        SizedBox(height: 12),
        _Review(
          'Suresh Yadav',
          'Professional team and safe working environment.',
          '1 week ago',
          5,
        ),
        SizedBox(height: 12),
        _Review(
          'Imran Khan',
          'Good project. Timings could be communicated earlier.',
          '2 weeks ago',
          4,
        ),
      ],
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
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
