-- ============================================================
-- 20260715000003_sns.sql
-- SNS 계정명 검출 + 은행 약칭 보강
--
--   플랫폼명 표기는 띄어쓰기 · - · / · · · _ 를 무시하고 매칭한다.
--   ("네이버블로그" 하나로 "네이버 블로그", "네이버-블로그" 를 모두 잡는다)
--
--   계정명은 앞 5자만 남기고 마스킹해야 한다.
--     nanyo***********  → 통과
--     nanyoung_official → 검출
--
--   커뮤니티(디시·에펨·블라인드 등)는 익명 닉네임이라 매칭이 성립하지 않는다.
--   대상에서 제외한다.
-- ============================================================

do $$ begin
  alter type slda.pii_kind add value if not exists 'sns_id';
exception when others then null;
end $$;


-- ════════════════════════════════════════════════════════════
-- 1. 은행 약칭 보강
-- ════════════════════════════════════════════════════════════
insert into slda.banks (name) values
  -- 영문 약칭
  ('KB'),('KEB'),('IBK'),('KDB'),('NH'),('SC'),('DGB'),('BNK'),('JB'),('BNP'),
  ('SH'),('KFCC'),('CU'),('MG'),('EXIM'),
  -- 영문 표기
  ('Kookmin'),('Shinhan'),('Woori'),('Hana'),('Nonghyup'),('Suhyup'),
  ('Standard Chartered'),('Citibank'),('Citi'),('KakaoBank'),('Kakao Bank'),
  ('K bank'),('Kbank'),('Toss Bank'),('TossBank'),
  ('Daegu Bank'),('Busan Bank'),('Kyongnam Bank'),('Kwangju Bank'),
  ('Jeonbuk Bank'),('Jeju Bank'),('Industrial Bank of Korea'),
  ('Korea Development Bank'),('Export-Import Bank'),
  -- 한글 약칭 · 별칭
  ('국민'),('신한'),('우리'),('하나'),('외환'),('제일'),('씨티'),
  ('농협중앙회'),('단위농협'),('지역농협'),('수협중앙회'),
  ('기업'),('산업'),('중소기업은행'),('한국산업은행'),
  ('대구'),('부산'),('경남'),('광주'),('전북'),('제주'),
  ('카카오'),('케이'),('아이엠뱅크'),
  ('금고'),('신용협동조합'),('상호신용'),('우체국예금'),
  -- 계좌 문맥어 보강
  ('입금'),('송금'),('이체'),('계좌'),('예금')
on conflict (name) do nothing;


-- ════════════════════════════════════════════════════════════
-- 2. SNS 플랫폼
--    커뮤니티는 넣지 않는다.
-- ════════════════════════════════════════════════════════════
create table if not exists slda.sns_platforms (name text primary key);

insert into slda.sns_platforms (name) values
  -- 총칭
  ('SNS'),('소셜네트워크'),('소셜네트워크서비스'),('소셜미디어'),
  ('social network'),('social media'),
  -- 인스타그램
  ('인스타그램'),('인스타'),('instagram'),('insta'),('insta gram'),
  -- 페이스북
  ('페이스북'),('페북'),('facebook'),('meta'),
  -- 트위터 · X
  ('트위터'),('엑스'),('twitter'),('tweet'),
  -- 스레드
  ('스레드'),('쓰레드'),('threads'),
  -- 유튜브
  ('유튜브'),('유투브'),('youtube'),('shorts'),
  -- 틱톡
  ('틱톡'),('tiktok'),
  -- 블로그
  ('네이버블로그'),('네이버포스트'),('블로그'),('blog'),('naverblog'),('blogspot'),
  ('티스토리'),('tistory'),('브런치'),('브런치스토리'),('brunch'),('velog'),('벨로그'),
  ('워드프레스'),('wordpress'),('medium'),('미디엄'),
  -- 카카오
  ('카카오스토리'),('카스'),('kakaostory'),('카카오채널'),('오픈채팅'),
  -- 기타 플랫폼
  ('링크드인'),('linkedin'),('텀블러'),('tumblr'),('핀터레스트'),('pinterest'),
  ('텔레그램'),('telegram'),('디스코드'),('discord'),('레딧'),('reddit'),
  ('트위치'),('twitch'),('스포티파이'),('노션'),('notion'),
  ('깃허브'),('github'),('비하인드'),
  -- 계정 문맥어
  ('계정명'),('아이디'),('닉네임'),('핸들'),('username'),('user id'),('account'),
  ('프로필'),('profile'),('채널명'),('채널')
on conflict (name) do nothing;


