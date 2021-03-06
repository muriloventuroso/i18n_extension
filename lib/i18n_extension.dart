import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';

import 'i18n_widget.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/i18n_extension

// /////////////////////////////////////////////////////////////////////////////////////////////////

/// To localize a translatable string, pass its [key] and the [translations] object.
///
/// The locale may also be passed, but if it's null the locale in [I18n.localeStr] will be used.
/// If [I18n.localeStr] is not yet defined, it will use the default locale of the translation.
///
/// Fallback order:
/// - If the translation to the exact locale is found, this will be returned.
/// - Otherwise, it tries to return a translation for the general language of the locale.
/// - Otherwise, it tries to return a translation for any locale with that language.
/// - Otherwise, it tries to return the key itself (which is the translation for the default locale).
///
/// Example 1:
/// If "pt_br" is asked, and "pt_br" is available, return for "pt_br".
///
/// Example 2:
/// If "pt_br" is asked, "pt_br" is not available, and "pt" is available, return for "pt".
///
/// Example 3:
/// If "pt_mo" is asked, "pt_mo" and "pt" are not available, but "pt_br" is, return for "pt_br".
///
String localize(
  String key,
  ITranslations translations, {
  String locale,
}) {
  Map<String, String> translatedStringPerLocale = translations[key];

  if (translatedStringPerLocale == null) {
    if (Translations.recordMissingKeys)
      Translations.missingKeys
          .add(TranslatedString(locale: translations.defaultLocaleStr, text: key));

    Translations.missingKeyCallback(key, translations.defaultLocaleStr);

    return key;
  }
  //
  else {
    locale = _effectiveLocale(translations, locale);

    if (locale == "null")
      throw TranslationsException("Locale is the 4 letter string 'null', which is invalid.");

    // During app initialization the locale may be null.
    // In this case, use the key itself, which is the translation in the default locale.
    if (locale == null) return key;

    // Get the translated string in the language we want.
    String translatedString = translatedStringPerLocale[locale];

    // Return the translated string in the language we want.
    if (translatedString != null) return translatedString;

    // If there's no translated string in the locale, record it.
    if (Translations.recordMissingTranslations && locale != translations.defaultLocaleStr) {
      Translations.missingTranslations.add(TranslatedString(locale: locale, text: key));
      Translations.missingTranslationCallback(key, locale);
    }

    // ---

    var lang = _language(locale);

    // Try finding the translation in the general language. Note: If the locale
    // is already general, it was already searched, so no need to do it again.
    if (!_isGeneral(locale)) {
      translatedString = translatedStringPerLocale[lang];
      if (translatedString != null) return translatedString;
    }

    // Try finding the translation in any local with that language.
    for (MapEntry<String, String> entry in translatedStringPerLocale.entries) {
      if (lang == _language(entry.key)) return entry.value;
    }

    // If nothing is found, return the key itself,
    // that is the translation in the default locale.
    return key;
  }
}

/// This simply records the given key as a missing translation with unknown locale.
String recordKey(String key) {
  if (Translations.recordMissingKeys)
    Translations.missingKeys.add(TranslatedString(locale: "", text: key));

  Translations.missingKeyCallback(key, "");

  return key;
}

/// "pt" is a general locale, because is just a language, while "pt_br" is not.
bool _isGeneral(String locale) => locale.length == 2 && !locale.contains("_");

/// The language must be the first 2 chars, otherwise this won't work.
String _language(String locale) => locale.substring(0, 2);

String localizeFill(String text, List<Object> params) => sprintf(text, params);

