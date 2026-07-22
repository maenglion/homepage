// SLDA §14.4 — 발급 세션 시작 Edge Function (공개)
//
// 목적: 플로우 시작 시 짧은 수명의 세션 토큰을 발급한다.
//   slda-issue-prompt 는 이 토큰이 있어야만 1단 프롬프트를 내준다(봇·스크래퍼 차단).
//   토큰은 실명·개인정보와 무관한 난수이며 slda_sessions 에 저장된다.
//
// 공개(verify_jwt=false). 요청: POST → 응답: { token, expires_at }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

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

function randomToken(bytes = 24): string {
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  let out = "";
  for (const b of arr) out += b.toString(16).padStart(2, "0");
  return out;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // 기회주의적 만료 정리(가벼움)
  await db.from("slda_sessions").delete().lt("expires_at", new Date().toISOString());

  const token = randomToken();
  const { data, error } = await db
    .from("slda_sessions")
    .insert({ token })
    .select("token, expires_at")
    .single();

  if (error) return json({ error: "session_create_failed", detail: error.message }, 500);
  return json({ token: data.token, expires_at: data.expires_at });
});
