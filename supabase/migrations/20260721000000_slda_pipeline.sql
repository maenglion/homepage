-- ============================================================
-- SLDA 신청 파이프라인 데이터 모델 (SPEC §8)
--
-- 미수령 원칙: 실명·원문·엔티티 매핑(BLOCK A)은 저장하지 않는다.
--   서버가 수령하는 것은 라벨화된 BLOCK B·C 뿐이다.
--   BLOCK A 는 어떤 테이블에도 저장하지 않는다.
--
-- 기존 slda 스키마(20260710000000_slda_intake.sql)와 공존한다.
-- 파이프라인 전용 테이블은 pl_ 접두사를 쓴다.
-- ============================================================

create schema if not exists slda;

-- ---------------------------------------------------------------
-- 1. 타입
-- ---------------------------------------------------------------
do $$ begin
  create type slda.pl_model as enum ('lit', 'sns', 'spk');
exception when duplicate_object then null; end $$;

do $$ begin
  create type slda.pl_status as enum ('received', 'analyzing', 'done', 'rejected');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------
-- 2. 접수번호 시퀀스 — {MODEL}-{YYMMDD}-{SEQ4}
-- ---------------------------------------------------------------
create table if not exists slda.pl_seq (
  day    text not null,
  model  slda.pl_model not null,
  n      int  not null default 0,
  primary key (day, model)
);

create or replace function slda.pl_next_ref(p_model slda.pl_model)
returns text
language plpgsql
as $$
declare
  v_day  text := to_char(now() at time zone 'Asia/Seoul', 'YYMMDD');
  v_code text := upper(p_model::text);
  v_n    int;
begin
  insert into slda.pl_seq (day, model, n)
  values (v_day, p_model, 1)
  on conflict (day, model) do update set n = slda.pl_seq.n + 1
  returning n into v_n;

  return v_code || '-' || v_day || '-' || lpad(v_n::text, 4, '0');
end;
$$;

-- ---------------------------------------------------------------
-- 3. 테이블
-- ---------------------------------------------------------------
create table if not exists slda.pl_submissions (
  ref             text primary key,
  model           slda.pl_model not null,
  status          slda.pl_status not null default 'received',
  stance          text,                       -- LIT 입장 (원고·피고·소외인N) / SNS·SPK 는 전체
  block_b         text,                       -- 라벨화 본문 (파기 시 삭제)
  block_c         text,                       -- 익명 요약 원본 (파기 시 삭제)
  block_c_parsed  jsonb,                       -- 파싱 결과 (실명 0)
  created_at      timestamptz not null default now()
);

create index if not exists pl_submissions_status_idx on slda.pl_submissions (status);

-- 파기 로그 — 접수번호 + 사유코드 + 시각. 실명·값 없음.
-- 클라이언트 2차 방어 반려(제출 이전)도 기록할 수 있도록 FK 를 걸지 않는다.
create table if not exists slda.pl_reject_log (
  id           bigint generated always as identity primary key,
  ref          text not null,
  code         text not null,
  rejected_at  timestamptz not null default now()
);

create index if not exists pl_reject_ref_idx on slda.pl_reject_log (ref);

-- 산출물 — 파일명(§6) · URL · 게시/파기 시각
create table if not exists slda.pl_reports (
  id            bigint generated always as identity primary key,
  ref           text not null references slda.pl_submissions(ref) on delete cascade,
  filename      text not null,
  file_url      text,
  published_at  timestamptz not null default now(),
  purge_at      timestamptz not null default now() + interval '14 days'
);

create index if not exists pl_reports_purge_idx on slda.pl_reports (purge_at);
create index if not exists pl_reports_ref_idx on slda.pl_reports (ref);

-- ---------------------------------------------------------------
-- 4. RLS — 정책 없음 = 전부 차단. service_role 만 우회.
-- ---------------------------------------------------------------
alter table slda.pl_submissions enable row level security;
alter table slda.pl_reject_log  enable row level security;
alter table slda.pl_reports     enable row level security;
alter table slda.pl_submissions force row level security;
alter table slda.pl_reject_log  force row level security;
alter table slda.pl_reports     force row level security;

