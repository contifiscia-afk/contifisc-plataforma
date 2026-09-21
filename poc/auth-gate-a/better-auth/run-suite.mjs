// Executa uma suite: node run-suite.mjs <a|b|c|d|e|g> ; grava results/betterauth-<suite>.json
import { save, results } from "./lib/t.mjs";
import { prisma } from "./lib/auth-factory.mjs";
// Reset do banco DESCARTAVEL do PoC (trava: so roda se DATABASE_URL apontar para localhost:55450).
if (!/localhost:55450\//.test(process.env.DATABASE_URL ?? "")) { console.error("ABORTADO: DATABASE_URL nao e o PG descartavel do PoC"); process.exit(2); }
{
  const rows = await prisma.$queryRaw`select tablename from pg_tables where schemaname='public'`;
  if (rows.length) await prisma.$executeRawUnsafe(`TRUNCATE ${rows.map((x) => `"${x.tablename}"`).join(", ")} RESTART IDENTITY CASCADE`);
}
const which = process.argv[2];
const files = { a: "./suite-a-identity.mjs", b: "./suite-b-session.mjs", c: "./suite-c-mfa.mjs", d: "./suite-d-oauth.mjs", e: "./suite-e-passkey.mjs", g: "./suite-g-ops.mjs" };
try {
  const m = await import(files[which]);
  await m.run();
} catch (e) { console.log("SUITE ERRO:", String(e.stack ?? e).slice(0, 600)); process.exitCode = 1; }
finally {
  save(`../results/betterauth-${which}.json`);
  const c = results.reduce((a, r) => (a[r.status] = (a[r.status] ?? 0) + 1, a), {});
  console.log("== RESUMO suite", which, JSON.stringify(c));
  await prisma.$disconnect();
}


