import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'photo_viewer.dart';

/// 상세 화면의 사진 표시 (1장 = 전체폭, 2장 = 반반). btc_review 요구사항.
/// 탭하면 전체화면으로 확대해서 볼 수 있다.
class PhotoSection extends StatelessWidget {
  final List<String> photos;
  const PhotoSection({super.key, required this.photos});

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
          onTap: () => openPhotoViewer(context, photos, initialIndex: index),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
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
