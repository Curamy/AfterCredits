import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/theme.dart';

/// 5각형 레이더 차트 (내 점수 vs 전체 평균). btc_review RadarChart 계승.
class ReviewRadarChart extends StatelessWidget {
  final Map<String, int> current;
  final Map<String, double> average;
  final String movieTitle;
  final List<ScoreMetric> metrics;

  const ReviewRadarChart({
    super.key,
    required this.current,
    required this.average,
    required this.movieTitle,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final labels = metrics.map((m) => m.label).toList();
    final gridColor = context.isDark
        ? const Color(0xFF3A4049)
        : Colors.grey.shade300;
    final titleColor = context.isDark
        ? const Color(0xFFD1D5DB)
        : const Color(0xFF374151);

    List<RadarEntry> entriesFrom(num Function(String key) get) =>
        metrics.map((m) => RadarEntry(value: get(m.key).toDouble())).toList();

    final wide = MediaQuery.of(context).size.width >= kMobileBreakpoint;

    String wrapIfLong(String label) {
      if (label.length <= 5) return label;
      final mid = (label.length / 2).ceil();
      return '${label.substring(0, mid)}\n${label.substring(mid)}';
    }

    // 눈금(0,2,4,6,8,10) 숫자 색상 — fl_chart 내장 눈금은 소수점(.0)이 강제로
    // 붙기 때문에 내장 눈금은 투명 처리하고, 같은 위치에 정수 텍스트를 직접 겹쳐 그린다.
    final tickColor = context.isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF4B5563);
    const tickFontSize = 13.0;

    // 모바일은 폭이 좁아 차트가 어차피 폭에 맞춰 작게 그려지므로, 박스 높이를
    // 폭 기준으로 계산해 위아래 빈 여백이 과하게 남지 않도록 한다.
    final screenWidth = MediaQuery.of(context).size.width;
    final chartHeight =
        wide ? 480.0 : (screenWidth * 0.95).clamp(280.0, 420.0);

    return SectionColumn(
      children: [
        Padding(
          // 라벨이 오각형 밖에 놓일 공간 확보 (넓은 화면은 여유가 더 많음)
          padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 16),
          child: SizedBox(
            height: chartHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final centerX = constraints.maxWidth / 2;
                final centerY = constraints.maxHeight / 2;
                final radius = math.min(centerX, centerY) * 0.8;
                return Stack(
                  children: [
                    RadarChart(
                      RadarChartData(
                        radarShape: RadarShape.polygon,
                        tickCount: 5,
                        ticksTextStyle: const TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                        ),
                        radarBorderData: BorderSide(color: gridColor, width: 1),
                        gridBorderData: BorderSide(color: gridColor, width: 1),
                        tickBorderData: BorderSide(color: gridColor, width: 1),
                        titlePositionPercentageOffset: 0.13,
                        titleTextStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        getTitle: (index, angle) {
                          // 상단 좌·우(2번째·5번째) 라벨은 안쪽으로 파고들기 쉬워 더 바깥으로 +
                          // 5글자를 넘으면 두 줄로 접어 폭을 줄인다.
                          // (줄바꿈 자체가 폭을 줄여주므로 오프셋은 굳이 더 키우지 않는다 —
                          //  키우면 모서리와 여백이 생기고 좁은 화면에서 밖으로 밀려난다.)
                          final upper = index == 1 || index == 4;
                          final label = labels[index % labels.length];
                          final text = upper ? wrapIfLong(label) : label;
                          return RadarChartTitle(
                            text: text,
                            positionPercentageOffset: upper ? 0.24 : 0.11,
                          );
                        },
                        dataSets: [
                          // 축을 0~10으로 고정하기 위한 투명 데이터셋 2개(최소 0, 최대 10).
                          // fl_chart는 데이터 min~max로 스케일링하므로 양 끝을 강제로 심는다.
                          RadarDataSet(
                            dataEntries: List.generate(
                              labels.length,
                              (_) => const RadarEntry(value: 0),
                            ),
                            borderColor: Colors.transparent,
                            fillColor: Colors.transparent,
                            entryRadius: 0,
                            borderWidth: 0,
                          ),
                          RadarDataSet(
                            dataEntries: List.generate(
                              labels.length,
                              (_) => const RadarEntry(value: 10),
                            ),
                            borderColor: Colors.transparent,
                            fillColor: Colors.transparent,
                            entryRadius: 0,
                            borderWidth: 0,
                          ),
                          // 전체 평균 (빨강)
                          RadarDataSet(
                            dataEntries: entriesFrom((k) => average[k] ?? 0),
                            borderColor: kAverageColor,
                            fillColor: kAverageColor.withValues(alpha: 0.25),
                            borderWidth: 2,
                            entryRadius: 2,
                          ),
                          // 내 점수 (파랑)
                          RadarDataSet(
                            dataEntries: entriesFrom((k) => current[k] ?? 0),
                            borderColor: kPrimaryColor,
                            fillColor: kPrimaryColor.withValues(alpha: 0.4),
                            borderWidth: 2,
                            entryRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    // 2점 간격(2,4,6,8,10) 축 눈금을 소수점 없이 직접 표시.
                    for (final v in [2, 4, 6, 8, 10])
                      Positioned(
                        left: centerX + 6,
                        top: centerY - radius * (v / 10) - tickFontSize,
                        child: IgnorePointer(
                          child: Text(
                            '$v',
                            style: TextStyle(
                              color: tickColor,
                              fontSize: tickFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 긴 제목도 좁은 화면에서 줄바꿈되도록 Wrap 사용
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            _LegendDot(color: kPrimaryColor, label: movieTitle),
            const _LegendDot(color: kAverageColor, label: '내 전체 평균'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 내부 전용: 세로 배치 헬퍼
class SectionColumn extends StatelessWidget {
  final List<Widget> children;
  const SectionColumn({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}
