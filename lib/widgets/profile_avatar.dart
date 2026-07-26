import 'package:flutter/material.dart';

import '../utils/network_image_view.dart';

/// 프로필 원형 아바타. 사진이 없거나 로드 실패 시 기본 인물 아이콘으로 대체한다.
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    this.size = 36,
  });

  /// 카카오가 http:// 로 내려주는 경우가 있어 https로 올린다.
  /// (배포 시 HTTPS 페이지에서 혼합 콘텐츠로 차단되는 것을 방지)
  static String _toHttps(String url) =>
      url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
      child: Icon(Icons.person, size: size * 0.62, color: scheme.onSurfaceVariant),
    );

    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: networkImageView(_toHttps(url), size: size, fallback: fallback),
    );
  }
}
