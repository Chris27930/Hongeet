import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentlyPlayedCache {
  static const _key = 'recently_played';
  static const _maxItems = 20;

  static Future<void> add(Map<String, dynamic> song) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    raw.removeWhere((e) => jsonDecode(e)['id'] == song['id']);
    raw.insert(0, jsonEncode(song));

    if (raw.length > _maxItems) {
      raw.removeLast();
    }

    await prefs.setStringList(_key, raw);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }
}
