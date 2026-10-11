import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart' show DartPbkdf2;
import 'package:flutter/foundation.dart' show compute;

/// Must match the web version byte for byte:
///   auth password = hex(PBKDF2-SHA256(pw, "zadachnik/auth/v1/" + email, 310000, 32 bytes))
///   encryption key = PBKDF2-SHA256(pw, "zadachnik/enc/v1/" + email, 310000, 32 bytes)
///   record = AES-256-GCM, 12-byte IV, AAD = record id, data = base64(ciphertext || 16-byte tag)
const kdfIterations = 310000;

class DerivedKeys {
  DerivedKeys(this.authPassword, this.encKey);
  final String authPassword;
  final List<int> encKey;
}

/// args = [password, salt]. Top-level so it can run in a background isolate via compute().
Future<List<int>> _pbkdf2(List<String> args) async {
  final password = args[0], salt = args[1];
  // Runs in its own isolate, so the periodic pauses that keep a UI thread responsive are not needed.
  final algo = DartPbkdf2(macAlgorithm: Hmac.sha256(), iterations: kdfIterations, bits: 256, pauseFrequency: 0);
  final key = await algo.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: utf8.encode(salt));
  return key.extractBytes();
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Runs both derivations in parallel background isolates (a few seconds on a phone).
Future<DerivedKeys> deriveKeys(String email, String password) async {
  final e = email.trim().toLowerCase();
  final results = await Future.wait([
    compute(_pbkdf2, [password, 'zadachnik/auth/v1/$e']),
    compute(_pbkdf2, [password, 'zadachnik/enc/v1/$e']),
  ]);
  return DerivedKeys(_hex(results[0]), results[1]);
}

class RecordCipher {
  RecordCipher(List<int> keyBytes) : _key = SecretKey(keyBytes);
  final SecretKey _key;
  final AesGcm _algo = AesGcm.with256bits();

  Future<({String iv, String data})> encrypt(Map<String, dynamic> record, String id) async {
    final nonce = _algo.newNonce();
    final box = await _algo.encrypt(
      utf8.encode(jsonEncode(record)),
      secretKey: _key,
      nonce: nonce,
      aad: utf8.encode(id),
    );
    return (iv: base64Encode(nonce), data: base64Encode([...box.cipherText, ...box.mac.bytes]));
  }

  Future<Map<String, dynamic>> decrypt(String iv, String data, String id) async {
    final all = base64Decode(data);
    if (all.length < 16) throw const FormatException('ciphertext too short');
    final box = SecretBox(
      all.sublist(0, all.length - 16),
      nonce: base64Decode(iv),
      mac: Mac(all.sublist(all.length - 16)),
    );
    final clear = await _algo.decrypt(box, secretKey: _key, aad: utf8.encode(id));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
  }
}
