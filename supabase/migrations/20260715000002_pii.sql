-- ============================================================
-- 20260715000002_pii.sql
-- 비식별 처리 검출 → 판정 → 자동 조치
--
--   검출은 사실이고, 판정은 규칙이다.
--   규칙은 신청인 지위(당사자 본인 / 대리인·제3자)에 따라 갈린다.
--   사람이 파일을 열기 전에 돌린다.
--
--   사용:
--     select * from slda.screen_pending();          -- 대기 건 일괄 심사
--     select * from slda.verdict('SLDA-XXXX');      -- 개별 판정 내역
--     select * from slda.scan_summary('본문'::text); -- 임의 텍스트 검사
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. 타입
-- ════════════════════════════════════════════════════════════
do $$ begin
  create type slda.pii_kind as enum
    ('rin', 'case_no', 'name_ctx', 'phone', 'account', 'biz_no');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type slda.verdict_action as enum ('purge', 'review', 'pass');
exception when duplicate_object then null;
end $$;


-- ════════════════════════════════════════════════════════════
-- 2. 사전
-- ════════════════════════════════════════════════════════════

-- ── 한국 성씨 (복성 + 단성) ──
create table if not exists slda.surnames (name text primary key, len int not null);

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
  ('풍',1),('필',1),('학',1),('해',1),('형',1),('화',1),('환',1),('후',1),('흥',1),('희',1)
on conflict (name) do nothing;

-- ── 은행 · 금융기관 · 계좌 문맥어 ──
create table if not exists slda.banks (name text primary key);

insert into slda.banks (name) values
  ('국민은행'),('KB국민'),('신한은행'),('우리은행'),('하나은행'),('KEB하나'),
  ('SC제일'),('제일은행'),('씨티은행'),('한국씨티'),
  ('농협'),('NH농협'),('농협은행'),('축협'),('수협'),('수협은행'),
  ('기업은행'),('IBK기업'),('IBK'),('산업은행'),('KDB'),('수출입은행'),
  ('대구은행'),('DGB'),('부산은행'),('BNK'),('경남은행'),('광주은행'),
  ('전북은행'),('제주은행'),('iM뱅크'),
  ('카카오뱅크'),('케이뱅크'),('토스뱅크'),
  ('새마을금고'),('새마을'),('신협'),('우체국'),('저축은행'),('상호저축'),
  ('미래에셋'),('삼성증권'),('NH투자'),('한국투자'),('키움증권'),
  ('KB증권'),('신한투자'),('하나증권'),('대신증권'),('메리츠'),('유안타'),
  ('교보증권'),('현대차증권'),('한화투자'),('SK증권'),
  ('예금주'),('계좌번호'),('입금계좌'),('가상계좌'),('은행'),('증권')
on conflict (name) do nothing;


-- ════════════════════════════════════════════════════════════
-- 3. 검출
--    마스킹된 것(*가 섞인 것)은 어느 패턴에도 걸리지 않는다.
-- ════════════════════════════════════════════════════════════

-- ── 3-1. 주민등록번호 ──
--   YYMMDD + 구분자 + 7자리. 앞 6자리가 유효 날짜일 때만.
--   900101-1****** → 통과 (마스킹됨)
--   900101-1234567 → 검출
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

-- ── 3-2. 사건번호 ──
--   연도 4자리 + 사건부호 + 일련번호가 모두 숫자일 때.
--   2024가합2***** → 통과
--   2024가합206528 → 검출
create or replace function slda.scan_case_no(p_text text)
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

-- ── 3-3. 성명 + 문맥 ──
--   성씨로 시작하는 3글자가, 같은 문장 안에서 주소 또는 숫자와 함께 나타날 때.
--   2글자 이름은 흔해서 제외한다.
--   "정민하가 주장하기를"           → 통과 (숫자·주소 없음)
--   "정민하 830515-1234567"        → 검출
--   "정민하는 서울시 강남구 123-45" → 검출
create or replace function slda.scan_name_ctx(p_text text)
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
    -- 같은 문장에 주소 표기 또는 3자리 이상 숫자가 있을 때만
    continue when not (
      v_sent ~ '(시|도|구|군|읍|면|동|리|로|길)\s*\d' or v_sent ~ '\d{3,}'
    );

    for v_name in
      select m[1]
      from regexp_matches(v_sent, '(\m' || v_pat || '[가-힣]{2}\M)', 'g') as m
    loop
      hit := v_name;
      ctx := left(v_sent, 160);
      return next;
    end loop;
  end loop;
end;
$$;

-- ── 3-4. 계좌번호 ──
--   은행명 뒤 30자 이내의 미마스킹 숫자열. 은행명이 없으면 검출하지 않는다.
--   "국민은행 123456-**-*****"  → 통과
--   "국민은행 123456-01-234567" → 검출
create or replace function slda.scan_account(p_text text)
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
        v_pat || '[^0-9\*\n]{0,30}(\m[0-9][0-9\-]{5,}[0-9]\M)',
        'g'
      ) as m
    loop
      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;
  end loop;
