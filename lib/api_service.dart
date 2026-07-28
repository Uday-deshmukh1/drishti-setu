import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // For Android emulator, 10.0.2.2 maps to host localhost.
  // For physical device, replace with your电脑的 IP address.
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── Status & Hotspots ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStatus() async {
    final res = await http.get(Uri.parse('$baseUrl/status'));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getHotspots() async {
    final res = await http.get(Uri.parse('$baseUrl/hotspots'));
    return (jsonDecode(res.body)['hotspots'] as List);
  }

  // ── SOS ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendSOS({
    required double lat,
    required double lng,
    required String issueType,
    required String language,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        'issue_type': issueType,
        'language': language,
      }),
    );
    return jsonDecode(res.body);
  }

  // ── Alerts ─────────────────────────────────────────────────────────
  static Future<List<dynamic>> getActiveAlerts() async {
    final res = await http.get(Uri.parse('$baseUrl/alerts/active'));
    return (jsonDecode(res.body)['alerts'] as List);
  }

  // ── Volunteer Location ─────────────────────────────────────────────
  static Future<void> updateVolunteerLocation({
    required String volunteerId,
    required double lat,
    required double lng,
    required String name,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/volunteer/location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'volunteer_id': volunteerId,
        'lat': lat,
        'lng': lng,
        'name': name,
      }),
    );
  }

  static Future<List<dynamic>> getActiveVolunteers() async {
    final res = await http.get(Uri.parse('$baseUrl/volunteers/active'));
    return (jsonDecode(res.body)['volunteers'] as List);
  }

  // ── Assign Volunteer ───────────────────────────────────────────────
  static Future<void> assignVolunteer({
    required String alertId,
    required String volunteerId,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/volunteer/assign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'alert_id': alertId,
        'volunteer_id': volunteerId,
      }),
    );
  }
}
