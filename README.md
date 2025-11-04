# FunChat - End-to-End Encrypted P2P Chat App

FunChat is a production-quality, peer-to-peer, end-to-end encrypted chat application built with Flutter. It uses the Signal Protocol (X3DH + Double Ratchet) for encryption, WebRTC DataChannel for P2P transport, and a lightweight Cloudflare Worker for signaling.

## Features

- ✅ End-to-end encryption using Signal Protocol (libsignal)
- ✅ Peer-to-peer communication via WebRTC DataChannel
- ✅ Local SQLite storage with Drift
- ✅ No server-side message storage
- ✅ Offline message queue with automatic retry
- ✅ Dark/Light theme support
- ✅ WhatsApp-like UI/UX
- ✅ Message status indicators (pending/sent/delivered)
- ✅ Search conversations
- ✅ Swipe to delete chats
- ✅ Identity key verification

## Architecture

### Frontend (Flutter)
- **State Management**: Riverpod
- **Database**: Drift (SQLite)
- **Encryption**: libsignal_protocol_dart
- **P2P Transport**: flutter_webrtc
- **UI**: Material Design 3

### Backend (Cloudflare Worker)
- **Framework**: HonoJS (TypeScript)
- **Purpose**: Signaling only (no message storage)
- **Endpoints**: Registration, lookup, offer/answer, ICE exchange, presence

## Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Bun (for backend) - [Install Bun](https://bun.sh)
- Android Studio / Xcode (for mobile development)

## Setup Instructions

### 1. Backend Setup

```bash
cd backend

# Install dependencies using bun
bun install

# Run development server
bun run dev

# The server will start on http://localhost:8787
```

For production deployment to Cloudflare Workers:
```bash
# Login to Cloudflare
wrangler login

# Deploy
bun run deploy
```

### 2. Flutter App Setup

```bash
# Install Flutter dependencies
flutter pub get

# Generate Drift database code
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### 3. Environment Configuration

The app uses `--dart-define` for configuration. Default values are set in `lib/config/environment.dart`.

To run with custom configuration:

```bash
flutter run \
  --dart-define=SIGNALING_URL=ws://localhost:8787 \
  --dart-define=BUILD_MODE=dev \
  --dart-define=LOG_LEVEL=debug
```

Available environment variables:
- `SIGNALING_URL` - WebSocket URL for signaling server (default: ws://localhost:8787)
- `BUILD_MODE` - dev/production (default: dev)
- `APP_NAME` - Application name (default: FunChat)
- `APP_DOMAIN` - App domain (default: funchat.local)
- `MAX_CHUNK_SIZE_BYTES` - File chunk size (default: 65536)
- `LOG_LEVEL` - Logging level (default: debug)
- `ICE_SERVERS` - JSON array of ICE servers
- `TURN_USERNAME` - TURN server username
- `TURN_CREDENTIAL` - TURN server credential

## Project Structure

```
funchat/
├── lib/
│   ├── config/
│   │   └── environment.dart          # Environment configuration
│   ├── core/
│   │   ├── crypto/
│   │   │   └── signal_protocol_manager.dart  # Signal Protocol implementation
│   │   ├── webrtc/
│   │   │   └── webrtc_manager.dart   # WebRTC P2P manager
│   │   └── signaling/
│   │       └── signaling_client.dart # Signaling client
│   ├── data/
│   │   ├── database/
│   │   │   └── database.dart         # Drift database schema
│   │   └── repositories/
│   │       └── chat_repository.dart  # Chat business logic
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── chat_list_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── add_contact_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── providers/
│   │   └── app_providers.dart        # Riverpod providers
│   └── main.dart
├── backend/
│   ├── src/
│   │   └── index.ts                  # Signaling server
│   ├── package.json
│   ├── wrangler.toml
│   └── .env
└── README.md
```

## How It Works

### 1. Identity & Key Management
- On first run, the app generates a Signal Protocol identity keypair
- Pre-keys and signed pre-keys are generated and published to the signaling server
- Private keys are stored securely using flutter_secure_storage

### 2. Adding Contacts
- User enters contact's User ID
- App fetches contact's public identity and pre-key bundle from signaling server
- X3DH handshake establishes initial session
- Contact is saved locally

### 3. Establishing P2P Connection
- Sender creates WebRTC offer and sends via signaling server
- Recipient receives offer and creates answer
- ICE candidates are exchanged
- Direct P2P DataChannel connection is established

### 4. Sending Messages
- Message is encrypted using Signal Protocol (Double Ratchet)
- Encrypted message is sent over WebRTC DataChannel
- Message is stored locally as ciphertext
- If recipient is offline, message is queued locally

### 5. Receiving Messages
- Encrypted message arrives via DataChannel
- Message is decrypted using Signal Protocol
- Message is stored locally and displayed
- Delivery acknowledgment is sent

### 6. Offline Handling
- Messages sent while recipient is offline are queued locally
- When connection is re-established, queued messages are automatically sent
- Fresh session keys are derived on reconnection

## Security Features

- **End-to-End Encryption**: All messages encrypted with Signal Protocol
- **Perfect Forward Secrecy**: Double Ratchet ensures past messages remain secure
- **No Server Storage**: Messages never stored on server
- **Secure Key Storage**: Private keys stored in device secure enclave
- **Identity Verification**: Users can verify contact fingerprints
- **Encrypted Session State**: Signal session state encrypted at rest

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Running on Multiple Devices
To test P2P functionality:
1. Run backend: `cd backend && bun run dev`
2. Run app on device 1: `flutter run -d device1`
3. Run app on device 2: `flutter run -d device2`
4. Add each other as contacts using User IDs
5. Start chatting!

## Building for Production

### Android
```bash
flutter build apk --release \
  --dart-define=SIGNALING_URL=wss://your-worker.workers.dev \
  --dart-define=BUILD_MODE=production
