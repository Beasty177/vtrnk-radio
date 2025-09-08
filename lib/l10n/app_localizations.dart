import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.localeName);

  final String localeName;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale.languageCode));
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get telegram {
    switch (localeName) {
      case 'en':
        return 'Telegram';
      case 'he':
        return 'טלגרם';
      default:
        return 'Telegram';
    }
  }

  String get chat {
    switch (localeName) {
      case 'en':
        return 'Our Chat';
      case 'he':
        return 'הצ\'אט שלנו';
      default:
        return 'Наш чат';
    }
  }

  String get videoStream {
    switch (localeName) {
      case 'en':
        return 'Video Stream';
      case 'he':
        return 'זרם וידאו';
      default:
        return 'Видео стрим';
    }
  }

  String get settings {
    switch (localeName) {
      case 'en':
        return 'Settings';
      case 'he':
        return 'הגדרות';
      default:
        return 'Настройки';
    }
  }

  String get close {
    switch (localeName) {
      case 'en':
        return 'Close';
      case 'he':
        return 'סגור';
      default:
        return 'Закрыть';
    }
  }

  String get nowPlaying {
    switch (localeName) {
      case 'en':
        return 'Now Playing';
      case 'he':
        return 'משדר כעת';
      default:
        return 'Сейчас в эфире';
    }
  }

  String get buffering {
    switch (localeName) {
      case 'en':
        return 'Buffering...';
      case 'he':
        return 'מטעין...';
      default:
        return 'Загрузка аудио...';
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ru', 'he'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
