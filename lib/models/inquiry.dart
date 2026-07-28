import 'package:cloud_firestore/cloud_firestore.dart';

/// 1:1 문의 한 건. 답변(reply)은 운영자만 작성할 수 있고,
/// 작성자는 자기 문의와 그 답변만 읽을 수 있다.
class Inquiry {
  final String? id;
  final String uid;
  final String subject;
  final String message;
  final String createdAt; // ISO8601
  final String? reply;
  final String? repliedAt;

  const Inquiry({
    this.id,
    required this.uid,
    required this.subject,
    required this.message,
    required this.createdAt,
    this.reply,
    this.repliedAt,
  });

  bool get isAnswered => (reply ?? '').trim().isNotEmpty;

  factory Inquiry.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Inquiry(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt: data['createdAt'] as String? ?? '',
      reply: data['reply'] as String?,
      repliedAt: data['repliedAt'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'subject': subject,
        'message': message,
        'createdAt': createdAt,
      };
}
