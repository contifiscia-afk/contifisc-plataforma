// SUITE A - Identidade externa -> ContaAcesso; cenarios de tenant; revogacao independente; vigencia.
import { buildAuth, startServer, prisma } from "./lib/auth-factory.mjs";
import { Client } from "./lib/http.mjs";
import { betterAuthProvider } from "./lib/idp-betterauth.mjs";
import { resolveConta, podeUsarTenant, vigenteEm, listarTenantsVigentes, principalFromRequest, novaConta, vincular, novoTenant, conceder } from "./lib/contifisc-core.mjs";
import { T, ok, res, info, nc, fail, uniq, PW, hdr, results } from "./lib/t.mjs";

export async function run() {
  const G = "A-identidade";
  const auth = buildAuth();
  const idp = betterAuthProvider(auth);
  const srv = await startServer(auth);
  const signUp = async (tag, name = tag) => {
    const c = new Client(tag); const email = uniq(tag);
    const r = await c.post("/api/auth/sign-up/email", { email, password: PW, name });
    return { c, email, userId: r.json?.user?.id };
  };
  try {
    // --- usuarios FICTICIOS ---
    const A = await signUp("socio-medico");       // USUARIO A
    const B = await signUp("financeiro");         // USUARIO B
    const C = await signUp("multi-tenant");       // ContaAcesso C
    const D = await signUp("interno-contifisc");  // ContaAcesso D (interno)
    const contaA = await novaConta(), contaB = await novaConta(), contaC = await novaConta(), contaD = await novaConta({ categoria: "INTERNO" });
    await vincular(contaA, { subject: A.userId }); await vincular(contaB, { subject: B.userId });
    await vincular(contaC, { subject: C.userId }); await vincular(contaD, { subject: D.userId });
    const tenantT = await novoTenant(), tenantX = await novoTenant(), tenantY = await novoTenant(), tenantZ = await novoTenant();

    // ---------------- IDENTIDADE ----------------
    await T(G, "ID-01", "subject estavel: id do provedor nao muda quando o e-mail muda", async () => {
      const before = (await A.c.get("/api/auth/get-session")).json.user;
      const newEmail = uniq("socio-novo");
      const r = await A.c.post("/api/auth/change-email", { newEmail });
      const after = (await A.c.get("/api/auth/get-session")).json.user;
      const p = await principalFromRequest(idp, { headers: hdr(A.c) });
      A.oldEmail = before.email; A.email = after.email;
      if (r.status !== 200) return fail(`change-email status ${r.status} ${r.text.slice(0, 80)}`);
      return (before.id === after.id && before.email !== after.email && p.ok && p.contaId === contaA.id) ? ok("user.id igual; e-mail mudou; ContaAcesso resolvida igual") : fail("id/e-mail inesperado");
    });
    await T(G, "ID-02", "e-mail reciclado NAO herda acesso (e-mail nao e chave)", async () => {
      // B passa a usar o e-mail ANTIGO de A. Nao pode herdar a conta de A.
      const r = await B.c.post("/api/auth/change-email", { newEmail: A.oldEmail });
      const p = await principalFromRequest(idp, { headers: hdr(B.c) });
      return (r.status === 200 && p.ok && p.contaId === contaB.id && p.contaId !== contaA.id) ? ok("B com e-mail antigo de A continua ContaAcesso B") : fail(`status ${r.status}`);
    });
    await T(G, "ID-03", "novo usuario do provedor sem vinculo => sem acesso; nenhuma conta criada automaticamente", async () => {
      const n0 = await prisma.contaAcesso.count();
      const O = await signUp("orfao");
      const p = await principalFromRequest(idp, { headers: hdr(O.c) });
      const n1 = await prisma.contaAcesso.count();
      return (!p.ok && p.reason === "IDENTIDADE_SEM_CONTA" && n0 === n1) ? ok("IDENTIDADE_SEM_CONTA; contas antes/depois iguais") : fail(JSON.stringify(p.reason));
    });
    await T(G, "ID-04", "subject alterado indevidamente na base => acesso negado (fail-closed)", async () => {
      const ident = await prisma.identidadeAcessoExterna.findFirst({ where: { conta_acesso_id: contaC.id } });
      await prisma.identidadeAcessoExterna.update({ where: { id: ident.id }, data: { subject_externo: "subject-adulterado" } });
      const p = await principalFromRequest(idp, { headers: hdr(C.c) });
      await prisma.identidadeAcessoExterna.update({ where: { id: ident.id }, data: { subject_externo: C.userId } });
      const p2 = await principalFromRequest(idp, { headers: hdr(C.c) });
      return (!p.ok && p.reason === "IDENTIDADE_SEM_CONTA" && p2.ok) ? ok("adulterado => IDENTIDADE_SEM_CONTA; restaurado => ok") : fail(p.reason);
    });
    await T(G, "ID-05", "identidade revogada (CONTIFISC) => nega mesmo com sessao valida no provedor", async () => {
      const ident = await prisma.identidadeAcessoExterna.findFirst({ where: { conta_acesso_id: contaB.id } });
      const sess = (await B.c.get("/api/auth/get-session")).json?.session;
      await prisma.identidadeAcessoExterna.update({ where: { id: ident.id }, data: { estado: "REVOGADA", revogada_em: new Date() } });
      const p = await principalFromRequest(idp, { headers: hdr(B.c) });
      await prisma.identidadeAcessoExterna.update({ where: { id: ident.id }, data: { estado: "ATIVA", revogada_em: null } });
      return (!!sess && !p.ok && p.reason === "IDENTIDADE_REVOGADA") ? ok("sessao do provedor ativa; CONTIFISC nega: IDENTIDADE_REVOGADA") : fail(p.reason);
    });
    await T(G, "ID-06", "ContaAcesso suspensa + provedor ativo => nega", async () => {
      await prisma.contaAcesso.update({ where: { id: contaB.id }, data: { status: "SUSPENSA" } });
      const sess = (await B.c.get("/api/auth/get-session")).json?.session;
      const p = await principalFromRequest(idp, { headers: hdr(B.c) });
      await prisma.contaAcesso.update({ where: { id: contaB.id }, data: { status: "ATIVA" } });
      return (!!sess && !p.ok && p.reason === "CONTA_SUSPENSA") ? ok("CONTA_SUSPENSA") : fail(p.reason);
    });
    await T(G, "ID-07", "usuario removido no provedor => vinculo orfao detectavel; sessoes somem; conta preservada", async () => {
      const X = await signUp("removido"); const contaX = await novaConta(); await vincular(contaX, { subject: X.userId });
      const r = await X.c.post("/api/auth/delete-user", { password: PW });
      const still = await prisma.user.count({ where: { id: X.userId } });
      const sessLeft = await prisma.session.count({ where: { userId: X.userId } });
      const orfaos = await prisma.$queryRaw`select i.id from identidade_acesso_externa i where i.provedor='better_auth' and i.estado='ATIVA' and not exists (select 1 from "user" u where u.id = i.subject_externo)`;
      const contaOk = await prisma.contaAcesso.findUnique({ where: { id: contaX.id } });
      const p = await principalFromRequest(idp, { headers: hdr(X.c) });
      return (r.status === 200 && still === 0 && sessLeft === 0 && orfaos.length >= 1 && contaOk && !p.ok) ? ok(`delete-user 200; user removido; sessoes=0; ${orfaos.length} vinculo(s) orfao(s) detectado(s) por reconciliacao; ContaAcesso preservada`) : fail(`status=${r.status} user=${still} sess=${sessLeft} orfaos=${orfaos.length}`);
    });
    await T(G, "ID-08", "segunda identidade (outro usuario do provedor + outro provedor) => mesma ContaAcesso, vinculo explicito", async () => {
      const A2 = await signUp("socio-2a-identidade");
      await vincular(contaA, { subject: A2.userId, estado: "ATIVA" });
      await vincular(contaA, { provider: "clerk", issuer: "poc-clerk-instance", subject: "user_2abcSIMULADO" });
      const p1 = await principalFromRequest(idp, { headers: hdr(A.c) }); const p2 = await principalFromRequest(idp, { headers: hdr(A2.c) });
      const viaClerk = await resolveConta({ provider: "clerk", issuer: "poc-clerk-instance", subject: "user_2abcSIMULADO" });
      return (p1.contaId === contaA.id && p2.contaId === contaA.id && viaClerk.contaId === contaA.id) ? ok("3 identidades (2 BA + 1 clerk simulado) -> mesma ContaAcesso") : fail("resolucao divergente");
    });
    await T(G, "ID-09", "unicidade (provedor, emissor, subject): duplicado barrado; mesmo subject em outro emissor permitido", async () => {
      let dup = false;
      try { await vincular(contaB, { subject: A.userId }); } catch (e) { dup = /Unique|P2002/i.test(String(e.message)); }
      const outroEmissor = await prisma.identidadeAcessoExterna.create({ data: { provedor: "better_auth", emissor: "poc-outro-ambiente", subject_externo: A.userId, conta_acesso_id: contaB.id } }).then(() => true).catch(() => false);
      return (dup && outroEmissor) ? ok("P2002 no duplicado; emissor distinto aceito") : fail(`dup=${dup} outroEmissor=${outroEmissor}`);
    });
    await T(G, "ID-10", "provider user id nao define papel: mudar user.role no provedor nao altera acesso/papel CONTIFISC", async () => {
      await conceder(contaB, tenantT, "financeiro.operador");
      await prisma.user.update({ where: { id: B.userId }, data: { role: "admin" } });      // "admin" DO PROVEDOR
      const papel = await prisma.contaAcessoTenantPoc.findFirst({ where: { conta_acesso_id: contaB.id, tenant_id: tenantT.id } });
      const semGrantOutroTenant = await podeUsarTenant(contaB.id, tenantX.id);
      const p = await principalFromRequest(idp, { headers: hdr(B.c) }, { tenantId: tenantT.id });
      return (papel.papel === "financeiro.operador" && semGrantOutroTenant === false && p.ok) ? ok("role=admin do provedor nao concedeu nada; papel CONTIFISC intacto") : fail("provedor influenciou");
    });

    // ---------------- DOIS USUARIOS NO MESMO TENANT ----------------
    await T(G, "TN-01", "dois usuarios (A socio, B financeiro) no MESMO tenant: contas distintas, mesmo tenant, papeis CONTIFISC independentes", async () => {
      await conceder(contaA, tenantT, "cliente.socio_admin");
      const pa = await principalFromRequest(idp, { headers: hdr(A.c) }, { tenantId: tenantT.id });
      const pb = await principalFromRequest(idp, { headers: hdr(B.c) }, { tenantId: tenantT.id });
      const gs = await prisma.contaAcessoTenantPoc.findMany({ where: { tenant_id: tenantT.id }, orderBy: { papel: "asc" } });
      const orgTables = await prisma.$queryRaw`select count(*)::int as n from information_schema.tables where table_schema='public' and table_name in ('organization','member','invitation','team')`;
      return (pa.ok && pb.ok && pa.contaId !== pb.contaId && pa.identity.subject !== pb.identity.subject && gs.length === 2 && gs[0].papel !== gs[1].papel && orgTables[0].n === 0)
        ? ok(`ambos autenticam; contas distintas; papeis ${gs.map((g) => g.papel).join(" | ")}; 0 tabelas de organization no provedor`) : fail("cenario");
    });
    await T(G, "TN-02", "capabilities futuras podem divergir entre A e B (estado independente por conta)", async () => {
      // Sem entitlement definitivo (fora do escopo): so demonstra que o papel e por-conta e nao vem do provedor.
      const ga = await prisma.contaAcessoTenantPoc.findFirst({ where: { conta_acesso_id: contaA.id, tenant_id: tenantT.id } });
      const gb = await prisma.contaAcessoTenantPoc.findFirst({ where: { conta_acesso_id: contaB.id, tenant_id: tenantT.id } });
      return (ga.papel !== gb.papel) ? ok("papel por ContaAcesso (CONTIFISC); nada do provedor participa") : fail("papeis iguais");
    });

    // ---------------- UM USUARIO EM DOIS TENANTS ----------------
    await T(G, "TN-03", "ContaAcesso C em Tenant X e Y: autentica UMA vez; troca de tenant sem reautenticar; Z negado", async () => {
      await conceder(contaC, tenantX, "cliente.socio_admin"); await conceder(contaC, tenantY, "cliente.socio_admin");
      const sess0 = await prisma.session.count({ where: { userId: C.userId } });
      const px = await principalFromRequest(idp, { headers: hdr(C.c) }, { tenantId: tenantX.id });
      const py = await principalFromRequest(idp, { headers: hdr(C.c) }, { tenantId: tenantY.id });
      const pz = await principalFromRequest(idp, { headers: hdr(C.c) }, { tenantId: tenantZ.id });
      const sess1 = await prisma.session.count({ where: { userId: C.userId } });
      const lista = await listarTenantsVigentes(contaC.id);
      return (px.ok && py.ok && !pz.ok && pz.reason === "TENANT_NAO_AUTORIZADO" && sess0 === sess1 && lista.length === 2) ? ok(`1 sessao antes/depois (${sess0}/${sess1}); X e Y ok; Z=TENANT_NAO_AUTORIZADO; nenhum organization id envolvido`) : fail(JSON.stringify({ px: px.ok, py: py.ok, pz: pz.reason, sess0, sess1 }));
    });

    // ---------------- USUARIO INTERNO ----------------
    await T(G, "IN-01", "usuario interno autentica como os demais mas NAO recebe tenant algum", async () => {
      const p = await principalFromRequest(idp, { headers: hdr(D.c) });
      const lista = await listarTenantsVigentes(contaD.id);
      const negados = await Promise.all([tenantT, tenantX, tenantY, tenantZ].map((t) => podeUsarTenant(contaD.id, t.id)));
      return (p.ok && p.categoria === "INTERNO" && lista.length === 0 && negados.every((x) => x === false) && p.identity.factors.join() === "pwd") ? ok("autenticacao igual (fator pwd/aal1); 0 tenants; 4/4 negados") : fail("interno com acesso implicito");
    });
    await T(G, "IN-02", "acesso interno = concessao administrativa explicita, com vigencia (expira sozinho sem job)", async () => {
      const agora = Date.now();
      const g = await conceder(contaD, tenantX, "interno.contador", { origem: "CARTEIRA_INTERNA", inicio: new Date(agora - 1000), fim: new Date(agora + 1500) });
      const antes = await podeUsarTenant(contaD.id, tenantX.id);
      await new Promise((r) => setTimeout(r, 2200));
      const depois = await podeUsarTenant(contaD.id, tenantX.id);
      const linha = await prisma.contaAcessoTenantPoc.count({ where: { id: g.id } });
      return (antes === true && depois === false && linha === 1) ? ok("vigente -> vencida em ~1,5s; linha AINDA existe (nenhum varredor rodou) e a decisao ja e NEGADO") : fail(`antes=${antes} depois=${depois} linha=${linha}`);
    });

    // ---------------- REVOGACAO INDEPENDENTE DO PROVEDOR (D, E, F) ----------------
    await T(G, "RV-D", "D: ContaAcesso desativada na CONTIFISC => nega mesmo com sessao externa valida", async () => {
      await prisma.contaAcesso.update({ where: { id: contaA.id }, data: { status: "SUSPENSA" } });
      const sess = (await A.c.get("/api/auth/get-session")).json?.session;
      const p = await principalFromRequest(idp, { headers: hdr(A.c) }, { tenantId: tenantT.id });
      await prisma.contaAcesso.update({ where: { id: contaA.id }, data: { status: "ATIVA" } });
      return (!!sess && !p.ok) ? ok(`sessao do provedor valida; ${p.reason}`) : fail("acesso indevido");
    });
    await T(G, "RV-E", "E: identidade externa revogada => nega mesmo com sessao externa valida", async () => {
      const ident = await prisma.identidadeAcessoExterna.findFirst({ where: { conta_acesso_id: contaA.id, subject_externo: A.userId } });
      await prisma.identidadeAcessoExterna.update({ where: { id: ident.id }, data: { estado: "REVOGADA" } });
      const sess = (await A.c.get("/api/auth/get-session")).json?.session;
      const p = await principalFromRequest(idp, { headers: hdr(A.c) }, { tenantId: tenantT.id });
      await prisma.identidadeAcessoExterna.update({ where: { id: ident.id }, data: { estado: "ATIVA" } });
      return (!!sess && !p.ok) ? ok(`sessao valida; ${p.reason}`) : fail("acesso indevido");
    });
    await T(G, "RV-F", "F: acesso ao Tenant removido (DELETE da concessao) => nega mesmo com sessao externa valida", async () => {
      const g = await prisma.contaAcessoTenantPoc.findFirst({ where: { conta_acesso_id: contaA.id, tenant_id: tenantT.id } });
      await prisma.contaAcessoTenantPoc.delete({ where: { id: g.id } });
      const sess = (await A.c.get("/api/auth/get-session")).json?.session;
      const p = await principalFromRequest(idp, { headers: hdr(A.c) }, { tenantId: tenantT.id });
      await prisma.contaAcessoTenantPoc.create({ data: { conta_acesso_id: contaA.id, tenant_id: tenantT.id, papel: g.papel } });
      return (!!sess && !p.ok && p.reason === "TENANT_NAO_AUTORIZADO") ? ok("sessao valida; TENANT_NAO_AUTORIZADO") : fail("acesso indevido");
    });
    await T(G, "RV-G", "tenant SUSPENSO => nega (kill switch independente do provedor)", async () => {
      await prisma.tenantPoc.update({ where: { id: tenantT.id }, data: { status: "SUSPENSO" } });
      const p = await principalFromRequest(idp, { headers: hdr(B.c) }, { tenantId: tenantT.id });
      await prisma.tenantPoc.update({ where: { id: tenantT.id }, data: { status: "ATIVO" } });
      return !p.ok ? ok(p.reason) : fail("acesso a tenant suspenso");
    });

    // ---------------- VIGENCIA (predicado deterministico) ----------------
    await T(G, "VG-01", "vigencia: inicio<=t AND (fim IS NULL OR t<fim) - matriz de fronteiras exatas", async () => {
      const T0 = new Date("2030-01-01T00:00:00.000Z"), T1 = new Date("2030-02-01T00:00:00.000Z");
      const ca = await novaConta(); const tn = await novoTenant();
      const g = await conceder(ca, tn, "x.y", { inicio: T0, fim: T1 });
      const mid = new Date("2030-01-15T00:00:00.000Z");
      const m = (d, dms) => new Date(d.getTime() + dms);
      const casos = [["antes do inicio (-1ms)", m(T0, -1), false], ["exatamente no inicio", T0, true], ["meio", mid, true], ["fim -1ms", m(T1, -1), true], ["exatamente no fim", T1, false], ["depois do fim (+1ms)", m(T1, 1), false]];
      const out = []; let allOk = true;
      for (const [nome, t, esperado] of casos) { const r = await vigenteEm(g.id, t); out.push(`${nome}=${r}`); if (r !== esperado) allOk = false; }
      // sem fim
      const g2 = await conceder(await novaConta(), await novoTenant(), "x.y", { inicio: T0, fim: null });
      const semFimApos = await vigenteEm(g2.id, new Date("2099-01-01T00:00:00Z")); const semFimAntes = await vigenteEm(g2.id, m(T0, -1));
      if (semFimApos !== true || semFimAntes !== false) allOk = false;
      out.push(`sem-fim depois=${semFimApos} antes=${semFimAntes}`);
      return allOk ? ok(out.join("; ")) : fail(out.join("; "));
    });
    await T(G, "VG-02", "vigencia futura, ativa e vencida decididas por now() do BANCO (relogio do cliente irrelevante)", async () => {
      const ca = await novaConta(); const tn = await novoTenant(); const dia = 86400000; const n = Date.now();
      const futura = await novoTenant(); const ativa = tn; const vencida = await novoTenant();
      await conceder(ca, futura, "x.y", { inicio: new Date(n + dia), fim: null });
      await conceder(ca, ativa, "x.y", { inicio: new Date(n - dia), fim: null });
      await conceder(ca, vencida, "x.y", { inicio: new Date(n - 2 * dia), fim: new Date(n - dia) });
      const [f, a, v] = await Promise.all([podeUsarTenant(ca.id, futura.id), podeUsarTenant(ca.id, ativa.id), podeUsarTenant(ca.id, vencida.id)]);
      // "relogio do navegador": nada na assinatura da funcao aceita instante; header falsificado nao entra em lugar algum.
      const semParametroTempo = podeUsarTenant.length === 2;
      return (f === false && a === true && v === false && semParametroTempo) ? ok(`futura=${f} ativa=${a} vencida=${v}; podeUsarTenant(conta,tenant) nao recebe instante do cliente`) : fail(`f=${f} a=${a} v=${v}`);
    });
  } finally { await srv.close(); }
  return results.filter((r) => r.group === "A-identidade");
}
if (process.argv[1].endsWith("suite-a-identity.mjs") || process.argv[1].endsWith("suite-a-identidade.mjs")) { /* noop */ }

