import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../utils/changelog.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/max_width_body.dart';

/// 공지사항 — 업데이트 내역 + 하단에 1:1 문의하기
class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myInquiries = ref.watch(myInquiriesProvider).asData?.value ?? const [];

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
                    const Text('공지사항',
                        style:
                            TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('v$kAppVersion',
                        style:
                            TextStyle(color: context.subtleText, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 20),
                for (final release in kChangelog) ...[
                  _ReleaseCard(release: release),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                Divider(color: context.scheme.outlineVariant),
                const SizedBox(height: 20),

                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.push('/inquiries'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                            ),
                            icon: const Icon(Icons.history, size: 18),
                            label: Text(myInquiries.isEmpty
                                ? '1:1 문의내역'
                                : '1:1 문의내역 (${myInquiries.length})'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () => _openInquiry(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                            ),
                            icon: const Icon(Icons.mail_outline, size: 18),
                            label: const Text('1:1 문의하기'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Email) $kContactEmail',
                          style: TextStyle(
                              color: context.hintText, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openInquiry(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _InquirySheet(),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final AppRelease release;
  const _ReleaseCard({required this.release});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('v${release.version}',
                    style: const TextStyle(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const Spacer(),
              Text(release.date,
                  style: TextStyle(color: context.subtleText, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in release.changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.subtleText,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                      child: Text(line,
                          style: const TextStyle(height: 1.45, fontSize: 14))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InquirySheet extends ConsumerStatefulWidget {
  const _InquirySheet();

  @override
  ConsumerState<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends ConsumerState<_InquirySheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('문의 내용을 입력해주세요.')));
      return;
    }
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(inquiryServiceProvider).create(
            uid: uid,
            subject:
                _subject.text.trim().isEmpty ? '문의' : _subject.text.trim(),
            message: _message.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('문의가 접수되었습니다. 답변은 공지사항에서 확인할 수 있어요.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1:1 문의하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('답변이 등록되면 공지사항 화면에서 확인할 수 있습니다.',
              style: TextStyle(color: context.subtleText, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _subject,
            decoration: InputDecoration(
              labelText: '제목',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _message,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: '문의 내용',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('보내기'),
          ),
        ],
      ),
    );
  }
}
