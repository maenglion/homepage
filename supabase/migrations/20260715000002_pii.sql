-- ============================================================
-- 20260715000002_pii.sql   (통합본 · 이 파일 하나만 실행한다)
--
-- 비식별 처리 검출 → 판정 → 자동 조치
--
--   검출은 사실이고, 판정은 규칙이다.
--   규칙은 신청인 지위(당사자 본인 / 대리인·제3자)에 따라 갈린다.
--   사람이 파일을 열기 전에 돌린다.
--
--   앞서 만든 pii_scan / pii_verdict / sns / name_fix / email 은 모두 이 파일에 흡수되었다.
--   맨 위에서 전부 지우고 다시 만든다.
--
--   사용:
--     select * from slda.screen_pending();           -- 대기 건 일괄 심사
--     select * from slda.verdict('SLDA-XXXX');       -- 개별 판정 내역
--     select * from slda.scan_pii('본문'::text);      -- 임의 텍스트 검사
--     select * from slda.scan_summary('본문'::text);  -- 유형별 건수만
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 0. 초기화 — 이전 실행분을 전부 제거한다
-- ════════════════════════════════════════════════════════════
drop function if exists slda.screen_pending();
drop function if exists slda.apply_verdict(text);
drop function if exists slda.verdict_action(text);
drop function if exists slda.verdict(text);
drop function if exists slda.role_of(text);
drop function if exists slda.scan_summary(text);
drop function if exists slda.scan_pii(text);
drop function if exists slda.scan_rin(text);
drop function if exists slda.scan_case_no(text);
drop function if exists slda.scan_name_ctx(text);
drop function if exists slda.scan_account(text);
drop function if exists slda.scan_biz_no(text);
drop function if exists slda.scan_sns_id(text);
drop function if exists slda.scan_email(text);
drop function if exists slda.scan_story(text);
drop function if exists slda.fuzzy_pattern(text);
drop function if exists slda.is_place_name(text);

drop table if exists slda.pii_policy;
drop table if exists slda.surnames;
drop table if exists slda.banks;
drop table if exists slda.sns_platforms;
drop table if exists slda.name_stopwords;

drop type if exists slda.pii_kind cascade;
drop type if exists slda.verdict_action cascade;


-- ════════════════════════════════════════════════════════════
-- 1. 타입 — 8종을 한 번에 만든다. ALTER TYPE 이 필요 없다.
-- ════════════════════════════════════════════════════════════
create type slda.pii_kind as enum (
  'rin',       -- 주민등록번호
  'case_no',   -- 사건번호
  'name_ctx',  -- 성명 + 주소/숫자 문맥
  'phone',     -- 휴대폰 번호
  'account',   -- 계좌번호 (은행명 문맥)
  'biz_no',    -- 사업자등록번호
  'sns_id',    -- SNS 계정명
  'email'      -- 이메일 주소
);

create type slda.verdict_action as enum (
  'purge',   -- 자동 파기. 사람이 열람하지 않는다.
  'review',  -- 사람이 판단한다.
  'pass'     -- 통과.
);


-- ════════════════════════════════════════════════════════════
-- 2. 사전
-- ════════════════════════════════════════════════════════════

-- ── 2-1. 한국 성씨 (복성 + 단성) ──
create table slda.surnames (name text primary key, len int not null);

insert into slda.surnames (name, len) values
  ('남궁',2),('독고',2),('황보',2),('제갈',2),('사공',2),('선우',2),('서문',2),('동방',2),
  ('김',1),('이',1),('박',1),('최',1),('정',1),('강',1),('조',1),('윤',1),('장',1),('임',1),
  ('오',1),('한',1),('신',1),('서',1),('권',1),('황',1),('안',1),('송',1),('전',1),('홍',1),
  ('유',1),('고',1),('문',1),('양',1),('손',1),('배',1),('백',1),('허',1),('남',1),('심',1),
  ('노',1),('하',1),('곽',1),('성',1),('차',1),('주',1),('우',1),('구',1),('나',1),('민',1),
  ('진',1),('지',1),('엄',1),('채',1),('원',1),('천',1),('방',1),('공',1),('현',1),('함',1),
  ('변',1),('염',1),('여',1),('추',1),('도',1),('소',1),('석',1),('선',1),('설',1),('마',1),
  ('길',1),('연',1),('위',1),('표',1),('명',1),('기',1),('반',1),('왕',1),('금',1),('옥',1),
  ('육',1),('인',1),('맹',1),('제',1),('모',1),('탁',1),('국',1),('어',1),('은',1),('편',1),
  ('용',1),('봉',1),('경',1),('사',1),('피',1),('두',1),('감',1),('음',1),('빈',1),('동',1),
  ('온',1),('시',1),('복',1),('태',1),('간',1),('류',1),('예',1),('호',1),('묵',1),('견',1),
  ('당',1),('평',1),('대',1),('아',1),('초',1),('춘',1),('탕',1),('판',1),('팽',1),('포',1),
  ('풍',1),('필',1),('학',1),('해',1),('형',1),('화',1),('환',1),('후',1),('흥',1),('희',1);

