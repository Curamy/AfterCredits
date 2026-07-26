import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

/// 영화 리뷰 도메인 모델 (Firestore `movies` 컬렉션 문서에 대응)
class MovieReview {
  final String? id; // Firestore 문서 id (신규 작성 시 null)

  /// 작성자 Firebase UID. 본인만 읽기/수정/삭제 가능하도록 하는 기준값.
  final String ownerUid;

  // --- TMDB 자동 입력 ---
  final int? tmdbId;
  final String title;
  final String originalTitle;
  final String? posterPath;
  final int? releaseYear;
  final int? runtime; // 러닝타임(분)
  final List<String> genres;
  final String country; // 국내 / 해외

  // --- 수동 입력 ---
  final String theater; // 영화관 (CGV / 메가박스 / OTT 등)
  final List<String> specialFormats; // 특별관 (IMAX / 4DX ...)
  final String watchDate; // 시청 날짜 YYYY-MM-DD
  final int watchYear; // watchDate 파생 (필터용)
  final int difficulty; // 난이도 0~10
  final int maturity; // 수위 0~10
  final Map<String, int> scores; // fun/story/immersion/av/originality
  /// 저장 시점의 평가 기준 라벨 스냅샷(key→label). 비어있으면(과거 리뷰)
  /// 상세 화면에서 현재 프로필의 평가 기준을 그대로 보여준다.
  /// 이후 사용자가 프로필에서 기준을 바꿔도 이미 저장된 리뷰의 차트는
  /// 이 스냅샷 덕분에 바뀌지 않는다.
  final Map<String, String> metricLabels;
  final String review;
  final List<String> photos; // Storage URL (최대 2)

  // --- 파생/메타 ---
  final double totalScore;
  final String createdAt;
  final String updatedAt;

  const MovieReview({
    this.id,
    this.ownerUid = '',
    this.tmdbId,
    required this.title,
    this.originalTitle = '',
    this.posterPath,
    this.releaseYear,
    this.runtime,
    this.genres = const [],
    this.country = kDomestic,
    this.theater = '',
    this.specialFormats = const [],
    this.watchDate = '',
    this.watchYear = 0,
    this.difficulty = 5,
    this.maturity = 5,
    required this.scores,
    this.metricLabels = const {},
    this.review = '',
    this.photos = const [],
    this.totalScore = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  /// 점수 맵의 평균 (5지표 평균 = totalScore)
  static double averageOf(Map<String, int> scores) {
    if (scores.isEmpty) return 0;
    final sum = scores.values.fold<int>(0, (a, b) => a + b);
    return sum / scores.length;
  }

  /// 기본 점수 맵 (모든 지표 5점)
  static Map<String, int> defaultScores() =>
      {for (final k in kScoreKeys) k: 5};

  factory MovieReview.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return MovieReview.fromMap(data, id: doc.id);
  }

  factory MovieReview.fromMap(Map<String, dynamic> data, {String? id}) {
    final rawScores = (data['scores'] as Map?) ?? {};
    final scores = <String, int>{
      for (final k in kScoreKeys) k: (rawScores[k] as num?)?.toInt() ?? 0,
    };
    return MovieReview(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      tmdbId: (data['tmdbId'] as num?)?.toInt(),
      title: data['title'] as String? ?? '',
      originalTitle: data['originalTitle'] as String? ?? '',
      posterPath: data['posterPath'] as String?,
      releaseYear: (data['releaseYear'] as num?)?.toInt(),
      runtime: (data['runtime'] as num?)?.toInt(),
      genres: (data['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      country: data['country'] as String? ?? kDomestic,
      theater: data['theater'] as String? ?? '',
      specialFormats:
          (data['specialFormats'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      watchDate: data['watchDate'] as String? ?? '',
      watchYear: (data['watchYear'] as num?)?.toInt() ?? 0,
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 5,
      maturity: (data['maturity'] as num?)?.toInt() ?? 5,
      scores: scores,
      metricLabels: (data['metricLabels'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString())) ??
          const {},
      review: data['review'] as String? ?? '',
      photos: (data['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      totalScore: (data['totalScore'] as num?)?.toDouble() ?? averageOf(scores),
      createdAt: data['createdAt'] as String? ?? '',
      updatedAt: data['updatedAt'] as String? ?? '',
    );
  }

  /// Firestore 저장용 맵 (id는 제외, totalScore·watchYear는 재계산)
  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'tmdbId': tmdbId,
      'title': title,
      'originalTitle': originalTitle,
      'posterPath': posterPath,
      'releaseYear': releaseYear,
      'runtime': runtime,
      'genres': genres,
      'country': country,
      'theater': theater,
      'specialFormats': specialFormats,
      'watchDate': watchDate,
      'watchYear': watchYear,
      'difficulty': difficulty,
      'maturity': maturity,
      'scores': scores,
      'metricLabels': metricLabels,
      'review': review,
      'photos': photos,
      'totalScore': averageOf(scores),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  MovieReview copyWith({
    String? id,
    String? ownerUid,
    int? tmdbId,
    String? title,
    String? originalTitle,
    String? posterPath,
    int? releaseYear,
    int? runtime,
    List<String>? genres,
    String? country,
    String? theater,
    List<String>? specialFormats,
    String? watchDate,
    int? watchYear,
    int? difficulty,
    int? maturity,
    Map<String, int>? scores,
    Map<String, String>? metricLabels,
    String? review,
    List<String>? photos,
    double? totalScore,
    String? createdAt,
    String? updatedAt,
  }) {
    return MovieReview(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      posterPath: posterPath ?? this.posterPath,
      releaseYear: releaseYear ?? this.releaseYear,
      runtime: runtime ?? this.runtime,
      genres: genres ?? this.genres,
      country: country ?? this.country,
      theater: theater ?? this.theater,
      specialFormats: specialFormats ?? this.specialFormats,
      watchDate: watchDate ?? this.watchDate,
      watchYear: watchYear ?? this.watchYear,
      difficulty: difficulty ?? this.difficulty,
      maturity: maturity ?? this.maturity,
      scores: scores ?? this.scores,
      metricLabels: metricLabels ?? this.metricLabels,
      review: review ?? this.review,
      photos: photos ?? this.photos,
      totalScore: totalScore ?? this.totalScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
