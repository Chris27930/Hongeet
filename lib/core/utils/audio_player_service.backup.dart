import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/api/saavn_song_api.dart';
import '../../features/library/recently_played_cache.dart';

class NowPlaying {
  final String title;
  final String artist;
  final String imageUrl;

  NowPlaying({
    required this.title,
    required this.artist,
    required this.imageUrl,
  });
}

class QueuedSong {
  final String id;
  String? url;
  final NowPlaying meta;
  final bool isLocal;

  QueuedSong({
    required this.id,
    required this.meta,
    this.url,
    this.isLocal = false,
  });
}

class AudioPlayerService {
  int _playToken = 0;

  static final AudioPlayerService _instance =
  AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() {
    _player.currentIndexStream.listen(_onIndexChanged);
    _player.processingStateStream.listen(_onProcessingStateChanged);
    _player.setLoopMode(LoopMode.off);
    _loadRecentlyPlayed();
  }

  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist =
  ConcatenatingAudioSource(children: []);

  final List<QueuedSong> _queue = [];
  List<QueuedSong> get queue => List.unmodifiable(_queue);

  final _recentlyPlayedSubject = BehaviorSubject<List<Map<String, dynamic>>>();
  Stream<List<Map<String, dynamic>>> get recentlyPlayedStream =>
      _recentlyPlayedSubject.stream;

  final Map<String, _CachedUrl> _urlCache = {};
  final _nowPlaying = BehaviorSubject<NowPlaying?>();
  Stream<NowPlaying?> get nowPlayingStream => _nowPlaying.stream;

  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  int? get currentIndex => _player.currentIndex;

  Stream<PlayerState> get playerStateStream =>
      _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  LoopMode get loopMode => _player.loopMode;

  int _loadingGeneration = 0;
  bool _isLoading = false;

  final Set<int> _loadedIndices = {};

  Future<void> _loadRecentlyPlayed() async {
    final items = await RecentlyPlayedCache.getAll();
    _recentlyPlayedSubject.add(items);
  }

  Future<String> _resolveUrl(String id) async {
    if (_urlCache.containsKey(id)) {
      final cached = _urlCache[id]!;
      final age = DateTime.now().difference(cached.timestamp);
      if (age.inHours < 24) {
        return cached.url;
      } else {
        _urlCache.remove(id);
      }
    }
    final url = await SaavnSongApi.fetchBestStreamUrl(id);
    _urlCache[id] = _CachedUrl(url: url, timestamp: DateTime.now());
    if (_urlCache.length > 500) _cleanCache();
    return url;
  }

  void _cleanCache() {
    final entries = _urlCache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
    for (int i = 0; i < 100 && i < entries.length; i++) {
      _urlCache.remove(entries[i].key);
    }
  }

