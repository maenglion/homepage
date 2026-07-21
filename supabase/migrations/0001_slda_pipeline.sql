-- =====================================================================
-- SLDA 신청 파이프라인 마이그레이션 (SPEC §8 · §11.4 · §14 · §15)
-- 안전 원칙: 기존 DB를 깨지 않는다. IF NOT EXISTS / OR REPLACE 위주.
-- 접수번호 = 64비트 난수 조회키 + 표시용 모델 접두어 (순번 금지)
-- 실명·엔티티 매핑(BLOCK A)은 어떤 테이블에도 저장하지 않는다.
-- =====================================================================

-- 확장: 자동파기 스케줄용
create extension if not exists pg_cron;
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. ENUM
-- ---------------------------------------------------------------------
do $$ begin
  create type slda_model as enum ('lit','sns','spk');
exception when duplicate_object then null; end $$;

do $$ begin
  create type slda_status as enum ('received','analyzing','done','rejected');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. 접수번호 생성 (64비트 난수 + 모델 접두어)
--    표시 예: LIT-a3f9c2e1d5b7f0a2
-- ---------------------------------------------------------------------
create or replace function slda_gen_ref(p_model slda_model)
returns text language plpgsql as $$
declare
  prefix text := upper(p_model::text);
  token  text;
begin
  -- 64비트(8바이트) 난수 → 16자리 hex
  token := encode(gen_random_bytes(8), 'hex');
  return prefix || '-' || token;
end $$;

