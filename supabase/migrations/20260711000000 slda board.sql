-- ============================================================
-- 20260711000000_slda_board.sql
-- 게시판: 닉네임(형용사+동물), 제목, 공개동의, 목록 RPC
-- SQL Editor 에서 실행. create_submission 은 교체된다.
-- ============================================================

-- ------------------------------------------------------------
-- 1. 닉네임 풀 — 중립적인 것만. 소송·논쟁 중인 사람들이 본다.
-- ------------------------------------------------------------
create table if not exists slda.adjectives (word text primary key);
create table if not exists slda.animals     (word text primary key);

insert into slda.adjectives (word) values
  ('조용한'),('느긋한'),('단정한'),('꼼꼼한'),('차분한'),('신중한'),
  ('성실한'),('묵묵한'),('담담한'),('올곧은'),('한결같은'),('침착한'),
  ('부지런한'),('의젓한'),('진득한'),('나긋한')
on conflict do nothing;

insert into slda.animals (word) values
  ('수달'),('해달'),('두루미'),('오소리'),('너구리'),('다람쥐'),
  ('물범'),('펭귄'),('해오라기'),('산양'),('고슴도치'),('청설모'),
  ('물총새'),('오리'),('두더지'),('비버')
on conflict do nothing;

-- ------------------------------------------------------------
-- 2. submissions 에 컬럼 추가
-- ------------------------------------------------------------
alter table slda.submissions
  add column if not exists nickname     text unique,
  add column if not exists title        text,
  add column if not exists title_public boolean not null default false;

-- ------------------------------------------------------------
-- 3. create_submission 교체
--    제목 · 공개동의 파라미터 추가, 닉네임 자동 생성
-- ------------------------------------------------------------
drop function if exists public.create_submission(text, text, int, int, text);

create function public.create_submission(
  p_kind         text,
  p_story        text,
  p_doc_count    int,
  p_page_est     int     default null,
  p_contact      text    default null,
  p_title        text    default null,
  p_title_public boolean default false
)
returns table (ref text, nickname text)
language plpgsql
security definer
set search_path = slda, pg_temp
as $$
declare
  v_ref  text;
  v_nick text;
begin
  if p_kind not in ('litigation', 'controversy', 'general') then
    raise exception '잘못된 유형입니다';
  end if;

  -- 닉네임: 형용사 + 동물. 충돌 시 10회까지 재시도, 그래도 겹치면 숫자 접미.
  for i in 1..10 loop
    select a.word || ' ' || b.word into v_nick
    from slda.adjectives a, slda.animals b
    order by random() limit 1;
    exit when not exists (select 1 from slda.submissions s where s.nickname = v_nick);
  end loop;
  if exists (select 1 from slda.submissions s where s.nickname = v_nick) then
    v_nick := v_nick || ' ' || floor(random() * 90 + 10)::text;
  end if;

  insert into slda.submissions
    (kind, story, doc_count, page_est, contact, title, title_public, nickname)
  values
    (p_kind::slda.kind, p_story, p_doc_count, p_page_est,
     nullif(trim(p_contact), ''),
     nullif(trim(p_title), ''),
     coalesce(p_title_public, false),
     v_nick)
  returning slda.submissions.ref into v_ref;

  insert into slda.status_log (ref, status) values (v_ref, '접수');

  return query select v_ref, v_nick;
end;
$$;

revoke all on function public.create_submission(text, text, int, int, text, text, boolean) from public;
grant execute on function public.create_submission(text, text, int, int, text, text, boolean) to anon;

-- ------------------------------------------------------------
-- 4. 게시판 목록
--    닉네임 · 유형 · 제목(공개동의 시만) · 최신상태 · 갱신일.
--    접수번호 · 사연 · 연락처 · 파일명은 절대 나가지 않는다.
-- ------------------------------------------------------------
create or replace function public.list_board()
returns table (
  nickname   text,
  kind       text,
  title      text,
  status     text,
  updated_at timestamptz
)
language sql
security definer
stable
set search_path = slda, pg_temp
as $$
  select
    s.nickname,
    s.kind::text,
    case when s.title_public then s.title else null end,
    (select l.status::text from slda.status_log l
       where l.ref = s.ref order by l.logged_at desc limit 1),
    (select max(l.logged_at) from slda.status_log l where l.ref = s.ref)
  from slda.submissions s
  where s.nickname is not null
  order by (select max(l.logged_at) from slda.status_log l where l.ref = s.ref) desc
  limit 50;
$$;

revoke all on function public.list_board() from public;
grant execute on function public.list_board() to anon;