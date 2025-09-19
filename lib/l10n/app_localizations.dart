import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';

// Локализация для VTRNK Radio
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Статические переводы
  Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'languageDialogTitle': 'Select Language',
      'vibration': 'Vibration',
      'adaptiveBackground': 'Adaptive Background',
      'coverLoading': 'Load Cover Art',
      'showEqualizer': 'Show Equalizer',
      'settings': 'Settings',
      'close': 'Close',
      'telegram': 'Telegram',
      'chat': 'Chat',
      'videoStream': 'Video Stream',
      'nowPlaying': 'Now Playing',
      'buffering': 'Buffering...',
    },
    'ru': {
      'languageDialogTitle': 'Выберите язык',
      'vibration': 'Вибрация',
      'adaptiveBackground': 'Адаптивный фон',
      'coverLoading': 'Загружать обложки',
      'showEqualizer': 'Показывать эквалайзер',
      'settings': 'Настройки',
      'close': 'Закрыть',
      'telegram': 'Телеграм',
      'chat': 'Чат',
      'videoStream': 'Видеопоток',
      'nowPlaying': 'Сейчас играет',
      'buffering': 'Буферизация...',
    },
    'he': {
      'languageDialogTitle': 'בחר שפה',
      'vibration': 'רטט',
      'adaptiveBackground': 'רקע דינמי',
      'coverLoading': 'טען תמונת כריכה',
      'showEqualizer': 'הצג אקולייזר',
      'settings': 'הגדרות',
      'close': 'סגור',
      'telegram': 'טלגרם',
      'chat': 'צאט',
      'videoStream': 'זרם וידאו',
      'nowPlaying': 'מנגן כעת',
      'buffering': 'ממתין...',
    },
  };

  String get languageDialogTitle =>
      _localizedValues[locale.languageCode]!['languageDialogTitle']!;
  String get vibration => _localizedValues[locale.languageCode]!['vibration']!;
  String get adaptiveBackground =>
      _localizedValues[locale.languageCode]!['adaptiveBackground']!;
  String get coverLoading =>
      _localizedValues[locale.languageCode]!['coverLoading']!;
  String get showEqualizer =>
      _localizedValues[locale.languageCode]!['showEqualizer']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;
  String get close => _localizedValues[locale.languageCode]!['close']!;
  String get telegram => _localizedValues[locale.languageCode]!['telegram']!;
  String get chat => _localizedValues[locale.languageCode]!['chat']!;
  String get videoStream =>
      _localizedValues[locale.languageCode]!['videoStream']!;
  String get nowPlaying =>
      _localizedValues[locale.languageCode]!['nowPlaying']!;
  String get buffering => _localizedValues[locale.languageCode]!['buffering']!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ru', 'he'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
