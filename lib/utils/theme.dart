import 'package:flutter/material.dart';

import 'constants.dart';

/// 라이트/다크 테마 정의. 위젯은 하드코딩 색 대신 아래 색을 사용해 다크모드에 대응.

/// 플랫폼과 무관하게 항상 같은 페이지 전환 애니메이션을 쓰도록 통일.
/// (기본값은 플랫폼별로 달라서, 웹에서 iOS User-Agent로 접속하면 iOS 전용
/// Cupertino 전환(패럴랙스로 두 레이어가 동시에 움직이는 방식)이 적용돼
/// "슬라이드가 두 번 보인다"는 착시를 유발할 수 있었다.)
const _pageTransitionsTheme = PageTransitionsTheme(builders: {
  TargetPlatform.android: ZoomPageTransitionsBuilder(),
  TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
  TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
  TargetPlatform.linux: ZoomPageTransitionsBuilder(),
  TargetPlatform.windows: ZoomPageTransitionsBuilder(),
  TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
});

ThemeData buildLightTheme(String fontFamily) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kPrimaryColor,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF9FAFB),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE5E7EB),
    pageTransitionsTheme: _pageTransitionsTheme,
  );
}

ThemeData buildDarkTheme(String fontFamily) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kPrimaryColor,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0F1115),
    cardColor: const Color(0xFF1B1E24),
    dividerColor: const Color(0xFF2A2F37),
    pageTransitionsTheme: _pageTransitionsTheme,
  );
}

/// 위젯에서 테마 색을 짧게 쓰기 위한 확장
extension ThemeColorsX on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  /// 카드/섹션 배경
  Color get cardBg => Theme.of(this).cardColor;

  /// 페이지 배경
  Color get pageBg => Theme.of(this).scaffoldBackgroundColor;

  /// 본문 보조(회색) 텍스트
  Color get subtleText => Theme.of(this).colorScheme.onSurfaceVariant;

  /// 더 옅은 힌트 텍스트
  Color get hintText =>
      Theme.of(this).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

  /// 옅은 칩/막대 배경
  Color get chipBg => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF2A2F37)
      : const Color(0xFFF3F4F6);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
