/**
 * 카카오 로그인 연동용 Cloud Function.
 *
 * 클라이언트가 카카오 SDK로 로그인해 받은 access token을 보내면,
 * 서버가 카카오 API로 토큰을 검증한 뒤 Firebase 커스텀 토큰을 발급한다.
 * (Firebase Auth는 카카오를 기본 제공자로 지원하지 않으므로 이 단계가 필요)
 */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({region: "asia-northeast3", maxInstances: 10});

/**
 * 인가 코드(authCode)를 카카오 액세스 토큰으로 교환한다.
 * 웹은 SDK가 토큰 교환을 지원하지 않아 서버에서 처리해야 한다.
 */
async function exchangeCodeForToken(authCode, redirectUri) {
  const restApiKey = process.env.KAKAO_REST_API_KEY;
  if (!restApiKey) {
    throw new HttpsError(
        "failed-precondition",
        "서버에 KAKAO_REST_API_KEY가 설정되지 않았습니다.",
    );
  }
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: restApiKey,
    redirect_uri: redirectUri,
    code: authCode,
  });
  // 카카오 콘솔에서 '클라이언트 시크릿'을 사용함으로 설정한 경우 필수
  const clientSecret = process.env.KAKAO_CLIENT_SECRET;
  if (clientSecret) {
    body.set("client_secret", clientSecret);
  }
  const res = await fetch("https://kauth.kakao.com/oauth/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
    },
    body,
  });
  const json = await res.json();
  if (!res.ok || !json.access_token) {
    throw new HttpsError(
        "unauthenticated",
        `인가 코드 교환 실패: ${json.error_description || json.error || res.status}`,
    );
  }
  return json.access_token;
}

exports.kakaoCustomToken = onCall(async (request) => {
  const data = request.data || {};

  // 모바일: SDK가 발급한 accessToken을 그대로 전달
  // 웹: authorize()로 받은 authCode + redirectUri를 전달 → 서버가 토큰으로 교환
  let accessToken = data.accessToken;
  if (!accessToken) {
    if (!data.authCode || !data.redirectUri) {
      throw new HttpsError(
          "invalid-argument",
          "accessToken 또는 (authCode, redirectUri)가 필요합니다.",
      );
    }
    accessToken = await exchangeCodeForToken(data.authCode, data.redirectUri);
  }
  if (typeof accessToken !== "string") {
    throw new HttpsError("invalid-argument", "accessToken 형식이 올바르지 않습니다.");
  }

  // 1) 카카오 API로 액세스 토큰 검증 + 프로필 조회
  let profile;
  try {
    const res = await fetch("https://kapi.kakao.com/v2/user/me", {
      headers: {Authorization: `Bearer ${accessToken}`},
    });
    if (!res.ok) {
      throw new HttpsError("unauthenticated", `카카오 토큰 검증 실패 (${res.status})`);
    }
    profile = await res.json();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", `카카오 API 호출 실패: ${e.message}`);
  }

  if (!profile || !profile.id) {
    throw new HttpsError("unauthenticated", "카카오 프로필을 확인할 수 없습니다.");
  }

  // 2) Firebase 사용자 생성/갱신 (uid는 카카오 회원번호 기반으로 고정)
  const uid = `kakao:${profile.id}`;
  const account = profile.kakao_account || {};
  const kProfile = account.profile || {};
  const displayName = kProfile.nickname || `카카오사용자${profile.id}`;
  const photoURL = kProfile.profile_image_url || undefined;

  const userProps = {displayName};
  if (photoURL) userProps.photoURL = photoURL;

  try {
    await admin.auth().updateUser(uid, userProps);
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      await admin.auth().createUser({uid, ...userProps});
    } else {
      throw new HttpsError("internal", `사용자 생성 실패: ${e.message}`);
    }
  }

  // 3) 커스텀 토큰 발급 → 클라이언트가 signInWithCustomToken으로 로그인
  const token = await admin.auth().createCustomToken(uid, {provider: "kakao"});
  return {token};
});
