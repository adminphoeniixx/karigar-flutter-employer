import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/auth/registration_screen.dart';
import 'package:employer_kariger_app/screens/dashboard/main_shell.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  bool sent = false;
  bool loading = false;
  final phoneController = TextEditingController();
  final otpControllers = List.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    phoneController.dispose();
    for (final controller in otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      _message('10 digit mobile number enter karein.');
      return;
    }
    setState(() => loading = true);
    final auth = AppScope.of(context).auth;
    if (!sent) {
      final success = await auth.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        loading = false;
        if (success) sent = true;
      });
      if (!success) _message(auth.error ?? 'OTP send nahi ho paaya.');
      return;
    }
    final otp = otpControllers.map((e) => e.text).join();
    final response = await auth.verifyOtp(phone, otp);
    if (!mounted) return;
    setState(() => loading = false);
    if (response == null) {
      _message(auth.error ?? 'OTP verify nahi ho paaya.');
      return;
    }
    final needsRegistration = response['needs_registration'] == true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            needsRegistration ? const RegistrationScreen() : const MainShell(),
      ),
      (_) => false,
    );
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      shape: const Border(),
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.smartphone,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Login with Mobile',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Employer · We'll send you a one-time code",
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!sent)
          _PhoneForm(controller: phoneController)
        else
          _VerificationForm(
            phone: phoneController.text,
            controllers: otpControllers,
            onChange: () => setState(() => sent = false),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: loading ? null : _continue,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(sent ? 'Verify & Continue' : 'Send OTP'),
        ),
        if (sent) ...[
          const SizedBox(height: 16),
          const Text(
            'By continuing you agree to our Terms & Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ],
    ),
  );
}

class _PhoneForm extends StatelessWidget {
  const _PhoneForm({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Mobile number',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 7),
      Container(
        height: 58,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.line2,
              alignment: Alignment.centerLeft,
              child: const Text(
                'IN\n+91',
                style: TextStyle(
                  height: 1.45,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  hintText: '98765 43210',
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Applicant alerts will be sent to this number.',
        style: TextStyle(color: AppColors.muted, fontSize: 11.5),
      ),
    ],
  );
}

class _VerificationForm extends StatelessWidget {
  const _VerificationForm({
    required this.onChange,
    required this.phone,
    required this.controllers,
  });
  final VoidCallback onChange;
  final String phone;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Enter the 6-digit code sent to'),
      const SizedBox(height: 4),
      Row(
        children: [
          Text('+91 $phone', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: AppColors.brand50,
              foregroundColor: AppColors.brandDark,
            ),
            child: const Text('Change', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          6,
          (index) => SizedBox(
            width: 48,
            height: 54,
            child: TextField(
              controller: controllers[index],
              onChanged: (value) {
                if (value.isNotEmpty && index < controllers.length - 1) {
                  FocusScope.of(context).nextFocus();
                }
              },
              textAlign: TextAlign.center,
              maxLength: 1,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'Resend in 30s',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ],
  );
}
