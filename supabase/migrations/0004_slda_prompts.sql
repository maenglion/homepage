-- =====================================================================
-- SLDA §14.4 — 프롬프트 저장소 (엄격 모드)
-- 프롬프트 본문을 코드(함수 소스·번들)에서 완전히 분리한다. 레포가 public 이라
-- 함수 소스도 노출되므로, 프롬프트는 이 테이블에만 두고 함수가 service-role 로 읽는다.
--
-- ⚠️ 본문은 이 마이그레이션에 넣지 않는다(스키마만). 운영자가 SQL Editor 에서 직접 INSERT.
--    예) insert into slda_prompts(model, version, body, active)
--        values ('sns', 'v1', '<1단 단순화판 프롬프트>', true);
--
-- RLS 전면 잠금(anon select 불가). 모델당 active 는 하나만.
-- 안전: IF NOT EXISTS 로 멱등. --include-all 로 적용.
-- =====================================================================
create table if not exists slda_prompts (
  model       slda_model  not null,
  version     text        not null,
  body        text        not null,
  active      boolean     not null default false,
  updated_at  timestamptz not null default now(),
  primary key (model, version)
);

-- 모델당 active=true 는 최대 1개
create unique index if not exists one_active_prompt_per_model
  on slda_prompts(model) where active;

alter table slda_prompts enable row level security;
drop policy if exists prompts_none on slda_prompts;
create policy prompts_none on slda_prompts for select using (false);
