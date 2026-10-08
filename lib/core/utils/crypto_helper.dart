import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../constants/app_constants.dart';

class CryptoHelper {
  /// Decrypts CryptoJS AES ciphertext (OpenSSL format: Salted__ + salt + ciphertext)
  static String? decryptCryptoJS(String? ciphertextBase64, [String? passphrase]) {
    if (ciphertextBase64 == null || ciphertextBase64.trim().isEmpty) return null;
    final secret = passphrase ?? AppConstants.secureKey;

    try {
      final cipherBytes = base64.decode(ciphertextBase64.trim());
      if (cipherBytes.length < 16) return null;

      // Check for "Salted__" header (0x53, 0x61, 0x6C, 0x74, 0x65, 0x64, 0x5F, 0x5F)
      final prefix = utf8.decode(cipherBytes.sublist(0, 8), allowMalformed: true);
      if (prefix == 'Salted__') {
        final salt = cipherBytes.sublist(8, 16);
        final encrypted = cipherBytes.sublist(16);

        // OpenSSL EVP_BytesToKey with MD5 derivation
        final passBytes = utf8.encode(secret);
        final d = <int>[];
        var dI = <int>[];

        // d_0 = MD5(passphrase + salt)
        dI = md5.convert([...passBytes, ...salt]).bytes;
        d.addAll(dI);

        // d_1 = MD5(d_0 + passphrase + salt)
        dI = md5.convert([...dI, ...passBytes, ...salt]).bytes;
        d.addAll(dI);

        // d_2 = MD5(d_1 + passphrase + salt)
        dI = md5.convert([...dI, ...passBytes, ...salt]).bytes;
        d.addAll(dI);

        final key = Uint8List.fromList(d.sublist(0, 32));
        final iv = Uint8List.fromList(d.sublist(32, 48));

        final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc, padding: 'PKCS7'));
        final decrypted = encrypter.decrypt(enc.Encrypted(Uint8List.fromList(encrypted)), iv: enc.IV(iv));
        return decrypted;
      }
    } catch (_) {}
    return null;
  }
}
