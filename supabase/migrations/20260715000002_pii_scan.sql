-- ============================================================
-- 20260715000002_pii_scan.sql
-- 비식별 처리 여부 검출.
--   1) 주민등록번호 — 13자리가 모두 숫자
--   2) 사건번호 — 뒷자리가 모두 숫자
--   3) 성명 — 성씨로 시작하는 3글자가, 같은 문장 안에서 주소·숫자와 함께 나타남
-- ============================================================

-- ------------------------------------------------------------
-- 한국 성씨 (단일 글자 + 복성)
-- 2015 인구주택총조사 기준 상위 성씨. 99% 이상 포괄.
-- ------------------------------------------------------------
create table if not exists slda.surnames (name text primary key, len int not null);

insert into slda.surnames (name, len) values
  -- 복성 먼저 (긴 것부터 매칭)
  ('남궁',2),('독고',2),('황보',2),('제갈',2),('사공',2),('선우',2),('서문',2),('동방',2),
  ('어금',2),('망절',2),('小峰',2),
  -- 단성
  ('김',1),('이',1),('박',1),('최',1),('정',1),('강',1),('조',1),('윤',1),('장',1),('임',1),
  ('오',1),('한',1),('신',1),('서',1),('권',1),('황',1),('안',1),('송',1),('전',1),('홍',1),
  ('유',1),('고',1),('문',1),('양',1),('손',1),('배',1),('백',1),('허',1),('남',1),('심',1),
  ('노',1),('하',1),('곽',1),('성',1),('차',1),('주',1),('우',1),('구',1),('나',1),('민',1),
  ('진',1),('지',1),('엄',1),('채',1),('원',1),('천',1),('방',1),('공',1),('현',1),('함',1),
  ('변',1),('염',1),('여',1),('추',1),('도',1),('소',1),('석',1),('선',1),('설',1),('마',1),
  ('길',1),('연',1),('위',1),('표',1),('명',1),('기',1),('반',1),('왕',1),('금',1),('옥',1),
  ('육',1),('인',1),('맹',1),('제',1),('모',1),('탁',1),('국',1),('어',1),('은',1),('편',1),
  ('용',1),('봉',1),('경',1),('사',1),('피',1),('두',1),('감',1),('음',1),('빈',1),('동',1),
  ('온',1),('시',1),('복',1),('태',1),('간',1),('료',1),('류',1),('노',1),('예',1),('호',1),
  ('가',1),('묵',1),('탄',1),('견',1),('당',1),('평',1),('대',1),('아',1),('야',1),('오',1),
  ('즙',1),('초',1),('총',1),('추',1),('춘',1),('탕',1),('판',1),('팽',1),('포',1),('풍',1),
  ('필',1),('학',1),('해',1),('형',1),('화',1),('환',1),('후',1),('훈',1),('흥',1),('희',1)
on conflict (name) do nothing;


-- ------------------------------------------------------------
-- 검출 유형
-- ------------------------------------------------------------
do $$ begin
  create type slda.pii_kind as enum ('rin', 'case_no', 'name_ctx', 'phone', 'account');
exception when duplicate_object then null;
end $$;


-- ------------------------------------------------------------
-- 1) 주민등록번호 — YYMMDD + 구분자 + 7자리, 앞자리가 유효 날짜
--    마스킹된 것(900101-1******)은 걸리지 않는다.
-- ------------------------------------------------------------
create or replace function slda.scan_rin(p_text text)
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


-- ------------------------------------------------------------
-- 2) 사건번호 — 연도 4자리 + 사건부호 + 일련번호가 모두 숫자
--    마스킹된 것(2024가합2*****)은 걸리지 않는다.
-- ------------------------------------------------------------
create or replace function slda.scan_case_no(p_text text)
returns setof text
language sql stable
as $$
  select m[1]
  from regexp_matches(
    p_text,
    '((?:19|20)\d{2}\s?(?:가합|가단|가소|가기|나|다|차|카합|카단|카기|고합|고단|고정|고약|노|도|초기|즈합|즈단|느합|느단|드합|드단|재가합|재나|머|므|타채|타경|하단|하합|하면|비합|비단|라|마|바|자|허|후|추|모|과)\s?\d{2,7}\M)',
    'g'
  ) as m;
$$;


-- ------------------------------------------------------------
-- 3) 성명 + 문맥
--    성씨로 시작하는 3글자 이름이, 같은 문장 안에서
--    주소 또는 숫자와 함께 나타나는 경우만 검출한다.
--    2글자 이름은 흔해서 제외한다.
-- ------------------------------------------------------------
create or replace function slda.scan_name_ctx(p_text text)
returns table (hit text, sentence text)
language plpgsql stable
as $$
declare
  v_sent text;
  v_pat  text;
  v_name text;
begin
  -- 성씨 목록으로 이름 패턴을 만든다 (복성 우선)
  select '(?:' || string_agg(name, '|' order by len desc, name) || ')'
    into v_pat
  from slda.surnames;

  -- 문장 단위로 쪼갠다
  for v_sent in
    select s from regexp_split_to_table(p_text, '(?<=[.!?。])\s+|\n+') as s
  loop
    -- 주소 또는 숫자가 같은 문장에 있어야 한다
    if v_sent ~ '(시|도|구|군|읍|면|동|리|로|길)\s*\d' or v_sent ~ '\d{3,}' then
      for v_name in
        select m[1]
        from regexp_matches(v_sent, '(\m' || v_pat || '[가-힣]{2}\M)', 'g') as m
      loop
        hit := v_name;
        sentence := left(v_sent, 160);
        return next;
      end loop;
    end if;
  end loop;
end;
$$;


-- ------------------------------------------------------------
-- 4) 통합 검사 — 이것만 부르면 된다
-- ------------------------------------------------------------
create or replace function slda.scan_pii(p_text text)
returns table (kind slda.pii_kind, hit text, ctx text)
language sql stable
as $$
  select 'rin'::slda.pii_kind, r, null::text from slda.scan_rin(p_text) as r
  union all
  select 'case_no'::slda.pii_kind, c, null::text from slda.scan_case_no(p_text) as c
  union all
  select 'name_ctx'::slda.pii_kind, n.hit, n.sentence from slda.scan_name_ctx(p_text) as n
  union all
  select 'phone'::slda.pii_kind, m[1], null::text
    from regexp_matches(p_text, '(\m01[016789][-\s]?\d{3,4}[-\s]?\d{4}\M)', 'g') as m
  union all
  select 'account'::slda.pii_kind, m[1], null::text
    from regexp_matches(p_text, '(\m\d{2,6}-\d{2,6}-\d{2,8}\M)', 'g') as m;
$$;


-- ------------------------------------------------------------
-- 5) 요약 — 유형별 건수만
-- ------------------------------------------------------------
create or replace function slda.scan_summary(p_text text)
returns table (kind slda.pii_kind, n bigint, sample text)
language sql stable
as $$
  select s.kind, count(*), min(s.hit)
  from slda.scan_pii(p_text) s
  group by s.kind
  order by s.kind;
$$;


-- ------------------------------------------------------------
-- 6) 접수 건의 사연 검사
-- ------------------------------------------------------------
create or replace function slda.scan_story(p_ref text)
returns table (kind slda.pii_kind, n bigint, sample text)
language sql stable
as $$
  select * from slda.scan_summary(
    (select story from slda.submissions where ref = p_ref)
  );
$$;