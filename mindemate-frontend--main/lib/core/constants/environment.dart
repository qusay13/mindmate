class Environment {
  // Base URLs for API and WebSocket
  // Use http://10.0.2.2:8000/api for Android emulator
  // Use http://127.0.0.1:8000/api for Linux/Mac/Windows desktop or iOS simulator
  // Use http://192.168.1.10:8000/api for local network testing
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const String wsUrl = 'ws://127.0.0.1:8000/ws';

  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    // Remove trailing /api to get the root host URL
    final serverRoot = baseUrl.replaceAll('/api', '');
    return '$serverRoot$path';
  }
}
