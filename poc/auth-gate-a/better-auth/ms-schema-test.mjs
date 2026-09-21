// Experimento PD-07: tabelas do Better Auth em schema separado (contifisc_auth) com Prisma multiSchema. PoC descartavel.
// Uso: node ms-schema-test.mjs  (DATABASE_URL_MS aponta para um banco descartavel dedicado)
import fs from "node:fs";
import { execFileSync } from "node:child_process";
const out = { steps: [] };
const step = (name, ok, detail = "") => { out.steps.push({ name, ok, detail }); console.log(`${ok ? "OK  " : "FAIL"} ${name}${detail ? " :: " + detail : ""}`); };
const url = process.env.DATABASE_URL_MS;
if (!/localhost:55450\/gatea_ms/.test(url ?? "")) { console.error("ABORTADO: DATABASE_URL_MS invalido"); process.exit(2); }

// 1) schema multi-schema a partir do schema do harness
let s = fs.readFileSync("prisma/schema.prisma", "utf8");
const BA = ["User", "Session", "Account", "Verification", "TwoFactor", "Passkey"];
s = s.replace(/generator client \{[^}]*\}/, `generator client {\n  provider = "prisma-client-js"\n  output   = "../generated/ms"\n}`);
s = s.replace(/datasource db \{[^}]*\}/, `datasource db {\n  provider = "postgresql"\n  url      = env("DATABASE_URL_MS")\n  schemas  = ["public", "contifisc_auth"]\n}`);
s = s.replace(/^(model (\w+) \{[\s\S]*?)^\}/gm, (m, body, name) => `${body}  @@schema("${BA.includes(name) ? "contifisc_auth" : "public"}")\n}`);
fs.writeFileSync("prisma/schema-ms.prisma", s);
step("schema multi-schema gerado", /@@schema\("contifisc_auth"\)/.test(s), "6 modelos do provedor => contifisc_auth; tabelas CONTIFISC => public");

const run = (args) => execFileSync(process.platform === "win32" ? "npx.cmd" : "npx", args, { env: { ...process.env, DATABASE_URL_MS: url }, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], shell: process.platform === "win32" });
try { run(["prisma", "validate", "--schema", "prisma/schema-ms.prisma"]); step("prisma validate (multiSchema)", true); } catch (e) { step("prisma validate (multiSchema)", false, String(e.stderr ?? e.message).slice(0, 300)); }
try { const o = run(["prisma", "db", "push", "--schema", "prisma/schema-ms.prisma", "--skip-generate", "--accept-data-loss"]); step("prisma db push (2 schemas)", /in sync/i.test(o), o.split("\n").filter((l) => /sync|schema/i.test(l)).slice(0, 2).join(" | ")); } catch (e) { step("prisma db push (2 schemas)", false, String(e.stderr ?? e.message).slice(0, 300)); }
try { run(["prisma", "generate", "--schema", "prisma/schema-ms.prisma"]); step("prisma generate (client multiSchema)", true); } catch (e) { step("prisma generate (client multiSchema)", false, String(e.stderr ?? e.message).slice(0, 300)); }

// 2) Better Auth usando o client multiSchema
process.env.DATABASE_URL = url; // o client gerado le DATABASE_URL_MS; BA nao le a URL diretamente
const { PrismaClient } = await import("./generated/ms/index.js");
const prismaMs = new PrismaClient();
const { betterAuth } = await import("better-auth");
const { prismaAdapter } = await import("@better-auth/prisma-adapter");
const auth = betterAuth({ baseURL: "http://localhost:3400", secret: "poc-ms-secret-poc-ms-secret-poc-ms-00", database: prismaAdapter(prismaMs, { provider: "postgresql" }), emailAndPassword: { enabled: true, minPasswordLength: 12 } });
try {
  const r = await auth.api.signUpEmail({ body: { email: `ms.${Date.now()}@example.test`, password: "Correct-Horse-Battery-9!", name: "ms" }, asResponse: false });
  step("Better Auth sign-up com tabelas em contifisc_auth", !!r?.user?.id, `user.id=${(r?.user?.id ?? "").slice(0, 6)}...`);
} catch (e) { step("Better Auth sign-up com tabelas em contifisc_auth", false, String(e.message).slice(0, 250)); }
const rows = await prismaMs.$queryRaw`select table_schema, table_name from information_schema.tables where table_schema in ('public','contifisc_auth') order by 1,2`;
const bySchema = rows.reduce((a, r) => ((a[r.table_schema] ??= []).push(r.table_name), a), {});
step("tabelas por schema", (bySchema.contifisc_auth ?? []).includes("user") && !(bySchema.public ?? []).includes("user"), JSON.stringify(bySchema));
// 3) isolamento por role: role de auth sem acesso a tabelas CONTIFISC (privilegio por schema)
await prismaMs.$disconnect();
fs.writeFileSync("../results/ms-schema-result.json", JSON.stringify(out, null, 2));
