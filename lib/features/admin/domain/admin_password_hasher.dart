import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Client-side helpers that match the Cloud Function password hashing.
class AdminPasswordHasher {
  AdminPasswordHasher._();

  static const minLength = 8;
  static final _complexity = RegExp('[0-9!@#%^&*(),.?":{}|<>]');

  static String hash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool hasComplexity(String password) =>
      _complexity.hasMatch(password.trim());

  static bool meetsPolicy(String password) {
    final value = password.trim();
    return value.length >= minLength && hasComplexity(value);
  }

  static String? policyError(String? password) {
    final value = password?.trim() ?? '';
    if (value.isEmpty) return 'Please enter a new password';
    if (value.length < minLength) {
      return 'Password must be at least 8 characters';
    }
    if (!_complexity.hasMatch(value)) {
      return 'Include a number or special character';
    }
    return null;
  }
}
