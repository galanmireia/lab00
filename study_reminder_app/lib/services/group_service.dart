import 'package:shared_preferences/shared_preferences.dart';

class GroupService {
  static const _tokenKey = 'group_token';

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Forgets the group locally. The person can always do this themselves —
  /// there's no way for whoever assigns tasks to prevent it.
  Future<void> leaveGroup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
