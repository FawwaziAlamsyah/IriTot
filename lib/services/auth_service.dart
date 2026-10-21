import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyUsername = 'iritot_auth_username';
  static const String _keyPassword = 'iritot_auth_password';
  static const String _keyIsLoggedIn = 'iritot_auth_is_logged_in';
  static const String _keyRememberMe = 'iritot_auth_remember_me';
  static const String _keyLastActiveTimestamp = 'iritot_auth_last_active_timestamp';

  // Batas waktu sesi di latar belakang: 5 menit (300.000 milidetik)
  static const int sessionTimeoutMs = 5 * 60 * 1000;

  static const String defaultUsername = 'usertest';
  static const String defaultPassword = 'iritot123';

  final SharedPreferences _prefs;

  AuthService(this._prefs);

  static Future<AuthService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = AuthService(prefs);
    await service._initDefaultCredentialsIfNeeded();
    return service;
  }

  Future<void> _initDefaultCredentialsIfNeeded() async {
    if (!_prefs.containsKey(_keyUsername)) {
      await _prefs.setString(_keyUsername, defaultUsername);
    }
    if (!_prefs.containsKey(_keyPassword)) {
      await _prefs.setString(_keyPassword, defaultPassword);
    }
  }

  String getUsername() {
    return _prefs.getString(_keyUsername) ?? defaultUsername;
  }

  String _getPassword() {
    return _prefs.getString(_keyPassword) ?? defaultPassword;
  }

  bool isLoggedIn() {
    final loggedIn = _prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!loggedIn) return false;

    // Jika sesi telah melewati 5 menit, anggap belum login
    if (isSessionExpired()) {
      return false;
    }
    return true;
  }

  bool isRememberMe() {
    return _prefs.getBool(_keyRememberMe) ?? true;
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

  Future<bool> login(String username, String password, {bool rememberMe = true}) async {
    final currentUsername = getUsername();
    final currentPassword = _getPassword();

    if (username.trim() == currentUsername && password == currentPassword) {
      await _prefs.setBool(_keyIsLoggedIn, true);
      await _prefs.setBool(_keyRememberMe, rememberMe);
      await updateLastActiveTimestamp();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _prefs.setBool(_keyIsLoggedIn, false);
    await _prefs.remove(_keyLastActiveTimestamp);
  }

  // Validasi dan Ubah Username & Password
  Future<Map<String, dynamic>> changeCredentials({
    required String oldUsername,
    required String oldPassword,
    required String newUsername,
    required String newPassword,
  }) async {
    final currentUsername = getUsername();
    final currentPassword = _getPassword();

    // 1. Validasi kredensial lama
    if (oldUsername.trim() != currentUsername) {
      return {
        'success': false,
        'message': 'Username lama tidak sesuai.',
      };
    }

    if (oldPassword != currentPassword) {
      return {
        'success': false,
        'message': 'Password lama salah.',
      };
    }

    // 2. Validasi input baru
    if (newUsername.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Username baru tidak boleh kosong.',
      };
    }

    if (newPassword.length < 4) {
      return {
        'success': false,
        'message': 'Password baru minimal 4 karakter.',
      };
    }

    // 3. Simpan kredensial baru ke database lokal
    await _prefs.setString(_keyUsername, newUsername.trim());
    await _prefs.setString(_keyPassword, newPassword);

    return {
      'success': true,
      'message': 'Username dan password berhasil diperbarui!',
    };
  }
}
