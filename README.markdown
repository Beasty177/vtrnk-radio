# VTRNK Radio

A Flutter-based internet radio app for streaming audio from https://vtrnk.online. Features dynamic UI, WebSocket integration, and background playback.

## Features
- Stream audio with `just_audio` and `audio_service`.
- Dynamic background color based on track cover using `palette_generator`.
- WebSocket updates for track metadata.
- Responsive UI for portrait and landscape orientations.
- Links to Telegram and video stream with `url_launcher`.

## Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/Beasty177/vtrnk-radio.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Screenshots
(Add screenshots of the app in portrait and landscape modes here)

## Technologies
- Flutter, Dart
- Packages: `just_audio`, `audio_service`, `socket_io_client`, `palette_generator`, `url_launcher`, `cached_network_image`

## License
MIT License