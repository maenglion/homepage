-- ============================================================
-- 20260715000004_mask.sql
-- 자동 마스킹
--
--   브라우저가 텍스트 파일을 읽어 public.prepare_text() 를 호출한다.
--   마스킹된 사본만 업로드된다. 원본은 저장되지 않는다.
--
--   마스킹 규칙 (자릿수 유지)
--     주민등록번호  앞 7자리만    900101-1234567    → 900101-1******
--     사건번호      앞 5자리만    2024가합206528    → 2024가합2*****
--     성명          마지막 글자   홍길동            → 홍길*
--     휴대폰        앞 3자리만    010-1234-5678     → 010-****-****
--     계좌번호      앞 5자리만    123456-01-234567  → 12345*-**-******
--     사업자번호    앞 5자리만    123-45-67890      → 123-45-*****
--     SNS 계정      앞 5자만      @nanyoung_official→ @nanyo***********
--     이메일        @ 앞 5자만    nanyoung@gmail.com→ nanyo***@gmail.com
--
--   당사자 본인이 제출한 자기 사건번호만 예외로 남긴다.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. 마스킹 도구
-- ════════════════════════════════════════════════════════════

-- ── 숫자만 세어 앞 n개를 남기고 나머지를 * 로 ──
--   구분자(- 공백)는 그대로 둔다. 자릿수가 유지된다.
create or replace function slda.mask_digits(p_s text, p_keep int)
returns text
language plpgsql immutable
as $$
declare
  v_out text := '';
  v_ch  text;
  v_n   int := 0;
  i     int;
begin
  for i in 1..length(p_s) loop
    v_ch := substr(p_s, i, 1);
    if v_ch ~ '\d' then
      v_n := v_n + 1;
      v_out := v_out || case when v_n <= p_keep then v_ch else '*' end;
    else
      v_out := v_out || v_ch;
    end if;
  end loop;
  return v_out;
end;
$$;

-- ── 앞 n자를 남기고 나머지를 * 로 ──
create or replace function slda.mask_tail(p_s text, p_keep int)
returns text
language sql immutable
as $$
  select case
    when length(p_s) <= p_keep then p_s
    else left(p_s, p_keep) || repeat('*', length(p_s) - p_keep)
  end;
$$;


-- ════════════════════════════════════════════════════════════
-- 2. 마스킹
--   긴 패턴부터 치환한다. 부분 치환으로 다른 패턴이 깨지지 않게.
-- ════════════════════════════════════════════════════════════
create or replace function slda.mask_text(p_text text, p_role text default 'unknown')
returns table (masked text, n int)
language plpgsql stable
as $$
declare
  v_out  text := p_text;
  v_hit  text;
  v_n    int := 0;
  v_role text := case when p_role in ('party','agent') then p_role else 'unknown' end;
  v_loc  text;
  v_dom  text;
  v_at   int;
