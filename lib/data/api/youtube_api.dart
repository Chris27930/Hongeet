import 'dart:async';
import 'package:flutter/services.dart';
import '../models/saavn_song.dart';

class YoutubeApi {
  static const MethodChannel _channel = MethodChannel('youtube_extractor');

  static const Duration _searchTimeout = Duration(seconds: 16);
  static const Duration _searchFallbackTimeout = Duration(seconds: 10);
  static const Duration _relatedTimeout = Duration(seconds: 12);
  static const Duration _relatedFallbackTimeout = Duration(seconds: 8);

  static final Map<String, _TimedSongsCache> _searchCache = {};
  static final Map<String, _TimedSongsCache> _relatedCache = {};

  static Future<List<SaavnSong>> searchSongs(
    String query, {
    int take = 24,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final safeTake = take.clamp(2, 50);
    final cacheKey = '${normalized.toLowerCase()}::$safeTake';

    final cached = _searchCache[cacheKey];
    if (cached != null && !cached.isExpired(const Duration(minutes: 2))) {
      return cached.songs;
    }

    List<SaavnSong> songs = const [];
    try {
      songs = await _search(
        normalized,
        take: safeTake,
        timeout: _searchTimeout,
      );
    } catch (_) {
      final fallbackTake = safeTake >= 24 ? 22 : safeTake;
      songs = await _search(
        normalized,
        take: fallbackTake,
        timeout: _searchFallbackTimeout,
      );
    }

    final normalizedSongs = List<SaavnSong>.unmodifiable(songs);
    _searchCache[cacheKey] = _TimedSongsCache(normalizedSongs);
    _trimCache(_searchCache, maxEntries: 60);
    return normalizedSongs;
  }

  static Future<List<SaavnSong>> relatedSongs(
    String videoId, {
    int take = 10,
  }) async {
    final normalized = videoId.trim();
    if (normalized.isEmpty) return const [];

    final safeTake = take.clamp(1, 50);
    final cacheKey = '${normalized.toLowerCase()}::$safeTake';

    final cached = _relatedCache[cacheKey];
    if (cached != null && !cached.isExpired(const Duration(minutes: 5))) {
      return cached.songs;
    }

    List<SaavnSong> songs = const [];
    try {
      songs = await _related(
        normalized,
        take: safeTake,
        timeout: _relatedTimeout,
      );
    } catch (_) {
      final fallbackTake = (safeTake - 2).clamp(1, safeTake);
      songs = await _related(
        normalized,
        take: fallbackTake,
        timeout: _relatedFallbackTimeout,
      );
    }

    final normalizedSongs = List<SaavnSong>.unmodifiable(songs);
    _relatedCache[cacheKey] = _TimedSongsCache(normalizedSongs);
    _trimCache(_relatedCache, maxEntries: 100);
    return normalizedSongs;
  }

  static Future<List<SaavnSong>> _search(
    String query, {
    required int take,
    required Duration timeout,
  }) async {
    final dynamic response = await _channel
        .invokeMethod<dynamic>('search', {'query': query, 'take': take})
        .timeout(timeout);

    return _coerceSongs(response);
  }

  static Future<List<SaavnSong>> _related(
    String videoId, {
    required int take,
    required Duration timeout,
  }) async {
    final dynamic response = await _channel
        .invokeMethod<dynamic>('related', {'videoId': videoId, 'take': take})
        .timeout(timeout);

    return _coerceSongs(response);
  }

  static List<SaavnSong> _coerceSongs(dynamic response) {
    if (response is! List) return const [];

    final songs = <SaavnSong>[];
    final seen = <String>{};

    for (final item in response) {
      if (item is! Map) continue;
      final song = _mapToSaavnSong(item);
      if (song == null) continue;
      if (seen.add(song.id)) songs.add(song);
    }
    return songs;
  }

  static SaavnSong? _mapToSaavnSong(Map raw) {
    final idRaw = (raw['id'] ?? '').toString().trim();
    final title = (raw['name'] ?? raw['title'] ?? '').toString().trim();
    if (idRaw.isEmpty || title.isEmpty) return null;

    final id = idRaw.startsWith('yt:') ? idRaw : 'yt:$idRaw';
    final artist = (raw['author'] ?? raw['artists'] ?? 'Unknown')
        .toString()
        .trim();
    final imageUrl = (raw['thumbnail'] ?? '').toString().trim();

    final durationRaw = raw['duration'];
    int? duration;
    if (durationRaw is num) {
      duration = durationRaw.toInt();
    } else if (durationRaw is String) {
      duration = int.tryParse(durationRaw);
    }

    return SaavnSong(
      id: id,
      name: title,
      artists: artist.isEmpty ? 'Unknown' : artist,
      imageUrl: imageUrl,
      duration: duration,
      downloadUrls: const [],
    );
  }

  static void _trimCache(
    Map<String, _TimedSongsCache> cache, {
    required int maxEntries,
  }) {
    if (cache.length <= maxEntries) return;
    final keys = cache.keys.toList(growable: false);
    final removeCount = cache.length - maxEntries;
    for (var i = 0; i < removeCount; i++) {
      cache.remove(keys[i]);
    }
  }
}

class _TimedSongsCache {
  final DateTime timestamp;
  final List<SaavnSong> songs;

  _TimedSongsCache(this.songs) : timestamp = DateTime.now();

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }
}