-- ── 2-2. 은행 · 계좌 문맥어 ──
--   총칭('입금','계좌','은행')은 넣지 않는다.
--   범위가 너무 넓어 같은 줄의 무관한 숫자를 다 잡는다.
create table slda.banks (name text primary key);

insert into slda.banks (name) values
  -- 정식 은행명
  ('국민은행'),('KB국민'),('KB증권'),('신한은행'),('신한투자'),('우리은행'),
  ('하나은행'),('KEB하나'),('하나증권'),('SC제일'),('제일은행'),('씨티은행'),('한국씨티'),
  ('농협은행'),('NH농협'),('NH투자'),('농협중앙회'),('단위농협'),('지역농협'),('축협'),
  ('수협은행'),('수협중앙회'),('기업은행'),('IBK기업'),('산업은행'),('한국산업은행'),
  ('중소기업은행'),('수출입은행'),('한국수출입은행'),
  ('대구은행'),('부산은행'),('경남은행'),('광주은행'),('전북은행'),('제주은행'),('iM뱅크'),
  ('카카오뱅크'),('케이뱅크'),('토스뱅크'),('아이엠뱅크'),
  ('새마을금고'),('신용협동조합'),('우체국예금'),('저축은행'),('상호저축'),
  ('미래에셋'),('삼성증권'),('한국투자'),('키움증권'),('대신증권'),('메리츠'),
  ('유안타'),('교보증권'),('현대차증권'),('한화투자'),('SK증권'),('DB금융투자'),
  -- 영문
  ('Kookmin'),('Shinhan'),('Woori'),('Hana'),('Nonghyup'),('Suhyup'),
  ('Standard Chartered'),('Citibank'),('KakaoBank'),('Kakao Bank'),
  ('Toss Bank'),('TossBank'),('Kbank'),('Industrial Bank of Korea'),
  -- 계좌를 직접 지시하는 문맥어
  ('계좌번호'),('입금계좌'),('가상계좌'),('송금계좌'),('이체계좌'),('예금주');

-- ── 2-3. SNS 플랫폼 ──
--   커뮤니티(디시·에펨·블라인드 등)는 익명 닉네임이라 매칭이 성립하지 않는다. 제외.
create table slda.sns_platforms (name text primary key);

insert into slda.sns_platforms (name) values
  ('SNS'),('소셜네트워크'),('소셜네트워크서비스'),('소셜미디어'),
  ('social network'),('social media'),
  ('인스타그램'),('인스타'),('instagram'),('insta'),
  ('페이스북'),('페북'),('facebook'),('meta'),
  ('트위터'),('엑스'),('twitter'),('tweet'),
  ('스레드'),('쓰레드'),('threads'),
  ('유튜브'),('유투브'),('youtube'),('shorts'),
  ('틱톡'),('tiktok'),
  ('네이버블로그'),('네이버포스트'),('블로그'),('blog'),('naverblog'),('blogspot'),
  ('티스토리'),('tistory'),('브런치'),('브런치스토리'),('brunch'),('velog'),('벨로그'),
  ('워드프레스'),('wordpress'),('medium'),('미디엄'),
  ('카카오스토리'),('카스'),('kakaostory'),('카카오채널'),('오픈채팅'),
  ('링크드인'),('linkedin'),('텀블러'),('tumblr'),('핀터레스트'),('pinterest'),
  ('텔레그램'),('telegram'),('디스코드'),('discord'),('레딧'),('reddit'),
  ('트위치'),('twitch'),('노션'),('notion'),('깃허브'),('github'),
  ('계정명'),('아이디'),('닉네임'),('핸들'),('username'),('user id'),('account'),
  ('프로필'),('profile'),('채널명'),('채널');

