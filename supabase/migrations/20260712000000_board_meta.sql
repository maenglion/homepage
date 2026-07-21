-- ============================================================
-- 20260712000000_board_meta.sql
-- 게시판 조회수 + 공지
-- ============================================================

-- 조회수 · 공지를 담을 단일 행 테이블
create table if not exists slda.board_meta (
  id         int primary key default 1,
  views      bigint not null default 0,
  notice     text,
  updated_at timestamptz not null default now(),
  constraint one_row check (id = 1)
);

insert into slda.board_meta (id, views, notice)
values (1, 0, '첫 번째 분석 케이스를 받고 있습니다. 접수된 자료는 학습에 쓰이지 않으며, 분석 종료 후 파기됩니다. 파기 기록은 예약 작업이 자동으로 남깁니다.')
on conflict (id) do nothing;

-- 조회수 +1 하고 현재 메타 반환
create or replace function public.bump_board_views()
returns table (views bigint, notice text)
language plpgsql
security definer
set search_path = slda, pg_temp
as $$
begin
  update slda.board_meta set views = views + 1, updated_at = now() where id = 1;
  return query select m.views, m.notice from slda.board_meta m where m.id = 1;
end;
$$;

revoke all on function public.bump_board_views() from public;
grant execute on function public.bump_board_views() to anon;