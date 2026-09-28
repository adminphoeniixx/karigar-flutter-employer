import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Semantics(
        label: 'Super Karigar Employer. Kaam. Hunar. Bharosa.',
        image: true,
        child: ExcludeSemantics(
          child: SizedBox.expand(
            child: Image.asset(
              'assets/splash.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    ),
  );
}