-- ── 2-4. 성명 제외어 ──
--   성씨로 시작하지만 이름이 아닌 3글자.
--   부족하면 계속 추가한다:
--     insert into slda.name_stopwords (word) values ('새말') on conflict do nothing;
create table slda.name_stopwords (word text primary key);

insert into slda.name_stopwords (word) values
  -- 광역 행정구역
  ('서울시'),('부산시'),('대구시'),('인천시'),('광주시'),('대전시'),('울산시'),('세종시'),
  ('경기도'),('강원도'),('충청도'),('전라도'),('경상도'),('제주도'),
  ('충청북'),('충청남'),('전라북'),('전라남'),('경상북'),('경상남'),
  -- 소송 · 계약 용어
  ('사업자'),('연락처'),('소외인'),('신청인'),('피신청'),('참고인'),('이해관'),('관계인'),
  ('대리인'),('담당자'),('관리자'),('책임자'),('감정인'),('감정원'),('증인석'),
  ('계약자'),('채권자'),('채무자'),('보증인'),('연대보'),('명의자'),('당사자'),
  ('원고측'),('피고측'),('원고인'),('피고인'),('법정대'),('소송대'),('변호인'),
  ('재판부'),('법원장'),('주심판'),('배석판'),
  -- 법인 형태
  ('주식회'),('유한회'),('합자회'),('합명회'),('사단법'),('재단법'),('영리법'),
  -- 문서 · 서식
  ('신청서'),('진술서'),('의견서'),('답변서'),('준비서'),('증거설'),('사실조'),
  ('계약서'),('약정서'),('합의서'),('확인서'),('공문서'),('사문서'),
  -- 금융 · 회계
  ('보증금'),('계약금'),('중도금'),('잔금일'),('원리금'),('연체이'),('대위변'),
  ('입금액'),('출금액'),('송금액'),('이체액'),('예금주'),('명의인'),
  ('국민은'),('신한은'),('우리은'),('하나은'),('기업은'),('산업은'),('농협은'),
  -- 일반
  ('관련하'),('경우에'),('때문에'),('그러나'),('그리고'),('따라서'),('그런데'),
  ('마찬가'),('아니라'),('하지만'),('다음과'),('상기와'),('전술한'),('후술할'),
  ('구체적'),('명시적'),('묵시적'),('실질적'),('형식적'),('직접적'),('간접적'),
  ('일반적'),('예외적'),('원칙적'),('최종적'),('부분적'),('전체적'),
  ('가능성'),('필요성'),('타당성'),('정당성'),('위법성'),('고의성'),
  ('상당한'),('현저한'),('명백한'),('중대한'),('경미한'),
  ('연월일'),('년월일'),('오전에'),('오후에'),('금일자'),('당일에');


-- ════════════════════════════════════════════════════════════
-- 3. 보조 함수
-- ════════════════════════════════════════════════════════════

-- ── 표기 흔들림 흡수 ──
--   '블로그' → '블[\s\-/·_.]*로[\s\-/·_.]*그'
--   하나만 등록해도 "블 로 그", "블-로-그", "블/로/그" 를 모두 잡는다.
create function slda.fuzzy_pattern(p_name text)
returns text
language sql immutable
as $$
  select regexp_replace(
           regexp_replace(p_name, '[\s\-/·_.]', '', 'g'),
           '(.)', '\1[\s\-/·_.]*', 'g'
         );
$$;

-- ── 행정구역 접미사 ──
create function slda.is_place_name(p_word text)
returns boolean
language sql immutable
as $$
  select p_word ~ '(시|도|구|군|읍|면|동|리|로|길|가|번|층|호)$';
$$;


-- ════════════════════════════════════════════════════════════
-- 4. 검출
--    마스킹된 것(* 가 섞인 것)은 어느 패턴에도 걸리지 않는다.
-- ════════════════════════════════════════════════════════════

