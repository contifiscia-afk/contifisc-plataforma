// Smoke tests S01-S17 da RLS no Neon DEV. Somente dados sinteticos. NUNCA imprime a connection string.
// Le DATABASE_URL do .env. Revisado na 6a sessao (regex ADR-C005/C014 estritos; setup e teardown com janela
// atomica de membership no mediator; DROP OWNED BY removido). Ver RLS_NEON_DEPLOYMENT_REPORT.md, ADENDO 6.
// uso: node 09_neon_smoke_s01_s17.mjs <setup|fixture|run|cleanup|teardown-role> [direct|pooled]
//   setup          cria contifisc_smoke_runtime (NOLOGIN, NOBYPASSRLS), grants minimos e EXECUTE nas 2 funcoes SD
//                  (EXECUTE exige agir como o mediator: janela GRANT->SET LOCAL ROLE->REVOKE numa transacao)
//   fixture        carrega a fixture sintetica (aborta se o banco nao estiver vazio)
//   run            suite S01-S17 no endpoint escolhido (direct|pooled)
//   cleanup        TRUNCATE das 25 tabelas de negocio (nunca _prisma_migrations) e confirma 0 linhas
//   teardown-role  remove o role de teste e seus grants
import fs from "node:fs";
import { PrismaClient } from "file:///C:/Dev/Contifisc_Plataforma/node_modules/@prisma/client/index.js";

const [cmd, mode = "direct"] = process.argv.slice(2);
const env = {};
for (const l of fs.readFileSync("C:/Dev/Contifisc_Plataforma/.env", "utf8").split(/\r?\n/)) {
  const m = l.match(/^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/);
  if (m) env[m[1]] = m[2];
}
function buildUrl(m, extra = "") {
  let u = env.DATABASE_URL;
  if (m === "pooled") {
    u = u.replace(/(@ep-[a-z0-9-]+?)(\.c-)/, "$1-pooler$2");
    if (!/pgbouncer=/.test(u)) u += (u.includes("?") ? "&" : "?") + "pgbouncer=true";
  }
  if (extra) u += (u.includes("?") ? "&" : "?") + extra;
  return u;
}
const isPooledHost = (u) => /@ep-[a-z0-9-]+-pooler\./.test(u);
const mk = (m, extra) => new PrismaClient({ datasources: { db: { url: buildUrl(m, extra) } } });
const prisma = mk(mode);
const clean = (s) => String(s).replace(/postgres(ql)?:\/\/\S+/g, "<url>").replace(/\s+/g, " ").slice(0, 230);

const TA = "aaaaaaaa-0000-0000-0000-00000000000a", TB = "bbbbbbbb-0000-0000-0000-00000000000b";
const CA = "cccccccc-0000-0000-0000-0000000000aa", CB = "cccccccc-0000-0000-0000-0000000000bb", CC = "cccccccc-0000-0000-0000-0000000000cc";
const UEA = "eeeeeeee-0000-0000-0000-00000000000a", UEB = "eeeeeeee-0000-0000-0000-00000000000b";
const ROLE = "contifisc_smoke_runtime";
const sfx = mode === "pooled" ? "9b" : "9a"; // ids exclusivos por modo (evita colisao S09/S12 entre direct e pooled)
const id = (p, n) => `${p}000000-0000-0000-0000-00000000${n}${sfx}`;

