import 'package:flutter_test/flutter_test.dart';
import 'package:funchat/core/crypto/signal_protocol_manager.dart';

void main() {
  group('Signal Protocol Manager Tests', () {
    test('Initialize and generate keys', () async {
      final manager = SignalProtocolManager();
      await manager.initialize('test_user_1');
      
      final preKeyBundle = await manager.generatePreKeyBundle();
      
      expect(preKeyBundle['identityKey'], isNotEmpty);
      expect(preKeyBundle['registrationId'], isNotNull);
      expect(preKeyBundle['preKeys'], isNotEmpty);
      expect(preKeyBundle['signedPreKey'], isNotNull);
    });

    test('Encrypt and decrypt message', () async {
      final alice = SignalProtocolManager();
      final bob = SignalProtocolManager();
      
      await alice.initialize('alice');
      await bob.initialize('bob');
      
      final bobBundle = await bob.generatePreKeyBundle();
      await alice.processPreKeyBundle('bob', bobBundle);
      
      final aliceBundle = await alice.generatePreKeyBundle();
      await bob.processPreKeyBundle('alice', aliceBundle);
      
      const plaintext = 'Hello, Bob!';
      final ciphertext = await alice.encryptMessage('bob', plaintext);
      
      expect(ciphertext, isNotEmpty);
      expect(ciphertext, isNot(equals(plaintext)));
      
      final decrypted = await bob.decryptMessage('alice', ciphertext);
      expect(decrypted, equals(plaintext));
    });

    test('Generate fingerprint', () async {
      final manager = SignalProtocolManager();
      await manager.initialize('test_user');
      
      final publicKey = manager.getPublicIdentityKey();
      final fingerprint = manager.getFingerprint(publicKey);
      
      expect(fingerprint, isNotEmpty);
      expect(fingerprint.length, equals(32));
    });
  });
}