-- ── 4-1. 주민등록번호 ──
--   YYMMDD + 구분자 + 7자리. 앞 6자리가 유효 날짜일 때만.
--   900101-1****** → 통과 / 900101-1234567 → 검출
create function slda.scan_rin(p_text text)
returns setof text
language sql stable
as $$
  select m[1]
  from regexp_matches(
    p_text,
    '(\m\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])[-\s]?[1-8]\d{6}\M)',
    'g'
  ) as m;
$$;

-- ── 4-2. 사건번호 ──
--   2024가합2***** → 통과 / 2024가합206528 → 검출
create function slda.scan_case_no(p_text text)
returns setof text
language sql stable
as $$
  select m[1]
  from regexp_matches(
    p_text,
    '((?:19|20)\d{2}\s?(?:가합|가단|가소|가기|카합|카단|카기|고합|고단|고정|고약|초기|즈합|즈단|느합|느단|드합|드단|재가합|재나|타채|타경|하단|하합|하면|비합|비단|나|다|차|노|도|머|므|라|마|바|자|허|후|추|모|과)\s?\d{2,7}\M)',
    'g'
  ) as m;
$$;

-- ── 4-3. 성명 + 문맥 ──
--   성씨로 시작하는 3글자가, 같은 문장 안에서 주소 또는 숫자와 함께 나타날 때.
--   2글자 이름은 흔해서 제외한다.
--   "정민하가 주장하기를"           → 통과 (숫자·주소 없음)
--   "정민하 830515-1234567"        → 검출
--   "서울시 강남구 역삼동"          → 통과 (행정구역)
create function slda.scan_name_ctx(p_text text)
returns table (hit text, ctx text)
language plpgsql stable
as $$
declare
  v_sent text;
  v_pat  text;
  v_name text;
begin
  select '(?:' || string_agg(name, '|' order by len desc, name) || ')'
    into v_pat
  from slda.surnames;

  for v_sent in
    select s from regexp_split_to_table(p_text, '(?<=[.!?。])\s+|\n+') as s
  loop
    continue when not (
      v_sent ~ '(시|도|구|군|읍|면|동|리|로|길)\s*\d' or v_sent ~ '\d{3,}'
    );

    for v_name in
      select m[1]
      from regexp_matches(v_sent, '(\m' || v_pat || '[가-힣]{2}\M)', 'g') as m
    loop
      continue when slda.is_place_name(v_name);
      continue when exists (select 1 from slda.name_stopwords w where w.word = v_name);
      continue when exists (select 1 from slda.banks b where b.name = v_name);

      hit := v_name;
      ctx := left(v_sent, 160);
      return next;
    end loop;
  end loop;
end;
$$;

-- ── 4-4. 계좌번호 ──
--   은행명 뒤 20자 이내의 미마스킹 숫자열. 은행명이 없으면 검출하지 않는다.
--   사업자등록번호·전화번호 형태는 각자의 검출기가 맡는다.
create function slda.scan_account(p_text text)
returns table (hit text, ctx text)
language plpgsql stable
as $$
declare
  v_line text;
  v_pat  text;
  v_hit  text;
begin
  select '(?:' || string_agg(name, '|' order by length(name) desc, name) || ')'
    into v_pat
  from slda.banks;

  for v_line in
    select l from regexp_split_to_table(p_text, '(?<=[.!?。])\s+|\n+') as l
  loop
    continue when v_line !~ v_pat;

    for v_hit in
      select m[1]
      from regexp_matches(
        v_line,
        v_pat || '[^0-9\*\n]{0,20}(\m[0-9][0-9\-]{5,}[0-9]\M)',
        'g'
      ) as m
    loop
      continue when v_hit ~ '\*';
      continue when v_hit ~ '^\d{3}-\d{2}-\d{5}$';               -- 사업자등록번호
      continue when v_hit ~ '^01[016789]-\d{3,4}-\d{4}$';        -- 휴대폰
      continue when v_hit ~ '^0[2-6][0-9]?-\d{3,4}-\d{4}$';      -- 지역번호

      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;
  end loop;
end;
$$;

-- ── 4-5. 사업자등록번호 ──
--   뒤 5자리(일련번호+검증번호)가 가려지면 조회가 불가능하다.
--   123-45-***** → 통과 / 123-45-67890 → 검출
create function slda.scan_biz_no(p_text text)
returns setof text
language sql stable
as $$
  select m[1]
  from regexp_matches(p_text, '(\m\d{3}-\d{2}-\d{5}\M)', 'g') as m;
