-- ============================================================
-- 20260715000005_audit.sql
-- 감사 기록
--
--   무엇을 남기나
--     · 어떤 에이전트로 · 어떤 엔진으로 · 언제 분석했나
--     · 제출 자료가 몇 개였나
--     · 당사자였나 대리인이었나
--     · 확인 응답을 어디까지 체크했나
--     · 본인인증을 거쳤나
--     · 언제 파기했나
--
--   무엇을 남기지 않나
--     · 신청자의 신원. 이름·전화번호·주민번호를 저장하지 않는다.
--       본인인증은 인증기관이 수행하고, 회사는 "인증됨"이라는 사실만 받는다.
--       익명 접수는 그대로 성립한다.
--     · 자료의 내용. 파기되면 사라진다.
--
--   자료는 파기되어도 기록은 남는다. 그것이 이 테이블의 목적이다.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- 1. 분석 엔진
-- ════════════════════════════════════════════════════════════
create table if not exists slda.engines (
  code    text primary key,
  vendor  text not null,
  country text not null,
  tier    text not null check (tier in ('standard','premium','domestic')),
  note    text
);

insert into slda.engines (code, vendor, country, tier, note) values
  ('local',    '소울스펙트럼',                          '대한민국', 'domestic',
   '국외 이전 없음. 자동화 보조 없이 진행하므로 기간이 길어진다.'),
  ('claude',   'Anthropic PBC',                        '미국',     'premium',
   '학습 미사용 · 처리 후 미보관.'),
  ('deepseek', 'Hangzhou DeepSeek AI Co., Ltd.',       '중국',     'standard',
   '공개 자료 전용. 비공개 자료에는 선택할 수 없다.')
on conflict (code) do update
  set vendor = excluded.vendor, country = excluded.country,
      tier = excluded.tier, note = excluded.note;


-- ════════════════════════════════════════════════════════════
-- 2. 에이전트
--   코드는 세 글자 + 숫자. 앞 세 글자가 범위를 말한다.
--     LIT  Litigation  법률 문서
--     SOC  Social      SNS · 메신저
--     CON  Contract    계약서
--   버전이 갈리면 LIT-3.1 처럼 붙인다.
-- ════════════════════════════════════════════════════════════
create table if not exists slda.agents (
  code     text primary key,
  scope    text not null check (scope in ('LIT','SOC','CON')),
  name     text not null,
  name_ko  text not null,
  actor    text not null check (actor in ('party','third','party_only')),
  engines  text[] not null,
  outputs  text[] not null,
  note     text
);

