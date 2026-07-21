-- ============================================================
-- SLDA 접수번호 → 64비트 난수 조회키 (SPEC §8)
--
-- 순번 포맷({MODEL}-{YYMMDD}-{SEQ4})은 익명 접수에서 위험하다:
-- 접수번호가 유일 인증수단인데 순번이면 인접 접수를 추측·열람할 수 있다.
-- → 조회 키를 64비트 난수(추측 불가)로 교체한다.
--   표시 = 모델 접두어 + 난수 16 hex. 예: LIT-a3f9c2e1b4d5f6a7
--
-- pl_next_ref 시그니처를 유지하므로 create_pipeline_submission 은 그대로 동작한다.
-- pl_seq 테이블은 더 이상 쓰이지 않으나(하위호환) 남겨둔다.
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

create or replace function slda.pl_next_ref(p_model slda.pl_model)
returns text
language sql
volatile
as $$
  select upper(p_model::text) || '-' || encode(extensions.gen_random_bytes(8), 'hex');
$$;
