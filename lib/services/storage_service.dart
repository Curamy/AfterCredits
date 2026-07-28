import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

/// 업로드 결과: 원본(표시용)과 썸네일 URL
class UploadedPhoto {
  final String url;
  final String thumbUrl;
  const UploadedPhoto({required this.url, required this.thumbUrl});
}

/// Firebase Storage 사진 업로드/삭제 (웹·모바일 공통, bytes 기반)
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 목록 카드·상세 화면에 쓸 썸네일 가로 크기.
  /// 원본(수 MB)을 그대로 내려받으면 특히 모바일 브라우저에서 심하게 버벅인다.
  static const int _thumbWidth = 640;

  /// 사진 업로드 후 원본/썸네일 URL 반환.
  /// 경로: photos/{uid}/{millis}_{index}.jpg, 썸네일은 같은 이름에 _thumb 접미사
  Future<UploadedPhoto> uploadPhoto({
    required String uid,
    required Uint8List bytes,
    required int index,
    String ext = 'jpg',
    String contentType = 'image/jpeg',
  }) async {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final base = 'photos/$uid/${millis}_$index';

    final fullRef = _storage.ref('$base.$ext');
    await fullRef.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await fullRef.getDownloadURL();

    // 썸네일 생성 실패는 치명적이지 않으므로 원본으로 대체한다.
    String thumbUrl = url;
    try {
      final thumbBytes = await _makeThumbnail(bytes);
      if (thumbBytes != null) {
        final thumbRef = _storage.ref('${base}_thumb.jpg');
        await thumbRef.putData(
            thumbBytes, SettableMetadata(contentType: 'image/jpeg'));
        thumbUrl = await thumbRef.getDownloadURL();
      }
    } catch (_) {
      // 무시하고 원본 URL 사용
    }

    return UploadedPhoto(url: url, thumbUrl: thumbUrl);
  }

  Future<Uint8List?> _makeThumbnail(Uint8List bytes) async {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    // EXIF 방향 정보를 픽셀에 직접 반영(baking)한다. copyResize는 리사이즈가
    // 실제로 일어날 때만 이걸 해주므로, 리사이즈가 필요 없는 작은 이미지도
    // 항상 명시적으로 처리해야 회전이 씹히는 경우가 없다.
    decoded = img.bakeOrientation(decoded);
    if (decoded.width > _thumbWidth) {
      decoded = img.copyResize(decoded, width: _thumbWidth);
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
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