/// Returns the translated version for the plural modifier.
/// After getting the version, substring %d will be replaced with the modifier.
String localizePlural(
  int modifier,
  String key,
  ITranslations translations, {
  String locale,
}) {
  assert(modifier != null);
  if (locale != null) locale = locale.toLowerCase();

  Map<String, String> versions = localizeAllVersions(key, translations, locale: locale);

  String text;

  /// For plural(0), returns the version 0, otherwise the version many, otherwise the unversioned.
  if (modifier == 0)
    text = versions["0"] ?? versions["M"] ?? versions[null];

  /// For plural(1), returns the version 1, otherwise the unversioned.
  else if (modifier == 1)
    text = versions["1"] ?? versions[null];

  /// For plural(2), returns the version 2, otherwise the version 2-3-4,
  /// otherwise the version many, otherwise the unversioned.
  else if (modifier == 2)
    text = versions["2"] ?? versions["C"] ?? versions["M"] ?? versions[null];

  /// For plural(3), returns the version 3, otherwise the version 2-3-4,
  /// otherwise the version many, otherwise the unversioned.
  else if (modifier == 3)
    text = versions["3"] ?? versions["C"] ?? versions["M"] ?? versions[null];

  /// For plural(4), returns the version 4, otherwise the version 2-3-4,
  /// otherwise the version many, otherwise the unversioned.
  else if (modifier == 4)
    text = versions["4"] ?? versions["C"] ?? versions["M"] ?? versions[null];

  /// For plural(5), returns the version 5, otherwise the version many, otherwise the unversioned.
  else if (modifier == 5)
    text = versions["5"] ?? versions["M"] ?? versions[null];

  /// For plural(6), returns the version 6, otherwise the version many, otherwise the unversioned.
  else if (modifier == 6)
    text = versions["6"] ?? versions["M"] ?? versions[null];

  /// For plural(10), returns the version 10, otherwise the version many, otherwise the unversioned.
  else if (modifier == 10)
    text = versions["T"] ?? versions["M"] ?? versions[null];

  /// For plural(<0 or >2), returns the version many, otherwise the unversioned.
  else
    text = versions[modifier.toString()] ?? versions["M"] ?? versions[null];

  // ---

  if (text == null)
    throw TranslationsException("No version found "
        "(modifier: $modifier, key: '$key', locale: '${_effectiveLocale(translations, locale)}').");

  text = text.replaceAll("%d", modifier.toString());

  return text;
}

/// Return the localized string, according to key and modifier.
///
/// You may pass any type of object to the modifier, but it will to a
/// `toString()` in it and use that. So make sure your object has a suitable
/// string representation.
///
String localizeVersion(
  Object modifier,
  String key,
  ITranslations translations, {
  String locale,
}) {
  if (locale != null) locale = locale.toLowerCase();
  String total = localize(key, translations, locale: locale);
  if (!total.startsWith(_splitter1))
    throw TranslationsException("This text has no version for modifier '$modifier' "
        "(modifier: $modifier, key: '$key', locale: '${_effectiveLocale(translations, locale)}').");
  List<String> parts = total.split(_splitter1);
  for (int i = 2; i < parts.length; i++) {
    var part = parts[i];
    List<String> par = part.split(_splitter2);
    if (par.length != 2 || par[0].isEmpty || par[1].isEmpty)
      throw TranslationsException("Invalid text version for '$part'.");
    String _modifier = par[0];
    String text = par[1];
    if (_modifier == modifier.toString()) return text;
  }
  throw TranslationsException("This text has no version for modifier '$modifier' "
      "(modifier: $modifier, key: '$key', locale: '${_effectiveLocale(translations, locale)}').");
}

/// Returns a map of all translated strings, where modifiers are the keys.
/// In special, the unversioned text is returned indexed with a null key.
Map<String, String> localizeAllVersions(
  String key,
  ITranslations translations, {
  String locale,
}) {
  if (locale != null) locale = locale.toLowerCase();
  String total = localize(key, translations, locale: locale);

  if (!total.startsWith(_splitter1)) {
    return {null: total};
  }

  Map<String, String> all = {null: total};

  List<String> parts = total.split(_splitter1);
  for (int i = 2; i < parts.length; i++) {
    var part = parts[i];
    List<String> par = part.split(_splitter2);
    if (par.length != 2 || par[0].isEmpty || par[1].isEmpty)
      throw TranslationsException("Invalid text version for '$part' "
          "(key: '$key', locale: '${_effectiveLocale(translations, locale)}').");
    String version = par[0];
    String text = par[1];
    all[version] = text;
  }

  return all;
}

_effectiveLocale(ITranslations translations, String locale) {
  return (locale != null)
      ? locale = locale.toLowerCase()
      : I18n.localeStr ?? translations.defaultLocaleStr;
}

const _splitter1 = "\uFFFF";
const _splitter2 = "\uFFFE";

// /////////////////////////////////////////////////////////////////////////////////////////////////

class TranslatedString {
  //
  final String locale;
  final String text;

  TranslatedString({
    @required this.locale,
    @required this.text,
  });

