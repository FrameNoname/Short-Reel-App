import 'package:flutter/widgets.dart';

import 'thai.dart';

enum AppLanguage {
  english('English'),
  thai('ไทย');

  const AppLanguage(this.label);

  /// Each language is named in itself, so it can be found from any language.
  final String label;
}

/// Tells widgets below it which language to show. Widgets that read it
/// rebuild when the language changes, even when they are `const`.
class LanguageScope extends InheritedWidget {
  const LanguageScope({
    super.key,
    required this.language,
    required super.child,
  });

  final AppLanguage language;

  static AppLanguage of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.language ??
      AppLanguage.english;

  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      language != oldWidget.language;
}

/// The text to show for [english] in [language]. Anything without a
/// translation stays as it is, which is what user-written content does.
String translate(String english, AppLanguage language) =>
    language == AppLanguage.thai ? thaiOf(english) : english;

extension TranslateContext on BuildContext {
  /// Translates [english] and rebuilds the caller when the language changes.
  String tr(String english) => translate(english, LanguageScope.of(this));
}
