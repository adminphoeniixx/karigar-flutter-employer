import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/api/api_exception.dart';
import '../../core/app_scope.dart';
import '../../core/theme.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final legalName = TextEditingController(), address = TextEditingController();
  final forms = <String, _DocumentForm>{};
  List<Map<String, dynamic>> types = const [];
  Map<String, Map<String, dynamic>> docs = const {};
  Map<String, dynamic> kyc = const {};
  String? type, error;
  bool loading = true, submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _load();
  }

  Map<String, dynamic>? _first(
    Iterable<Map<String, dynamic>> rows,
    bool Function(Map<String, dynamic>) check,
  ) {
    for (final row in rows) {
      if (check(row)) return row;
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final api = AppScope.of(context).api;
      final data = await Future.wait([api.reference(), api.kyc()]);
      if (!mounted) return;
      final ref = data[0], response = data[1];
      final verification = ref['verification'] is Map
          ? Map<String, dynamic>.from(ref['verification'] as Map)
          : <String, dynamic>{};
      types = (verification['business_types'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      docs = {
        for (final e
            in (verification['documents'] as List? ?? const [])
                .whereType<Map>())
          '${e['key']}': Map<String, dynamic>.from(e),
      };
      kyc = response['kyc'] is Map
          ? Map<String, dynamic>.from(response['kyc'] as Map)
          : const {};
      final business = response['business'] is Map
          ? Map<String, dynamic>.from(response['business'] as Map)
          : const {};
      type = business['business_type']?.toString();
      legalName.text = '${business['legal_name'] ?? ''}';
      address.text = '${business['registered_address'] ?? ''}';
      _syncDocuments();
    } on ApiException catch (e) {
      error = e.statusCode == 404
          ? 'Business verification is currently unavailable.'
          : e.message;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _syncDocuments() {
    final selected = _first(types, (e) => '${e['key']}' == type);
    final keys = (selected?['documents'] as List? ?? const [])
        .map((e) => '$e')
        .toSet();
    final saved = (kyc['documents'] as List? ?? const []).whereType<Map>().map(
      (e) => Map<String, dynamic>.from(e),
    );
    for (final key in keys) {
      forms.putIfAbsent(key, () {
        final old = _first(saved, (e) => '${e['type']}' == key);
        return _DocumentForm()..number.text = '${old?['number'] ?? ''}';
      });
    }
    forms.removeWhere((key, _) => !keys.contains(key));
  }

  Future<void> _pick(_DocumentForm form) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (await file.length() > 5 * 1024 * 1024) {
      _message('File size must not exceed 5 MB.');
      return;
    }
    setState(() => form.file = file);
  }

  Future<void> _submit() async {
    if (type == null ||
        legalName.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      _message('Select business type and complete business details.');
      return;
    }
    final fields = <String, String>{
      'business_type': type!,
      'legal_name': legalName.text.trim(),
      'registered_address': address.text.trim(),
    };
    final files = <String, File>{};
    for (final entry in forms.entries) {
      final key = entry.key, form = entry.value;
      if (form.missing) {
        if (form.alternate == null || form.reason.text.trim().isEmpty) {
          _message(
            'Complete alternate details for ${docs[key]?['label'] ?? key}.',
          );
          return;
        }
        fields['${key}_missing'] = '1';
        fields['${key}_alt_type'] = form.alternate!;
        fields['${key}_reason'] = form.reason.text.trim();
        if (form.number.text.trim().isNotEmpty)
          fields['${key}_alt_number'] = form.number.text.trim();
        if (form.file != null) files['${key}_alt_doc'] = form.file!;
      } else {
        if (form.number.text.trim().isEmpty) {
          _message('Enter ${docs[key]?['label'] ?? key} number.');
          return;
        }
        fields['${docs[key]?['number_field'] ?? '${key}_number'}'] = form
            .number
            .text
            .trim()
            .toUpperCase()
            .replaceAll(' ', '');
        if (form.file != null) files['${key}_doc'] = form.file!;
      }
    }
    setState(() => submitting = true);
    try {
      await AppScope.of(context).api.submitKyc(fields: fields, files: files);
      if (!mounted) return;
      _message('Business verification submitted for review.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  void dispose() {
    legalName.dispose();
    address.dispose();
    for (final form in forms.values) {
      form.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business Verification')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error!, textAlign: TextAlign.center),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(
                    LucideIcons.shieldCheck,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    '${kyc['status_label'] ?? 'Verify your business'}',
                  ),
                  subtitle: kyc['remarks'] == null
                      ? const Text('Submit your details for review.')
                      : Text('${kyc['remarks']}'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Business details',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Business type'),
                items: types
                    .map(
                      (e) => DropdownMenuItem(
                        value: '${e['key']}',
                        child: Text('${e['label']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  type = value;
                  _syncDocuments();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: legalName,
                decoration: InputDecoration(
                  labelText: type == 'individual'
                      ? 'Full name (as on PAN)'
                      : 'Legal name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: type == 'individual'
                      ? 'Address'
                      : 'Registered address',
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Documents',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              ...forms.entries.map(
                (e) => _DocumentCard(
                  label: '${docs[e.key]?['label'] ?? e.key}',
                  config: docs[e.key] ?? const {},
                  form: e.value,
                  pick: () => _pick(e.value),
                  changed: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: submitting ? null : _submit,
                icon: const Icon(LucideIcons.shieldCheck),
                label: Text(
                  submitting ? 'Submitting...' : 'Submit for verification',
                ),
              ),
            ],
          ),
  );
}

class _DocumentForm {
  final number = TextEditingController(), reason = TextEditingController();
  bool missing = false;
  String? alternate;
  File? file;
  void dispose() {
    number.dispose();
    reason.dispose();
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.label,
    required this.config,
    required this.form,
    required this.pick,
    required this.changed,
  });
  final String label;
  final Map<String, dynamic> config;
  final _DocumentForm form;
  final VoidCallback pick, changed;
  @override
  Widget build(BuildContext context) {
    final alternatives = (config['alternates'] as List? ?? const [])
        .whereType<Map>();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("I don't have this"),
              value: form.missing,
              onChanged: (v) {
                form.missing = v;
                changed();
              },
            ),
            if (form.missing) ...[
              DropdownButtonFormField<String>(
                value: form.alternate,
                decoration: const InputDecoration(
                  labelText: 'Document you have',
                ),
                items: alternatives
                    .map(
                      (e) => DropdownMenuItem(
                        value: '${e['key']}',
                        child: Text('${e['label']}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  form.alternate = v;
                  changed();
                },
              ),
              TextField(
                controller: form.number,
                decoration: const InputDecoration(
                  labelText: 'Document number (optional)',
                ),
              ),
              TextField(
                controller: form.reason,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Why don't you have it?",
                ),
              ),
            ] else
              TextField(
                controller: form.number,
                decoration: InputDecoration(
                  labelText: '$label number',
                  hintText: '${config['hint'] ?? ''}',
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: pick,
              icon: const Icon(LucideIcons.upload, size: 18),
              label: Text(
                form.file == null
                    ? 'Upload photo or PDF'
                    : form.file!.path.split(Platform.pathSeparator).last,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
