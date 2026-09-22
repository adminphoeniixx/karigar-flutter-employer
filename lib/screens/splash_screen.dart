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
      systemNavigationBarColor: Color(0xFFF4F3EF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF4F3EF),
      body: Semantics(
        label: 'Super Karigar Employer. Kaam. Hunar. Bharosa.',
        image: true,
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final aspectRatio = constraints.maxWidth / constraints.maxHeight;
              // Use the complete artwork so photo/fabric transitions stay seamless.
              // Portrait crops only its outer edges; extreme shapes show it whole
              // to keep the logo, Employer title and tagline visible.
              final fit = aspectRatio >= .38 && aspectRatio <= .85
                  ? BoxFit.cover
                  : BoxFit.contain;
              return SizedBox.expand(
                child: Image.asset(
                  'assets/splash.png',
                  fit: fit,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
