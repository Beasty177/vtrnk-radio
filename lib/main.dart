import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'l10n/app_localizations.dart';

AudioHandler? globalAudioHandler;

// Top-level function to extract dominant color with preference for vibrant colors
Color? extractDominantColor(Uint8List imageBytes) {
  try {
    debugPrint(
        'Extracting dominant color from image bytes, length=${imageBytes.length}');
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      debugPrint('Failed to decode image for color extraction');
      return null;
    }
    final pixels = image.getBytes();
    debugPrint(
        'Image decoded: width=${image.width}, height=${image.height}, pixels=${pixels.length}');
    // Convert RGB to HSV and track vibrant colors
    Map<int, int> colorCounts = {};
    Map<int, double> saturationMap = {};
    for (int i = 0; i < pixels.length; i += 4) {
      int r = pixels[i];
      int g = pixels[i + 1];
      int b = pixels[i + 2];
      // Convert RGB to HSV
      double rNorm = r / 255.0;
      double gNorm = g / 255.0;
      double bNorm = b / 255.0;
      double max = [rNorm, gNorm, bNorm].reduce((a, b) => a > b ? a : b);
      double min = [rNorm, gNorm, bNorm].reduce((a, b) => a < b ? a : b);
      double saturation = max == 0 ? 0 : (max - min) / max;
      // Only consider colors with sufficient saturation to avoid grey
      if (saturation > 0.3) {
        int color = (r << 16) | (g << 8) | b;
        colorCounts[color] = (colorCounts[color] ?? 0) + 1;
        saturationMap[color] = saturation;
      }
    }
    if (colorCounts.isEmpty) {
      debugPrint('No vibrant pixels found for color extraction');
      return null;
    }
    // Find the most frequent vibrant color
    int maxCount = 0;
    int dominantColorInt = 0;
    double maxSaturation = 0;
    colorCounts.forEach((color, count) {
      double saturation = saturationMap[color] ?? 0;
      // Prioritize colors with higher saturation and sufficient frequency
      if (count > maxCount ||
          (count == maxCount && saturation > maxSaturation)) {
        maxCount = count;
        dominantColorInt = color;
        maxSaturation = saturation;
      }
    });
    final dominantR = (dominantColorInt >> 16) & 0xFF;
    final dominantG = (dominantColorInt >> 8) & 0xFF;
    final dominantB = dominantColorInt & 0xFF;
    final result = Color.fromRGBO(dominantR, dominantG, dominantB, 1.0);
    debugPrint(
        'Dominant color extracted: R=$dominantR G=$dominantG B=$dominantB, saturation=$maxSaturation');
    return result;
  } catch (e) {
    debugPrint("Error in color extraction: $e");
    return null;
  }
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      try {
        globalAudioHandler = await AudioService.init(
          builder: () => AudioPlayerHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.vtrnk.radio.channel.audio',
            androidNotificationChannelName: 'VTRNK Radio Playback',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        );
        debugPrint('AudioService init success');
      } catch (e) {
        debugPrint('Audio initialization error: $e');
      }
      runApp(const MyApp());
    },
    (error, stackTrace) {
      debugPrint('Unhandled error in main: $error');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _localeNotifier = ValueNotifier<Locale>(const Locale('en'));

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString('locale');
    if (savedLocale == null) {
      // First app launch: check device locale
      final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
      final supportedLocales = ['en', 'ru', 'es', 'fr', 'he'];
      final defaultLocale =
          supportedLocales.contains(deviceLocale) ? deviceLocale : 'en';
      await prefs.setString('locale', defaultLocale);
      _localeNotifier.value = Locale(defaultLocale);
    } else {
      _localeNotifier.value = Locale(savedLocale);
    }
  }

  Future<void> _setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    _localeNotifier.value = Locale(locale);
  }

  @override
  void dispose() {
    _localeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: _localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'VTRNK Radio',
          locale: locale,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('ru', ''),
            Locale('es', ''),
            Locale('fr', ''),
            Locale('he', ''),
          ],
          home: MyHomePage(onLocaleChange: _setLocale),
        );
      },
    );
  }
}

class AppSettings {
  final bool enableVibration;
  final bool enableAdaptiveBackground;
  final bool enableCoverLoading;
  final bool showEqualizer;
  final bool showExtendedTrackInfo;

  AppSettings({
    this.enableVibration = true,
    this.enableAdaptiveBackground = true,
    this.enableCoverLoading = true,
    this.showEqualizer = true,
    this.showExtendedTrackInfo = true,
  });

  AppSettings copyWith({
    bool? enableVibration,
    bool? enableAdaptiveBackground,
    bool? enableCoverLoading,
    bool? showEqualizer,
    bool? showExtendedTrackInfo,
  }) {
    return AppSettings(
      enableVibration: enableVibration ?? this.enableVibration,
      enableAdaptiveBackground:
          enableAdaptiveBackground ?? this.enableAdaptiveBackground,
      enableCoverLoading: enableCoverLoading ?? this.enableCoverLoading,
      showEqualizer: showEqualizer ?? this.showEqualizer,
      showExtendedTrackInfo:
          showExtendedTrackInfo ?? this.showExtendedTrackInfo,
    );
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableVibration', enableVibration);
    await prefs.setBool('enableAdaptiveBackground', enableAdaptiveBackground);
    await prefs.setBool('enableCoverLoading', enableCoverLoading);
    await prefs.setBool('showEqualizer', showEqualizer);
    await prefs.setBool('showExtendedTrackInfo', showExtendedTrackInfo);
  }

