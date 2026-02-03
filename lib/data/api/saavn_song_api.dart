import 'dart:convert';
import 'package:http/http.dart' as http;

class SaavnSongApi {
  static const String baseUrl = 'http://127.0.0.1:8080';

  /// Returns the highest-quality stream URL from downloadUrl[]
  static Future<String> fetchBestStreamUrl(String songId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/song/saavn/$songId'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch song details');
    }

    final decoded = json.decode(res.body);
    final data = decoded['data'] as List;
    if (data.isEmpty) throw Exception('No song data');

    final song = data.first;
    final urls = song['downloadUrl'] as List? ?? [];
    if (urls.isEmpty) throw Exception('No stream URLs');

    // pick highest quality
    final best = urls.last;
    return best['url'];
  }
}
