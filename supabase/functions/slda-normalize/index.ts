// SLDA §14.2 · §16.1 — 서버측 2단 정규화 Edge Function (norm_ledger 결정적 재사용)
//
// 원칙:
//   - 원문을 교체하지 않는다. 표기(surface)에 대한 "해석 주석(normalized)"만 산출한다.
//   - 정규화는 2계층이다:
//       1) 규칙표(확정·결정적) — §16.1 1차. 표기변이 매핑 + 안전한 결정적 정리(NFC/공백/반복).
//          전부 재현성 100%. 원장(slda_norm_ledger)에 저장·재사용, source='variant-rule'|'passthrough'.
//       2) LLM 후보(가능성·참고) — §16.1 2차. 규칙표가 못 잡은 잔여분에 대한 "후보"만 제시.
//          확정 아님 · 원장에 저장하지 않음 · 채점에 사용하지 않음. 운영자가 규칙표로 승격하면 확정이 된다.
//          기본 비활성(삽입점만 유지). 활성 시에도 응답의 candidates[]로만 내려간다.
//   - 채점(3단)은 확정 정규화(원장)만 사용한다. 비결정성이 채점에 새어들지 않는다.
//   - 2단 산출물은 프론트로 반환되지 않는다. 이 함수는 service-role(verify_jwt=true)로만 호출된다.
//   - 미수령 원칙: 표기 문자열은 이미 라벨화·마스킹된 BLOCK 유래여야 한다(실명 금지).
//   - LIT(소송)에는 표기변이 정규화를 적용하지 않는다(§14.2) — 호출측이 SNS/SPK만 넘긴다.
//
// 요청(service-role JWT 필수):
//   POST { "ref": "LIT-...", "surfaces": ["그korea", "  ㅋㅋㅋ ", ...] }
// 응답:
//   { ref, count, reused, computed,
//     annotations: [{ surface, normalized, source, reused }],   // 확정(원장)
//     candidates:  [{ surface, suggestion, source: 'llm-candidate' }] }  // 참고(미저장). 비활성 시 []

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── 1) §14.2 표기변이 규칙표 (확정·결정적) ────────────────────────────────
// 자주 나오는 오타·자모분리·표기변이를 결정적으로 확정 치환한다. 재현성 100%.
// 여기가 규칙표의 성장점이다 — CBT(§16.2)에서 검증된 변이를 계속 추가한다.
// 의미를 바꾸는 재작성은 금지. 동일 의미의 표기 통일만.
const VARIANT_MAP: Record<string, string> = {
  "그korea": "그러니까",   // §14.2 예시 (자판 전환 오타)
  "머라고": "뭐라고",
  "뭐라구": "뭐라고",
  "그니까": "그러니까",
  "그까": "그러니까",
  "알겟어": "알겠어",
  "됫어": "됐어",
  "안됀다": "안 된다",
};

// 안전한 결정적 정리(의미 보존만). 규칙표 적용 전 공통 전처리.
function deterministicClean(raw: string): string {
  let s = String(raw);
  s = s.normalize("NFC");                        // 유니코드 정규화
  s = s.replace(/[\u200B-\u200D\uFEFF]/g, "");   // 제로폭 문자 제거
  s = s.replace(/\s+/g, " ").trim();             // 공백 정리
  s = s.replace(/(.)\1{2,}/gu, "$1$1");          // 3회+ 반복 → 2회 (ㅋㅋㅋㅋ→ㅋㅋ)
  return s;
}

// 확정 정규화: {normalized, source}. source='variant-rule' 이면 규칙표가 잡은 것,
// 'passthrough' 이면 규칙표 미해당(일반 정리만).
function ruleNormalize(raw: string): { normalized: string; source: string } {
  const cleaned = deterministicClean(raw);
  if (Object.prototype.hasOwnProperty.call(VARIANT_MAP, cleaned)) {
    return { normalized: VARIANT_MAP[cleaned], source: "variant-rule" };
  }
  return { normalized: cleaned, source: "passthrough" };
}

// ── 2) LLM 후보 삽입점 (가능성·참고 · 기본 비활성) ───────────────────────
// 규칙표가 못 잡은(=passthrough) 표기에 대해서만 "후보"를 제시한다.
// 확정 아님 · 원장 미저장 · 채점 미사용. 활성화하려면 LLM 호출을 여기 구현하고,
// 반환 배열의 각 원소를 candidates[] 로 내려보낸다(운영자 검토 → 규칙표 승격).
const LLM_CANDIDATES_ENABLED = false;
async function llmCandidates(
  _surfaces: string[],
): Promise<Array<{ surface: string; suggestion: string }>> {
  if (!LLM_CANDIDATES_ENABLED) return [];
  // 삽입점: 여기서 규칙표 미해당 표기에 대한 LLM 주석 후보를 생성한다.
  // 반드시 "후보"로만 — 확정·저장·채점 금지.
  return [];
}

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let ref = "";
  let surfaces: string[] = [];
  try {
    const b = await req.json();
    ref = String(b?.ref || "").trim();
    surfaces = Array.isArray(b?.surfaces) ? b.surfaces.map((x: unknown) => String(x)) : [];
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  if (!ref) return json({ error: "ref_required" }, 400);

  // 중복 표기 제거(공백만 있는 것 제외)
  const uniq = Array.from(new Set(surfaces.filter((s) => s.trim().length)));

  const annotations: Array<{ surface: string; normalized: string; source: string; reused: boolean }> = [];
  const unresolved: string[] = []; // 규칙표 미해당(passthrough) → LLM 후보 대상
  let reused = 0;
  let computed = 0;

  for (const surface of uniq) {
    // 1) 원장 조회 → 있으면 재사용(결정적)
    const { data: hit, error: selErr } = await db
      .from("slda_norm_ledger")
      .select("normalized, source")
      .eq("ref", ref)
      .eq("surface", surface)
      .maybeSingle();
    if (selErr) return json({ error: "ledger_select_failed", detail: selErr.message }, 500);

    if (hit) {
      annotations.push({ surface, normalized: hit.normalized, source: hit.source ?? "passthrough", reused: true });
      if ((hit.source ?? "passthrough") === "passthrough") unresolved.push(surface);
      reused++;
      continue;
    }

    // 2) 최초 산출(확정 규칙표) → 저장. 경합 시 unique(ref,surface) 위반은 재조회로 흡수.
    const { normalized, source } = ruleNormalize(surface);
    const { error: insErr } = await db
      .from("slda_norm_ledger")
      .insert({ ref, surface, normalized, source });

    if (insErr) {
      const { data: again } = await db
        .from("slda_norm_ledger")
        .select("normalized, source")
        .eq("ref", ref)
        .eq("surface", surface)
        .maybeSingle();
      annotations.push({
        surface,
        normalized: again?.normalized ?? normalized,
        source: again?.source ?? source,
        reused: true,
      });
      if ((again?.source ?? source) === "passthrough") unresolved.push(surface);
      reused++;
      continue;
    }
    annotations.push({ surface, normalized, source, reused: false });
    if (source === "passthrough") unresolved.push(surface);
    computed++;
  }

  // 규칙표가 못 잡은 잔여분에 대해서만 LLM 후보(참고·미저장)
  const candidates = (await llmCandidates(unresolved)).map((c) => ({ ...c, source: "llm-candidate" }));

  return json({ ref, count: annotations.length, reused, computed, annotations, candidates });
});
