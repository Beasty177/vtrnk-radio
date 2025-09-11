VTRNK Radio
VTRNK Radio is a Flutter-based mobile application for streaming internet radio from https://vtrnk.online/radio_stream. It features a dynamic equalizer, real-time track metadata updates via WebSocket, background playback, and a responsive UI for both portrait and landscape modes. The app integrates with Liquidsoap and Icecast for seamless audio streaming.
Features

Audio Streaming: Streams high-quality audio with real-time metadata (artist, title, cover art) using just_audio and audio_service.
Dynamic Equalizer: Visualizes audio playback with a customizable 14-bar equalizer animation.
Background Playback: Continues playing audio in the background with system notification controls.
WebSocket Integration: Fetches real-time track updates via socket_io_client for artist, title, and cover art.
Dynamic Background: Adjusts the UI background color based on the track's cover art using palette_generator.
External Links: Quick access to Telegram channels (https://t.me/vtornikshow, https://t.me/beastybeats23) and video stream (https://vtrnk.online/stream.html) via url_launcher.
Responsive Design: Adapts seamlessly to portrait and landscape orientations.
Multilingual Support: Offers interface in English, Russian, and Hebrew, with persistent language selection.

Screenshots



Portrait Mode
Landscape Mode
Language Selection Menu








Installation

Clone the repository:git clone https://github.com/Beasty177/vtrnk-radio.git
cd radio_app_new


Install dependencies:flutter pub get


Run the app:flutter run



Server Setup
The app connects to a server running Liquidsoap and Icecast at https://vtrnk.online. To configure the server:

SSH into the server: ssh beasty197@89.169.174.227
Activate virtual environment: source /home/beasty197/projects/vtrnk_radio/venv/bin/activate
Run Liquidsoap: /home/beasty197/.opam/4.14.0/bin/liquidsoap /home/beasty197/projects/vtrnk_radio/liquidsoap/radio.liq
Use credentials:
<source-password>vtrnk_stream123</source-password>
<relay-password>vtrnk_stream123</relay-password>
<admin-password>vtrnk_admin123</admin-password>



Technologies

Framework: Flutter, Dart
Key Packages:
just_audio: ^0.9.46, just_audio_background: ^0.0.1-beta.17, audio_service: ^0.18.18 for audio streaming and background playback.
socket_io_client: ^3.1.2 for real-time track metadata updates.
palette_generator: ^0.3.3+7 for dynamic background color extraction.
url_launcher: ^6.3.1 for external links.
cached_network_image: ^3.4.1 for efficient image loading.
shared_preferences: ^2.5.3 for persistent settings.
flutter_localizations and intl: ^0.20.2 for multilingual support.



Contributing
Contributions are welcome! Please open an issue or submit a pull request on GitHub. For major changes, discuss them in the issues section first.
License
This project is licensed under the MIT License.