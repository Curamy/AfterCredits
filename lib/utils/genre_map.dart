/// TMDB 영화 장르 ID → 한글 매핑
/// 참고: https://developer.themoviedb.org/reference/genre-movie-list
const Map<int, String> kTmdbGenreMap = {
  28: '액션',
  12: '모험',
  16: '애니메이션',
  35: '코미디',
  80: '범죄',
  99: '다큐멘터리',
  18: '드라마',
  10751: '가족',
  14: '판타지',
  36: '역사',
  27: '공포',
  10402: '음악',
  9648: '미스터리',
  10749: '로맨스',
  878: 'SF',
  10770: 'TV 영화',
  53: '스릴러',
  10752: '전쟁',
  37: '서부',
};

/// 장르 ID 목록 → 한글 장르명 목록 (매핑 없는 ID는 제외)
List<String> mapGenreIds(List<int> ids) {
  return ids
      .map((id) => kTmdbGenreMap[id])
      .whereType<String>()
      .toList();
}