  static Future<AppSettings> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      enableVibration: prefs.getBool('enableVibration') ?? true,
      enableAdaptiveBackground:
          prefs.getBool('enableAdaptiveBackground') ?? true,
      enableCoverLoading: prefs.getBool('enableCoverLoading') ?? true,
      showEqualizer: prefs.getBool('showEqualizer') ?? true,
      showExtendedTrackInfo: prefs.getBool('showExtendedTrackInfo') ?? true,
    );
  }
}

class MyHomePage extends StatefulWidget {
  final void Function(String) onLocaleChange;
  const MyHomePage({super.key, required this.onLocaleChange});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isMenuOpen = false;
  late AnimationController _controller;
  late AnimationController _colorController;
  late AnimationController _menuController;
  late AnimationController _buttonController;
  late List<AnimationController> _menuItemControllers;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _menuOpacityAnimation;
  late Animation<Offset> _menuOffsetAnimation;
  late Animation<double> _buttonScaleAnimation;
  late List<Animation<double>> _menuItemScaleAnimations;
  late List<double> _randomOffsets;
  late List<double> _randomMultipliers;
  late List<double> _randomSpeeds;
  final Random _random = Random();
  final int barCount = 14;
  AudioPlayerHandler? _audioHandler;
  bool _isPlaying = false;
  String _artist = "Waiting for artist...";
  String _title = "Waiting for track...";
  String _coverUrl = 'assets/vt-videoplaceholder.png';
  Uint8List? _coverBytes;
  Uint8List? _previousCoverBytes;
  String? _previousCoverUrl;
  bool _isAssetCover = true;
  Color _backgroundColor = Colors.black;
  bool _isLoading = true;
  String _errorMessage = '';
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _randomOffsets =
        List.generate(barCount, (_) => _random.nextDouble() * pi * 2);
    _randomMultipliers =
        List.generate(barCount, (_) => _random.nextDouble() * 0.8 + 0.2);
    _randomSpeeds =
        List.generate(barCount, (_) => 0.8 + _random.nextDouble() * 0.7);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          setState(() {
            _randomOffsets =
                List.generate(barCount, (_) => _random.nextDouble() * pi * 2);
            _randomMultipliers = List.generate(
                barCount, (_) => _random.nextDouble() * 0.8 + 0.2);
            _randomSpeeds = List.generate(
                barCount, (_) => 0.8 + _random.nextDouble() * 0.7);
          });
        }
      });
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _colorAnimation =
        ColorTween(begin: _backgroundColor, end: _backgroundColor).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
    );
    _menuOffsetAnimation = Tween<Offset>(
      begin: const Offset(-0.2, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
    );
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    _menuItemControllers = List.generate(
      7, // Обновлено с 6 на 7 для Privacy Policy
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
      ),
    );
    _menuItemScaleAnimations = _menuItemControllers
        .asMap()
        .map((index, controller) => MapEntry(
              index,
              Tween<double>(begin: 1.0, end: 0.95).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
              ),
            ))
        .values
        .toList();
    _initAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _audioHandler != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _audioHandler!.fetchTrackInfo();
        if (_settings.enableCoverLoading) {
          _audioHandler!.loadCover();
        }
        debugPrint('App resumed: Refreshing track info and cover');
      });
    }
  }

  Future<void> _showLanguageDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          title: Text(
            AppLocalizations.of(context).languageDialogTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                    title: const Text(
                      'English',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      widget.onLocaleChange('en');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Text('🇷🇺', style: TextStyle(fontSize: 24)),
                    title: const Text(
                      'Русский',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      widget.onLocaleChange('ru');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Text('🇪🇸', style: TextStyle(fontSize: 24)),
                    title: const Text(
                      'Español',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      widget.onLocaleChange('es');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Text('🇫🇷', style: TextStyle(fontSize: 24)),
                    title: const Text(
                      'Français',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      widget.onLocaleChange('fr');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Text('🇮🇱', style: TextStyle(fontSize: 24)),
                    title: const Text(
                      'עברית',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      widget.onLocaleChange('he');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a1a),
              title: Text(
                AppLocalizations.of(context).settings,
                style: const TextStyle(color: Colors.white),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: Text(
                          AppLocalizations.of(context).vibration,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: _settings.enableVibration,
                        onChanged: (value) {
                          setDialogState(() {
                            _settings = _settings.copyWith(
                              enableVibration: value,
                            );
                          });
                          setState(() {});
                          _settings.saveToPrefs();
                          debugPrint('Vibration setting changed: $value');
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          AppLocalizations.of(context).adaptiveBackground,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: _settings.enableAdaptiveBackground,
                        onChanged: (value) {
                          setDialogState(() {
                            _settings = _settings.copyWith(
                              enableAdaptiveBackground: value,
                            );
                          });
                          setState(() {
                            debugPrint(
                                'Adaptive background setting changed: $value');
                            if (!value) {
                              _backgroundColor = Colors.black;
                              _colorAnimation = ColorTween(
                                begin: _backgroundColor,
                                end: _backgroundColor,
                              ).animate(
                                CurvedAnimation(
                                  parent: _colorController,
                                  curve: Curves.easeInOut,
                                ),
                              );
                            } else if (!_isAssetCover) {
                              _loadCoverBytes();
                            }
                          });
                          _settings.saveToPrefs();
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          AppLocalizations.of(context).coverLoading,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: _settings.enableCoverLoading,
                        onChanged: (value) async {
                          setDialogState(() {
                            _settings = _settings.copyWith(
                              enableCoverLoading: value,
                            );
                          });
                          setState(() {
                            debugPrint('Cover loading setting changed: $value');
                            _isAssetCover = !value;
                            if (value && _audioHandler != null) {
                              _audioHandler!.loadCover();
                              if (_settings.enableAdaptiveBackground) {
                                _loadCoverBytes();
                              }
                            } else {
                              _previousCoverUrl = _coverUrl;
                              _previousCoverBytes = _coverBytes;
                              _coverUrl = 'assets/vt-videoplaceholder.png';
                              _coverBytes = null;
                              _isAssetCover = true;
                              _backgroundColor = Colors.black;
                              _colorAnimation = ColorTween(
                                begin: _backgroundColor,
                                end: _backgroundColor,
                              ).animate(
                                CurvedAnimation(
                                  parent: _colorController,
                                  curve: Curves.easeInOut,
                                ),
                              );
                            }
                          });
                          await _settings.saveToPrefs();
                          await Future.delayed(
                              const Duration(milliseconds: 500));
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          AppLocalizations.of(context).showEqualizer,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: _settings.showEqualizer,
                        onChanged: (value) {
                          setDialogState(() {
                            _settings = _settings.copyWith(
                              showEqualizer: value,
                            );
                          });
                          setState(() {});
                          _settings.saveToPrefs();
                          debugPrint('Show equalizer setting changed: $value');
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          AppLocalizations.of(context).showExtendedTrackInfo,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: _settings.showExtendedTrackInfo,
                        onChanged: (value) {
                          setDialogState(() {
                            _settings = _settings.copyWith(
                              showExtendedTrackInfo: value,
                            );
                          });
                          setState(() {
                            debugPrint(
                                'Show extended track info setting changed: $value');
                          });
                          _settings.saveToPrefs();
                          _audioHandler?.updateMediaMetadata(
                              settings: _settings, title: _title);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).close,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _initAll() async {
    debugPrint('InitAll start');
    try {
      _settings = await AppSettings.loadFromPrefs();
      debugPrint(
          'Settings loaded: enableCoverLoading=${_settings.enableCoverLoading}, enableAdaptiveBackground=${_settings.enableAdaptiveBackground}, showExtendedTrackInfo=${_settings.showExtendedTrackInfo}');
      _isAssetCover = !_settings.enableCoverLoading;
      if (_isAssetCover) {
        _coverUrl = 'assets/vt-videoplaceholder.png';
        await _loadCoverBytes();
      }
      _audioHandler = globalAudioHandler as AudioPlayerHandler?;
      if (_audioHandler == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Audio initialization failed';
        });
        return;
      }
      _audioHandler!.playbackState.listen((playbackState) {
        if (mounted) {
          setState(() {
            _isPlaying = playbackState.playing;
            if (_isPlaying && _settings.showEqualizer) {
              _controller.repeat(reverse: true);
            } else {
              _controller.stop();
              _controller.reset();
            }
          });
        }
      });
      try {
        _audioHandler!.mediaItem.listen((MediaItem? item) {
          if (mounted && item != null) {
            debugPrint(
                'MediaItem received in UI: title=${item.title}, artist=${item.artist}, cover=${item.artUri}');
            setState(() {
              _artist = item.artist ?? "VTRNK";
              _title = item.title;
              if (_settings.enableCoverLoading && !_isAssetCover) {
                _previousCoverUrl = _coverUrl;
                final newCoverUrl =
                    item.artUri?.toString() ?? 'assets/vt-videoplaceholder.png';
                if (newCoverUrl != _coverUrl) {
                  _previousCoverBytes = _coverBytes;
                  _coverUrl = newCoverUrl;
                }
              }
            });
            if (!_isAssetCover) {
              _loadCoverBytes();
            }
          }
        });
        // Force initial fetch of track info and cover
        if (_settings.enableCoverLoading && !_isAssetCover) {
          _audioHandler!.loadCover();
          await _audioHandler!.fetchTrackInfo();
          final initialItem = _audioHandler!.mediaItem.value;
          if (mounted && initialItem != null) {
            debugPrint(
                'Initial MediaItem set: title=${initialItem.title}, artist=${initialItem.artist}, cover=${initialItem.artUri}');
            setState(() {
              _artist = initialItem.artist ?? "VTRNK";
              _title = initialItem.title;
              if (_settings.enableCoverLoading && !_isAssetCover) {
                _previousCoverUrl = _coverUrl;
                final newCoverUrl = initialItem.artUri?.toString() ??
                    'assets/vt-videoplaceholder.png';
                if (newCoverUrl != _coverUrl) {
                  _previousCoverBytes = _coverBytes;
                  _coverUrl = newCoverUrl;
                }
              }
            });
            _loadCoverBytes();
          }
        }
      } catch (e) {
        debugPrint('MediaItem listen error: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('InitAll success');
    } catch (e) {
      debugPrint('InitAll error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Initialization error: $e';
        });
      }
    }
  }

  Future<void> _loadCoverBytes() async {
    if (_coverUrl == _previousCoverUrl) {
      debugPrint('Cover URL unchanged, skipping reload to avoid flicker');
      return;
    }

    if (_isAssetCover || _coverUrl.startsWith('assets/')) {
      try {
        final byteData = await rootBundle.load(_coverUrl);
        final bytes = byteData.buffer.asUint8List();
        if (mounted) {
          setState(() {
            _coverBytes = bytes;
          });
        }
        if (_settings.enableAdaptiveBackground) {
          _updateBackgroundColor(bytes);
        }
      } catch (e) {
        debugPrint('Asset load error: $e');
      }
      return;
    }

    if (!_settings.enableAdaptiveBackground && !_settings.enableCoverLoading) {
      debugPrint('Load bytes skipped: Settings disabled');
      return;
    }

    try {
      debugPrint('Loading cover bytes from $_coverUrl');
      final response = await http
          .get(Uri.parse(_coverUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint(
            'Failed to load image bytes: ${response.statusCode}, body=${response.body}');
        return;
      }
      final bytes = response.bodyBytes;
      if (mounted) {
        setState(() {
          _coverBytes = bytes;
        });
      }
      if (_settings.enableAdaptiveBackground) {
        _updateBackgroundColor(bytes);
      }
    } catch (e) {
      debugPrint("Error loading cover bytes: $e");
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        _loadCoverBytes();
      }
    }
  }

  Future<void> _updateBackgroundColor(Uint8List bytes) async {
    try {
      final dominantColor = await compute(extractDominantColor, bytes);
      if (dominantColor == null) {
        debugPrint('Failed to extract dominant color');
        return;
      }
      if (mounted) {
        setState(() {
          final luminance = dominantColor.computeLuminance();
          final targetColor = Color.fromRGBO(
            (dominantColor.r * 255.0).round() & 0xFF,
            (dominantColor.g * 255.0).round() & 0xFF,
            (dominantColor.b * 255.0).round() & 0xFF,
            luminance > 0.5 ? 0.8 : 1.0,
          );
          debugPrint(
              'Setting background color: $targetColor, luminance=$luminance');
          _colorAnimation = ColorTween(
            begin: _backgroundColor,
            end: targetColor,
          ).animate(
            CurvedAnimation(
              parent: _colorController,
              curve: Curves.easeInOut,
            ),
          );
          _backgroundColor = targetColor;
        });
        _colorController.forward(from: 0.0);
      }
    } catch (e) {
      debugPrint("Error updating background: $e");
    }
  }

  Widget _buildCoverWidget() {
    debugPrint(
        'Building cover widget: _coverUrl=$_coverUrl, _isAssetCover=$_isAssetCover, _previousCoverUrl=$_previousCoverUrl, hasBytes=${_coverBytes != null}');

    final currentCover = _coverBytes != null
        ? Image.memory(
            _coverBytes!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Image.memory error: $error');
              return Image.asset('assets/vt-videoplaceholder.png',
                  fit: BoxFit.cover);
            },
          )
        : const SizedBox.shrink();

    final previousCover = _previousCoverBytes != null
        ? Image.memory(
            _previousCoverBytes!,
            fit: BoxFit.cover,
          )
        : Image.asset(
            'assets/vt-videoplaceholder.png',
            fit: BoxFit.cover,
          );

    if (_isAssetCover || _coverUrl.startsWith('assets/')) {
      return Image.asset(
        _coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image.asset error: $error');
          return Image.asset('assets/vt-videoplaceholder.png',
              fit: BoxFit.cover);
        },
      );
    } else {
      return AnimatedCrossFade(
        firstChild: previousCover,
        secondChild: currentCover,
        crossFadeState: _coverBytes != null
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 600),
        firstCurve: Curves.easeInOut,
        secondCurve: Curves.easeInOut,
        layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
          return Stack(
            children: <Widget>[
              Positioned(
                key: bottomChildKey,
                left: 0.0,
                top: 0.0,
                right: 0.0,
                bottom: 0.0,
                child: bottomChild,
              ),
              Positioned(
                key: topChildKey,
                child: topChild,
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_settings.enableVibration) {
        HapticFeedback.lightImpact();
      }
      _buttonController.forward().then((_) => _buttonController.reverse());
      if (_audioHandler == null) {
        debugPrint('Audio handler not initialized');
        setState(() {
          _errorMessage = 'Audio handler not initialized';
        });
        return;
      }
      if (_isPlaying) {
        await _audioHandler!.pause();
      } else {
        await _audioHandler!.play();
      }
    } catch (e) {
      debugPrint("Playback error: $e");
      setState(() {
        _errorMessage = 'Playback error: $e';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _colorController.dispose();
    _menuController.dispose();
    _buttonController.dispose();
    for (var controller in _menuItemControllers) {
      controller.dispose();
    }
    _audioHandler?.stop();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_settings.enableVibration) {
        HapticFeedback.lightImpact();
      }
      if (_isMenuOpen) {
        _menuController.forward();
      } else {
        _menuController.reverse();
      }
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      debugPrint('Attempting to launch URL: $url');
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('Can launch URL: $canLaunch');
      if (canLaunch) {
        await launchUrl(
          uri,
          mode: url.startsWith('https://t.me')
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
        debugPrint('URL launched successfully: $url');
      } else {
        debugPrint("Could not launch URL: $url - app not found");
      }
    } catch (e) {
      debugPrint("Error launching URL: $url - $e");
    }
  }

  void _onMenuItemTap(int index, VoidCallback callback) {
    if (_settings.enableVibration) {
      HapticFeedback.lightImpact();
    }
    _menuItemControllers[index].forward().then((_) {
      _menuItemControllers[index].reverse();
      callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
              ElevatedButton(onPressed: _initAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    String mainTitle = _title;
    String? parenthetical;
    if (_settings.showExtendedTrackInfo) {
      int bracketIndex = _title.indexOf('(');
      int squareBracketIndex = _title.indexOf('[');
      int firstBracketIndex = -1;
      if (bracketIndex == -1 && squareBracketIndex != -1) {
        firstBracketIndex = squareBracketIndex;
      } else if (squareBracketIndex == -1 && bracketIndex != -1) {
        firstBracketIndex = bracketIndex;
      } else if (bracketIndex != -1 && squareBracketIndex != -1) {
        firstBracketIndex = min(bracketIndex, squareBracketIndex);
      }
      if (firstBracketIndex > 0) {
        mainTitle = _title.substring(0, firstBracketIndex).trim();
        parenthetical = _title.substring(firstBracketIndex);
      }
    } else {
      int bracketIndex = _title.indexOf('(');
      int squareBracketIndex = _title.indexOf('[');
      int firstBracketIndex = -1;
      if (bracketIndex == -1 && squareBracketIndex != -1) {
        firstBracketIndex = squareBracketIndex;
      } else if (squareBracketIndex == -1 && bracketIndex != -1) {
        firstBracketIndex = bracketIndex;
      } else if (bracketIndex != -1 && squareBracketIndex != -1) {
        firstBracketIndex = min(bracketIndex, squareBracketIndex);
      }
      if (firstBracketIndex > 0) {
        mainTitle = _title.substring(0, firstBracketIndex).trim();
      }
    }
    final statusText = _isPlaying
        ? AppLocalizations.of(context).nowPlaying
        : AppLocalizations.of(context).buffering;
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        final currentColor = _colorAnimation.value ?? _backgroundColor;
        final luminance = currentColor.computeLuminance();
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: currentColor,
            statusBarBrightness:
                luminance < 0.5 ? Brightness.light : Brightness.dark,
          ),
        );
        return Scaffold(
          backgroundColor: currentColor,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              OrientationBuilder(
                builder: (context, orientation) {
                  return Stack(
                    children: [
                      if (orientation == Orientation.landscape)
                        SizedBox.expand(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 60),
                                      child: SizedBox(
                                        width: 150,
                                        child: Image.asset(
                                          'assets/logovtrnk.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    if (_settings.showEqualizer)
                                      SizedBox(
                                        height: 40,
                                        width: 150,
                                        child: AnimatedBuilder(
                                          animation: _controller,
                                          builder: (context, child) {
                                            return CustomPaint(
                                              painter: EqualizerPainter(
                                                progress: _controller.value,
                                                barCount: barCount,
                                                randomOffsets: _randomOffsets,
                                                randomMultipliers:
                                                    _randomMultipliers,
                                                randomSpeeds: _randomSpeeds,
                                                isPlaying: _isPlaying,
                                                barWidth: 9.0,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    const SizedBox(height: 40),
                                    Center(
                                      child: AnimatedBuilder(
                                        animation: _buttonScaleAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _buttonScaleAnimation.value,
                                            child: SizedBox(
                                              width: 105,
                                              height: 52.5,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF808080),
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                  ),
                                                ),
                                                onPressed: _togglePlayPause,
                                                child: Icon(
                                                  _isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 320.0,
                                        maxWidth: 320.0,
                                      ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1a1a1a),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(8)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(8)),
                                          child: _buildCoverWidget(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20, right: 20),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 60),
                                          Text(
                                            statusText,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(height: 15),
                                          Text(
                                            _artist,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18),
                                            textAlign: TextAlign.left,
                                          ),
                                          const SizedBox(height: 12),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                mainTitle,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16),
                                                textAlign: TextAlign.left,
                                              ),
                                              if (parenthetical != null &&
                                                  _settings
                                                      .showExtendedTrackInfo)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4.0),
                                                  child: Text(
                                                    parenthetical,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14),
                                                    textAlign: TextAlign.left,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 30),
                                        child: const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Developed by',
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 16),
                                            ),
                                            Text(
                                              'Beasty Beats 2025',
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Center(
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 60),
                                    child: SizedBox(
                                      width: 200,
                                      child: Image.asset(
                                        'assets/logovtrnk.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  if (_settings.showEqualizer)
                                    SizedBox(
                                      height: 40,
                                      width: 200,
                                      child: AnimatedBuilder(
                                        animation: _controller,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            painter: EqualizerPainter(
                                              progress: _controller.value,
                                              barCount: barCount,
                                              randomOffsets: _randomOffsets,
                                              randomMultipliers:
                                                  _randomMultipliers,
                                              randomSpeeds: _randomSpeeds,
                                              isPlaying: _isPlaying,
                                              barWidth: 12.0,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  const SizedBox(height: 15),
                                  Text(
                                    statusText,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    _artist,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        mainTitle,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (parenthetical != null &&
                                          _settings.showExtendedTrackInfo)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            parenthetical,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 320,
                                    height: 320,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1a1a1a),
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(8)),
                                      child: _buildCoverWidget(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  AnimatedBuilder(
                                    animation: _buttonScaleAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _buttonScaleAnimation.value,
                                        child: SizedBox(
                                          width: 105,
                                          height: 52.5,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF808080),
                                              shape:
                                                  const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.zero,
                                              ),
                                            ),
                                            onPressed: _togglePlayPause,
                                            child: Icon(
                                              _isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Developed by Beasty Beats 2025',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 30,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 36,
                          ),
                          onPressed: _toggleMenu,
                        ),
                      ),
                      if (_isMenuOpen)
                        Positioned(
                          top: orientation == Orientation.landscape ? 70 : 70,
                          right: 10,
                          child: AnimatedBuilder(
                            animation: _menuController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _menuOpacityAnimation.value,
                                child: Transform.translate(
                                  offset: _menuOffsetAnimation.value,
                                  child: Container(
                                    width: orientation == Orientation.landscape
                                        ? 180
                                        : 195,
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              0.7,
                                    ),
                                    color: const Color(0xFF1a1a1a),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 0),
                                    child: ListView(
                                      shrinkWrap: true,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      children: [
                                        _buildMenuItem(
                                          0,
                                          () => _launchURL(
                                              'https://t.me/vtornikshow'),
                                          AppLocalizations.of(context).telegram,
                                          const Color(0xFF00aced),
                                        ),
                                        _buildMenuItem(
                                          1,
                                          () => _launchURL(
                                              'https://t.me/beastybeats23'),
                                          AppLocalizations.of(context).chat,
                                          const Color(0xFF00aced),
                                        ),
                                        _buildMenuItem(
                                          2,
                                          () => _launchURL(
                                              'https://vtrnk.online/stream.html'),
                                          AppLocalizations.of(context)
                                              .videoStream,
                                          const Color(0xFF00aced),
                                        ),
                                        _buildMenuItem(
                                          3,
                                          _showSettingsDialog,
                                          AppLocalizations.of(context).settings,
                                          const Color(0xFF00aced),
                                        ),
                                        _buildMenuItem(
                                          4,
                                          () => _launchURL(
                                              'https://beasty177.github.io/vtrnk-radio/privacy_policy.html'),
                                          AppLocalizations.of(context)
                                              .privacyPolicy,
                                          const Color(0xFF00aced),
                                        ),
                                        _buildMenuItem(
                                          5,
                                          () => _showLanguageDialog(),
                                          '🇬🇧 🇷🇺 🇪🇸 🇫🇷 🇮🇱',
                                          const Color(0xFF00aced),
                                        ),
                                        _buildMenuItem(
                                          6,
                                          _toggleMenu,
                                          AppLocalizations.of(context).close,
                                          Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
      int index, VoidCallback callback, String text, Color color) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        splashColor: const Color(0xFF333333),
        onTapDown: (_) => _menuItemControllers[index].forward(),
        onTapCancel: () => _menuItemControllers[index].reverse(),
        onTap: () => _onMenuItemTap(index, callback),
        child: AnimatedBuilder(
          animation: _menuItemScaleAnimations[index],
          builder: (context, child) {
            return Transform.scale(
              scale: _menuItemScaleAnimations[index].value,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  text,
                  style: TextStyle(color: color, fontSize: 18),
                  textAlign: TextAlign.end,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EqualizerPainter extends CustomPainter {
  final double progress;
  final int barCount;
  final List<double> randomOffsets;
  final List<double> randomMultipliers;
  final List<double> randomSpeeds;
  final bool isPlaying;
  final double barWidth;
  final double gap;
  final double maxHeight;

  EqualizerPainter({
    required this.progress,
    required this.barCount,
    required this.randomOffsets,
    required this.randomMultipliers,
    required this.randomSpeeds,
    required this.isPlaying,
    this.barWidth = 9.0,
    this.gap = 1.0,
    this.maxHeight = 40.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    double totalWidth = barCount * barWidth + (barCount - 1) * gap;
    double startX = (size.width - totalWidth) / 2;
    for (int i = 0; i < barCount; i++) {
      double phase = progress * 2 * pi * randomSpeeds[i] + randomOffsets[i];
      double heightFactor = (sin(phase) + 1) / 2;
      double barHeight = isPlaying
          ? 5 + (maxHeight - 5) * heightFactor * randomMultipliers[i]
          : 5.0;
      double x = startX + i * (barWidth + gap);
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EqualizerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.randomOffsets != randomOffsets ||
        oldDelegate.randomMultipliers != randomMultipliers ||
        oldDelegate.randomSpeeds != randomSpeeds;
  }
}

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  static final _player = AudioPlayer();
  io.Socket? _socket;
  String _artist = "VTRNK";
  String _title = "Stream";
  String _coverUrl = 'assets/vt-videoplaceholder.png';
  int _retryCount = 0;
  static const int maxRetries = 3;

  AudioPlayerHandler() {
    try {
      debugPrint('AudioHandler constructor start');
      _player.playbackEventStream.map(_transformEvent).listen((event) {
        playbackState.add(event);
      });
      _player.setLoopMode(LoopMode.off);
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          debugPrint("Stream completed unexpectedly - reconnecting");
          reloadStream();
          _player.play();
        } else if (state == ProcessingState.buffering) {
          updateMediaMetadata(title: "Buffering...");
        }
      });
      _initWebSocket();
      _fetchTrackInfo();
      _loadInitialTrack();
      debugPrint('AudioHandler constructor success');
    } catch (e) {
      debugPrint('AudioHandler constructor error: $e');
      updateMediaMetadata(title: "Audio error: $e");
    }
  }

  Future<void> _loadInitialTrack() async {
    await reloadStream();
  }

  Future<void> reloadStream() async {
    try {
      final settings = await AppSettings.loadFromPrefs();
      int bracketIndex = _title.indexOf('(');
      int squareBracketIndex = _title.indexOf('[');
      int firstBracketIndex = -1;

      if (bracketIndex == -1 && squareBracketIndex != -1) {
        firstBracketIndex = squareBracketIndex;
      } else if (squareBracketIndex == -1 && bracketIndex != -1) {
        firstBracketIndex = bracketIndex;
      } else if (bracketIndex != -1 && squareBracketIndex != -1) {
        firstBracketIndex = min(bracketIndex, squareBracketIndex);
      }

      final title = settings.showExtendedTrackInfo
          ? _title
          : firstBracketIndex > 0
              ? _title.substring(0, firstBracketIndex).trim()
              : _title;
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse('https://vtrnk.online/radio_stream'),
          tag: MediaItem(
            id: '1',
            album: 'VTRNK Radio',
            title: title,
            artist: _artist,
            artUri: Uri.parse(_coverUrl),
            duration: null,
          ),
        ),
      );
      debugPrint(
          "Stream source reloaded with title=$title, artist=$_artist, cover=$_coverUrl");
      _retryCount = 0;
    } catch (e) {
      debugPrint("Stream reload error: $e");
      updateMediaMetadata(title: "Connection error");
      if (_retryCount < maxRetries) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 5));
        await reloadStream();
      } else {
        debugPrint("Max retries reached for stream reload");
        updateMediaMetadata(title: "Failed to connect to stream");
      }
    }
  }

  void loadCover() {
    debugPrint('loadCover triggered');
    _fetchCoverUrl();
  }

  Future<void> fetchTrackInfo() async {
    await _fetchTrackInfo();
  }

  void _initWebSocket() {
    try {
      debugPrint('WebSocket init start');
      _socket = io.io(
        'https://vtrnk.online',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build(),
      );
      _socket!.onConnect((_) {
        debugPrint('WebSocket connected');
        _retryCount = 0;
        _fetchTrackInfo();
      });
      _socket!.on('track_update', (data) async {
        debugPrint("Received track_update: $data");
        if (data is Map && !isVideoStreamActive(data)) {
          _artist = data['artist']?.toString() ?? _artist;
          _title = data['title']?.toString() ?? _title;
          await _fetchCoverUrl();
          final settings = await AppSettings.loadFromPrefs();
          updateMediaMetadata(settings: settings);
        }
      });
      _socket!.onDisconnect((_) {
        debugPrint('WebSocket disconnected');
        if (_retryCount < maxRetries) {
          _retryCount++;
          Future.delayed(const Duration(seconds: 5), () => _initWebSocket());
        }
      });
      debugPrint('WebSocket init success');
    } catch (e) {
      debugPrint('WebSocket init error: $e');
      if (_retryCount < maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 5), () => _initWebSocket());
      }
    }
  }

  bool isVideoStreamActive(Map data) {
    return data['video_stream_active'] == true;
  }

  Future<void> _fetchTrackInfo() async {
    try {
      debugPrint('FetchTrack start');
      final response = await http
          .get(Uri.parse('https://vtrnk.online/track'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final trackData = {for (var item in data) item[0]: item[1]};
        _artist = trackData['artist']?.toString() ?? _artist;
        _title = trackData['title']?.toString() ?? _title;
        debugPrint('Track info updated: title=$_title, artist=$_artist');
        await _fetchCoverUrl();
        final settings = await AppSettings.loadFromPrefs();
        updateMediaMetadata(settings: settings);
      } else {
        debugPrint("Track fetch error: ${response.statusCode}");
        updateMediaMetadata(title: "Track fetch error");
      }
    } catch (e) {
      debugPrint("Error fetching track data: $e");
      updateMediaMetadata(title: "Connection error");
      if (_retryCount < maxRetries) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 5));
        await _fetchTrackInfo();
      }
    }
  }

  Future<void> _fetchCoverUrl() async {
    try {
      debugPrint(
          'FetchCover start: requesting https://vtrnk.online/get_cover_path');
      final coverResponse = await http
          .get(Uri.parse('https://vtrnk.online/get_cover_path'))
          .timeout(const Duration(seconds: 10));
      debugPrint(
          "FetchCover response: status=${coverResponse.statusCode}, body=${coverResponse.body}");
      if (coverResponse.statusCode == 200) {
        final coverData =
            jsonDecode(coverResponse.body) as Map<String, dynamic>;
        final newCoverUrl =
            'https://vtrnk.online${coverData['cover_path'] ?? '/assets/vt-videoplaceholder.png'}';
        debugPrint("Cover updated: $newCoverUrl");
        _coverUrl = newCoverUrl;
        final settings = await AppSettings.loadFromPrefs();
        updateMediaMetadata(settings: settings);
      } else {
        debugPrint("Cover fetch error: ${coverResponse.statusCode}");
        updateMediaMetadata(title: "Cover fetch error");
      }
    } catch (e) {
      debugPrint("Error fetching cover: $e");
      updateMediaMetadata(title: "Error fetching cover");
      if (_retryCount < maxRetries) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 5));
        await _fetchCoverUrl();
      }
    }
  }

  void updateMediaMetadata({String? title, AppSettings? settings}) {
    final effectiveTitle = title ?? _title;
    int bracketIndex = effectiveTitle.indexOf('(');
    int squareBracketIndex = effectiveTitle.indexOf('[');
    int firstBracketIndex = -1;

    if (bracketIndex == -1 && squareBracketIndex != -1) {
      firstBracketIndex = squareBracketIndex;
    } else if (squareBracketIndex == -1 && bracketIndex != -1) {
      firstBracketIndex = bracketIndex;
    } else if (bracketIndex != -1 && squareBracketIndex != -1) {
      firstBracketIndex = min(bracketIndex, squareBracketIndex);
    }

    final displayTitle = settings != null && settings.showExtendedTrackInfo
        ? effectiveTitle
        : firstBracketIndex > 0
            ? effectiveTitle.substring(0, firstBracketIndex).trim()
            : effectiveTitle;
    final newItem = MediaItem(
      id: '1',
      album: 'VTRNK Radio',
      title: displayTitle,
      artist: _artist,
      artUri: Uri.parse(_coverUrl),
      duration: null,
    );
    debugPrint(
        "Updating MediaItem: title=${newItem.title}, artist=${newItem.artist}, cover=${newItem.artUri}");
    mediaItem.add(newItem);
  }

  // ignore: deprecated_member_use
  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    try {
      debugPrint(
          "Updating MediaItem for notifications: title=${mediaItem.title}, artist=${mediaItem.artist}, cover=${mediaItem.artUri}");
      await updateQueue([mediaItem]);
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
          playing: _player.playing,
        ),
      );
      await AudioService.updateMediaItem(mediaItem);
      debugPrint(
          "Notifications updated: title=${mediaItem.title}, artist=${mediaItem.artist}, cover=${mediaItem.artUri}");
    } catch (e) {
      debugPrint("Error updating MediaItem: $e");
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
      ],
      systemActions: {MediaAction.seek},
      androidCompactActionIndices: const [0],
      processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState] ??
          AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex ?? 0,
    );
  }

  @override
  Future<void> play() async {
    try {
      if (!_player.playing) {
        await reloadStream();
      }
      await _player.play();
    } catch (e) {
      debugPrint("Playback error: $e");
      updateMediaMetadata(title: "Playback error");
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint("Pause error: $e");
    }
  }

  @override
  Future<void> stop() async {
    try {
      _socket?.disconnect();
      await _player.stop();
    } catch (e) {
      debugPrint("Stop error: $e");
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint("Seek error: $e");
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {}
}
