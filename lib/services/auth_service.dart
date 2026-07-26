import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
// 카카오 SDK도 User 타입을 export하므로 Firebase의 User와 충돌 방지
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;

import '../utils/web_url.dart';

/// 카카오 단일 로그인 인증 서비스.
///
/// Firebase Auth는 카카오를 기본 제공자로 지원하지 않으므로,
/// 카카오 SDK로 로그인 → 액세스 토큰을 Cloud Function(kakaoCustomToken)에 전달 →
/// 서버가 카카오 API로 검증 후 Firebase 커스텀 토큰 발급 → 그 토큰으로 Firebase 로그인.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 카카오 로그인 시작.
  ///
  /// 웹: SDK의 authorize()가 카카오 인증 페이지로 **전체 페이지를 리다이렉트**한다.
  ///     (팝업이 아니며 즉시 빈 값을 반환하므로 여기서 로그인이 끝나지 않는다.)
  ///     복귀 후 [completeWebSignInIfNeeded]가 URL의 code를 받아 마무리한다.
  /// 모바일: SDK가 액세스 토큰까지 발급하므로 바로 Firebase 로그인까지 진행한다.
  Future<UserCredential?> signInWithKakao() async {
    if (kIsWeb) {
      // SDK의 authorize()는 JavaScript 키로 인가 코드를 발급하는데,
      // 서버의 토큰 교환은 REST API 키를 쓰므로 카카오가 'Bad client credentials'로 거부한다.
      // 따라서 웹에서는 REST API 키로 인증 URL을 직접 구성해 표준 REST OAuth 흐름을 탄다.
      final restKey = dotenv.env['KAKAO_REST_API_KEY'];
      if (restKey == null || restKey.isEmpty) {
        throw Exception('KAKAO_REST_API_KEY가 설정되지 않았습니다 (.env 확인).');
      }
      final url = Uri.https('kauth.kakao.com', '/oauth/authorize', {
        'client_id': restKey,
        'redirect_uri': Uri.base.origin,
        'response_type': 'code',
      });
      redirectTo(url.toString());
      return null; // 리다이렉트되므로 이 지점으로 돌아오지 않는다
    }
    final kakaoToken = await _loginToKakao();
    return _firebaseSignIn({'accessToken': kakaoToken.accessToken});
  }

  /// 웹 리다이렉트 복귀 처리 — 주소에 ?code=... 가 있으면 로그인을 마무리한다.
  /// 앱 시작 시 1회 호출한다.
  Future<void> completeWebSignInIfNeeded() async {
    if (!kIsWeb) return;
    final code = Uri.base.queryParameters['code'];
    if (code == null || code.isEmpty) return;

    try {
      await _firebaseSignIn({
        'authCode': code,
        'redirectUri': Uri.base.origin,
      });
    } finally {
      // 인가 코드는 1회용이므로 주소창에서 제거
      clearUrlQuery();
    }
  }

  /// Cloud Function으로 Firebase 커스텀 토큰을 받아 로그인
  Future<UserCredential> _firebaseSignIn(Map<String, dynamic> payload) async {
    final callable = _functions.httpsCallable('kakaoCustomToken');
    final result = await callable.call<Map<String, dynamic>>(payload);

    final customToken = result.data['token'] as String?;
    if (customToken == null) {
      throw Exception('커스텀 토큰을 받지 못했습니다.');
    }
    return _auth.signInWithCustomToken(customToken);
  }

  /// 모바일 전용 카카오 로그인.
  /// 카카오톡이 설치돼 있으면 앱으로 바로 로그인(app-to-app), 아니면 계정 로그인.
  Future<OAuthToken> _loginToKakao() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        // 사용자가 카카오톡 로그인을 취소한 경우 계정 로그인으로 넘어가지 않음
        if (e is PlatformException && e.code == 'CANCELED') rethrow;
        return UserApi.instance.loginWithKakaoAccount();
      }
    }
    return UserApi.instance.loginWithKakaoAccount();
  }

  Future<void> signOut() async {
    // 카카오 세션도 함께 정리 (실패해도 Firebase 로그아웃은 진행)
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    await _auth.signOut();
  }
}
