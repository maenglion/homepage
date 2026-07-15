-- ============================================================
-- 20260715000005_agents.sql
-- 에이전트 · 엔진 · 게이트 · 감사 기록
--
--   에이전트는 로직, 파라미터는 조건.
--   산출물이 같으면 같은 에이전트다. 입력이 다른 것은 파라미터다.
--
--     1-1 우리 측 · 1-2 상대 측         → LIT-01  (side)
--     1-3 양측 교차                      → LIT-02
--     1-4 판례 대조                      → LIT-03
--     2-1 공개 · 2-2 비공개 · 2-3 반공개  → SOC-01  (scope)
--     3   업무 담당·책임자 · 제3자        → CON-01  (requester)
--
--   게이트는 에이전트가 아니라 파라미터에 붙는다.
--
--   사용
--     select * from slda.agent_menu;
--     select * from slda.param_menu where agent = 'SOC-01';
--     select slda.start_analysis('SLDA-XXXX','LIT-01','claude','{"side":"counter"}');
--     select * from slda.audit('SLDA-XXXX');
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
  ('local',    '소울스펙트럼',                    '대한민국', 'domestic',
   '국외 이전 없음. 자동화 보조 없이 진행하므로 기간이 길어진다.'),
  ('claude',   'Anthropic PBC',                  '미국',     'premium',
   '학습 미사용 · 처리 후 미보관.'),
  ('deepseek', 'Hangzhou DeepSeek AI Co., Ltd.', '중국',     'standard',
   '이미 공개된 자료 전용. 비공개 자료에는 선택할 수 없다.')
on conflict (code) do update
  set vendor = excluded.vendor, country = excluded.country,
      tier = excluded.tier, note = excluded.note;


-- ════════════════════════════════════════════════════════════
-- 2. 에이전트 — 5개
-- ════════════════════════════════════════════════════════════
create table if not exists slda.agents (
  code    text primary key,
  scope   text not null check (scope in ('LIT','SOC','CON')),
  name    text not null,
  name_ko text not null,
  params  text[] not null default '{}',
  engines text[] not null,
  outputs text[] not null,
  note    text
);

insert into slda.agents (code, scope, name, name_ko, params, engines, outputs, note) values
  ('LIT-01','LIT','Single Semantic','단측 시맨틱 분석',
   '{side}',
   '{claude,local}',
   '{표현강도 변화,주체귀속 변화,주장 드리프트,전제충돌,절차 프로세스 확장,지칭빈도,분석 raw}',
   '한쪽 서면·증거만 분석한다. side=own 우리 측 · side=counter 상대 측. 산출물이 같으므로 하나의 에이전트다.'),

  ('LIT-02','LIT','Cross Semantic','양측 교차 시맨틱 분석',
   '{}',
   '{claude,local}',
   '{표현강도 변화,시간축 양쪽 입장분석,시간축 양쪽 강도변화,주체귀속 변화,주장 드리프트,전제충돌,절차 프로세스 확장,지칭빈도,분석 raw}',
   '양측 서면을 교차 분석한다. 시간축 양쪽 입장·강도 비교는 한쪽 자료로 성립하지 않으므로 별개 에이전트다. 참고인·탄원서·의견서가 있으면 참고자료로 넣는다.'),

  ('LIT-03','LIT','Precedent Match','판례 대조',
   '{}',
   '{claude,local}',
   '{시간축 변화,지칭빈도,본 사건과 유사성 점수,분석 raw}',
   '어떤 법에 대해 시간축으로 어떻게 변화하는가. 1심·2심·3심, 단독·합의부에 따른 점수로 정량화한다. 판례 3개 이하면 이미 걸러 넣은 것이므로 요약에 그 내용을 쓴다. 유사도가 낮으면 분석 정확도가 낮다는 뜻이다.'),

  ('SOC-01','SOC','Thread Semantic','스레드 시맨틱 분석',
   '{scope}',
   '{claude,deepseek,local}',
   '{주체별 주요 주장 요약,시간축 주장 드리프트,전제충돌,전진 및 후퇴,주장별 세부 점수,시사점,분석 raw}',
   'SNS·메신저. scope=public 공개 · semi 반공개 · closed 비공개. 산출물이 동일하며, 공개 범위는 접수 조건이지 분석 로직이 아니다.'),

  ('CON-01','CON','Clause Semantic','조항 시맨틱 분석',
   '{requester}',
   '{claude,local}',
   '{시간축 변화,지칭빈도,시사점,분석 raw}',
   '계약서. requester=party 업무 담당·책임자 · third 제3자. 어떤 부분 위주의 변화가 도드라지는지 본다. 비공개 자료이므로 중국은 선택할 수 없다.')
