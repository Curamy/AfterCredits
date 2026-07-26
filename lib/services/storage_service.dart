import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage 사진 업로드/삭제 (웹·모바일 공통, bytes 기반)
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 사진 업로드 후 다운로드 URL 반환.
  /// 경로: photos/{uid}/{millis}_{index}.{ext}
  Future<String> uploadPhoto({
    required String uid,
    required Uint8List bytes,
    required int index,
    String ext = 'jpg',
    String contentType = 'image/jpeg',
  }) async {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('photos/$uid/${millis}_$index.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// 다운로드 URL로부터 해당 파일 삭제 (실패는 무시 — 이미 없을 수 있음)
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // 파일이 이미 없거나 권한 문제 — 무시
    }
  }
}
