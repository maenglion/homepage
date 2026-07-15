// 만료된 제출 자료를 삭제하고 status_log 에 파기 기록을 남긴다.
// Supabase Cron 으로 매일 1회 호출한다.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const storage = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
).storage.from("slda-uploads");

Deno.serve(async () => {
  const { data: due, error } = await db.rpc("due_for_purge");
  if (error) return new Response(error.message, { status: 500 });

  const result: Record<string, number> = {};

  for (const { ref } of due ?? []) {
    const { data: files } = await storage.list(ref);
    const paths = (files ?? []).map((f) => `${ref}/${f.name}`);

    if (paths.length > 0) {
      const { error: rmError } = await storage.remove(paths);
      if (rmError) {
        console.error(`purge failed: ${ref}`, rmError.message);
        continue;
      }
    }

    await db.rpc("mark_purged", { p_ref: ref, p_files: paths.length });
    result[ref] = paths.length;
  }

  return Response.json({ purged: result, at: new Date().toISOString() });
});
