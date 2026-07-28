import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'photo_viewer.dart';

/// 상세 화면의 사진 표시 (1장 = 전체폭, 2장 = 반반). btc_review 요구사항.
/// 탭하면 전체화면으로 확대해서 볼 수 있다.
class PhotoSection extends StatelessWidget {
  /// 화면에 인라인으로 띄울 URL (가벼운 축소본)
  final List<String> photos;
  /// 탭해서 확대할 때 쓸 원본 URL (없으면 photos 사용)
  final List<String>? fullPhotos;
  const PhotoSection({super.key, required this.photos, this.fullPhotos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    if (photos.length == 1) {
      return _photo(context, photos.first, 0, aspectRatio: 16 / 9);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _photo(context, photos[0], 0, aspectRatio: 3 / 4)),
        const SizedBox(width: 8),
        Expanded(child: _photo(context, photos[1], 1, aspectRatio: 3 / 4)),
      ],
    );
  }

  Widget _photo(BuildContext context, String url, int index,
      {required double aspectRatio}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: GestureDetector(
          onTap: () => openPhotoViewer(context, fullPhotos ?? photos,
              initialIndex: index),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: 1000,
            placeholder: (c, _) => Container(color: Colors.grey.shade200),
            errorWidget: (c, _, _) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
