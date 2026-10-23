import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyUsername = 'iritot_auth_username';
  static const String _keyPassword = 'iritot_auth_password';
  static const String _keyDisplayName = 'iritot_auth_display_name';
  static const String _keyIsLoggedIn = 'iritot_auth_is_logged_in';
  static const String _keyRememberMe = 'iritot_auth_remember_me';
  static const String _keySavedUsername = 'iritot_auth_saved_username';
  static const String _keyLastActiveTimestamp = 'iritot_auth_last_active_timestamp';

  // Batas waktu sesi di latar belakang: 5 menit (300.000 milidetik)
  static const int sessionTimeoutMs = 5 * 60 * 1000;

  static const String defaultUsername = 'NewUser';
  static const String defaultDisplayName = 'NewUser';
  static const String defaultPassword = 'iritot123';

  final SharedPreferences _prefs;

  AuthService(this._prefs);

  static Future<AuthService> init([SharedPreferences? existingPrefs]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    final service = AuthService(prefs);
    await service._initDefaultCredentialsIfNeeded();
    return service;
  }

  Future<void> _initDefaultCredentialsIfNeeded() async {
    final currentUsername = _prefs.getString(_keyUsername);
    if (currentUsername == null || currentUsername == 'usertest') {
      await _prefs.setString(_keyUsername, defaultUsername);
    }
    if (!_prefs.containsKey(_keyDisplayName)) {
      await _prefs.setString(_keyDisplayName, defaultDisplayName);
    }
    if (!_prefs.containsKey(_keyPassword)) {
      await _prefs.setString(_keyPassword, defaultPassword);
    }
    if (!_prefs.containsKey(_keyRememberMe)) {
      await _prefs.setBool(_keyRememberMe, true);
    }
    if (!_prefs.containsKey(_keySavedUsername) && (_prefs.getBool(_keyRememberMe) ?? true)) {
      await _prefs.setString(_keySavedUsername, defaultUsername);
    }
  }

  String getUsername() {
    return _prefs.getString(_keyUsername) ?? defaultUsername;
  }

  String getDisplayName() {
    final name = _prefs.getString(_keyDisplayName);
    if (name != null && name.trim().isNotEmpty) return name;
    return getUsername();
  }

  Future<void> setDisplayName(String displayName) async {
    await _prefs.setString(_keyDisplayName, displayName.trim());
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

  String? getSavedUsername() {
    if (!isRememberMe()) return null;
    return _prefs.getString(_keySavedUsername) ?? getUsername();
  }

  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(_keyRememberMe, value);
    if (!value) {
      await _prefs.remove(_keySavedUsername);
    } else {
      await _prefs.setString(_keySavedUsername, getUsername());
    }
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
    final currentUsername = getUsername().trim().toLowerCase();
    final inputUser = username.trim().toLowerCase();
    final currentPassword = _getPassword();

    final matchesUser = inputUser == currentUsername || (currentUsername == 'newuser' && inputUser == 'usertest');

    if (matchesUser && password == currentPassword) {
      await _prefs.setBool(_keyIsLoggedIn, true);
      await _prefs.setBool(_keyRememberMe, rememberMe);
      if (rememberMe) {
        await _prefs.setString(_keySavedUsername, username.trim());
      } else {
        await _prefs.remove(_keySavedUsername);
      }
      await updateLastActiveTimestamp();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _prefs.setBool(_keyIsLoggedIn, false);
    await _prefs.remove(_keyLastActiveTimestamp);
  }

  // Update profil: Nama Tampilan, Username, dan opsional Password
  Future<Map<String, dynamic>> updateProfile({
    required String newDisplayName,
    required String newUsername,
    String? oldPassword,
    String? newPassword,
  }) async {
    final trimmedName = newDisplayName.trim();
    final trimmedUser = newUsername.trim();

    if (trimmedName.isEmpty) {
      return {
        'success': false,
        'message': 'Nama tampilan tidak boleh kosong.',
      };
    }

    if (trimmedUser.isEmpty) {
      return {
        'success': false,
        'message': 'Username akun tidak boleh kosong.',
      };
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      final currentPassword = _getPassword();
      if (oldPassword == null || oldPassword != currentPassword) {
        return {
          'success': false,
          'message': 'Kata sandi saat ini salah.',
        };
      }
      if (newPassword.length < 4) {
        return {
          'success': false,
          'message': 'Kata sandi baru minimal 4 karakter.',
        };
      }
      await _prefs.setString(_keyPassword, newPassword);
    }

    await _prefs.setString(_keyDisplayName, trimmedName);
    await _prefs.setString(_keyUsername, trimmedUser);
    if (isRememberMe()) {
      await _prefs.setString(_keySavedUsername, trimmedUser);
    }

    return {
      'success': true,
      'message': 'Profil berhasil diperbarui!',
    };
  }

  // Validasi dan Ubah Username & Password (kompatibilitas lama)
  Future<Map<String, dynamic>> changeCredentials({
    required String oldUsername,
    required String oldPassword,
    required String newUsername,
    required String newPassword,
    String? newDisplayName,
  }) async {
    final currentUsername = getUsername();
    final currentPassword = _getPassword();

    // 1. Validasi kredensial lama
    final matchesOldUser = oldUsername.trim().toLowerCase() == currentUsername.toLowerCase() ||
        (currentUsername.toLowerCase() == 'newuser' && oldUsername.trim().toLowerCase() == 'usertest');

    if (!matchesOldUser) {
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
    if (isRememberMe()) {
      await _prefs.setString(_keySavedUsername, newUsername.trim());
    }
    if (newDisplayName != null && newDisplayName.trim().isNotEmpty) {
      await _prefs.setString(_keyDisplayName, newDisplayName.trim());
    }

    return {
      'success': true,
      'message': 'Username dan password berhasil diperbarui!',
    };
  }
}