  Future<void> playFromList({
    required List<QueuedSong> songs,
    required int startIndex,
  }) async {
    if (songs.isEmpty) return;

    final safeIndex = startIndex.clamp(0, songs.length - 1);

    final int token = ++_playToken;

    if (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _isLoading = true;

    try {
      await _player.stop();

      _queue
        ..clear()
        ..addAll(songs);
      _loadedIndices.clear();
      await _playlist.clear();

      final song = _queue[safeIndex];
      final resolvedUrl = song.url ?? await _resolveUrl(song.id);

      if (token != _playToken) return;

      song.url = resolvedUrl;

      await _playlist.add(
        AudioSource.uri(Uri.parse(resolvedUrl)),
      );

      if (token != _playToken) return;

      await _player.setAudioSource(_playlist, initialIndex: 0);

      _nowPlaying.add(song.meta);
      await _player.play();

      _prefetchQueue(safeIndex, token);
    } finally {
      if (token == _playToken) {
        _isLoading = false;
      }
    }
  }

  Future<void> playNow(QueuedSong song) async {
    final int token = ++_playToken;

    if (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _isLoading = true;

    try {
      await _player.stop();

      _queue
        ..clear()
        ..add(song);
      _loadedIndices.clear();
      await _playlist.clear();

      final resolvedUrl = song.url ?? await _resolveUrl(song.id);

      if (token != _playToken) return;

      song.url = resolvedUrl;

      await _playlist.add(
        AudioSource.uri(Uri.parse(resolvedUrl)),
      );

      if (token != _playToken) return;

      await _player.setAudioSource(_playlist, initialIndex: 0);

      _nowPlaying.add(song.meta);
      await _player.play();
    } finally {
      if (token == _playToken) {
        _isLoading = false;
      }
    }
  }

  Future<void> playLocalFile(String path, String name) async {
    try {
      final song = QueuedSong(
          id: path,
          isLocal: true,
          meta: NowPlaying(title: name, artist: 'Offline', imageUrl: ''));
      _queue.clear();
      _queue.add(song);
      _loadedIndices.clear();
      await _playlist.clear();
      await _playlist.add(AudioSource.uri(Uri.file(path)));
      _loadedIndices.add(0);
      await _player.setAudioSource(_playlist, initialIndex: 0);
      _nowPlaying.add(song.meta);
      await _player.play();
    } catch (e) {
      print('❌ Error playing local file: $e');
    }
  }

  Future<void> playFromCache(Map<String, dynamic> song) async {
    final bool isLocal = song['isLocal'] ?? false;
    if (isLocal) {
      await playLocalFile(song['id'], song['title']);
    } else {
      final queued = QueuedSong(
        id: song['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        url: song['url'],
        meta: NowPlaying(
          title: song['title'],
          artist: song['artist'],
          imageUrl: song['imageUrl'],
        ),
      );
      await playNow(queued);
    }
  }

  Future<void> _prefetchQueue(int startIndex, int token) async {
    if (_queue.isEmpty) return;

    final int maxIndex = _queue.length - 1;
    final int safeStart = startIndex.clamp(0, maxIndex);

    const int prefetchCount = 3;

    for (int i = safeStart + 1;
    i <= maxIndex && i <= safeStart + prefetchCount;
    i++) {

      if (token != _playToken) return;

      if (_loadedIndices.contains(i)) continue;

      try {
        final song = _queue[i];
        final url = song.url ?? await _resolveUrl(song.id);

        if (token != _playToken) return;

        song.url = url;

        await _playlist.add(
          AudioSource.uri(Uri.parse(url)),
        );

        _loadedIndices.add(i);
      } catch (e) {
        print('❌ Failed to load song at index $i: $e');
      }
    }
  }

  Future<void> _ensureSongLoaded(int index) async {
    if (_loadedIndices.contains(index) || index >= _queue.length || index < 0) return;
    try {
      final song = _queue[index];
      song.url ??= await _resolveUrl(song.id);
      await _playlist.insert(index, AudioSource.uri(Uri.parse(song.url!)));
      _loadedIndices.add(index);
    } catch (e) {
      print('❌ Failed to load song at index $index: $e');
    }
  }

  void togglePlayPause() => _player.playing ? _player.pause() : _player.play();

  Future<void> skipNext() async {
    final nextIndex = (_player.currentIndex ?? 0) + 1;
    if (nextIndex < _queue.length) {
      await _ensureSongLoaded(nextIndex);
      if (_player.hasNext) await _player.seekToNext();
    }
  }

  Future<void> skipPrevious() async {
    final prevIndex = (_player.currentIndex ?? 0) - 1;
    if (prevIndex >= 0) {
      await _ensureSongLoaded(prevIndex);
      if (_player.hasPrevious) await _player.seekToPrevious();
    }
  }

  Future<void> jumpToIndex(int queueIndex) async {
    if (queueIndex < 0 || queueIndex >= _queue.length) return;
    await _ensureSongLoaded(queueIndex);
    if (_loadedIndices.contains(queueIndex)) {
      await _player.seek(Duration.zero, index: queueIndex);
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> toggleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off: await _player.setLoopMode(LoopMode.all); break;
      case LoopMode.all: await _player.setLoopMode(LoopMode.one); break;
      case LoopMode.one: await _player.setLoopMode(LoopMode.off); break;
    }
  }

  Future<void> setLoopMode(LoopMode mode) async => await _player.setLoopMode(mode);

  void _onIndexChanged(int? index) {
    if (index == null || index < 0 || index >= _queue.length) return;

    final song = _queue[index];
    _nowPlaying.add(song.meta);
    _addToRecentlyPlayed(song);

    _ensureSongLoaded(index + 1);
    _ensureSongLoaded(index + 2);
    _ensureSongLoaded(index + 3);
  }

  void _onProcessingStateChanged(ProcessingState state) {
    final currentIndex = _player.currentIndex;
    if (state == ProcessingState.buffering && currentIndex != null) {
      _ensureSongLoaded(currentIndex);
      _ensureSongLoaded(currentIndex + 1);
    }
    if (state == ProcessingState.ready && currentIndex != null) {
      _ensureSongLoaded(currentIndex + 1);
      _ensureSongLoaded(currentIndex + 2);
    }
  }

  Future<void> _addToRecentlyPlayed(QueuedSong song) async {
    final songMap = {
      'id': song.id,
      'url': song.url,
      'title': song.meta.title,
      'artist': song.meta.artist,
      'imageUrl': song.meta.imageUrl,
      'isLocal': song.isLocal,
    };
    await RecentlyPlayedCache.add(songMap);
    await _loadRecentlyPlayed();
  }

  void clearCache() {
    _urlCache.clear();
  }

  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int fresh = 0;
    int stale = 0;
    for (final entry in _urlCache.values) {
      final age = now.difference(entry.timestamp);
      if (age.inHours < 24) fresh++; else stale++;
    }
    return {'total': _urlCache.length, 'fresh': fresh, 'stale': stale};
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _nowPlaying.close();
    await _recentlyPlayedSubject.close();
  }
}

class _CachedUrl {
  final String url;
  final DateTime timestamp;
  _CachedUrl({required this.url, required this.timestamp});
}
