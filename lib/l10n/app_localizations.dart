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
      'showExtendedTrackInfo': 'Show Extended Track Info',
      'settings': 'Settings',
      'close': 'Close',
      'telegram': 'Telegram',
      'chat': 'Chat',
      'videoStream': 'Video Stream',
      'nowPlaying': 'Now Playing',
      'buffering': 'Buffering...',
      'privacyPolicy': 'Privacy Policy',
    },
    'ru': {
      'languageDialogTitle': 'Выберите язык',
      'vibration': 'Вибрация',
      'adaptiveBackground': 'Адаптивный фон',
      'coverLoading': 'Загружать обложки',
      'showEqualizer': 'Показывать эквалайзер',
      'showExtendedTrackInfo': 'Показывать доп. информацию о треке',
      'settings': 'Настройки',
      'close': 'Закрыть',
      'telegram': 'Телеграм',
      'chat': 'Чат',
      'videoStream': 'Видео стрим',
      'nowPlaying': 'Сейчас играет',
      'buffering': 'Буферизация...',
      'privacyPolicy': 'Политика конфиденциальности',
    },
    'he': {
      'languageDialogTitle': 'בחר שפה',
      'vibration': 'רטט',
      'adaptiveBackground': 'רקע דינמי',
      'coverLoading': 'טען תמונת כריכה',
      'showEqualizer': 'הצג אקולייזר',
      'showExtendedTrackInfo': 'הצג מידע מורחב על השיר',
      'settings': 'הגדרות',
      'close': 'סגור',
      'telegram': 'טלגרם',
      'chat': 'צאט',
      'videoStream': 'זרם וידאו',
      'nowPlaying': 'מנגן כעת',
      'buffering': 'ממתין...',
      'privacyPolicy': 'מדיניות פרטיות',
    },
    'fr': {
      'languageDialogTitle': 'Sélectionner la langue',
      'vibration': 'Vibration',
      'adaptiveBackground': 'Fond adaptatif',
      'coverLoading': 'Charger les pochettes',
      'showEqualizer': 'Afficher l’égaliseur',
      'showExtendedTrackInfo': 'Afficher les informations détaillées du titre',
      'settings': 'Paramètres',
      'close': 'Fermer',
      'telegram': 'Telegram',
      'chat': 'Chat',
      'videoStream': 'Flux vidéo',
      'nowPlaying': 'En cours de lecture',
      'buffering': 'Mise en mémoire tampon...',
      'privacyPolicy': 'Politique de confidentialité',
    },
    'es': {
      'languageDialogTitle': 'Seleccionar idioma',
      'vibration': 'Vibración',
      'adaptiveBackground': 'Fondo adaptativo',
      'coverLoading': 'Cargar portadas',
      'showEqualizer': 'Mostrar ecualizador',
      'showExtendedTrackInfo': 'Mostrar información adicional del tema',
      'settings': 'Configuración',
      'close': 'Cerrar',
      'telegram': 'Telegram',
      'chat': 'Chat',
      'videoStream': 'Transmisión de video',
      'nowPlaying': 'Ahora suena',
      'buffering': 'Buffering...',
      'privacyPolicy': 'Política de privacidad',
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
  String get showExtendedTrackInfo =>
      _localizedValues[locale.languageCode]!['showExtendedTrackInfo']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;
  String get close => _localizedValues[locale.languageCode]!['close']!;
  String get telegram => _localizedValues[locale.languageCode]!['telegram']!;
  String get chat => _localizedValues[locale.languageCode]!['chat']!;
  String get videoStream =>
      _localizedValues[locale.languageCode]!['videoStream']!;
  String get nowPlaying =>
      _localizedValues[locale.languageCode]!['nowPlaying']!;
  String get buffering => _localizedValues[locale.languageCode]!['buffering']!;
  String get privacyPolicy =>
      _localizedValues[locale.languageCode]!['privacyPolicy']!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ru', 'es', 'fr', 'he'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