insert into slda.agents (code, scope, name, name_ko, actor, engines, outputs, note) values
  ('LIT-1','LIT','Own Semantic','우리 측 시맨틱 분석','party',
   '{claude,local}',
   '{표현강도 변화,주체귀속 변화,주장 드리프트,전제충돌,절차 프로세스 확장,지칭빈도,분석 raw}',
   '자기 측 서면만 분석한다.'),

  ('LIT-2','LIT','Counter Semantic','상대 측 시맨틱 분석','party',
   '{claude,local}',
   '{표현강도 변화,주체귀속 변화,주장 드리프트,전제충돌,절차 프로세스 확장,지칭빈도,분석 raw}',
   '상대 측 서면만 분석한다.'),

  ('LIT-3','LIT','Cross Semantic','양측 교차 시맨틱 분석','party',
   '{claude,local}',
   '{표현강도 변화,시간축 양쪽 입장분석,시간축 양쪽 강도변화,주체귀속 변화,주장 드리프트,전제충돌,절차 프로세스 확장,지칭빈도,분석 raw}',
   '양측 서면을 교차 분석한다. 참고인·탄원서·의견서가 있으면 참고자료로 넣는다.'),

  ('LIT-4','LIT','Precedent Match','기존 판례 분석','party',
   '{claude,local}',
   '{시간축 변화,지칭빈도,본 사건과 유사성 점수,분석 raw}',
   '판례 3개 이하면 이미 걸러 넣은 것이므로 요약에 그 내용을 쓴다. 유사도가 낮으면 분석 정확도가 낮다는 뜻이다.'),

  ('SOC-1','SOC','Public Thread','공개글 분석','third',
   '{claude,deepseek,local}',
   '{주체별 주요 주장 요약,시간축 주장 드리프트,전제충돌,전진 및 후퇴,주장별 세부 점수,시사점,분석 raw}',
   '누구나 열람할 수 있는 게시물.'),

  ('SOC-2','SOC','Semi Thread','반공개글 분석','third',
   '{claude,deepseek,local}',
   '{주체별 주요 주장 요약,시간축 주장 드리프트,전제충돌,전진 및 후퇴,주장별 세부 점수,시사점,분석 raw}',
   '팔로워·친구 등 다수가 열람할 수 있는 게시물. 공연성이 성립한다.'),

  ('SOC-3','SOC','Private Thread','비공개글 분석','party_only',
   '{claude,local}',
   '{주체별 주요 주장 요약,시간축 주장 드리프트,전제충돌,전진 및 후퇴,주장별 세부 점수,시사점,분석 raw}',
   '당사자 본인이 참여한 대화에 한한다. 제3자가 남의 비공개글을 제출하는 것은 받지 않는다. 국외 이전 중 중국은 선택할 수 없다.'),

  ('CON-1','CON','Party Contract','업무자 요청 분석','party',
   '{claude,local}',
   '{시간축 변화,지칭빈도,시사점,분석 raw}',
   '계약 당사자의 요청. 비공개 자료이므로 중국은 선택할 수 없다.'),

  ('CON-2','CON','Third Contract','제3자 분석','third',
   '{claude,local}',
   '{시간축 변화,지칭빈도,시사점,분석 raw}',
   '제3자가 제출하는 계약서. 당사자 동의가 확인되어야 한다. 중국은 선택할 수 없다.')
on conflict (code) do update
  set scope = excluded.scope, name = excluded.name, name_ko = excluded.name_ko,
      actor = excluded.actor, engines = excluded.engines,
      outputs = excluded.outputs, note = excluded.note;


-- ════════════════════════════════════════════════════════════
-- 3. submissions 확장
-- ════════════════════════════════════════════════════════════
alter table slda.submissions
  -- 본인인증 여부. 신원은 저장하지 않는다.
  -- 인증기관이 신원을 보유하고, 회사는 인증 사실만 받는다.
  add column if not exists verified boolean not null default false,
  add column if not exists verified_at timestamptz,

  -- 확인 응답. 텍스트가 아니라 구조로 남긴다.
  --   { "role":"agent", "scope":"public",
  --     "checks":{"rin":true,"name":true,"addr":true,"contact":true,
  --               "case_no":true,"consent":true,"right":true} }
  add column if not exists checks jsonb,

  -- 어떤 에이전트 · 어떤 엔진으로 분석했나
  add column if not exists agent  text references slda.agents(code),
  add column if not exists engine text references slda.engines(code),
  add column if not exists analyzed_at timestamptz,

  -- 자동 마스킹 결과
  add column if not exists mask_n int,
  add column if not exists file_n int;


-- ════════════════════════════════════════════════════════════
-- 4. 분석 시작 기록
-- ════════════════════════════════════════════════════════════
create or replace function slda.start_analysis(
  p_ref    text,
  p_agent  text,
  p_engine text
)
returns text
language plpgsql
as $$
declare
  a slda.agents%rowtype;
  e slda.engines%rowtype;
  v_role text;
