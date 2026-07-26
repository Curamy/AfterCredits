import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';
import '../utils/genre_map.dart';

/// TMDB 검색 결과 1건 (목록 표시용)
class TmdbSearchResult {
  final int tmdbId;
  final String title;
  final String originalTitle;
  final String? posterPath;
  final int? releaseYear;
  final String overview;

  const TmdbSearchResult({
    required this.tmdbId,
    required this.title,
    required this.originalTitle,
    this.posterPath,
    this.releaseYear,
    this.overview = '',
  });
}

/// TMDB 상세 정보 (영화 선택 시 폼 자동 채움용)
class TmdbMovieDetails {
  final int tmdbId;
  final String title;
  final String originalTitle;
  final String? posterPath;
  final int? releaseYear;
  final int? runtime; // 분
  final List<String> genres;
  final String country; // 국내 / 해외

  const TmdbMovieDetails({
    required this.tmdbId,
    required this.title,
    required this.originalTitle,
    this.posterPath,
    this.releaseYear,
    this.runtime,
    this.genres = const [],
    this.country = kDomestic,
  });
}

class TmdbException implements Exception {
  final String message;
  TmdbException(this.message);
  @override
  String toString() => 'TmdbException: $message';
}

/// TMDB API 클라이언트 (v3 엔드포인트 + v4 Bearer 토큰)
class TmdbService {
  static const String _base = 'https://api.themoviedb.org/3';

  String get _credential {
    final t = dotenv.env['TMDB_TOKEN'];
    if (t == null || t.isEmpty || t == 'PASTE_YOUR_TMDB_TOKEN_HERE') {
      throw TmdbException('TMDB_TOKEN이 설정되지 않았습니다 (.env 확인).');
    }
    return t;
  }

  /// v4 읽기 액세스 토큰(JWT, eyJ... )인지 v3 API Key(32자 hex)인지 자동 판별
  bool get _isV4Token => _credential.startsWith('eyJ');

  Map<String, String> get _headers => {
        'accept': 'application/json',
        if (_isV4Token) 'Authorization': 'Bearer $_credential',
      };

  /// 공통 쿼리 파라미터 (v3 키면 api_key 추가)
  Map<String, String> _params(Map<String, String> extra) => {
        if (!_isV4Token) 'api_key': _credential,
        ...extra,
      };

  static int? _yearFrom(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  /// 제목으로 영화 검색 (한국어, 한국 지역 우선)
  Future<List<TmdbSearchResult>> searchMovies(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/search/movie').replace(queryParameters: _params({
      'query': query,
      'language': 'ko-KR',
      'region': 'KR',
      'include_adult': 'false',
      'page': '1',
    }));
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw TmdbException('검색 실패 (${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? [];
    return results.map((r) {
      final m = r as Map<String, dynamic>;
      return TmdbSearchResult(
        tmdbId: (m['id'] as num).toInt(),
        title: (m['title'] as String?)?.isNotEmpty == true
            ? m['title'] as String
            : (m['original_title'] as String? ?? ''),
        originalTitle: m['original_title'] as String? ?? '',
        posterPath: m['poster_path'] as String?,
        releaseYear: _yearFrom(m['release_date'] as String?),
        overview: m['overview'] as String? ?? '',
      );
    }).toList();
  }

  /// 현재 상영작 (검색 전 기본 목록으로 표시)
  Future<List<TmdbSearchResult>> getNowPlaying() async {
    final uri = Uri.parse('$_base/movie/now_playing').replace(
        queryParameters: _params({'language': 'ko-KR', 'region': 'KR', 'page': '1'}));
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw TmdbException('상영작 조회 실패 (${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? [];
    return results.map((r) {
      final m = r as Map<String, dynamic>;
      return TmdbSearchResult(
        tmdbId: (m['id'] as num).toInt(),
        title: (m['title'] as String?)?.isNotEmpty == true
            ? m['title'] as String
            : (m['original_title'] as String? ?? ''),
        originalTitle: m['original_title'] as String? ?? '',
        posterPath: m['poster_path'] as String?,
        releaseYear: _yearFrom(m['release_date'] as String?),
        overview: m['overview'] as String? ?? '',
      );
    }).toList();
  }

  /// 영화 상세 (러닝타임·장르·제작국가 포함)
  Future<TmdbMovieDetails> getDetails(int tmdbId) async {
    final uri = Uri.parse('$_base/movie/$tmdbId')
        .replace(queryParameters: _params({'language': 'ko-KR'}));
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw TmdbException('상세 조회 실패 (${res.statusCode})');
    }
    final m = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    // 장르: TMDB가 이미 한글명을 주지만, 매핑 테이블로 표기 통일
    final genreIds = ((m['genres'] as List?) ?? [])
        .map((g) => (g as Map<String, dynamic>)['id'] as int)
        .toList();
    var genres = mapGenreIds(genreIds);
    if (genres.isEmpty) {
      genres = ((m['genres'] as List?) ?? [])
          .map((g) => (g as Map<String, dynamic>)['name'].toString())
          .toList();
    }

    // 제작국가로 국내/해외 판정 (KR 포함 시 국내)
    final countries = ((m['production_countries'] as List?) ?? [])
        .map((c) => (c as Map<String, dynamic>)['iso_3166_1'].toString())
        .toList();
    final isKorean = countries.contains('KR') ||
        (m['original_language'] as String?) == 'ko';

    return TmdbMovieDetails(
      tmdbId: tmdbId,
      title: (m['title'] as String?)?.isNotEmpty == true
          ? m['title'] as String
          : (m['original_title'] as String? ?? ''),
      originalTitle: m['original_title'] as String? ?? '',
      posterPath: m['poster_path'] as String?,
      releaseYear: _yearFrom(m['release_date'] as String?),
      runtime: (m['runtime'] as num?)?.toInt(),
      genres: genres,
      country: isKorean ? kDomestic : kOverseas,
    );
  }
}
