import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  static Future<void> saveToken(String token) async {
    await _prefs?.setString(AppConstants.tokenKey, token);
  }

  static String? getToken() {
    return _prefs?.getString(AppConstants.tokenKey);
  }

  static Future<void> removeToken() async {
    await _prefs?.remove(AppConstants.tokenKey);
  }

  // User management
  static Future<void> saveUser(UserModel user) async {
    await _prefs?.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  static UserModel? getUser() {
    final userStr = _prefs?.getString(AppConstants.userKey);
    if (userStr != null && userStr.isNotEmpty) {
      try {
        final Map<String, dynamic> json = jsonDecode(userStr);
        return UserModel.fromJson(json);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> removeUser() async {
    await _prefs?.remove(AppConstants.userKey);
  }

  // Conversation history management
  static List<int> getConversationHistoryIds() {
    final list = _prefs?.getStringList('messagerie_history_ids') ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }

  static Future<void> saveConversationHistoryIds(List<int> ids) async {
    await _prefs?.setStringList('messagerie_history_ids', ids.map((e) => e.toString()).toList());
  }

  // Year selection management
  static Future<void> saveSelectedYear(String year) async {
    await _prefs?.setString('selected_annee', year);
  }

  static String? getSelectedYear() {
    return _prefs?.getString('selected_annee');
  }

  // Clear all
  static Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
