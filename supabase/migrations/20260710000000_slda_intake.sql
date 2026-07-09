-- SLDA 접수 · 상태 · 파기
-- 원칙: 브라우저는 함수 2개만 호출한다. 테이블은 REST에 노출되지 않는다.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------
-- 1. 스키마 — public 이 아니므로 Data API 에 노출되지 않는다
-- ---------------------------------------------------------------
create schema if not exists slda;
revoke all on schema slda from anon, authenticated;

-- ---------------------------------------------------------------
-- 2. 테이블
-- ---------------------------------------------------------------
create type slda.kind as enum ('litigation', 'controversy', 'general');

create type slda.status as enum (
  '접수',
  '분석 가능',
  '분석 불가',
  '분석 진행',
  '분석 완료',
  '파기 완료'
);

create table slda.submissions (
  id           uuid primary key default gen_random_uuid(),
  ref          text unique not null default 'SLDA-' || upper(encode(extensions.gen_random_bytes(8), 'hex')),
  kind         slda.kind not null,
  story        text not null check (char_length(story) between 20 and 5000),
  doc_count    int  not null check (doc_count between 1 and 200),
  page_est     int  check (page_est between 1 and 100000),
  contact      text check (contact is null or char_length(contact) <= 200),
  purge_after  timestamptz,
  purged_at    timestamptz,
  created_at   timestamptz not null default now()
);

create index on slda.submissions (purge_after) where purged_at is null;

create table slda.status_log (
  id         bigint generated always as identity primary key,
  ref        text not null references slda.submissions(ref) on delete cascade,
  status     slda.status not null,
  note       text,
  logged_at  timestamptz not null default now()
);

create index on slda.status_log (ref, logged_at);

-- ---------------------------------------------------------------
-- 3. RLS — 정책을 하나도 만들지 않는다 = 전부 차단
--    service_role 만 우회한다. 이중 방어.
-- ---------------------------------------------------------------
alter table slda.submissions enable row level security;
alter table slda.status_log  enable row level security;
alter table slda.submissions force row level security;
alter table slda.status_log  force row level security;

-- ---------------------------------------------------------------
-- 4. 접수 — 유일한 쓰기 경로
--    ref 는 서버가 만든다. 신청자가 지정할 수 없다.
-- ---------------------------------------------------------------
create function public.create_submission(
  p_kind      text,
  p_story     text,
  p_doc_count int,
  p_page_est  int  default null,
  p_contact   text default null
)
returns text
language plpgsql
security definer
set search_path = slda, pg_temp
as $$
declare
  v_ref text;
begin
  if p_kind not in ('litigation', 'controversy', 'general') then
    raise exception '잘못된 유형입니다';
  end if;

  insert into slda.submissions (kind, story, doc_count, page_est, contact)
  values (p_kind::slda.kind, p_story, p_doc_count, p_page_est, nullif(trim(p_contact), ''))
  returning ref into v_ref;

  insert into slda.status_log (ref, status) values (v_ref, '접수');

  return v_ref;
end;
$$;

-- ---------------------------------------------------------------
-- 5. 조회 — 접수번호를 아는 사람만, 그 한 건만
-- ---------------------------------------------------------------
create function public.get_status(p_ref text)
returns table (status text, note text, logged_at timestamptz)
language sql
security definer
stable
set search_path = slda, pg_temp
as $$
  select l.status::text, l.note, l.logged_at
  from slda.status_log l
  where l.ref = upper(trim(p_ref))
  order by l.logged_at;
$$;

-- ---------------------------------------------------------------
-- 6. 업로드 경로 검증용 헬퍼
--    스토리지 정책은 anon 권한으로 평가되므로 definer 함수가 필요하다
-- ---------------------------------------------------------------
create function public.ref_accepts_upload(p_ref text)
returns boolean
language sql
security definer
stable
set search_path = slda, pg_temp
as $$
  select exists (
    select 1 from slda.submissions s
    where s.ref = p_ref
      and s.purged_at is null
      and s.created_at > now() - interval '30 days'
  );
$$;

-- ---------------------------------------------------------------
-- 7. 권한 — anon 은 함수 3개만. 테이블 권한 0.
-- ---------------------------------------------------------------
revoke all on function public.create_submission(text, text, int, int, text) from public;
revoke all on function public.get_status(text) from public;
revoke all on function public.ref_accepts_upload(text) from public;

grant execute on function public.create_submission(text, text, int, int, text) to anon;
grant execute on function public.get_status(text) to anon;
grant execute on function public.ref_accepts_upload(text) to anon;

-- ---------------------------------------------------------------
-- 8. 스토리지 — 비공개 버킷. 넣을 수만 있고 못 꺼낸다.
-- ---------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('slda-uploads', 'slda-uploads', false, 104857600)
on conflict (id) do nothing;

create policy "upload into own ref folder"
  on storage.objects for insert to anon
  with check (
    bucket_id = 'slda-uploads'
    and public.ref_accepts_upload((storage.foldername(name))[1])
  );

-- select / update / delete 정책 없음 = 관리자(service_role)만 열람·삭제

-- ---------------------------------------------------------------
-- 9. 파기 대상 조회 — Edge Function 이 service_role 로 호출
-- ---------------------------------------------------------------
create function slda.due_for_purge()
returns table (ref text)
language sql
stable
as $$
  select s.ref from slda.submissions s
  where s.purged_at is null
    and s.purge_after is not null
    and s.purge_after <= now();
$$;

create function slda.mark_purged(p_ref text, p_files int)
returns void
language plpgsql
as $$
begin
  update slda.submissions set purged_at = now() where ref = p_ref;
  insert into slda.status_log (ref, status, note)
  values (p_ref, '파기 완료', p_files || '개 파일 삭제');
end;
$$;

-- 분석 불가 판정 시 즉시 파기 대상으로
create function slda.reject(p_ref text, p_note text default null)
returns void
language plpgsql
as $$
begin
  update slda.submissions set purge_after = now() where ref = p_ref;
  insert into slda.status_log (ref, status, note) values (p_ref, '분석 불가', p_note);
end;
$$;

-- 분석 완료 시 30일 후 파기 예약
create function slda.complete(p_ref text)
returns void
language plpgsql
as $$
begin
  update slda.submissions set purge_after = now() + interval '30 days' where ref = p_ref;
  insert into slda.status_log (ref, status, note)
  values (p_ref, '분석 완료', to_char(now() + interval '30 days', 'YYYY-MM-DD') || ' 파기 예정');
end;
$$;