on conflict (code) do update
  set scope = excluded.scope, name = excluded.name, name_ko = excluded.name_ko,
      params = excluded.params, engines = excluded.engines,
      outputs = excluded.outputs, note = excluded.note;


-- ════════════════════════════════════════════════════════════
-- 3. 파라미터 허용값
--   label · hint 는 화면에 그대로 뿌린다. UI 가 DB 를 따라간다.
-- ════════════════════════════════════════════════════════════
create table if not exists slda.agent_params (
  agent text not null references slda.agents(code) on delete cascade,
  param text not null,
  value text not null,
  label text not null,
  hint  text,
  primary key (agent, param, value)
);

insert into slda.agent_params (agent, param, value, label, hint) values
  ('LIT-01','side','own',     '우리 측 서면 · 증거', null),
  ('LIT-01','side','counter', '상대 측 서면 · 증거', null),

  ('SOC-01','scope','public', '공개글',
   '누구나 열람할 수 있는 게시물'),
  ('SOC-01','scope','semi',   '반공개',
   '비공개이나 팔로워·친구 등 접근할 수 있는 사람 수가 많은 글'),
  ('SOC-01','scope','closed', '비공개',
   '소수만 열람할 수 있는 글. 당사자 본인이 참여한 대화만 제출할 수 있습니다.'),

  ('CON-01','requester','party', '업무 담당 · 책임자',
   '해당 계약을 책임지는 라인. 대표자 · 법무팀 · 계약 실무 담당자'),
  ('CON-01','requester','third', '제3자',
   '위 어디에도 해당하지 않는 경우. 당사자의 동의가 확인되어야 합니다.')
on conflict (agent, param, value) do update
  set label = excluded.label, hint = excluded.hint;


-- ════════════════════════════════════════════════════════════
-- 4. 게이트 사유
-- ════════════════════════════════════════════════════════════
create table if not exists slda.gates (
  code   text primary key,
  reason text not null
);

insert into slda.gates (code, reason) values
  ('closed_third',
   '비공개 게시물은 당사자 본인이 참여한 대화에 한하여 분석합니다. 제3자가 타인의 비공개 게시물을 제출할 수 없습니다.'),
  ('closed_foreign',
   '비공개 게시물은 이미 공개된 자료가 아니므로 Standard(중국)를 선택할 수 없습니다. Premium(미국) 또는 국내 처리를 선택해주세요.'),
  ('private_foreign',
   '비공개 자료이므로 Standard(중국)를 선택할 수 없습니다. Premium(미국) 또는 국내 처리를 선택해주세요.'),
  ('third_consent',
   '제3자가 제출하는 경우 당사자로부터 동의를 받아야 합니다. 확인 항목에 체크되지 않았습니다.')
on conflict (code) do update set reason = excluded.reason;


-- ════════════════════════════════════════════════════════════
-- 5. submissions 확장
--   본인인증은 사실만 남긴다. 신원은 저장하지 않는다.
-- ════════════════════════════════════════════════════════════
alter table slda.submissions
  add column if not exists agent       text references slda.agents(code),
  add column if not exists engine      text references slda.engines(code),
  add column if not exists params      jsonb,
  add column if not exists analyzed_at timestamptz,
  add column if not exists checks      jsonb,
  add column if not exists mask_n      int,
  add column if not exists file_n      int,
  add column if not exists verified    boolean not null default false,
  add column if not exists verify_by   text,
  add column if not exists verified_at timestamptz;


