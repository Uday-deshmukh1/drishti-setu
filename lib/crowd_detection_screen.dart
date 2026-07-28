import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'yolo_service.dart';

class CrowdDetectionScreen extends StatefulWidget {
  const CrowdDetectionScreen({super.key});

  @override
  State<CrowdDetectionScreen> createState() => _CrowdDetectionScreenState();
}

class _CrowdDetectionScreenState extends State<CrowdDetectionScreen> {
  CameraController? _camCtrl;
  YoloService? _yolo;
  bool _loading = true;
  String? _error;
  bool _modelAvailable = false;

  List<Detection> _detections = [];
  int _personCount = 0;
  int _fps = 0;
  DateTime _lastFrameTime = DateTime.now();
  int _frameCount = 0;
  List<_Hotspot> _hotspots = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _error = 'Camera permission denied';
        _loading = false;
      });
      return;
    }

    _yolo = YoloService();
    await _yolo!.loadModel();
    _modelAvailable = _yolo!.isLoaded;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera found';
          _loading = false;
        });
        return;
      }

      _camCtrl = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _camCtrl!.initialize();
      if (!mounted) return;

      setState(() => _loading = false);

      if (_modelAvailable) {
        _startDetectionLoop();
      }
    } catch (e) {
      setState(() {
        _error = 'Camera error: $e';
        _loading = false;
      });
    }
  }

  void _startDetectionLoop() async {
    while (mounted && _camCtrl != null && _camCtrl!.value.isInitialized) {
      try {
        final file = await _camCtrl!.takePicture();
        final bytes = await file.readAsBytes();
        final detections = await _yolo!.detect(bytes);

        final now = DateTime.now();
        final elapsed = now.difference(_lastFrameTime).inMilliseconds;
        _frameCount++;
        if (elapsed >= 1000) {
          setState(() => _fps = _frameCount);
          _frameCount = 0;
          _lastFrameTime = now;
        }

        if (mounted) {
          setState(() {
            _detections = detections;
            _personCount = detections.length;
            _hotspots = _findHotspots(detections);
          });
        }
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  List<_Hotspot> _findHotspots(List<Detection> dets, {double eps = 100, int minSamples = 3}) {
    if (dets.length < minSamples) return [];
    final centers = dets.map((d) => Offset(d.x + d.w / 2, d.y + d.h / 2)).toList();
    final List<bool> visited = List.filled(centers.length, false);
    final List<_Hotspot> hotspots = [];

    for (var i = 0; i < centers.length; i++) {
      if (visited[i]) continue;
      visited[i] = true;
      final cluster = <Offset>[centers[i]];
      for (var j = i + 1; j < centers.length; j++) {
        if (visited[j]) continue;
        if ((centers[i] - centers[j]).distance < eps) {
          visited[j] = true;
          cluster.add(centers[j]);
        }
      }
      if (cluster.length >= minSamples) {
        final cx = cluster.map((p) => p.dx).reduce((a, b) => a + b) / cluster.length;
        final cy = cluster.map((p) => p.dy).reduce((a, b) => a + b) / cluster.length;
        hotspots.add(_Hotspot(center: Offset(cx, cy), count: cluster.length));
      }
    }
    return hotspots;
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    _yolo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Crowd Detection'),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Opening camera...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_camCtrl!),
                    if (_modelAvailable)
                      CustomPaint(
                        painter: _DetectionPainter(
                          detections: _detections,
                          hotspots: _hotspots,
                          previewSize: _camCtrl!.value.previewSize!,
                        ),
                      ),
                    // ── Stats overlay ──────────────────────────────
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _overlayStat(Icons.people, '$_personCount', Colors.green),
                            _overlayStat(Icons.local_fire_department, '${_hotspots.length}', Colors.red),
                            if (_modelAvailable) _overlayStat(Icons.speed, '$_fps FPS', Colors.amber),
                          ],
                        ),
                      ),
                    ),
                    // ── Hotspot warning ────────────────────────────
                    if (_hotspots.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Crowd Hotspot — ${_hotspots.length} zone(s)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ── Web notice ─────────────────────────────────
                    if (!_modelAvailable)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Camera preview active.\nRun on Android/iOS for live YOLO crowd detection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _overlayStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _Hotspot {
  final Offset center;
  final int count;
  _Hotspot({required this.center, required this.count});
}

class _DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final List<_Hotspot> hotspots;
  final Size previewSize;

  _DetectionPainter({
    required this.detections,
    required this.hotspots,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / previewSize.height;
    final scaleY = size.height / previewSize.width;

    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    for (var det in detections) {
      final rect = Rect.fromLTWH(
        det.x * scaleX, det.y * scaleY,
        det.w * scaleX, det.h * scaleY,
      );
      canvas.drawRect(rect, boxPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '${(det.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left, rect.top - 14));
    }

    final hsPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;
    final hsFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red.withOpacity(0.15);

    for (var hs in hotspots) {
      final radius = (hs.count * 12.0).clamp(40.0, 150.0);
      final center = Offset(hs.center.dx * scaleX, hs.center.dy * scaleY);
      canvas.drawCircle(center, radius, hsFill);
      canvas.drawCircle(center, radius, hsPaint);
      final countTp = TextPainter(
        text: TextSpan(
          text: '${hs.count} people',
          style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      countTp.paint(canvas, Offset(center.dx - countTp.width / 2, center.dy - countTp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter old) => true;
}
