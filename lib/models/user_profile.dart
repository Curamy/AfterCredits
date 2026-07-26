import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

/// 사용자별 평가기준 오버라이드 (label/description만, key는 고정)
class CriteriaOverride {
  final String label;
  final String description;
  const CriteriaOverride({required this.label, required this.description});

  Map<String, dynamic> toMap() => {'label': label, 'description': description};

  factory CriteriaOverride.fromMap(Map<String, dynamic> m) => CriteriaOverride(
        label: m['label'] as String? ?? '',
        description: m['description'] as String? ?? '',
      );
}

/// Firestore `users/{uid}` 문서 — 프로필 + 앱 설정
class UserProfile {
  final String uid;
  final String? nickname; // null → 카카오 이름 사용
  final String? photoUrl; // 업로드한 커스텀 사진 URL
  final bool useDefaultPhoto; // true → 기본 아이콘 강제
  final Map<String, CriteriaOverride> criteria; // key → 오버라이드

  // 설정
  final String themeMode; // 'light' | 'dark' | 'system'
  final bool showPhotoPreview;
  final bool showRecommendations;

  const UserProfile({
    required this.uid,
    this.nickname,
    this.photoUrl,
    this.useDefaultPhoto = false,
    this.criteria = const {},
    this.themeMode = 'system',
    this.showPhotoPreview = true,
    this.showRecommendations = true,
  });

  /// 기본값 (문서가 없을 때)
  factory UserProfile.defaults(String uid) => UserProfile(uid: uid);

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawCriteria = (data['criteria'] as Map?) ?? {};
    final criteria = <String, CriteriaOverride>{};
    rawCriteria.forEach((k, v) {
      if (v is Map) {
        criteria[k.toString()] =
            CriteriaOverride.fromMap(Map<String, dynamic>.from(v));
      }
    });
    return UserProfile(
      uid: doc.id,
      nickname: (data['nickname'] as String?)?.isNotEmpty == true
          ? data['nickname'] as String
          : null,
      photoUrl: data['photoUrl'] as String?,
      useDefaultPhoto: data['useDefaultPhoto'] as bool? ?? false,
      criteria: criteria,
      themeMode: data['themeMode'] as String? ?? 'system',
      showPhotoPreview: data['showPhotoPreview'] as bool? ?? true,
      showRecommendations: data['showRecommendations'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'nickname': nickname,
        'photoUrl': photoUrl,
        'useDefaultPhoto': useDefaultPhoto,
        'criteria': {for (final e in criteria.entries) e.key: e.value.toMap()},
        'themeMode': themeMode,
        'showPhotoPreview': showPhotoPreview,
        'showRecommendations': showRecommendations,
      };

  /// 기본 기준에 사용자 오버라이드를 병합한 실제 표시용 지표
  List<ScoreMetric> get effectiveMetrics {
    return kDefaultScoreMetrics.map((d) {
      final o = criteria[d.key];
      if (o == null) return d;
      return ScoreMetric(
        d.key,
        o.label.isNotEmpty ? o.label : d.label,
        o.description.isNotEmpty ? o.description : d.description,
      );
    }).toList();
  }

  UserProfile copyWith({
    String? nickname,
    bool clearNickname = false,
    String? photoUrl,
    bool clearPhotoUrl = false,
    bool? useDefaultPhoto,
    Map<String, CriteriaOverride>? criteria,
    String? themeMode,
    bool? showPhotoPreview,
    bool? showRecommendations,
  }) {
    return UserProfile(
      uid: uid,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      useDefaultPhoto: useDefaultPhoto ?? this.useDefaultPhoto,
      criteria: criteria ?? this.criteria,
      themeMode: themeMode ?? this.themeMode,
      showPhotoPreview: showPhotoPreview ?? this.showPhotoPreview,
      showRecommendations: showRecommendations ?? this.showRecommendations,
    );
  }
}
