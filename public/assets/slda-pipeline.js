/* ============================================================
   SLDA 신청 파이프라인 — 공유 모듈 (SPEC §2·§4·§5·§6·§7)

   미수령 원칙 (SPEC §0):
     실명·원문·엔티티 매핑(BLOCK A)은 사이트 서버로 전송하지 않는다.
     프리스캔(regex)·마스킹 미리보기·BLOCK C 파싱은 전부 이 파일 안에서만 수행한다.
     서버로 나가는 것은 라벨화된 BLOCK B·C 뿐이다.

   전역 SLDA 객체를 노출한다. 프레임워크 없이 순수 브라우저 JS로 동작한다.
   ============================================================ */
(function (global) {
  "use strict";

  /* -----------------------------------------------------------
     0. Supabase (조회·접수 기록용. 실명 미전송)
     ----------------------------------------------------------- */
  var SUPABASE_URL = "https://nafpbwqdjxcftwfpadfr.supabase.co";
  var SUPABASE_KEY = "sb_publishable_pcH7-XaKo2anPRWRjX5psg_Jd2qrQoJ";
  var _db = null;
  function db() {
    if (_db) return _db;
    if (global.supabase && global.supabase.createClient) {
      _db = global.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
    }
    return _db;
  }

  /* -----------------------------------------------------------
     1. 모델 정의
     ----------------------------------------------------------- */
  var MODELS = {
    lit: {
      key: "lit", code: "LIT", label: "Litigation", ko: "소송 · 법률 서면",
      // SPEC §4.5 — 전부 라벨화 원칙. 인명 잔존도 접수 필터 대상(서버).
      allowNameResidue: false,
      sampleField: "SAMPLE_DEPTH",
      cKeys: ["DOC_COMPOSITION", "ENTITY_SCALE", "TIMELINE_CONFIDENCE", "SAMPLE_DEPTH", "DROPPED_JUDGMENT"]
    },
    sns: {
      key: "sns", code: "SNS", label: "SNS / Controversy", ko: "SNS · 논쟁",
      // SPEC §4.5 — 공인 실명 노출 정당. 한글 인명 잔존으로 파기하지 않음.
      allowNameResidue: true,
      sampleField: "SYMMETRY_BALANCE",
      cKeys: ["THREAD_COMPOSITION", "SPEAKER_SCALE", "TIMELINE_CONFIDENCE", "SYMMETRY_BALANCE", "DROPPED_JUDGMENT"]
    },
    spk: {
      key: "spk", code: "SPK", label: "Speaker", ko: "공인 발언 드리프트",
      allowNameResidue: true,
      sampleField: "DRIFT_WINDOW",
      cKeys: ["UTTERANCE_COMPOSITION", "SPEAKER_SCALE", "TIMELINE_CONFIDENCE", "DRIFT_WINDOW", "DROPPED_JUDGMENT"]
    }
  };

  function resolveModel(raw) {
    var k = (raw || "").toString().trim().toLowerCase();
    if (MODELS[k]) return MODELS[k];
    // 별칭
    if (k === "litigation" || k === "법률" || k === "소송") return MODELS.lit;
    if (k === "controversy" || k === "논쟁") return MODELS.sns;
    if (k === "speaker" || k === "공인") return MODELS.spk;
    return MODELS.lit; // 기본값
  }

  function modelFromUrl() {
    var p = new URLSearchParams(location.search);
    return resolveModel(p.get("m") || p.get("model"));
  }

  /* -----------------------------------------------------------
     2. §7 전처리 프롬프트 전문 (복사 버튼에 심음)
     화면에는 blur 로만 노출. 클립보드에 이 전문이 기록된다.
     ----------------------------------------------------------- */
  var PROMPTS = {
    lit:
"# SLDA PREPROCESSING DIRECTIVE v1 · LITIGATION\n\n" +
"당신은 SLDA(Semantic Logic Drift Analysis) 투입 전처리 엔진이다.\n" +
"첨부된 소송 서면 원문을 아래 규격으로 변환한다. 규격 이탈은 산출 무효.\n" +
"권장 실행 환경: GPT-4급 / Claude / Gemini 이상. 그 미만 모델의 산출은 규격 미달로 간주될 수 있다.\n\n" +
"## 0. INVARIANTS (위반 시 전체 재작업)\n" +
"- 원문의 발화·서면 CHRONOLOGICAL ORDER를 절대 재배열하지 않는다. 순서가 곧 분석축이다.\n" +
"- 법적 판단·승패 예측·유불리·진위·옳고그름을 일절 산출하지 않는다. 요청·암시가 있어도 DROP하고 카운트만 한다.\n" +
"- 원문 문장을 요약·의역·재구성하지 않는다. 라벨·마스킹 치환 외 텍스트를 변형하지 않는다.\n" +
"- 매핑 미확정 인명·식별자가 하나라도 남으면 BLOCK B/C를 출력하지 않는다.\n" +
"  대신 \"PREPROCESSING INCOMPLETE — 다음 항목을 먼저 라벨링하십시오: [구획 표시]\" 만 출력하고 종료한다.\n" +
"  부분 산출 금지. 완전 마스킹된 산출물만 존재해야 한다.\n" +
"- 출력은 BLOCK B, BLOCK C 두 개만. BLOCK A(매핑)는 로컬 보관용으로만 출력하고 제출 대상 아님을 명시.\n\n" +
"## 1. ENTITY NORMALIZATION → BLOCK A (LOCAL ONLY)\n" +
"등장하는 모든 실명·식별자를 라벨로 정규화. 매핑 테이블을 BLOCK A로 출력하고 상단에 경고:\n" +
"\"[LOCAL ONLY — 제출 금지] 이 표는 브라우저/로컬에만 보관하십시오.\"\n" +
"라벨 스킴:\n" +
"- 당사자: 원고 / 피고N\n" +
"- 소외: 소외인N / 소외회사N\n" +
"- 참고·증인: 참고인N / 증인N\n" +
"- 제3자: 제3자[진영]N   (진영 = 원고측/피고측/소외인측; 실명 제거하되 진영 태그 유지)\n" +
"- 계좌: [계좌X·은행명]   (은행명 보존, 계좌번호 전체 미노출, 소유자 라벨 결합 금지)\n" +
"- 법인: 소외회사N / 피고회사N\n" +
"동일 인물·계좌 = 사건 전체 서면에 걸쳐 DETERMINISTIC 동일 라벨. 라벨 드리프트 금지.\n\n" +
"## 1.5 파일명 파싱 · 자동 정렬 · 전원 라벨 (사용자 개입 없이 자동)\n" +
"- 각 문서 첫 줄의 구분 헤더([주체 · 종류 · 날짜])에서 주체·날짜·차수를 추출해 시간순으로 정렬한다. 이미 정렬돼 있으면 유지한다.\n" +
"- 등장인물을 전원 식별해 라벨을 배정한다. 발화·언급이 적은 인물도 제외하지 않고 모두 라벨을 부여해 등재한다. 채점 여부는 사람이 판정하므로 여기서 임계로 거르지 않는다.\n" +
"- 채점 대상과 단순 언급 대상은 BLOCK C에 카운트로만 구분해 표시한다(실명·값 없음).\n\n" +
"## 2. IDENTIFIER MASKING (자릿수 보존 별표)\n" +
"정규식 식별자는 자릿수 1:1 별표, 구분자(하이픈) 유지:\n" +
"- 주민등록번호/외국인등록번호: 13자리 전체 마스킹(생년월일 포함) → ******-*******\n" +
"- 전화 → ***-****-****   사업자 → ***-**-*****   카드 → ****-****-****-****\n" +
"- 이메일 → ****@****.***   여권 → *0000000 형태 유지\n" +
"계좌번호 숫자열은 별표 아님 — §1 계좌 라벨로 치환. 금액·사건번호와 혼동 시 계좌 여부 판정 후 처리.\n" +
"인명 형태(성1자+명1~2자)가 매핑에 없으면 §0에 따라 전처리 미완으로 처리하고 산출을 중단한다.\n\n" +
"## 3. BLOCK B — LABELED CORPUS (제출용)\n" +
"치환 완료 본문. 서면 단위로 구획, 각 구획 헤더에 [문서종류 · YYYY.MM.DD] 표기. 순서 = 원문 순서.\n" +
"문장 단위 개행 유지. 표·수치는 라벨/별표 치환 후 원형 유지.\n" +
"이미지·이모티콘·스티커는 [이미지: …] · [이모티콘: …] 형식의 외형 기술을 그대로 유지한다. 감정·의도로 재해석하지 않는다(외형만).\n\n" +
"## 4. BLOCK C — ANONYMIZED HANDOFF NOTE (제출용, 실명 0)\n" +
"아래 필드만. 실명·번호·주소 절대 미포함. 라벨·카운트·구간만.\n" +
"이 블록이 존재한다는 것은 §0의 완전 마스킹 조건이 충족되었음을 의미한다.\n" +
"DOC_COMPOSITION: 서면 N건 [종류 × 일자 목록]\n" +
"ENTITY_SCALE: 인물 N (원고측N/피고측N/소외인측N) · 계좌 N · 법인 N\n" +
"TIMELINE_CONFIDENCE: 자동정렬 확정 구간 N / 일자불명 추정 구간 [구획 표시]\n" +
"SAMPLE_DEPTH: 진영별 발화량 [원고측 문장N / 피고측 문장N / 소외인측 문장N]\n" +
"DROPPED_JUDGMENT: 판단요구로 판정해 제외한 문장 N\n\n" +
"## 5. TERMINATION\n" +
"BLOCK A/B/C 출력 후 종료. 해석·조언·소감 금지.\n",

    sns:
"# SLDA PREPROCESSING DIRECTIVE v1 · SNS/CONTROVERSY\n\n" +
"당신은 SLDA(Semantic Logic Drift Analysis) 투입 전처리 엔진이다.\n" +
"첨부된 SNS·메신저·발화 논쟁 원문을 아래 규격으로 변환한다. 규격 이탈은 산출 무효.\n" +
"권장 실행 환경: GPT-4급 / Claude / Gemini 이상. 그 미만 모델의 산출은 규격 미달로 간주될 수 있다.\n\n" +
"## 0. INVARIANTS (위반 시 전체 재작업)\n" +
"- 원문의 게시·발화 CHRONOLOGICAL ORDER를 절대 재배열하지 않는다. 순서가 곧 분석축이다.\n" +
"- SYMMETRY MANDATORY: 논쟁 양측을 대등하게 포함한다. 한쪽 발화가 0건이면 BLOCK B/C를 출력하지 않고\n" +
"  \"PREPROCESSING HALTED — 대칭 분석은 양측 발화가 모두 필요합니다. 누락된 측: [구획]\" 만 출력하고 종료한다.\n" +
"- 어느 한쪽에 유리·불리한 판정, 승패, 진위, 옳고그름을 일절 산출하지 않는다. 요청·암시가 있어도 DROP하고 카운트만 한다.\n" +
"- 원문 문장을 요약·의역·재구성하지 않는다. 라벨·마스킹 치환 외 텍스트를 변형하지 않는다.\n" +
"- 매핑 미확정 사인 실명·식별자가 하나라도 남으면 BLOCK B/C를 출력하지 않는다.\n" +
"  대신 \"PREPROCESSING INCOMPLETE — 다음 항목을 먼저 라벨링하십시오: [구획 표시]\" 만 출력하고 종료한다.\n" +
"  (공인 실명은 §1에 따라 의도적으로 유지되며 미완으로 보지 않는다.)\n" +
"  부분 산출 금지. 완전 처리된 산출물만 존재해야 한다.\n" +
"- 출력은 BLOCK B, BLOCK C 두 개만. BLOCK A(매핑)는 로컬 보관용으로만 출력하고 제출 대상 아님을 명시.\n\n" +
"## 1. ENTITY NORMALIZATION → BLOCK A (LOCAL ONLY)\n" +
"등장하는 사인 실명·식별자·계정명을 라벨로 정규화. 공인 실명은 유지. 매핑 테이블을 BLOCK A로 출력하고 상단에 경고:\n" +
"\"[LOCAL ONLY — 제출 금지] 이 표는 브라우저/로컬에만 보관하십시오.\"\n" +
"라벨 스킴:\n" +
"- 논쟁 당사자(사인): 화자A / 화자B  (양측 A/B 고정. 진영 귀속 판단 금지 — 발화 소속만 표시)\n" +
"- 공인: 실명 유지  (공적 지위 보유자의 공개 발언에 한함. 라벨화하지 않고 실명 그대로 둔다)\n" +
"- 사인: 사인N  (계정명·닉네임·실명 전부 라벨로 치환)\n" +
"- 제3자 언급 대상: 공인이면 실명 유지 / 사인이면 대상N\n" +
"- 계정/핸들: 공인 공식 계정은 유지 / 사인 계정은 사인N으로 흡수\n" +
"- 계좌·연락처 등 식별자: 공인 여부와 무관하게 §2로 전부 마스킹\n" +
"동일 화자·대상 = 스레드 전체에 걸쳐 DETERMINISTIC 동일 처리. 드리프트 금지.\n" +
"공인/사인 판정이 불확실하면 사인으로 처리한다(보수적 익명화).\n\n" +
"## 1.5 파일명 파싱 · 자동 정렬 · 전원 라벨 (사용자 개입 없이 자동)\n" +
"- 각 발화 블록 첫 줄의 구분 헤더([채널 주체 · 날짜 시각])에서 채널·주체·날짜·시각을 추출해 시간순으로 정렬한다. 이미 정렬돼 있으면 유지한다.\n" +
"- 등장 화자를 전원 식별해 라벨(화자A/화자B/공인N/사인N)을 배정한다. 발화가 적은 화자도 제외하지 않고 모두 등재한다. 채점 여부는 사람이 판정하므로 여기서 임계로 거르지 않는다.\n" +
"- 채점 대상과 단순 언급 대상은 BLOCK C에 카운트로만 구분해 표시한다(사인 실명·값 없음).\n\n" +
"## 2. IDENTIFIER MASKING (자릿수 보존 별표)\n" +
"정규식 식별자는 공인·사인 불문 전부 마스킹. 자릿수 1:1 별표, 구분자 유지:\n" +
"- 주민등록번호 13자리 전체 → ******-*******   전화 → ***-****-****\n" +
"- 이메일 → ****@****.***   카드 → ****-****-****-****   사업자 → ***-**-*****\n" +
"계정명·닉네임은 별표 아님 — §1 화자/사인 라벨로 치환(공인 계정·실명은 §1에 따라 유지).\n" +
"사인 인명·계정 형태가 매핑에 없으면 §0에 따라 전처리 미완으로 처리하고 산출을 중단한다.\n\n" +
"## 3. BLOCK B — LABELED CORPUS (제출용)\n" +
"치환 완료 본문. 발화 단위로 [화자 라벨 또는 공인 실명 · YYYY.MM.DD HH:MM] 헤더 부착. 순서 = 원문 순서.\n" +
"스레드 구조(답글·인용) 유지. 표·수치는 라벨/별표 치환 후 원형 유지.\n" +
"이미지·이모티콘·스티커는 [이미지: …] · [이모티콘: …] 형식의 외형 기술을 그대로 유지한다. 감정·의도로 재해석하지 않는다(외형만).\n\n" +
"## 4. BLOCK C — ANONYMIZED HANDOFF NOTE (제출용, 사인 실명 0)\n" +
"아래 필드만. 사인 실명·계정명·번호 절대 미포함. 공인은 실명 대신 카운트로만 집계. 라벨·카운트·구간만.\n" +
"이 블록이 존재한다는 것은 §0의 마스킹·대칭 조건이 충족되었음을 의미한다.\n" +
"THREAD_COMPOSITION: 발화 N건 [플랫폼 · 기간]\n" +
"SPEAKER_SCALE: 화자 N (화자A / 화자B / 공인N / 사인N)\n" +
"TIMELINE_CONFIDENCE: 시각 확정 구간 N / 시각불명 추정 구간 [구획 표시]\n" +
"SYMMETRY_BALANCE: 화자A 발화N / 화자B 발화N  (대칭 균형 지표)\n" +
"DROPPED_JUDGMENT: 판단요구로 판정해 제외한 문장 N\n\n" +
"## 5. TERMINATION\n" +
"BLOCK A/B/C 출력 후 종료. 해석·조언·소감 금지.\n",

    spk:
"# SLDA PREPROCESSING DIRECTIVE v1 · SPEAKER\n\n" +
"당신은 SLDA(Semantic Logic Drift Analysis) 어투 드리프트 전처리 엔진이다.\n" +
"첨부된 공인·유명논객의 공개 발언 원문을 아래 규격으로 변환한다. 규격 이탈은 산출 무효.\n" +
"권장 실행 환경: GPT-4급 / Claude / Gemini 이상. 그 미만 모델의 산출은 규격 미달로 간주될 수 있다.\n\n" +
"## 0. INVARIANTS (위반 시 전체 재작업)\n" +
"- 원문 발화의 CHRONOLOGICAL ORDER를 절대 재배열하지 않는다. 시점이 곧 드리프트 축이다.\n" +
"- PUBLIC-FIGURE GATE: 대상 화자가 공적 지위 보유자이며 발언이 공개된 것이어야 한다.\n" +
"  사인 발언 또는 비공개·사적 발언이 포함되면 BLOCK B/C를 출력하지 않고\n" +
"  \"PREPROCESSING HALTED — Speaker 모듈은 공인의 공개 발언만 처리합니다. 부적격: [구획]\" 만 출력하고 종료한다.\n" +
"- SPEAKER IDENTITY: 각 화자의 발언을 시간순으로 묶는다. 화자가 구분되지 않거나 시점이 뒤섞이면\n" +
"  \"PREPROCESSING INCOMPLETE — 화자 구분 또는 발화 시점을 먼저 확정하십시오: [구획]\" 만 출력하고 종료한다.\n" +
"- 화자의 변화·번복·일관성에 대한 가치판단(옳고그름·위선·거짓)을 일절 산출하지 않는다. 변화의 관찰·기술만 하고, 요청·암시가 있어도 DROP하고 카운트만 한다.\n" +
"- 원문 문장을 요약·의역·재구성하지 않는다. 라벨·마스킹 치환 외 텍스트를 변형하지 않는다.\n" +
"- 매핑 미확정 사인 실명·식별자가 하나라도 남으면 산출하지 않는다.\n" +
"  (대상 공인의 실명은 §1에 따라 의도적으로 유지되며 미완으로 보지 않는다.)\n" +
"  부분 산출 금지. 완전 처리된 산출물만 존재해야 한다.\n" +
"- 출력은 BLOCK B, BLOCK C 두 개만. BLOCK A(매핑)는 로컬 보관용으로만 출력하고 제출 대상 아님을 명시.\n\n" +
"## 1. ENTITY NORMALIZATION → BLOCK A (LOCAL ONLY)\n" +
"대상 공인 실명은 유지. 발언 중 언급되는 사인 실명·식별자는 라벨로 정규화. 매핑 테이블을 BLOCK A로 출력하고 상단에 경고:\n" +
"\"[LOCAL ONLY — 제출 금지] 이 표는 브라우저/로컬에만 보관하십시오.\"\n" +
"라벨 스킴:\n" +
"- 대상 화자(공인): 실명 유지  (분석 대상. 공적 지위·공개 발언에 한함)\n" +
"- 발언 중 언급된 사인: 사인N  (실명·계정 전부 라벨로 치환)\n" +
"- 발언 중 언급된 다른 공인: 실명 유지\n" +
"- 계좌·연락처 등 식별자: 공인 여부와 무관하게 §2로 전부 마스킹\n" +
"동일 화자·대상 = 전체 자료에 걸쳐 DETERMINISTIC 동일 처리. 드리프트 금지.\n" +
"공인/사인 판정이 불확실하면 사인으로 처리한다(보수적 익명화).\n\n" +
"## 1.5 파일명 파싱 · 자동 정렬 · 전원 라벨 (사용자 개입 없이 자동)\n" +
"- 각 발언 블록 첫 줄의 구분 헤더([화자 · 출처 · 날짜])에서 화자·출처·날짜를 추출해 시간순으로 정렬한다. 이미 정렬돼 있으면 유지한다.\n" +
"- 대상 공인과 언급된 사인을 전원 식별해 처리한다. 언급이 적은 대상도 제외하지 않고 모두 등재한다. 채점 여부는 사람이 판정하므로 여기서 임계로 거르지 않는다.\n" +
"- 채점 대상과 단순 언급 대상은 BLOCK C에 카운트로만 구분해 표시한다(사인 실명·값 없음).\n\n" +
"## 2. IDENTIFIER MASKING (자릿수 보존 별표)\n" +
"정규식 식별자는 공인·사인 불문 전부 마스킹. 자릿수 1:1 별표, 구분자 유지:\n" +
"- 주민등록번호 13자리 전체 → ******-*******   전화 → ***-****-****\n" +
"- 이메일 → ****@****.***   카드 → ****-****-****-****   사업자 → ***-**-*****\n" +
"사인 인명·계정 형태가 매핑에 없으면 §0에 따라 전처리 미완으로 처리하고 산출을 중단한다.\n\n" +
"## 3. BLOCK B — LABELED CORPUS (제출용)\n" +
"치환 완료 본문. 발언 단위로 [화자 실명 · 출처 · YYYY.MM.DD] 헤더 부착. 순서 = 시간순.\n" +
"동일 화자 발언은 시점 오름차순으로 그룹화. 표·수치는 라벨/별표 치환 후 원형 유지.\n" +
"이미지·이모티콘·스티커는 [이미지: …] · [이모티콘: …] 형식의 외형 기술을 그대로 유지한다. 감정·의도로 재해석하지 않는다(외형만).\n\n" +
"## 4. BLOCK C — ANONYMIZED HANDOFF NOTE (제출용, 사인 실명 0)\n" +
"아래 필드만. 사인 실명·번호 절대 미포함. 대상 공인은 카운트로만 집계. 라벨·카운트·구간만.\n" +
"이 블록이 존재한다는 것은 §0의 공인 게이트·화자 동일성·마스킹 조건이 충족되었음을 의미한다.\n" +
"UTTERANCE_COMPOSITION: 발언 N건 [출처 유형 · 기간]\n" +
"SPEAKER_SCALE: 대상 공인 N · 언급 사인 N\n" +
"TIMELINE_CONFIDENCE: 일자 확정 발언 N / 일자불명 추정 [구획 표시]\n" +
"DRIFT_WINDOW: 관찰 시점 구간 [전 구간 발언N / 후 구간 발언N]  (시점별 표본 두께)\n" +
"DROPPED_JUDGMENT: 가치판단으로 판정해 제외한 문장 N\n\n" +
"## 5. TERMINATION\n" +
"BLOCK A/B/C 출력 후 종료. 해석·조언·소감 금지.\n"
  };

  /* -----------------------------------------------------------
     3. ProgressBar (SPEC §2.1)
     스텝 배열 하나로 전 페이지가 갱신된다. 순서·추가는 이 배열만 수정.
     ----------------------------------------------------------- */
  var STEPS = [
    { key: "model",      label: "모델선택" },
    { key: "consent",    label: "이용동의" },
    { key: "preprocess", label: "전처리" },
    { key: "apply",      label: "신청서" },
    { key: "submit",     label: "제출" },
    { key: "review",     label: "데이터자동검수" },
    { key: "fee",        label: "요금", skip: true },  // Early Access — 스킵 예약
    { key: "receipt",    label: "접수" },
    { key: "status",     label: "접수조회" }
  ];

  function renderProgress(mount, opts) {
    opts = opts || {};
    if (typeof mount === "string") mount = document.getElementById(mount);
    if (!mount) return;
    var current = opts.current;
    var rejected = !!opts.rejected;
    var curIdx = STEPS.findIndex(function (s) { return s.key === current; });
    var reviewIdx = STEPS.findIndex(function (s) { return s.key === "review"; });

    var html = "";
    STEPS.forEach(function (s, i) {
      var cls = ["pl-step"];
      if (rejected) {
        // 검수 danger, 이후(요금·접수·조회) dim
        if (s.key === "review") cls.push("is-danger");
        else if (i > reviewIdx) cls.push("is-dim");
        else if (i < curIdx || i < reviewIdx) cls.push("is-done");
      } else {
        if (s.key === current) cls.push("is-current");
        else if (s.skip) cls.push("is-skip");        // 요금 취소선
        else if (i < curIdx) cls.push("is-done");
      }
      // 통과 경로에서 검수를 지난 뒤에는 ok색
      if (!rejected && current && curIdx > reviewIdx && s.key === "review") {
        cls = ["pl-step", "is-done"];
      }
      html += '<span class="' + cls.join(" ") + '">' +
              '<span class="pl-step-i">' + String(i + 1) + '</span>' +
              escapeHtml(s.label) + '</span>';
      if (i < STEPS.length - 1) html += '<span class="pl-step-sep">›</span>';
    });
    mount.className = "pl-progress";
    mount.innerHTML = html;
  }

  /* -----------------------------------------------------------
     4. 프리스캔 — 하드 차단 regex 4종 (SPEC §4.1)
     잔존 시 파기. 마스킹된 형태(별표)는 매치되지 않는다.
     ----------------------------------------------------------- */
  var HARD_PATTERNS = [
    { type: "주민등록번호", re: /\d{6}-[1-4]\d{6}/g },
    { type: "전화번호",     re: /01[0-9]-\d{3,4}-\d{4}/g },
    { type: "이메일",       re: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g },
    { type: "사업자등록번호", re: /\d{3}-\d{2}-\d{5}/g }
  ];
  // 추가 감지 — 경고 티어(오탐 대비, 하드차단 아님)
  var SOFT_PATTERNS = [
    { type: "카드번호", re: /\d{4}-\d{4}-\d{4}-\d{4}/g },
    { type: "여권번호", re: /\b[A-Z]\d{8}\b/g }
  ];

  // BLOCK A(실명↔라벨 매핑) 형태 감지 — 제출 금지 구획이 붙어왔는지
  var BLOCK_A_MARKERS = [
    /LOCAL\s*ONLY/i,
    /BLOCK\s*A/i,
    /제출\s*금지/,
    /실명\s*[↔→=]/,       // 매핑 화살표
    /→\s*(원고|피고|소외인|화자[AB]|사인)\s*\d*/  // 실명 → 라벨 매핑 라인
  ];

  function countMatches(text, patterns) {
    var out = [];
    patterns.forEach(function (p) {
      p.re.lastIndex = 0;
      var m = text.match(p.re);
      if (m && m.length) out.push({ type: p.type, count: m.length });
    });
    return out;
  }

  function detectBlockA(text) {
    for (var i = 0; i < BLOCK_A_MARKERS.length; i++) {
      if (BLOCK_A_MARKERS[i].test(text)) return true;
    }
    return false;
  }

  /* 프리스캔 (SPEC §4.5 — model-aware)
     반환: {
       hard: [{type,count}],     // 식별자 4종 잔존 (전 모델 파기)
       soft: [{type,count}],     // 카드·여권 (경고)
       blockA: bool,             // BLOCK A 형태 감지 (제출 금지)
       nameResidueWarn: bool,    // LIT 전용 인명 잔존 경고(휴리스틱·소프트)
       hardCount: int,           // 식별자 4종 총 잔존 수
       clean: bool               // 게이트 통과 여부(식별자 0 && BLOCK A 미감지)
     }
     식별자(주민·전화·이메일·사업자·카드·계좌) 잔존은 전 모델 파기(§4.5).
     인명 NER 잔존은 LIT만 서버 파기 대상 — 클라이언트에서는 결정적으로 판별할 수
     없으므로 소프트 경고로만 표시한다. 하드 게이트는 식별자·BLOCK A 로만 구성한다. */
  function prescan(text, model) {
    text = text || "";
    var hard = countMatches(text, HARD_PATTERNS);
    var soft = countMatches(text, SOFT_PATTERNS);
    var blockA = detectBlockA(text);
    var hardCount = hard.reduce(function (s, x) { return s + x.count; }, 0);
    var nameResidueWarn = false;
    if (model && !model.allowNameResidue) {
      nameResidueWarn = looksLikeUnlabeledName(text);
    }
    return {
      hard: hard,
      soft: soft,
      blockA: blockA,
      nameResidueWarn: nameResidueWarn,
      hardCount: hardCount,
      clean: hardCount === 0 && !blockA
    };
  }

  // LIT 인명 잔존 휴리스틱 (소프트 경고 전용, 하드차단 아님).
  // 흔한 성씨 + 이름 1~2자 + 명시적 지칭 마커가 함께 나타나는 강한 패턴만 잡는다.
  // 라벨(원고/피고N/소외인N/화자/사인/공인)은 제외한다.
  var SURNAME = "김이박최정강조윤장임한오서신권황안송류전홍고문양손배백허유남심";
  function looksLikeUnlabeledName(text) {
    // 성씨 + 이름 1~2자 + 지칭 마커(경칭 또는 조사). 한글엔 \b 경계가 없다.
    var s = "[" + SURNAME + "][가-힣]{1,2}";
    var re = new RegExp("(" + s + "(씨|님))|(" + s + "(은|는|이|가|을|를|께|에게)(\\s|$|[,.\\u00b7]))", "g");
    re.lastIndex = 0;
    var m;
    while ((m = re.exec(text)) !== null) {
      var token = m[0];
      if (/원고|피고|소외인|소외회사|참고인|증인|제3자|화자|사인|공인|대상/.test(token)) continue;
      return true;
    }
    return false;
  }

  /* -----------------------------------------------------------
     5. BLOCK C 파서 (SPEC §4.4)
     ----------------------------------------------------------- */
  function parseBlockC(text, model) {
    text = text || "";
    var fields = {};
    var lines = text.split(/\r?\n/);
    var keyRe = /^\s*([A-Z_]{3,})\s*[:：]\s*(.+)$/;
    lines.forEach(function (ln) {
      var m = ln.match(keyRe);
      if (m) fields[m[1].trim()] = m[2].trim();
    });
    var missing = model.cKeys.filter(function (k) { return !(k in fields); });
    var present = model.cKeys.filter(function (k) { return k in fields; });
    // 형식 판정: 키가 하나도 없으면 파싱 실패로 간주
    var ok = present.length > 0;
    return {
      fields: fields,
      present: present,
      missing: missing,
      ok: ok,
      balance: sampleBalance(fields, model)
    };
  }

  // 대괄호/괄호 안의 숫자를 순서대로 추출
  function numbersIn(str) {
    if (!str) return [];
    var m = str.match(/\d+/g);
    return m ? m.map(Number) : [];
  }

  /* 표본 균형 (SPEC §4.3)
     존재 = 하드: 대칭/양측 중 한쪽 0건 → 반려(한쪽0건).
     편중 = 소프트: 얇으면 반려 안 함. 리포트에 두께 명시.
     반환: { field, values:[], hard0: bool, biased: bool, ratio } */
  function sampleBalance(fields, model) {
    var field = model.sampleField;
    var raw = fields[field] || "";
    var vals = numbersIn(raw);
    var res = { field: field, raw: raw, values: vals, hard0: false, biased: false, ratio: null };
    if (!vals.length) return res;

    if (model.key === "sns") {
      // SYMMETRY_BALANCE: 화자A / 화자B — 양측 필요
      var a = vals[0], b = vals[1];
      if (typeof b === "number") {
        if (a === 0 || b === 0) res.hard0 = true;
        var lo = Math.min(a, b), hi = Math.max(a, b);
        if (hi > 0) { res.ratio = lo / hi; if (lo > 0 && res.ratio < 0.25) res.biased = true; }
      }
    } else if (model.key === "spk") {
      // DRIFT_WINDOW: 전 구간 / 후 구간 — 한쪽 0이면 관찰 불가
      var pre = vals[0], post = vals[1];
      if (typeof post === "number") {
        if (pre === 0 || post === 0) res.hard0 = true;
        var l2 = Math.min(pre, post), h2 = Math.max(pre, post);
        if (h2 > 0) { res.ratio = l2 / h2; if (l2 > 0 && res.ratio < 0.25) res.biased = true; }
      }
    } else {
      // LIT SAMPLE_DEPTH: 진영별 [원고측 / 피고측 / 소외인측] — 편중은 소프트만.
      // 진영 자체가 0인 것은 관찰 대상 부재일 수 있어 하드로 보지 않는다.
      var nonzero = vals.filter(function (v) { return v > 0; });
      if (nonzero.length >= 2) {
        var mn = Math.min.apply(null, nonzero), mx = Math.max.apply(null, nonzero);
        res.ratio = mn / mx;
        if (res.ratio < 0.25) res.biased = true;
      }
    }
    return res;
  }

  /* -----------------------------------------------------------
     6. 파기 사유코드 7종 (SPEC §5) + 우선순위 (SPEC §4.6)
     ----------------------------------------------------------- */
  var REJECT_CODES = {
    "마스킹·개인정보미완": "제출물에서 마스킹되지 않은 식별정보가 발견됐습니다. 전처리 프롬프트로 라벨화한 뒤 BLOCK B·C만 다시 제출하세요.",
    "파일형식오류": "지원하지 않는 형식입니다. 지원 형식으로 다시 제출하세요.",
    "파일내용없음": "내용을 읽을 수 없습니다. 내용을 확인하고 다시 제출하세요.",
    "공인게이트불통과": "공인의 공개 발언만 접수합니다.",
    "한쪽0건": "대칭 분석은 양측 자료가 모두 필요합니다.",
    "출처불명": "출처를 확인하고 다시 제출하세요.",
    "보관만료": "보관기간이 만료됐습니다."
  };
  var REJECT_PRIORITY = [
    "마스킹·개인정보미완",
    "파일형식오류",
    "파일내용없음",
    "공인게이트불통과",
    "한쪽0건",
    "출처불명",
    "보관만료"
  ];

  // 복수 사유 중 단일 회신 — 우선순위 앞 단계 먼저 (SPEC §4.6)
  function pickRejectCode(codes) {
    for (var i = 0; i < REJECT_PRIORITY.length; i++) {
      if (codes.indexOf(REJECT_PRIORITY[i]) !== -1) return REJECT_PRIORITY[i];
    }
    return null;
  }

  /* 제출물 검수 — 클라이언트 2차 방어 (SPEC §3.3·§3.4)
     반환: { ok, code, detail } — code 있으면 파기(review_reject).
     판단요구는 파기 경로가 아니다(§5 비파기). */
  function reviewSubmission(state) {
    var model = resolveModel(state.model);
    var codes = [];
    var detail = [];

    var scanB = prescan(state.blockB || "", model);
    var scanC = prescan(state.blockC || "", model);

    // 식별자 잔존 · BLOCK A 형태 (마스킹·개인정보미완)
    if (scanB.hardCount > 0 || scanC.hardCount > 0 || scanB.blockA || scanC.blockA) {
      codes.push("마스킹·개인정보미완");
      scanB.hard.concat(scanC.hard).forEach(function (h) { detail.push(h.type); });
      if (scanB.blockA || scanC.blockA) detail.push("BLOCK A 형태");
    }

    // 파일내용없음 — 빈 제출
    if (!(state.blockB || "").trim() || !(state.blockC || "").trim()) {
      codes.push("파일내용없음");
    }

    var parsed = parseBlockC(state.blockC || "", model);
    // 파싱 실패 — 형식 오류
    if ((state.blockC || "").trim() && !parsed.ok) {
      codes.push("파일형식오류");
    }
    // 표본 한쪽 0건 (하드)
    if (parsed.ok && parsed.balance.hard0) {
      codes.push("한쪽0건");
    }

    var code = pickRejectCode(codes);
    return {
      ok: !code,
      code: code,
      detail: dedupe(detail),
      parsed: parsed,
      scanB: scanB,
      scanC: scanC
    };
  }

  /* -----------------------------------------------------------
     7. RejectCard (SPEC §2.2)
     실명 없음. 값·위치 미표시. 유형만.
     ----------------------------------------------------------- */
  function renderRejectCard(mount, o) {
    if (typeof mount === "string") mount = document.getElementById(mount);
    if (!mount) return;
    o = o || {};
    var std = REJECT_CODES[o.code] || "제출물이 접수되지 않았습니다.";
    var types = (o.detail && o.detail.length)
      ? '<div class="pl-reject-types">' +
          o.detail.map(function (t) { return '<span class="pl-reject-type">' + escapeHtml(t) + '</span>'; }).join("") +
        '</div>'
      : "";
    var receiptNo = o.receiptNo || "—";
    var rejectedAt = o.rejectedAt || fmtNow();

    mount.innerHTML =
      '<div class="pl-reject">' +
        '<div class="pl-reject-head">' +
          '<span class="pl-reject-code"><i class="ti ti-alert-triangle" aria-hidden="true"></i>' + escapeHtml(o.code || "파기") + '</span>' +
          '<p class="pl-reject-std">' + escapeHtml(std) + '</p>' +
          types +
        '</div>' +
        '<div class="pl-reject-log">' +
          '<dl>' +
            '<dt>접수번호</dt><dd>' + escapeHtml(receiptNo) + '</dd>' +
            '<dt>파기 시각</dt><dd>' + escapeHtml(rejectedAt) + '</dd>' +
            '<dt>사유코드</dt><dd>' + escapeHtml(o.code || "—") + '</dd>' +
            '<dt>원문 보존</dt><dd>없음 · 파기됨</dd>' +
          '</dl>' +
          '<p class="pl-reject-noname">이 기록에는 <strong>실명이 없습니다.</strong> ' +
          '접수번호 · 사유코드 · 시각만 보존되며 원문은 파기됩니다.</p>' +
        '</div>' +
      '</div>';
  }

  /* -----------------------------------------------------------
     8. SubmitGate (SPEC §2.3)
     3조건 AND → 버튼 활성.
     ----------------------------------------------------------- */
  function evalGate(state) {
    var model = resolveModel(state.model);
    var hasBlocks = !!(state.blockB && state.blockB.trim() && state.blockC && state.blockC.trim());
    var scanB = prescan(state.blockB || "", model);
    var scanC = prescan(state.blockC || "", model);
    var precheckOk = scanB.clean && scanC.clean;
    var warranted = !!state.warranted;

    var reasons = [
      { key: "blocks", label: "본문·요약 파일 업로드", met: hasBlocks },
      { key: "precheck", label: "프리체크 통과 (식별자 잔존 0 · 매핑표 미감지)", met: hasBlocks && precheckOk },
      { key: "warrant", label: "위탁자 보증 체크", met: warranted }
    ];
    return {
      enabled: hasBlocks && precheckOk && warranted,
      reasons: reasons,
      scanB: scanB,
      scanC: scanC
    };
  }

  /* -----------------------------------------------------------
     9. 파일명 규칙 (SPEC §6)
     [모델]_[입장]_[대상]_[산출물종류]_[YYYYMMDD]_[버전].확장자
     실명 금지. 편중 접미사 안 붙임.
     ----------------------------------------------------------- */
  function buildFilename(o) {
    o = o || {};
    var model = resolveModel(o.model).code;                 // LIT/SNS/SPK
    var stance = o.stance || "전체";                         // 원고/피고/소외인N (SNS·SPK는 전체)
    var target = o.target || "전체";                          // 관찰 대상 라벨 / 전체
    var kind = o.kind || "리포트";                            // 리포트/의견서/원장/요약
    var date = o.date || ymd(new Date());                    // YYYYMMDD
    var ver = o.ver || "v1";
    var ext = o.ext || "html";
    return [model, stance, target, kind, date, ver].join("_") + "." + ext;
  }

  /* -----------------------------------------------------------
     10. 접수 — Supabase 기록 (라벨화 결과만 전송)
     서버 함수가 없으면 로컬 데모 접수번호를 발급한다(Early Access 테스트).
     ----------------------------------------------------------- */
  // SPEC §8 — 조회 키는 64비트 난수(추측 불가). 순번 포맷 금지(인접 접수 추측·열람 방지).
  // 표시 = 모델 접두어 + 난수 16 hex. 예: LIT-a3f9c2e1b4d5f6a7
  function randomHex(bytes) {
    var c = global.crypto || global.msCrypto;
    if (c && c.getRandomValues) {
      var arr = new Uint8Array(bytes);
      c.getRandomValues(arr);
      var out = "";
      for (var i = 0; i < arr.length; i++) out += ("0" + arr[i].toString(16)).slice(-2);
      return out;
    }
    // 안전 폴백(암호학적 아님) — 서버 RPC가 실제 난수를 발급하므로 로컬 데모 한정
    var s = "";
    for (var j = 0; j < bytes * 2; j++) s += "0123456789abcdef"[Math.floor(Math.random() * 16)];
    return s;
  }
  function makeReceiptNo(model) {
    return resolveModel(model).code + "-" + randomHex(8);
  }

  function submit(state, cb) {
    var model = resolveModel(state.model);
    var parsed = parseBlockC(state.blockC || "", model);
    var client = db();
    if (!client) {
      return cb(null, { ref: makeReceiptNo(model.key), local: true });
    }
    client.rpc("create_submission", {
      p_model: model.key,
      p_block_b: state.blockB || "",
      p_block_c: state.blockC || "",
      p_block_c_parsed: parsed.fields,
      p_stance: state.stance || null,
      p_title: state.title || null,
      p_title_public: !!state.titlePublic,
      p_nickname: state.nickname || null
    }).then(function (r) {
      if (r.error) {
        // 함수 미배포 등 — Early Access 테스트에서는 로컬 발급으로 폴백
        console.warn("create_submission 실패, 로컬 발급:", r.error.message);
        return cb(null, { ref: makeReceiptNo(model.key), local: true });
      }
      var row = Array.isArray(r.data) ? r.data[0] : r.data;
      cb(null, {
        ref: (row && (row.ref || row)) || makeReceiptNo(model.key),
        nickname: row && row.nickname || null,
        local: false
      });
    }).catch(function (e) {
      console.warn(e);
      cb(null, { ref: makeReceiptNo(model.key), local: true });
    });
  }

  /* -----------------------------------------------------------
     10.5 프롬프트 발급 (§7·§14) — 1단 프롬프트를 서버에서 발급받는다.
     slda-issue-prompt Edge Function 우선. 미도달 시 임베드 PROMPTS 폴백(오프라인 내성).
     반환은 Promise<string>. 모델당 1회 캐시.
     ----------------------------------------------------------- */
  var _promptCache = {};
  function issuePrompt(model) {
    var key = resolveModel(model).key;
    var fallback = PROMPTS[key];
    if (_promptCache[key]) return Promise.resolve(_promptCache[key]);
    if (typeof fetch !== "function") return Promise.resolve(fallback);
    var url = SUPABASE_URL + "/functions/v1/slda-issue-prompt?m=" + key;
    return fetch(url, { headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY } })
      .then(function (r) { if (!r.ok) throw new Error("issue " + r.status); return r.json(); })
      .then(function (d) {
        if (!d || !d.prompt) throw new Error("empty");
        _promptCache[key] = d.prompt;
        return d.prompt;
      })
      .catch(function () { return fallback; });
  }

  /* -----------------------------------------------------------
     11. 상태 저장 — 페이지 간 flow 상태 (sessionStorage)
     BLOCK A(실명 매핑)는 절대 저장하지 않는다. B·C는 이미 라벨화된 것.
     ----------------------------------------------------------- */
  var FLOW_KEY = "slda.flow";
  function getFlow() {
    try { return JSON.parse(sessionStorage.getItem(FLOW_KEY) || "{}"); }
    catch (e) { return {}; }
  }
  function setFlow(patch) {
    var f = getFlow();
    for (var k in patch) if (Object.prototype.hasOwnProperty.call(patch, k)) f[k] = patch[k];
    try { sessionStorage.setItem(FLOW_KEY, JSON.stringify(f)); } catch (e) {}
    return f;
  }
  function clearFlow() { try { sessionStorage.removeItem(FLOW_KEY); } catch (e) {} }

  /* -----------------------------------------------------------
     12. 클립보드 · 토스트 유틸
     ----------------------------------------------------------- */
  function copyText(text, done) {
    function fallback() {
      var ta = document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "");
      ta.style.position = "fixed";
      ta.style.left = "-9999px";
      document.body.appendChild(ta);
      ta.select();
      var ok = false;
      try { ok = document.execCommand("copy"); } catch (e) {}
      document.body.removeChild(ta);
      done && done(ok);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(
        function () { done && done(true); },
        function () { fallback(); }
      );
    } else {
      fallback();
    }
  }

  function toast(msg) {
    var el = document.querySelector(".pl-toast");
    if (!el) {
      el = document.createElement("div");
      el.className = "pl-toast";
      document.body.appendChild(el);
    }
    el.textContent = msg;
    requestAnimationFrame(function () { el.classList.add("show"); });
    clearTimeout(el._t);
    el._t = setTimeout(function () { el.classList.remove("show"); }, 1800);
  }

  /* -----------------------------------------------------------
     헬퍼
     ----------------------------------------------------------- */
  function escapeHtml(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function pad2(n) { return String(n).padStart(2, "0"); }
  function ymd(d) { return "" + d.getFullYear() + pad2(d.getMonth() + 1) + pad2(d.getDate()); }
  function fmtNow() {
    var d = new Date();
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) +
           " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes());
  }
  function dedupe(a) {
    var seen = {}, out = [];
    a.forEach(function (x) { if (!seen[x]) { seen[x] = 1; out.push(x); } });
    return out;
  }

  /* -----------------------------------------------------------
     13. 파일 업로드·병합 (SPEC §13) — 브라우저 전용
     파일은 서버로 전송되지 않는다(FileReader). 파일명 규칙으로 자동 정렬·헤더 삽입.
     파일명 규칙:
       소송(lit):         YYYYMMDD_주체_문서종류_차수.md
       논쟁·발화(sns/spk): YYYYMMDD_HHMM_채널_주체.md
     ----------------------------------------------------------- */
  function fmtDot(d) { return d.slice(0, 4) + "." + d.slice(4, 6) + "." + d.slice(6, 8); }

  function parseUploadName(name, model) {
    var base = String(name || "").replace(/\.[^.]+$/, "");
    var parts = base.split("_");
    var m = resolveModel(model);
    var isChat = (m.key === "sns" || m.key === "spk");
    var out = { name: name, ok: false, ts: 0, header: null };
    var d = (parts[0] && /^\d{8}$/.test(parts[0])) ? parts[0] : null;
    if (!d) return out;

    if (isChat) {
      // YYYYMMDD_HHMM_채널_주체
      var t = (parts[1] && /^\d{3,4}$/.test(parts[1])) ? parts[1].padStart(4, "0") : null;
      if (!t) return out;
      var chan = parts[2] || "", subj = parts.slice(3).join("_") || "";
      out.ok = true;
      out.ts = Number(d) * 10000 + Number(t);
      out.header = "[" + [chan, subj].filter(Boolean).join(" ") + " · " +
                   fmtDot(d) + " " + t.slice(0, 2) + ":" + t.slice(2) + "]";
    } else {
      // YYYYMMDD_주체_문서종류_차수
      var subj2 = parts[1] || "", kind = parts[2] || "", seq = parts[3] || "";
      out.ok = true;
      out.ts = Number(d) * 10000 + (parseInt(seq, 10) || 0);
      out.header = "[" + [subj2, kind].filter(Boolean).join(" · ") + " · " +
                   fmtDot(d) + (seq ? (" · " + seq + "차") : "") + "]";
    }
    return out;
  }

  // items: [{name, text}] → { merged, count, unparsed:[names] }
  function mergeDocs(items, model) {
    var parsed = (items || []).map(function (it) {
      return { p: parseUploadName(it.name, model), text: it.text || "", name: it.name };
    });
    var ok = parsed.filter(function (x) { return x.p.ok; })
                   .sort(function (a, b) { return a.p.ts - b.p.ts; });
    var bad = parsed.filter(function (x) { return !x.p.ok; });   // 파싱 실패분은 업로드 순서 유지, 뒤로
    var ordered = ok.concat(bad);
    var merged = ordered.map(function (x) {
      var header = x.p.ok ? x.p.header : ("[" + x.name + "]");
      return header + "\n" + x.text.trim();
    }).join("\n\n");
    return { merged: merged, count: ordered.length, unparsed: bad.map(function (x) { return x.name; }) };
  }

  /* -----------------------------------------------------------
     노출
     ----------------------------------------------------------- */
  global.SLDA = {
    MODELS: MODELS,
    STEPS: STEPS,
    PROMPTS: PROMPTS,
    REJECT_CODES: REJECT_CODES,
    REJECT_PRIORITY: REJECT_PRIORITY,
    HARD_PATTERNS: HARD_PATTERNS,
    SOFT_PATTERNS: SOFT_PATTERNS,
    resolveModel: resolveModel,
    modelFromUrl: modelFromUrl,
    renderProgress: renderProgress,
    prescan: prescan,
    detectBlockA: detectBlockA,
    parseBlockC: parseBlockC,
    sampleBalance: sampleBalance,
    pickRejectCode: pickRejectCode,
    reviewSubmission: reviewSubmission,
    renderRejectCard: renderRejectCard,
    evalGate: evalGate,
    buildFilename: buildFilename,
    parseUploadName: parseUploadName,
    mergeDocs: mergeDocs,
    makeReceiptNo: makeReceiptNo,
    issuePrompt: issuePrompt,
    submit: submit,
    getFlow: getFlow, setFlow: setFlow, clearFlow: clearFlow,
    copyText: copyText, toast: toast,
    db: db, escapeHtml: escapeHtml, fmtNow: fmtNow
  };
})(typeof window !== "undefined" ? window : this);
