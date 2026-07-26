import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// 콘텐츠를 화면 중앙에 최대폭으로 제한 (btc_review의 max-w-6xl mx-auto 계승).
/// PC에서는 가운데 정렬, 모바일에서는 전체폭.
class MaxWidthBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const MaxWidthBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 흰 카드 컨테이너 (btc_review의 bg-white rounded-lg shadow-sm 계승)
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