-- ════════════════════════════════════════════════════════════
-- 6. 분석 시작 — 게이트가 여기서 작동한다
--   규칙이 문서가 아니라 코드다. 실수로 뚫을 수 없다.
-- ════════════════════════════════════════════════════════════
create or replace function slda.start_analysis(
  p_ref    text,
  p_agent  text,
  p_engine text,
  p_params jsonb default '{}'::jsonb
)
returns text
language plpgsql
as $$
declare
  a       slda.agents%rowtype;
  e       slda.engines%rowtype;
  v_role  text;
  v_par   text;
  v_val   text;
  v_scope text;
  v_req   text;
  v_gate  text;
begin
  select * into a from slda.agents where code = p_agent;
  if not found then
    raise exception '알 수 없는 에이전트: %   → select * from slda.agent_menu;', p_agent;
  end if;

  select * into e from slda.engines where code = p_engine;
  if not found then
    raise exception '알 수 없는 엔진: %   → select * from slda.engine_menu;', p_engine;
  end if;

  -- ── 파라미터 검증 ──
  foreach v_par in array a.params loop
    v_val := p_params->>v_par;
    if v_val is null then
      raise exception '% 에는 % 파라미터가 필요합니다.  가능한 값: %',
        a.code, v_par,
        (select string_agg(value || ' — ' || label, '  /  ')
           from slda.agent_params where agent = a.code and param = v_par);
    end if;
    if not exists (select 1 from slda.agent_params
                    where agent = a.code and param = v_par and value = v_val) then
      raise exception '% 의 % 에 % 는 없습니다.  가능한 값: %',
        a.code, v_par, v_val,
        (select string_agg(value, ', ') from slda.agent_params where agent = a.code and param = v_par);
    end if;
  end loop;

  -- ── 엔진 허용 ──
  if not (p_engine = any(a.engines)) then
    raise exception '% 는 % 엔진을 사용할 수 없습니다.  사용 가능: %',
      a.code, e.vendor, array_to_string(a.engines, ', ');
  end if;

  v_role  := slda.role_of(p_ref);
  v_scope := p_params->>'scope';
  v_req   := p_params->>'requester';

  -- ── 게이트 ①  비공개 게시물 + 제3자 제출 ──
  if a.code = 'SOC-01' and v_scope = 'closed' and v_role <> 'party' then
    select reason into v_gate from slda.gates where code = 'closed_third';
    raise exception '%', v_gate;
  end if;

  -- ── 게이트 ②  비공개 게시물 + 중국 ──
  if a.code = 'SOC-01' and v_scope = 'closed' and e.tier = 'standard' then
    select reason into v_gate from slda.gates where code = 'closed_foreign';
    raise exception '%', v_gate;
  end if;

  -- ── 게이트 ③  비공개 자료(법률·계약) + 중국 ──
  if a.scope in ('LIT','CON') and e.tier = 'standard' then
    select reason into v_gate from slda.gates where code = 'private_foreign';
    raise exception '%', v_gate;
  end if;

  -- ── 게이트 ④  계약서 제3자 제출 + 당사자 동의 미확인 ──
  if a.code = 'CON-01' and v_req = 'third' then
    if coalesce(
         (select checks->'checks'->>'consent' from slda.submissions where ref = p_ref),
         'false') <> 'true' then
      select reason into v_gate from slda.gates where code = 'third_consent';
      raise exception '%', v_gate;
    end if;
  end if;

  -- ── 기록 ──
  update slda.submissions
    set agent = p_agent, engine = p_engine, params = p_params, analyzed_at = now()
    where ref = p_ref;

  insert into slda.status_log (ref, status, note)
  values (p_ref, '분석 진행',
    a.code || ' · ' || a.name_ko ||
    coalesce(' (' || (select string_agg(k || '=' || v, ', ')
                        from jsonb_each_text(p_params) as t(k, v)) || ')', '') ||
    ' · ' || e.vendor || ' (' || e.country || ')');

  return a.code || ' / ' || e.code || ' 로 분석을 시작했습니다.';
