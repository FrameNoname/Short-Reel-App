import 'package:flutter/widgets.dart' as w;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        InlineSpan,
        StatelessWidget,
        TextAlign,
        TextOverflow,
        TextSpan,
        TextStyle,
        Widget;

import '../l10n/app_language.dart';

/// A drop-in replacement for Flutter's `Text` that shows the translation of
/// its string in the current language. Strings without a translation, such as
/// film titles and comments, are shown as written.
///
/// Files use it by importing Flutter with `hide Text` and this file.
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final span = textSpan;
    if (span == null) {
      return w.Text(
        translate(data!, language),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return w.Text.rich(
      _translated(span, language),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Translates each piece of a rich text on its own, keeping its styling.
InlineSpan _translated(InlineSpan span, AppLanguage language) {
  if (span is! TextSpan) return span;
  return TextSpan(
    text: span.text == null ? null : translate(span.text!, language),
    children: span.children
        ?.map((child) => _translated(child, language))
        .toList(),
    style: span.style,
    recognizer: span.recognizer,
    semanticsLabel: span.semanticsLabel,
  );
}
