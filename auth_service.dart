import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class AuthResult {
  final bool success;
  final String message;
  AuthResult(this.success, this.message);
}

class AuthService {
  /// Hashes a password using SHA-256.
  /// Note: for production, prefer bcrypt via a server-side function.
  /// SHA-256 here keeps everything client-side simple for an MVP.
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Signup flow:
  /// 1. Check register number exists in whitelist and is not used
  /// 2. Check name roughly matches (case-insensitive)
  /// 3. Create user record
  /// 4. Mark whitelist entry as used
  static Future<AuthResult> signup({
    required String registerNo,
    required String name,
    required String batch,
    required String password,
  }) async {
    try {
      final regNo = registerNo.trim().toUpperCase();

      // Step 1: Check whitelist
      final whitelistResult = await supabase
          .from('valid_register_numbers')
          .select()
          .eq('register_no', regNo)
          .maybeSingle();

      if (whitelistResult == null) {
        return AuthResult(false, 'Register number not found. Contact admin if you believe this is an error.');
      }

      if (whitelistResult['is_used'] == true) {
        return AuthResult(false, 'This register number is already registered. Try logging in instead.');
      }

      // Step 2: Loose name match (case-insensitive, ignore extra spaces)
      final whitelistName = (whitelistResult['name'] as String).trim().toLowerCase();
      final enteredName = name.trim().toLowerCase();
      if (whitelistName != enteredName) {
        return AuthResult(false, 'Name does not match our records for this register number.');
      }

      // Step 3: Check no duplicate in users table (extra safety)
      final existingUser = await supabase
          .from('users')
          .select('uid')
          .eq('register_no', regNo)
          .maybeSingle();

      if (existingUser != null) {
        return AuthResult(false, 'An account already exists for this register number.');
      }

      // Step 4: Create user
      final department = whitelistResult['department'] as String?;
      final hashedPassword = _hashPassword(password);

      final inserted = await supabase.from('users').insert({
        'register_no': regNo,
        'name': name.trim(),
        'department': department,
        'batch': batch,
        'app_password_hash': hashedPassword,
      }).select().single();

      // Step 5: Mark whitelist as used
      await supabase
          .from('valid_register_numbers')
          .update({'is_used': true})
          .eq('register_no', regNo);

      // Save session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', inserted['uid']);
      await prefs.setString('name', inserted['name']);
      await prefs.setString('register_no', inserted['register_no']);
      await prefs.setString('department', inserted['department'] ?? '');
      await prefs.setString('batch', inserted['batch'] ?? '');

      return AuthResult(true, 'Account created successfully');
    } catch (e) {
      return AuthResult(false, 'Signup failed: ${e.toString()}');
    }
  }

  /// Login flow: check register number + password hash match
  static Future<AuthResult> login({
    required String registerNo,
    required String password,
  }) async {
    try {
      final regNo = registerNo.trim().toUpperCase();
      final hashedPassword = _hashPassword(password);

      final user = await supabase
          .from('users')
          .select()
          .eq('register_no', regNo)
          .maybeSingle();

      if (user == null) {
        return AuthResult(false, 'No account found for this register number.');
      }

      if (user['app_password_hash'] != hashedPassword) {
        return AuthResult(false, 'Incorrect password.');
      }

      // Save session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', user['uid']);
      await prefs.setString('name', user['name']);
      await prefs.setString('register_no', user['register_no']);
      await prefs.setString('department', user['department'] ?? '');
      await prefs.setString('batch', user['batch'] ?? '');

      return AuthResult(true, 'Login successful');
    } catch (e) {
      return AuthResult(false, 'Login failed: ${e.toString()}');
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<Map<String, String>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'uid': prefs.getString('uid') ?? '',
      'name': prefs.getString('name') ?? '',
      'register_no': prefs.getString('register_no') ?? '',
      'department': prefs.getString('department') ?? '',
      'batch': prefs.getString('batch') ?? '',
    };
  }
}
