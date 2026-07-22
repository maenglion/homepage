-- =====================================================================
-- SLDA §14.4 — 프롬프트 발급 세션
-- 플로우 시작 시 짧은 수명의 세션 토큰을 발급하고, slda-issue-prompt 는
-- 유효 세션 토큰이 있어야만 1단 프롬프트를 내준다(봇·스크래퍼 차단, 정상 유저만 수령).
-- 토큰은 실명·개인정보와 무관한 난수. RLS 로 anon 직접 접근 차단(함수는 service-role 경유).
-- 안전: IF NOT EXISTS / OR REPLACE 로 멱등. --include-all 로 적용.
-- =====================================================================
create table if not exists slda_sessions (
  token       text primary key,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default (now() + interval '6 hours')
);
create index if not exists idx_sessions_expires on slda_sessions(expires_at);

alter table slda_sessions enable row level security;
drop policy if exists sessions_none on slda_sessions;
create policy sessions_none on slda_sessions for select using (false);

-- 자동파기에 만료 세션 정리를 합류(0001 본문 + 세션 정리 1줄)
create or replace function slda_purge_expired()
returns void language plpgsql security definer as $$
declare r record;
begin
  for r in select ref from slda_reports where purge_at < now() loop
    insert into slda_reject_log(ref, code) values (r.ref, '보관만료');
  end loop;
  delete from slda_reports where purge_at < now();
  update slda_submissions set block_b = null, block_c = null
   where status = 'done' and (block_b is not null or block_c is not null)
     and updated_at < now() - interval '14 days';
  delete from slda_sessions where expires_at < now();
end $$;
