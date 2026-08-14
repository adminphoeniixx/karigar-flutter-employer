import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final gstinController = TextEditingController();
  final panController = TextEditingController();
  File? gstDoc;
  File? panDoc;
  Map<String, dynamic>? existingKyc;
  bool loading = true;
  bool submitting = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && error == null) _load();
  }

  Future<void> _load() async {
    try {
      final response = await AppScope.of(context).api.kyc();
      if (!mounted) return;
      gstinController.text = '${response['gstin'] ?? ''}';
      existingKyc = response['kyc'] is Map
          ? Map<String, dynamic>.from(response['kyc'])
          : null;
    } on ApiException catch (exception) {
      if (!mounted) return;
      error = exception.statusCode == 404
          ? 'Business verification is currently unavailable.'
          : exception.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pick(bool pan) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (await file.length() > 5 * 1024 * 1024) {
      _message('File size must not exceed 5 MB.');
      return;
    }
    setState(() {
      if (pan) {
        panDoc = file;
      } else {
        gstDoc = file;
      }
    });
  }

  Future<void> _submit() async {
    final gstin = gstinController.text.trim().toUpperCase();
    final pan = panController.text.trim().toUpperCase();
    if (!RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z][A-Z\d]$').hasMatch(gstin)) {
      _message('Enter a valid 15-character GSTIN.');
      return;
    }
    if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(pan)) {
      _message('Enter a valid PAN number.');
      return;
    }
    if (existingKyc == null && (gstDoc == null || panDoc == null)) {
      _message('PAN and GST documents are required for the first submission.');
      return;
    }
    setState(() => submitting = true);
    try {
      await AppScope.of(
        context,
      ).api.submitKyc(gstin: gstin, pan: pan, gstDoc: gstDoc, panDoc: panDoc);
      if (!mounted) return;
      _message('Business verification submitted for review.');
      Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) _message('$exception');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  void dispose() {
    gstinController.dispose();
    panController.dispose();
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.greenBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          LucideIcons.shieldCheck,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              existingKyc?['status_label'] ??
                                  'Build trust with workers',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${existingKyc?['remarks'] ?? 'Submit business documents for verification.'}',
                              style: const TextStyle(
                                fontSize: 13,
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
              const SectionTitle('Business information'),
              LabeledField(
                'GSTIN',
                hint: '22ABCDE1234F1Z5',
                controller: gstinController,
              ),
              LabeledField(
                'PAN number',
                hint: 'ABCDE1234F',
                controller: panController,
              ),
              const SectionTitle('Documents'),
              _Upload('PAN card', file: panDoc, onTap: () => _pick(true)),
              const SizedBox(height: 10),
              _Upload(
                'Business proof / GST certificate',
                file: gstDoc,
                onTap: () => _pick(false),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: submitting ? null : _submit,
                child: Text(
                  submitting ? 'Submitting...' : 'Submit for Verification',
                ),
              ),
            ],
          ),
  );
}

class _Upload extends StatelessWidget {
  const _Upload(this.text, {required this.file, required this.onTap});
  final String text;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.upload, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file?.path.split(Platform.pathSeparator).last ?? text,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              file == null ? 'Upload' : 'Change',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
