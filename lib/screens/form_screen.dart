import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/movie_review.dart';
import '../services/tmdb_service.dart';
import '../state/providers.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/kakao_login_button.dart';
import '../widgets/max_width_body.dart';
import '../widgets/movie_search_field.dart';
import '../widgets/score_slider.dart';

/// 사진 항목: 기존 URL 또는 새로 고른 파일
class _PhotoItem {
  final String? url; // 기존 사진(원본)
  final String? thumbUrl; // 기존 사진의 축소본
  final XFile? file; // 새로 선택
  const _PhotoItem.url(this.url, {this.thumbUrl}) : file = null;
  const _PhotoItem.file(this.file)
      : url = null,
        thumbUrl = null;
  bool get isNew => file != null;

  /// 폼에서 미리보기로 띄울 URL (가능하면 가벼운 축소본)
  String? get previewUrl => thumbUrl ?? url;
}

/// 리뷰 등록·수정 폼. btc_review ReviewForm 계승.
class FormScreen extends ConsumerStatefulWidget {
  final String? id; // null이면 신규
  const FormScreen({super.key, this.id});

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<FormScreen> {
  final _theaterController = TextEditingController();
  final _reviewController = TextEditingController();
  final _etcController = TextEditingController();
  bool _etcSelected = false;

  int? _tmdbId;
  String _title = '';
  String _originalTitle = '';
  String? _posterPath;
  int? _releaseYear;
  int? _runtime;
  List<String> _genres = [];
  String _country = kDomestic;

  List<String> _specialFormats = [];
  DateTime? _watchDate;
  int _difficulty = 5;
  int _maturity = 5;
  Map<String, int> _scores = MovieReview.defaultScores();
  List<_PhotoItem> _photos = [];
  List<String> _originalPhotoUrls = [];
  List<String> _originalThumbUrls = [];

  bool _initializing = false;
  bool _saving = false;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  @override
  void dispose() {
    _theaterController.dispose();
    _reviewController.dispose();
    _etcController.dispose();
    super.dispose();
  }

  /// 프리셋에 없는 값 = '기타'로 직접 입력한 특별관 이름
  List<String> get _effectiveSpecialFormats {
    final etc = _etcController.text.trim();
    return [
      ..._specialFormats,
      if (_etcSelected && etc.isNotEmpty) etc,
    ];
  }

  Future<void> _loadExisting() async {
    setState(() => _initializing = true);
    final r = await ref.read(reviewServiceProvider).getById(widget.id!);
    if (r == null || !mounted) {
      setState(() => _initializing = false);
      return;
    }
    setState(() {
      _tmdbId = r.tmdbId;
      _title = r.title;
      _originalTitle = r.originalTitle;
      _posterPath = r.posterPath;
      _releaseYear = r.releaseYear;
      _runtime = r.runtime;
      _genres = List.of(r.genres);
      _country = r.country;
      _theaterController.text = r.theater;
      // 프리셋에 있는 값은 칩으로, 나머지는 '기타' 직접 입력으로 복원
      _specialFormats =
          r.specialFormats.where(kSpecialFormats.contains).toList();
      final custom =
          r.specialFormats.where((f) => !kSpecialFormats.contains(f)).toList();
      _etcSelected = custom.isNotEmpty;
      _etcController.text = custom.join(', ');
      _watchDate = r.watchDate.isNotEmpty ? DateTime.tryParse(r.watchDate) : null;
      _difficulty = r.difficulty;
      _maturity = r.maturity;
      _scores = Map.of(r.scores);
      _reviewController.text = r.review;
      _originalPhotoUrls = List.of(r.photos);
      _originalThumbUrls = List.of(r.photoThumbs);
      _photos = [
        for (var i = 0; i < r.photos.length; i++)
          _PhotoItem.url(r.photos[i],
              thumbUrl: i < r.photoThumbs.length ? r.photoThumbs[i] : null),
      ];
      _initializing = false;
    });
  }

  void _onMovieSelected(TmdbMovieDetails details) {
    setState(() {
      _tmdbId = details.tmdbId;
      _title = details.title;
      _originalTitle = details.originalTitle;
      _posterPath = details.posterPath;
      _releaseYear = details.releaseYear;
      _runtime = details.runtime;
      _genres = List<String>.of(details.genres);
      _country = details.country;
    });
  }

  // 웹 <input type=file>은 개수·파일형식을 브라우저/OS 단에서 강제할 수 없으므로
  // (accept="image/*"를 줘도 일부 브라우저의 사진 선택기가 동영상 등을 허용하는
  // 경우가 있음) 선택 이후 여기서 직접 개수·형식·용량을 검증한다.
  static const _maxPhotoBytes = 10 * 1024 * 1024; // 10MB
  static const _imageExtensions = {
    'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'gif', 'bmp'
  };

  bool _isImageFile(XFile x) {
    final mime = x.mimeType;
    if (mime != null) return mime.startsWith('image/');
    final ext = x.name.split('.').last.toLowerCase();
    return _imageExtensions.contains(ext);
  }

  Future<void> _pickPhoto() async {
    final remaining = 2 - _photos.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    // 갤러리 선택 화면에서 여러 장을 한 번에 고르면서(카카오톡/인스타그램처럼
    // 선택 순서 번호가 뜨는 것은 OS 제공 picker의 기본 동작) 순서까지 정할 수 있게
    // pickMultiImage를 쓴다. 남은 자리가 1장뿐이면 단일 선택으로 충분하다.
    // maxWidth로 원본 해상도를 제한한다. 요즘 폰 사진은 4000px가 넘어서 그대로
    // 올리면 화면에 띄울 때 디코딩 메모리가 수십 MB씩 잡히고, 특히 iOS 사파리는
    // 탭당 메모리 상한이 낮아 페이지가 통째로 죽는다.
    final List<XFile> picked;
    if (remaining == 1) {
      final x = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920);
      picked = x == null ? const [] : [x];
    } else {
      picked = await picker.pickMultiImage(
          imageQuality: 85, maxWidth: 1920, limit: remaining);
    }
    if (picked.isEmpty) return;

    final tooMany = picked.length > remaining;
    final candidates = picked.take(remaining);

    final accepted = <XFile>[];
    var rejectedType = false;
    var rejectedSize = false;
    for (final x in candidates) {
      if (!_isImageFile(x)) {
        rejectedType = true;
        continue;
      }
      if (await x.length() > _maxPhotoBytes) {
        rejectedSize = true;
        continue;
      }
      accepted.add(x);
    }

    if (accepted.isNotEmpty) {
      setState(() => _photos = [..._photos, ...accepted.map(_PhotoItem.file)]);
    }

    final warnings = <String>[
      if (tooMany) '사진은 최대 2장까지만 첨부할 수 있어요.',
      if (rejectedType) '이미지 파일만 첨부할 수 있어요.',
      if (rejectedSize) '사진 1장당 용량은 10MB를 넘을 수 없어요.',
    ];
    if (warnings.isNotEmpty) _snack(warnings.join(' '));
  }