  /// TranslatedString in the default locale will come first.
  /// Then, come the other TranslatedStrings with the same language as the default locale.
  /// Then, come the other TranslatedStrings, in alphabetic order.
  static int Function(TranslatedString, TranslatedString) comparable(String defaultLocaleStr) =>
      (ts1, ts2) {
        if (ts1.locale == defaultLocaleStr) return -1;
        if (ts2.locale == defaultLocaleStr) return 1;

        var defaultLanguageStr = defaultLocaleStr.substring(0, 2);

        if (ts1.locale.startsWith(defaultLanguageStr) && !ts2.locale.startsWith(defaultLocaleStr))
          return -1;

        if (ts2.locale.startsWith(defaultLanguageStr) && !ts1.locale.startsWith(defaultLocaleStr))
          return 1;

        return ts1.locale.compareTo(ts2.locale);
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslatedString &&
          runtimeType == other.runtimeType &&
          locale == other.locale &&
          text == other.text;

  @override
  int get hashCode => locale.hashCode ^ text.hashCode;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

class TranslationsException {
  String msg;

  TranslationsException(this.msg);

  @override
  String toString() => msg;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationsException && runtimeType == other.runtimeType && msg == other.msg;

  @override
  int get hashCode => msg.hashCode;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

abstract class ITranslations {
  Map<String, Map<String, String>> get translations;

  String get defaultLocaleStr;

  String get defaultLanguageStr;

  int get length;

  Map<String, String> operator [](String key) => translations[key];
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

class Translations extends ITranslations {
  //
  /// All missing keys and translations will be put here.
  /// This may be used in tests to make sure no translations are missing.
  static Set<TranslatedString> missingKeys = {};
  static Set<TranslatedString> missingTranslations = {};

  static bool recordMissingKeys = true;
  static bool recordMissingTranslations = true;

  /// Replace this to log missing keys.
  static void Function(String, String) missingKeyCallback =
      (key, locale) => print("➜ Translation key in '$locale' is missing: \"$key\".");

  /// Replace this to log missing translations.
  static void Function(String, String) missingTranslationCallback =
      (key, locale) => print("➜ There are no translations in '$locale' for \"$key\".");

  Map<String, Map<String, String>> translations;
  final String defaultLocaleStr;
  final String defaultLanguageStr;

  Translations(String defaultLocaleStr)
      : assert(defaultLocaleStr != null && trim(defaultLocaleStr).isNotEmpty),
        defaultLocaleStr = trim(defaultLocaleStr),
        defaultLanguageStr = trim(defaultLocaleStr).substring(0, 2),
        translations = Map<String, Map<String, String>>();

  static String trim(String locale) {
    locale = locale.trim();
    while (locale.endsWith("_")) locale = locale.substring(0, locale.length - 1);
    return locale;
  }

  static TranslationsByLocale byLocale(String defaultLocaleStr) =>
      TranslationsByLocale._(defaultLocaleStr);

  int get length => translations.length;

  Translations operator +(Map<String, String> translations) {
    assert(this.translations != null);
    // ---
    var defaultTranslation = translations[defaultLocaleStr];

    if (defaultTranslation == null)
      throw TranslationsException("No default translation for '$defaultLocaleStr'.");

    String key = _getKey(defaultTranslation);

    this.translations[key] = translations;
    return this;
  }

  /// If the translation does NOT start with _splitter2, the translation is the key.
  /// Otherwise, if the translation is something like "·MyKey·0→abc·1→def" the key is "Mykey".
  static String _getKey(String translation) {
    if (translation.startsWith(_splitter1)) {
      List<String> parts = translation.split(_splitter1);
      return parts[1];
    } else
      return translation;
  }

  /// Combine this translation with another translation.
  Translations operator *(ITranslations translationsByLocale) {
    if (translationsByLocale.defaultLocaleStr != defaultLocaleStr)
      throw TranslationsException("Can't combine translations with different default locales: "
          "'$defaultLocaleStr' and '${translationsByLocale.defaultLocaleStr}'.");
    // ---

    for (MapEntry<String, Map<String, String>> entry in translationsByLocale.translations.entries) {
      var key = entry.key;
      for (MapEntry<String, String> entry2 in entry.value.entries) {
        String locale = entry2.key;
        String translatedString = entry2.value;
        add(locale: locale, key: key, translatedString: translatedString);
      }
    }
    return this;
  }

  @override
  String toString() {
    String text = "\nTranslations: ---------------\n";
    for (MapEntry<String, Map<String, String>> entry in translations.entries) {
      Map<String, String> translation = entry.value;
      for (var translatedString in _translatedStrings(translation)) {
        text += "  ${translatedString.locale.padRight(5)} | ${_prettify(translatedString.text)}\n";
      }
      text += "-----------------------------\n";
    }
    return text;
  }

  /// This prettifies versioned strings (that have modifiers).
  String _prettify(String translation) {
    if (!translation.startsWith(_splitter1)) return translation;
    List<String> parts = translation.split(_splitter1);
    String result = parts[1];
    for (int i = 2; i < parts.length; i++) {
      var part = parts[i];
      List<String> par = part.split(_splitter2);
      if (par.length != 2 || par[0].isEmpty || par[1].isEmpty) return translation;
      String modifier = par[0];
      String text = par[1];
      result += "\n          $modifier → $text";
    }
    return result;
  }

  List<TranslatedString> _translatedStrings(Map<String, String> translation) => translation.entries
      .map((entry) => TranslatedString(locale: entry.key, text: entry.value))
      .toList()
        ..sort(TranslatedString.comparable(defaultLocaleStr));

  void add({
    @required String locale,
    @required String key,
    @required String translatedString,
  }) {
    if (locale == null || locale.isEmpty) throw TranslationsException("Missing locale.");
    if (key == null || key.isEmpty) throw TranslationsException("Missing key.");
    if (translatedString == null || translatedString.isEmpty)
      throw TranslationsException("Missing translatedString.");
    // ---

    Map<String, String> _translations = translations[key];
    if (_translations == null) {
      _translations = {};
      translations[key] = _translations;
    }
    _translations[locale] = translatedString;
  }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

class TranslationsByLocale extends ITranslations {
  final Translations byKey;

  Map<String, Map<String, String>> get translations => byKey.translations;

  TranslationsByLocale._(String defaultLocaleStr) : byKey = Translations(defaultLocaleStr);

  TranslationsByLocale operator +(Map<String, Map<String, String>> translations) {
    for (MapEntry<String, Map<String, String>> entry in translations.entries) {
      String locale = entry.key;
      for (MapEntry<String, String> entry2 in entry.value.entries) {
        String key = Translations._getKey(entry2.key);
        String translatedString = entry2.value;
        byKey.add(locale: locale, key: key, translatedString: translatedString);
      }
    }
    return this;
  }

  /// Combine this translation with another translation.
  TranslationsByLocale operator *(ITranslations translationsByLocale) {
    if (translationsByLocale.defaultLocaleStr != defaultLocaleStr)
      throw TranslationsException("Can't combine translations with different default locales: "
          "'$defaultLocaleStr' and '${translationsByLocale.defaultLocaleStr}'.");
    // ---

    for (MapEntry<String, Map<String, String>> entry in translationsByLocale.translations.entries) {
      var key = entry.key;
      for (MapEntry<String, String> entry2 in entry.value.entries) {
        String locale = entry2.key;
        String translatedString = entry2.value;
        byKey.add(locale: locale, key: key, translatedString: translatedString);
      }
    }
    return this;
  }

  List<TranslatedString> _translatedStrings(Map<String, String> translation) =>
      byKey._translatedStrings(translation);

  @override
  String get defaultLanguageStr => byKey.defaultLanguageStr;

  @override
  String get defaultLocaleStr => byKey.defaultLocaleStr;

  @override
  int get length => byKey.length;

  @override
  String toString() => byKey.toString();
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

extension Localization on String {
  //
  String modifier(Object identifier, String text) {
    assert(identifier != null);
    assert(text != null);
    return ((!this.startsWith(_splitter1)) ? _splitter1 : "") +
        "${this}$_splitter1$identifier$_splitter2$text";
  }

  /// Plural modifier for zero elements.
  String zero(String text) => modifier("0", text);

  /// Plural modifier for 1 element.
  String one(String text) => modifier("1", text);

  /// Plural modifier for 2 elements.
  String two(String text) => modifier("2", text);

  /// Plural modifier for 3 elements.
  String three(String text) => modifier("3", text);

  /// Plural modifier for 4 elements.
  String four(String text) => modifier("4", text);

  /// Plural modifier for 5 elements.
  String five(String text) => modifier("5", text);

  /// Plural modifier for 6 elements.
  String six(String text) => modifier("6", text);

  /// Plural modifier for 10 elements.
  String ten(String text) => modifier("T", text);

  /// Plural modifier for any number of elements, except 0, 1 and 2.
  String times(int numberOfTimes, String text) {
    assert(numberOfTimes != null && (numberOfTimes < 0 || numberOfTimes > 2));
    return modifier(numberOfTimes, text);
  }

  /// Plural modifier for 2, 3 or 4 elements (especially for Czech language).
  String twoThreeFour(String text) => modifier("C", text);

  /// Plural modifier for any number of elements, except 1.
  String many(String text) => modifier("M", text);
}

// /////////////////////////////////////////////////////////////////////////////////////////////////