$$;

-- ── 4-6. 이메일 ──
--   도메인은 남겨도 된다. 식별자는 @ 앞(로컬파트)이다.
--   nanyo***@gmail.com → 통과 / nanyoung@gmail.com → 검출
--   ctx 에 마스킹 예시를 담는다. 반려 시 그대로 보여준다.
create function slda.scan_email(p_text text)
returns table (hit text, ctx text)
language plpgsql stable
as $$
declare
  v_local  text;
  v_domain text;
  m        text[];
begin
  for m in
    select regexp_matches(
      p_text,
      '\m([A-Za-z0-9._%+\-]{1,64})@([A-Za-z0-9.\-]+\.[A-Za-z]{2,})\M',
      'g'
    )
  loop
    v_local  := m[1];
    v_domain := m[2];

    continue when v_local ~ '\*';
    continue when length(v_local) <= 5;   -- 5자 이하는 가릴 것이 없다

    hit := v_local || '@' || v_domain;
    ctx := left(v_local, 5) || repeat('*', length(v_local) - 5) || '@' || v_domain;
    return next;
  end loop;
end;
$$;

-- ── 4-7. SNS 계정명 ──
--   플랫폼명 근처의 미마스킹 계정명. 앞 5자만 남기고 마스킹해야 한다.
--   @nanyo*********** → 통과 / @nanyoung_official → 검출
--   이메일은 scan_email 이 맡는다. 여기서는 제외한다.
create function slda.scan_sns_id(p_text text)
returns table (hit text, ctx text)
language plpgsql stable
as $$
declare
  v_line text;
  v_pat  text;
  v_hit  text;
begin
  select '(?:' || string_agg(slda.fuzzy_pattern(name), '|' order by length(name) desc, name) || ')'
    into v_pat
  from slda.sns_platforms;

  for v_line in
    select l from regexp_split_to_table(p_text, '(?<=[.!?。])\s+|\n+') as l
  loop
    continue when v_line !~* v_pat;

    -- ① @handle — 뒤에 도메인이 붙으면 이메일이므로 제외
    for v_hit in
      select m[1] from regexp_matches(v_line, '@([A-Za-z0-9._]{6,30})(?!\.[A-Za-z]{2,})\M', 'g') as m
    loop
      continue when v_hit ~ '\*';
      hit := '@' || v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;

    -- ② 따옴표 안의 계정명 (곡선따옴표 포함)
    for v_hit in
      select m[1] from regexp_matches(v_line, '[''"“”‘’]([A-Za-z0-9가-힣._\-]{6,40})[''"“”‘’]', 'g') as m
    loop
      continue when v_hit ~ '\*';
      continue when v_hit ~ '@';
      continue when v_hit ~* v_pat;
      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;

    -- ③ 플랫폼명 뒤 40자 이내의 영문 토큰
    for v_hit in
      select m[1]
      from regexp_matches(v_line, v_pat || '[^A-Za-z0-9\*\n]{0,40}\m([A-Za-z][A-Za-z0-9._\-]{5,39})\M', 'g') as m
    loop
      continue when v_hit ~ '\*';
      continue when v_hit ~* v_pat;
      continue when v_line ~ (v_hit || '@') or v_line ~ ('@' || v_hit);   -- 이메일 일부
      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;
  end loop;
end;
$$;

-- ── 4-8. 통합 ──
create function slda.scan_pii(p_text text)
returns table (kind slda.pii_kind, hit text, ctx text)
language sql stable
as $$
  select 'rin'::slda.pii_kind, r, null::text from slda.scan_rin(p_text) as r
  union all
  select 'case_no'::slda.pii_kind, c, null::text from slda.scan_case_no(p_text) as c
  union all
  select 'name_ctx'::slda.pii_kind, n.hit, n.ctx from slda.scan_name_ctx(p_text) as n
  union all
  select 'phone'::slda.pii_kind, m[1], null::text
    from regexp_matches(p_text, '(\m01[016789][-\s]?\d{3,4}[-\s]?\d{4}\M)', 'g') as m
  union all
  select 'account'::slda.pii_kind, a.hit, a.ctx from slda.scan_account(p_text) as a
  union all
  select 'biz_no'::slda.pii_kind, b, null::text from slda.scan_biz_no(p_text) as b
  union all
  select 'sns_id'::slda.pii_kind, s.hit, s.ctx from slda.scan_sns_id(p_text) as s
  union all
  select 'email'::slda.pii_kind, e.hit, e.ctx from slda.scan_email(p_text) as e;
