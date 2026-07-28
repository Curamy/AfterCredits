import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/detail_screen.dart';
import 'screens/form_screen.dart';
import 'screens/inquiries_screen.dart';
import 'screens/notices_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/settings_screen.dart';
import 'state/providers.dart';
import 'utils/theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RankingScreen()),
    GoRoute(
      path: '/review/:id',
      builder: (context, state) =>
          DetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(path: '/create', builder: (context, state) => const FormScreen()),
    GoRoute(
      path: '/edit/:id',
      builder: (context, state) => FormScreen(id: state.pathParameters['id']),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/notices', builder: (context, state) => const NoticesScreen()),
    GoRoute(path: '/inquiries', builder: (context, state) => const InquiriesScreen()),
  ],
);

class MovieReviewApp extends ConsumerWidget {
  const MovieReviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '애프터 크레딧',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // 날짜 선택기 등 기본 위젯을 한국어로 (기본은 영어)
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: buildLightTheme('NotoSansKR'),
      darkTheme: buildDarkTheme('NotoSansKR'),
    );
  }
}