  Future<void> _save() async {
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      _snack('로그인이 필요합니다.');
      return;
    }
    if (_title.trim().isEmpty) {
      _snack('영화를 검색해 선택해주세요.');
      return;
    }
    if (_watchDate == null) {
      _snack('시청 날짜를 선택해주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      final storage = ref.read(storageServiceProvider);

      // 1) 사진 업로드 (신규만). 목록/상세에서 쓸 축소본도 함께 만든다.
      final photoUrls = <String>[];
      final thumbUrls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (p.url != null) {
          photoUrls.add(p.url!);
          thumbUrls.add(p.thumbUrl ?? p.url!);
        } else if (p.file != null) {
          final Uint8List bytes = await p.file!.readAsBytes();
          final uploaded =
              await storage.uploadPhoto(uid: uid, bytes: bytes, index: i);
          photoUrls.add(uploaded.url);
          thumbUrls.add(uploaded.thumbUrl);
        }
      }
      // 2) 제거된 기존 사진 삭제 (썸네일도 함께)
      for (final old in _originalPhotoUrls) {
        if (!photoUrls.contains(old)) await storage.deleteByUrl(old);
      }
      for (final old in _originalThumbUrls) {
        if (!thumbUrls.contains(old) && !photoUrls.contains(old)) {
          await storage.deleteByUrl(old);
        }
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_watchDate!);
      // 현재 평가 기준을 스냅샷으로 저장 — 이후 프로필에서 기준을 바꿔도
      // 이미 저장된(수정하지 않는 한) 리뷰의 차트 라벨은 그대로 유지된다.
      final metrics = ref.read(scoreMetricsProvider);
      final metricLabels = {for (final m in metrics) m.key: m.label};
      final review = MovieReview(
        id: widget.id,
        ownerUid: uid,
        tmdbId: _tmdbId,
        title: _title,
        originalTitle: _originalTitle,
        posterPath: _posterPath,
        releaseYear: _releaseYear,
        runtime: _runtime,
        genres: _genres,
        country: _country,
        theater: _theaterController.text.trim(),
        specialFormats: _effectiveSpecialFormats,
        watchDate: dateStr,
        watchYear: _watchDate!.year,
        difficulty: _difficulty,
        maturity: _maturity,
        scores: _scores,
        metricLabels: metricLabels,
        review: _reviewController.text.trim(),
        photos: photoUrls,
        photoThumbs: thumbUrls,
      );

      final service = ref.read(reviewServiceProvider);
      if (_isEdit) {
        await service.update(widget.id!, review);
      } else {
        await service.create(review);
      }
      if (mounted) {
        _snack(_isEdit ? '리뷰가 수정되었습니다.' : '리뷰가 저장되었습니다.');
        context.go('/');
      }
    } on FirebaseException catch (e) {
      // plugin: cloud_firestore(권한) / firebase_storage(사진·Blaze) 구분
      if (e.plugin == 'firebase_storage') {
        _snack('사진 업로드 실패: Storage(Blaze) 설정 필요 — [${e.code}]');
      } else if (e.code == 'permission-denied') {
        _snack('권한 거부: 로그인 상태를 확인하세요 (Firestore 규칙) — [${e.code}]');
      } else {
        _snack('저장 실패 [${e.plugin}/${e.code}]: ${e.message}');
      }
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      body: SafeArea(
        child: !loggedIn
          ? _LoginPrompt()
          : _initializing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: MaxWidthBody(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 뒤로가기 + 제목: 콘텐츠 영역 좌측 상단에 배치
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/'),
                              icon: const Icon(Icons.arrow_back),
                              tooltip: '뒤로',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: context.subtleText,
                            ),
                            const SizedBox(width: 12),
                            Text(_isEdit ? '리뷰 수정' : '리뷰 작성',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _section('영화 검색', MovieSearchField(onSelected: _onMovieSelected)),
                        if (_title.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _selectedMovieCard(),
                        ],
                        const SizedBox(height: 12),
                        _section('영화관', _theaterField()),
                        const SizedBox(height: 12),
                        _section('특별관', _specialFormatChips()),
                        const SizedBox(height: 12),
                        _section('시청 정보', _infoBox()),
                        const SizedBox(height: 12),
                        _section('평가', _scoreSliders()),
                        const SizedBox(height: 12),
                        _section('후기', _reviewField()),
                        const SizedBox(height: 12),
                        _section('사진 (최대 2장)', _photoPicker()),
                        const SizedBox(height: 24),
                        _saveBar(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _selectedMovieCard() {
    final poster = posterUrl(_posterPath, size: 'w200');
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 50,
              height: 75,
              child: poster == null
                  ? Container(color: Colors.grey.shade200, child: const Icon(Icons.movie))
                  : Image.network(poster, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  [
                    if (_releaseYear != null) '$_releaseYear',
                    if (_runtime != null) '$_runtime분',
                    _country,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final g in _genres)
                      Chip(
                        label: Text(g, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                // 국내/해외는 TMDB 제작국가로 자동 판정 (위 메타 줄에 표시). 별도 입력 UI 없음.
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _theaterField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _theaterController,
          decoration: InputDecoration(
            hintText: '영화관/OTT 입력',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in kTheaterPresets)
              ActionChip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _theaterController.text = t),
              ),
          ],
        ),
      ],
    );
  }

  Widget _specialFormatChips() {
    // 프리셋에 없는 값이 저장돼 있으면 '기타'로 직접 입력한 것으로 본다.
    final presets = kSpecialFormats.where((f) => f != kSpecialFormatEtc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in presets)
              FilterChip(
                label: Text(f),
                selected: _specialFormats.contains(f),
                selectedColor: kPrimaryColor.withValues(alpha: 0.2),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    _specialFormats = [..._specialFormats, f];
                  } else {
                    _specialFormats =
                        _specialFormats.where((e) => e != f).toList();
                  }
                }),
              ),
            FilterChip(
              label: const Text(kSpecialFormatEtc),
              selected: _etcSelected,
              selectedColor: kPrimaryColor.withValues(alpha: 0.2),
              onSelected: (sel) => setState(() {
                _etcSelected = sel;
                if (!sel) _etcController.clear();
              }),
            ),
          ],
        ),
        if (_etcSelected) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _etcController,
            decoration: InputDecoration(
              hintText: '특별관 이름 직접 입력',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 시청 날짜
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _watchDate ?? now,
              firstDate: DateTime(1950),
              lastDate: DateTime(now.year + 1),
            );
            if (picked != null) setState(() => _watchDate = picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: '시청 날짜 *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _watchDate == null ? '날짜 선택' : DateFormat('yyyy-MM-dd').format(_watchDate!),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('러닝타임', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_runtime != null ? '$_runtime분' : '-',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 24),
        ScoreSlider(
          label: '난이도',
          description: '내용을 이해하기 얼마나 어려운지',
          value: _difficulty,
          onChanged: (v) => setState(() => _difficulty = v),
        ),
        ScoreSlider(
          label: '수위',
          description: '폭력성·선정성 등 수위 정도',
          value: _maturity,
          onChanged: (v) => setState(() => _maturity = v),
        ),
      ],
    );
  }

  Widget _scoreSliders() {
    final metrics = ref.watch(scoreMetricsProvider);
    return Column(
      children: [
        for (final m in metrics)
          ScoreSlider(
            label: m.label,
            description: m.description,
            value: _scores[m.key] ?? 5,
            onChanged: (v) => setState(() => _scores = {..._scores, m.key: v}),
          ),
      ],
    );
  }

  Widget _reviewField() {
    return TextField(
      controller: _reviewController,
      maxLines: 6,
      decoration: InputDecoration(
        hintText: '영화 감상 후기를 자유롭게 작성하세요',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _photoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _photos.length; i++) ...[
              _photoThumb(_photos[i], i),
              const SizedBox(width: 8),
            ],
            if (_photos.length < 2)
              InkWell(
                onTap: _pickPhoto,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.grey),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _photoThumb(_PhotoItem p, int index) {
    Widget img;
    if (p.url != null) {
      img = Image.network(p.url!, fit: BoxFit.cover, width: 90, height: 90);
    } else {
      img = FutureBuilder<Uint8List>(
        future: p.file!.readAsBytes(),
        builder: (c, snap) => snap.hasData
            ? Image.memory(snap.data!, fit: BoxFit.cover, width: 90, height: 90)
            : Container(width: 90, height: 90, color: Colors.grey.shade200),
      );
    }
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: () => setState(() => _photos = [..._photos]..removeAt(index)),
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => context.canPop() ? context.pop() : context.go('/'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('취소'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? '리뷰 저장' : '리뷰 작성'),
          ),
        ),
      ],
    );
  }
}

class _LoginPrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('로그인이 필요합니다',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('리뷰 작성을 위해 로그인해주세요', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          const KakaoLoginButton(),
        ],
      ),
    );
  }
}