$$;

-- ── 4-9. 요약 ──
create function slda.scan_summary(p_text text)
returns table (kind slda.pii_kind, n bigint, sample text)
language sql stable
as $$
  select s.kind, count(*), min(s.hit)
  from slda.scan_pii(p_text) s
  group by s.kind
  order by s.kind;
$$;


-- ════════════════════════════════════════════════════════════
-- 5. 판정표
-- ════════════════════════════════════════════════════════════
create table slda.pii_policy (
  kind    slda.pii_kind not null,
  role    text not null check (role in ('party','agent','unknown')),
  action  slda.verdict_action not null,
  note    text not null,
  primary key (kind, role)
);

insert into slda.pii_policy (kind, role, action, note) values
  -- 주민등록번호 — 본인 것이라도 뒷자리를 지우라고 안내했다. 예외 없음.
  ('rin','party',  'purge','주민등록번호 13자리가 처리되지 않았습니다. 본인의 번호라도 뒷자리는 삭제해야 합니다.'),
  ('rin','agent',  'purge','제3자의 주민등록번호가 처리되지 않았습니다.'),
  ('rin','unknown','purge','주민등록번호가 처리되지 않았습니다.'),

  -- 사건번호 — 당사자 본인은 자기 사건이므로 그대로 둘 수 있다.
  ('case_no','party',  'pass',  '당사자 본인의 사건번호입니다.'),
  ('case_no','agent',  'purge', '대리인·제3자 제출 시 사건번호 뒷자리를 마스킹해야 합니다.'),
  ('case_no','unknown','review','신청인 지위가 확인되지 않았습니다.'),

  -- 성명 — 기계가 본인인지 제3자인지 구분하지 못한다. 사람이 본다.
  ('name_ctx','party',  'review','성명이 주소 또는 식별번호와 함께 나타납니다. 본인 외 제3자인지 확인이 필요합니다.'),
  ('name_ctx','agent',  'review','성명이 주소 또는 식별번호와 함께 나타납니다. 제3자 여부 확인이 필요합니다.'),
  ('name_ctx','unknown','review','성명이 주소 또는 식별번호와 함께 나타납니다.'),

  -- 연락처 — 본인 연락처는 연락처란에 적는다. 본문에 있으면 제3자일 가능성.
  ('phone','party',  'review','연락처가 본문에 있습니다. 본인 연락처는 연락처란에 적어주세요.'),
  ('phone','agent',  'purge', '제3자의 연락처가 처리되지 않았습니다.'),
  ('phone','unknown','review','연락처가 본문에 있습니다.'),

  -- 계좌번호 — 은행명과 함께 나타난 미마스킹 번호.
  ('account','party',  'review','은행명과 함께 계좌번호 전체가 나타납니다. 본인 계좌인지 확인이 필요합니다.'),
  ('account','agent',  'purge', '제3자의 계좌번호가 처리되지 않았습니다. 앞 5자리만 남기고 마스킹해야 합니다.'),
  ('account','unknown','review','은행명과 함께 계좌번호 전체가 나타납니다.'),

  -- 사업자등록번호 — 뒤 5자리가 가려지면 조회가 불가능하다.
  ('biz_no','party',  'review','사업자등록번호 전체가 나타납니다. 본인 사업자번호인지 확인이 필요합니다.'),
  ('biz_no','agent',  'purge', '제3자의 사업자등록번호가 처리되지 않았습니다. 뒤 5자리를 마스킹해야 합니다.'),
  ('biz_no','unknown','review','사업자등록번호 전체가 나타납니다.'),

  -- SNS 계정명 — 계정명 자체가 식별자다.
  ('sns_id','party',  'review','SNS 계정명이 처리되지 않았습니다. 본인 계정인지 확인이 필요합니다.'),
  ('sns_id','agent',  'purge', '제3자의 SNS 계정명이 처리되지 않았습니다. 앞 5자만 남기고 마스킹해야 합니다.'),
  ('sns_id','unknown','purge', 'SNS 계정명이 처리되지 않았습니다. 앞 5자만 남기고 마스킹해야 합니다.'),

  -- 이메일 — 도메인은 남겨도 된다. @ 앞이 식별자다.
  ('email','party',  'review','이메일 주소가 본문에 있습니다. 본인 주소는 연락처란에 적어주세요.'),
  ('email','agent',  'purge', '제3자의 이메일 주소가 처리되지 않았습니다. @ 앞 5자만 남기고 마스킹해야 합니다. 도메인은 그대로 두어도 됩니다.'),
  ('email','unknown','purge', '이메일 주소가 처리되지 않았습니다. @ 앞 5자만 남기고 마스킹해야 합니다.');


