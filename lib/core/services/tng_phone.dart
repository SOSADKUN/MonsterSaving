import '../localization/strings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TngPhone {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String normalize(String input) {
    var n = input.replaceAll(RegExp(r'[\s()+-]'), '');
    if (n.startsWith('60')) n = '0${n.substring(2)}';
    if (!RegExp(r'^01\d{8,9}$').hasMatch(n)) {
      throw FormatException(tr('tng_phone.001'));
    }
    return n;
  }

  static String password(String phone) => normalize(phone).substring(1);
  Future<String?> read() => _storage.read(key: 'tng_phone_v1');
  Future<void> save(String phone) =>
      _storage.write(key: 'tng_phone_v1', value: normalize(phone));
  Future<void> clear() => _storage.delete(key: 'tng_phone_v1');
}