-- ════════════════════════════════════════════════════════════
-- 3. 표기 흔들림을 흡수하는 패턴 생성
--    "블로그" → "블[\s\-/·_.]*로[\s\-/·_.]*그"
-- ════════════════════════════════════════════════════════════
create or replace function slda.fuzzy_pattern(p_name text)
returns text
language sql immutable
as $$
  select regexp_replace(
           regexp_replace(p_name, '[\s\-/·_.]', '', 'g'),
           '(.)', '\1[\s\-/·_.]*', 'g'
         );
$$;


-- ════════════════════════════════════════════════════════════
-- 4. SNS 계정명 검출
--    플랫폼명 근처 40자 이내의 미마스킹 계정명.
--      @handle
--      '계정명' 또는 "계정명"  (따옴표는 무시하고 안쪽만 본다)
--      영문 6자 이상 토큰
--    5자 이하는 통과. * 가 섞인 것도 통과.
-- ════════════════════════════════════════════════════════════
create or replace function slda.scan_sns_id(p_text text)
returns table (hit text, ctx text)
language plpgsql stable
as $$
declare
  v_line text;
  v_pat  text;
  v_hit  text;
begin
  -- 플랫폼명 패턴 (긴 것 우선)
  select '(?:' || string_agg(slda.fuzzy_pattern(name), '|' order by length(name) desc, name) || ')'
    into v_pat
  from slda.sns_platforms;

  for v_line in
    select l from regexp_split_to_table(p_text, '(?<=[.!?。])\s+|\n+') as l
  loop
    continue when v_line !~* v_pat;

    -- ① @handle
    for v_hit in
      select m[1] from regexp_matches(v_line, '@([A-Za-z0-9._]{6,30})\M', 'g') as m
    loop
      continue when v_hit ~ '\*';
      hit := '@' || v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;

    -- ② 따옴표 안의 계정명
    for v_hit in
      select m[1] from regexp_matches(v_line, '[''"“”‘’]([A-Za-z0-9가-힣._\-]{6,40})[''"“”‘’]', 'g') as m
    loop
      continue when v_hit ~ '\*';
      continue when v_hit ~* v_pat;   -- 플랫폼명 자체는 제외
      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;

    -- ③ 플랫폼명 뒤 40자 이내의 영문 토큰
    for v_hit in
      select m[1]
      from regexp_matches(v_line, v_pat || '[^A-Za-z0-9\*\n]{0,40}\m([A-Za-z][A-Za-z0-9._\-]{5,39})\M', 'g') as m
    loop
      continue when v_hit ~ '\*';
      continue when v_hit ~* v_pat;
      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;
  end loop;
end;
$$;


-- ════════════════════════════════════════════════════════════
-- 5. scan_pii 교체
-- ════════════════════════════════════════════════════════════
create or replace function slda.scan_pii(p_text text)
returns table (kind slda.pii_kind, hit text, ctx text)
language sql stable
as $$
  select 'rin'::slda.pii_kind, r, null::text from slda.scan_rin(p_text) as r
  union all
  select 'case_no'::slda.pii_kind, c, null::text from slda.scan_case_no(p_text) as c
  union all
  select 'name_ctx'::slda.pii_kind, n.hit, n.ctx from slda.scan_name_ctx(p_text) as n
  union all
  select 'phone'::slda.pii_kind, m[1], null::text
    from regexp_matches(p_text, '(\m01[016789][-\s]?\d{3,4}[-\s]?\d{4}\M)', 'g') as m
  union all
  select 'account'::slda.pii_kind, a.hit, a.ctx from slda.scan_account(p_text) as a
  union all
  select 'biz_no'::slda.pii_kind, b, null::text from slda.scan_biz_no(p_text) as b
  union all
  select 'sns_id'::slda.pii_kind, s.hit, s.ctx from slda.scan_sns_id(p_text) as s;
$$;


-- ════════════════════════════════════════════════════════════
-- 6. 판정
--    계정명은 그 자체가 식별자다. 지위 무관 파기.
--    논쟁 자료(controversy)는 제3자 계정이 전제이므로 예외 없음.
-- ════════════════════════════════════════════════════════════
insert into slda.pii_policy (kind, role, action, note) values
  ('sns_id','party',  'review','SNS 계정명이 처리되지 않았습니다. 본인 계정인지 확인이 필요합니다.'),
  ('sns_id','agent',  'purge','제3자의 SNS 계정명이 처리되지 않았습니다. 앞 5자만 남기고 마스킹해야 합니다.'),
  ('sns_id','unknown','purge','SNS 계정명이 처리되지 않았습니다. 앞 5자만 남기고 마스킹해야 합니다.')
on conflict (kind, role) do update
  set action = excluded.action, note = excluded.note;