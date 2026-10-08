-- slda-skills /run 결과 저장. public 트랙 전용(개인정보 없음). → homepage/supabase/migrations/ 로 복사 후 SQL Editor 실행
create table if not exists slda_runs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  mod text not null, data_class text not null default 'public',
  "order" text[] not null, rubrics text[] not null, verdict_mode text not null, dispatch_version text,
  model text, input_sha256 text not null, input_bytes int, output text, usage jsonb, ms int,
  caller text, label text
);
create index if not exists slda_runs_mod_created on slda_runs(mod, created_at desc);
alter table slda_runs enable row level security;   -- anon 접근 0. 함수(service-role)만 쓰고, 프론트는 자기 서버 경유로 읽는다.
