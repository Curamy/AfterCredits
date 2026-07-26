import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// 감상연도 / 국내·해외 / 장르 3필터 (btc_review FilterBar 계승)
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final years = ref.watch(availableYearsProvider);
    final genres = ref.watch(availableGenresProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FilterDropdown<int>(
          hint: '감상 연도',
          value: filter.year,
          items: {for (final y in years) '$y년': y},
          onSelected: notifier.setYear,
        ),
        _FilterDropdown<String>(
          hint: '국내·해외',
          value: filter.country,
          items: const {kDomestic: kDomestic, kOverseas: kOverseas},
          onSelected: notifier.setCountry,
        ),
        _FilterDropdown<String>(
          hint: '장르',
          value: filter.genre,
          items: {for (final g in genres) g: g},
          onSelected: notifier.setGenre,
        ),
        if (!filter.isEmpty)
          TextButton.icon(
            onPressed: notifier.clear,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('필터 해제'),
            style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
          ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final Map<String, T> items; // 표시 라벨 → 값
  final ValueChanged<T?> onSelected;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onSelected,
  });

  String get _label {
    if (value == null) return hint;
    final entry = items.entries.where((e) => e.value == value);
    return entry.isNotEmpty ? entry.first.key : hint;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T?>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<T?>(value: null, child: const Text('전체 보기')),
        ...items.entries.map(
          (e) => PopupMenuItem<T?>(value: e.value, child: Text(e.key)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: value != null ? kPrimaryColor.withValues(alpha: 0.12) : context.cardBg,
          border: Border.all(
              color: value != null ? kPrimaryColor : context.scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_label,
                style: TextStyle(
                    color: value != null ? kPrimaryColor : null,
                    fontWeight: value != null ? FontWeight.w600 : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 18,
                color: value != null ? kPrimaryColor : context.subtleText),
          ],
        ),
      ),
    );
  }
}
