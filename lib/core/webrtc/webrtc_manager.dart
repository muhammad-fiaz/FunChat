import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../config/environment.dart';

enum ConnectionState { disconnected, connecting, connected, failed }

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final List<RTCIceCandidate> _iceCandidateBuffer = [];
  bool _remoteDescriptionSet = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<ConnectionState> get stateStream => _stateController.stream;

  Future<void> initialize() async {
    final config = {
      'iceServers': Environment.iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);
    
    _peerConnection!.onIceCandidate = (candidate) {
      if (_remoteDescriptionSet) {
        _onIceCandidate?.call(candidate);
      } else {
        _iceCandidateBuffer.add(candidate);
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _stateController.add(ConnectionState.connected);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _stateController.add(ConnectionState.failed);
      }
    };

    _peerConnection!.onDataChannel = (channel) {
      _setupDataChannel(channel);
    };
  }

  Future<String> createOffer() async {
    _dataChannel = await _peerConnection!.createDataChannel(
      'funchat-data',
      RTCDataChannelInit()..ordered = true,
    );
    _setupDataChannel(_dataChannel!);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return jsonEncode(offer.toMap());
  }

  Future<String> createAnswer(String offerJson) async {
    final offerMap = jsonDecode(offerJson);
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offerMap['sdp'], offerMap['type']),
    );
    _remoteDescriptionSet = true;
    _flushIceCandidates();

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return jsonEncode(answer.toMap());
  }

  Future<void> setRemoteDescription(String descriptionJson) async {
    final descMap = jsonDecode(descriptionJson);
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(descMap['sdp'], descMap['type']),
    );
    _remoteDescriptionSet = true;
    _flushIceCandidates();
  }

  Future<void> addIceCandidate(String candidateJson) async {
    final candMap = jsonDecode(candidateJson);
    final candidate = RTCIceCandidate(
      candMap['candidate'],
      candMap['sdpMid'],
      candMap['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    
    channel.onMessage = (message) {
      try {
        final data = message.type == MessageType.text
            ? jsonDecode(message.text)
            : jsonDecode(utf8.decode(message.binary));
        _messageController.add(data);
      } catch (e) {
        print('Error parsing message: $e');
      }
    };

    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _stateController.add(ConnectionState.connected);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _stateController.add(ConnectionState.disconnected);
      }
    };
  }

  void _flushIceCandidates() {
    for (var candidate in _iceCandidateBuffer) {
      _onIceCandidate?.call(candidate);
    }
    _iceCandidateBuffer.clear();
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message)));
    }
  }

  void sendBinary(List<int> data) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage.fromBinary(data is Uint8List ? data : Uint8List.fromList(data)));
    }
  }

  Future<void> close() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
    _remoteDescriptionSet = false;
    _iceCandidateBuffer.clear();
    _stateController.add(ConnectionState.disconnected);
  }

  void dispose() {
    _messageController.close();
    _stateController.close();
  }

  Function(RTCIceCandidate)? _onIceCandidate;
  set onIceCandidate(Function(RTCIceCandidate) callback) {
    _onIceCandidate = callback;
  }
}
