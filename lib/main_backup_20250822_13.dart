import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:palette_generator/palette_generator.dart';

void main() {
  print("NEW CODE IS RUNNING!");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VTRNK Radio',
      theme: ThemeData.dark(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;
  late AnimationController _controller;
  late List<Animation<double>> _animations;
  late List<double> _maxHeights;
  final Random _random = Random();
  final int barCount = 14;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _artist = "Ожидание исполнителя...";
  String _title = "Ожидание трека...";
  String _coverUrl = 'https://vtrnk.online/images/logovtrnk.png';
  late IOWebSocketChannel _channel;
  Color _backgroundColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _maxHeights = List.generate(barCount, (_) => _random.nextDouble() * 0.6 + 0.4);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _updateHeights();
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });

    _animations = List.generate(barCount, (index) {
      double delay = index * (1.0 / barCount);
      double range = 0.8 / barCount;
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(delay, delay + range, curve: Curves.easeInOut),
        ),
      );
    });
    _controller.forward();

    _initAudioPlayer();
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.ready) {
        setState(() {
          _isPlaying = _audioPlayer.playing;
        });
      } else if (playerState.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
    _fetchTrackInfo();
    _initWebSocket();
    _updateBackgroundColor();
  }

  void _initWebSocket() {
    try {
      _channel = IOWebSocketChannel.connect('wss://vtrnk.online');
      _channel.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data is Map && !isVideoStreamActive(data)) {
            setState(() {
              _artist = data['artist'] ?? "VTRNK";
              _title = data['title'] ?? "Video Stream";
              _coverUrl = data['cover_path'] != null
                  ? 'https://vtrnk.online${data['cover_path']}'
                  : 'https://vtrnk.online/images/logovtrnk.png';
              _updateBackgroundColor();
            });
          }
        },
        onError: (error) => print("WebSocket ошибка: $error"),
        onDone: () => print("WebSocket закрыт"),
      );
    } catch (e) {
      print("Ошибка подключения WebSocket: $e");
    }
  }

  bool isVideoStreamActive(Map? data) {
    return data?['video_stream_active'] == true;
  }

  Future<void> _fetchTrackInfo() async {
    try {
      final response = await http.get(Uri.parse('https://vtrnk.online/track'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final trackData = {for (var item in data) item[0]: item[1]};
        setState(() {
          _artist = trackData['artist']?.toString() ?? "VTRNK";
          _title = trackData['title']?.toString() ?? "Video Stream";
        });
      }
      final coverResponse = await http.get(Uri.parse('https://vtrnk.online/get_cover_path'));
      if (coverResponse.statusCode == 200) {
        final coverData = jsonDecode(coverResponse.body) as Map<String, dynamic>;
        setState(() {
          _coverUrl = 'https://vtrnk.online${coverData['cover_path'] ?? '/images/logovtrnk.png'}';
          _updateBackgroundColor();
        });
      }
    } catch (e) {
      print("Ошибка при запросе данных: $e");
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setUrl('https://vtrnk.online/radio_stream');
    } catch (e) {
      print("Ошибка при инициализации стрима: $e");
    }
  }

  void _updateHeights() {
    setState(() {
      _maxHeights = List.generate(barCount, (_) => _random.nextDouble() * 0.6 + 0.4);
    });
  }

  Future<void> _updateBackgroundColor() async {
    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(_coverUrl),
        maximumColorCount: 10,
      );
      setState(() {
        final dominantColor = palette.dominantColor?.color ?? Colors.black;
        _backgroundColor = Color.fromRGBO(
          dominantColor.red,
          dominantColor.green,
          dominantColor.blue,
          0.5, // Затемнение
        ).withOpacity(1.0);
      });
    } catch (e) {
      print("Ошибка при извлечении цвета: $e");
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.stop();
        await _initAudioPlayer();
        await _audioPlayer.play();
      }
    } catch (e) {
      print("Ошибка при переключении: $e");
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _handleTapOutsideMenu(TapDownDetails details) {
    final RenderBox? overlay = Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (overlay != null && _isMenuOpen) {
      final localPosition = overlay.globalToLocal(details.globalPosition);
      final menuRect = Rect.fromLTWH(
        overlay.size.width - 160,
        10,
        150,
        120,
      );
      if (!menuRect.contains(localPosition)) {
        setState(() {
          _isMenuOpen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapOutsideMenu,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 36),
              onPressed: _toggleMenu,
            ),
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200, // Увеличен до 200px
                        child: Image.asset('assets/logovtrnk.png', fit: BoxFit.contain),
                      ),
                      SizedBox(height: 10),
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
                                  height: 40 * _animations[index].value * _maxHeights[index],
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  color: Color(0xFFd3d3d3),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 15),
                      Text('Сейчас в эфире', style: TextStyle(color: Colors.white, fontSize: 16)),
                      SizedBox(height: 15),
                      Text(_artist, style: TextStyle(color: Colors.white, fontSize: 18)),
                      SizedBox(height: 12),
                      Text(_title, style: TextStyle(color: Colors.white, fontSize: 16)),
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
                          child: Image.network(
                            _coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.image_not_supported, color: Colors.white, size: 100);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: 105,
                        height: 52.5,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF333),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: _togglePlayPause,
                          child: Icon(
                            _isPlaying ? Icons.stop : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('Test Radio App', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
            if (_isMenuOpen)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 150,
                  color: Color(0xFF1a1a1a),
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            // Эффект нажатия
                          });
                        },
                        child: TextButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                return states.contains(MaterialState.pressed) ? Color(0xFF333) : Colors.transparent;
                              },
                            ),
                          ),
                          onPressed: () {},
                          child: Text('Telegram', style: TextStyle(color: Color(0xFF00aced))),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            // Эффект нажатия
                          });
                        },
                        child: TextButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                return states.contains(MaterialState.pressed) ? Color(0xFF333) : Colors.transparent;
                              },
                            ),
                          ),
                          onPressed: () {},
                          child: Text('Чат', style: TextStyle(color: Color(0xFF00aced))),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            // Эффект нажатия
                          });
                        },
                        child: TextButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                return states.contains(MaterialState.pressed) ? Color(0xFF333) : Colors.transparent;
                              },
                            ),
                          ),
                          onPressed: () {},
                          child: Text('Радиострим', style: TextStyle(color: Color(0xFF00aced))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}