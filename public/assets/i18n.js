/* ============================================================
   i18n.js — Soul Spectrum KO / EN Language Toggle
   구조 변경 없이 data-i18n 키만 교체합니다.
   ============================================================ */
(function () {
  'use strict';

  /* ── 번역 사전 ─────────────────────────────────────────── */
  var T = {

    /* ── 공통 네비게이션 ── */
    'nav.research':    { ko: 'Research',   en: 'Research' },
    'nav.casp.sub':    { ko: '음성 발화의 비언어 신호', en: 'Non-verbal signals in speech' },
    'nav.slda.sub':    { ko: '문서·논쟁의 의미 드리프트', en: 'Semantic drift in documents & debates' },
    'nav.engine':      { ko: 'Engine',     en: 'Engine' },
    'nav.company':     { ko: 'Company',    en: 'Company' },
    'nav.founder':     { ko: 'Founder',    en: 'Founder' },
    'nav.early-access':{ ko: 'Early Access', en: 'Early Access' },
    'nav.partnership': { ko: 'Partnership', en: 'Partnership' },
    'nav.menu-open':   { ko: '메뉴 열기',  en: 'Open menu' },

    /* ── 공통 푸터 ── */
    'footer.brand':           { ko: '소울스펙트럼 Soul Spectrum Inc.', en: 'Soul Spectrum Inc.' },
    'footer.casp-line':       { ko: 'CASP ENGINE · Cognitive–Adaptive Stress Paralinguistic Engine', en: 'CASP ENGINE · Cognitive–Adaptive Stress Paralinguistic Engine' },
    'footer.slda-line':       { ko: 'SLDA · Semantic Logic Drift Analysis · 의미·논리 드리프트 분석', en: 'SLDA · Semantic Logic Drift Analysis' },
    'footer.biz':             { ko: '(주)소울스펙트럼 · 사업자등록번호: 651-81-03691', en: 'Soul Spectrum Inc. · Business Reg. No.: 651-81-03691' },
    'footer.addr':            { ko: '인천광역시 연수구 테크노파크로111번길 5, 8층 801-에스7호', en: '5 Technopark-ro 111beon-gil, Yeonsu-gu, Incheon, Korea' },
    'footer.privacy-officer': { ko: '개인정보 보호책임자: 맹난영 · nanyoung@soulspectrum.kr', en: 'Privacy Officer: Nanyoung Maeng · nanyoung@soulspectrum.kr' },
    'footer.kakao':           { ko: '카카오톡 채널: @soulspectrum', en: 'KakaoTalk: @soulspectrum' },
    'footer.col-casp':        { ko: 'CASP',    en: 'CASP' },
    'footer.col-slda':        { ko: 'SLDA',    en: 'SLDA' },
    'footer.intro':           { ko: 'Intro',   en: 'Intro' },
    'footer.engine':          { ko: 'Engine',  en: 'Engine' },
    'footer.company':         { ko: 'Company', en: 'Company' },
    'footer.founder':         { ko: 'Founder', en: 'Founder' },
    'footer.contact':         { ko: 'Partnership', en: 'Partnership' },
    'footer.slda-apply':      { ko: '분석 문의', en: 'Inquiry' },
    'footer.slda-status':     { ko: '접수 조회', en: 'Status' },
    'footer.privacy':         { ko: '개인정보 처리방침', en: 'Privacy Policy' },

    /* ── index.html ── */
    'index.eyebrow':              { ko: 'Realtime Paralinguistic Analysis Engine', en: 'Realtime Paralinguistic Analysis Engine' },
    'index.hero.title':           { ko: '텍스트가 아닌 파라링귀스틱.<br /><span class="accent">음성이 담고 있는 변이량을 정량화합니다.</span>', en: 'Not text — paralinguistics.<br /><span class="accent">We quantify the variance encoded in speech.</span>' },
    'index.hero.desc':            { ko: 'CASP ENGINE은 발화의 의미가 아닌 비언어 음성 신호: 말속도·멈춤·리듬·떨림·에너지 변이: 를 추출하고 정규화하여, 커뮤니케이션의 발화 신호 변화를 데이터로 구조화합니다.', en: 'CASP ENGINE extracts and normalises non-verbal speech signals — speech rate, pause, rhythm, tremor, energy variance — and structures the resulting signal changes as data.' },
    'index.badge.patent':         { ko: '특허 출원 중', en: 'Patent Pending' },
    'index.badge.baseline':       { ko: '기준점 데이터셋 구축 중', en: 'Baseline Dataset in Progress' },
    'index.badge.sdk':            { ko: 'SDK · API 준비 중', en: 'SDK · API Coming Soon' },
    'index.casp.title':           { ko: 'CASP는 무엇인가', en: 'What is CASP?' },
    'index.casp.desc':            { ko: '<strong>Cognitive–Adaptive Stress Paralinguistics.</strong> CASP는 단독 서비스가 아니라, 기존 제품·조직의 의사결정 과정에 붙는 엔진입니다. 모바일·웨어러블·차량·콜센터·교육/코칭 등 현장 환경에서 발생하는 커뮤니케이션 신호를 세션 단위 지표로 변환해, 운영·지원·개입 판단에 활용할 수 있습니다.', en: '<strong>Cognitive–Adaptive Stress Paralinguistics.</strong> CASP is not a standalone service; it is an engine that attaches to existing products and organisational decision-making workflows. It converts communication signals from mobile, wearable, automotive, call-centre, and coaching environments into session-level indicators for operational, support, and intervention decisions.' },
    'index.casp.cognitive':       { ko: '정보 처리, 구조화, 전환 속도 등 인지 처리 특성', en: 'Information processing, structuring, and switching speed' },
    'index.casp.adaptive':        { ko: '환경·과제·관계 변화에 대한 적응 반응', en: 'Adaptive responses to environmental, task, and relational changes' },
    'index.casp.stress':          { ko: '인지 과부하·긴장·감각 과잉 상황에서의 반응', en: 'Responses under cognitive overload, tension, or sensory excess' },
    'index.casp.para':            { ko: '말속도·멈춤·떨림·리듬·억양 등 비언어 음성 지표', en: 'Non-verbal speech indicators: rate, pause, tremor, rhythm, intonation' },
    'index.focus.title':          { ko: '우리가 집중하는 것', en: 'What We Focus On' },
    'index.focus.desc':           { ko: '실제 커뮤니케이션의 오해는 "무엇을 말했는가"보다 "어떻게 말했는가"에서 발생합니다. CASP ENGINE은 다음 요소를 핵심 신호로 봅니다.', en: 'Most misunderstandings in communication stem from how something was said, not what was said. CASP ENGINE treats the following as core signals.' },
    'index.focus.volatility':     { ko: '변동성', en: 'Volatility' },
    'index.focus.volatility.desc':{ ko: '말속도 급변, 에너지 급락·급등, 리듬 붕괴', en: 'Sudden rate changes, energy spikes/drops, rhythm collapse' },
    'index.focus.pause':          { ko: '멈춤·전환', en: 'Pause & Transition' },
    'index.focus.pause.desc':     { ko: '비정상적 pause ratio, 전환 구간의 패턴 변화', en: 'Abnormal pause ratio, pattern shifts at transition points' },
    'index.focus.interaction':    { ko: '상호작용', en: 'Interaction' },
    'index.focus.interaction.desc':{ ko: '세션 단위 흐름에서 관계 감정·교류 패턴 모델링', en: 'Session-level modelling of relational affect and exchange patterns' },
    'index.direction.title':      { ko: '기술이 향하는 방향', en: 'Direction of the Technology' },
    'index.direction.desc':       { ko: 'CASP ENGINE은 진단을 대체하지 않습니다. 대신 연구·검증·응용이 가능한 <strong>데이터 구조</strong>로 커뮤니케이션을 재정의합니다.', en: 'CASP ENGINE does not replace diagnosis. Instead, it redefines communication as a <strong>data structure</strong> available for research, validation, and application.' },
    'index.direction.feat':       { ko: '의미를 제거한 비언어 음성 지표 추출 및 정규화', en: 'Extraction and normalisation of non-verbal speech features, stripped of semantic content' },
    'index.direction.score':      { ko: '개인별·상황별 비교 가능한 스코어링·인덱싱 체계', en: 'Comparable scoring and indexing system across individuals and contexts' },
    'index.direction.model':      { ko: '대화 흐름(세션) 기반 상호작용 패턴 모델링', en: 'Session-based interaction pattern modelling' },
    'index.cta.title':            { ko: '협업·검증·PoC가 필요한 기관·기업을 찾습니다.', en: 'We are looking for institutions and companies for collaboration, validation, and PoC.' },
    'index.cta.desc':             { ko: '연구 협업, 데이터 프로젝트, 제품 적용 논의가 가능합니다.', en: 'Research collaboration, data projects, and product integration discussions are open.' },
    'index.cta.btn-contact':      { ko: '제휴·협업 문의', en: 'Contact Us' },
    'index.cta.btn-founder':      { ko: '창업자 소개', en: 'Meet the Founder' },
    'index.slda.eyebrow':         { ko: 'Applied Product Line', en: 'Applied Product Line' },
    'index.slda.title':           { ko: 'SLDA — 의미·논리 드리프트 분석', en: 'SLDA — Semantic Logic Drift Analysis' },
    'index.slda.desc1':           { ko: '<strong>SLDA (Semantic Logic Drift Analysis)</strong> 는 CASP의 변화량 분석 관점을 문서와 논쟁 자료에 확장한 응용 제품군입니다. 여러 차수의 문서를 시간순·주체별·쟁점별로 교차 분석하여 논점 이동, 표현강도 변화, 주체귀속 전환, 전제충돌을 문장 단위로 측정하고 표시합니다.', en: '<strong>SLDA (Semantic Logic Drift Analysis)</strong> extends CASP\'s variance-analysis perspective to documents and debate materials. It cross-analyses multiple document rounds chronologically, by party, and by issue — measuring and marking argument shift, intensity change, attribution transfer, and premise conflict at the sentence level.' },
    'index.slda.desc2':           { ko: 'CASP는 <strong>음성의 드리프트</strong>를, SLDA는 <strong>문서의 드리프트</strong>를 봅니다. 두 엔진은 같은 명제 위에 있습니다 — <strong>개인 기준점 대비 변화량</strong>.', en: 'CASP observes <strong>drift in speech</strong>; SLDA observes <strong>drift in documents</strong>. Both engines rest on the same proposition — <strong>variance relative to an individual baseline</strong>.' },
    'index.slda.logic':           { ko: '논리 드리프트 분석', en: 'Logic Drift Analysis' },
    'index.slda.logic.desc':      { ko: '주장이 시간에 따라 어디에서 이동했는지 타임라인으로 표시', en: 'Timeline display of where an argument has shifted over time' },
    'index.slda.coherence':       { ko: '논리 정합성 분석', en: 'Logical Coherence Analysis' },
    'index.slda.coherence.desc':  { ko: '양립하기 어려운 두 전제를 전제충돌 후보로 묶어 원문과 함께 제시', en: 'Pairs of incompatible premises flagged as premise-conflict candidates, shown alongside source text' },
    'index.slda.attribution':     { ko: '주체귀속 이동', en: 'Attribution Shift' },
    'index.slda.attribution.desc':{ ko: '능력·책임·행위·지배가 누구에게 귀속되는지의 변화 측정', en: 'Measurement of changes in who is attributed capability, responsibility, action, or control' },
    'index.slda.rule':            { ko: 'SLDA는 변화의 <strong>양·분포·진폭을 산출</strong>합니다.<br />변화의 <strong>원인·진위·의도는 산출하지 않습니다.</strong>', en: 'SLDA produces the <strong>quantity, distribution, and amplitude of change</strong>.<br />It does <strong>not</strong> produce the cause, truth, or intent of change.' },
    'index.slda.cta.title':       { ko: 'SLDA Early Access · 3 / 20', en: 'SLDA Early Access · 3 / 20' },
    'index.slda.cta.desc':        { ko: '법률·계약 문서, 논쟁·토론 자료의 초기 분석 케이스를 받고 있습니다. (2026.07 기준)', en: 'Accepting initial analysis cases for legal/contract documents and debate materials. (as of 2026.07)' },
    'index.slda.btn-apply':       { ko: 'SLDA 분석 문의', en: 'SLDA Inquiry' },
    'index.slda.btn-status':      { ko: '접수 조회', en: 'Check Status' },

    /* ── slda.html ── */
    'slda.hero.title':            { ko: '의미·논리 드리프트 분석', en: 'Semantic Logic Drift Analysis' },
    'slda.hero.desc':             { ko: '여러 차수의 문서와 논쟁 자료를 시간순·주체별·쟁점별로 교차 분석하여 논점 이동, 표현강도 변화, 주체귀속 전환, 전제충돌을 문장 단위로 측정하고 표시합니다.', en: 'Cross-analyses multiple document rounds chronologically, by party, and by issue — measuring and marking argument shift, intensity change, attribution transfer, and premise conflict at the sentence level.' },
    'slda.meta.slots':            { ko: 'Early Access · <strong id="slots">3 / 20</strong> · <strong>무료</strong>', en: 'Early Access · <strong id="slots">3 / 20</strong> · <strong>Free</strong>' },
    'slda.meta.cbt':              { ko: '방법론 CBT(폐쇄 베타) · 20명 한정', en: 'Methodology CBT (Closed Beta) · 20 slots' },
    'slda.meta.nopay':            { ko: '현재 결제 단계 없음', en: 'No payment required' },
    'slda.hero.cbt-note':         { ko: 'SLDA 채점 방법론은 현재 <strong>CBT(폐쇄 베타)</strong> 단계로, 초기 20명과 함께 루브릭을 검증합니다. 결과는 즉시 나오지 않고 <strong>최대 3영업일</strong>이 걸립니다 — 미완이 아니라, 방법론을 함께 다듬는 초기 참여입니다.', en: 'The SLDA scoring methodology is currently in <strong>CBT (Closed Beta)</strong>. We are validating the rubric with the first 20 participants. Results take <strong>up to 3 business days</strong> — this is early participation in refining the methodology, not an incomplete product.' },
    'slda.privacy-banner':        { ko: '', en: '' },
    'slda.privacy-banner.title':  { ko: '🔒 1차 변환은 귀하의 기기에서 이루어집니다', en: '🔒 First-stage transformation occurs on your device' },
    'slda.btn-inquiry':           { ko: 'SLDA 분석 문의하기', en: 'Inquire about SLDA Analysis' },
    'slda.btn-status':            { ko: '접수 조회', en: 'Check Status' },
    'slda.rubric.title':          { ko: '누가 넣어도, 같은 자료면 같은 결론', en: 'Same data, same result — regardless of who submits' },
    'slda.rubric.desc':           { ko: 'SLDA는 사안의 진위나 옳고 그름, 승패 가능성을 판단하지 않습니다. 자체 개발한 루브릭에 따라 단어·음절·문장의 특징을 분해하는 시맨틱 분석으로 채점하며, <strong>분석 데이터가 동일하면 누가 요청해도 결과는 같습니다.</strong>', en: 'SLDA does not judge the truth, correctness, or likely outcome of a case. It scores through semantic analysis that decomposes word, syllable, and sentence features according to a proprietary rubric. <strong>Identical input data produces identical results, regardless of who submits it.</strong>' },
    'slda.rubric.fixed':          { ko: '고정 루브릭', en: 'Fixed Rubric' },
    'slda.rubric.fixed.desc':     { ko: '미리 정의된 채점 기준표에 따라 각 항목을 판정합니다. 분석자의 주관이 아니라 규칙이 점수를 정하므로, 동일 자료는 언제 분석해도 동일한 결과가 나옵니다.', en: 'Each item is judged according to a pre-defined scoring rubric. Rules, not analyst subjectivity, determine the score — so identical data always yields identical results.' },
    'slda.rubric.gate':           { ko: '게이트 방식', en: 'Gate Method' },
    'slda.rubric.gate.desc':      { ko: '지정된 쟁점을 다루지 않은 주장은 내부 완결성만으로 점수를 받지 못합니다. 문장이 아무리 정연해도 논점을 벗어났다면 해당 항목을 통과하지 못합니다.', en: 'Arguments that do not address the designated issue cannot score on internal coherence alone. No matter how well-structured a sentence is, it fails the gate if it misses the point.' },
    'slda.rubric.norm':           { ko: '인용 단위 정규화', en: 'Citation-unit Normalisation' },
    'slda.rubric.norm.desc':      { ko: '반복되는 동일 문자열은 하나의 인용 단위로 묶어 셉니다. 같은 표현을 여러 번 반복한 것이 새로운 근거처럼 부풀려지지 않습니다.', en: 'Repeated identical strings are counted as a single citation unit. Repeating the same expression multiple times does not inflate it into new evidence.' },
    'slda.rubric.prenorm':        { ko: '분석 전 정규화', en: 'Pre-analysis Normalisation' },
    'slda.rubric.prenorm.desc':   { ko: '제출된 라벨 자료를 분석에 맞게 정규화합니다(형식 정합성·표기 통일). <strong>원문 내용은 바꾸지 않으므로</strong> 근거 추적과 재현성이 그대로 유지됩니다.', en: 'Submitted labelled data is normalised for analysis (format consistency, notation unification). <strong>Source content is not altered</strong>, so traceability and reproducibility are preserved.' },
    'slda.rubric.trace':          { ko: '근거 추적', en: 'Evidence Traceability' },
    'slda.rubric.trace.desc':     { ko: '모든 판정값은 해당 문장 원문과 함께 기록됩니다. 왜 그 점수가 나왔는지를 원문으로 되짚을 수 있습니다.', en: 'Every scored value is recorded alongside the corresponding source sentence. The reasoning behind each score can be traced back to the original text.' },
    'slda.rule':                  { ko: 'SLDA는 변화의 <strong>양·분포·진폭을 산출</strong>합니다.<br />변화의 <strong>원인·진위·의도는 산출하지 않습니다.</strong><br /><span style="opacity:.75">세고 표시할 뿐, 옳고그름·승패·유불리를 판단하지 않습니다. "왜 여기서 바뀌었지?"는 읽는 사람의 몫입니다.</span>', en: 'SLDA produces the <strong>quantity, distribution, and amplitude of change</strong>.<br />It does <strong>not</strong> produce the cause, truth, or intent of change.<br /><span style="opacity:.75">It counts and marks. It does not judge right/wrong, win/lose, or advantage. "Why did it change here?" is for the reader to decide.</span>' },
    'slda.models.title':          { ko: '엔진 하나, 모델 셋', en: 'One Engine, Three Models' },
    'slda.models.desc':           { ko: '측정 축(드리프트·전제충돌·주체귀속)은 하나의 엔진입니다. 그 위에 자료 유형별 <strong>모델(패키지)</strong>을 얹어, 관찰 규율만 각 맥락에 맞춥니다.', en: 'The measurement axes (drift, premise conflict, attribution) form a single engine. <strong>Model packages</strong> are layered on top per data type, adapting only the observation protocol to each context.' },
    'slda.tab.lit':               { ko: '소송 Litigation', en: 'Litigation' },
    'slda.tab.sns':               { ko: '논쟁 Controversy', en: 'Controversy' },
    'slda.tab.spk':               { ko: '발화 Speaker', en: 'Speaker' },
    'slda.lit.title':             { ko: '소송 · 법률 서면', en: 'Litigation · Legal Documents' },
    'slda.lit.desc':              { ko: '다차수 준비서면·의견서를 <strong>입장별로 분리해</strong> 봅니다(원고편/피고편/소외인편 · 비혼합). 측정한 값만 등재하며, 승패·유불리는 판단하지 않습니다.', en: 'Multi-round briefs and opinions are analysed <strong>by party</strong> (plaintiff / defendant / third party — unmixed). Only measured values are recorded; win/loss and advantage are not assessed.' },
    'slda.lit.m1':                { ko: '표현강도 <b>추이</b>', en: 'Intensity <b>Trend</b>' },
    'slda.lit.m2':                { ko: '같은 결론 <b>반복 횟수</b>', en: 'Conclusion <b>Repetition Count</b>' },
    'slda.lit.m3':                { ko: '근거 <b>교체 횟수</b>', en: 'Evidence <b>Replacement Count</b>' },
    'slda.lit.m4':                { ko: '전제충돌 <b>등재</b>', en: 'Premise Conflict <b>Registration</b>' },
    'slda.lit.m5':                { ko: '주체귀속 <b>이동</b>', en: 'Attribution <b>Shift</b>' },
    'slda.sns.title':             { ko: '논쟁 · 공개 담론', en: 'Controversy · Public Discourse' },
    'slda.sns.desc':              { ko: '논쟁 <strong>양측을 대칭으로</strong> 포함해야 접수됩니다. 쟁점별 게이트로 채점하고, 인용된 문서는 별도로 등재합니다. 한쪽 자료만으로는 분석하지 않습니다.', en: 'Submissions must include <strong>both sides symmetrically</strong>. Scored by issue-specific gates; cited documents are registered separately. One-sided data is not accepted.' },
    'slda.sns.m1':                { ko: '대칭 <b>균형</b>', en: 'Symmetric <b>Balance</b>' },
    'slda.sns.m2':                { ko: '쟁점 <b>게이트 채점</b>', en: 'Issue <b>Gate Scoring</b>' },
    'slda.sns.m3':                { ko: '인용문서 <b>별도 등재</b>', en: 'Cited Documents <b>Separately Registered</b>' },
    'slda.sns.m4':                { ko: '표현강도 <b>대칭 추이</b>', en: 'Intensity <b>Symmetric Trend</b>' },
    'slda.sns.ex1.tag':           { ko: '예시 · SNS', en: 'Example · Social Media' },
    'slda.sns.ex1.title':         { ko: '공개 게시 논쟁 (윤리·정치·사건 등 다양한 주제)', en: 'Public post disputes (ethics, politics, incidents, etc.)' },
    'slda.sns.ex1.desc':          { ko: '공개 타임라인에서 오간 양측 주장을 시간순으로 등재하고, 차수별 표현강도와 근거 교체를 셉니다.', en: 'Both sides\' arguments from a public timeline are registered chronologically; intensity and evidence replacement are counted per round.' },
    'slda.sns.ex2.tag':           { ko: '예시 · 메신저', en: 'Example · Messenger' },
    'slda.sns.ex2.title':         { ko: '단체대화, 2인대화 논점분석', en: 'Group chat / two-party conversation issue analysis' },
    'slda.sns.ex2.desc':          { ko: '양측 발화가 모두 포함된 대화만 접수합니다. 화자A/화자B로 라벨화된 발화만 관찰합니다.', en: 'Only conversations containing both parties are accepted. Only utterances labelled Speaker A / Speaker B are observed.' },
    'slda.spk.title':             { ko: '발화 · 공인 드리프트', en: 'Speaker · Public Figure Drift' },
    'slda.spk.desc':              { ko: '<strong>공인의 공개 발언만</strong> 접수합니다(공인 게이트). 같은 화자의 발언을 시점순으로 묶어 어투·입장의 시점 드리프트를 관찰합니다. <strong>가치판단(위선·거짓)은 하지 않습니다.</strong>', en: '<strong>Only public statements by public figures</strong> are accepted (public-figure gate). Statements by the same speaker are grouped chronologically to observe tonal and positional drift over time. <strong>Value judgements (hypocrisy, falsehood) are not made.</strong>' },
    'slda.spk.m1':                { ko: '공인 <b>게이트</b>', en: 'Public Figure <b>Gate</b>' },
    'slda.spk.m2':                { ko: '시점 <b>드리프트</b>', en: 'Temporal <b>Drift</b>' },
    'slda.spk.m3':                { ko: '입장 <b>번복 횟수</b>', en: 'Position <b>Reversal Count</b>' },
    'slda.spk.m4':                { ko: '표현강도 <b>시점 추이</b>', en: 'Intensity <b>Temporal Trend</b>' },
    'slda.drift.title':           { ko: '차수마다, 관찰값만', en: 'Per Round — Observed Values Only' },
    'slda.drift.desc':            { ko: '각 차수의 서면에서 <strong>관찰한 값만</strong> 세로로 쌓아 보여줍니다. 해석이나 결론은 붙이지 않습니다 — 값이 어떻게 움직였는지만 남깁니다.', en: 'Only <strong>observed values</strong> from each round are stacked vertically. No interpretation or conclusion is appended — only how the values moved.' },
    'slda.drift.r1':              { ko: '1차 · 준비서면', en: 'Round 1 · Brief' },
    'slda.drift.r1.doc':          { ko: '최초 주장 등재', en: 'Initial argument registered' },
    'slda.drift.r2':              { ko: '2차 · 준비서면', en: 'Round 2 · Brief' },
    'slda.drift.r2.doc':          { ko: '같은 결론, 근거 교체', en: 'Same conclusion, evidence replaced' },
    'slda.drift.r3':              { ko: '3차 · 답변서', en: 'Round 3 · Response' },
    'slda.drift.r3.doc':          { ko: '귀속 라벨 이동 관찰', en: 'Attribution label shift observed' },
    'slda.drift.note':            { ko: '위 값은 표시 예시입니다. 실제 리포트는 각 값 옆에 해당 SLDA는 세고 표시하며, 그 움직임을 무엇이라 부를지는 판단하지 않습니다.', en: 'The values above are display examples. In actual reports, each value is shown alongside the corresponding source text. SLDA counts and marks; it does not name what the movement means.' },
    'slda.process.title':         { ko: '원문을 아예 받지 않습니다', en: 'We do not receive the original text at all' },
    'slda.process.desc':          { ko: '개인정보를 <strong>받아서 지우는</strong> 방식이 아닙니다. <strong>애초에 원문을 받지 않는</strong> 방식입니다. 마스킹·라벨화는 사용자가 자신의 AI로 직접 수행하고, 사이트는 그 결과만 받습니다.', en: 'This is not a system that <strong>receives and then deletes</strong> personal information. It is a system that <strong>never receives the original text in the first place</strong>. Masking and labelling are performed by the user with their own AI; the site receives only the result.' },
    'slda.intl-standard.tag':     { ko: '국제 기준 준수', en: 'International Standards Compliance' },
    'slda.intl-standard.p1':      { ko: 'SLDA의 데이터 처리 설계는 <strong>GDPR(EU 일반 개인정보보호 규정)</strong> 및 <strong>APEC CBPR(아태지역 국경 간 프라이버시 규칙)</strong>의 데이터 최소화(Data Minimisation)·목적 제한(Purpose Limitation)·저장 제한(Storage Limitation) 원칙을 따릅니다.', en: 'SLDA\'s data processing design follows the principles of Data Minimisation, Purpose Limitation, and Storage Limitation under <strong>GDPR (EU General Data Protection Regulation)</strong> and <strong>APEC CBPR (Cross-Border Privacy Rules)</strong>.' },
    'slda.intl-standard.p2':      { ko: '핵심 원칙: <strong>1차 변환(라벨화·익명화)은 사용자 본인의 컴퓨터에서만 이루어집니다.</strong> 서버는 변환이 완료된 라벨 결과물만 수령하며, 원문·실명·식별자는 어떤 경로로도 서버에 도달하지 않습니다.', en: 'Core principle: <strong>First-stage transformation (labelling and anonymisation) takes place solely on the user\'s own computer.</strong> The server receives only the completed labelled output; the original text, real names, and identifiers never reach the server by any route.' },
    'slda.proc.th1':              { ko: '단계', en: 'Stage' },
    'slda.proc.th2':              { ko: '하는 일', en: 'Action' },
    'slda.proc.th3':              { ko: '원문의 위치', en: 'Location of Source Text' },
    'slda.proc.s1.name':          { ko: '1차 변환 (로컬)', en: 'Stage 1: Local Transformation' },
    'slda.proc.s1.action':        { ko: '사용자가 <strong>자신의 컴퓨터에서</strong> AI에 원문 + 전처리 프롬프트를 넣어 실명을 라벨(원고/피고N…)로, 식별자를 별표로 치환합니다. <strong>이 과정 전체는 사용자 기기 내에서만 완결됩니다.</strong>', en: 'The user feeds the source text + preprocessing prompt into their AI <strong>on their own computer</strong>, replacing real names with labels (Plaintiff/Defendant N…) and identifiers with asterisks. <strong>This entire process is completed solely within the user\'s device.</strong>' },
    'slda.proc.s1.loc':           { ko: '사용자 기기<br /><span class="proc-note">원문은 브라우저 밖으로 나가지 않음</span>', en: 'User\'s device<br /><span class="proc-note">Source text does not leave the browser</span>' },
    'slda.proc.s2.name':          { ko: '라벨 결과 제출', en: 'Stage 2: Submit Labelled Output' },
    'slda.proc.s2.action':        { ko: 'AI가 만든 <strong>라벨화 본문·익명 요약</strong>만 제출합니다. 실명↔라벨 매핑표는 제출 대상이 아닙니다.', en: 'Only the AI-generated <strong>labelled body text and anonymised summary</strong> are submitted. The real-name-to-label mapping table is not submitted.' },
    'slda.proc.s2.loc':           { ko: '사용자 기기<br /><span class="proc-note">매핑표는 본인 기기에만 보관</span>', en: 'User\'s device<br /><span class="proc-note">Mapping table retained on user\'s device only</span>' },
    'slda.proc.s3.name':          { ko: '접수 필터 (클라이언트)', en: 'Stage 3: Intake Filter (Client-side)' },
    'slda.proc.s3.action':        { ko: '올린 파일을 <strong>브라우저 안에서</strong> 재검사합니다. 식별자 잔존이나 매핑표 형태가 감지되면 접수되지 않습니다.', en: 'Uploaded files are re-inspected <strong>within the browser</strong>. If residual identifiers or mapping-table patterns are detected, the submission is rejected.' },
    'slda.proc.s3.loc':           { ko: '브라우저(클라이언트)<br /><span class="proc-note">검사는 서버로 전송되지 않음</span>', en: 'Browser (client-side)<br /><span class="proc-note">Inspection does not transmit to server</span>' },
    'slda.proc.s4.name':          { ko: '접수', en: 'Stage 4: Intake' },
    'slda.proc.s4.action':        { ko: '접수번호를 발급하고 <strong>라벨화된 본문·요약만</strong> 저장합니다. 실명·원문·매핑은 저장되지 않습니다.', en: 'An intake number is issued and <strong>only the labelled body text and summary</strong> are stored. Real names, source text, and mappings are not stored.' },
    'slda.proc.s4.loc':           { ko: '대한민국 서울<br /><span class="proc-note">라벨화 결과만</span>', en: 'Seoul, Republic of Korea<br /><span class="proc-note">Labelled output only</span>' },
    'slda.proc.s5.name':          { ko: '파기', en: 'Stage 5: Deletion' },
    'slda.proc.s5.action':        { ko: '완료 산출물은 게시 후 <strong>2주 자동 파기</strong>. 부적격 접수는 즉시 파기. 파기 사실만 기록에 남습니다(실명 0).', en: 'Completed outputs are <strong>automatically deleted 2 weeks</strong> after publication. Ineligible submissions are deleted immediately. Only the fact of deletion is recorded (zero real names).' },
    'slda.proc.s5.loc':           { ko: '삭제됨<br /><span class="proc-note">기록만 남고 내용 미보존</span>', en: 'Deleted<br /><span class="proc-note">Record only; content not retained</span>' },
    'slda.proc.rule':             { ko: '접수·상태·파기 기록은 <strong>추가만 가능하고 수정·삭제할 수 없는 구조</strong>로 저장됩니다.<br />그리고 그 기록 어디에도 <strong>실명은 없습니다.</strong>', en: 'Intake, status, and deletion records are stored in an <strong>append-only structure — no modification or deletion is possible</strong>.<br />And <strong>no real names appear anywhere</strong> in those records.' },
    'slda.masking.title':         { ko: '실명은 브라우저를 벗어나지 않습니다', en: 'Real names do not leave the browser' },
    'slda.masking.desc':          { ko: '서버가 자동으로 마스킹하던 방식은 폐지됐습니다. 이제 전처리는 사용자가 직접 수행하며, <strong>서버에는 개인정보를 보관할 장소 자체가 없습니다.</strong>', en: 'The previous approach of server-side automatic masking has been discontinued. Pre-processing is now performed by the user directly, and <strong>the server has no place to store personal data at all.</strong>' },
    'slda.masking.r1':            { ko: '원문은 전송되지 않는다', en: 'Source text is not transmitted' },
    'slda.masking.r1.desc':       { ko: '원문·실명·매핑은 사이트 서버로 전송되지 않습니다. 서버가 수령하는 것은 라벨화된 본문·요약 뿐이며, 분석자가 원문을 열람할 경로가 없습니다.', en: 'Source text, real names, and mappings are not transmitted to the site server. The server receives only labelled body text and summary; there is no route by which an analyst can access the source text.' },
    'slda.masking.r2':            { ko: '전처리는 사용자가 한다', en: 'Pre-processing is performed by the user' },
    'slda.masking.r2.desc':       { ko: '마스킹·라벨화 책임은 위탁자(사용자)에게 있습니다. 사이트는 붙여넣은 결과를 <strong>2차로 재검사</strong>할 뿐입니다.', en: 'Responsibility for masking and labelling lies with the submitter (user). The site only performs a <strong>secondary re-inspection</strong> of the pasted result.' },
    'slda.masking.r3':            { ko: '보관할 장소가 없다', en: 'No storage location exists' },
    'slda.masking.r3.desc':       { ko: '데이터 모델 어디에도 실명·원문·매핑표를 저장하는 컬럼이 없습니다. 남는 것은 라벨·카운트·구간뿐입니다.', en: 'There is no column in the data model for storing real names, source text, or mapping tables. What remains is labels, counts, and intervals only.' },
    'slda.masking.rule-tag':      { ko: '마스킹 규칙', en: 'Masking Rules' },
    'slda.masking.rule-p1':       { ko: '식별자는 <strong>자릿수를 보존한 별표</strong>로 치환합니다(구분자 유지). 주민등록번호는 <strong>앞 6자리(생년월일)를 포함한 13자리 전체</strong>를 가립니다.', en: 'Identifiers are replaced with <strong>asterisks preserving digit count</strong> (separators retained). National ID numbers are masked in full — <strong>all 13 digits including the first 6 (date of birth)</strong>.' },
    'slda.masking.rule-p2':       { ko: '사람 이름은 별표가 아니라 <strong>지위 라벨</strong>(원고·피고N·소외인N)로, 계좌는 <strong>[계좌X·은행명]</strong>으로 치환합니다(은행명 보존, 번호 전체 미노출).', en: 'Personal names are replaced not with asterisks but with <strong>role labels</strong> (Plaintiff, Defendant N, Third Party N). Bank accounts are replaced with <strong>[Account X · Bank Name]</strong> (bank name preserved, full account number not exposed).' },
    'slda.fileformat.title':      { ko: '제출은 파일 업로드입니다', en: 'Submission is by file upload' },
    'slda.fileformat.desc':       { ko: '전처리 AI가 만든 <strong>본문·요약 파일(.md) 2개를 올립니다.</strong> 올리는 즉시 브라우저 안에서 식별자 잔존을 검사합니다(붙여넣기가 아니라 파일 업로드).', en: 'Upload <strong>2 files (.md) — body text and summary</strong> — produced by the preprocessing AI. Residual identifiers are inspected within the browser immediately upon upload (file upload, not paste).' },
    'slda.file.body':             { ko: '본문 파일<br /><span class="rows-tag ok">라벨화 본문</span>', en: 'Body File<br /><span class="rows-tag ok">Labelled Body</span>' },
    'slda.file.body.desc':        { ko: '실명이 지위 라벨로, 식별자가 별표로 치환된 본문 전체. 서면 단위로 구획된 md 파일입니다.', en: 'The full body text with real names replaced by role labels and identifiers replaced by asterisks. An md file sectioned by document unit.' },
    'slda.file.summary':          { ko: '요약 파일<br /><span class="rows-tag ok">익명 요약</span>', en: 'Summary File<br /><span class="rows-tag ok">Anonymised Summary</span>' },
    'slda.file.summary.desc':     { ko: '서면 수·엔티티 규모·시간축·표본 두께 등 라벨·카운트·구간만 담긴 요약. 실명·번호는 포함되지 않습니다.', en: 'A summary containing only labels, counts, and intervals — document count, entity scale, time axis, sample depth. No real names or numbers.' },
    'slda.file.mapping':          { ko: '매핑표<br /><span class="rows-tag">제출 금지</span>', en: 'Mapping Table<br /><span class="rows-tag">Do Not Submit</span>' },
    'slda.file.mapping.desc':     { ko: '실명↔라벨 매핑표. <strong>본인 기기에만 보관</strong>하며 제출하지 않습니다. 실수로 올리면 접수 필터가 자동 반려합니다.', en: 'The real-name-to-label mapping table. <strong>Retain on your own device only</strong> — do not submit. If accidentally uploaded, the intake filter will automatically reject it.' },
    'slda.guide.tag':             { ko: '시작', en: 'Get Started' },
    'slda.guide.title':           { ko: '전처리 프롬프트로 라벨화하기', en: 'Labelling with the Preprocessing Prompt' },
    'slda.guide.desc':            { ko: '사용하는 AI에 원문과 전처리 프롬프트를 함께 넣어 본문·요약을 만드는 방법을 안내합니다.', en: 'A guide to producing body text and summary by feeding the source text and preprocessing prompt together into your AI.' },
    'slda.guide.go':              { ko: '전처리로 →', en: 'Go to Preprocessing →' },
    'slda.overseas.tag':          { ko: '국외 이전 고지', en: 'International Transfer Notice' },
    'slda.overseas.p1':           { ko: '<strong>정규화·분석</strong> 과정의 일부에서 인공지능 도구를 보조적으로 사용하며, 이 과정에서 <strong>라벨화된 텍스트만</strong> 미국(Anthropic PBC)으로 전송될 수 있습니다. 전송받는 곳은 이를 학습에 사용하지 않고 처리 후 보관하지 않습니다. 원문·실명은 애초에 사이트로 전송되지 않으므로 국외로도 나가지 않습니다.', en: 'AI tools are used supplementarily during <strong>normalisation and analysis</strong>. In this process, <strong>only labelled text</strong> may be transmitted to the United States (Anthropic PBC). The recipient does not use it for training and does not retain it after processing. Source text and real names are never transmitted to the site in the first place, so they do not leave the country either.' },
    'slda.overseas.p2':           { ko: '분석에 적합한 <strong>도구를 선택·확정하는 과정</strong>에 전문 검토가 포함됩니다. 점수는 <strong>고정된 루브릭이 산출</strong>하며 사람이 가감하지 않습니다 — 같은 자료면 누가 요청해도 결과는 같습니다.', en: 'Expert review is included in the process of <strong>selecting and confirming appropriate tools</strong> for analysis. Scores are <strong>produced by a fixed rubric</strong> and are not adjusted by humans — identical data yields identical results regardless of who requests it.' },
    'slda.cta.title':             { ko: 'SLDA 분석을 검토 중이신가요?', en: 'Considering SLDA analysis?' },
    'slda.cta.desc':              { ko: '직접 신청 전에 분석 대상 자료의 적합성, 전처리 방법, 결과 형식에 대해 먼저 문의하실 수 있습니다.', en: 'Before submitting directly, you can first inquire about the suitability of your materials, the preprocessing method, and the result format.' },
    'slda.cta.btn':               { ko: '분석 문의하기', en: 'Contact for Analysis' },
    'slda.cta.btn-status':        { ko: '접수 조회', en: 'Check Status' },
    'slda.faq.title':             { ko: '자주 묻는 질문', en: 'Frequently Asked Questions' },
    'slda.faq.desc':              { ko: '궁금한 항목을 눌러 펼쳐보세요.', en: 'Click an item to expand.' },
    'slda.faq.cat1':              { ko: '표기 · 개념', en: 'Notation · Concepts' },
    'slda.faq.q1':                { ko: 'SDLA 분석인가요, SLDA 분석인가요?', en: 'Is it SDLA or SLDA?' },
    'slda.faq.a1':                { ko: '정확한 표기는 <strong>SLDA (Semantic Logic Drift Analysis)</strong> 입니다. Semantic <strong>L</strong>ogic <strong>D</strong>rift Analysis 의 약어이며, SDLA로 잘못 표기되는 경우가 있습니다. 국문으로는 의미·논리 드리프트 분석, 줄여서 논리 드리프트 분석 또는 논리 정합성 분석이라 합니다.', en: 'The correct notation is <strong>SLDA (Semantic Logic Drift Analysis)</strong>. It is an abbreviation of Semantic <strong>L</strong>ogic <strong>D</strong>rift Analysis; SDLA is a common misspelling. In Korean it is called 의미·논리 드리프트 분석, or abbreviated as 논리 드리프트 분석 or 논리 정합성 분석.' },
    'slda.faq.q2':                { ko: '전처리가 무엇인가요?', en: 'What is preprocessing?' },
    'slda.faq.a2':                { ko: '원문 대신 <strong>이름을 지운(라벨로 바꾼) 자료</strong>를 넣는 과정입니다. 상대방의 개인정보를 보호하고, 우리가 <strong>원문을 아예 받지 않기 위해서</strong>입니다.', en: 'It is the process of substituting <strong>data with names removed (replaced by labels)</strong> for the original text. This protects the personal information of third parties and ensures that <strong>we never receive the source text at all</strong>.' },
    'slda.faq.cat2':              { ko: '개인정보 · 파기', en: 'Personal Data · Deletion' },
    'slda.faq.q3':                { ko: '개인정보 없이 분석이 가능한가요?', en: 'Is analysis possible without personal data?' },
    'slda.faq.a3':                { ko: '네. SLDA는 <strong>그 사람이 누구인지 알 필요가 없습니다.</strong> 필요한 것은 실명이 아니라 <strong>누가 누구인지의 구분</strong>(원고·피고1·화자A 같은 지칭)뿐입니다. 그래서 개인정보를 <strong>받아서 지우는</strong> 것이 아니라, <strong>애초에 원문을 받지 않습니다.</strong>', en: 'Yes. SLDA <strong>does not need to know who a person is.</strong> What is needed is not a real name but a <strong>distinction of who is who</strong> (labels such as Plaintiff, Defendant 1, Speaker A). So rather than <strong>receiving and deleting</strong> personal data, we <strong>never receive the source text in the first place.</strong>' },
    'slda.faq.q4':                { ko: '개인정보는 어떻게 자동파기되나요?', en: 'How is personal data automatically deleted?' },
    'slda.faq.a4':                { ko: '파기는 사람이 손으로 지우는 것이 아니라 <strong>예약 작업</strong>이 처리합니다. 완료 산출물은 게시 후 <strong>2주(14일)</strong>가 지나면 자동 파기되고, 부적격 접수는 즉시 파기됩니다.', en: 'Deletion is not performed manually but by a <strong>scheduled task</strong>. Completed outputs are automatically deleted <strong>2 weeks (14 days)</strong> after publication; ineligible submissions are deleted immediately.' },
    'slda.faq.cat3':              { ko: '사용 방법', en: 'How to Use' },
    'slda.faq.q5':                { ko: '프롬프트는 어떻게 사용하나요?', en: 'How do I use the prompt?' },
    'slda.faq.a5':                { ko: '<code>전처리</code> 페이지에서 파일을 <strong>파일명 규칙</strong>에 맞춰 올리면 브라우저가 시간순으로 합쳐줍니다. 전처리를 시작하면 <strong>프롬프트가 서버에서 발급</strong>됩니다. \'프롬프트 + 내 자료 함께 복사\'를 눌러 사용하는 AI에 붙여넣으면 AI가 결과를 만들어 줍니다.', en: 'Upload files to the <code>Preprocessing</code> page following the <strong>filename convention</strong>; the browser merges them chronologically. When preprocessing begins, the <strong>prompt is issued from the server</strong>. Click "Copy prompt + my data together" and paste into your AI; the AI will produce the result.' },
    'slda.faq.q6':                { ko: '사진·이모티콘은 어떻게 넣나요?', en: 'How do I include photos or emojis?' },
    'slda.faq.a6':                { ko: 'SLDA는 글자만 읽습니다. 사진·이모티콘·스티커는 <strong>보이는 대로</strong> 본문에 적어주세요. <strong>외형만 적고, 무슨 뜻인지는 쓰지 마세요.</strong>', en: 'SLDA reads text only. Describe photos, emojis, and stickers <strong>as they appear</strong> in the body text. <strong>Describe only the appearance; do not write what they mean.</strong>' },
    'slda.faq.cat4':              { ko: '무엇을 잡아내나', en: 'What Does It Detect?' },
    'slda.faq.q7':                { ko: '논점 흐리기·물타기를 잡아내나요?', en: 'Does it detect issue-blurring or deflection?' },
    'slda.faq.a7':                { ko: 'SLDA는 논점이 <strong>어디서 이동했는지</strong>를 문장 단위로 표시합니다. 그 이동을 무엇이라 부를지는 읽는 사람의 판단입니다(SLDA는 단정하지 않습니다).', en: 'SLDA marks <strong>where an argument shifted</strong> at the sentence level. What to call that shift is for the reader to judge (SLDA makes no determination).' },
    'slda.faq.q8':                { ko: '말바꾸기·논리 모순을 찾나요?', en: 'Does it find position reversals or logical contradictions?' },
    'slda.faq.a8':                { ko: '서로 양립하기 어려운 두 전제를 사용한 지점을 <strong>전제충돌 후보</strong>로 묶어 원문과 함께 제시합니다. 변화와 충돌 후보를 <strong>표시</strong>할 뿐, 의도나 진위는 단정하지 않습니다.', en: 'Points where two incompatible premises are used are grouped as <strong>premise-conflict candidates</strong> and presented alongside the source text. Changes and conflict candidates are <strong>marked</strong>; intent and truth are not determined.' },
    'slda.faq.q9':                { ko: '논쟁 쟁점 찾기에 쓸 수 있나요?', en: 'Can it be used to identify dispute issues?' },
    'slda.faq.a9':                { ko: '그것이 논쟁 모델의 주된 용도입니다. 논쟁 자료는 <strong>양쪽을 동시에</strong> 분석하며, 한쪽만 분석한 결과물은 제공하지 않습니다(대칭 필수).', en: 'That is the primary use of the Controversy model. Dispute materials are analysed <strong>with both sides simultaneously</strong>; one-sided results are not provided (symmetry is required).' },
    'slda.faq.cat5':              { ko: '비용', en: 'Cost' },
    'slda.faq.q10':               { ko: '비용이 드나요?', en: 'Is there a cost?' },
    'slda.faq.a10':               { ko: '현재는 <strong>Early Access · 무료</strong>입니다. <strong>결제 단계가 없습니다.</strong> 정식 전환 시 요금 안내가 별도로 공지됩니다.', en: 'Currently <strong>Early Access · Free</strong>. <strong>No payment step.</strong> Pricing will be announced separately upon official launch.' },
    'slda.faq.cat6':              { ko: '진행 방식', en: 'Process' },
    'slda.faq.q11':               { ko: 'CBT(폐쇄 베타)는 무엇이고, 왜 결과가 바로 안 나오나요?', en: 'What is CBT (Closed Beta) and why are results not immediate?' },
    'slda.faq.a11':               { ko: 'SLDA 채점 방법론은 자동화가 목표이며, 지금은 <strong>CBT(폐쇄 베타) · 20명 한정</strong> 단계입니다. 전문 검토가 들어가 루브릭을 검증하므로 <strong>최대 3영업일</strong>이 걸립니다. 단, <strong>점수 자체는 고정된 루브릭이 산출</strong>하며 사람이 가감하지 않습니다.', en: 'The SLDA scoring methodology targets full automation; it is currently in <strong>CBT (Closed Beta) · 20 slots</strong>. Expert review validates the rubric, so results take <strong>up to 3 business days</strong>. However, <strong>scores are produced by a fixed rubric</strong> and are not adjusted by humans.' },

    /* ── engine.html ── */
    'engine.hero.title':    { ko: '같은 음성은 같은 값을 낸다', en: 'Same speech, same value' },
    'engine.hero.desc':     { ko: 'CASP ENGINE은 발화를 텍스트로 옮기지 않습니다. 음성 신호에서 지표를 뽑고, 개인 기준점 대비 변이량으로 정렬합니다. 기준값이 갱신되더라도 과거 분석 결과는 그대로 재현됩니다.', en: 'CASP ENGINE does not transcribe speech to text. It extracts indicators from the audio signal and aligns them as variance relative to an individual baseline. Past analysis results remain reproducible even when the baseline is updated.' },
    'engine.pipeline.title':{ ko: '분석 파이프라인', en: 'Analysis Pipeline' },
    'engine.realtime.title':{ ko: '실시간 처리와 기준값 갱신을 분리합니다', en: 'Real-time processing and baseline updates are decoupled' },
    'engine.repro.title':   { ko: '재현 가능성', en: 'Reproducibility' },
    'engine.tworef.title':  { ko: '두 가지 기준', en: 'Two Reference Standards' },
    'engine.not.title':     { ko: '산출하지 않는 것', en: 'What Is Not Produced' },

    /* ── company.html ── */
    'company.hero.title':   { ko: '변화가 일어난 지점을 찾습니다', en: 'We find where change occurs' },
    'company.why.title':    { ko: '왜 변이량인가', en: 'Why variance?' },
    'company.prop.title':   { ko: '두 제품, 하나의 명제', en: 'Two products, one proposition' },
    'company.origin.title': { ko: '이 관점은 어디에서 왔는가', en: 'Where does this perspective come from?' },
    'company.journey.title':{ ko: 'Journey', en: 'Journey' },
    'company.not.title':    { ko: '우리가 하지 않는 것', en: 'What we do not do' }
  };

  /* ── 언어 상태 ─────────────────────────────────────────── */
  var STORAGE_KEY = 'ss_lang';
  var currentLang = localStorage.getItem(STORAGE_KEY) || 'ko';

  /* ── DOM 적용 ───────────────────────────────────────────── */
  function applyLang(lang) {
    var els = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      var key = el.getAttribute('data-i18n');
      if (T[key] && T[key][lang] !== undefined && T[key][lang] !== '') {
        el.innerHTML = T[key][lang];
      }
    }
    // aria-label for nav-toggle
    var ariaEls = document.querySelectorAll('[data-i18n-aria]');
    for (var j = 0; j < ariaEls.length; j++) {
      var aEl = ariaEls[j];
      var aKey = aEl.getAttribute('data-i18n-aria');
      if (T[aKey] && T[aKey][lang]) {
        aEl.setAttribute('aria-label', T[aKey][lang]);
      }
    }
    // html lang attribute
    document.documentElement.lang = lang === 'ko' ? 'ko' : 'en';
    // 데스크톱 토글 버튼
    var label = lang === 'ko' ? 'ENG' : 'KOR';
    var ariaLabel = lang === 'ko' ? 'Switch to English' : '한국어로 전환';
    var btn = document.getElementById('lang-toggle');
    if (btn) {
      btn.textContent = label;
      btn.setAttribute('aria-label', ariaLabel);
    }
    // 모바일 토글 버튼
    var mbtns = document.querySelectorAll('.lang-toggle-mobile');
    for (var k = 0; k < mbtns.length; k++) {
      mbtns[k].textContent = label;
      mbtns[k].setAttribute('aria-label', ariaLabel);
    }
  }

  /* ── 토글 이벤트 ───────────────────────────────────────────────────── */
  function onToggle() {
    currentLang = currentLang === 'ko' ? 'en' : 'ko';
    localStorage.setItem(STORAGE_KEY, currentLang);
    applyLang(currentLang);
  }

  function initToggle() {
    // 데스크톱
    var btn = document.getElementById('lang-toggle');
    if (btn) btn.addEventListener('click', onToggle);
    // 모바일 (복수 가능)
    var mbtns = document.querySelectorAll('.lang-toggle-mobile');
    for (var i = 0; i < mbtns.length; i++) {
      mbtns[i].addEventListener('click', onToggle);
    }
  }

  /* ── 초기화 ─────────────────────────────────────────────── */
  function init() {
    applyLang(currentLang);
    initToggle();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