class RB extends Error { constructor(r) { super("ROLLBACK_PROPOSITAL"); this.result = r; } }
async function asRuntime(fn, { tenant, conta, commit = false, db = prisma } = {}) {
  try {
    return await db.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(`SET LOCAL ROLE ${ROLE}`);
      if (tenant !== undefined) await tx.$executeRawUnsafe(`SET LOCAL app.current_tenant_id = '${tenant}'`);
      if (conta !== undefined) await tx.$executeRawUnsafe(`SET LOCAL app.current_conta_acesso_id = '${conta}'`);
      const r = await fn(tx);
      if (!commit) throw new RB(r);
      return r;
    }, { timeout: 30000, maxWait: 30000 });
  } catch (e) {
    if (e instanceof RB) return e.result;
    if (e && e.cause instanceof RB) return e.cause.result;
    throw e;
  }
}
const q = (tx, sql) => tx.$queryRawUnsafe(sql);
const ids = async (tx, tbl, where = "true") => (await q(tx, `select id::text as id from ${tbl} where ${where} order by 1`)).map((r) => r.id);
const cnt = async (tx, tbl, where = "true") => (await q(tx, `select count(*)::int as n from ${tbl} where ${where}`))[0].n;
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
async function expectErr(p, re) { try { await p; return { ok: false, msg: "NAO ERROU" }; } catch (e) { const m = clean(e.message); return { ok: re.test(m), msg: m }; } }

const results = [];
async function T(name, fn) {
  try {
    const r = await fn();
    const ok = r === true || (r && r.ok);
    results.push({ name, ok, detail: r && r.detail ? r.detail : "" });
    console.log(`${ok ? "PASS" : "FAIL"} ${name}${r && r.detail ? " :: " + r.detail : ""}`);
  } catch (e) {
    results.push({ name, ok: false, detail: clean(e.message) });
    console.log(`FAIL ${name} :: EXCECAO ${clean(e.message)}`);
  }
}

// ---------------------------------------------------------------- comandos
const SD_FUNCS = "public.contifisc_conta_tem_acesso_tenant(uuid, uuid), public.contifisc_vinculo_tem_extremidade_no_tenant(uuid, uuid)";
async function setup() {
  // tudo numa unica transacao: se qualquer passo falhar, nada persiste
  await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe(`CREATE ROLE ${ROLE} NOSUPERUSER NOLOGIN NOBYPASSRLS NOCREATEROLE NOCREATEDB NOINHERIT`);
    await tx.$executeRawUnsafe(`GRANT ${ROLE} TO neondb_owner WITH SET TRUE, INHERIT FALSE`); // permite SET LOCAL ROLE nos testes
    await tx.$executeRawUnsafe(`GRANT USAGE ON SCHEMA public TO ${ROLE}`);
    const tabs = await tx.$queryRawUnsafe(`select tablename from pg_tables where schemaname='public' and tablename<>'_prisma_migrations' order by 1`);
    for (const t of tabs) await tx.$executeRawUnsafe(`GRANT SELECT, INSERT, UPDATE, DELETE ON public.${t.tablename} TO ${ROLE}`);
    // EXECUTE nas funcoes SD: o dono e o mediator -> janela atomica GRANT -> SET LOCAL ROLE -> operacao -> RESET -> REVOKE
    await tx.$executeRawUnsafe("GRANT contifisc_rls_mediator TO neondb_owner WITH SET TRUE, INHERIT FALSE");
    await tx.$executeRawUnsafe("SET LOCAL ROLE contifisc_rls_mediator");
    await tx.$executeRawUnsafe(`GRANT EXECUTE ON FUNCTION ${SD_FUNCS} TO ${ROLE}`);
    await tx.$executeRawUnsafe("RESET ROLE");
    await tx.$executeRawUnsafe("REVOKE contifisc_rls_mediator FROM neondb_owner");
  }, { timeout: 60000 });
  console.log("setup ok (role de teste criado; janela de membership no mediator concedida e revogada na mesma transacao)");
}

async function fixture() {
  const nz = await prisma.$queryRawUnsafe(`select sum((xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text::int)::int as n from information_schema.tables where table_schema='public' and table_type='BASE TABLE' and table_name<>'_prisma_migrations'`);
  if (nz[0].n !== 0) throw new Error("banco NAO esta vazio; abortando fixture");
  const sql = fs.readFileSync("C:/Dev/Contifisc_Plataforma/packages/core/prisma/rls/poc/01_fixture.sql", "utf8")
    .split(/\r?\n/).map((l) => l.replace(/--.*$/, "")).filter((l) => l.trim() !== "").join("\n"); // remove comentarios (inclusive no fim da linha)
  const stmts = sql.split(/;\s*\n/).map((s) => s.trim()).filter(Boolean);
  await prisma.$transaction(async (tx) => { for (const s of stmts) await tx.$executeRawUnsafe(s); }, { timeout: 60000 });
  console.log(`fixture ok (${stmts.length} statements, 1 transacao)`);
}

