import 'package:web/web.dart' as web;

/// 웹: 새 탭에서 URL을 연다. (기존 코드에서 이미 검증된 window.open 방식을
/// 그대로 써서, url_launcher 웹 플러그인 쪽 문제를 우회한다.)
Future<void> openExternalUrl(String url) async {
  web.window.open(url, '_blank');
}
