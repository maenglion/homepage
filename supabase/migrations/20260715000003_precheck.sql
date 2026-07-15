-- ============================================================
-- 20260715000003_precheck.sql
-- 제출 전 검사
--
--   브라우저가 파일을 읽어 이 함수를 호출한다.
--   검사 결과가 purge 면 업로드 자체를 하지 않는다.
--   파일이 저장소에 도달하지 않는다.
--
--   함수는 텍스트를 저장하지 않는다. 메모리에서 검사하고 결과만 반환한다.
--   stable 함수이므로 쓰기 자체가 불가능하다.
-- ============================================================

create or replace function public.check_pii(
  p_text text,
  p_role text default 'unknown'
)
returns table (
  kind   text,
  action text,
  n      bigint,
  sample text,
  fix    text,
  note   text
)
language sql
security definer
stable
set search_path = slda, pg_temp
as $$
  with lim as (
    -- 과도한 입력 차단
    select left(p_text, 2000000) as t
  ),
  r as (
    select case when p_role in ('party','agent') then p_role else 'unknown' end as role
  ),
  found as (
    select f.kind, count(*) as n, min(f.hit) as sample, min(f.ctx) as ctx
    from lim, slda.scan_pii(lim.t) f
    group by f.kind
  )
  select
    f.kind::text,
    p.action::text,
    f.n,
    f.sample,
    f.ctx,
    p.note
  from found f
  cross join r
  join slda.pii_policy p on p.kind = f.kind and p.role = r.role
  order by
    case p.action when 'purge' then 1 when 'review' then 2 else 3 end,
    f.kind;
$$;

revoke all on function public.check_pii(text, text) from public;
grant execute on function public.check_pii(text, text) to anon;


-- ------------------------------------------------------------
-- 사전 규모 — 홈페이지에 표시한다
-- ------------------------------------------------------------
create or replace function public.pii_dict_stats()
returns table (dict text, n bigint)
language sql
security definer
stable
set search_path = slda, pg_temp
as $$
  select '성씨',        count(*) from slda.surnames
  union all
  select '은행·계좌',   count(*) from slda.banks
  union all
  select 'SNS 플랫폼',  count(*) from slda.sns_platforms
  union all
  select '성명 제외어', count(*) from slda.name_stopwords
  union all
  select '검출 유형',   count(*) from unnest(enum_range(null::slda.pii_kind))
  union all
  select '판정 규칙',   count(*) from slda.pii_policy;
$$;

revoke all on function public.pii_dict_stats() from public;
grant execute on function public.pii_dict_stats() to anon;