async function cleanup() {
  const tabs = (await prisma.$queryRawUnsafe(`select tablename from pg_tables where schemaname='public' and tablename<>'_prisma_migrations' order by 1`)).map((r) => r.tablename);
  await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${tabs.map((t) => `public.${t}`).join(", ")} RESTART IDENTITY CASCADE`);
  const n = await prisma.$queryRawUnsafe(`select sum((xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text::int)::int as n from information_schema.tables where table_schema='public' and table_type='BASE TABLE' and table_name<>'_prisma_migrations'`);
  console.log(`cleanup ok; total de linhas de negocio restantes = ${n[0].n}`);
}

async function teardownRole() {
  // numa transacao: revoga os grants concedidos pelo owner (tabelas/schema) e, via janela atomica no mediator,
  // o EXECUTE nas funcoes SD (grantor = mediator); depois DROP ROLE. Falha => nada persiste.
  await prisma.$transaction(async (tx) => {
    const tabs = await tx.$queryRawUnsafe(`select tablename from pg_tables where schemaname='public' and tablename<>'_prisma_migrations' order by 1`);
    for (const t of tabs) await tx.$executeRawUnsafe(`REVOKE ALL ON public.${t.tablename} FROM ${ROLE}`);
    await tx.$executeRawUnsafe(`REVOKE ALL ON SCHEMA public FROM ${ROLE}`);
    await tx.$executeRawUnsafe("GRANT contifisc_rls_mediator TO neondb_owner WITH SET TRUE, INHERIT FALSE");
    await tx.$executeRawUnsafe("SET LOCAL ROLE contifisc_rls_mediator");
    await tx.$executeRawUnsafe(`REVOKE EXECUTE ON FUNCTION ${SD_FUNCS} FROM ${ROLE}`);
    await tx.$executeRawUnsafe("RESET ROLE");
    await tx.$executeRawUnsafe("REVOKE contifisc_rls_mediator FROM neondb_owner");
    await tx.$executeRawUnsafe(`DROP ROLE ${ROLE}`);
  }, { timeout: 60000 });
  console.log("teardown-role ok (role de teste removido; janela de membership no mediator revogada)");
}

// ---------------------------------------------------------------- suite
async function run() {
  const url = buildUrl(mode);
  console.log(`# modo=${mode} host_pooler=${isPooledHost(url)}`);
  const tenantTabs = ["receita", "unidade_economica", "arquivo_origem", "documento_fiscal", "cenario_tributario", "resultado_calculo", "conflito_dado", "revisao_tecnica", "tenant"];

  await T("S01 Tenant A acessa proprio tenant", () => asRuntime(async (tx) => {
    const r = await ids(tx, "receita"), ue = await ids(tx, "unidade_economica"), tn = await ids(tx, "tenant");
    const doc = await cnt(tx, "documento_fiscal"), ar = await cnt(tx, "arquivo_origem");
    const ok = eq(r.filter((x) => x.startsWith("11111111")), ["11111111-0000-0000-0000-00000000000a"]) && eq(ue, [UEA]) && eq(tn, [TA]) && doc === 1 && ar === 1;
    return { ok, detail: `receitaA=${r.length} ue=${ue.length} tenant=${tn.length} doc=${doc} arq=${ar}` };
  }, { tenant: TA, conta: CA }));

  await T("S02 Tenant A nao acessa Tenant B", () => asRuntime(async (tx) => {
    const c = [];
    c.push(await cnt(tx, "receita", "id='11111111-0000-0000-0000-00000000000b'"));
    c.push(await cnt(tx, "unidade_economica", `id='${UEB}'`));
    c.push(await cnt(tx, "arquivo_origem", "id='22222222-0000-0000-0000-00000000000b'"));
    c.push(await cnt(tx, "documento_fiscal", "id='33333333-0000-0000-0000-00000000000b'"));
    c.push(await cnt(tx, "cenario_tributario", "id='cc000000-0000-0000-0000-00000000000b'"));
    c.push(await cnt(tx, "conflito_dado", "id='77777777-0000-0000-0000-00000000000b'"));
    c.push(await cnt(tx, "revisao_tecnica", "id='99999999-0000-0000-0000-00000000000b'"));
    c.push(await cnt(tx, "tenant", `id='${TB}'`));
    return { ok: c.every((x) => x === 0), detail: `contagens cross-tenant=${c.join(",")}` };
  }, { tenant: TA, conta: CA }));

  await T("S03 Conta sem concessao (Conta C)", () => asRuntime(async (tx) => {
    const a = await cnt(tx, "tenant");
    return { ok: a === 0, detail: `tenants visiveis=${a}` };
  }, { conta: CC })
    .then(async (r1) => {
      const r2 = await asRuntime(async (tx) => cnt(tx, "tenant"), { tenant: TA, conta: CC });
      return { ok: r1.ok && r2 === 0, detail: `${r1.detail}; com tenant A + conta C tenants=${r2}` };
    }));

  await T("S04 contexto ausente fail-closed", () => asRuntime(async (tx) => {
    const z = [];
    for (const t of [...tenantTabs, "vinculo", "vinculo_extremidade", "conta_acesso_tenant", "conta_acesso_unidade_economica", "evento_auditoria_seguranca"]) z.push([t, await cnt(tx, t)]);
    const pf = await cnt(tx, "pessoa_fisica");
    const g = (await q(tx, `select current_setting('app.current_tenant_id', true) as t`))[0].t;
    const bad = z.filter(([, n]) => n !== 0);
    return { ok: bad.length === 0 && pf === 1, detail: `tabelas>0: ${JSON.stringify(bad)}; pessoa_fisica(global)=${pf}; GUC=${JSON.stringify(g)}` };
  }, {}));

  await T("S05 contexto invalido fail-closed (sem erro)", async () => {
    const outs = [];
    for (const [t, c] of [["not-a-uuid", "xyz"], ["", ""], ["null", "null"], ["aaaaaaaa-0000-0000-0000-00000000000", "zzzzzzzz-0000-0000-0000-0000000000aa"]]) {
      outs.push(await asRuntime(async (tx) => (await cnt(tx, "receita")) + (await cnt(tx, "tenant")) + (await cnt(tx, "unidade_economica")), { tenant: t, conta: c }));
    }
    return { ok: outs.every((x) => x === 0), detail: `linhas por contexto invalido=${outs.join(",")}` };
  });

  await T("S06 INSERT proprio permitido", () => asRuntime(async (tx) => {
    await tx.$executeRawUnsafe(`insert into receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id) values ('${id("f6", "06")}', 5.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', '${UEA}')`);
    await tx.$executeRawUnsafe(`insert into arquivo_origem (id, hash_conteudo, armazenamento_referencia, registrado_em, tenant_id) values ('${id("f7", "06")}', 'h-smoke', 'r-smoke', now(), '${TA}')`);
    const n = await cnt(tx, "receita", `id='${id("f6", "06")}'`), m = await cnt(tx, "arquivo_origem", `id='${id("f7", "06")}'`);
    return { ok: n === 1 && m === 1, detail: `inseridas visiveis: receita=${n} arquivo=${m}` };
  }, { tenant: TA, conta: CA }));

  await T("S07 INSERT cross-tenant bloqueado", async () => {
    const re = /row-level security|violates row-level/i;
    const a = await expectErr(asRuntime((tx) => tx.$executeRawUnsafe(`insert into receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id) values ('${id("f6", "07")}', 5.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', '${UEB}')`), { tenant: TA, conta: CA }), re);
    const b = await expectErr(asRuntime((tx) => tx.$executeRawUnsafe(`insert into unidade_economica (id, nome, status_registro, criado_em, atualizado_em, tenant_id) values ('${id("f8", "07")}', 'x', 'ATIVO', now(), now(), '${TB}')`), { tenant: TA, conta: CA }), re);
    const c = await expectErr(asRuntime((tx) => tx.$executeRawUnsafe(`insert into arquivo_origem (id, hash_conteudo, armazenamento_referencia, registrado_em, tenant_id) values ('${id("f7", "07")}', 'h', 'r', now(), '${TB}')`), { tenant: TA, conta: CA }), re);
    return { ok: a.ok && b.ok && c.ok, detail: `receita:${a.ok} ue:${b.ok} arquivo:${c.ok}${a.ok && b.ok && c.ok ? "" : " msgs=" + [a.msg, b.msg, c.msg].join(" | ")}` };
  });

  await T("S08 UPDATE/DELETE cross-tenant bloqueado", async () => {
    const r = await asRuntime(async (tx) => {
      const upB = await tx.$executeRawUnsafe(`update receita set valor_receita_bruta = 9 where id='11111111-0000-0000-0000-00000000000b'`);
      const delB = await tx.$executeRawUnsafe(`delete from receita where id='11111111-0000-0000-0000-00000000000b'`);
      const upA = await tx.$executeRawUnsafe(`update receita set valor_receita_bruta = 9 where id='11111111-0000-0000-0000-00000000000a'`);
      return [upB, delB, upA];
    }, { tenant: TA, conta: CA });
    const mv = await expectErr(asRuntime((tx) => tx.$executeRawUnsafe(`update unidade_economica set tenant_id='${TB}' where id='${UEA}'`), { tenant: TA, conta: CA }), /row-level security/i);
    const own = await q(prisma, `select valor_receita_bruta::text as v from receita where id='11111111-0000-0000-0000-00000000000b'`);
    return { ok: eq(r, [0, 0, 1]) && mv.ok && own[0] && own[0].v === "2000.00", detail: `afetadas(upB,delB,upA)=${r}; mover UE p/ tenant B bloqueado=${mv.ok}; receitaB intacta=${own[0] && own[0].v}` };
  });

  await T("S09 Vinculo novo valido (+ADR-C005)", async () => {
    const v = id("aa", "09"), e1 = id("ab", "0a"), e2 = id("ab", "0b");
    await asRuntime(async (tx) => {
      await tx.$executeRawUnsafe(`insert into vinculo (id, tipo_vinculo, registrado_em) values ('${v}', 'SOCIETARIO', now())`);
      await tx.$executeRawUnsafe(`insert into vinculo_extremidade (id, vinculo_id, lado_extremidade, unidade_economica_id, registrado_em) values ('${e1}', '${v}', 'ORIGEM', '${UEA}', now()), ('${e2}', '${v}', 'DESTINO', '${UEA}', now())`);
      return true;
    }, { tenant: TA, conta: CA, commit: true });
    const visA = await asRuntime((tx) => cnt(tx, "vinculo", `id='${v}'`), { tenant: TA, conta: CA });
    const visB = await asRuntime((tx) => cnt(tx, "vinculo", `id='${v}'`), { tenant: TB, conta: CB });
    // ADR-C005: vinculo com 1 unica extremidade deve falhar no COMMIT (constraint trigger deferrable)
    const v2 = id("aa", "08");
    const neg = await expectErr(asRuntime(async (tx) => {
      await tx.$executeRawUnsafe(`insert into vinculo (id, tipo_vinculo, registrado_em) values ('${v2}', 'SOCIETARIO', now())`);
      await tx.$executeRawUnsafe(`insert into vinculo_extremidade (id, vinculo_id, lado_extremidade, unidade_economica_id, registrado_em) values ('${id("ab", "0c")}', '${v2}', 'ORIGEM', '${UEA}', now())`);
      return true;
    }, { tenant: TA, conta: CA, commit: true }), /ADR-C005/);
    const persisted = await cnt(prisma, "vinculo", `id='${v2}'`);
    return { ok: visA === 1 && visB === 0 && neg.ok && persisted === 0, detail: `criado e visivel A=${visA}, invisivel B=${visB}; ADR-C005 (1 extremidade) rejeitado=${neg.ok} persistiu=${persisted}; msg="${neg.msg.slice(0, 90)}"` };
  });

  await T("S10 Vinculo cross-tenant bloqueado", async () => {
    const v = id("aa", "10");
    const both = await expectErr(asRuntime(async (tx) => {
      await tx.$executeRawUnsafe(`insert into vinculo (id, tipo_vinculo, registrado_em) values ('${v}', 'SOCIETARIO', now())`);
      await tx.$executeRawUnsafe(`insert into vinculo_extremidade (id, vinculo_id, lado_extremidade, unidade_economica_id, registrado_em) values ('${id("ab", "1a")}', '${v}', 'ORIGEM', '${UEB}', now()), ('${id("ab", "1b")}', '${v}', 'DESTINO', '${UEB}', now())`);
      return true;
    }, { tenant: TA, conta: CA, commit: true }), /row-level security/i);
    const mixed = await expectErr(asRuntime(async (tx) => {
      await tx.$executeRawUnsafe(`insert into vinculo (id, tipo_vinculo, registrado_em) values ('${id("aa", "11")}', 'SOCIETARIO', now())`);
      await tx.$executeRawUnsafe(`insert into vinculo_extremidade (id, vinculo_id, lado_extremidade, unidade_economica_id, registrado_em) values ('${id("ab", "1c")}', '${id("aa", "11")}', 'ORIGEM', '${UEA}', now()), ('${id("ab", "1d")}', '${id("aa", "11")}', 'DESTINO', '${UEB}', now())`);
      return true;
    }, { tenant: TA, conta: CA, commit: true }), /row-level security/i);
    const seenB = await asRuntime((tx) => ids(tx, "vinculo", "id in ('aa000000-0000-0000-0000-00000000001a','aa000000-0000-0000-0000-00000000002a','aa000000-0000-0000-0000-00000000003a')"), { tenant: TB, conta: CB });
    const seenA = await asRuntime((tx) => ids(tx, "vinculo", "id in ('aa000000-0000-0000-0000-00000000001a','aa000000-0000-0000-0000-00000000002a','aa000000-0000-0000-0000-00000000003a')"), { tenant: TA, conta: CA });
    const persisted = await cnt(prisma, "vinculo", `id in ('${v}','${id("aa", "11")}')`);
    return { ok: both.ok && mixed.ok && seenB.length === 0 && eq(seenA, ["aa000000-0000-0000-0000-00000000001a", "aa000000-0000-0000-0000-00000000002a"]) && persisted === 0, detail: `ambas UE-B bloqueado=${both.ok}; mista bloqueado=${mixed.ok}; B ve vinculos de A=${seenB.length}; A ve 1a/2a e nunca 3a=${eq(seenA, ["aa000000-0000-0000-0000-00000000001a", "aa000000-0000-0000-0000-00000000002a"])}; persistidos=${persisted}` };
  });

  await T("S11 ADR-C014 (concessao UE exige concessao Tenant)", async () => {
    const pos = await asRuntime((tx) => cnt(tx, "conta_acesso_unidade_economica"), { tenant: TA, conta: CA });
    const rt = await expectErr(asRuntime((tx) => tx.$executeRawUnsafe(`insert into conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel) values ('${id("bb", "11")}', '${CB}', '${UEA}', 'RESTRITO_UE')`), { tenant: TA, conta: CB, commit: true }), /./);
    // como owner (BYPASSRLS): a RLS nao intervem; o bloqueio deve vir do trigger ADR-C014
    const ow = await expectErr(prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(`insert into conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel) values ('${id("bb", "12")}', '${CB}', '${UEA}', 'RESTRITO_UE')`);
    }), /ADR-C014/);
    const persisted = await cnt(prisma, "conta_acesso_unidade_economica", `id in ('${id("bb", "11")}','${id("bb", "12")}')`);
    return { ok: pos === 1 && rt.ok && ow.ok && persisted === 0, detail: `existente visivel=${pos}; runtime bloqueado=${rt.ok}; owner(sem RLS) bloqueado pelo trigger=${ow.ok} msg="${ow.msg.slice(0, 110)}"; persistidos=${persisted}` };
  });

  await T("S12 SET LOCAL + COMMIT", async () => {
    const rid = id("f6", "12");
    const dentro = await asRuntime(async (tx) => {
      await tx.$executeRawUnsafe(`insert into receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id) values ('${rid}', 7.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', '${UEA}')`);
      return (await q(tx, `select current_setting('app.current_tenant_id', true) as t`))[0].t;
    }, { tenant: TA, conta: CA, commit: true });
    const semCtx = await asRuntime(async (tx) => ({ g: (await q(tx, `select current_setting('app.current_tenant_id', true) as t`))[0].t, n: await cnt(tx, "receita") }), {});
    const owner = await cnt(prisma, "receita", `id='${rid}'`);
    const comCtx = await asRuntime((tx) => cnt(tx, "receita", `id='${rid}'`), { tenant: TA, conta: CA });
    return { ok: dentro === TA && (semCtx.g === "" || semCtx.g === null) && semCtx.n === 0 && owner === 1 && comCtx === 1, detail: `GUC dentro=ok; apos COMMIT GUC=${JSON.stringify(semCtx.g)} linhas=${semCtx.n}; linha persistiu=${owner}; visivel com ctx=${comCtx}` };
  });

  await T("S13 SET LOCAL + ROLLBACK", async () => {
    const rid = id("f6", "13");
    await asRuntime(async (tx) => {
      await tx.$executeRawUnsafe(`insert into receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id) values ('${rid}', 8.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', '${UEB}')`);
      return true;
    }, { tenant: TB, conta: CB, commit: false });
    const owner = await cnt(prisma, "receita", `id='${rid}'`);
    const semCtx = await asRuntime(async (tx) => ({ g: (await q(tx, `select current_setting('app.current_tenant_id', true) as t`))[0].t, n: await cnt(tx, "receita") }), {});
    return { ok: owner === 0 && (semCtx.g === "" || semCtx.g === null) && semCtx.n === 0, detail: `linha revertida (owner ve ${owner}); apos ROLLBACK GUC=${JSON.stringify(semCtx.g)} linhas=${semCtx.n}` };
  });

  await T("S14 Prisma $transaction() interativa e em array", async () => {
    const inter = await asRuntime(async (tx) => {
      const a = await cnt(tx, "receita");
      await tx.$executeRawUnsafe(`insert into receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id) values ('${id("f6", "14")}', 1.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', '${UEA}')`);
      const b = await cnt(tx, "receita");
      await tx.$executeRawUnsafe(`update receita set valor_receita_bruta = 2.00 where id='${id("f6", "14")}'`);
      const d = await tx.$executeRawUnsafe(`delete from receita where id='${id("f6", "14")}'`);
      const c = await cnt(tx, "receita");
      return [a, b, c, d];
    }, { tenant: TA, conta: CA });
    const arr = await prisma.$transaction([
      prisma.$executeRawUnsafe(`SET LOCAL ROLE ${ROLE}`),
      prisma.$executeRawUnsafe(`SET LOCAL app.current_tenant_id = '${TA}'`),
      prisma.$queryRawUnsafe(`select count(*)::int as n from receita`),
      prisma.$queryRawUnsafe(`select current_user::text as u`),
    ]);
    const after = await prisma.$queryRawUnsafe(`select current_user::text as u, current_setting('app.current_tenant_id', true) as t`);
    const okI = inter[1] === inter[0] + 1 && inter[2] === inter[0] && inter[3] === 1;
    return { ok: okI && arr[2][0].n === inter[0] && arr[3][0].u === ROLE && after[0].u === "neondb_owner" && (after[0].t === "" || after[0].t === null), detail: `interativa(antes,pos-insert,pos-delete,del)=${inter}; array: n=${arr[2][0].n} user=${arr[3][0].u}; conexao volta owner=${after[0].u} GUC=${JSON.stringify(after[0].t)}` };
  });

  await T("S17 reutilizacao de conexao sem vazamento", async () => {
    const one = mk(mode, "connection_limit=1");
    try {
      const expA = await ids(prisma, "receita", `unidade_economica_id='${UEA}'`);
      const expB = await ids(prisma, "receita", `unidade_economica_id='${UEB}'`);
      const ctxs = [[TA, CA, expA], [TB, CB, expB], [undefined, undefined, []], [TA, CC, expA], [undefined, CC, []]];
      const pids = new Set();
      let bad = [];
      for (let i = 0; i < 30; i++) {
        const [t, c, exp] = ctxs[i % ctxs.length];
        const r = await asRuntime(async (tx) => ({ ids: await ids(tx, "receita"), pid: (await q(tx, `select pg_backend_pid()::int as p`))[0].p }), { tenant: t, conta: c, db: one });
        pids.add(r.pid);
        if (!eq(r.ids, exp)) bad.push(i);
        const plain = await one.$queryRawUnsafe(`select current_user::text as u, current_setting('app.current_tenant_id', true) as g, current_setting('app.current_conta_acesso_id', true) as h`);
        if (plain[0].u !== "neondb_owner" || (plain[0].g && plain[0].g !== "") || (plain[0].h && plain[0].h !== "")) bad.push("leak@" + i);
      }
      // concorrencia: 12 transacoes simultaneas com contextos alternados no cliente padrao
      const conc = await Promise.all(Array.from({ length: 12 }, (_, i) => {
        const [t, c, exp] = ctxs[i % ctxs.length];
        return asRuntime((tx) => ids(tx, "receita"), { tenant: t, conta: c }).then((r) => eq(r, exp));
      }));
      const pass = bad.length === 0 && conc.every(Boolean);
      return { ok: pass, detail: `30 tx sequenciais (connection_limit=1) backends distintos=${pids.size}, falhas=${JSON.stringify(bad)}; 12 tx concorrentes ok=${conc.filter(Boolean).length}/12` };
    } finally { await one.$disconnect(); }
  });

  // S15/S16 = suite completa neste endpoint
  const core = results.filter((r) => !r.name.startsWith("S15") && !r.name.startsWith("S16"));
  const allOk = core.every((r) => r.ok);
  const label = mode === "pooled" ? "S16 POOLED (suite completa no endpoint -pooler)" : "S15 DIRECT (suite completa no endpoint direto)";
  const hostOk = mode === "pooled" ? isPooledHost(url) : !isPooledHost(url);
  results.push({ name: label, ok: allOk && hostOk });
  console.log(`${allOk && hostOk ? "PASS" : "FAIL"} ${label} :: ${core.filter((r) => r.ok).length}/${core.length} testes ok, host_correto=${hostOk}`);
  console.log(`# RESUMO modo=${mode}: ${results.filter((r) => r.ok).length}/${results.length} PASS`);
}

try {
  if (cmd === "setup") await setup();
  else if (cmd === "fixture") await fixture();
  else if (cmd === "run") await run();
  else if (cmd === "cleanup") await cleanup();
  else if (cmd === "teardown-role") await teardownRole();
  else throw new Error("comando desconhecido");
} catch (e) {
  console.log("ERRO: " + clean(e.message));
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}

