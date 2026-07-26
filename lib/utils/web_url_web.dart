import 'package:web/web.dart' as web;

/// 로그인 복귀 후 주소창의 ?code=... 를 제거한다.
/// (인가 코드는 1회용이라 새로고침 시 재사용 오류가 나는 것을 막기 위함)
void clearUrlQuery() {
  web.window.history.replaceState(null, '', web.window.location.pathname);
}

/// 지정한 URL로 페이지 전체를 이동시킨다 (카카오 인증 페이지로 리다이렉트).
void redirectTo(String url) {
  web.window.location.href = url;
}
