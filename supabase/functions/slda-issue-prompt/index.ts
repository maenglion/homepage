// SLDA §7·§14 — 전처리(1단) 프롬프트 발급 Edge Function
//
// 목적: §7 전처리 프롬프트를 정적 번들에 하드코딩하지 않고 서버에서 "발급"한다.
//   - 1단 프롬프트(라벨화·마스킹·병합 지시)만 발급한다. 2단(정규화)·3단(채점)은 여기서 절대 노출하지 않는다.
//   - §14.4 발급 세션: 유효한 세션 토큰(slda-start-session 발급)이 있어야만 프롬프트를 내준다.
//     봇·스크래퍼 차단, 정상 유저만 수령. 토큰 없음/만료 → 401.
//   - 서버 정본이므로 프롬프트 교체는 이 함수 재배포만으로 끝난다(정적 사이트 재빌드 불필요).
//   - 미수령 원칙: 이 함수는 어떤 실명·원문도 받지 않는다. 모델 키 + 세션 토큰만 입력, 프롬프트 텍스트만 출력.
//
// 공개 함수(verify_jwt=false)지만 세션 토큰으로 게이팅한다.
// 요청:  GET  ?m=lit|sns|spk   (세션 토큰: 헤더 x-slda-session 또는 ?s=)
//        POST {"model":"lit","session":"..."}
// 응답:  { model, version, prompt }  ·  401 { error: "session_required" }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PROMPTS } from "./prompts.ts";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const VERSION = "v1"; // 프롬프트 규격 버전(§7). 갱신 시 올린다.
const MODELS = ["lit", "sns", "spk"] as const;

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-slda-session",
  "Cache-Control": "no-store",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

async function sessionValid(token: string): Promise<boolean> {
  if (!token) return false;
  const { data, error } = await db
    .from("slda_sessions")
    .select("token, expires_at")
    .eq("token", token)
    .maybeSingle();
  if (error || !data) return false;
  return new Date(data.expires_at).getTime() > Date.now();
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const url = new URL(req.url);
  let model = "";
  let session = req.headers.get("x-slda-session") || url.searchParams.get("s") || "";

  if (req.method === "GET") {
    model = url.searchParams.get("m") || "";
  } else if (req.method === "POST") {
    try {
      const b = await req.json();
      model = (b && (b.model || b.m)) || "";
      session = session || (b && (b.session || b.s)) || "";
    } catch {
      model = "";
    }
  } else {
    return json({ error: "method_not_allowed" }, 405);
  }

  // §14.4 세션 게이트
  if (!(await sessionValid(String(session).trim()))) {
    return json({ error: "session_required" }, 401);
  }

  model = String(model).toLowerCase().trim();
  if (!(MODELS as readonly string[]).includes(model)) {
    return json({ error: "unknown_model", allowed: MODELS }, 400);
  }

  return json({ model, version: VERSION, prompt: PROMPTS[model] });
});
