import 'package:flutter/material.dart';

/// 앱 전역 상수 정의 (btc_review 구조 계승, 영화 도메인으로 변경)

/// 5각형 레이더 차트 & 평가 폼에서 공용으로 쓰는 지표 정의
class ScoreMetric {
  final String key;
  final String label;
  final String description;
  const ScoreMetric(this.key, this.label, this.description);
}

/// 기본 5기준 (내부 key는 고정 — 기존 데이터 호환 및 미래 다중 유저 비교용).
/// 사용자는 프로필에서 label·description만 커스터마이징할 수 있다.
const List<ScoreMetric> kDefaultScoreMetrics = [
  ScoreMetric('fun', '순수재미', '영화를 감상하는 동안 느낀 직관적인 즐거움과 흥미'),
  ScoreMetric('story', '스토리',
      '개연성 있는 전개와 복선 회수, 결말의 완성도 등 이야기 구조와 흐름의 논리적 짜임새'),
  ScoreMetric('immersion', '연기/연출',
      '배우의 연기력, 캐릭터의 매력, 장면 연출로 만들어지는 인물의 행동이나 상황에 대한 몰입감'),
  ScoreMetric('av', '시청각 효과',
      'CG, 촬영, 색감 등의 영상미와 BGM, 음향, 편집 기법 등 기술적 표현의 완성도'),
  ScoreMetric('originality', '작품성',
      '참신한 아이디어와 소재의 독창성, 명확한 주제의식과 메시지 전달력이 남기는 깊은 여운'),
];

/// 점수 key 목록 (평균 계산·저장용) — 항상 기본 정의의 고정 key 순서
final List<String> kScoreKeys =
    kDefaultScoreMetrics.map((m) => m.key).toList();

/// 커스터마이징 입력 길이 제한
const int kCriteriaLabelMax = 10;
const int kCriteriaDescMax = 50;
const int kNicknameMax = 10;

/// 영화관 프리셋 (자유 입력도 허용)
const List<String> kTheaterPresets = [
  'CGV',
  '메가박스',
  '롯데시네마',
  'Netflix',
  'Disney+',
  'Watcha',
  'Wavve',
  'Tving',
  'Coupang Play',
  '기타',
];

/// 특별관(상영 포맷) 옵션 — 다중 선택
const List<String> kSpecialFormats = [
  '일반',
  'IMAX',
  '4DX',
  'ScreenX',
  '돌비 시네마',
  'Dolby Atmos',
  'SUPER PLEX',
  'Cine&Foret',
];

/// 국내/해외 구분
const String kDomestic = '국내';
const String kOverseas = '해외';

/// TMDB 이미지 base URL
const String kTmdbImageBase = 'https://image.tmdb.org/t/p';

/// 포스터 URL 생성 (size: w200 썸네일, w500 상세 등)
String? posterUrl(String? posterPath, {String size = 'w500'}) {
  if (posterPath == null || posterPath.isEmpty) return null;
  return '$kTmdbImageBase/$size$posterPath';
}

/// 앱 테마 컬러 (btc_review의 blue-500 계열 계승)
const Color kPrimaryColor = Color(0xFF3B82F6);
const Color kAverageColor = Color(0xFFEF4444);

/// 0~10 점수를 흰→노랑→주황→빨강 그라데이션 색으로 변환 (btc_review renderSlider 로직 계승)
Color scoreColor(num score) {
  int r, g, b;
  if (score <= 3) {
    final ratio = score / 3;
    r = 255;
    g = 255;
    b = (255 * (1 - ratio)).round();
  } else if (score <= 7) {
    final ratio = (score - 3) / 4;
    r = 255;
    g = (255 - 90 * ratio).round();
    b = 0;
  } else {
    final ratio = (score - 7) / 3;
    r = 255;
    g = (165 * (1 - ratio)).round();
    b = 0;
  }
  return Color.fromARGB(255, r, g, b);
}

/// 반응형: 콘텐츠 최대 폭 (btc_review의 max-w-6xl ≈ 1152px 계승)
const double kMaxContentWidth = 1152;
const double kMobileBreakpoint = 768;
