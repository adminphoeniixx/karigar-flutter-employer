import 'package:flutter/material.dart';

/// A compact, reusable picker for long reference lists such as states/cities.
Future<String?> showSearchableOptionSheet(
  BuildContext context, {
  required String title,
  required List<String> values,
  bool citySearch = false,
  String? stateName,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _SearchableOptionSheet(
    title: title,
    values: values,
    citySearch: citySearch,
    stateName: stateName,
  ),
);

class _SearchableOptionSheet extends StatefulWidget {
  const _SearchableOptionSheet({
    required this.title,
    required this.values,
    this.citySearch = false,
    this.stateName,
  });
  final String title;
  final List<String> values;
  final bool citySearch;
  final String? stateName;

  @override
  State<_SearchableOptionSheet> createState() => _SearchableOptionSheetState();
}

class _SearchableOptionSheetState extends State<_SearchableOptionSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final matches = widget.values.toSet().where((value) {
      return normalized.isEmpty || value.toLowerCase().contains(normalized);
    }).toList();
    // List.sort is not stable: with an empty search every rank ties and the
    // A–Z list came out shuffled (Haryana above Andhra Pradesh). Keep the
    // original order inside each rank.
    final order = {for (var i = 0; i < matches.length; i++) matches[i]: i};
    final visible = matches
      ..sort((a, b) {
        final byRank = _rank(a, normalized).compareTo(_rank(b, normalized));
        return byRank != 0 ? byRank : order[a]!.compareTo(order[b]!);
      });
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
                    decoration: InputDecoration(
                      hintText: widget.citySearch
                          ? 'Type a city name'
                          : 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        widget.citySearch && query.trim().isNotEmpty
                            ? 'No city called “${query.trim()}” in this state'
                            : 'No matching options',
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) => ListTile(
                        title: _highlight(visible[index], normalized),
                        onTap: () => Navigator.pop(context, visible[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _rank(String value, String query) {
    if (query.isEmpty) return 0;
    final lower = value.toLowerCase();
    if (lower.startsWith(query)) return 0;
    if (lower
        .split(RegExp(r'[^a-z0-9]+'))
        .any((word) => word.startsWith(query))) {
      return 1;
    }
    return 2;
  }

  Widget _highlight(String value, String query) {
    if (query.isEmpty) return Text(value);
    final start = value.toLowerCase().indexOf(query);
    if (start < 0) return Text(value);
    final end = start + query.length;
    return Text.rich(
      TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(text: value.substring(0, start)),
          TextSpan(
            text: value.substring(start, end),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value.substring(end)),
        ],
      ),
    );
  }
}
