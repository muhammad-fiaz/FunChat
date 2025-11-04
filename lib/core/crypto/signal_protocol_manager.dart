import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class SignalProtocolManager {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late IdentityKeyPair _identityKeyPair;
  late int _registrationId;
  late SignalProtocolStore _store;

  Future<void> initialize(String userId) async {
    final storedIdentity = await _secureStorage.read(key: 'identity_$userId');
    
    if (storedIdentity != null) {
      final data = jsonDecode(storedIdentity);
      _identityKeyPair = IdentityKeyPair.fromSerialized(
        Uint8List.fromList(List<int>.from(data['identityKey'])),
      );
      _registrationId = data['registrationId'];
    } else {
      _identityKeyPair = generateIdentityKeyPair();
      _registrationId = generateRegistrationId(false);
      
      await _secureStorage.write(
        key: 'identity_$userId',
        value: jsonEncode({
          'identityKey': _identityKeyPair.serialize().toList(),
          'registrationId': _registrationId,
        }),
      );
    }

    _store = InMemorySignalProtocolStore(_identityKeyPair, _registrationId);
  }

  Future<Map<String, dynamic>> generatePreKeyBundle() async {
    final preKeys = generatePreKeys(0, 100);
    final signedPreKey = generateSignedPreKey(_identityKeyPair, 0);

    for (var preKey in preKeys) {
      await _store.storePreKey(preKey.id, preKey);
    }
    await _store.storeSignedPreKey(signedPreKey.id, signedPreKey);

    return {
      'identityKey': base64Encode(_identityKeyPair.getPublicKey().serialize()),
      'registrationId': _registrationId,
      'preKeys': preKeys.map((pk) => {
        'id': pk.id,
        'publicKey': base64Encode(pk.getKeyPair().publicKey.serialize()),
      }).toList(),
      'signedPreKey': {
        'id': signedPreKey.id,
        'publicKey': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
        'signature': base64Encode(signedPreKey.signature),
      },
    };
  }

  Future<void> processPreKeyBundle(String peerId, Map<String, dynamic> bundle) async {
    final identityKey = IdentityKey.fromBytes(
      Uint8List.fromList(base64Decode(bundle['identityKey'])),
      0,
    );
    
    final signedPreKeyPublic = Uint8List.fromList(
      base64Decode(bundle['signedPreKey']['publicKey']),
    );
    
    final preKeyPublic = bundle['preKeys'].isNotEmpty
        ? Uint8List.fromList(base64Decode(bundle['preKeys'][0]['publicKey']))
        : null;

    final address = SignalProtocolAddress(peerId, 1);
    final sessionBuilder = SessionBuilder(
      _store,
      _store,
      _store,
      _store,
      address,
    );

    final preKeyBundle = PreKeyBundle(
      bundle['registrationId'],
      1,
      preKeyPublic != null ? bundle['preKeys'][0]['id'] : 0,
      preKeyPublic != null ? Curve.decodePoint(preKeyPublic, 0) : null,
      bundle['signedPreKey']['id'],
      Curve.decodePoint(signedPreKeyPublic, 0),
      Uint8List.fromList(base64Decode(bundle['signedPreKey']['signature'])),
      identityKey,
    );

    await sessionBuilder.processPreKeyBundle(preKeyBundle);
  }

  Future<String> encryptMessage(String peerId, String plaintext) async {
    final address = SignalProtocolAddress(peerId, 1);
    final sessionCipher = SessionCipher(
      _store,
      _store,
      _store,
      _store,
      address,
    );
    
    final ciphertext = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode(plaintext)),
    );

    return base64Encode(ciphertext.serialize());
  }

  Future<String> decryptMessage(String peerId, String ciphertextBase64) async {
    final address = SignalProtocolAddress(peerId, 1);
    final sessionCipher = SessionCipher(
      _store,
      _store,
      _store,
      _store,
      address,
    );
    
    final ciphertextBytes = base64Decode(ciphertextBase64);
    
    Uint8List plaintext;
    if (ciphertextBytes[0] == 3) {
      final preKeyMessage = PreKeySignalMessage(ciphertextBytes);
      plaintext = await sessionCipher.decrypt(preKeyMessage);
    } else {
      final signalMessage = SignalMessage.fromSerialized(ciphertextBytes);
      plaintext = await sessionCipher.decryptFromSignal(signalMessage);
    }

    return utf8.decode(plaintext);
  }

  String getPublicIdentityKey() {
    return base64Encode(_identityKeyPair.getPublicKey().serialize());
  }

  String getFingerprint(String peerPublicKey) {
    final localKey = _identityKeyPair.getPublicKey().serialize();
    final remoteKey = base64Decode(peerPublicKey);
    final combined = Uint8List.fromList([...localKey, ...remoteKey]);
    final hash = sha256.convert(combined);
    return hash.toString().substring(0, 32);
  }
}
