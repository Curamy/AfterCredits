import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/movie_review.dart';
import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/open_url.dart';
import '../utils/theme.dart';
import '../widgets/max_width_body.dart';
import '../widgets/photo_section.dart';
import '../widgets/radar_chart.dart';

/// 리뷰 상세 화면. btc_review ReviewDetail 계승.
class DetailScreen extends ConsumerWidget {
  final String id;
  const DetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(reviewByIdProvider(id));
    final average = ref.watch(averageScoresProvider);
    final loggedIn = ref.watch(isLoggedInProvider);

    // 로그인 전에는 URL 직접 접근으로도 열람할 수 없게 차단
    if (!loggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('로그인이 필요합니다',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('처음으로'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (review) {
          if (review == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('리뷰를 찾을 수 없습니다.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    style: FilledButton.styleFrom(backgroundColor: kPrimaryColor),
                    child: const Text('목록으로'),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            child: MaxWidthBody(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 뒤로가기: 화면 끝이 아니라 콘텐츠 영역 좌측 상단에 배치
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: '목록으로',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: context.subtleText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Header(review: review),
                  const SizedBox(height: 16),
                  _InfoBox(review: review),
                  const SizedBox(height: 16),
                  SectionCard(
                      child: ReviewRadarChart(
                    current: review.scores,
                    average: average,
                    movieTitle: review.title,
                    // 리뷰에 저장된 평가 기준 스냅샷을 우선 사용 — 이후 프로필에서
                    // 기준을 바꿔도 이미 저장된 리뷰의 차트는 바뀌지 않는다.
                    // 스냅샷이 없는(과거) 리뷰는 현재 기준을 그대로 보여준다.
                    metrics: review.metricLabels.isEmpty
                        ? ref.watch(scoreMetricsProvider)
                        : kDefaultScoreMetrics
                            .map((d) => ScoreMetric(
                                d.key,
                                review.metricLabels[d.key] ?? d.label,
                                d.description))
                            .toList(),
                  )),
                  if (review.review.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('후기',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(review.review, style: const TextStyle(height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                  if (review.photos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    PhotoSection(
                        photos: review.displayPhotos,
                        fullPhotos: review.photos),
                  ],
                  if (loggedIn) ...[
                    const SizedBox(height: 20),
                    _ActionButtons(review: review),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

/// 영화 제목 — 탭하면 TMDB의 해당 영화 페이지로 이동.
class _TmdbTitleLink extends StatelessWidget {
  final String title;
  final int tmdbId;
  const _TmdbTitleLink({required this.title, required this.tmdbId});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => openExternalUrl(
            'https://www.themoviedb.org/movie/$tmdbId?language=ko-KR'),
        child: Text(title,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final MovieReview review;
  const _Header({required this.review});

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(review.posterPath, size: 'w500');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 100,
            height: 150,
            child: poster == null
                ? Container(color: Colors.grey.shade200, child: const Icon(Icons.movie))
                : CachedNetworkImage(
                    imageUrl: poster, fit: BoxFit.cover, memCacheWidth: 300),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: review.tmdbId == null
                        ? Text(review.title,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold))
                        : _TmdbTitleLink(
                            title: review.title, tmdbId: review.tmdbId!),
                  ),
                  const SizedBox(width: 8),
                  Text(review.totalScore.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (review.releaseYear != null) '${review.releaseYear}',
                  review.country,
                  if (review.theater.isNotEmpty) review.theater,
                ].join('  ·  '),
                style: TextStyle(color: context.subtleText),
              ),
              if (review.specialFormats.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in review.specialFormats)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(f,
                            style: const TextStyle(fontSize: 11, color: kPrimaryColor)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in review.genres)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(g, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final MovieReview review;
  const _InfoBox({required this.review});

  @override
  Widget build(BuildContext context) {
    final items = <List<String>>[
      ['시청 날짜', review.watchDate],
      ['러닝타임', review.runtime != null ? '${review.runtime}분' : '-'],
      ['난이도', '${review.difficulty}점'],
      ['수위', '${review.maturity}점'],
    ];
    Widget item(int i, CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          children: [
            Text(items[i][0],
                style: TextStyle(fontSize: 12, color: context.subtleText)),
            const SizedBox(height: 4),
            Text(items[i][1], style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        );

    final wide = MediaQuery.of(context).size.width >= kMobileBreakpoint;

    return SectionCard(
      child: wide
          // PC: 폭이 동일한 4칸으로 나눠 0%·25%·50%·75% 위치에 좌측정렬.
          ? Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(child: item(i, CrossAxisAlignment.start)),
              ],
            )
          // 모바일/태블릿: 첫 항목은 좌측 끝, 마지막 항목은 우측 끝에 맞춘 양쪽정렬.
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < items.length; i++)
                  item(
                      i,
                      i == 0
                          ? CrossAxisAlignment.start
                          : i == items.length - 1
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.center),
              ],
            ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final MovieReview review;
  const _ActionButtons({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/edit/${review.id}'),
            style: FilledButton.styleFrom(
                backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
            icon: const Icon(Icons.edit),
            label: const Text('수정'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            style: FilledButton.styleFrom(
                backgroundColor: kAverageColor, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete),
            label: const Text('삭제'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
    if (ok != true) return;
    if (!context.mounted) return;
    final storage = ref.read(storageServiceProvider);
    final photos = List<String>.of(review.photos);
    // Firestore 문서가 삭제되면 이 화면이 보고 있던 리뷰 스트림이 곧바로 null을
    // 내보내면서(로컬 캐시 낙관적 반영) 화면이 '찾을 수 없음'으로 먼저 리렌더되어
    // 버튼(따라서 context)이 사라져버릴 수 있다 — 그래서 mounted 체크가 걸려
    // 삭제 후 자동 이동이 씹혔다. 라우터를 먼저 확보해 삭제보다 먼저 이동시킨다.
    final router = GoRouter.of(context);
    router.go('/');
    await ref.read(reviewServiceProvider).delete(review.id!);
    // 사진은 뒤에서 정리 (네비게이션을 막지 않음)
    for (final url in photos) {
      storage.deleteByUrl(url);
    }
  }
}
