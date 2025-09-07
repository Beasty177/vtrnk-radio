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

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.radio_app_new.channel.audio',
      androidNotificationChannelName: 'VTRNK Radio Playback',
      androidNotificationChannelDescription: 'VTRNK Radio audio playback controls',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidStopForegroundOnPause: true,
    );
    runApp(const MyApp());
  }, (error, stackTrace) {
    print('Unhandled error in main: $error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VTRNK Radio',
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
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
  late List<Animation<double>> _animations;
  late List<double> _delays;
  late List<double> _randomMultipliers;
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
  String _statusText = "Сейчас в эфире";

  @override
  void initState() {
    super.initState();
    _delays = List.generate(barCount, (_) => _random.nextDouble());
    _randomMultipliers = List.generate(barCount, (_) => _random.nextDouble() * 0.8 + 0.2);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _isPlaying) {
          setState(() {
            _randomMultipliers = List.generate(barCount, (_) => _random.nextDouble() * 0.8 + 0.2);
          });
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed && _isPlaying) {
          _controller.forward();
        }
      });
    _animations = List.generate(barCount, (index) {
      double delay = _delays[index] * 0.8;
      double range = 0.3 + _random.nextDouble() * 0.4;
      if (delay + range > 1.0) range = 1.0 - delay;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(delay, delay + range, curve: Curves.easeInOutSine),
        ),
      );
    });
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _colorAnimation = ColorTween(
      begin: _backgroundColor,
      end: _backgroundColor,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOut,
    ));
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
    );
    _menuOffsetAnimation = Tween<Offset>(
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
    // Инициализация контроллеров для каждого пункта меню
    _menuItemControllers = List.generate(
      6,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
      ),
    );
    _menuItemScaleAnimations = _menuItemControllers
        .map((controller) => Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeInOut),
            ))
        .toList();
    _initAll();
  }

  Future<void> _initAll() async {
    try {
      await _initAudioPlayer();
      _audioHandler.playbackState.listen((playbackState) {
        if (mounted) {
          setState(() {
            _isPlaying = playbackState.playing;
            _statusText = playbackState.processingState == ProcessingState.buffering
                ? "Загрузка аудио..."
                : "Сейчас в эфире";
            if (_isPlaying) {
              _controller.forward(from: 0.0);
            } else {
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
            _coverUrl = item.artUri?.toString() ?? 'asset:///assets/vt-videoplaceholder.png';
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
          _colorAnimation = ColorTween(
            begin: _backgroundColor,
            end: targetColor,
          ).animate(CurvedAnimation(
            parent: _colorController,
            curve: Curves.easeInOut,
          ));
          _backgroundColor = targetColor;
        });
        _colorController.forward(from: 0.0);
      }
    } catch (e) {
      print("Ошибка при извлечении цвета: $e");
      await Future.delayed(Duration(seconds: 5));
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
        await launchUrl(uri, mode: url.startsWith('https://t.me') ? LaunchMode.externalApplication : LaunchMode.platformDefault);
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
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red))),
      );
    }
    String mainTitle = _title;
    String? parenthetical;
    final match = RegExp(r'^(.*?)(?:\s*\((.*?)\))?$').firstMatch(_title);
    if (match != null) {
      mainTitle = match.group(1)?.trim() ?? _title;
      parenthetical = match.group(2);
    }
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        final currentColor = _colorAnimation.value ?? _backgroundColor;
        final luminance = currentColor.computeLuminance();
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: currentColor,
          statusBarBrightness: luminance < 0.5 ? Brightness.light : Brightness.dark,
        ));
        return Scaffold(
          backgroundColor: currentColor,
          body: Stack(
            children: [
              OrientationBuilder(
                builder: (context, orientation) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final coverSize = 320.0;
                  return Stack(
                    children: [
                      if (orientation == Orientation.landscape)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Левая часть: логотип + эквалайзер + кнопка
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 60),
                                    child: SizedBox(
                                      width: 150,
                                      child: Image.asset('assets/logovtrnk.png', fit: BoxFit.contain),
                                    ),
                                  ),
                                  SizedBox(height: 30),
                                  SizedBox(
                                    height: 40,
                                    child: AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(barCount, (index) {
                                            return Container(
                                              width: (150 / barCount) - 2,
                                              height: _isPlaying ? (5 + 35 * _animations[index].value * _randomMultipliers[index]).toDouble() : 5.0,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              color: Color(0xFFd3d3d3),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 40),
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
                                                backgroundColor: Color(0xFF808080),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                              ),
                                              onPressed: _togglePlayPause,
                                              child: Icon(
                                                _isPlaying ? Icons.pause : Icons.play_arrow,
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
                            // Центр: обложка
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: coverSize, maxWidth: coverSize),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Color(0xFF1a1a1a),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: _coverUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) => Image.asset(
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
                            // Правая часть: текст + надпись разработчика
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: 20, right: 20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 60),
                                        Text(_statusText, style: TextStyle(color: Colors.white, fontSize: 16)),
                                        SizedBox(height: 15),
                                        Text(_artist, style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.left),
                                        SizedBox(height: 12),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mainTitle,
                                              style: TextStyle(color: Colors.white, fontSize: 16),
                                              textAlign: TextAlign.left,
                                            ),
                                            if (parenthetical != null)
                                              Text(
                                                '($parenthetical)',
                                                style: TextStyle(color: Colors.white, fontSize: 14),
                                                textAlign: TextAlign.left,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 30),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Developed by', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                                          Text('Beasty Beats 2025', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
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
                        // Portrait layout
                        Center(
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 320),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 60),
                                    child: SizedBox(
                                      width: 200,
                                      child: Image.asset('assets/logovtrnk.png', fit: BoxFit.contain),
                                    ),
                                  ),
                                  SizedBox(height: 30),
                                  SizedBox(
                                    height: 40,
                                    child: AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(barCount, (index) {
                                            return Container(
                                              width: (200 / barCount) - 2,
                                              height: _isPlaying ? (5 + 35 * _animations[index].value * _randomMultipliers[index]).toDouble() : 5.0,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              color: Color(0xFFd3d3d3),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 15),
                                  Text(_statusText, style: TextStyle(color: Colors.white, fontSize: 16)),
                                  SizedBox(height: 15),
                                  Text(_artist, style: TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
                                  SizedBox(height: 12),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        mainTitle,
                                        style: TextStyle(color: Colors.white, fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (parenthetical != null)
                                        Text(
                                          '($parenthetical)',
                                          style: TextStyle(color: Colors.white, fontSize: 14),
                                          textAlign: TextAlign.center,
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Container(
                                    width: 320,
                                    height: 320,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1a1a1a),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: _coverUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => Image.asset(
                                          'assets/vt-videoplaceholder.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10),
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
                                              backgroundColor: Color(0xFF808080),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                            ),
                                            onPressed: _togglePlayPause,
                                            child: Icon(
                                              _isPlaying ? Icons.pause : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 10),
                                  Text('Developed by Beasty Beats 2025', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Иконка меню и само меню
                      Positioned(
                        top: 30,
                        right: 10,
                        child: IconButton(
                          icon: Icon(Icons.menu, color: Colors.white, size: 36),
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
                                    color: Color(0xFF1a1a1a),
                                    padding: EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Material(
                                          type: MaterialType.transparency,
                                          child: InkWell(
                                            splashColor: Color(0xFF333333),
                                            onTapDown: (_) => _menuItemControllers[0].forward(),
                                            onTapCancel: () => _menuItemControllers[0].reverse(),
                                            onTap: () => _onMenuItemTap(0, () => _launchURL('https://t.me/vtornikshow')),
                                            child: AnimatedBuilder(
                                              animation: _menuItemScaleAnimations[0],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _menuItemScaleAnimations[0].value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    child: Text(
                                                      'Telegram',
                                                      style: TextStyle(color: Color(0xFF00aced), fontSize: 18),
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
                                            splashColor: Color(0xFF333333),
                                            onTapDown: (_) => _menuItemControllers[1].forward(),
                                            onTapCancel: () => _menuItemControllers[1].reverse(),
                                            onTap: () => _onMenuItemTap(1, () => _launchURL('https://t.me/beastybeats23')),
                                            child: AnimatedBuilder(
                                              animation: _menuItemScaleAnimations[1],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _menuItemScaleAnimations[1].value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    child: Text(
                                                      'Наш чат',
                                                      style: TextStyle(color: Color(0xFF00aced), fontSize: 18),
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
                                            splashColor: Color(0xFF333333),
                                            onTapDown: (_) => _menuItemControllers[2].forward(),
                                            onTapCancel: () => _menuItemControllers[2].reverse(),
                                            onTap: () => _onMenuItemTap(2, () => _launchURL('https://vtrnk.online/stream.html')),
                                            child: AnimatedBuilder(
                                              animation: _menuItemScaleAnimations[2],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _menuItemScaleAnimations[2].value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    child: Text(
                                                      'Видео стрим',
                                                      style: TextStyle(color: Color(0xFF00aced), fontSize: 18),
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
                                            splashColor: Color(0xFF333333),
                                            onTapDown: (_) => _menuItemControllers[3].forward(),
                                            onTapCancel: () => _menuItemControllers[3].reverse(),
                                            onTap: () => _onMenuItemTap(3, () => print("Настройки pressed")),
                                            child: AnimatedBuilder(
                                              animation: _menuItemScaleAnimations[3],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _menuItemScaleAnimations[3].value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    child: Text(
                                                      'Настройки',
                                                      style: TextStyle(color: Color(0xFF00aced), fontSize: 18),
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
                                            splashColor: Color(0xFF333333),
                                            onTapDown: (_) => _menuItemControllers[4].forward(),
                                            onTapCancel: () => _menuItemControllers[4].reverse(),
                                            onTap: () => _onMenuItemTap(4, () => print("Язык pressed")),
                                            child: AnimatedBuilder(
                                              animation: _menuItemScaleAnimations[4],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _menuItemScaleAnimations[4].value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    child: Text(
                                                      '🇬🇧 🇷🇺 🇮🇱',
                                                      style: TextStyle(color: Color(0xFF00aced), fontSize: 18),
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
                                            splashColor: Color(0xFF333333),
                                            onTapDown: (_) => _menuItemControllers[5].forward(),
                                            onTapCancel: () => _menuItemControllers[5].reverse(),
                                            onTap: () => _onMenuItemTap(5, _toggleMenu),
                                            child: AnimatedBuilder(
                                              animation: _menuItemScaleAnimations[5],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _menuItemScaleAnimations[5].value,
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    child: Text(
                                                      'Закрыть',
                                                      style: TextStyle(color: Colors.grey[300], fontSize: 18),
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

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
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
    _socket = IO.io('https://vtrnk.online', IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build());
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
      final response = await http.get(Uri.parse('https://vtrnk.online/track')).timeout(Duration(seconds: 10));
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
      await Future.delayed(Duration(seconds: 5));
      await _fetchTrackInfo();
    }
  }

  Future<void> _fetchCoverUrl() async {
    try {
      final coverResponse = await http.get(Uri.parse('https://vtrnk.online/get_cover_path')).timeout(Duration(seconds: 10));
      print("Ответ от /get_cover_path: ${coverResponse.body}");
      if (coverResponse.statusCode == 200) {
        final coverData = jsonDecode(coverResponse.body) as Map<String, dynamic>;
        _coverUrl = 'https://vtrnk.online${coverData['cover_path'] ?? '/assets/vt-videoplaceholder.png'}';
        print("Обложка обновлена: $_coverUrl");
        _updateMediaMetadata();
      } else {
        print("Ошибка получения обложки: ${coverResponse.statusCode}");
        _updateMediaMetadata();
      }
    } catch (e) {
      print("Ошибка при запросе обложки: $e");
      _updateMediaMetadata();
      await Future.delayed(Duration(seconds: 5));
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
    print("Обновление MediaItem: title=${newItem.title}, artist=${newItem.artist}, cover=${newItem.artUri}");
    updateMediaItem(newItem);
  }

  Future<void> updateMediaItem(MediaItem item) async {
    try {
      print("Updating MediaItem: title=${item.title}, artist=${item.artist}, cover=${item.artUri}");
      mediaItem.add(item);
      await updateQueue([item]);
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.ready,
        playing: _player.playing,
      ));
      await AudioService.updateMediaItem(item);
      print("Уведомления обновлены: title=${item.title}, artist=${item.artist}, cover=${item.artUri}");
    } catch (e) {
      print("Ошибка обновления MediaItem: $e");
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
      ],
      systemActions: {
        MediaAction.seek,
      },
      androidCompactActionIndices: [0],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
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