// SLDA skills API — 서버 간 호출 전용 (§14: 2·3단 자산은 프론트에 내려가지 않는다)
// Deploy: 이 폴더를 maenglion/homepage/supabase/functions/slda-skills/ 로 복사 후, homepage 루트에서
//         supabase functions deploy slda-skills --no-verify-jwt   (프로젝트 nafpbwqdjxcftwfpadfr)
// 1단 전처리 지시문은 여기서 내려주지 않는다 — slda-issue-prompt(DB slda_prompts) 가 담당 (homepage §14.4).
// Secrets (대시보드는 소문자만 허용): slda_api_key · gh_token(Contents:read) · gh_repo=maenglion/slda-skills · gh_ref=main

const KEY = Deno.env.get("slda_api_key") ?? Deno.env.get("SLDA_API_KEY")!;
const GH_TOKEN = (Deno.env.get("gh_token") ?? Deno.env.get("GH_TOKEN"))!;
const REPO = Deno.env.get("gh_repo") ?? Deno.env.get("GH_REPO") ?? "maenglion/slda-skills";
const REF = Deno.env.get("gh_ref") ?? Deno.env.get("GH_REF") ?? "main";
// /run 전용 — LLM 키는 여기 한 곳에만. 호출 프론트는 slda_api_key 하나만 들면 된다.
const ANTHROPIC_KEY = Deno.env.get("anthropic_api_key") ?? Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const LLM_MODEL = Deno.env.get("slda_llm_model") ?? "claude-sonnet-4-5";
const SB_URL = Deno.env.get("SUPABASE_URL") ?? ""; const SB_SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const cache = new Map<string, { t: number; body: string }>();
const TTL = 5 * 60 * 1000;

async function raw(path: string): Promise<string> {
  const k = `${REF}:${path}`; const c = cache.get(k);
  if (c && Date.now() - c.t < TTL) return c.body;
  const r = await fetch(`https://raw.githubusercontent.com/${REPO}/${REF}/${path}`, { headers: { Authorization: `token ${GH_TOKEN}` } });
  if (!r.ok) throw new Error(`${path}: ${r.status}`);
  const body = await r.text(); cache.set(k, { t: Date.now(), body }); return body;
}
async function sha256(t: string) { const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(t)); return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, "0")).join(""); }
const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { "content-type": "application/json; charset=utf-8" } });

