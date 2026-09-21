// SUITE G — Operacao, lock-in, cadastro fechado, rate limit, dados em repouso, schema separado, Organizations.
import fs from "node:fs";
import { buildAuth, startServer, prisma } from "./lib/auth-factory.mjs";
import { Client } from "./lib/http.mjs";
import { T, ok, res, info, nc, fail, uniq, PW, results } from "./lib/t.mjs";

const G = "G-operacao";
async function newUser(tag) { const c = new Client(tag); const email = uniq(tag); const r = await c.post("/api/auth/sign-up/email", { email, password: PW, name: tag }); return { c, email, id: r.json?.user?.id }; }

export async function run() {
  // ---------- servidor 1: signup aberto (so para criar um admin e inspecionar dados) ----------
  let auth = buildAuth(); let srv = await startServer(auth);
  let admin, victim;
  try {
    admin = await newUser("adm"); await prisma.user.update({ where: { id: admin.id }, data: { role: "admin" } });
    victim = await newUser("dados");
    await T(G, "OP-01", "token de sessao em repouso: valor do cookie == session.token no banco (em claro)", async () => {
      const name = [...victim.c.jar.keys()].find((k) => k.includes("session_token")); const cookieTok = decodeURIComponent(victim.c.jar.get(name)).split(".")[0];
      const row = await prisma.session.findFirst({ where: { userId: victim.id } });
      return (row?.token === cookieTok) ? res("session.token guardado em claro: quem le a tabela session sequestra sessoes => tabela em schema/role dedicado (contifisc_auth), backup criptografado, sem acesso do runtime de dados") : ok("token nao esta em claro no banco");
    });
    await T(G, "OP-02", "hash de senha: algoritmo/formato identificaveis (portabilidade)", async () => {
      const acc = await prisma.account.findFirst({ where: { userId: victim.id, providerId: "credential" } });
      const m = /^([0-9a-f]+):([0-9a-f]+)$/.exec(acc.password ?? "");
      return m ? info(`account.password no formato salt(hex ${m[1].length / 2}B):key(hex ${m[2].length / 2}B) — scrypt customizado do Better Auth; migrar para outro provedor exige importador compativel ou reset de senha`) : info(`formato ${String(acc.password).slice(0, 4)}...`);
    });
    await T(G, "OP-03", "inventario de exportacao: tudo esta no NOSSO banco (SQL) — usuarios, hashes, TOTP(criptografado), passkeys, contas OAuth", async () => {
      const cols = await prisma.$queryRaw`select table_name, string_agg(column_name, ',' order by ordinal_position) as cols from information_schema.columns where table_schema='public' and table_name in ('user','account','twoFactor','passkey','session') group by 1 order by 1`;
      const admApi = Object.keys(auth.api).filter((k) => /export|import/i.test(k));
      return ok(`tabelas exportaveis por SELECT: ${cols.map((c) => c.table_name).join(", ")}; API de export/import nativa: ${admApi.length ? admApi.join(",") : "nenhuma"}; TOTP exige BETTER_AUTH_SECRET p/ decifrar; passkeys (credentialID+publicKey) portaveis a outro RP com o MESMO rpId/origem`);
    });
    await T(G, "OP-04", "Organizations: PoC funciona SEM plugin organization; nenhuma tabela/campo de organizacao; sessao sem activeOrganizationId", async () => {
      const t = await prisma.$queryRaw`select count(*)::int as n from information_schema.tables where table_schema='public' and table_name in ('organization','member','invitation','team','teamMember','organizationRole')`;
      const s = await victim.c.get("/api/auth/get-session");
      const semCampo = !("activeOrganizationId" in (s.json?.session ?? {}));
      return (t[0].n === 0 && semCampo) ? ok("0 tabelas de organizacao; sessao sem activeOrganizationId; nenhuma feature testada exigiu Organization") : fail(JSON.stringify({ n: t[0].n, semCampo }));
    });
    await T(G, "OP-05", "rate limit: default FORA de producao e desligado (15 tentativas erradas sem 429)", async () => {
      const c = new Client("bf"); const codes = [];
      for (let i = 0; i < 15; i++) codes.push((await c.post("/api/auth/sign-in/email", { email: victim.email, password: "senha-errada-123" })).status);
      const has429 = codes.includes(429);
      return has429 ? ok(`429 presente: ${[...new Set(codes)]}`) : res(`codigos=${[...new Set(codes)]} (sem 429) => rate limit precisa ser ligado explicitamente (rateLimit.enabled) e/ou aplicado na borda; NAO depender do default`);
    });
  } finally { await srv.close(); }

  // ---------- servidor 2: rate limit ligado ----------
  auth = buildAuth({ rateLimit: { enabled: true, window: 10, max: 5 } }); srv = await startServer(auth);
  try {
    await T(G, "OP-06", "rate limit LIGADO (window=10s,max=5): tentativas excedentes => 429", async () => {
      const c = new Client("bf2"); const codes = [];
      for (let i = 0; i < 12; i++) codes.push((await c.post("/api/auth/sign-in/email", { email: victim.email, password: "senha-errada-123" })).status);
      const n429 = codes.filter((x) => x === 429).length;
      return n429 > 0 ? ok(`${n429} de 12 tentativas => 429 (codigos: ${[...new Set(codes)]})`) : fail(`sem 429: ${[...new Set(codes)]}`);
    });
  } finally { await srv.close(); }

  // ---------- servidor 3: cadastro publico DESLIGADO (onboarding por convite/admin) ----------
  auth = buildAuth({ disableSignUp: true }); srv = await startServer(auth);
  try {
    await T(G, "OP-07", "cadastro publico desabilitado: /sign-up/email e recusado; usuarios so por criacao administrativa (server-side)", async () => {
      const c = new Client("cad"); const r = await c.post("/api/auth/sign-up/email", { email: uniq("intruso"), password: PW, name: "x" });
      const a = new Client("adm2"); await a.post("/api/auth/sign-in/email", { email: admin.email, password: PW });
      const novoEmail = uniq("convidado");
      const cr = await a.post("/api/auth/admin/create-user", { email: novoEmail, password: PW, name: "Convidado", role: "user" });
      const existe = await prisma.user.count({ where: { email: novoEmail } });
      const semIntruso = await prisma.user.count({ where: { email: { startsWith: "intruso" } } });
      return (r.status >= 400 && cr.status === 200 && existe === 1 && semIntruso === 0) ? ok(`sign-up publico=${r.status} ${r.json?.code ?? ""}; admin/create-user=${cr.status}; usuario criado so pelo admin; nenhuma conta criada por auto-cadastro (a CONTIFISC vincula ContaAcesso depois)`) : fail(JSON.stringify({ su: r.status, cr: cr.status, existe, semIntruso, txt: cr.text.slice(0, 100) }));
    });
  } finally { await srv.close(); }

  // ---------- inventario de evidencia de AAL gravada nas suites ----------
  await T(G, "OP-08", "evidencia de AAL gravada pela CONTIFISC: combinacoes metodo->nivel observadas nas suites", async () => {
    const r = await prisma.$queryRaw`select array_to_string(metodos, '+') as metodos, aal, count(*)::int as n from sessao_evidencia_auth group by 1,2 order by 1,2`;
    return info(r.map((x) => `${x.metodos}=aal${x.aal}(${x.n})`).join("; ") || "(vazio)");
  });
  await T(G, "OP-09", "versoes testadas", async () => {
    const pkg = JSON.parse(fs.readFileSync("node_modules/better-auth/package.json", "utf8"));
    const pk = JSON.parse(fs.readFileSync("node_modules/@better-auth/passkey/package.json", "utf8"));
    const pr = JSON.parse(fs.readFileSync("node_modules/prisma/package.json", "utf8"));
    return info(`better-auth=${pkg.version}; @better-auth/passkey=${pk.version}; prisma=${pr.version}; node=${process.version}; PostgreSQL 18.6 (container descartavel)`);
  });
  await T(G, "OP-10", "monitoramento/auditoria nativos do provedor", async () => info("Better Auth nao fornece trilha de auditoria de seguranca persistente: os eventos (login, falha, troca de fator, ban) precisam ser emitidos pela CONTIFISC via hooks (usados nesta PoC para AAL) e gravados em EventoAuditoriaSeguranca (DP-12). Logs do provedor sao apenas de aplicacao."));
  return results.filter((r) => r.group === G);
}
