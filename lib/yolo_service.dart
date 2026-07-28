class Detection {
  final int classId;
  final String label;
  final double confidence;
  final double x, y, w, h;

  Detection({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class YoloService {
  bool _isLoaded = false;
  String? _loadError;

  bool get isLoaded => _isLoaded;
  String? get loadError => _loadError;

  Future<void> loadModel() async {
    // YOLO inference via tflite_flutter only works on Android/iOS (native FFI).
    // On web/desktop, the camera preview still works but detection is disabled.
    _isLoaded = false;
    _loadError =
        'YOLO detection requires Android or iOS.\n\n'
        'On web, the camera preview works but without AI inference.\n'
        'Run on an Android device/emulator for live crowd detection.';
  }

  Future<List<Detection>> detect(List<int> imageBytes) async {
    return [];
  }

  void dispose() {
    _isLoaded = false;
  }
}
