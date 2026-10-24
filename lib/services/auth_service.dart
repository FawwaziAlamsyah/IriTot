import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyPin = 'iritot_auth_pin';
  static const String _keyDisplayName = 'iritot_auth_display_name';
  static const String _keyIsLoggedIn = 'iritot_auth_is_logged_in';
  static const String _keyLastActiveTimestamp = 'iritot_auth_last_active_timestamp';

  // Batas waktu sesi di latar belakang: 5 menit (300.000 milidetik)
  static const int sessionTimeoutMs = 5 * 60 * 1000;

  static const String defaultDisplayName = 'NewUser';
  static const String defaultPin = '000000';

  final SharedPreferences _prefs;

  AuthService(this._prefs);

  static Future<AuthService> init([SharedPreferences? existingPrefs]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    final service = AuthService(prefs);
    await service._initDefaultCredentialsIfNeeded();
    return service;
  }

  Future<void> _initDefaultCredentialsIfNeeded() async {
    // Bersihkan data username & password lama jika sebelumnya tersimpan
    await _prefs.remove('iritot_auth_username');
    await _prefs.remove('iritot_auth_password');
    await _prefs.remove('iritot_auth_remember_me');
    await _prefs.remove('iritot_auth_saved_username');

    if (!_prefs.containsKey(_keyDisplayName)) {
      await _prefs.setString(_keyDisplayName, defaultDisplayName);
    }
    final existingPin = _prefs.getString(_keyPin);
    if (existingPin == null || existingPin == '0000') {
      await _prefs.setString(_keyPin, defaultPin);
    }
  }

  String getPin() {
    return _prefs.getString(_keyPin) ?? defaultPin;
  }

  String getDisplayName() {
    final name = _prefs.getString(_keyDisplayName);
    if (name != null && name.trim().isNotEmpty) return name;
    return defaultDisplayName;
  }

  Future<void> setDisplayName(String displayName) async {
    await _prefs.setString(_keyDisplayName, displayName.trim());
  }

  /// Verifikasi PIN
  bool verifyPin(String pin) => pin.trim() == getPin();

  bool isLoggedIn() {
    final loggedIn = _prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!loggedIn) return false;

    // Jika sesi telah melewati 5 menit, anggap belum login
    if (isSessionExpired()) {
      return false;
    }
    return true;
  }

  // Perbarui stempel waktu terakhir aktif
  Future<void> updateLastActiveTimestamp([int? timestampMs]) async {
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(_keyLastActiveTimestamp, ts);
  }

  int? getLastActiveTimestamp() {
    return _prefs.getInt(_keyLastActiveTimestamp);
  }

  // Periksa apakah sudah keluar/tidak aktif lebih dari 5 menit
  bool isSessionExpired([int? currentTimestampMs]) {
    final loggedIn = _prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!loggedIn) return false;

    final lastActive = getLastActiveTimestamp();
    if (lastActive == null) return false;

    final now = currentTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    return (now - lastActive) > sessionTimeoutMs;
  }

  // Kunci sesi otomatis karena batas waktu 5 menit tercapai
  Future<void> lockSessionDueToTimeout() async {
    await _prefs.setBool(_keyIsLoggedIn, false);
  }

  Future<bool> login(String pin) async {
    if (verifyPin(pin)) {
      await _prefs.setBool(_keyIsLoggedIn, true);
      await updateLastActiveTimestamp();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _prefs.setBool(_keyIsLoggedIn, false);
    await _prefs.remove(_keyLastActiveTimestamp);
  }

  // Update profil: Nama Tampilan dan opsional PIN baru 6 digit
  Future<Map<String, dynamic>> updateProfile({
    required String newDisplayName,
    String? oldPin,
    String? newPin,
  }) async {
    final trimmedName = newDisplayName.trim();

    if (trimmedName.isEmpty) {
      return {
        'success': false,
        'message': 'Nama tampilan tidak boleh kosong.',
      };
    }

    if (newPin != null && newPin.isNotEmpty) {
      final currentPin = getPin();
      if (oldPin == null || oldPin.trim() != currentPin) {
        return {
          'success': false,
          'message': 'PIN saat ini salah.',
        };
      }
      final cleanPin = newPin.trim();
      if (cleanPin.length != 6) {
        return {
          'success': false,
          'message': 'PIN baru harus 6 digit angka.',
        };
      }
      if (!RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
        return {
          'success': false,
          'message': 'PIN hanya boleh berisi angka.',
        };
      }
      await _prefs.setString(_keyPin, cleanPin);
    }

    await _prefs.setString(_keyDisplayName, trimmedName);

    return {
      'success': true,
      'message': 'Profil berhasil diperbarui!',
    };
  }

  // Validasi dan Ubah PIN Keamanan (harus 6 digit angka)
  Future<Map<String, dynamic>> changePin({
    required String oldPin,
    required String newPin,
    String? newDisplayName,
  }) async {
    final currentPin = getPin();

    if (oldPin.trim() != currentPin) {
      return {
        'success': false,
        'message': 'PIN lama salah.',
      };
    }

    final cleanPin = newPin.trim();
    if (cleanPin.length != 6) {
      return {
        'success': false,
        'message': 'PIN baru harus 6 digit angka.',
      };
    }
    if (!RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      return {
        'success': false,
        'message': 'PIN hanya boleh berisi angka.',
      };
    }

    await _prefs.setString(_keyPin, cleanPin);
    if (newDisplayName != null && newDisplayName.trim().isNotEmpty) {
      await _prefs.setString(_keyDisplayName, newDisplayName.trim());
    }

    return {
      'success': true,
      'message': 'PIN berhasil diperbarui!',
    };
  }
}
