class YoutubeThumbnailUtils {
  static final RegExp _ytImgVideoRegExp = RegExp(
    r'/(?:vi|vi_webp)/([A-Za-z0-9_-]{11})/',
  );
  static final RegExp _watchVideoRegExp = RegExp(r'[?&]v=([A-Za-z0-9_-]{11})');
  static final RegExp _shortUrlRegExp = RegExp(
    r'youtu\.be/([A-Za-z0-9_-]{11})',
  );
  static final RegExp _embedVideoRegExp = RegExp(r'/embed/([A-Za-z0-9_-]{11})');
  static final RegExp _videoIdRegExp = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static String bestInitialUrl({
    required String videoId,
    String? preferredUrl,
  }) {
    final candidates = candidateUrls(
      songId: 'yt:$videoId',
      imageUrl: preferredUrl,
    );
    if (candidates.isEmpty) return '';

    for (final url in candidates) {
      if (url.contains('/sddefault.jpg')) return url;
    }
    for (final url in candidates) {
      if (url.contains('/hqdefault.jpg')) return url;
    }
    return candidates.first;
  }

  static List<String> candidateUrls({String? songId, String? imageUrl}) {
    final videoId = videoIdFromSongId(songId) ?? videoIdFromUrl(imageUrl);
    final ordered = <String>{};

    void add(String? raw) {
      final normalized = _normalizeUrl(raw);
      if (normalized.isNotEmpty) ordered.add(normalized);
    }

    if (videoId != null) {
      add('https://i.ytimg.com/vi/$videoId/maxresdefault.jpg');
      add('https://i.ytimg.com/vi/$videoId/sddefault.jpg');
      add('https://i.ytimg.com/vi/$videoId/hq720.jpg');
      add('https://i.ytimg.com/vi/$videoId/hqdefault.jpg');
      add('https://i.ytimg.com/vi/$videoId/mqdefault.jpg');
      add('https://i.ytimg.com/vi/$videoId/default.jpg');
    }

    add(imageUrl);

    if (videoId != null) {
      add('https://i.ytimg.com/vi_webp/$videoId/maxresdefault.webp');
      add('https://i.ytimg.com/vi_webp/$videoId/sddefault.webp');
      add('https://i.ytimg.com/vi_webp/$videoId/hqdefault.webp');
    }

    return ordered.toList(growable: false);
  }

  static String? videoIdFromSongId(String? songId) {
    if (songId == null) return null;
    final raw = songId.trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('yt:')) {
      final id = raw.substring(3).trim();
      return _isVideoId(id) ? id : null;
    }

    final lower = raw.toLowerCase();
    final looksLikeYoutubeRef =
        lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('ytimg.com') ||
        lower.contains('/vi/') ||
        lower.contains('/vi_webp/');
    if (!looksLikeYoutubeRef) return null;

    return videoIdFromUrl(raw);
  }

  static String? videoIdFromUrl(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (_isVideoId(text)) return text;

    final ytImgMatch = _ytImgVideoRegExp.firstMatch(text);
    if (ytImgMatch != null) {
      final id = ytImgMatch.group(1);
      if (_isVideoId(id)) return id;
    }

    final watchMatch = _watchVideoRegExp.firstMatch(text);
    if (watchMatch != null) {
      final id = watchMatch.group(1);
      if (_isVideoId(id)) return id;
    }

    final shortMatch = _shortUrlRegExp.firstMatch(text);
    if (shortMatch != null) {
      final id = shortMatch.group(1);
      if (_isVideoId(id)) return id;
    }

    final embedMatch = _embedVideoRegExp.firstMatch(text);
    if (embedMatch != null) {
      final id = embedMatch.group(1);
      if (_isVideoId(id)) return id;
    }

    return null;
  }

  static bool _isVideoId(String? value) {
    if (value == null) return false;
    return _videoIdRegExp.hasMatch(value);
  }

  static String _normalizeUrl(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://')) {
      return trimmed.replaceFirst('http://', 'https://');
    }
    return trimmed;
  }
}
