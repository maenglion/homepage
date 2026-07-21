// SLDA §14.2 — 서버측 2단 정규화 Edge Function (norm_ledger 결정적 재사용)
//
// 원칙(§14.2):
//   - 원문을 교체하지 않는다. 표기(surface)에 대한 "해석 주석(normalized)"만 산출한다.
//   - 최초 1회 산출 후 slda_norm_ledger 에 저장하고, 이후 동일 (ref, surface) 는 재사용한다(결정적).
//   - 2단 산출물은 프론트로 절대 반환하지 않는다. 이 함수는 service-role(verify_jwt=true)로만 호출된다.
//   - 미수령 원칙: 표기 문자열은 이미 라벨화·마스킹된 BLOCK 유래여야 한다(실명 금지).
//
// 요청(service-role JWT 필수):
//   POST { "ref": "LIT-...", "surfaces": ["그korea", "  ㅋㅋㅋ ", ...] }
// 응답:
//   { ref, count, reused, computed, annotations: [{ surface, normalized, reused }] }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── 결정적 표면 정규화 규칙 (의미 보존만; 해석·재구성 금지) ─────────────────
// 주: 여기는 §14.2 규칙 계층의 삽입점이다. 현재는 의미를 바꾸지 않는 안전한
//     결정적 정규화만 수행한다(공백/제로폭/과다반복 정리 + NFC). 더 풍부한
//     오타·표기변이 주석 규칙(또는 LLM 주석기)은 이 함수를 교체해 확장한다.
function normalizeSurface(raw: string): string {
  let s = String(raw);
  s = s.normalize("NFC");                 // 유니코드 정규화(결정적)
  s = s.replace(/[\u200B-\u200D\uFEFF]/g, ""); // 제로폭 문자 제거
  s = s.replace(/\s+/g, " ").trim();      // 공백 정리
  s = s.replace(/(.)\1{2,}/gu, "$1$1");   // 3회 이상 반복 문자 → 2회 (ㅋㅋㅋㅋ→ㅋㅋ)
  return s;
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
  const uniq = Array.from(new Set(surfaces.map((s) => s).filter((s) => s.trim().length)));

  const annotations: Array<{ surface: string; normalized: string; reused: boolean }> = [];
  let reused = 0;
  let computed = 0;

  for (const surface of uniq) {
    // 1) 원장 조회 → 있으면 재사용(결정적)
    const { data: hit, error: selErr } = await db
      .from("slda_norm_ledger")
      .select("normalized")
      .eq("ref", ref)
      .eq("surface", surface)
      .maybeSingle();
    if (selErr) return json({ error: "ledger_select_failed", detail: selErr.message }, 500);

    if (hit) {
      annotations.push({ surface, normalized: hit.normalized, reused: true });
      reused++;
      continue;
    }

    // 2) 최초 산출 → 저장(경합 시 unique(ref,surface) 위반은 재조회로 흡수)
    const normalized = normalizeSurface(surface);
    const { error: insErr } = await db
      .from("slda_norm_ledger")
      .insert({ ref, surface, normalized });

    if (insErr) {
      // 동시 삽입 등으로 이미 존재하면 그 값을 재사용
      const { data: again } = await db
        .from("slda_norm_ledger")
        .select("normalized")
        .eq("ref", ref)
        .eq("surface", surface)
        .maybeSingle();
      annotations.push({ surface, normalized: again?.normalized ?? normalized, reused: true });
      reused++;
      continue;
    }
    annotations.push({ surface, normalized, reused: false });
    computed++;
  }

  return json({ ref, count: annotations.length, reused, computed, annotations });
});
