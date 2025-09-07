import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final int barCount = 8;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _artist = "Ожидание исполнителя...";
  String _title = "Ожидание трека...";
  String _coverUrl = 'https://vtrnk.online/images/logovtrnk.png'; // Дефолтная обложка

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
    _fetchTrackInfo(); // Запрос данных трека
  }

  Future<void> _fetchTrackInfo() async {
    try {
      final response = await http.get(Uri.parse('https://vtrnk.online/track'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _artist = data[0][1]; // Artist из JSON (пример: data[0][1] = artist)
          _title = data[1][1]; // Title из JSON (пример: data[1][1] = title)
          // Если есть cover, заменить _coverUrl = 'https://vtrnk.online$coverPath';
        });
      }
    } catch (e) {
      print("Ошибка при запросе трека: $e");
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
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: _toggleMenu,
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 70,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(barCount, (index) {
                          return Container(
                            width: 14,
                            height: 70 * _animations[index].value * _maxHeights[index],
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: Colors.white,
                          );
                        }),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Color(0xFF1a1a1a), // Фон как в HTML
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
                SizedBox(height: 15),
                Text('Сейчас в эфире', style: TextStyle(color: Color(0xFFccc), fontSize: 16)),
                SizedBox(height: 5),
                Text(_artist, style: TextStyle(color: Colors.white, fontSize: 18)),
                SizedBox(height: 2),
                Text(_title, style: TextStyle(color: Color(0xFFddd), fontSize: 16)),
                SizedBox(height: 20),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _togglePlayPause,
                ),
                SizedBox(height: 20),
                Text('Test Radio App', style: TextStyle(color: Colors.white, fontSize: 24)),
              ],
            ),
          ),
          if (_isMenuOpen)
            Positioned(
              top: 60,
              right: 10,
              child: Container(
                width: 150,
                color: Color(0xFF1A1A1A),
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: Text('Telegram', style: TextStyle(color: Color(0xFF00ACED))),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text('Чат', style: TextStyle(color: Color(0xFF00ACED))),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text('Радиострим', style: TextStyle(color: Color(0xFF00ACED))),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}