-- ============================================================
-- 20260715000005_email.sql
-- 이메일 검출
--
--   도메인은 남겨도 된다. 식별자는 @ 앞(로컬파트)이다.
--     nanyo****@gmail.com  → 통과
--     nanyoung@gmail.com   → 검출
--
--   로컬파트가 5자 이하면 통과. 마스킹할 것이 없다.
--     abc@gmail.com  → 통과
-- ============================================================

do $$ begin
  alter type slda.pii_kind add value if not exists 'email';
exception when others then null;
end $$;


-- ════════════════════════════════════════════════════════════
-- 이메일 — 로컬파트 6자 이상 + * 없음
-- ════════════════════════════════════════════════════════════
create or replace function slda.scan_email(p_text text)
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

    -- 이미 마스킹됨
    continue when v_local ~ '\*';
    -- 5자 이하는 마스킹 대상이 아니다
    continue when length(v_local) <= 5;

    hit := v_local || '@' || v_domain;
    ctx := left(v_local, 5) || repeat('*', length(v_local) - 5) || '@' || v_domain;
    return next;
  end loop;
end;
$$;


-- ════════════════════════════════════════════════════════════
-- scan_pii 교체 — email 추가
-- ════════════════════════════════════════════════════════════
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
  select 'biz_no'::slda.pii_kind, b, null::text from slda.scan_biz_no(p_text) as b
  union all
  select 'sns_id'::slda.pii_kind, s.hit, s.ctx from slda.scan_sns_id(p_text) as s
  union all
  select 'email'::slda.pii_kind, e.hit, e.ctx from slda.scan_email(p_text) as e;
$$;


-- ════════════════════════════════════════════════════════════
-- 판정
--   본인 이메일은 연락처란에 적는다. 본문에 있으면 제3자일 가능성.
-- ════════════════════════════════════════════════════════════
insert into slda.pii_policy (kind, role, action, note) values
  ('email','party',  'review','이메일 주소가 본문에 있습니다. 본인 주소는 연락처란에 적어주세요.'),
  ('email','agent',  'purge','제3자의 이메일 주소가 처리되지 않았습니다. @ 앞 5자만 남기고 마스킹해야 합니다. 도메인은 그대로 두어도 됩니다.'),
  ('email','unknown','purge','이메일 주소가 처리되지 않았습니다. @ 앞 5자만 남기고 마스킹해야 합니다.')
on conflict (kind, role) do update
  set action = excluded.action, note = excluded.note;


-- ════════════════════════════════════════════════════════════
-- sns_id 가 이메일을 중복으로 잡지 않게
--   "인스타그램 문의는 abc@gmail.com" 같은 줄에서
--   @handle 패턴이 이메일 로컬파트를 잡을 수 있다.
-- ════════════════════════════════════════════════════════════
create or replace function slda.scan_sns_id(p_text text)
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

    -- ② 따옴표 안의 계정명
    for v_hit in
      select m[1] from regexp_matches(v_line, '[''"“”‘’]([A-Za-z0-9가-힣._\-]{6,40})[''"“”‘’]', 'g') as m
    loop
      continue when v_hit ~ '\*';
      continue when v_hit ~* v_pat;
      continue when v_hit ~ '@';
      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;

    -- ③ 플랫폼명 뒤 40자 이내의 영문 토큰 — 이메일 일부는 제외
    for v_hit in
      select m[1]
      from regexp_matches(v_line, v_pat || '[^A-Za-z0-9\*\n]{0,40}\m([A-Za-z][A-Za-z0-9._\-]{5,39})\M', 'g') as m
    loop
      continue when v_hit ~ '\*';
      continue when v_hit ~* v_pat;
      -- 같은 줄에 이 토큰이 이메일의 일부로 나타나면 제외
      continue when v_line ~ (v_hit || '@') or v_line ~ ('@' || v_hit);
      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;
  end loop;
end;
$$;