import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _levelKey = 'level';

  static Future<int> getSavedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelKey) ?? 1;
  }

  static Future<void> saveLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_levelKey, level);
  }
}
