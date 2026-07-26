import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// 같은 viewType을 두 번 등록하면 예외가 나므로 등록 여부를 기억한다.
final Set<String> _registered = <String>{};

/// 웹: 카카오 CDN처럼 CORS 헤더가 없는 이미지는 CanvasKit이 그리지 못한다.
/// `<img>` 요소는 표시 목적에는 CORS 제약이 없으므로 HtmlElementView로 렌더링한다.
Widget networkImageView(
  String url, {
  required double size,
  required Widget fallback,
}) {
  final viewType = 'network-img:$url';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final img = web.HTMLImageElement()..src = url;
      img.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover'
        // 플랫폼 뷰가 클릭을 가로채면 아래의 Flutter 위젯(팝업 메뉴 등)이
        // 탭을 받지 못하므로 포인터 이벤트를 통과시킨다.
        ..pointerEvents = 'none';
      return img;
    });
  }
  return SizedBox(
    width: size,
    height: size,
    child: HtmlElementView(viewType: viewType),
  );
}
