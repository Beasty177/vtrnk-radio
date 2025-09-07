import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  final String _streamUrl = 'https://vtrnk.online/radio_stream';

  MyAudioHandler() {
    // Связываем состояние плеера с audio_service
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: {
        MediaAction.seek, // Оставляем seek, хотя для стрима он редко нужен
      },
      androidCompactActionIndices: [0, 1],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
    );
  }

  @override
  Future<void> play() async {
    if (_player.audioSource == null) {
      await _player.setUrl(_streamUrl);
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  // Обновление метаданных для lock screen и notifications
  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String coverUrl,
  }) async {
    mediaItem.add(MediaItem(
      id: 'radio_stream',
      title: title,
      artist: artist,
      artUri: Uri.parse(coverUrl),
    ));
  }
}