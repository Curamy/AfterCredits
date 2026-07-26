import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 상세 화면의 사진 표시 (1장 = 전체폭, 2장 = 반반). btc_review 요구사항.
class PhotoSection extends StatelessWidget {
  final List<String> photos;
  const PhotoSection({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    if (photos.length == 1) {
      return _photo(photos.first, aspectRatio: 16 / 9);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _photo(photos[0], aspectRatio: 3 / 4)),
        const SizedBox(width: 8),
        Expanded(child: _photo(photos[1], aspectRatio: 3 / 4)),
      ],
    );
  }

  Widget _photo(String url, {required double aspectRatio}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: aspectRatio,
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
    );
  }
}
