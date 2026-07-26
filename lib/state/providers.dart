import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_review.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';
import '../services/tmdb_service.dart';
import '../services/user_service.dart';
import '../utils/constants.dart';

// --- 서비스 프로바이더 ---
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final tmdbServiceProvider = Provider<TmdbService>((ref) => TmdbService());
final userServiceProvider = Provider<UserService>((ref) => UserService());

// --- 사용자 프로필/설정 (users/{uid}) ---
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watchProfile(user.uid);
});

/// 현재 프로필(없으면 기본값). 로그인 안 됐으면 null.
final currentProfileProvider = Provider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  return ref.watch(userProfileProvider).asData?.value ??
      UserProfile.defaults(user.uid);
});

/// 실제 표시용 평가지표 (기본 + 사용자 오버라이드)
final scoreMetricsProvider = Provider<List<ScoreMetric>>((ref) {
  final profile = ref.watch(currentProfileProvider);
  return profile?.effectiveMetrics ?? kDefaultScoreMetrics;
});

/// 설정 토글 편의 접근
final showRecommendationsProvider = Provider<bool>(
    (ref) => ref.watch(currentProfileProvider)?.showRecommendations ?? true);
final showPhotoPreviewProvider = Provider<bool>(
    (ref) => ref.watch(currentProfileProvider)?.showPhotoPreview ?? true);

/// 테마 모드 (프로필의 themeMode 반영)
final themeModeProvider = Provider<ThemeMode>((ref) {
  switch (ref.watch(currentProfileProvider)?.themeMode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});

// --- 인증 상태 ---
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// 로그인 여부 (작성/수정/삭제 버튼 노출 판단)
final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).asData?.value != null,
);

// --- 리뷰 목록 (본인 것만, totalScore 내림차순 스트림) ---
// 로그아웃 상태에서는 아무 데이터도 내려주지 않는다.
final reviewsProvider = StreamProvider<List<MovieReview>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(const <MovieReview>[]);
  return ref.watch(reviewServiceProvider).watchReviews(user.uid);
});

/// 단일 리뷰 (상세 화면)
final reviewByIdProvider =
    FutureProvider.family<MovieReview?, String>((ref, id) async {
  // 목록이 이미 로드돼 있으면 거기서 찾고, 없으면 단건 조회
  final list = ref.watch(reviewsProvider).asData?.value;
  if (list != null) {
    final matches = list.where((r) => r.id == id).toList();
    if (matches.isNotEmpty) return matches.first;
  }
  return ref.watch(reviewServiceProvider).getById(id);
});

/// 전체 평균 점수 (레이더 차트용)
final averageScoresProvider = Provider<Map<String, double>>((ref) {
  final list = ref.watch(reviewsProvider).asData?.value ?? [];
  return ReviewService.averageScores(list);
});

// --- 필터 (감상연도 / 국내·해외 / 장르) ---
class MovieFilter {
  final int? year;
  final String? country;
  final String? genre;
  const MovieFilter({this.year, this.country, this.genre});

  bool get isEmpty => year == null && country == null && genre == null;
}

class FilterNotifier extends Notifier<MovieFilter> {
  @override
  MovieFilter build() => const MovieFilter();

  void setYear(int? year) =>
      state = MovieFilter(year: year, country: state.country, genre: state.genre);
  void setCountry(String? country) =>
      state = MovieFilter(year: state.year, country: country, genre: state.genre);
  void setGenre(String? genre) =>
      state = MovieFilter(year: state.year, country: state.country, genre: genre);
  void clear() => state = const MovieFilter();
}

final filterProvider =
    NotifierProvider<FilterNotifier, MovieFilter>(FilterNotifier.new);

/// 필터 적용된 리뷰 목록
final filteredReviewsProvider = Provider<List<MovieReview>>((ref) {
  final all = ref.watch(reviewsProvider).asData?.value ?? [];
  final f = ref.watch(filterProvider);
  return all.where((r) {
    if (f.year != null && r.watchYear != f.year) return false;
    if (f.country != null && r.country != f.country) return false;
    if (f.genre != null && !r.genres.contains(f.genre)) return false;
    return true;
  }).toList();
});

/// 필터 드롭다운 옵션 — 데이터에서 추출
final availableYearsProvider = Provider<List<int>>((ref) {
  final all = ref.watch(reviewsProvider).asData?.value ?? [];
  final years = all.map((r) => r.watchYear).where((y) => y > 0).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  return years;
});

final availableGenresProvider = Provider<List<String>>((ref) {
  final all = ref.watch(reviewsProvider).asData?.value ?? [];
  final genres = <String>{for (final r in all) ...r.genres}.toList()..sort();
  return genres;
});
