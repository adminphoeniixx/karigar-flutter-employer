import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  Future<Map<String, dynamic>> _load() => AppScope.of(context).api.legal();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terms & Privacy')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? Center(child: Text('${snapshot.error}'))
              : const Center(child: CircularProgressIndicator());
        }
        final documents = (snapshot.data!['documents'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item));
        return ListView(
          children: documents
              .map(
                (document) => ListTile(
                  title: Text('${document['title'] ?? ''}'),
                  subtitle: Text('${document['summary'] ?? ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalDocumentScreen(
                        keyName: '${document['key'] ?? ''}',
                        title: '${document['title'] ?? 'Legal'}',
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.keyName,
    required this.title,
  });
  final String keyName, title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: AppScope.of(context).api.legalDocument(keyName),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final document = snapshot.data!['document'] as Map? ?? const {};
        final sections = document['sections'] as List? ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if ('${document['intro'] ?? ''}'.isNotEmpty)
              Text('${document['intro']}'),
            ...sections.whereType<Map>().expand(
              (section) => [
                const SizedBox(height: 20),
                Text(
                  '${section['title'] ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ...((section['blocks'] as List? ?? const [])
                    .whereType<Map>()
                    .map((block) {
                      if (block['type'] == 'list')
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: (block['items'] as List? ?? const [])
                                .map((item) => Text('• $item'))
                                .toList(),
                          ),
                        );
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '${block['text'] ?? ''}',
                          style: block['type'] == 'heading'
                              ? Theme.of(context).textTheme.titleMedium
                              : null,
                        ),
                      );
                    })),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Support')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: AppScope.of(context).api.support(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final channels = data['channels'] as Map? ?? const {};
        final faqs = data['faqs'] as List? ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (channels['email'] != null)
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text('${channels['email']}'),
                onTap: () => launchUrl(
                  Uri(scheme: 'mailto', path: '${channels['email']}'),
                ),
              ),
            if (channels['phone'] != null)
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: Text('${channels['phone']}'),
                onTap: () =>
                    launchUrl(Uri(scheme: 'tel', path: '${channels['phone']}')),
              ),
            if (channels['hours'] != null)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('${channels['hours']}'),
              ),
            const SizedBox(height: 16),
            Text(
              'Frequently asked questions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...faqs.whereType<Map>().map(
              (faq) => ExpansionTile(
                title: Text('${faq['question'] ?? ''}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text('${faq['answer'] ?? ''}'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
