import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

class WrongPassphrase implements Exception {
  @override
  String toString() => 'The passphrase doesn\'t match this backup.';
}

class NotABackup implements Exception {
  @override
  String toString() => 'This file isn\'t a Bills O9 backup.';
}

/// Backup file format (".b9"), smallest practical size:
///   "B9T1" | salt (16) | nonce (12) | mac (16) | AES-256-GCM(gzip(JSON))
/// The key comes from the user's passphrase via PBKDF2-HMAC-SHA256.
class BackupCodec {
  static const fileName = 'bills-o9-backup.b9';
  static const _magic = [0x42, 0x39, 0x54, 0x31]; // B9T1
  static const _iterations = 100000;

  static Future<SecretKey> _key(String passphrase, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt);

  static Future<Uint8List> encode(
      Map<String, dynamic> data, String passphrase) async {
    final json = utf8.encode(jsonEncode(data));
    final packed = GZipEncoder().encode(json, level: 9)!;
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final box = await AesGcm.with256bits()
        .encrypt(packed, secretKey: await _key(passphrase, salt));
    return Uint8List.fromList([
      ..._magic,
      ...salt,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  static bool looksLikeBackup(List<int> bytes) =>
      bytes.length > 48 &&
      bytes[0] == _magic[0] &&
      bytes[1] == _magic[1] &&
      bytes[2] == _magic[2] &&
      bytes[3] == _magic[3];

  static Future<Map<String, dynamic>> decode(
      List<int> bytes, String passphrase) async {
    if (!looksLikeBackup(bytes)) throw NotABackup();
    final salt = bytes.sublist(4, 20);
    final nonce = bytes.sublist(20, 32);
    final mac = bytes.sublist(32, 48);
    final cipherText = bytes.sublist(48);
    final List<int> clear;
    try {
      clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: await _key(passphrase, salt),
      );
    } on SecretBoxAuthenticationError {
      throw WrongPassphrase();
    }
    final json = utf8.decode(GZipDecoder().decodeBytes(clear));
    final data = jsonDecode(json);
    if (data is! Map || data['t'] is! Map) throw NotABackup();
    return data.cast<String, dynamic>();
  }
}
