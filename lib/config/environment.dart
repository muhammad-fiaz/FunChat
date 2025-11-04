import 'dart:convert';

class Environment {
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: 'your_secure_random_key_here',
  );
  static String get signalingUrl {
    const url = String.fromEnvironment('SIGNALING_URL', defaultValue: 'ws://localhost:8787');
    return url;
  }

  static const String buildMode = String.fromEnvironment(
    'BUILD_MODE',
    defaultValue: 'dev',
  );

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'FunChat',
  );

  static const String appDomain = String.fromEnvironment(
    'APP_DOMAIN',
    defaultValue: 'localhost',
  );

  static const int maxChunkSizeBytes = int.fromEnvironment(
    'MAX_CHUNK_SIZE_BYTES',
    defaultValue: 65536,
  );

  static const String logLevel = String.fromEnvironment(
    'LOG_LEVEL',
    defaultValue: 'debug',
  );

  static const String turnUsername = String.fromEnvironment(
    'TURN_USERNAME',
    defaultValue: '',
  );

  static const String turnCredential = String.fromEnvironment(
    'TURN_CREDENTIAL',
    defaultValue: '',
  );

  static List<Map<String, dynamic>> get iceServers {
    const iceServersJson = String.fromEnvironment(
      'ICE_SERVERS',
      defaultValue: '',
    );

    if (iceServersJson.isNotEmpty) {
      try {
        return List<Map<String, dynamic>>.from(jsonDecode(iceServersJson));
      } catch (_) {}
    }

    return [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      if (turnUsername.isNotEmpty && turnCredential.isNotEmpty)
        {
          'urls': 'turn:turn.example.com:3478',
          'username': turnUsername,
          'credential': turnCredential,
        },
    ];
  }

  static Map<String, dynamic> get mediaCompressionSettings => {
        'image': {
          'maxWidth': 1920,
          'maxHeight': 1920,
          'quality': 85,
        },
        'video': {
          'maxWidth': 1280,
          'maxHeight': 720,
          'bitrate': 2000000,
        },
      };

  static bool get isProduction => buildMode == 'production';
  static bool get isDevelopment => buildMode == 'dev';
}
