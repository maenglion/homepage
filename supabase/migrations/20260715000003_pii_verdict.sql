-- ============================================================
-- 20260715000003_pii_verdict.sql
-- 검출 → 판정.
-- 검출은 사실이고, 판정은 규칙이다. 규칙은 신청인 지위에 따라 갈린다.
-- ============================================================

-- ------------------------------------------------------------
-- 판정 결과
--   purge  자동 파기. 사람이 열람하지 않는다.
--   review 사람이 판단한다.
--   pass   통과.
-- ------------------------------------------------------------
do $$ begin
  create type slda.verdict_action as enum ('purge', 'review', 'pass');
exception when duplicate_object then null;
end $$;


-- ------------------------------------------------------------
-- 판정표
--   role: party(당사자 본인) / agent(대리인·제3자) / unknown
-- ------------------------------------------------------------
create table if not exists slda.pii_policy (
  kind    slda.pii_kind not null,
  role    text not null check (role in ('party','agent','unknown')),
  action  slda.verdict_action not null,
  note    text not null,
  primary key (kind, role)
);

insert into slda.pii_policy (kind, role, action, note) values
  -- 주민등록번호: 본인 것이라도 뒷자리를 지우라고 안내했다. 예외 없음.
  ('rin','party','purge','주민등록번호 13자리가 처리되지 않았습니다. 본인의 번호라도 뒷자리는 삭제해야 합니다.'),
  ('rin','agent','purge','제3자의 주민등록번호가 처리되지 않았습니다.'),
  ('rin','unknown','purge','주민등록번호가 처리되지 않았습니다.'),

  -- 사건번호: 당사자 본인은 자기 사건이므로 그대로 둘 수 있다.
  ('case_no','party','pass','당사자 본인의 사건번호입니다.'),
  ('case_no','agent','purge','대리인·제3자 제출 시 사건번호 뒷자리를 마스킹해야 합니다.'),
  ('case_no','unknown','review','지위가 확인되지 않았습니다.'),

  -- 성명: 본인 이름인지 제3자인지 기계가 구분하지 못한다.
  ('name_ctx','party','review','성명이 주소 또는 식별번호와 함께 나타납니다. 본인 외 제3자인지 확인이 필요합니다.'),
  ('name_ctx','agent','review','성명이 주소 또는 식별번호와 함께 나타납니다. 제3자 여부 확인이 필요합니다.'),
  ('name_ctx','unknown','review','성명이 주소 또는 식별번호와 함께 나타납니다.'),

  -- 연락처: 본인 연락처는 연락처란에 적는다. 본문에 있으면 제3자일 가능성.
  ('phone','party','review','연락처가 본문에 있습니다. 본인 연락처는 연락처란에 적어주세요.'),
  ('phone','agent','purge','제3자의 연락처가 처리되지 않았습니다.'),
  ('phone','unknown','review','연락처가 본문에 있습니다.'),

  -- 계좌·사업자번호 형태: 계약서에는 정상적으로 존재할 수 있다.
  ('account','party','review','계좌번호 형태의 숫자가 있습니다.'),
  ('account','agent','review','계좌번호 형태의 숫자가 있습니다. 제3자의 것이면 삭제해야 합니다.'),
  ('account','unknown','review','계좌번호 형태의 숫자가 있습니다.')
on conflict (kind, role) do update
  set action = excluded.action, note = excluded.note;


-- ------------------------------------------------------------
-- 접수 건의 신청인 지위를 읽는다.
-- 폼이 story 뒤에 "신청인 지위: ..." 를 붙여둔다.
-- ------------------------------------------------------------
create or replace function slda.role_of(p_ref text)
returns text
language sql stable
as $$
  select case
    when s.story ~ '신청인 지위:\s*당사자 본인'   then 'party'
    when s.story ~ '신청인 지위:\s*대리인'        then 'agent'
    when s.kind = 'controversy'                   then 'agent'   -- 논쟁 자료는 제3자 발화가 전제
    else 'unknown'
  end
  from slda.submissions s where s.ref = p_ref;
$$;


-- ------------------------------------------------------------
-- ★ 판정 — 이것만 부르면 된다.
--    반환: 최종 조치 + 유형별 내역
-- ------------------------------------------------------------
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
  join r on true
  join slda.pii_policy p on p.kind = f.kind and p.role = r.role
  order by
    case p.action when 'purge' then 1 when 'review' then 2 else 3 end,
    f.kind;
$$;


-- ------------------------------------------------------------
-- 최종 조치 한 줄
--   하나라도 purge 면 purge. 없으면 review 여부. 다 pass 면 pass.
-- ------------------------------------------------------------
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


-- ------------------------------------------------------------
-- 판정에 따라 자동 처리.
--   purge  → 즉시 파기 대상 + '분석 불가 / 개인정보 미처리' 기록
--   review → 아무것도 하지 않는다. 사람이 본다.
--   pass   → '분석 가능' 기록
-- 사람이 파일을 열기 전에 이것을 먼저 돌린다.
-- ------------------------------------------------------------
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
    select string_agg(v.note, ' ' order by v.kind)
      into v_notes
    from slda.verdict(p_ref) v where v.action = 'purge';

    perform slda.reject(p_ref, 'privacy', v_notes);
    return 'purge — 즉시 파기 대상으로 표시했습니다. purge 함수를 호출하면 파일이 삭제됩니다.';

  elsif v_act = 'review' then
    return 'review — 사람이 확인해야 합니다.  select * from slda.verdict(''' || p_ref || ''');';

  else
    insert into slda.status_log (ref, status) values (p_ref, '분석 가능');
    return 'pass — 비식별 처리가 확인되었습니다. 분석 가능으로 기록했습니다.';
  end if;
end;
$$;


-- ------------------------------------------------------------
-- 대기 중인 건 일괄 판정
-- ------------------------------------------------------------
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