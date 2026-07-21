// §7 전처리 프롬프트를 클라이언트 정본(slda-pipeline.js)에서 추출해
// 프롬프트 발급 Edge Function의 서버측 정본(prompts.ts)으로 재생성한다.
// 실행: node scripts/gen-prompts.js  (저장소 루트에서)
const fs = require("fs");
const code = fs.readFileSync("public/assets/slda-pipeline.js", "utf8");
const g = {};
(new Function("window", code))(g);
const P = g.SLDA.PROMPTS;
if (!P || !P.lit || !P.sns || !P.spk) { console.error("PROMPTS 추출 실패"); process.exit(1); }
const ts =
  "// AUTO-GENERATED from public/assets/slda-pipeline.js PROMPTS (§7).\n" +
  "// 이 파일은 프롬프트 발급 Edge Function의 서버측 정본이다. 클라이언트 임베드본은 오프라인 폴백.\n" +
  "// 재생성: node scripts/gen-prompts.js\n" +
  "export const PROMPTS: Record<string, string> = " + JSON.stringify(P, null, 2) + ";\n";
fs.writeFileSync("supabase/functions/slda-issue-prompt/prompts.ts", ts);
console.log("prompts.ts 재생성 완료:", Object.keys(P).join(", "));
