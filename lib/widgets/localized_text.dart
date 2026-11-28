import 'package:flutter/material.dart' as material;

import '../core/app_language.dart';
import '../core/app_scope.dart';
import '../core/app_strings.dart';

/// Drop-in Text widget used by employer screens. Unlike Material's Text, it
/// resolves fixed app copy again whenever the selected locale changes.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
  }) : textSpan = null;

  const Text.rich(
    material.InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
  }) : data = '';

  final String data;
  final material.TextStyle? style;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.InlineSpan? textSpan;

  /// Listens to the chosen language: most labels are `const`, so without
  /// this they kept the old language on screens that stay alive (Home, My
  /// Jobs) until the app was restarted.
  @override
  material.Widget build(material.BuildContext context) =>
      material.ListenableBuilder(
        listenable:
            AppScope.maybeOf(context)?.appLanguage ?? AppLanguage.shared,
        builder: (context, _) => _build(context),
      );

  material.Widget _build(material.BuildContext context) => textSpan == null
      ? material.Text(
          context.tr(data),
          style: style,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
        )
      : material.Text.rich(
          textSpan!,
          style: style,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
        );
}
