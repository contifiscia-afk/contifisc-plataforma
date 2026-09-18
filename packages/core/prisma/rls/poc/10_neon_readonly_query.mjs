// Helper de consulta ao Neon DEV (somente leitura por convencao). Nao imprime a connection string.
// Helper de consulta ao Neon DEV. NUNCA imprime a connection string.
// uso: node neon_q.mjs <arquivo.sql> [direct|pooled] [ro|rw]
// arquivo.sql: consultas separadas por linhas "-- ;;" ; cada consulta pode ter um titulo "-- @ titulo" na 1a linha.
import fs from "node:fs";
import { PrismaClient } from "file:///C:/Dev/Contifisc_Plataforma/node_modules/@prisma/client/index.js";

const [file, mode = "direct", rw = "ro"] = process.argv.slice(2);
const env = {};
for (const l of fs.readFileSync("C:/Dev/Contifisc_Plataforma/.env", "utf8").split(/\r?\n/)) {
  const m = l.match(/^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/);
  if (m) env[m[1]] = m[2];
}
let url = env.DATABASE_URL;
if (mode === "pooled") {
  if (env.DATABASE_URL_POOLED) url = env.DATABASE_URL_POOLED;
  else url = url.replace(/(@ep-[a-z0-9-]+?)(\.c-)/, "$1-pooler$2");
}
const prisma = new PrismaClient({ datasources: { db: { url } } });
const ser = (v) => JSON.parse(JSON.stringify(v, (k, x) => (typeof x === "bigint" ? Number(x) : x)));
const blocks = fs.readFileSync(file, "utf8").split(/^-- ;;\s*$/m).map((s) => s.trim()).filter(Boolean);
try {
  for (const b of blocks) {
    const t = b.match(/^-- @ (.*)$/m);
    const body = b.replace(/^--.*$/gm, "").trim();
    console.log("### " + (t ? t[1] : "q"));
    if (/^(select|with)\b/i.test(body)) {
      console.log(JSON.stringify(ser(await prisma.$queryRawUnsafe(b))));
    } else {
      console.log("exec ok, affected=" + (await prisma.$executeRawUnsafe(b)));
    }
  }
} catch (e) {
  console.log("ERRO: " + String(e.message).replace(/postgres(ql)?:\/\/\S+/g, "<url>").slice(0, 800));
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}

