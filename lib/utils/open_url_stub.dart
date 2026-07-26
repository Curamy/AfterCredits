import 'package:url_launcher/url_launcher.dart' as launcher;

/// 모바일/데스크톱: 기본 브라우저(외부 앱)로 URL을 연다.
Future<void> openExternalUrl(String url) async {
  await launcher.launchUrl(Uri.parse(url),
      mode: launcher.LaunchMode.externalApplication);
}
