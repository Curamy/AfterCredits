/// 웹이 아닌 플랫폼에서는 할 일이 없다.
void clearUrlQuery() {}

/// 웹이 아닌 플랫폼에서는 리다이렉트를 쓰지 않는다 (모바일은 SDK가 처리).
void redirectTo(String url) {}
