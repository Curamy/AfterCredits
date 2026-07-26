import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/kakao_login_button.dart';
import '../widgets/max_width_body.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/review_card.dart';

/// 메인 랭킹 화면 (totalScore 내림차순). btc_review ReviewList 계승.
class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsProvider);
    final filtered = ref.watch(filteredReviewsProvider);
    final loggedIn = ref.watch(isLoggedInProvider);
    final showPhoto = ref.watch(showPhotoPreviewProvider);

    // 로그인 전에는 목록을 아예 노출하지 않는다 (개인 기록이므로)
    if (!loggedIn) return const _LoggedOutView();

    return Scaffold(
      body: SafeArea(
        child: reviewsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('데이터를 불러오지 못했습니다.\n$e', textAlign: TextAlign.center),
            ),
          ),
          // 콘텐츠와 '리뷰 작성' 버튼을 같은 최대폭(1152) 영역 안에 겹쳐 배치.
          // → 버튼이 화면 구석이 아니라 콘텐츠 우측 하단에 위치한다.
          data: (_) => MaxWidthBody(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더: 제목 + 로그인/프로필
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    'assets/icons/lighticon_tp.png',
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('애프터 크레딧',
                                      style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('총 ${filtered.length}편의 영화를 감상했습니다',
                                  style: TextStyle(color: context.subtleText)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const AuthWidget(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const FilterBar(),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text('아직 기록된 영화가 없습니다.',
                              style: TextStyle(color: context.hintText)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          // 웹은 세로 스크롤바가 점수를 가리므로 우측 여백 추가
                          padding: EdgeInsets.only(
                              bottom: 88, right: kIsWeb ? 12 : 0),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => ReviewCard(
                            review: filtered[i],
                            rank: i + 1,
                            showPhotoPreview: showPhoto,
                            onTap: () => context.push('/review/${filtered[i].id}'),
                          ),
                        ),
                      ),
                  ],
                ),
                // 콘텐츠 영역 기준 우측 하단
                Positioned(
                  right: 0,
                  bottom: 8,
                  child: FloatingActionButton.extended(
                    onPressed: () => context.push('/create'),
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('리뷰 작성',
                        style:
                            TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 로그아웃 상태 화면 — 개인 기록이므로 로그인 전에는 아무 리뷰도 보여주지 않는다.
class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/lighticon_tp.png',
                  width: 86,
                  height: 86,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text('애프터 크레딧',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('지금 나만의 영화 기록을 남겨 보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.subtleText)),
                const SizedBox(height: 24),
                const KakaoLoginButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 로그인 전: 카카오 로그인 버튼 / 로그인 후: 프로필 원형 + 메뉴(프로필·설정·로그아웃)
class AuthWidget extends ConsumerWidget {
  const AuthWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user == null) {
      return const KakaoLoginButton(compact: true);
    }

    final profile = ref.watch(currentProfileProvider);
    // 표시 이름/사진: 프로필 오버라이드 우선, 없으면 카카오 값
    final name = profile?.nickname ??
        (user.displayName?.isNotEmpty == true
            ? user.displayName!
            : (user.email ?? '내 계정'));
    final photo = (profile?.useDefaultPhoto ?? false)
        ? null
        : (profile?.photoUrl ?? user.photoURL);

    // 좁은 화면에서는 이름을 숨겨 공간을 확보 (이름은 메뉴 안에도 표시됨)
    final isWide = MediaQuery.of(context).size.width >= kMobileBreakpoint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileAvatar(photoUrl: photo),
        if (isWide) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text('$name 님',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
        PopupMenuButton<String>(
          tooltip: '메뉴',
          icon: Icon(Icons.menu, color: context.subtleText),
          offset: const Offset(0, 44),
          onSelected: (v) async {
            switch (v) {
              case 'profile':
                context.push('/profile');
              case 'settings':
                context.push('/settings');
              case 'logout':
                await ref.read(authServiceProvider).signOut();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text('$name 님',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'profile', child: Text('프로필')),
            const PopupMenuItem(value: 'settings', child: Text('설정')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
          ],
        ),
      ],
    );
  }
}
