# VTRNK Radio

[![Download on Google Play](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png)](https://play.google.com/store/apps/details?id=com.vtrnk.radio)

VTRNK Radio is a Flutter-based mobile application for streaming internet radio from https://vtrnk.online/radio_stream. It features a dynamic equalizer, real-time track metadata updates via WebSocket, background playback, and a responsive UI for both portrait and landscape modes. The app integrates with Liquidsoap and Icecast for seamless audio streaming.

This is my personal project, driven by a passion for programming and music. As an enthusiast in both fields, I developed VTRNK Radio from scratch to showcase full-cycle app development, from initial concept to release. It serves as my portfolio, demonstrating skills in Flutter, Dart, audio streaming with just_audio and audio_service, real-time updates via socket_io_client, and multilingual support using flutter_localizations. The app operates independently from the radio website, relying only on public information like the audio stream URL. With minimal modifications (e.g., updating the stream endpoint in main.dart), it can be adapted or duplicated for any other online radio station using a similar audio stream setup.

## Features

- Audio Streaming: Streams high-quality audio with real-time metadata (artist, title, cover art) using just_audio and audio_service.
- Dynamic Equalizer: Visualizes audio playback with a customizable 14-bar equalizer animation.
- Background Playback: Continues playing audio in the background with system notification controls.
- WebSocket Integration: Fetches real-time track updates via socket_io_client for artist, title, and cover art.
- Dynamic Background: Adjusts the UI background color based on the track's cover art using pixel color extraction.
- External Links: Quick access to Telegram channels (https://t.me/vtornikshow, https://t.me/beastybeats23), video stream (https://vtrnk.online/stream.html), and Privacy Policy (https://beasty177.github.io/vtrnk-radio/privacy_policy.html) via url_launcher.
- Responsive Design: Adapts seamlessly to portrait and landscape orientations.
- Multilingual Support: Offers interface in English, Russian, Spanish, French, and Hebrew, with persistent language selection based on device locale.
- Customizable Settings: User-configurable options including vibration feedback, adaptive background, cover art loading, equalizer display, and extended track info display, stored locally via shared_preferences.
- Privacy Policy: Complies with Google Play requirements, with no personal data collection and minimal app queries for link handling.

## Screenshots

| Portrait Mode | Landscape Mode | Language Selection Menu | Settings Menu |
|---------------|---------------|-------------------------|---------------|
| ![Portrait Mode](https://github.com/Beasty177/vtrnk-radio/raw/main/screenshots/portrait.jpg) | ![Landscape Mode](https://github.com/Beasty177/vtrnk-radio/raw/main/screenshots/landscape.jpg) | ![Language Selection Menu](https://github.com/Beasty177/vtrnk-radio/raw/main/screenshots/language_menu.jpg) | ![Settings Menu](https://github.com/Beasty177/vtrnk-radio/raw/main/screenshots/settings_menu.jpg) |

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Beasty177/vtrnk-radio.git
   cd radio_app_new
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Technologies

- Framework: Flutter, Dart
- Key Packages:
  - just_audio: ^0.9.46
  - just_audio_background: ^0.0.1-beta.17
  - audio_service: ^0.18.18 for audio streaming and background playback
  - socket_io_client: ^3.1.2 for real-time track metadata updates
  - image: ^4.2.0 for dynamic background color extraction from cover art
  - url_launcher: ^6.3.1 for external links to Telegram, video stream, and Privacy Policy
  - shared_preferences: ^2.5.3 for persistent settings
  - flutter_localizations and intl: ^0.20.2 for multilingual support
  - http: ^1.2.2 for fetching cover art

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub. For major changes, discuss them in the issues section first.

## License

This project is licensed under the MIT License.

## Privacy Policy

The VTRNK Radio app does not collect or share personal data. For details, see our [Privacy Policy](https://beasty177.github.io/vtrnk-radio/privacy_policy.html).