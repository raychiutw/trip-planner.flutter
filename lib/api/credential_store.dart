/// 「用生物辨識登入」要重送的 email 與密碼（僅存這台裝置的 Keychain）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class SavedCredentials {
  const SavedCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

abstract class CredentialStore {
  Future<SavedCredentials?> read();
  Future<void> write(SavedCredentials credentials);
  Future<void> clear();
}

/// 正式實作：flutter_secure_storage。`unlocked_this_device` 不進 iCloud 備份、
/// 不遷移到別台裝置，裝置鎖定時讀不到。
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _emailKey = 'tripline_saved_email';
  static const _passwordKey = 'tripline_saved_password';
  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<SavedCredentials?> read() async {
    final email = await _storage.read(key: _emailKey, iOptions: _ios);
    final password = await _storage.read(key: _passwordKey, iOptions: _ios);
    if (email == null || password == null) return null;
    return SavedCredentials(email: email, password: password);
  }

  @override
  Future<void> write(SavedCredentials credentials) async {
    await _storage.write(
      key: _emailKey,
      value: credentials.email,
      iOptions: _ios,
    );
    await _storage.write(
      key: _passwordKey,
      value: credentials.password,
      iOptions: _ios,
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _emailKey, iOptions: _ios);
    await _storage.delete(key: _passwordKey, iOptions: _ios);
  }
}

class InMemoryCredentialStore implements CredentialStore {
  SavedCredentials? _saved;

  @override
  Future<SavedCredentials?> read() async => _saved;

  @override
  Future<void> write(SavedCredentials credentials) async =>
      _saved = credentials;

  @override
  Future<void> clear() async => _saved = null;
}

/// 預設記憶體版；App 於 main() override 成 [SecureCredentialStore]。
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => InMemoryCredentialStore(),
);
