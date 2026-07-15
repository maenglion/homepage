-- ============================================================
-- 20260715000004_name_fix.sql
-- name_ctx 오탐 제거
--
--   문제: 성씨 + 2글자 규칙이 행정구역·일반명사를 잡는다.
--     강남구 = 강(姓) + 남구
--     서울시 = 서(姓) + 울시
--     사업자 = 사(姓) + 업자
--     연락처 = 연(姓) + 락처
--
--   해결:
--     ① 행정구역 접미사로 끝나면 제외
--     ② 제외어 사전
--     ③ 은행명·SNS 플랫폼명과 겹치면 제외
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- 제외어 사전 — 성씨로 시작하지만 이름이 아닌 3글자
-- ════════════════════════════════════════════════════════════
create table if not exists slda.name_stopwords (word text primary key);

insert into slda.name_stopwords (word) values
  -- 광역 행정구역
  ('서울시'),('부산시'),('대구시'),('인천시'),('광주시'),('대전시'),('울산시'),('세종시'),
  ('경기도'),('강원도'),('충청도'),('전라도'),('경상도'),('제주도'),
  ('충청북'),('충청남'),('전라북'),('전라남'),('경상북'),('경상남'),
  -- 소송 · 계약 용어
  ('사업자'),('연락처'),('소외인'),('신청인'),('피신청'),('참고인'),('이해관'),('관계인'),
  ('대리인'),('담당자'),('관리자'),('책임자'),('감정인'),('감정원'),('증인석'),
  ('계약자'),('채권자'),('채무자'),('보증인'),('연대보'),('명의자'),('당사자'),
  ('원고측'),('피고측'),('원고인'),('피고인'),('법정대'),('소송대'),('변호인'),
  ('재판부'),('법원장'),('주심판'),('배석판'),
  -- 법인 형태
  ('주식회'),('유한회'),('합자회'),('합명회'),('사단법'),('재단법'),('영리법'),
  -- 문서 · 서식
  ('신청서'),('진술서'),('의견서'),('답변서'),('준비서'),('증거설'),('사실조'),
  ('계약서'),('약정서'),('합의서'),('확인서'),('공문서'),('사문서'),
  -- 금융 · 회계
  ('보증금'),('계약금'),('중도금'),('잔금일'),('원리금'),('연체이'),('대위변'),
  ('입금액'),('출금액'),('송금액'),('이체액'),('예금주'),('명의인'),
  -- 일반
  ('관련하'),('경우에'),('때문에'),('그러나'),('그리고'),('따라서'),('그런데'),
  ('마찬가'),('아니라'),('하지만'),('다음과'),('상기와'),('전술한'),('후술할'),
  ('구체적'),('명시적'),('묵시적'),('실질적'),('형식적'),('직접적'),('간접적'),
  ('일반적'),('예외적'),('원칙적'),('최종적'),('부분적'),('전체적'),
  ('가능성'),('필요성'),('타당성'),('정당성'),('위법성'),('고의성'),
  ('상당한'),('현저한'),('명백한'),('중대한'),('경미한'),
  ('국민은'),('신한은'),('우리은'),('하나은'),('기업은'),('산업은'),('농협은'),
  ('연월일'),('년월일'),('오전에'),('오후에'),('금일자'),('당일에')
on conflict (word) do nothing;


-- ════════════════════════════════════════════════════════════
-- 행정구역 접미사 — 이것으로 끝나면 이름이 아니다
-- ════════════════════════════════════════════════════════════
create or replace function slda.is_place_name(p_word text)
returns boolean
language sql immutable
as $$
  select p_word ~ '(시|도|구|군|읍|면|동|리|로|길|가|번|층|호)$';
$$;


-- ════════════════════════════════════════════════════════════
-- scan_name_ctx 교체
-- ════════════════════════════════════════════════════════════
create or replace function slda.scan_name_ctx(p_text text)
returns table (hit text, ctx text)
language plpgsql stable
as $$
declare
  v_sent text;
  v_pat  text;
  v_name text;
begin
  select '(?:' || string_agg(name, '|' order by len desc, name) || ')'
    into v_pat
  from slda.surnames;

  for v_sent in
    select s from regexp_split_to_table(p_text, '(?<=[.!?。])\s+|\n+') as s
  loop
    -- 같은 문장에 주소 표기 또는 3자리 이상 숫자가 있을 때만
    continue when not (
      v_sent ~ '(시|도|구|군|읍|면|동|리|로|길)\s*\d' or v_sent ~ '\d{3,}'
    );

    for v_name in
      select m[1]
      from regexp_matches(v_sent, '(\m' || v_pat || '[가-힣]{2}\M)', 'g') as m
    loop
      -- ① 행정구역 접미사
      continue when slda.is_place_name(v_name);
      -- ② 제외어
      continue when exists (select 1 from slda.name_stopwords w where w.word = v_name);
      -- ③ 은행명 · SNS 플랫폼명과 겹침
      continue when exists (select 1 from slda.banks b where b.name = v_name);

      hit := v_name;
      ctx := left(v_sent, 160);
      return next;
    end loop;
  end loop;
end;
$$;


-- ════════════════════════════════════════════════════════════
-- 계좌 문맥어 정리
--   '입금' '계좌' '예금' 같은 총칭은 범위가 너무 넓다.
--   같은 줄의 무관한 숫자까지 잡는다. 제거한다.
-- ════════════════════════════════════════════════════════════
delete from slda.banks where name in (
  '입금','송금','이체','계좌','예금','은행','증권',
  '국민','신한','우리','하나','기업','산업','대구','부산',
  '경남','광주','전북','제주','카카오','케이','금고'
);

-- 문맥어는 계좌를 직접 지시하는 것만 남긴다
insert into slda.banks (name) values
  ('계좌번호'),('입금계좌'),('가상계좌'),('예금주'),('송금계좌'),('이체계좌')
on conflict (name) do nothing;


-- ════════════════════════════════════════════════════════════
-- 계좌 검출 — 사업자등록번호(3-2-5)와 전화번호는 제외
-- ════════════════════════════════════════════════════════════
create or replace function slda.scan_account(p_text text)
returns table (hit text, ctx text)
language plpgsql stable
as $$
declare
  v_line text;
  v_pat  text;
  v_hit  text;
begin
  select '(?:' || string_agg(name, '|' order by length(name) desc, name) || ')'
    into v_pat
  from slda.banks;

  for v_line in
    select l from regexp_split_to_table(p_text, '(?<=[.!?。])\s+|\n+') as l
  loop
    continue when v_line !~ v_pat;

    for v_hit in
      select m[1]
      from regexp_matches(
        v_line,
        v_pat || '[^0-9\*\n]{0,20}(\m[0-9][0-9\-]{5,}[0-9]\M)',
        'g'
      ) as m
    loop
      continue when v_hit ~ '\*';
      -- 사업자등록번호 형태는 biz_no 가 잡는다
      continue when v_hit ~ '^\d{3}-\d{2}-\d{5}$';
      -- 전화번호 형태는 phone 이 잡는다
      continue when v_hit ~ '^01[016789]-\d{3,4}-\d{4}$';
      continue when v_hit ~ '^0[2-6][0-9]?-\d{3,4}-\d{4}$';

      hit := v_hit;
      ctx := left(v_line, 160);
      return next;
    end loop;
  end loop;
end;
$$;