begin
  select * into a from slda.agents where code = p_agent;
  if not found then
    raise exception '알 수 없는 에이전트: %  (select code, name_ko from slda.agents)', p_agent;
  end if;

  select * into e from slda.engines where code = p_engine;
  if not found then
    raise exception '알 수 없는 엔진: %  (select code, vendor, country from slda.engines)', p_engine;
  end if;

  -- 이 에이전트가 이 엔진을 쓸 수 있나
  if not (p_engine = any(a.engines)) then
    raise exception '% 는 % 엔진을 사용할 수 없습니다. 사용 가능: %',
      a.code, e.vendor, array_to_string(a.engines, ', ');
  end if;

  -- 당사자 전용 에이전트인데 대리인이 제출했나
  v_role := slda.role_of(p_ref);
  if a.actor = 'party_only' and v_role <> 'party' then
    raise exception '% 는 당사자 본인이 제출한 자료에만 적용됩니다. 현재 지위: %', a.code, v_role;
  end if;

  update slda.submissions
    set agent = p_agent, engine = p_engine, analyzed_at = now()
    where ref = p_ref;

  insert into slda.status_log (ref, status, note)
  values (p_ref, '분석 진행',
    a.code || ' · ' || a.name_ko || ' · ' || e.vendor || ' (' || e.country || ')');

  return a.code || ' / ' || e.code || ' 로 분석을 시작했습니다.';
end;
$$;


-- ════════════════════════════════════════════════════════════
-- 5. 감사 기록 — 이것을 그대로 내밀 수 있어야 한다
--   자료가 파기되어도 남는다. 신원은 없다.
-- ════════════════════════════════════════════════════════════
create or replace function slda.audit(p_ref text)
returns table (item text, value text)
language sql stable
as $$
  with s as (select * from slda.submissions where ref = p_ref),
       a as (select * from slda.agents  where code = (select agent  from s)),
       e as (select * from slda.engines where code = (select engine from s))
  select '접수번호',      (select ref from s)                                    union all
  select '표시명',        (select nickname from s)                               union all
  select '접수 일시',     to_char((select created_at from s), 'YYYY-MM-DD HH24:MI')  union all
  select '자료 유형',     (select kind::text from s)                             union all
  select '신청인 지위',   coalesce((select checks->>'role' from s), slda.role_of(p_ref))  union all
  select '본인인증',      case when (select verified from s)
                            then '완료 · ' || to_char((select verified_at from s), 'YYYY-MM-DD HH24:MI')
                            else '미실시 (익명 접수)' end                        union all
  select '신원 보유',     '없음. 회사는 신청자의 신원 정보를 저장하지 않습니다.'   union all
  select '확인 응답',     coalesce((select jsonb_pretty(checks->'checks') from s), '기록 없음')  union all
  select '제출 파일 수',  coalesce((select file_n::text from s), '0') || '개'     union all
  select '자동 마스킹',   coalesce((select mask_n::text from s), '0') || '개 항목' union all
  select '분석 에이전트', coalesce((select code || ' · ' || name_ko from a), '미지정')  union all
  select '분석 엔진',     coalesce((select vendor || ' (' || country || ')' from e), '미지정')  union all
  select '국외 이전',     coalesce((select case when country = '대한민국' then '없음' else country end from e), '미지정')  union all
  select '분석 일시',     coalesce(to_char((select analyzed_at from s), 'YYYY-MM-DD HH24:MI'), '미실시')  union all
  select '파기 예정',     coalesce(to_char((select purge_after from s), 'YYYY-MM-DD HH24:MI'), '미정')  union all
  select '파기 완료',     coalesce(to_char((select purged_at from s), 'YYYY-MM-DD HH24:MI'), '미실시')  union all
  select '상태 이력',     (select string_agg(
                             to_char(l.logged_at, 'MM-DD HH24:MI') || '  ' || l.status::text ||
                             coalesce('  (' || l.note || ')', ''), E'\n' order by l.logged_at)
                           from slda.status_log l where l.ref = p_ref);
$$;


-- ════════════════════════════════════════════════════════════
-- 6. 에이전트 · 엔진 목록
-- ════════════════════════════════════════════════════════════
create or replace view slda.agent_menu as
  select a.code, a.scope, a.name_ko, a.actor,
         array_to_string(a.engines, ' · ') as engines,
         a.note
  from slda.agents a
  order by a.scope, a.code;

create or replace view slda.engine_menu as
  select e.code, e.vendor, e.country, e.tier, e.note
  from slda.engines e
  order by case e.tier when 'domestic' then 1 when 'premium' then 2 else 3 end;