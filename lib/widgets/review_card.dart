import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/movie_review.dart';
import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import 'photo_viewer.dart';
import 'score_slider.dart';

/// 랭킹 목록의 리뷰 카드.
/// 포스터를 좌측에 카드 높이만큼 꽉 채우고(잘림 없이), 순위+제목은 같은 줄,
/// 점수는 항상 우측 상단. 카드 높이는 모든 카드가 동일하도록 고정.
/// 모바일 폭에서는 좌→우 스와이프로 수정, 우→좌 스와이프로 삭제할 수 있다.
class ReviewCard extends ConsumerWidget {
  final MovieReview review;
  final int rank;
  final VoidCallback onTap;
  final bool showPhotoPreview;

  const ReviewCard({
    super.key,
    required this.review,
    required this.rank,
    required this.onTap,
    this.showPhotoPreview = false,
  });

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = posterUrl(review.posterPath, size: 'w200');
    final special = review.specialFormats.join(' · ');
    final isWide = MediaQuery.of(context).size.width >= kMobileBreakpoint;
    final hasPhoto = showPhotoPreview && review.photos.isNotEmpty;
    final cardH = isWide ? 168.0 : 142.0;

    final score = Text(review.totalScore.toStringAsFixed(1),
        style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.bold, color: kPrimaryColor));

    final card = Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: cardH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 포스터 (2:3 비율 그대로 → 좌우 잘림 없음)
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: poster == null
                        ? Container(
                            color: context.chipBg,
                            child: Icon(Icons.movie, color: context.hintText))
                        : CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                            placeholder: (c, _) => Container(color: context.chipBg),
                            errorWidget: (c, _, _) => Container(
                                color: context.chipBg,
                                child: Icon(Icons.movie, color: context.hintText)),
                          ),
                  ),
                  // 정보
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 순위(원형 뱃지) + 제목 (한 줄, 넘치면 ...)
                          Row(
                            children: [
                              _RankBadge(rank: rank),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(review.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          Text(
                            [
                              if (review.theater.isNotEmpty) review.theater,
                              if (special.isNotEmpty) special,
                            ].join('  |  '),
                            style: TextStyle(fontSize: 12, color: context.subtleText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          _GenreLine(genres: review.genres),
                          Row(
                            children: [
                              _meta(context, Icons.calendar_today, review.watchDate),
                              const SizedBox(width: 10),
                              if (review.runtime != null) ...[
                                _meta(context, Icons.schedule, '${review.runtime}분'),
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: _meta(context, Icons.public, review.country),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              MiniScoreBar(
                                  icon: Icons.psychology,
                                  value: review.difficulty,
                                  width: 52),
                              const SizedBox(width: 12),
                              MiniScoreBar(
                                  icon: Icons.eighteen_up_rating,
                                  value: review.maturity,
                                  width: 52),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 점수(우측 상단) + 사진 미리보기
                  _RightRegion(
                    score: score,
                    photoUrl: hasPhoto ? review.photos.first : null,
                    isWide: isWide,
                    cardHeight: cardH,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 모바일 폭에서만 스와이프 액션 제공 (PC는 마우스 드래그라 어색함).
    if (isWide || review.id == null) return card;

    return Dismissible(
      key: ValueKey(review.id),
      direction: DismissDirection.horizontal,
      // 좌→우로 쓸면(카드가 오른쪽으로 밀리며 왼쪽에 노출) 수정
      background: _swipeAction(context,
          icon: Icons.edit, label: '수정', color: kPrimaryColor, alignLeft: true),
      // 우→좌로 쓸면(카드가 왼쪽으로 밀리며 오른쪽에 노출) 삭제
      secondaryBackground: _swipeAction(context,
          icon: Icons.delete, label: '삭제', color: kAverageColor, alignLeft: false),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          context.push('/edit/${review.id}');
          return false; // 목록에서 지우지 않고 그대로 둔다
        }
        return _confirmDelete(context);
      },
      onDismissed: (direction) async {
        final storage = ref.read(storageServiceProvider);
        final photos = List<String>.of(review.photos);
        await ref.read(reviewServiceProvider).delete(review.id!);
        for (final url in photos) {
          storage.deleteByUrl(url);
        }
      },
      child: card,
    );
  }

  Widget _swipeAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool alignLeft,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.only(left: alignLeft ? 28 : 0, right: alignLeft ? 0 : 28),
      child: content,
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.subtleText),
        const SizedBox(width: 3),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: context.subtleText)),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text('$rank',
          style: const TextStyle(
              color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

/// 점수(우측 상단) + 첨부 사진 미리보기.
/// 모바일: 점수 아래 남은 공간 중앙에 작은 사진.
/// PC: 점수 왼쪽에 카드 높이에 맞춘 큰 사진.
class _RightRegion extends StatelessWidget {
  final Widget score;
  final String? photoUrl;
  final bool isWide;
  final double cardHeight;
  const _RightRegion(
      {required this.score,
      required this.photoUrl,
      required this.isWide,
      required this.cardHeight});

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      // 카드 높이 대비 90% 크기의 정사각형 사진 + 점수와의 간격, 좌측 여백 확보.
      final photoSize = (cardHeight - 20) * 0.9;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (photoUrl != null) ...[
              SizedBox(
                  width: photoSize,
                  height: photoSize,
                  child: _Photo(url: photoUrl!)),
              const SizedBox(width: 20),
            ],
            // 점수: 상단 정렬
            Column(mainAxisAlignment: MainAxisAlignment.start, children: [score]),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          score,
          if (photoUrl != null)
            Expanded(
                child: Center(
                    child: SizedBox(
                        width: 48, height: 48, child: _Photo(url: photoUrl!)))),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String url;
  const _Photo({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: () => openPhotoViewer(context, [url]),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (c, _) => Container(color: context.chipBg),
          errorWidget: (c, _, _) => Container(color: context.chipBg),
        ),
      ),
    );
  }
}

/// 장르 칩을 한 줄로 표시하고, 넘치면 "+N"으로 접어 탭 시 전체를 보여준다.
class _GenreLine extends StatelessWidget {
  final List<String> genres;
  const _GenreLine({required this.genres});

  static const _style = TextStyle(fontSize: 11);
  static const _chipHPad = 8.0;

  double _chipWidth(String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width + _chipHPad * 2;
  }

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox(height: 20);
    return LayoutBuilder(builder: (context, c) {
      const spacing = 4.0;
      const overflowW = 42.0; // "+N" 칩 예약 폭
      double used = 0;
      final visible = <String>[];
      for (var i = 0; i < genres.length; i++) {
        final w = _chipWidth(genres[i]) + (visible.isEmpty ? 0 : spacing);
        final needReserve = i < genres.length - 1;
        if (used + w + (needReserve ? spacing + overflowW : 0) <= c.maxWidth) {
          used += w;
          visible.add(genres[i]);
        } else {
          break;
        }
      }
      final hidden = genres.length - visible.length;
      return Row(
        children: [
          for (final g in visible) ...[
            _chip(context, g),
            const SizedBox(width: spacing),
          ],
          if (hidden > 0)
            InkWell(
              onTap: () => _showAll(context),
              borderRadius: BorderRadius.circular(999),
              child: _chip(context, '+$hidden', accent: true),
            ),
        ],
      );
    });
  }

  Widget _chip(BuildContext context, String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _chipHPad, vertical: 2),
      decoration: BoxDecoration(
        color: accent ? kPrimaryColor.withValues(alpha: 0.14) : context.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: accent ? kPrimaryColor : null)),
    );
  }

  void _showAll(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('장르'),
        content: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final g in genres) _chip(ctx, g)],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }
}
