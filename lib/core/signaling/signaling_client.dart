import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/environment.dart';

class SignalingClient {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  String? _userId;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> connect(String userId) async {
    _userId = userId;
    final wsUrl = Environment.signalingUrl.replaceFirst('http', 'ws');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws?userId=$userId'));
      
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            print('Error parsing signaling message: $e');
          }
        },
        onError: (error) => print('WebSocket error: $error'),
        onDone: () => print('WebSocket closed'),
      );
    } catch (e) {
      print('Failed to connect to signaling server: $e');
    }
  }

  Future<void> register(String userId, String email, String displayName, Map<String, dynamic> preKeyBundle, String? profileImage) async {
    final url = Uri.parse('${Environment.signalingUrl}/register');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Environment.apiKey,
        },
        body: jsonEncode({
          'userId': userId,
          'email': email,
          'displayName': displayName,
          'preKeyBundle': preKeyBundle,
          'profileImage': profileImage,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> lookupUser(String userId) async {
    final url = Uri.parse('${Environment.signalingUrl}/lookup/$userId');
    
    try {
      final response = await http.get(
        url,
        headers: {'X-API-Key': Environment.apiKey},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('User not found');
      } else {
        throw Exception('Lookup failed: ${response.body}');
      }
    } catch (e) {
      print('Lookup error: $e');
      rethrow;
    }
  }

  Future<void> sendOffer(String targetUserId, String offer) async {
    final url = Uri.parse('${Environment.signalingUrl}/offer');
    
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Environment.apiKey,
        },
        body: jsonEncode({
          'from': _userId,
          'to': targetUserId,
          'offer': offer,
        }),
      );
    } catch (e) {
      print('Send offer error: $e');
      rethrow;
    }
  }

  Future<void> sendAnswer(String targetUserId, String answer) async {
    final url = Uri.parse('${Environment.signalingUrl}/answer');
    
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Environment.apiKey,
        },
        body: jsonEncode({
          'from': _userId,
          'to': targetUserId,
          'answer': answer,
        }),
      );
    } catch (e) {
      print('Send answer error: $e');
      rethrow;
    }
  }

  Future<void> sendIceCandidate(String targetUserId, String candidate) async {
    final url = Uri.parse('${Environment.signalingUrl}/ice');
    
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': Environment.apiKey,
        },
        body: jsonEncode({
          'from': _userId,
          'to': targetUserId,
          'candidate': candidate,
        }),
      );
    } catch (e) {
      print('Send ICE candidate error: $e');
    }
  }

  Future<bool> checkPresence(String userId) async {
    final url = Uri.parse('${Environment.signalingUrl}/presence/$userId');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['online'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
