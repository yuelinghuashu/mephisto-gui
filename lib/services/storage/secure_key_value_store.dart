/// 安全键值存储薄封装
///
/// 抽象 [FlutterSecureStorage] 为极简接口，主要目的：
///   - 供 LLM 配置等敏感字段使用系统级安全存储（Android Keystore /
///     iOS/macOS Keychain / Windows DPAPI / Linux libsecret）
///   - 隔离第三方库：`FlutterSecureStorage` 为 final class 无法直接 mock，
///     抽接口后单元测试可注入 [FakeSecureKeyValueStore] 验证读写逻辑
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全键值存储接口（可测试）。
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// 基于 [FlutterSecureStorage] 的真实实现。
class SecureKeyValueStoreImpl implements SecureKeyValueStore {
  const SecureKeyValueStoreImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
