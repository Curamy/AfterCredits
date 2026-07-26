import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/movie_review.dart';
import '../utils/constants.dart';

/// Firestore `movies` 컬렉션 CRUD
class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('movies');

  /// 로그인한 본인의 리뷰만 스트림으로 (totalScore 내림차순 = 랭킹)
  Stream<List<MovieReview>> watchReviews(String uid) {
    return _col
        .where('ownerUid', isEqualTo: uid)
        .orderBy('totalScore', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MovieReview.fromFirestore(d)).toList());
  }

  Future<MovieReview?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return MovieReview.fromFirestore(doc);
  }

  /// 신규 작성 → 생성된 문서 id 반환
  Future<String> create(MovieReview review) async {
    final now = DateTime.now().toIso8601String();
    final data = review.toMap()
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(String id, MovieReview review) async {
    final data = review.toMap()..['updatedAt'] = DateTime.now().toIso8601String();
    // createdAt은 기존 값 유지
    data.remove('createdAt');
    await _col.doc(id).update(data);
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// 전체 리뷰의 지표별 평균 (레이더 차트 '전체 평균'용)
  static Map<String, double> averageScores(List<MovieReview> reviews) {
    final result = {for (final k in kScoreKeys) k: 0.0};
    if (reviews.isEmpty) return result;
    for (final r in reviews) {
      for (final k in kScoreKeys) {
        result[k] = result[k]! + (r.scores[k] ?? 0);
      }
    }
    for (final k in kScoreKeys) {
      result[k] = result[k]! / reviews.length;
    }
    return result;
  }
}