begin
  -- ① 주민등록번호 — 앞 7자리(생년월일 6 + 성별 1)
  for v_hit in select distinct h from slda.scan_rin(p_text) h loop
    v_out := replace(v_out, v_hit, slda.mask_digits(v_hit, 7));
    v_n := v_n + 1;
  end loop;

  -- ② 계좌번호 — 앞 5자리
  for v_hit in select distinct a.hit from slda.scan_account(p_text) a loop
    v_out := replace(v_out, v_hit, slda.mask_digits(v_hit, 5));
    v_n := v_n + 1;
  end loop;

  -- ③ 사업자등록번호 — 앞 5자리
  for v_hit in select distinct b from slda.scan_biz_no(p_text) b loop
    v_out := replace(v_out, v_hit, slda.mask_digits(v_hit, 5));
    v_n := v_n + 1;
  end loop;

  -- ④ 휴대폰 — 앞 3자리
  for v_hit in
    select distinct m[1] from regexp_matches(p_text, '(\m01[016789][-\s]?\d{3,4}[-\s]?\d{4}\M)', 'g') as m
  loop
    v_out := replace(v_out, v_hit, slda.mask_digits(v_hit, 3));
    v_n := v_n + 1;
  end loop;

  -- ⑤ 이메일 — @ 앞 5자. 도메인은 남긴다.
  for v_hit in select distinct e.hit from slda.scan_email(p_text) e loop
    v_at  := position('@' in v_hit);
    v_loc := left(v_hit, v_at - 1);
    v_dom := substr(v_hit, v_at);
    v_out := replace(v_out, v_hit, slda.mask_tail(v_loc, 5) || v_dom);
    v_n := v_n + 1;
  end loop;

  -- ⑥ SNS 계정 — 앞 5자
  for v_hit in select distinct s.hit from slda.scan_sns_id(p_text) s loop
    if left(v_hit, 1) = '@' then
      v_out := replace(v_out, v_hit, '@' || slda.mask_tail(substr(v_hit, 2), 5));
    else
      v_out := replace(v_out, v_hit, slda.mask_tail(v_hit, 5));
    end if;
    v_n := v_n + 1;
  end loop;

  -- ⑦ 사건번호 — 앞 5자리. 당사자 본인은 예외.
  if v_role <> 'party' then
    for v_hit in select distinct c from slda.scan_case_no(p_text) c loop
      v_out := replace(v_out, v_hit, slda.mask_digits(v_hit, 5));
      v_n := v_n + 1;
    end loop;
  end if;

  -- ⑧ 성명 — 마지막 글자. 같은 이름은 같은 표기가 된다.
  for v_hit in select distinct nc.hit from slda.scan_name_ctx(p_text) nc loop
    v_out := replace(v_out, v_hit, slda.mask_tail(v_hit, length(v_hit) - 1));
    v_n := v_n + 1;
  end loop;

  masked := v_out;
  n := v_n;
  return next;
end;
$$;


-- ════════════════════════════════════════════════════════════
-- 3. 브라우저용 RPC
--   텍스트를 받아 마스킹본과 내역을 돌려준다.
--   저장하지 않는다. stable 함수이므로 쓰기 자체가 불가능하다.
-- ════════════════════════════════════════════════════════════
create or replace function public.prepare_text(
  p_text text,
  p_role text default 'unknown'
)
returns table (
  masked   text,
  n_masked int,
  findings jsonb
)
language plpgsql
security definer
stable
set search_path = slda, pg_temp
as $$
declare
  v_text text := left(p_text, 2000000);
  v_role text := case when p_role in ('party','agent') then p_role else 'unknown' end;
begin
  select m.masked, m.n into masked, n_masked
  from slda.mask_text(v_text, v_role) m;

  select coalesce(jsonb_agg(x order by x->>'kind'), '[]'::jsonb) into findings
  from (
    select jsonb_build_object(
             'kind',   f.kind::text,
             'label',  case f.kind
                         when 'rin'      then '주민등록번호'
                         when 'case_no'  then '사건번호'
                         when 'name_ctx' then '성명'
                         when 'phone'    then '휴대폰 번호'
                         when 'account'  then '계좌번호'
                         when 'biz_no'   then '사업자등록번호'
                         when 'sns_id'   then 'SNS 계정명'
                         when 'email'    then '이메일'
                       end,
             'n',      count(*),
             'kept',   case f.kind
                         when 'rin'      then '앞 7자리'
                         when 'case_no'  then '앞 5자리'
                         when 'name_ctx' then '마지막 글자'
                         when 'phone'    then '앞 3자리'
                         when 'account'  then '앞 5자리'
                         when 'biz_no'   then '앞 5자리'
                         when 'sns_id'   then '앞 5자'
                         when 'email'    then '@ 앞 5자'
                       end
           ) as x
    from slda.scan_pii(v_text) f
    where not (f.kind = 'case_no' and v_role = 'party')
    group by f.kind
  ) t;

  return next;
end;
$$;

revoke all on function public.prepare_text(text, text) from public;
grant execute on function public.prepare_text(text, text) to anon;