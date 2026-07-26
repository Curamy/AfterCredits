import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tmdb_service.dart';
import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// TMDB 영화 검색 자동완성 필드. 선택 시 상세정보를 조회해 콜백으로 전달.
class MovieSearchField extends ConsumerStatefulWidget {
  final ValueChanged<TmdbMovieDetails> onSelected;
  const MovieSearchField({super.key, required this.onSelected});

  @override
  ConsumerState<MovieSearchField> createState() => _MovieSearchFieldState();
}

class _MovieSearchFieldState extends ConsumerState<MovieSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<TmdbSearchResult> _results = [];
  List<TmdbSearchResult> _nowPlaying = [];
  bool _loading = false;
  String? _error;

  bool get _isSearching => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadNowPlaying();
  }

  Future<void> _loadNowPlaying() async {
    try {
      final res = await ref.read(tmdbServiceProvider).getNowPlaying();
      if (!mounted) return;
      setState(() => _nowPlaying = res);
    } catch (_) {
      // 상영작 로드 실패는 조용히 무시 (검색은 계속 가능)
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(tmdbServiceProvider).searchMovies(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is TmdbException ? e.message : '검색 중 오류가 발생했습니다';
        _loading = false;
      });
    }
  }

  Future<void> _select(TmdbSearchResult r) async {
    setState(() => _loading = true);
    try {
      final details = await ref.read(tmdbServiceProvider).getDetails(r.tmdbId);
      if (!mounted) return;
      widget.onSelected(details);
      setState(() {
        _controller.text = details.title;
        _results = [];
        _loading = false;
      });
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is TmdbException ? e.message : '상세 조회 중 오류가 발생했습니다';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: '영화 제목을 검색하세요',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: kAverageColor, fontSize: 13)),
          ),
        Builder(builder: (context) {
          // 검색 전 추천(현재 상영작)은 설정에서 끌 수 있다.
          final showRec = ref.watch(showRecommendationsProvider);
          final list = _isSearching
              ? _results
              : (showRec ? _nowPlaying : const <TmdbSearchResult>[]);
          if (list.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 340),
            decoration: BoxDecoration(
              color: context.cardBg,
              border: Border.all(color: context.scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isSearching)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.chipBg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                    ),
                    child: Text('현재 상영작',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: context.subtleText)),
                  ),
                Flexible(
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final r = list[i];
                      final poster = posterUrl(r.posterPath, size: 'w200');
                      return ListTile(
                        leading: SizedBox(
                          width: 40,
                          height: 60,
                          child: poster == null
                              ? Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.movie, size: 18))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
                                ),
                        ),
                        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            if (r.releaseYear != null) '${r.releaseYear}',
                            if (r.originalTitle.isNotEmpty && r.originalTitle != r.title)
                              r.originalTitle,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _select(r),
                      );
                    },
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
