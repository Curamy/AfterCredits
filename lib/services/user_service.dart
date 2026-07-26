import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_profile.dart';

/// Firestore `users/{uid}` — 프로필 + 설정 CRUD
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// 프로필 스트림 (문서 없으면 기본값)
  Stream<UserProfile> watchProfile(String uid) {
    return _doc(uid).snapshots().map(
        (d) => d.exists ? UserProfile.fromFirestore(d) : UserProfile.defaults(uid));
  }

  Future<UserProfile> getProfile(String uid) async {
    final d = await _doc(uid).get();
    return d.exists ? UserProfile.fromFirestore(d) : UserProfile.defaults(uid);
  }

  /// 전체 저장(merge). 부분 갱신은 copyWith 후 호출.
  Future<void> save(UserProfile profile) =>
      _doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));

  /// 프로필 사진 업로드 → URL 반환. 경로: avatars/{uid}/{millis}.jpg
  Future<String> uploadAvatar(String uid, Uint8List bytes,
      {String contentType = 'image/jpeg'}) async {
    final ref = _storage
        .ref('avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> deleteAvatarByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