```

### iOS
```bash
flutter build ios --release \
  --dart-define=SIGNALING_URL=wss://your-worker.workers.dev \
  --dart-define=BUILD_MODE=production
```

## Troubleshooting

### Backend not starting
- Ensure Bun is installed: `bun --version`
- Check port 8787 is not in use
- Verify wrangler.toml configuration

### App can't connect to signaling server
- Check SIGNALING_URL in environment.dart
- Ensure backend is running
- Check firewall settings

### Messages not sending
- Verify both devices are connected to signaling server
- Check WebRTC connection state
- Ensure ICE candidates are being exchanged

### Database errors
- Run: `flutter pub run build_runner build --delete-conflicting-outputs`
- Clear app data and restart

## Performance Considerations

- Messages are paginated for smooth scrolling
- Large files are chunked for efficient transfer
- Encryption operations run off main thread
- Database queries are optimized with indexes

## Future Enhancements

- [ ] Group chats (in progress)
- [ ] Voice/video calls
- [ ] File attachments with resume support
- [ ] Message reactions
- [ ] Push notifications
- [ ] Desktop apps (Windows, macOS, Linux)
- [ ] Message search
- [ ] Chat backup/restore

## Environment Configuration

### Flutter App (.env)

1. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

2. Update values in `.env`:
```env
SIGNALING_URL=ws://localhost:8787
BUILD_MODE=dev
API_KEY=funchat_secure_key_2024
```

3. Run with environment variables:
```bash
flutter run \
  --dart-define=SIGNALING_URL=ws://localhost:8787 \
  --dart-define=API_KEY=funchat_secure_key_2024
```

### Backend (.env)

1. Copy `.env.example` to `.env`:
```bash
cd backend
cp .env.example .env
```

2. Update values in `backend/.env`:
```env
PORT=8787
ENVIRONMENT=development
API_KEY=funchat_secure_key_2025
```

## Generating App Icons

The app uses `assets/images/logo.png` for all platform icons.

1. Place your logo at `assets/images/logo.png` (1024x1024 recommended)

2. Generate icons for all platforms:
```bash
flutter pub get
dart run flutter_launcher_icons
```

This will generate icons for:
- Android (all densities)
- iOS (all sizes)
- Web (favicon, manifest icons)
- Windows (ico file)
- macOS (icns file)
- Linux (png files)

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

## Developer

**Muhammad Fiaz**
- Email: contact@muhammadfiaz.com
- GitHub: [@muhammad-fiaz](https://github.com/muhammad-fiaz)
- Repository: [muhammad-fiaz/funchat](https://github.com/muhammad-fiaz/funchat)

## Support

For issues and questions:
- GitHub Issues: [Create an issue](https://github.com/muhammad-fiaz/funchat/issues)
- Email: contact@muhammadfiaz.com

## Acknowledgments

- Signal Protocol by Open Whisper Systems
- Flutter team for the amazing framework
- Cloudflare for Workers platform
- HonoJS for lightweight web framework
