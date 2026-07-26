// 플랫폼별 외부 URL 열기 (웹은 window.open, 그 외는 url_launcher)
export 'open_url_stub.dart' if (dart.library.js_interop) 'open_url_web.dart';