end;
$$;


-- ════════════════════════════════════════════════════════════
-- 7. 감사 기록
--   자료가 파기되어도 남는다. 신원은 없다.
--   이것을 그대로 내밀 수 있어야 한다.
-- ════════════════════════════════════════════════════════════
create or replace function slda.audit(p_ref text)
returns table (item text, value text)
language sql stable
as $$
  with s as (select * from slda.submissions where ref = p_ref),
       a as (select * from slda.agents  where code = (select agent  from s)),
       e as (select * from slda.engines where code = (select engine from s))
  select '접수번호',      (select ref from s)                                                          union all
  select '표시명',        (select nickname from s)                                                     union all
  select '접수 일시',     to_char((select created_at from s), 'YYYY-MM-DD HH24:MI')                    union all
  select '자료 유형',     (select kind::text from s)                                                   union all
  select '신청인 지위',   slda.role_of(p_ref)                                                          union all
  select '본인인증',      case when (select verified from s)
                            then '완료 · ' || coalesce((select verify_by from s), '-') || ' · ' ||
                                 to_char((select verified_at from s), 'YYYY-MM-DD HH24:MI')
                            else '미실시 (익명 접수)' end                                              union all
  select '신원 보유',     '없음. 회사는 신청자의 신원 정보를 저장하지 않으며, 인증 사실만 보관합니다.'    union all
  select '확인 응답',     coalesce((select jsonb_pretty(checks) from s), '기록 없음')                   union all
  select '제출 파일 수',  coalesce((select file_n::text from s), '0') || '개'                          union all
  select '자동 마스킹',   coalesce((select mask_n::text from s), '0') || '개 항목'                     union all
  select '분석 에이전트', coalesce((select code || ' · ' || name_ko from a), '미지정') ||
                          coalesce(' (' || (select string_agg(k || '=' || v, ', ')
                                              from jsonb_each_text((select params from s)) as t(k,v)) || ')', '')  union all
  select '분석 엔진',     coalesce((select vendor || ' · ' || country from e), '미지정')               union all
  select '국외 이전',     coalesce((select case when country = '대한민국' then '없음' else country end from e), '미지정')  union all
  select '분석 일시',     coalesce(to_char((select analyzed_at from s), 'YYYY-MM-DD HH24:MI'), '미실시') union all
  select '파기 예정',     coalesce(to_char((select purge_after from s), 'YYYY-MM-DD HH24:MI'), '미정')  union all
  select '파기 완료',     coalesce(to_char((select purged_at from s), 'YYYY-MM-DD HH24:MI'), '미실시')  union all
  select '상태 이력',     (select string_agg(
                             to_char(l.logged_at, 'MM-DD HH24:MI') || '  ' || l.status::text ||
                             coalesce('  ' || l.note, ''), E'\n' order by l.logged_at)
                           from slda.status_log l where l.ref = p_ref);
$$;


-- ════════════════════════════════════════════════════════════
-- 8. 목록
-- ════════════════════════════════════════════════════════════
create or replace view slda.agent_menu as
  select a.code, a.scope, a.name_ko,
         case when array_length(a.params,1) is null then '—'
              else array_to_string(a.params, ' · ') end as params,
         array_to_string(a.engines, ' · ') as engines,
         array_length(a.outputs, 1) as n_outputs,
         a.note
  from slda.agents a
  order by a.scope, a.code;

create or replace view slda.param_menu as
  select p.agent, p.param, p.value, p.label, p.hint
  from slda.agent_params p
  order by p.agent, p.param, p.value;

create or replace view slda.engine_menu as
  select e.code, e.vendor, e.country, e.tier, e.note
  from slda.engines e
  order by case e.tier when 'domestic' then 1 when 'premium' then 2 else 3 end;

create or replace view slda.output_menu as
  select a.code, a.name_ko, unnest(a.outputs) as output
  from slda.agents a
  order by a.code;