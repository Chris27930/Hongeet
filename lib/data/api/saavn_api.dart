import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/saavn_song.dart';

class SaavnApi {
  static const String baseUrl = 'http://127.0.0.1:8080';

  static Future<List<SaavnSong>> searchSongs(String query) async {
    final res = await http.get(
      Uri.parse('$baseUrl/search/saavn?q=$query'),
    );

    if (res.statusCode != 200) {
      throw Exception('Saavn search failed');
    }

    final decoded = json.decode(res.body);
    final results = decoded['data']['results'] as List;

    return results
        .map((e) => SaavnSong.fromJson(e))
        .toList();
  }
}
