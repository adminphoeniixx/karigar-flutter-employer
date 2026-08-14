import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final otpControllers = List.generate(4, (_) => TextEditingController());
  final otpFocusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    phoneController.dispose();
    for (final controller in otpControllers) {
      controller.dispose();
    }
    for (final focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      _message('Enter a valid 10-digit mobile number.');
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
      if (!success) _message(auth.error ?? 'Could not send the OTP.');
      return;
    }
    final otp = otpControllers.map((e) => e.text).join();
    if (!RegExp(r'^\d{4}$').hasMatch(otp)) {
      setState(() => loading = false);
      _message('Enter the 4-digit OTP.');
      return;
    }
    final response = await auth.verifyOtp(phone, otp);
    if (!mounted) return;
    setState(() => loading = false);
    if (response == null) {
      _message(auth.error ?? 'Could not verify the OTP.');
      return;
    }
    final user = response['user'];
    final role = user is Map
        ? user['role']?.toString().trim().toLowerCase()
        : null;
    if (role != null && role.isNotEmpty && role != 'employer') {
      await auth.logout();
      if (!mounted) return;
      setState(() {
        sent = false;
        for (final controller in otpControllers) {
          controller.clear();
        }
      });
      _message(
        'This number is already registered as a $role account. '
        'Use a different number for the employer app.',
      );
      return;
    }
    final needsRegistration =
        response['needs_registration'] == true ||
        response['is_new'] == true ||
        (user is Map &&
            (user['company_name'] == null ||
                user['company_name'].toString().trim().isEmpty));
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
    body: LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth < 360 ? 12 : 16,
          8,
          constraints.maxWidth < 360 ? 12 : 16,
          24,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                          ),
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
                      focusNodes: otpFocusNodes,
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
            ),
          ),
        ],
      ),
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
    required this.focusNodes,
  });
  final VoidCallback onChange;
  final String phone;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Enter the 4-digit code sent to'),
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
        children: List.generate(
          4,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
              child: Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      controllers[index].text.isEmpty &&
                      index > 0) {
                    controllers[index - 1].clear();
                    focusNodes[index - 1].requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: SizedBox(
                  height: 54,
                  child: TextField(
                    controller: controllers[index],
                    focusNode: focusNodes[index],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < controllers.length - 1) {
                        focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        focusNodes[index - 1].requestFocus();
                      }
                    },
                    onTap: () {
                      controllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controllers[index].text.length,
                      );
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    textInputAction: index == controllers.length - 1
                        ? TextInputAction.done
                        : TextInputAction.next,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
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
