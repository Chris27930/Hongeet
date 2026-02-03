import 'dart:io';
import 'package:path/path.dart' as p;

class DownloadedSong {
  final String path;
  final String name;

  DownloadedSong(this.path, this.name);
}

class DownloadedSongsProvider {
  static Future<List<DownloadedSong>> load() async {
    final dir = Directory('/storage/emulated/0/Download/Hongit');

    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
      final ext = p.extension(f.path).toLowerCase();
      return ['.mp3', '.m4a', '.webm'].contains(ext);
    })
        .toList();

    return files
        .map((f) => DownloadedSong(f.path, p.basenameWithoutExtension(f.path)))
        .toList();
  }

  static Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }
}
