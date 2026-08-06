import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/theme.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Credits & Plans')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.brandDark],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(
                LucideIcons.walletCards,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '12 credits',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "Free plan · 1 credit unlocks a worker's contact",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Choose a plan',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        const _Plan('Starter', '₹299', '10 credits', [
          'Unlock 10 worker contacts',
          'Credits never expire',
        ]),
        const SizedBox(height: 14),
        const _Plan('Growth', '₹699', '30 credits', [
          'Unlock 30 worker contacts',
          'Boost 2 job posts',
          'Priority support',
        ], featured: true),
        const SizedBox(height: 14),
        const _Plan('Business', '₹1,499', '80 credits', [
          'Unlock 80 worker contacts',
          'Boost 5 job posts',
          'Hiring analytics',
        ]),
      ],
    ),
  );
}

class _Plan extends StatelessWidget {
  const _Plan(
    this.name,
    this.price,
    this.credits,
    this.features, {
    this.featured = false,
  });
  final String name, price, credits;
  final List<String> features;
  final bool featured;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: featured ? AppColors.primary : AppColors.line,
        width: featured ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text(
              'MOST POPULAR',
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
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              price,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Text(credits, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        ...features.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(LucideIcons.check, size: 18, color: AppColors.green),
                const SizedBox(width: 8),
                Text(e),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: () {}, child: Text('Choose $name')),
      ],
    ),
  );
}
