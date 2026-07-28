import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/inquiry.dart';
import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/max_width_body.dart';

/// 내가 남긴 1:1 문의와 운영자 답변 목록
class InquiriesScreen extends ConsumerWidget {
  const InquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myInquiriesProvider);

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
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/notices'),
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: context.subtleText,
                    ),
                    const SizedBox(width: 12),
                    const Text('1:1 문의내역',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('불러오지 못했습니다.\n$e',
                        textAlign: TextAlign.center)),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text('아직 남긴 문의가 없습니다.',
                              style: TextStyle(color: context.hintText)),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final inquiry in list) ...[
                          InquiryCard(inquiry: inquiry),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 문의 1건 + 운영자 답변
class InquiryCard extends StatelessWidget {
  final Inquiry inquiry;
  const InquiryCard({super.key, required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final answered = inquiry.isAnswered;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(inquiry.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: answered
                      ? kPrimaryColor.withValues(alpha: 0.14)
                      : context.chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(answered ? '답변 완료' : '답변 대기',
                    style: TextStyle(
                        fontSize: 11,
                        color: answered ? kPrimaryColor : context.subtleText)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_formatDate(inquiry.createdAt),
              style: TextStyle(fontSize: 11, color: context.hintText)),
          const SizedBox(height: 10),
          Text(inquiry.message, style: const TextStyle(height: 1.45)),
          if (answered) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.chipBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 14, color: kPrimaryColor),
                      const SizedBox(width: 4),
                      const Text('답변',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor)),
                      const Spacer(),
                      if (inquiry.repliedAt != null)
                        Text(_formatDate(inquiry.repliedAt!),
                            style: TextStyle(
                                fontSize: 11, color: context.hintText)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(inquiry.reply!,
                      style: const TextStyle(height: 1.45, fontSize: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
