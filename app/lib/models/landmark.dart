/// Represents a single Smart Geo-Tagged Landmark as returned by
/// GET /api.php?action=get_landmarks
///
/// This same model is used for:
///  - the object we get straight from the network (fresh)
///  - the object we read back out of the local sqflite cache (offline)
/// so the rest of the app never has to care whether the data came from
/// the internet or from disk.
class Landmark {
  final int id;
  final String title;
  final double lat;
  final double lon;
  final String? image; // relative path, e.g. "uploads/123_456.jpg"
  final bool isActive; // false => soft-deleted, should not be shown
  final int visitCount;
  final double avgDistance;
  final double score; // server-computed, higher is better

  Landmark({
    required this.id,
    required this.title,
    required this.lat,
    required this.lon,
    required this.image,
    required this.isActive,
    required this.visitCount,
    required this.avgDistance,
    required this.score,
  });

  /// Build a Landmark from the JSON the API returns.
  /// The API is a bit loose with number types (ints vs strings), so every
  /// field is parsed defensively instead of trusting an exact JSON type.
  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: _asInt(json['id']),
      title: (json['title'] ?? '').toString(),
      lat: _asDouble(json['lat']),
      lon: _asDouble(json['lon']),
      image: json['image']?.toString(),
      isActive: _asInt(json['is_active'], fallback: 1) == 1,
      visitCount: _asInt(json['visit_count']),
      avgDistance: _asDouble(json['avg_distance']),
      score: _asDouble(json['score']),
    );
  }

  /// Build a Landmark from a row of our local sqflite cache table.
  factory Landmark.fromMap(Map<String, dynamic> map) {
    return Landmark(
      id: _asInt(map['id']),
      title: (map['title'] ?? '').toString(),
      lat: _asDouble(map['lat']),
      lon: _asDouble(map['lon']),
      image: map['image']?.toString(),
      isActive: _asInt(map['is_active'], fallback: 1) == 1,
      visitCount: _asInt(map['visit_count']),
      avgDistance: _asDouble(map['avg_distance']),
      score: _asDouble(map['score']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'lat': lat,
      'lon': lon,
      'image': image,
      'is_active': isActive ? 1 : 0,
      'visit_count': visitCount,
      'avg_distance': avgDistance,
      'score': score,
    };
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }
}
