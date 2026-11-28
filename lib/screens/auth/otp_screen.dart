import 'package:employer_kariger_app/controllers/auth_controller.dart'
    show employerNeedsRegistration;
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  String? formError;
  static const _resendCooldown = 30;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  final phoneController = TextEditingController();
  final otpControllers = List.generate(4, (_) => TextEditingController());
  final otpFocusNodes = List.generate(4, (_) => FocusNode());

  void _focusFirstOtpField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !sent) return;
      otpFocusNodes.first.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (loading || _resendSeconds > 0) return;
    final phone = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) return;
    setState(() => loading = true);
    final auth = AppScope.of(context).auth;
    final success = await auth.sendOtp(phone);
    if (!mounted) return;
    setState(() => loading = false);
    if (!success) {
      _message(auth.error ?? 'Could not resend the OTP.');
      return;
    }
    for (final controller in otpControllers) {
      controller.clear();
    }
    _startResendTimer();
    _focusFirstOtpField();
    _message('A new OTP has been sent.');
  }

  void _handleBack() {
    if (!sent) {
      Navigator.maybePop(context);
      return;
    }
    _resendTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    for (final controller in otpControllers) {
      controller.clear();
    }
    setState(() => sent = false);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
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
      if (success) {
        _startResendTimer();
        _focusFirstOtpField();
      }
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
            employerNeedsRegistration(Map<String, dynamic>.from(user)));

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            needsRegistration ? const RegistrationScreen() : const MainShell(),
      ),
      (_) => false,
    );
  }

  void _message(String value) => setState(() => formError = value);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sent,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _handleBack();
    },
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shape: const Border(),
        leading: IconButton(
          onPressed: _handleBack,
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
                    if (formError != null) ...[
                      _AuthErrorBanner(
                        message: formError!,
                        onDismiss: () => setState(() => formError = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              LucideIcons.smartphone,
                              size: 28,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
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
                            "We'll send a verification code to this number",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                        resendSeconds: _resendSeconds,
                        onResend: _resendOtp,
                        onCompleted: () {
                          if (!loading) _continue();
                        },
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loading ? null : _continue,
                      child: loading
                          ? Text(sent ? 'Please wait' : 'Processing')
                          : Text(sent ? 'Verify & Continue' : 'Send OTP'),
                    ),
                    if (sent) ...[
                      const SizedBox(height: 16),
                      Text(
                        'By continuing you agree to our Terms & Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          LucideIcons.circleAlert,
          color: Theme.of(context).colorScheme.error,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        IconButton(
          onPressed: onDismiss,
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.x, size: 17),
        ),
      ],
    ),
  );
}

class _PhoneForm extends StatelessWidget {
  const _PhoneForm({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
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
            color: colors.surfaceContainerLow,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: colors.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: const FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '🇮🇳 +91',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    hintText: 'Enter the 10 digit mobile',
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
        Text(
          'Applicant alerts will be sent to this number.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _VerificationForm extends StatelessWidget {
  const _VerificationForm({
    required this.onChange,
    required this.phone,
    required this.controllers,
    required this.focusNodes,
    required this.resendSeconds,
    required this.onResend,
    required this.onCompleted,
  });
  final VoidCallback onChange;

  /// Called once every box has a digit.
  final VoidCallback onCompleted;
  final String phone;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final int resendSeconds;
  final VoidCallback onResend;

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
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
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
                    autofocus: index == 0,
                    autofillHints: index == 0
                        ? const [AutofillHints.oneTimeCode]
                        : null,
                    onChanged: (value) {
                      // Several digits in one box: a pasted or auto-filled
                      // code, or a digit typed before the focus moved on.
                      // maxLength 1 used to drop them ("1234" became "134").
                      if (value.length > 1 && index == controllers.length - 1) {
                        // Last box: the newest digit replaces the old one.
                        controllers[index].text = value.substring(
                          value.length - 1,
                        );
                      } else if (value.length > 1) {
                        var next = index;
                        for (final digit in value.split('')) {
                          if (next >= controllers.length) break;
                          controllers[next].text = digit;
                          next++;
                        }
                        if (next < controllers.length) {
                          focusNodes[next].requestFocus();
                        }
                      } else if (value.isNotEmpty &&
                          index < controllers.length - 1) {
                        focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        focusNodes[index - 1].requestFocus();
                      }
                      // All digits in: verify straight away. The button sat
                      // under the keyboard, so the code looked stuck.
                      if (value.isNotEmpty &&
                          controllers.every((c) => c.text.length == 1)) {
                        FocusScope.of(context).unfocus();
                        onCompleted();
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
      Center(
        child: resendSeconds > 0
            ? Text(
                'Resend in ${resendSeconds}s',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            : TextButton(onPressed: onResend, child: const Text('Resend OTP')),
      ),
    ],
  );
}
