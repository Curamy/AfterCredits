import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inquiry.dart';

/// Firestore `inquiries` — 1:1 문의 등록 및 내 문의 조회.
/// 답변은 운영자 도구에서만 작성하며, 앱에서는 읽기만 한다.
class InquiryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('inquiries');

  Future<void> create({
    required String uid,
    required String subject,
    required String message,
  }) {
    final inquiry = Inquiry(
      uid: uid,
      subject: subject,
      message: message,
      createdAt: DateTime.now().toIso8601String(),
    );
    return _col.add(inquiry.toMap());
  }

  /// 내 문의 목록 (최신순). 인덱스 없이 동작하도록 정렬은 클라이언트에서 한다.
  Stream<List<Inquiry>> watchMine(String uid) {
    return _col.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(Inquiry.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
