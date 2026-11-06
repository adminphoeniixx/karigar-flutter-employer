import 'package:flutter/material.dart';

/// A compact, reusable picker for long reference lists such as states/cities.
Future<String?> showSearchableOptionSheet(
  BuildContext context, {
  required String title,
  required List<String> values,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _SearchableOptionSheet(title: title, values: values),
);

class _SearchableOptionSheet extends StatefulWidget {
  const _SearchableOptionSheet({required this.title, required this.values});
  final String title;
  final List<String> values;

  @override
  State<_SearchableOptionSheet> createState() => _SearchableOptionSheetState();
}

class _SearchableOptionSheetState extends State<_SearchableOptionSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final visible =
        widget.values
            .toSet()
            .where((value) => value.toLowerCase().contains(normalized))
            .toList()
          ..sort();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No matching options'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(visible[index]),
                        onTap: () => Navigator.pop(context, visible[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
