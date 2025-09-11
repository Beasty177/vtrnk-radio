import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.example.radio_app_new.channel.audio',
        androidNotificationChannelName: 'VTRNK Radio Playback',
        androidNotificationChannelDescription:
            'VTRNK Radio audio playback controls',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidStopForegroundOnPause: true,
      );
      runApp(const MyApp());
    },
    (error, stackTrace) {
      print('Unhandled error in main: $error');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _localeNotifier = ValueNotifier<Locale>(const Locale('ru'));

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString('locale') ?? 'ru';
    _localeNotifier.value = Locale(locale);
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
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('ru', ''),
            Locale('he', ''),
          ],
          home: MyHomePage(onLocaleChange: _setLocale),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final void Function(String) onLocaleChange;

  const MyHomePage({super.key, required this.onLocaleChange});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
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
  late AudioPlayerHandler _audioHandler;
  bool _isPlaying = false;
  String _artist = "Ожидание исполнителя...";
  String _title = "Ожидание трека...";
  String _coverUrl = 'asset:///assets/vt-videoplaceholder.png';
  Color _backgroundColor = Colors.black;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _randomOffsets = List.generate(
      barCount,
      (_) => _random.nextDouble() * pi * 2,
    );
    _randomMultipliers = List.generate(
      barCount,
      (_) => _random.nextDouble() * 0.8 + 0.2,
    );
    _randomSpeeds = List.generate(
      barCount,
      (_) => 0.8 + _random.nextDouble() * 0.7,
    );
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed ||
              status == AnimationStatus.dismissed) {
            setState(() {
              _randomOffsets = List.generate(
                barCount,
                (_) => _random.nextDouble() * pi * 2,
              );
              _randomMultipliers = List.generate(
                barCount,
                (_) => _random.nextDouble() * 0.8 + 0.2,
              );
              _randomSpeeds = List.generate(
                barCount,
                (_) => 0.8 + _random.nextDouble() * 0.7,
              );
            });
          }
        });
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _colorAnimation = ColorTween(begin: _backgroundColor, end: _backgroundColor)
        .animate(
          CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
        );
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
    );
    _menuOffsetAnimation =
        Tween<Offset>(
          begin: const Offset(0.2, 0.0),
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
      6,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
      ),
    );
    _menuItemScaleAnimations = _menuItemControllers
        .map(
          (controller) => Tween<double>(begin: 1.0, end: 0.95).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          ),
        )
        .toList();
    _initAll();
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
          content: Column(
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
        );
      },
    );
  }

  Future<void> _initAll() async {
    try {
      await _initAudioPlayer();
      _audioHandler.playbackState.listen((playbackState) {
        if (mounted) {
          setState(() {
            _isPlaying = playbackState.playing;
            if (_isPlaying) {
              _controller.repeat(reverse: true);
            } else {
              _controller.stop();
              _controller.reset();
            }
          });
        }
      });
      _audioHandler.mediaItem.listen((MediaItem? item) {
        if (mounted && item != null) {
          setState(() {
            _artist = item.artist ?? "VTRNK";
            _title = item.title;
            _coverUrl =
                item.artUri?.toString() ??
                'asset:///assets/vt-videoplaceholder.png';
          });
          _updateBackgroundColor();
        }
      });
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка инициализации: $e';
        });
      }
    }
  }

  Future<void> _initAudioPlayer() async {
    _audioHandler = AudioPlayerHandler();
  }

  Future<void> _updateBackgroundColor() async {
    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(_coverUrl),
        maximumColorCount: 10,
      );
      if (mounted) {
        final newColor = palette.dominantColor?.color ?? Colors.black;
        final luminance = newColor.computeLuminance();
        final targetColor = Color.fromRGBO(
          newColor.red,
          newColor.green,
          newColor.blue,
          0.5,
        ).withOpacity(luminance > 0.5 ? 0.8 : 1.0);
        setState(() {
          _colorAnimation =
              ColorTween(begin: _backgroundColor, end: targetColor).animate(
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
      print("Ошибка при извлечении цвета: $e");
      await Future.delayed(const Duration(seconds: 5));
      await _updateBackgroundColor();
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      HapticFeedback.lightImpact();
      _buttonController.forward().then((_) => _buttonController.reverse());
      if (_isPlaying) {
        await _audioHandler.pause();
      } else {
        await _audioHandler.play();
      }
    } catch (e) {
      print("Ошибка при переключении: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _colorController.dispose();
    _menuController.dispose();
    _buttonController.dispose();
    for (var controller in _menuItemControllers) {
      controller.dispose();
    }
    _audioHandler.stop();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      HapticFeedback.lightImpact();
      if (_isMenuOpen) {
        _menuController.forward();
      } else {
        _menuController.reverse();
      }
    });
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: url.startsWith('https://t.me')
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
      } else {
        print("Не удалось открыть URL: $url - приложение не найдено");
      }
    } catch (e) {
      print("Ошибка при открытии URL: $url - $e");
    }
  }

  void _onMenuItemTap(int index, VoidCallback callback) {
    HapticFeedback.lightImpact();
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
          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    String mainTitle = _title;
    String? parenthetical;
    final match = RegExp(r'^(.*?)(?:\s*\((.*?)\))?$').firstMatch(_title);
    if (match != null) {
      mainTitle = match.group(1)?.trim() ?? _title;
      parenthetical = match.group(2);
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
            statusBarBrightness: luminance < 0.5
                ? Brightness.light
                : Brightness.dark,
          ),
        );
        return Scaffold(
          backgroundColor: currentColor,
          body: Stack(
            children: [
              OrientationBuilder(
                builder: (context, orientation) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  const coverSize = 320.0;
                  return Stack(
                    children: [
                      if (orientation == Orientation.landscape)
                        Row(
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
                                                backgroundColor: const Color(
                                                  0xFF808080,
                                                ),
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
                                      maxHeight: coverSize,
                                      maxWidth: coverSize,
                                    ),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF1a1a1a),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: _coverUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) =>
                                              Image.asset(
                                                'assets/vt-videoplaceholder.png',
                                                fit: BoxFit.cover,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        Text(
                                          _artist,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
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
                                                fontSize: 16,
                                              ),
                                              textAlign: TextAlign.left,
                                            ),
                                            if (parenthetical != null)
                                              Text(
                                                '($parenthetical)',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                                textAlign: TextAlign.left,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 30,
                                      ),
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Developed by',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Beasty Beats 2025',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    _artist,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        mainTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (parenthetical != null)
                                        Text(
                                          '($parenthetical)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 320,
                                    height: 320,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1a1a1a),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: _coverUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            Image.asset(
                                              'assets/vt-videoplaceholder.png',
                                              fit: BoxFit.cover,
                                            ),
                                      ),
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
                                              backgroundColor: const Color(
                                                0xFF808080,
                                              ),
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
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Developed by Beasty Beats 2025',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
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
                          top: orientation == Orientation.landscape ? 80 : 70,
                          right: 10,
                          child: AnimatedBuilder(
                            animation: _menuController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _menuOpacityAnimation.value,
                                child: Transform.translate(
                                  offset: _menuOffsetAnimation.value,
                                  child: Container(
                                    width: 195,
                                    color: const Color(0xFF1a1a1a),
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            splashColor: const Color(
                                              0xFF333333,
                                            ),
                                            onTapDown: (_) =>
                                                _menuItemControllers[0]
                                                    .forward(),
                                            onTapCancel: () =>
                                                _menuItemControllers[0]
                                                    .reverse(),
                                            onTap: () => _onMenuItemTap(
                                              0,
                                              () => _launchURL(
                                                'https://t.me/vtornikshow',
                                              ),
                                            ),
                                            child: AnimatedBuilder(
                                              animation:
                                                  _menuItemScaleAnimations[0],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      _menuItemScaleAnimations[0]
                                                          .value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      ).telegram,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF00aced,
                                                        ),
                                                        fontSize: 18,
                                                      ),
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            splashColor: const Color(
                                              0xFF333333,
                                            ),
                                            onTapDown: (_) =>
                                                _menuItemControllers[1]
                                                    .forward(),
                                            onTapCancel: () =>
                                                _menuItemControllers[1]
                                                    .reverse(),
                                            onTap: () => _onMenuItemTap(
                                              1,
                                              () => _launchURL(
                                                'https://t.me/beastybeats23',
                                              ),
                                            ),
                                            child: AnimatedBuilder(
                                              animation:
                                                  _menuItemScaleAnimations[1],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      _menuItemScaleAnimations[1]
                                                          .value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      ).chat,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF00aced,
                                                        ),
                                                        fontSize: 18,
                                                      ),
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            splashColor: const Color(
                                              0xFF333333,
                                            ),
                                            onTapDown: (_) =>
                                                _menuItemControllers[2]
                                                    .forward(),
                                            onTapCancel: () =>
                                                _menuItemControllers[2]
                                                    .reverse(),
                                            onTap: () => _onMenuItemTap(
                                              2,
                                              () => _launchURL(
                                                'https://vtrnk.online/stream.html',
                                              ),
                                            ),
                                            child: AnimatedBuilder(
                                              animation:
                                                  _menuItemScaleAnimations[2],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      _menuItemScaleAnimations[2]
                                                          .value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      ).videoStream,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF00aced,
                                                        ),
                                                        fontSize: 18,
                                                      ),
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            splashColor: const Color(
                                              0xFF333333,
                                            ),
                                            onTapDown: (_) =>
                                                _menuItemControllers[3]
                                                    .forward(),
                                            onTapCancel: () =>
                                                _menuItemControllers[3]
                                                    .reverse(),
                                            onTap: () => _onMenuItemTap(
                                              3,
                                              () => print("Настройки pressed"),
                                            ),
                                            child: AnimatedBuilder(
                                              animation:
                                                  _menuItemScaleAnimations[3],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      _menuItemScaleAnimations[3]
                                                          .value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      ).settings,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF00aced,
                                                        ),
                                                        fontSize: 18,
                                                      ),
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            splashColor: const Color(
                                              0xFF333333,
                                            ),
                                            onTapDown: (_) =>
                                                _menuItemControllers[4]
                                                    .forward(),
                                            onTapCancel: () =>
                                                _menuItemControllers[4]
                                                    .reverse(),
                                            onTap: () => _onMenuItemTap(
                                              4,
                                              () => _showLanguageDialog(),
                                            ),
                                            child: AnimatedBuilder(
                                              animation:
                                                  _menuItemScaleAnimations[4],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      _menuItemScaleAnimations[4]
                                                          .value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: const Text(
                                                      '🇬🇧 🇷🇺 🇮🇱',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF00aced,
                                                        ),
                                                        fontSize: 18,
                                                      ),
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            splashColor: const Color(
                                              0xFF333333,
                                            ),
                                            onTapDown: (_) =>
                                                _menuItemControllers[5]
                                                    .forward(),
                                            onTapCancel: () =>
                                                _menuItemControllers[5]
                                                    .reverse(),
                                            onTap: () =>
                                                _onMenuItemTap(5, _toggleMenu),
                                            child: AnimatedBuilder(
                                              animation:
                                                  _menuItemScaleAnimations[5],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      _menuItemScaleAnimations[5]
                                                          .value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      ).close,
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 18,
                                                      ),
                                                      textAlign: TextAlign.end,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
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
  late IO.Socket _socket;
  String _artist = "VTRNK";
  String _title = "Stream";
  String _coverUrl = 'asset:///assets/vt-videoplaceholder.png';
  String? _currentStreamTitle;

  AudioPlayerHandler() {
    _player.playbackEventStream.map(_transformEvent).listen((event) {
      playbackState.add(event);
    });
    _player.setLoopMode(LoopMode.off);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print("Stream completed unexpectedly - reconnecting");
        reloadStream();
        _player.play();
      } else if (state == ProcessingState.buffering) {
        _updateMediaMetadata(title: "Buffering...");
      }
    });
    _loadInitialTrack();
    _initWebSocket();
  }

  Future<void> _loadInitialTrack() async {
    await reloadStream();
  }

  Future<void> reloadStream() async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse('https://vtrnk.online/radio_stream'),
          tag: MediaItem(
            id: '1',
            album: 'VTRNK Radio',
            title: 'VTRNK Radio',
            artist: 'Stream',
            artUri: Uri.parse('asset:///assets/vt-videoplaceholder.png'),
            duration: null,
          ),
        ),
      );
      print("Stream source reloaded");
    } catch (e) {
      print("Ошибка перезагрузки стрима: $e");
      _updateMediaMetadata(title: "Ошибка подключения");
    }
  }

  void _initWebSocket() {
    _socket = IO.io(
      'https://vtrnk.online',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );
    _socket.onConnect((_) {
      print('WebSocket подключён');
      _fetchTrackInfo();
    });
    _socket.on('track_update', (data) {
      print("Получено track_update: $data");
      if (data is Map && !isVideoStreamActive(data)) {
        _artist = data['artist']?.toString() ?? _artist;
        _title = data['title']?.toString() ?? "Stream";
        _fetchCoverUrl();
      }
    });
    _socket.onDisconnect((_) => print('WebSocket отключён'));
  }

  bool isVideoStreamActive(Map data) {
    return data['video_stream_active'] == true;
  }

  Future<void> _fetchTrackInfo() async {
    try {
      final response = await http
          .get(Uri.parse('https://vtrnk.online/track'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final trackData = {for (var item in data) item[0]: item[1]};
        _artist = trackData['artist']?.toString() ?? "VTRNK";
        _title = trackData['title']?.toString() ?? "Stream";
        await _fetchCoverUrl();
        _updateMediaMetadata();
      } else {
        print("Ошибка получения трека: ${response.statusCode}");
        _updateMediaMetadata(title: "Ошибка получения трека");
      }
    } catch (e) {
      print("Ошибка при запросе данных: $e");
      _updateMediaMetadata(title: "Ошибка подключения");
      await Future.delayed(const Duration(seconds: 5));
      await _fetchTrackInfo();
    }
  }

  Future<void> _fetchCoverUrl() async {
    try {
      final coverResponse = await http
          .get(Uri.parse('https://vtrnk.online/get_cover_path'))
          .timeout(const Duration(seconds: 10));
      print("Ответ от /get_cover_path: ${coverResponse.body}");
      if (coverResponse.statusCode == 200) {
        final coverData =
            jsonDecode(coverResponse.body) as Map<String, dynamic>;
        _coverUrl =
            'https://vtrnk.online${coverData['cover_path'] ?? '/assets/vt-videoplaceholder.png'}';
        print("Обложка обновлена: $_coverUrl");
        _updateMediaMetadata();
      } else {
        print("Ошибка получения обложки: ${coverResponse.statusCode}");
        _updateMediaMetadata();
      }
    } catch (e) {
      print("Ошибка при запросе обложки: $e");
      _updateMediaMetadata();
      await Future.delayed(const Duration(seconds: 5));
      await _fetchCoverUrl();
    }
  }

  void _updateMediaMetadata({String? title}) {
    final newItem = MediaItem(
      id: '1',
      album: 'VTRNK Radio',
      title: title ?? _title,
      artist: _artist,
      artUri: Uri.parse(_coverUrl),
      duration: null,
    );
    print(
      "Обновление MediaItem: title=${newItem.title}, artist=${newItem.artist}, cover=${newItem.artUri}",
    );
    updateMediaItem(newItem);
  }

  Future<void> updateMediaItem(MediaItem item) async {
    try {
      print(
        "Updating MediaItem: title=${item.title}, artist=${item.artist}, cover=${item.artUri}",
      );
      mediaItem.add(item);
      await updateQueue([item]);
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
          playing: _player.playing,
        ),
      );
      await AudioService.updateMediaItem(item);
      print(
        "Уведомления обновлены: title=${item.title}, artist=${item.artist}, cover=${item.artUri}",
      );
    } catch (e) {
      print("Ошибка обновления MediaItem: $e");
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
      ],
      systemActions: {MediaAction.seek},
      androidCompactActionIndices: const [0],
      processingState:
          {
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
      print("Ошибка воспроизведения: $e");
      _updateMediaMetadata(title: "Ошибка воспроизведения");
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      print("Ошибка паузы: $e");
    }
  }

  @override
  Future<void> stop() async {
    try {
      _socket.disconnect();
      await _player.stop();
    } catch (e) {
      print("Ошибка остановки: $e");
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print("Ошибка seek: $e");
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {}
}
