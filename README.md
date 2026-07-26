# 애프터 크레딧 (After Credits)

개인 영화 감상 기록·랭킹 앱. Flutter 단일 코드베이스로 iOS / Android / Web(PC)을 모두 지원하며,
모바일 앱을 메인으로, PC 웹은 보조 접근 수단으로 설계되었다.

- 서비스: https://aftercredits.web.app
- 로그인: 카카오 계정만 지원 (개인용 앱이라 다른 사람의 기록은 볼 수 없음)

## 주요 기능

- **영화 자동 완성**: TMDB API로 제목 검색 시 포스터·러닝타임·장르·제작 국가·개봉년도 자동 입력
- **관람 정보**: 영화관(CGV/메가박스/롯데/OTT 등) + 특별관(IMAX/4DX/ScreenX 등, 다중 선택)
- **평가**: 5개 지표(순수재미/스토리/연기·연출/시청각 효과/작품성) 슬라이더 + 난이도·수위
- **레이더 차트**: 해당 영화 점수 vs 내 전체 평균, 2점 간격 눈금
- **평가 기준 커스터마이징**: 프로필에서 5개 지표의 이름·설명을 자유롭게 수정 가능
  - 리뷰를 저장하는 시점의 기준이 리뷰에 함께 스냅샷으로 저장되므로, 이후 기준을 바꿔도
    이미 등록된 리뷰의 차트는 바뀌지 않는다 (새로 등록/수정하는 리뷰부터 새 기준 적용)
- **필터**: 감상 연도 / 국내·해외 / 장르
- **사진 첨부**: 리뷰당 최대 2장
- **개인화**: 닉네임·프로필 사진, 라이트/다크/시스템 테마, 사진 미리보기·추천작 표시 여부 설정
- **프라이버시**: Firestore/Storage 보안 규칙으로 본인 데이터만 읽기/쓰기 가능하도록 강제
- **반응형 UI**: 같은 화면이 모바일/태블릿/PC 폭에 맞춰 레이아웃을 조정 (앱 우선, 웹 보조)

## 기술 스택

| 영역 | 사용 기술 |
|---|---|
| 프레임워크 | Flutter (Dart), Riverpod (`flutter_riverpod`) |
| 라우팅 | `go_router` |
| 차트 | `fl_chart` (레이더 차트) |
| 백엔드 | Firebase Auth(커스텀 토큰), Cloud Firestore, Firebase Storage, Cloud Functions(Node 22), Hosting |
| 로그인 | 카카오 로그인 단일 (`kakao_flutter_sdk_user` — 모바일 네이티브 SDK / 웹은 OAuth 리다이렉트 + Cloud Functions 토큰 교환) |
| 외부 API | TMDB (The Movie Database) |
| 이미지 | `image_picker`, `cached_network_image` |

## 프로젝트 구조

```
lib/
  app.dart                # 앱 진입 위젯, 테마·라우터 연결
  main.dart                # Firebase 초기화 등 부트스트랩
  models/                  # MovieReview, UserProfile 등 도메인 모델
  screens/                 # 랭킹(메인)/상세/작성·수정/프로필/설정 화면
  services/                # Firestore/Storage/Auth/TMDB 연동 서비스
  state/providers.dart     # Riverpod 프로바이더 (인증 상태, 리뷰 목록/필터, 프로필 등)
  widgets/                 # 리뷰 카드, 레이더 차트, 필터바 등 재사용 위젯
  utils/                   # 상수, 테마, 웹 전용 conditional import 유틸

functions/                 # Cloud Functions (카카오 인가코드 → Firebase 커스텀 토큰 교환)
firestore.rules            # Firestore 보안 규칙 (본인 데이터만 접근)
storage.rules              # Storage 보안 규칙 (본인 파일만 접근)
firebase.json               # Hosting/Firestore/Storage/Functions 배포 설정
```

## 로컬 개발 환경 설정

### 1. 사전 준비물

- Flutter SDK (`environment.sdk`는 `pubspec.yaml` 참고)
- Firebase 프로젝트 (Blaze 요금제 — Storage/Cloud Functions 사용 때문에 필요)
- [TMDB API 키](https://www.themoviedb.org/settings/api)
- [카카오 개발자 앱](https://developers.kakao.com) (JS 키 / REST API 키 / 네이티브 앱 키, 필요 시 클라이언트 시크릿)

### 2. Firebase 연결

이 저장소에는 API 키가 포함된 Firebase 생성 파일(`lib/firebase_options.dart`,
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`)이 **제외**되어 있다.
본인 Firebase 프로젝트로 아래 명령을 실행해 생성해야 한다.

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

`.firebaserc`의 `projects.default`도 본인 프로젝트 ID로 바꿔야 한다.

### 3. 환경 변수

`.env.example` → `.env` 로 복사 후 값 채우기 (앱에서 asset으로 번들됨):

```bash
cp .env.example .env
```

Cloud Functions 쪽 서버 전용 값도 동일하게 준비:

```bash
cp functions/.env.example functions/.env
```

### 4. 카카오 로그인 설정

카카오 개발자 콘솔에서:

- **플랫폼 > Web** 도메인에 배포할 Firebase Hosting 도메인 등록 (예: `https://your-site.web.app`)
- **카카오 로그인 > Redirect URI** 에도 동일 도메인 등록 (웹은 인가 코드 방식 OAuth 리다이렉트를 사용)
- **카카오 로그인 > 보안 > 클라이언트 시크릿**을 활성화했다면 `functions/.env`의
  `KAKAO_CLIENT_SECRET`도 반드시 채워야 토큰 교환이 성공한다.

### 5. 실행

```bash
flutter pub get
flutter run                       # 모바일/에뮬레이터
flutter run -d chrome              # 웹
```

### 6. 배포

```bash
# Firestore/Storage 규칙 + Cloud Functions
firebase deploy --only firestore:rules,storage:rules,functions

# 웹 (아이콘 트리쉐이킹 끄지 않으면 Material 아이콘이 일부 누락됨)
flutter build web --release --no-tree-shake-icons
firebase deploy --only hosting
```

## 보안/개인정보 참고

- 모든 리뷰 문서는 `ownerUid`로 소유자를 구분하며, Firestore/Storage 규칙에서
  `request.auth.uid == ownerUid`가 아니면 읽기/쓰기를 모두 거부한다.
- 카카오 로그인의 클라이언트 시크릿, TMDB 토큰 등은 `.env` / `functions/.env`에만 두고
  저장소에는 커밋하지 않는다 (`.gitignore` 참고). 저장소를 포크/클론해 쓰려면 본인 값으로
  새로 발급받아야 한다.
