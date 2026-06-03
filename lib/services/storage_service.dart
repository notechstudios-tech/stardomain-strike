import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_save.dart';

class StorageService {
  static const _saveKey = 'game_save';

  static Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey);
  }

  static Future<GameSave?> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_saveKey);
    if (json == null) return null;
    try {
      return GameSave.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveGame(GameSave save) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, save.toJsonString());
  }

  static Future<void> clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }
}