-- ---------------------------------------------------------------------
-- 3. submissions
-- ---------------------------------------------------------------------
create table if not exists slda_submissions (
  ref             text primary key,
  model           slda_model  not null,
  status          slda_status not null default 'received',
  stance          text,                       -- LIT 입장(원고/피고/소외인). 그 외 null
  block_b         text,                       -- 라벨화 본문 (파기 시 삭제)
  block_c         text,                       -- 익명 요약 원본 (파기 시 삭제)
  block_c_parsed  jsonb,                       -- 파싱 메타 (실명 0)
  title           text,
  title_public    boolean not null default false,
  nickname        text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- 기존 테이블이 있을 경우 필요한 컬럼만 보강 (구버전 → 신버전)
alter table slda_submissions add column if not exists model          slda_model;
alter table slda_submissions add column if not exists status         slda_status default 'received';
alter table slda_submissions add column if not exists stance         text;
alter table slda_submissions add column if not exists block_b        text;
alter table slda_submissions add column if not exists block_c        text;
alter table slda_submissions add column if not exists block_c_parsed jsonb;
alter table slda_submissions add column if not exists nickname       text;
alter table slda_submissions add column if not exists updated_at     timestamptz default now();

-- ---------------------------------------------------------------------
-- 4. reject_log (실명·값 없음. 파기 사실만)
-- ---------------------------------------------------------------------
create table if not exists slda_reject_log (
  id          bigint generated always as identity primary key,
  ref         text not null,
  code        text not null,          -- §5 파기 사유코드
  rejected_at timestamptz not null default now()
);
create index if not exists idx_reject_ref on slda_reject_log(ref);

-- ---------------------------------------------------------------------
-- 5. reports (완료 보고서 · purge_at = published + 14d)
-- ---------------------------------------------------------------------
create table if not exists slda_reports (
  id           bigint generated always as identity primary key,
  ref          text not null,
  filename     text not null,         -- §6 파일명 규칙
  file_url     text,
  published_at timestamptz not null default now(),
  purge_at     timestamptz not null default (now() + interval '14 days')
);
create index if not exists idx_reports_ref  on slda_reports(ref);
create index if not exists idx_reports_purge on slda_reports(purge_at);

-- ---------------------------------------------------------------------
-- 6. 정규화 원장 (§14.2 · SNS/SPK 오타 주석 결정적 재사용)
--    원문 교체 아님 — 주석만. 최초 1회 산출 후 재사용.
-- ---------------------------------------------------------------------
create table if not exists slda_norm_ledger (
  id          bigint generated always as identity primary key,
  ref         text not null,
  surface     text not null,          -- 원문 표기 (예: 그korea)
  normalized  text not null,          -- 해석 주석 (예: 그러니까)
  created_at  timestamptz not null default now(),
  unique (ref, surface)
);
create index if not exists idx_norm_ref on slda_norm_ledger(ref);

-- ---------------------------------------------------------------------
-- 7. create_submission (§11.4 인자 교체본)
--    기존 p_story/p_page_est/p_role 제거 · p_model/p_block_*/p_stance 추가
-- ---------------------------------------------------------------------
create or replace function create_submission(
  p_model          slda_model,
  p_block_b        text,
  p_block_c        text,
  p_block_c_parsed jsonb,
  p_stance         text default null,
  p_title          text default null,
  p_title_public   boolean default false,
  p_nickname       text default null
) returns table(ref text, nickname text)
language plpgsql security definer as $$
declare
  v_ref  text;
  v_nick text;
begin
  v_ref  := slda_gen_ref(p_model);
  v_nick := coalesce(p_nickname, 'user-' || substr(encode(gen_random_bytes(3),'hex'),1,6));

  insert into slda_submissions(ref, model, status, stance, block_b, block_c, block_c_parsed, title, title_public, nickname)
  values (v_ref, p_model, 'received', p_stance, p_block_b, p_block_c, p_block_c_parsed, p_title, p_title_public, v_nick);

  return query select v_ref, v_nick;
end $$;

-- ---------------------------------------------------------------------
-- 8. 파기 (파기 + 로깅 한 트랜잭션 · block_b/c 즉시 삭제)
-- ---------------------------------------------------------------------
create or replace function slda_reject(p_ref text, p_code text)
returns void language plpgsql security definer as $$
begin
  update slda_submissions
     set status = 'rejected', block_b = null, block_c = null, updated_at = now()
   where ref = p_ref;
  insert into slda_reject_log(ref, code) values (p_ref, p_code);
end $$;

-- ---------------------------------------------------------------------
-- 9. 자동파기 (매일 03:00 KST=18:00 UTC · purge_at 경과분)
-- ---------------------------------------------------------------------
create or replace function slda_purge_expired()
returns void language plpgsql security definer as $$
declare r record;
begin
  for r in select ref from slda_reports where purge_at < now() loop
    insert into slda_reject_log(ref, code) values (r.ref, '보관만료');
  end loop;
  delete from slda_reports where purge_at < now();
  -- 완료 후 원문 잔재 정리(이미 done이면 block 비움)
  update slda_submissions set block_b = null, block_c = null
   where status = 'done' and (block_b is not null or block_c is not null)
     and updated_at < now() - interval '14 days';
end $$;

-- cron 등록 (중복 방지: 먼저 unschedule 시도)
do $$ begin
  perform cron.unschedule('slda_purge');
exception when others then null; end $$;
select cron.schedule('slda_purge', '0 18 * * *', $$select slda_purge_expired();$$);

-- ---------------------------------------------------------------------
-- 10. RLS
--    익명 접수 모델: 조회는 접수번호(난수)를 아는 사람만. 쓰기는 RPC(security definer)로만.
-- ---------------------------------------------------------------------
alter table slda_submissions enable row level security;
alter table slda_reject_log  enable row level security;
alter table slda_reports     enable row level security;
alter table slda_norm_ledger enable row level security;

-- 게시판 노출용: title_public 이거나 상태 배지 정도만 공개 (실명 없음)
drop policy if exists board_read on slda_submissions;
create policy board_read on slda_submissions
  for select using (true);
  -- 주: 애플리케이션은 list_board RPC로 공개 필드만 노출. 원문 컬럼은 select 안 함.
  -- 원문(block_b/c) 보호는 뷰/RPC 계층에서 컬럼 제한으로 처리.

-- reports/reject_log: 접수번호로만 조회 (anon 직접 select 차단, RPC 경유)
drop policy if exists reports_none on slda_reports;
create policy reports_none on slda_reports for select using (false);

drop policy if exists reject_none on slda_reject_log;
create policy reject_none on slda_reject_log for select using (false);

drop policy if exists norm_none on slda_norm_ledger;
create policy norm_none on slda_norm_ledger for select using (false);

-- 접수번호로 상태·보고서 조회 (RPC · 난수를 아는 사람만 결과 얻음)
create or replace function slda_status_lookup(p_ref text)
returns jsonb language plpgsql security definer as $$
declare
  v_sub  slda_submissions;
  v_reps jsonb;
  v_code text;
begin
  select * into v_sub from slda_submissions where ref = p_ref;
  if not found then
    return jsonb_build_object('found', false);
  end if;

  if v_sub.status = 'rejected' then
    select code into v_code from slda_reject_log where ref = p_ref order by rejected_at desc limit 1;
    return jsonb_build_object('found', true, 'status', v_sub.status, 'reject_code', v_code);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'filename', filename, 'file_url', file_url, 'purge_at', purge_at)), '[]'::jsonb)
    into v_reps from slda_reports where ref = p_ref;

  return jsonb_build_object(
    'found', true, 'status', v_sub.status, 'model', v_sub.model,
    'created_at', v_sub.created_at, 'reports', v_reps);
end $$;

-- ---------------------------------------------------------------------
-- 11. 제거 대상 (구버전 · 미수령 위반)
--     prepare_text / pii_dict_stats 는 서버 마스킹이라 제거한다.
--     존재하지 않아도 에러 안 나게 IF EXISTS.
-- ---------------------------------------------------------------------
drop function if exists prepare_text(text, text);
drop function if exists pii_dict_stats();

-- 주: storage 버킷 slda-uploads(원문 업로드)는 대시보드 Storage에서 수동 제거.
-- 주: Edge Function(프롬프트 발급 · 2단 정규화)은 SQL 아님 → supabase functions deploy 로 별도.

-- =====================================================================
-- 끝. Edge Function 2종은 supabase/functions/ 에 TypeScript로 별도 배포.
-- =====================================================================
