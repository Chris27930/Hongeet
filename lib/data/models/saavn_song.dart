class SaavnSong {
  final String id;
  final String name;
  final String artists;
  final String imageUrl;
  final int? duration;
  final List<Map<String, String>> downloadUrls;

  SaavnSong({
    required this.id,
    required this.name,
    required this.artists,
    required this.imageUrl,
    required this.duration,
    required this.downloadUrls,
  });

  factory SaavnSong.fromJson(Map<String, dynamic> json) {
    final images = json['image'] as List? ?? [];
    final imageUrl = images.isNotEmpty
        ? images.last['url'] ?? ''
        : '';

    final primaryArtists =
        json['artists']?['primary'] as List? ?? [];

    final artistNames = primaryArtists
        .map((a) => a['name'])
        .where((n) => n != null)
        .join(', ');

    final downloadUrlsRaw = json['downloadUrl'] as List? ?? [];
    final downloadUrls = downloadUrlsRaw.map<Map<String, String>>((d) {
      return {
        'quality': d['quality'] ?? '',
        'url': d['url'] ?? '',
      };
    }).toList();

    return SaavnSong(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      artists: artistNames.isNotEmpty ? artistNames : 'Unknown',
      imageUrl: imageUrl,
      duration: json['duration'],
      downloadUrls: downloadUrls,
    );
  }
}
