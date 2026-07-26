import 'package:flutter/material.dart';

/// 모바일/데스크톱: CORS 제약이 없으므로 일반 Image.network 사용
Widget networkImageView(
  String url, {
  required double size,
  required Widget fallback,
}) {
  return Image.network(
    url,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => fallback,
  );
}
