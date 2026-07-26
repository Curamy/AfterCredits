import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 웹 주소를 해시(#/review/xxx) 대신 일반 경로(/review/xxx)로 표시.
  // 다른 플랫폼에서는 이 호출이 아무 효과가 없다(no-op).
  usePathUrlStrategy();

  // go_router 8.0.0부터 context.push()는 (모바일 앱의 뒤로가기 스택 동작은
  // 그대로 유지하면서도) 기본적으로 웹 주소창을 갱신하지 않도록 바뀌었다.
  // 웹에서는 주소가 실제로 바뀌길 원하므로 켠다 — 웹이 아닌 플랫폼에는
  // 영향이 없다(모바일 뒤로가기 제스처는 그대로 정상 동작).
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // TMDB·카카오 키 등 환경변수 로드
  await dotenv.load(fileName: '.env');

  // 카카오 SDK 초기화 (웹은 JavaScript 키, 모바일은 네이티브 앱 키 사용).
  // 빈 문자열은 null로 넘기고, 초기화 실패가 앱 전체를 막지 않도록 방어한다.
  String? key(String name) {
    final v = dotenv.env[name];
    return (v == null || v.isEmpty) ? null : v;
  }

  try {
    KakaoSdk.init(
      nativeAppKey: key('KAKAO_NATIVE_APP_KEY'),
      javaScriptAppKey: key('KAKAO_JS_KEY'),
    );
  } catch (e) {
    debugPrint('카카오 SDK 초기화 실패: $e');
  }

  // Firebase 초기화 (flutterfire configure로 생성된 옵션 사용)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 웹 카카오 로그인은 전체 페이지 리다이렉트 방식이라,
  // 복귀 시 주소의 인가 코드로 로그인을 마무리해야 한다.
  try {
    await AuthService().completeWebSignInIfNeeded();
  } catch (e) {
    debugPrint('카카오 로그인 마무리 실패: $e');
  }

  runApp(const ProviderScope(child: MovieReviewApp()));
}
