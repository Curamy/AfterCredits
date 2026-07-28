import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/max_width_body.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nickname = TextEditingController();
  final Map<String, TextEditingController> _labelCtrls = {};
  final Map<String, TextEditingController> _descCtrls = {};

  String? _photoUrl; // 표시용(카카오 or 업로드)
  bool _useDefaultPhoto = false;
  Uint8List? _pendingAvatarBytes; // 저장 시 업로드할 새 사진
  bool _saving = false;
  bool _inited = false;

  @override
  void dispose() {
    _nickname.dispose();
    for (final c in _labelCtrls.values) {
      c.dispose();
    }
    for (final c in _descCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFrom(UserProfile profile, String? kakaoPhoto) {
    _nickname.text = profile.nickname ?? '';
    _useDefaultPhoto = profile.useDefaultPhoto;
    _photoUrl = _useDefaultPhoto ? null : (profile.photoUrl ?? kakaoPhoto);
    for (final m in profile.effectiveMetrics) {
      _labelCtrls[m.key] = TextEditingController(text: m.label);
      _descCtrls[m.key] = TextEditingController(text: m.description);
    }
    _inited = true;
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 512);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _pendingAvatarBytes = bytes;
      _useDefaultPhoto = false;
    });
  }

  void _useDefault() {
    setState(() {
      _useDefaultPhoto = true;
      _pendingAvatarBytes = null;
      _photoUrl = null;
    });
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
            '회원탈퇴 시 작성한 모든 리뷰·사진·프로필이 영구적으로 삭제되며 되돌릴 수 없습니다.\n정말 탈퇴하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('탈퇴', style: TextStyle(color: kAverageColor)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).deleteAccount();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('탈퇴 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetCriteria() {
    setState(() {
      for (final d in kDefaultScoreMetrics) {
        _labelCtrls[d.key]!.text = d.label;
        _descCtrls[d.key]!.text = d.description;
      }
    });
  }

  /// 글자 수 제한 위반 시 저장을 막고 이유를 알려준다.
  /// null 반환 = 통과.
  String? _validate() {
    if (_nickname.text.trim().length > kNicknameMax) {
      return '닉네임은 $kNicknameMax자 이내로 입력해주세요.';
    }
    for (var i = 0; i < kDefaultScoreMetrics.length; i++) {
      final d = kDefaultScoreMetrics[i];
      final label = _labelCtrls[d.key]!.text.trim();
      final desc = _descCtrls[d.key]!.text.trim();
      if (label.length > kCriteriaLabelMax || desc.length > kCriteriaDescMax) {
        return '${i + 1}번 항목의 글자 수 제한을 확인해주세요. (제목 $kCriteriaLabelMax자·설명 $kCriteriaDescMax자 이내)';
      }
    }
    return null;
  }

  Future<void> _save(UserProfile base) async {
    // IME(한글 등) 조합 중인 문자가 아직 컨트롤러에 반영되지 않은 채로
    // 저장 버튼이 눌리는 것을 막기 위해 포커스를 먼저 해제해 조합을 확정한다.
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);

    if (!mounted) return;
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final userService = ref.read(userServiceProvider);

      // 새 사진 업로드
      String? photoUrl = base.photoUrl;
      if (_useDefaultPhoto) {
        photoUrl = null;
      } else if (_pendingAvatarBytes != null) {
        photoUrl = await userService.uploadAvatar(uid, _pendingAvatarBytes!);
      }

      // 기준 오버라이드: 기본값과 다른 것만 저장
      final overrides = <String, CriteriaOverride>{};
      for (final d in kDefaultScoreMetrics) {
        final label = _labelCtrls[d.key]!.text.trim();
        final desc = _descCtrls[d.key]!.text.trim();
        if (label != d.label || desc != d.description) {
          overrides[d.key] = CriteriaOverride(
            label: label.isEmpty ? d.label : label,
            description: desc,
          );
        }
      }

      final nick = _nickname.text.trim();
      final updated = base.copyWith(
        nickname: nick.isEmpty ? null : nick,
        clearNickname: nick.isEmpty,
        photoUrl: photoUrl,
        clearPhotoUrl: photoUrl == null,
        useDefaultPhoto: _useDefaultPhoto,
        criteria: overrides,
      );
      await userService.save(updated);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('프로필이 저장되었습니다.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;
    // Firestore 프로필이 실제로 로드된 뒤에 폼을 초기화 (기본값 레이스 방지)
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.asData?.value;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_inited) _initFrom(profile, user.photoURL);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: MaxWidthBody(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(title: '프로필'),
                const SizedBox(height: 20),

                // 프로필 사진
                SectionCard(
                  child: Column(
                    children: [
                      _pendingAvatarBytes != null
                          ? ClipOval(
                              child: Image.memory(_pendingAvatarBytes!,
                                  width: 88, height: 88, fit: BoxFit.cover))
                          : ProfileAvatar(
                              photoUrl: _useDefaultPhoto ? null : _photoUrl,
                              size: 88),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickAvatar,
                            icon: const Icon(Icons.upload, size: 18),
                            label: const Text('사진 업로드'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _useDefault,
                            icon: const Icon(Icons.person, size: 18),
                            label: const Text('기본 프로필로 설정'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 닉네임
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('닉네임',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nickname,
                        maxLength: kNicknameMax,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(kNicknameMax)
                        ],
                        decoration: InputDecoration(
                          hintText: user.displayName ?? '닉네임 입력',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: _saving ? null : _confirmDeleteAccount,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Text('회원탈퇴',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.hintText,
                              decoration: TextDecoration.underline)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // 평가 기준 커스터마이징
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('평가 기준',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          TextButton.icon(
                            onPressed: _resetCriteria,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('기본값'),
                          ),
                        ],
                      ),
                      Text('영화를 평가하는 5가지 항목을 나만의 기준으로 커스터마이징 할 수 있습니다.',
                          style: TextStyle(fontSize: 12, color: context.subtleText)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < kDefaultScoreMetrics.length; i++)
                        _criteriaEditor(i, kDefaultScoreMetrics[i].key),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _saving ? null : () => _save(profile),
                  style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      minimumSize: const Size.fromHeight(50)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('저장'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _criteriaEditor(int index, String key) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}번 항목',
              style: TextStyle(fontSize: 12, color: context.subtleText)),
          const SizedBox(height: 6),
          TextField(
            controller: _labelCtrls[key],
            maxLength: kCriteriaLabelMax,
            decoration: InputDecoration(
              labelText: '제목',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(kCriteriaLabelMax)],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrls[key],
            maxLength: kCriteriaDescMax,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              labelText: '설명',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(kCriteriaDescMax)],
          ),
        ],
      ),
    );
  }
}

/// 콘텐츠 영역 좌측 상단 뒤로가기 + 제목
class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_back),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: context.subtleText,
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
