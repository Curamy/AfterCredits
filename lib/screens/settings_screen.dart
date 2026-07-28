import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_profile.dart';
import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/max_width_body.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _save(WidgetRef ref, UserProfile updated) =>
      ref.read(userServiceProvider).save(updated);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: MaxWidthBody(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: context.subtleText,
                    ),
                    const SizedBox(width: 12),
                    const Text('설정',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),

                // 테마
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('화면 테마',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ThemeCard(
                            icon: Icons.light_mode,
                            label: '라이트',
                            selected: profile.themeMode == 'light',
                            onTap: () =>
                                _save(ref, profile.copyWith(themeMode: 'light')),
                          ),
                          const SizedBox(width: 10),
                          _ThemeCard(
                            icon: Icons.dark_mode,
                            label: '다크',
                            selected: profile.themeMode == 'dark',
                            onTap: () =>
                                _save(ref, profile.copyWith(themeMode: 'dark')),
                          ),
                          const SizedBox(width: 10),
                          _ThemeCard(
                            icon: Icons.desktop_windows,
                            label: '시스템',
                            selected: profile.themeMode == 'system',
                            onTap: () =>
                                _save(ref, profile.copyWith(themeMode: 'system')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 표시 옵션
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('사진 미리보기'),
                        subtitle: Text('랭킹 목록에 첨부 사진 썸네일 표시',
                            style: TextStyle(color: context.subtleText, fontSize: 12)),
                        value: profile.showPhotoPreview,
                        onChanged: (v) =>
                            _save(ref, profile.copyWith(showPhotoPreview: v)),
                      ),
                      Divider(height: 1, color: context.chipBg),
                      SwitchListTile(
                        title: const Text('영화 추천'),
                        subtitle: Text('리뷰 작성 시 현재 상영작 목록 표시',
                            style: TextStyle(color: context.subtleText, fontSize: 12)),
                        value: profile.showRecommendations,
                        onChanged: (v) =>
                            _save(ref, profile.copyWith(showRecommendations: v)),
                      ),
                      Divider(height: 1, color: context.chipBg),
                      SwitchListTile(
                        title: const Text('밀어서 수정·삭제'),
                        subtitle: Text('목록에서 카드를 좌우로 밀어 수정/삭제 (모바일 전용)',
                            style: TextStyle(color: context.subtleText, fontSize: 12)),
                        value: profile.enableSwipeActions,
                        onChanged: (v) =>
                            _save(ref, profile.copyWith(enableSwipeActions: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 테마 선택 카드 (직사각형, 아이콘 위 + 라벨 아래, 선택 시 강조).
class _ThemeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = context.subtleText;
    final color = selected ? kPrimaryColor : base;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: selected
                ? kPrimaryColor.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: selected ? kPrimaryColor : context.scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
