// 기본 위젯 테스트 자리표시자.
// 앱 전체 테스트는 Firebase 초기화가 필요하므로 별도 통합 테스트로 다룬다.
import 'package:flutter_test/flutter_test.dart';

import 'package:after_credits/models/movie_review.dart';

void main() {
  test('averageOf: 5지표 평균 계산', () {
    final scores = {
      'fun': 8,
      'story': 6,
      'immersion': 7,
      'av': 9,
      'originality': 5,
    };
    expect(MovieReview.averageOf(scores), 7.0);
  });
}