// total_king: 메타 → 스킬 배치 (결정적). 점수 없음.
function dispatch(d: any, m: { mod: string; data_class?: string; sources?: string[]; signals?: string[]; flags?: string[]; pair_id?: string; output?: string }) {
  const has = (arr: string[] | undefined, pat: string) => (arr ?? []).some(s => new RegExp(pat, "i").test(s));
  const pub = m.data_class === "public";
  const order: string[] = [...d.always_first];
  if (!pub) { order.push(d.context.case_index); if (m.pair_id) order.push(d.context.counterpart_ledger.skill); }
  if (has(m.sources, "call|audio|stt|통화")) order.push("slda-transcript");
  const mod = d.modules[m.mod]; if (!mod) throw new Error(`unknown mod: ${m.mod}`);
  if (pub && !d.data_class.public_modules.includes(m.mod)) throw new Error(`mod ${m.mod} is not a public-track module`);
  if (!pub && mod.data_class === "public") throw new Error(`mod ${m.mod} requires data_class=public (no PII input)`);
  order.push(mod.skill);
  for (const s of mod.sub ?? []) if (has(m.sources, "신청서|제출명령|사실조회|과세정보|금융거래")) order.push(s.skill);
  if (has(m.signals, "ai_mention") && ["controversy", "dispute"].includes(m.mod)) order.push("slda-ai-invocation");
  if (has(m.signals, "probe|repeat_question|silence")) order.push("slda-probe");
  if (has(m.flags, "style")) order.push("slda-stylistic-drift");
  if (/^(html|pdf)$/i.test(m.output ?? "")) order.push("slda-report-html");
  return { order: [...new Set(order)], verdict_mode: mod.verdict_mode, data_class: pub ? "public" : "private", preprocess_directive: pub ? null : (d.preprocess_directive[m.mod] ?? null) };  // 참고용 경로. 실제 발급은 slda-issue-prompt
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.headers.get("x-slda-key") !== KEY) return json({ error: "unauthorized" }, 401);
  const url = new URL(req.url); const p = url.pathname.replace(/^\/slda-skills/, "");
  try {
    if (p === "/manifest") return new Response(await raw("manifest.json"), { headers: { "content-type": "application/json" } });
    const m = p.match(/^\/skill\/(slda-[a-z-]+)$/);
    if (m) return new Response(await raw(`${m[1]}/SKILL.md`), { headers: { "content-type": "text/markdown; charset=utf-8" } });
    if (p === "/rubrics") return new Response(await raw("rubrics.json"), { headers: { "content-type": "application/json" } });
    if (p === "/dispatch" && req.method === "POST") {
      const meta = await req.json(); const d = JSON.parse(await raw("dispatch.json")); const R = JSON.parse(await raw("rubrics.json"));
      const plan = dispatch(d, meta);
      const rubrics = [...new Set([...(R.by_module[meta.mod] ?? []), ...plan.order.flatMap((s: string) => R.overlay_rubrics[s] ?? [])])].sort();
      (plan as any).rubrics = rubrics;
      const bundle = meta.bundle ? (await Promise.all(plan.order.map(s => raw(`${s}/SKILL.md`)))).join("\n\n---\n\n") : undefined;
      return json({ ...plan, dispatch_version: d.version, bundle });
    }
    if (p === "/run" && req.method === "POST") {
      // dispatch → LLM → slda_runs 저장. public 트랙 전용 (private 입력은 받지 않는다 — 미수령 원칙).
      const body = await req.json();
      if (body.data_class !== "public") return json({ error: "run accepts data_class=public only" }, 400);
      if (!ANTHROPIC_KEY) return json({ error: "anthropic_api_key secret not set" }, 500);
      const d = JSON.parse(await raw("dispatch.json")); const R = JSON.parse(await raw("rubrics.json"));
      const plan = dispatch(d, body);
      const rubrics = [...new Set([...(R.by_module[body.mod] ?? []), ...plan.order.flatMap((s: string) => R.overlay_rubrics[s] ?? [])])].sort();
      const bundle = (await Promise.all(plan.order.map(s => raw(`${s}/SKILL.md`)))).join("\n\n---\n\n");
      const system = `${bundle}\n\n[RUN META] mod=${body.mod} verdict_mode=${plan.verdict_mode} rubrics=${rubrics.join(",")} dispatch_version=${d.version}`;
      const t0 = Date.now();
      const r = await fetch("https://api.anthropic.com/v1/messages", { method: "POST",
        headers: { "x-api-key": ANTHROPIC_KEY, "anthropic-version": "2023-06-01", "content-type": "application/json" },
        body: JSON.stringify({ model: LLM_MODEL, max_tokens: body.max_tokens ?? 8000, system, messages: [{ role: "user", content: body.input }] }) });
      const out = await r.json(); if (!r.ok) return json({ error: "llm", detail: out }, 502);
      const text = (out.content ?? []).map((c: any) => c.text ?? "").join("");
      const row = { mod: body.mod, data_class: "public", order: plan.order, rubrics, verdict_mode: plan.verdict_mode, dispatch_version: d.version,
        model: LLM_MODEL, input_sha256: await sha256(body.input), input_bytes: body.input.length, output: text,
        usage: out.usage ?? null, ms: Date.now() - t0, caller: body.caller ?? null, label: body.label ?? null };
      let run_id: string | null = null;
      if (SB_URL && SB_SRK) {
        const ins = await fetch(`${SB_URL}/rest/v1/slda_runs`, { method: "POST", headers: { apikey: SB_SRK, Authorization: `Bearer ${SB_SRK}`, "content-type": "application/json", Prefer: "return=representation" }, body: JSON.stringify(row) });
        if (ins.ok) run_id = (await ins.json())[0]?.id ?? null;
      }
      return json({ run_id, ...row, output: body.return_output === false ? undefined : text });
    }
    return json({ error: "not found", routes: ["GET /manifest", "GET /rubrics", "GET /skill/:name", "POST /dispatch {mod,sources,signals,flags,pair_id,output,bundle}", "POST /run {mod,data_class:'public',input,label?,caller?,max_tokens?}"] }, 404);
  } catch (e) { return json({ error: String(e) }, 500); }
});