end;
$$;

-- ── 3-5. 사업자등록번호 ──
--   3-2-5. 뒤 5자리가 모두 숫자일 때.
--   뒤 5자리(일련번호+검증번호)가 가려지면 조회가 불가능하다.
--   123-45-***** → 통과
--   123-45-67890 → 검출
create or replace function slda.scan_biz_no(p_text text)
returns setof text
language sql stable
as $$
  select m[1]
  from regexp_matches(p_text, '(\m\d{3}-\d{2}-\d{5}\M)', 'g') as m;
$$;

-- ── 3-6. 통합 ──
create or replace function slda.scan_pii(p_text text)
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
  select 'biz_no'::slda.pii_kind, b, null::text from slda.scan_biz_no(p_text) as b;
$$;

-- ── 3-7. 요약 ──
create or replace function slda.scan_summary(p_text text)
returns table (kind slda.pii_kind, n bigint, sample text)
language sql stable
as $$
  select s.kind, count(*), min(s.hit)
  from slda.scan_pii(p_text) s
  group by s.kind
  order by s.kind;
$$;


-- ════════════════════════════════════════════════════════════
-- 4. 판정표
--    purge  자동 파기. 사람이 열람하지 않는다.
--    review 사람이 판단한다.
--    pass   통과.
-- ════════════════════════════════════════════════════════════
create table if not exists slda.pii_policy (
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
  ('case_no','party',  'pass', '당사자 본인의 사건번호입니다.'),
  ('case_no','agent',  'purge','대리인·제3자 제출 시 사건번호 뒷자리를 마스킹해야 합니다.'),
  ('case_no','unknown','review','신청인 지위가 확인되지 않았습니다.'),

  -- 성명 — 기계가 본인인지 제3자인지 구분하지 못한다. 사람이 본다.
  ('name_ctx','party',  'review','성명이 주소 또는 식별번호와 함께 나타납니다. 본인 외 제3자인지 확인이 필요합니다.'),
  ('name_ctx','agent',  'review','성명이 주소 또는 식별번호와 함께 나타납니다. 제3자 여부 확인이 필요합니다.'),
  ('name_ctx','unknown','review','성명이 주소 또는 식별번호와 함께 나타납니다.'),

  -- 연락처 — 본인 연락처는 연락처란에 적는다. 본문에 있으면 제3자일 가능성.
  ('phone','party',  'review','연락처가 본문에 있습니다. 본인 연락처는 연락처란에 적어주세요.'),
  ('phone','agent',  'purge','제3자의 연락처가 처리되지 않았습니다.'),
  ('phone','unknown','review','연락처가 본문에 있습니다.'),

  -- 계좌번호 — 은행명과 함께 나타난 미마스킹 번호.
  ('account','party',  'review','은행명과 함께 계좌번호 전체가 나타납니다. 본인 계좌인지 확인이 필요합니다.'),
  ('account','agent',  'purge','제3자의 계좌번호가 처리되지 않았습니다. 앞 5자리만 남기고 마스킹해야 합니다.'),
  ('account','unknown','review','은행명과 함께 계좌번호 전체가 나타납니다.'),

  -- 사업자등록번호 — 뒤 5자리가 가려지면 조회가 불가능하다.
  ('biz_no','party',  'review','사업자등록번호 전체가 나타납니다. 본인 사업자번호인지 확인이 필요합니다.'),
  ('biz_no','agent',  'purge','제3자의 사업자등록번호가 처리되지 않았습니다. 뒤 5자리를 마스킹해야 합니다.'),
  ('biz_no','unknown','review','사업자등록번호 전체가 나타납니다.')
on conflict (kind, role) do update
  set action = excluded.action, note = excluded.note;


-- ════════════════════════════════════════════════════════════
-- 5. 판정
-- ════════════════════════════════════════════════════════════

-- ── 신청인 지위 — 폼이 story 뒤에 붙여둔 줄을 읽는다 ──
create or replace function slda.role_of(p_ref text)
returns text
language sql stable
as $$
  select case
    when s.story ~ '신청인 지위:\s*당사자 본인' then 'party'
    when s.story ~ '신청인 지위:\s*대리인'      then 'agent'
    when s.kind = 'controversy'                 then 'agent'
    else 'unknown'
  end
  from slda.submissions s where s.ref = p_ref;
$$;

-- ── 판정 내역 ──
create or replace function slda.verdict(p_ref text)
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
create or replace function slda.verdict_action(p_ref text)
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
-- 6. 자동 조치
--    purge  → 즉시 파기 대상 + '분석 불가 / 개인정보 미처리' 기록
--    review → 아무것도 하지 않는다
--    pass   → '분석 가능' 기록
-- ════════════════════════════════════════════════════════════
create or replace function slda.apply_verdict(p_ref text)
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
create or replace function slda.screen_pending()
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