-- ════════════════════════════════════════════════════════════
-- 6. 판정
-- ════════════════════════════════════════════════════════════

-- ── 신청인 지위 — 폼이 story 뒤에 붙여둔 줄을 읽는다 ──
create function slda.role_of(p_ref text)
returns text
language sql stable
as $$
  select case
    when s.story ~ '신청인 지위:\s*당사자 본인' then 'party'
    when s.story ~ '신청인 지위:\s*대리인'      then 'agent'
    when s.kind = 'controversy'                 then 'agent'   -- 논쟁 자료는 제3자 발화가 전제
    else 'unknown'
  end
  from slda.submissions s where s.ref = p_ref;
$$;

-- ── 판정 내역 ──
create function slda.verdict(p_ref text)
returns table (
  action slda.verdict_action,
  kind   slda.pii_kind,
  n      bigint,
  sample text,
  note   text
)
language sql stable
as $$
  with r as (select slda.role_of(p_ref) as role),
  found as (
    select f.kind, count(*) as n, min(f.hit) as sample
    from slda.scan_pii((select s.story from slda.submissions s where s.ref = p_ref)) f
    group by f.kind
  )
  select p.action, f.kind, f.n, f.sample, p.note
  from found f
  cross join r
  join slda.pii_policy p on p.kind = f.kind and p.role = r.role
  order by
    case p.action when 'purge' then 1 when 'review' then 2 else 3 end,
    f.kind;
$$;

-- ── 최종 조치 한 줄 ──
create function slda.verdict_action(p_ref text)
returns slda.verdict_action
language sql stable
as $$
  select coalesce(
    (select v.action from slda.verdict(p_ref) v
      order by case v.action when 'purge' then 1 when 'review' then 2 else 3 end
      limit 1),
    'pass'::slda.verdict_action
  );
$$;


-- ════════════════════════════════════════════════════════════
-- 7. 자동 조치
--    purge  → 즉시 파기 대상 + '분석 불가 / 개인정보 미처리' 기록
--    review → 아무것도 하지 않는다
--    pass   → '분석 가능' 기록
-- ════════════════════════════════════════════════════════════
create function slda.apply_verdict(p_ref text)
returns text
language plpgsql
as $$
declare
  v_act   slda.verdict_action;
  v_notes text;
begin
  v_act := slda.verdict_action(p_ref);

  if v_act = 'purge' then
    select string_agg(v.note, ' ' order by v.kind) into v_notes
    from slda.verdict(p_ref) v where v.action = 'purge';

    perform slda.reject(p_ref, 'privacy', v_notes);
    return 'purge — 즉시 파기 대상. purge 함수를 호출하면 파일이 삭제됩니다.';

  elsif v_act = 'review' then
    return 'review — 확인 필요.  select * from slda.verdict(''' || p_ref || ''');';

  else
    insert into slda.status_log (ref, status) values (p_ref, '분석 가능');
    return 'pass — 비식별 처리 확인. 분석 가능으로 기록했습니다.';
  end if;
end;
$$;

-- ── 대기 건 일괄 심사 ──
create function slda.screen_pending()
returns table (ref text, nickname text, result text)
language plpgsql
as $$
declare
  r record;
begin
  for r in
    select s.ref, s.nickname from slda.submissions s
    where s.purged_at is null
      and not exists (
        select 1 from slda.status_log l
        where l.ref = s.ref and l.status <> '접수'
      )
    order by s.created_at
  loop
    ref := r.ref;
    nickname := r.nickname;
    result := slda.apply_verdict(r.ref);
    return next;
  end loop;
end;
$$;