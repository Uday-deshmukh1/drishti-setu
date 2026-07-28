import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'crowd_detection_screen.dart';

class CrowdDashboardScreen extends StatefulWidget {
  const CrowdDashboardScreen({super.key});

  @override
  State<CrowdDashboardScreen> createState() => _CrowdDashboardScreenState();
}

class _CrowdDashboardScreenState extends State<CrowdDashboardScreen> {
  Timer? _timer;
  int _totalCount = 0;
  int _hotspotCount = 0;
  List<dynamic> _hotspots = [];
  List<dynamic> _alerts = [];
  List<dynamic> _volunteers = [];
  final MapController _mapCtrl = MapController();

  // Crowd trend history for analytics
  final List<FlSpot> _countHistory = [];
  int _historyIndex = 0;

  // Volunteer location sharing
  bool _sharingLocation = false;
  Timer? _shareTimer;
  String _volunteerId = '';
  String _volunteerName = '';

  // Thresholds
  static const int _greenMax = 50;
  static const int _yellowMax = 150;

  static const LatLng _center = LatLng(17.6800, 75.3300);

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    _loadVolunteerPrefs();
  }

  Future<void> _loadVolunteerPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _volunteerId = prefs.getString('volunteer_id') ?? '';
      _volunteerName = prefs.getString('staff_name') ?? '';
      _sharingLocation = prefs.getBool('sharing_location') ?? false;
    });
    if (_sharingLocation && _volunteerId.isNotEmpty) {
      _startSharing();
    }
  }

  Future<void> _refresh() async {
    try {
      final status = await ApiService.getStatus();
      final hotspots = await ApiService.getHotspots();
      final alerts = await ApiService.getActiveAlerts();
      final vols = await ApiService.getActiveVolunteers();
      if (!mounted) return;
      final count = status['total_count'] ?? 0;
      setState(() {
        _totalCount = count;
        _hotspotCount = status['active_hotspot_count'] ?? 0;
        _hotspots = hotspots;
        _alerts = alerts;
        _volunteers = vols;
        _countHistory.add(FlSpot(_historyIndex.toDouble(), count.toDouble()));
        if (_countHistory.length > 60) _countHistory.removeAt(0);
        _historyIndex++;
      });
    } catch (_) {}
  }

  // ── Volunteer location sharing ──────────────────────────────────────
  void _toggleSharing(bool value) async {
    if (value) {
      if (_volunteerName.isEmpty) {
        await _promptName();
        if (_volunteerName.isEmpty) return;
      }
      if (_volunteerId.isEmpty) {
        _volunteerId = DateTime.now().millisecondsSinceEpoch.toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('volunteer_id', _volunteerId);
      }
      setState(() => _sharingLocation = true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sharing_location', true);
      _startSharing();
    } else {
      _shareTimer?.cancel();
      setState(() => _sharingLocation = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sharing_location', false);
    }
  }

  void _startSharing() {
    _shareTimer?.cancel();
    _shareTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _sendLocation(),
    );
    _sendLocation();
  }

  Future<void> _sendLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ApiService.updateVolunteerLocation(
        volunteerId: _volunteerId,
        lat: pos.latitude,
        lng: pos.longitude,
        name: _volunteerName,
      );
    } catch (_) {}
  }

  Future<void> _promptName() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Your Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _volunteerName = ctrl.text.trim();
                SharedPreferences.getInstance().then(
                  (p) => p.setString('staff_name', _volunteerName),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shareTimer?.cancel();
    super.dispose();
  }

  Color get _statusColor {
    if (_totalCount < _greenMax) return Colors.green;
    if (_totalCount <= _yellowMax) return Colors.amber;
    return Colors.red;
  }

  String get _statusLabel {
    if (_totalCount < _greenMax) return 'Normal';
    if (_totalCount <= _yellowMax) return 'Moderate';
    return 'Critical';
  }

  double _distanceTo(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crowd Dashboard'),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(),
          Expanded(flex: 5, child: _buildMap()),
          Expanded(
            flex: 5,
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFF37474F),
                    child: const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.warning), text: 'Alerts'),
                        Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                        Tab(icon: Icon(Icons.location_on), text: 'Location'),
                      ],
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.amber,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAlertsList(),
                        _buildAnalytics(),
                        _buildLocationTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CrowdDetectionScreen()),
        ),
        backgroundColor: const Color(0xFFC62828),
        icon: const Icon(Icons.videocam, color: Colors.white),
        label: const Text(
          'Live Camera',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Container(
      color: const Color(0xFF37474F),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statBlock(Icons.people, 'People', _totalCount),
          _statBlock(Icons.local_fire_department, 'Hotspots', _hotspotCount),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Alerts: ${_alerts.length}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBlock(IconData icon, String label, int value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 26),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  // ── Map ─────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(initialCenter: _center, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.drishtisetu.app',
        ),
        CircleLayer(circles: _hotspotCircles()),
        MarkerLayer(markers: [
          ..._volunteerMarkers(),
          ..._alertMarkers(),
        ]),
      ],
    );
  }

  List<CircleMarker> _hotspotCircles() {
    return _hotspots.map<CircleMarker>((h) {
      final cx = (h['center']['x'] as num).toDouble();
      final cy = (h['center']['y'] as num).toDouble();
      final count = h['count'] as int;
      return CircleMarker(
        point: LatLng(
          _center.latitude + (cy - 300) * 0.00002,
          _center.longitude + (cx - 400) * 0.00002,
        ),
        radius: (count * 3).toDouble().clamp(30, 120),
        useRadiusInMeter: false,
        color: Colors.red.withOpacity(0.35),
        borderColor: Colors.red,
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  List<Marker> _volunteerMarkers() {
    return _volunteers.map<Marker>((v) {
      final lat = (v['lat'] as num).toDouble();
      final lng = (v['lng'] as num).toDouble();
      return Marker(
        point: LatLng(lat, lng),
        width: 36,
        height: 36,
        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
      );
    }).toList();
  }

  List<Marker> _alertMarkers() {
    return _alerts.map<Marker>((a) {
      final lat = (a['lat'] as num).toDouble();
      final lng = (a['lng'] as num).toDouble();
      return Marker(
        point: LatLng(lat, lng),
        width: 36,
        height: 36,
        child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
      );
    }).toList();
  }

  // ── Alerts ──────────────────────────────────────────────────────────
  Widget _buildAlertsList() {
    if (_alerts.isEmpty) {
      return const Center(
        child: Text('No active alerts', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: _alerts.length,
      padding: const EdgeInsets.only(top: 4),
      itemBuilder: (ctx, i) => _alertTile(_alerts[i]),
    );
  }

  Widget _alertTile(Map<String, dynamic> alert) {
    final mins = DateTime.now().difference(DateTime.parse(alert['timestamp'])).inMinutes;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: alert['status'] == 'assigned' ? Colors.green : Colors.red,
          child: Icon(
            alert['status'] == 'assigned' ? Icons.check : Icons.warning,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          alert['issue_type'].toString().toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${mins < 1 ? "Just now" : "$mins min ago"}  •  ${alert['status']}',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: alert['status'] == 'assigned'
            ? Text(
                '→ ${alert['assigned_to']}',
                style: const TextStyle(color: Colors.green, fontSize: 13),
              )
            : TextButton(
                onPressed: () => _showAssignSheet(alert),
                child: const Text('Assign'),
              ),
      ),
    );
  }

  void _showAssignSheet(Map<String, dynamic> alert) {
    final alertLat = (alert['lat'] as num).toDouble();
    final alertLng = (alert['lng'] as num).toDouble();

    final sorted = List<Map<String, dynamic>>.from(_volunteers);
    sorted.sort((a, b) {
      final dA = _distanceTo(
        alertLat, alertLng,
        (a['lat'] as num).toDouble(), (a['lng'] as num).toDouble(),
      );
      final dB = _distanceTo(
        alertLat, alertLng,
        (b['lat'] as num).toDouble(), (b['lng'] as num).toDouble(),
      );
      return dA.compareTo(dB);
    });

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nearby Volunteers',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No active volunteers nearby'),
              ),
            ...sorted.map((v) {
              final dist = _distanceTo(
                alertLat, alertLng,
                (v['lat'] as num).toDouble(), (v['lng'] as num).toDouble(),
              );
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(v['name']),
                subtitle: Text('${dist.toStringAsFixed(0)} m away'),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ApiService.assignVolunteer(
                      alertId: alert['id'],
                      volunteerId: v['volunteer_id'],
                    ).then((_) => _refresh());
                  },
                  child: const Text('Assign'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Analytics tab ──────────────────────────────────────────────────
  Widget _buildAnalytics() {
    if (_countHistory.length < 2) {
      return const Center(child: Text('Collecting data...'));
    }
    final minY = _countHistory.map((s) => s.y).reduce(min);
    final maxY = _countHistory.map((s) => s.y).reduce(max);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crowd Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: (minY - 10).clamp(0, minY),
                maxY: maxY + 10,
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: _countHistory,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Location tab ──────────────────────────────────────────────────
  Widget _buildLocationTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _sharingLocation ? Icons.location_on : Icons.location_off,
                color: _sharingLocation ? Colors.green : Colors.grey,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _sharingLocation ? 'Sharing Active' : 'Location Sharing Off',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _sharingLocation ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              Switch(
                value: _sharingLocation,
                onChanged: _toggleSharing,
                activeColor: Colors.green,
              ),
            ],
          ),
          if (_volunteerName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Name: $_volunteerName',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Active Volunteers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _volunteers.isEmpty
                ? const Center(child: Text('No active volunteers'))
                : ListView.builder(
                    itemCount: _volunteers.length,
                    itemBuilder: (ctx, i) {
                      final v = _volunteers[i];
                      return ListTile(
                        leading: const Icon(Icons.person_pin_circle, color: Colors.blue),
                        title: Text(v['name']),
                        subtitle: Text('ID: ${v['volunteer_id']}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
