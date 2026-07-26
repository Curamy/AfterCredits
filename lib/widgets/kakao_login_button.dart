import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// 카카오 로그인 버튼 (카카오 브랜드 컬러 #FEE500 + 검정 텍스트).
/// [compact]이면 아이콘+짧은 라벨로 헤더에 들어갈 크기가 된다.
class KakaoLoginButton extends ConsumerStatefulWidget {
  final bool compact;
  const KakaoLoginButton({super.key, this.compact = false});

  @override
  ConsumerState<KakaoLoginButton> createState() => _KakaoLoginButtonState();
}

class _KakaoLoginButtonState extends ConsumerState<KakaoLoginButton> {
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithKakao();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const kakaoYellow = Color(0xFFFEE500);
    const kakaoBrown = Color(0xFF191600);

    return ElevatedButton(
      onPressed: _loading ? null : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: kakaoYellow,
        foregroundColor: kakaoBrown,
        disabledBackgroundColor: kakaoYellow.withValues(alpha: 0.6),
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 14 : 24,
          vertical: widget.compact ? 12 : 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: kakaoBrown),
            )
          else
            const Icon(Icons.chat_bubble, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.compact ? '카카오 로그인' : '카카오 계정으로 로그인',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
