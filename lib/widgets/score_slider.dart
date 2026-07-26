import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// 0~10 점수 슬라이더 한 줄 (라벨 + 설명 + 값 + 슬라이더).
/// 폼의 평가 지표 / 난이도 / 수위 입력에 공용으로 사용.
class ScoreSlider extends StatelessWidget {
  final String label;
  final String? description;
  final int value;
  final ValueChanged<int> onChanged;
  final String suffix;

  const ScoreSlider({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
    this.suffix = '점',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$value$suffix',
                style: const TextStyle(
                    color: kPrimaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          activeColor: kPrimaryColor,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

/// 목록 카드용 미니 인디케이터 (아이콘 + 색상 막대). btc_review renderSlider 계승.
class MiniScoreBar extends StatelessWidget {
  final IconData icon;
  final int value;
  final double width;
  const MiniScoreBar({
    super.key,
    required this.icon,
    required this.value,
    this.width = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Container(
          width: width,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (value / 10).clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: scoreColor(value),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
