-- ============================================================
-- 20260715000000_purge_14days.sql
-- 분석 완료 후 파기 기간 30일 → 14일
-- ============================================================

create or replace function slda.complete(p_ref text)
returns void
language plpgsql
as $$
begin
  update slda.submissions set purge_after = now() + interval '14 days' where ref = p_ref;
  insert into slda.status_log (ref, status, note)
  values (p_ref, '분석 완료', to_char(now() + interval '14 days', 'YYYY-MM-DD') || ' 파기 예정');
end;
$$;