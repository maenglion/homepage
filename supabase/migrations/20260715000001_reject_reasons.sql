-- ============================================================
-- 20260715000001_reject_reasons.sql
-- 반려 사유 코드. 사유가 신청자에게 그대로 보인다.
-- ============================================================

-- 사유 코드 → 표시 문구
create table if not exists slda.reject_reasons (
  code    text primary key,
  label   text not null,
  detail  text not null,
  instant boolean not null default false   -- true = 즉시 파기
);

insert into slda.reject_reasons (code, label, detail, instant) values
  ('privacy',
   '개인정보 미처리',
   '제3자의 식별정보가 처리되지 않은 상태로 제출되었습니다. 자료를 열람하지 않고 즉시 파기했습니다. 처리 후 다시 신청해주세요.',
   true),
  ('private_post',
   '비공개 게시물',
   '소수만 열람할 수 있는 게시물은 분석하지 않습니다. 즉시 파기했습니다.',
   true),
  ('no_right',
   '제출 권한 불명',
   '자료를 제출할 정당한 권한이 확인되지 않았습니다. 즉시 파기했습니다.',
   true),
  ('too_few',
   '차수 부족',
   '분석에는 동일 쟁점에 대한 자료가 최소 3차수 이상 필요합니다. 제출된 자료로는 변화를 측정할 수 없습니다.',
   false),
  ('too_short',
   '분량 부족',
   '분석에 필요한 최소 분량에 미치지 못합니다. 문장 단위 측정이 통계적으로 성립하지 않습니다.',
   false),
  ('no_speaker',
   '화자 미구분',
   '누가 어떤 주장을 했는지 구분되지 않습니다. 주체귀속 분석이 불가능합니다.',
   false),
  ('off_topic',
   '쟁점 불일치',
   '제출된 자료들이 동일 쟁점을 다루지 않습니다. 차수 간 비교 대상이 성립하지 않습니다.',
   false),
  ('one_side',
   '한쪽 자료만 제출',
   '논쟁 자료는 양쪽을 함께 분석합니다. 한쪽만 분석한 결과물은 제공하지 않습니다.',
   false),
  ('unreadable',
   '판독 불가',
   '파일을 열 수 없거나 텍스트를 추출할 수 없습니다.',
   false),
  ('out_of_scope',
   '분석 범위 밖',
   'SLDA는 문서의 논점 이동과 전제충돌을 측정합니다. 제출된 자료는 그 대상이 아닙니다.',
   false)
on conflict (code) do update
  set label = excluded.label,
      detail = excluded.detail,
      instant = excluded.instant;

-- ------------------------------------------------------------
-- 반려 — 사유 코드로 호출한다.
-- instant = true 면 즉시 파기 대상이 된다.
-- ------------------------------------------------------------
drop function if exists slda.reject(text, text);

create or replace function slda.reject(p_ref text, p_code text, p_extra text default null)
returns void
language plpgsql
as $$
declare
  r slda.reject_reasons%rowtype;
  v_note text;
begin
  select * into r from slda.reject_reasons where code = p_code;
  if not found then
    raise exception '알 수 없는 사유 코드: %  (select code, label from slda.reject_reasons 로 확인)', p_code;
  end if;

  v_note := r.label || ' — ' || r.detail;
  if p_extra is not null and trim(p_extra) <> '' then
    v_note := v_note || ' ' || trim(p_extra);
  end if;

  -- 즉시 파기 사유면 지금, 아니면 7일 뒤 (재신청 문의 여유)
  update slda.submissions
    set purge_after = case when r.instant then now() else now() + interval '7 days' end
    where ref = p_ref;

  insert into slda.status_log (ref, status, note)
  values (p_ref, '분석 불가', v_note);
end;
$$;

-- 사유 목록 조회용
create or replace view slda.reject_menu as
  select code, label, instant, detail from slda.reject_reasons order by instant desc, code;