-- ---------------------------------------------------------------
-- 5. 접수 — 유일한 쓰기 경로. ref 는 서버가 만든다.
--    실명은 전송되지 않는다(클라이언트가 라벨화 후 BLOCK B·C 만 보냄).
-- ---------------------------------------------------------------
create or replace function public.create_pipeline_submission(
  p_model          text,
  p_stance         text default null,
  p_block_b        text default '',
  p_block_c        text default '',
  p_block_c_parsed jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = slda, pg_temp
as $$
declare
  v_model slda.pl_model;
  v_ref   text;
begin
  if p_model not in ('lit', 'sns', 'spk') then
    raise exception '잘못된 모델입니다';
  end if;
  v_model := p_model::slda.pl_model;

  v_ref := slda.pl_next_ref(v_model);

  insert into slda.pl_submissions (ref, model, status, stance, block_b, block_c, block_c_parsed)
  values (v_ref, v_model, 'received', nullif(trim(p_stance), ''),
          left(coalesce(p_block_b, ''), 2000000),
          left(coalesce(p_block_c, ''), 200000),
          coalesce(p_block_c_parsed, '{}'::jsonb));

  return v_ref;
end;
$$;

-- ---------------------------------------------------------------
-- 6. 파기 로그 — 클라이언트 2차 방어 반려 기록 (실명 0)
-- ---------------------------------------------------------------
create or replace function public.log_pipeline_reject(
  p_model text,
  p_ref   text,
  p_code  text
)
returns void
language plpgsql
security definer
set search_path = slda, pg_temp
as $$
begin
  if p_ref is null or p_code is null then return; end if;
  insert into slda.pl_reject_log (ref, code)
  values (upper(trim(p_ref)), left(p_code, 60));
end;
$$;

-- ---------------------------------------------------------------
-- 7. 조회 — 접수번호를 아는 사람만. 상태 4종 + 산출물 + 사유코드.
--    block_b/block_c(원문)는 절대 반환하지 않는다.
-- ---------------------------------------------------------------
create or replace function public.get_pipeline_status(p_ref text)
returns table (
  status       text,
  model        text,
  code         text,
  rejected_at  timestamptz,
  reports      jsonb
)
language sql
security definer
stable
set search_path = slda, pg_temp
as $$
  with s as (
    select * from slda.pl_submissions where ref = upper(trim(p_ref))
  ),
  rej as (
    select code, rejected_at
    from slda.pl_reject_log
    where ref = upper(trim(p_ref))
    order by rejected_at desc
    limit 1
  ),
  rep as (
    select coalesce(jsonb_agg(
             jsonb_build_object('filename', filename, 'url', file_url, 'purge_at', purge_at)
             order by published_at
           ), '[]'::jsonb) as reports
    from slda.pl_reports
    where ref = upper(trim(p_ref))
  )
  select
    coalesce(s.status::text,
             case when rej.code is not null then 'rejected' else null end) as status,
    s.model::text as model,
    rej.code as code,
    rej.rejected_at as rejected_at,
    rep.reports as reports
  from rep
  left join s on true
  left join rej on true
  where s.ref is not null or rej.code is not null;
$$;

-- ---------------------------------------------------------------
-- 8. 자동 파기 — reports.purge_at < now() → 파일·행 삭제 + 보관만료 기록
--    (SPEC §8) block_b/block_c 도 함께 삭제. 원문 미보존.
--    service_role(Edge Function/pg_cron)이 호출한다.
-- ---------------------------------------------------------------
create or replace function slda.pl_purge_due()
returns int
language plpgsql
as $$
declare
  r record;
  v_count int := 0;
begin
  for r in
    select distinct ref from slda.pl_reports where purge_at <= now()
  loop
    delete from slda.pl_reports where ref = r.ref and purge_at <= now();
    update slda.pl_submissions
       set block_b = null, block_c = null, status = 'rejected'
     where ref = r.ref;
    insert into slda.pl_reject_log (ref, code) values (r.ref, '보관만료');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------
-- 9. 권한 — anon 은 함수 3개만. 테이블 권한 0.
-- ---------------------------------------------------------------
revoke all on function public.create_pipeline_submission(text, text, text, text, jsonb) from public;
revoke all on function public.log_pipeline_reject(text, text, text) from public;
revoke all on function public.get_pipeline_status(text) from public;

grant execute on function public.create_pipeline_submission(text, text, text, text, jsonb) to anon;
grant execute on function public.log_pipeline_reject(text, text, text) to anon;
grant execute on function public.get_pipeline_status(text) to anon;
