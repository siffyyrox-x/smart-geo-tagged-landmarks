import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/landmark.dart';
import '../models/job.dart';

/// Thrown for any non-2xx response from the API, or a malformed response
/// body. Screens catch this and show a friendly Toast/Snackbar/dialog
/// instead of crashing (Requirement 9: Error Handling).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thin wrapper around the faculty-provided REST API
/// (https://labs.anontech.info/cse489/exm3/api.php).
///
/// This is the ONLY place in the app that knows about HTTP / JSON / the
/// `action=` query-parameter routing style. Everything else (providers,
/// screens, background workers) talks to this class, never to `http`
/// directly - that keeps the rest of the app simple and easy to test.
class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String action, [Map<String, String>? extraQuery]) {
    return Uri.parse('$kApiBaseUrl/api.php').replace(queryParameters: {
      'action': action,
      'key': kApiKey,
      ...?extraQuery,
    });
  }

  /// Turns a non-2xx response into a readable ApiException.
  /// The API always answers errors as JSON like {"error": "..."}.
  Never _throwForResponse(http.BaseResponse response, String bodyForMessage) {
    if (response.statusCode == 403) {
      throw ApiException(
        'Your API key was rejected by the server (invalid or expired). '
        'Double check kApiKey in lib/config.dart.',
        statusCode: 403,
      );
    }
    String message = 'Request failed (HTTP ${response.statusCode}).';
    try {
      final decoded = jsonDecode(bodyForMessage);
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } catch (_) {
      // Body wasn't JSON - fall back to the generic message above.
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  /// GET ?action=get_landmarks
  Future<List<Landmark>> getLandmarks() async {
    final response = await _client.get(_uri('get_landmarks'));
    if (response.statusCode != 200) {
      _throwForResponse(response, response.body);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw ApiException('Unexpected response shape for get_landmarks.');
    }
    return decoded
        .cast<Map<String, dynamic>>()
        .map((json) => Landmark.fromJson(json))
        .toList();
  }

  /// POST ?action=visit_landmark
  /// Body: { landmark_id, user_lat, user_lon }
  /// Returns the job_id the server assigned (status is always "pending"
  /// at this point - the distance is NOT available yet, see get_job_status).
  Future<int> visitLandmark({
    required int landmarkId,
    required double userLat,
    required double userLon,
  }) async {
    final response = await _client.post(
      _uri('visit_landmark'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'landmark_id': landmarkId,
        'user_lat': userLat,
        'user_lon': userLon,
      }),
    );
    if (response.statusCode != 200) {
      _throwForResponse(response, response.body);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final jobId = decoded['job_id'];
    if (jobId == null) {
      throw ApiException('Server did not return a job_id for this visit.');
    }
    return jobId is int ? jobId : int.parse(jobId.toString());
  }

  /// GET ?action=get_job_status&job_id=...
  /// Poll this (from a WorkManager task, never a blocking UI loop) until
  /// status is "done" or "failed".
  Future<VisitJob> getJobStatus(int jobId) async {
    final response = await _client.get(
      _uri('get_job_status', {'job_id': '$jobId'}),
    );
    if (response.statusCode == 404) {
      throw ApiException('Job not found (job_id=$jobId).', statusCode: 404);
    }
    if (response.statusCode != 200) {
      _throwForResponse(response, response.body);
    }
    return VisitJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// POST ?action=create_landmark
  /// MUST be multipart/form-data (the exam spec explicitly warns that a
  /// raw-JSON body leaves PHP's $_FILES empty server-side).
  /// Returns the new landmark's id.
  Future<int> createLandmark({
    required String title,
    required double lat,
    required double lon,
    File? imageFile,
  }) async {
    final request = http.MultipartRequest('POST', _uri('create_landmark'));
    request.fields['title'] = title;
    request.fields['lat'] = lat.toString();
    request.fields['lon'] = lon.toString();

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      _throwForResponse(response, response.body);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final id = decoded['id'];
    if (id == null) {
      throw ApiException('Server did not return an id for the new landmark.');
    }
    return id is int ? id : int.parse(id.toString());
  }

  /// POST ?action=delete_landmark (application/x-www-form-urlencoded, {id})
  Future<void> deleteLandmark(int id) async {
    final response = await _client.post(
      _uri('delete_landmark'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'id': '$id'},
    );
    if (response.statusCode != 200) {
      _throwForResponse(response, response.body);
    }
  }

  /// POST ?action=restore_landmark (application/x-www-form-urlencoded, {id})
  Future<void> restoreLandmark(int id) async {
    final response = await _client.post(
      _uri('restore_landmark'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'id': '$id'},
    );
    if (response.statusCode != 200) {
      _throwForResponse(response, response.body);
    }
  }

  void dispose() => _client.close();
}
