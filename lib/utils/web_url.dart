// 플랫폼별 URL 처리 (웹에서만 실제 동작)
export 'web_url_stub.dart' if (dart.library.js_interop) 'web_url_web.dart';
