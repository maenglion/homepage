-- ============================================================
-- SLDA 파이프라인 마이그레이션 정리 (SPEC §11.4)
--
-- 미수령 원칙(§0): 원문·실명이 서버로 전송되는 경로를 제거한다.
--   · prepare_text  — 서버 마스킹. 원문이 함수로 전송됨 → 미수령 위반 → 제거.
--   · pii_dict_stats — 서버 사전 통계. 전처리가 클라이언트로 이관되어 불필요 → 제거.
--
-- 전처리(마스킹·라벨화)는 사용자 AI가 수행한다(§7 프롬프트).
-- 접수는 create_pipeline_submission(20260721000000)만 사용한다.
--
-- storage 버킷 slda-uploads(원문 업로드)는 더 이상 쓰이지 않는다.
-- 기존 접수분 열람/파기를 위해 버킷 자체는 남기되, 신규 업로드 정책만 제거한다.
-- ============================================================

-- 1. 서버 마스킹 RPC 제거 (원문 전송 경로 차단)
drop function if exists public.prepare_text(text, text);

-- 2. 서버 PII 사전 통계 제거
drop function if exists public.pii_dict_stats();

-- 3. 원문 업로드 정책 제거 — 신규 파일 원문 수령 중단.
--    (버킷은 유지: 과거 접수분의 관리자 열람·파기 경로 보존)
drop policy if exists "upload into own ref folder" on storage.objects;

-- create_submission(구 폼: p_story/p_page_est/p_role)은 더 이상 호출되지 않는다.
-- 하위호환을 위해 남겨두되, 파이프라인 쓰기 경로는 create_pipeline_submission 뿐이다.
