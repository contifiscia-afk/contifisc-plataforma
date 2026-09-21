// SUITE D - OAuth/OIDC (IdP SIMULADO local via oauth2-mock-server; NAO e Google). Subject, linking, e-mail, MFA/AAL.
import { OAuth2Server } from "oauth2-mock-server";
import * as OTPAuth from "otpauth";
import { buildAuth, startServer, prisma, BASE } from "./lib/auth-factory.mjs";
import { Client } from "./lib/http.mjs";
import { betterAuthProvider } from "./lib/idp-betterauth.mjs";
import { resolveConta, novaConta, vincular, principalFromRequest } from "./lib/contifisc-core.mjs";
import { satisfiesAuthenticationLevel } from "./lib/aal-policy.mjs";
import { T, ok, res, info, nc, fail, uniq, PW, hdr, results } from "./lib/t.mjs";

const G = "D-oauth";
const IDP_PORT = 3500, ISSUER = `http://localhost:${IDP_PORT}`;
const claims = { sub: "idp-sub-0", email: "x@example.test", email_verified: true, name: "OAuth PoC" };

async function startIdp() {
  const s = new OAuth2Server();
  await s.issuer.keys.generate("RS256");
  s.service.on("beforeTokenSigning", (token) => { Object.assign(token.payload, { ...claims }); });
  s.service.on("beforeUserinfo", (resp) => { resp.body = { ...claims }; });
  await s.start(IDP_PORT, "localhost");
  return s;
}
const providers = [{ providerId: "mockidp", clientId: "poc-client", clientSecret: "poc-secret", discoveryUrl: `${ISSUER}/.well-known/openid-configuration`, scopes: ["openid", "email", "profile"], pkce: true }];

async function oauthFlow(client, path, body) {
  const r1 = await client.post(path, body);
  const url = r1.json?.url; if (!url) return { ok: false, step: 1, r1 };
  const r2 = await fetch(url, { redirect: "manual" });
  const loc = r2.headers.get("location"); if (!loc) return { ok: false, step: 2, status: r2.status };
  const cb = new URL(loc); const r3 = await client.get(cb.pathname + cb.search);
  return { ok: r3.status < 400, status: r3.status, location: r3.headers.get("location"), r3 };
}
const signIn = (c) => oauthFlow(c, "/api/auth/sign-in/social", { provider: "mockidp", callbackURL: `${BASE}/done` });
const link = (c) => oauthFlow(c, "/api/auth/link-social", { provider: "mockidp", callbackURL: `${BASE}/done` });
const sess = async (c) => (await c.get("/api/auth/get-session")).json;

export async function run() {
  const idpServer = await startIdp();
  try {
    // ================= variante padrao (linking implicito ligado - default do provedor) =================
    const auth = buildAuth({ oauthProviders: providers }); const srv = await startServer(auth); const idp = betterAuthProvider(auth);
    try {
      let oauthUserId, oauthClient;
      await T(G, "OA-01", "login OAuth/OIDC cria usuario+conta no provedor; sessao com evidencia CONTIFISC [oauth] aal1", async () => {
        Object.assign(claims, { sub: "idp-sub-1", email: uniq("oa1"), email_verified: true, name: "OA1" });
        oauthClient = new Client("oa1"); const r = await signIn(oauthClient);
        const s = await sess(oauthClient); oauthUserId = s?.user?.id;
        const p = await idp.resolve({ headers: hdr(oauthClient) }, { bypassSessionCache: true });
        return (r.ok && s?.session && p?.factors.join() === "oauth" && p.authenticationLevel === 1) ? ok(`callback ${r.status}; sessao criada; fatores=${p.factors}; nivel=${p.authenticationLevel}`) : fail(JSON.stringify({ step: r.step, st: r.status, r1: r.r1?.status, txt: r.r1?.text?.slice(0, 120) }));
      });
      await T(G, "OA-02", "subject: account.accountId = 'sub' do IdP; subject CONTIFISC = user.id do provedor (nao o sub, nao e-mail)", async () => {
        const acc = await prisma.account.findFirst({ where: { userId: oauthUserId, providerId: "mockidp" } });
        return (acc?.accountId === "idp-sub-1" && oauthUserId && oauthUserId !== "idp-sub-1") ? ok(`account.providerId=mockidp accountId=sub estavel; user.id (subject CONTIFISC)=${oauthUserId.slice(0, 6)}...`) : fail(JSON.stringify(acc));
      });
      await T(G, "OA-03", "e-mail alterado NO IdP (mesmo sub) => mesmo usuario/subject => mesma ContaAcesso", async () => {
        const conta = await novaConta(); await vincular(conta, { subject: oauthUserId });
        claims.email = uniq("oa1-novo-email");                                  // IdP muda o e-mail; sub igual
        const c2 = new Client("oa1b"); const r = await signIn(c2);
        const s2 = await sess(c2); const p = await principalFromRequest(idp, { headers: hdr(c2) });
        return (r.ok && s2?.user?.id === oauthUserId && p.ok && p.contaId === conta.id) ? ok("novo login com outro e-mail resolve o MESMO user.id e a MESMA ContaAcesso (identidade por sub, nao por e-mail)") : fail(JSON.stringify({ same: s2?.user?.id === oauthUserId, reason: p.reason }));
      });
      await T(G, "OA-04", "linking IMPLICITO por e-mail (default do provedor): takeover por IdP que afirma o e-mail da vitima?", async () => {
        // Atacante controla o IdP e afirma email=V, email_verified=true, sub diferente. Dois casos: e-mail da vitima NAO verificado / VERIFICADO no provedor.
        const tentar = async (verificado) => {
          const vEmail = uniq(verificado ? "vitima-ver" : "vitima-nver"); const v = new Client("vitima"); const rv = await v.post("/api/auth/sign-up/email", { email: vEmail, password: PW, name: "Vitima" });
          const vId = rv.json.user.id; const contaV = await novaConta(); await vincular(contaV, { subject: vId });
          if (verificado) await prisma.user.update({ where: { id: vId }, data: { emailVerified: true } });
          Object.assign(claims, { sub: "idp-sub-ATACANTE-" + (verificado ? "V" : "N"), email: vEmail, email_verified: true });
          const atk = new Client("atacante"); const r = await signIn(atk);
          const s = await sess(atk); const p = await principalFromRequest(idp, { headers: hdr(atk) });
          return { chegouAoCallback: r.status !== undefined, takeover: s?.user?.id === vId && p.ok && p.contaId === contaV.id };
        };
        const a = await tentar(false), b = await tentar(true);
        if (!a.chegouAoCallback || !b.chegouAoCallback) return fail("fluxo OAuth nao chegou ao callback");
        if (b.takeover) return res(`CONFIRMADO: vitima com e-mail NAO verificado => sem takeover (${a.takeover ? "TAKEOVER" : "account_not_linked"}); vitima com e-mail VERIFICADO => TAKEOVER (login OAuth do atacante resolveu a ContaAcesso da vitima). Mitigacao obrigatoria: disableImplicitLinking=true (ver OA-05)`);
        return ok(`sem takeover nos dois casos (nao verificado=${a.takeover}; verificado=${b.takeover}) no default 1.7.5`);
      });
    } finally { await srv.close(); }

    // ================= variante endurecida: disableImplicitLinking =================
    const auth2 = buildAuth({ oauthProviders: providers, disableImplicitLinking: true }); const srv2 = await startServer(auth2); const idp2 = betterAuthProvider(auth2);
    try {
      await T(G, "OA-05", "MITIGACAO: disableImplicitLinking=true => login OAuth com e-mail de usuario existente e REJEITADO (sem takeover)", async () => {
        const vEmail = uniq("vitima2"); const v = new Client("vitima2"); const rv = await v.post("/api/auth/sign-up/email", { email: vEmail, password: PW, name: "V2" });
        const vId = rv.json.user.id; const contaV = await novaConta(); await vincular(contaV, { subject: vId });
        Object.assign(claims, { sub: "idp-sub-ATACANTE-2", email: vEmail, email_verified: true });
        const atk = new Client("atacante2"); const r = await signIn(atk);
        const s = await sess(atk); const p = await principalFromRequest(idp2, { headers: hdr(atk) });
        const loc = r.location ?? "";
        if (r.status === undefined) return fail(`fluxo OAuth nao chegou ao callback (step ${r.step})`);
        return (!s?.session && !p.ok) ? ok(`callback ${r.status} ${/error/i.test(loc) ? "com erro (" + decodeURIComponent(loc).slice(-60) + ")" : ""}; nenhuma sessao criada; sem acesso a ContaAcesso da vitima`) : fail("takeover mesmo com disableImplicitLinking");
      });
      await T(G, "OA-06", "linking EXPLICITO por usuario autenticado (mesmo e-mail) adiciona identidade ao MESMO usuario do provedor", async () => {
        const email = uniq("linkme"); const u = new Client("linkme"); const ru = await u.post("/api/auth/sign-up/email", { email, password: PW, name: "Link" });
        const uid = ru.json.user.id; const conta = await novaConta(); await vincular(conta, { subject: uid });
        Object.assign(claims, { sub: "idp-sub-LINK", email, email_verified: true });
        const r = await link(u); const accs = await prisma.account.findMany({ where: { userId: uid }, select: { providerId: true } });
        const viaOauth = new Client("linked-login"); await signIn(viaOauth); const p = await principalFromRequest(idp2, { headers: hdr(viaOauth) });
        return (r.ok && accs.some((a) => a.providerId === "mockidp") && p.ok && p.contaId === conta.id) ? ok(`link ${r.status}; accounts=[${accs.map((a) => a.providerId)}]; login OAuth posterior resolve a MESMA ContaAcesso`) : fail(JSON.stringify({ ok: r.ok, step: r.step, accs, reason: p.reason }));
      });
      await T(G, "OA-07", "linking explicito com e-mail DIFERENTE no IdP e rejeitado por padrao (allowDifferentEmails=false)", async () => {
        const email = uniq("linkdiff"); const u = new Client("linkdiff"); const ru = await u.post("/api/auth/sign-up/email", { email, password: PW, name: "LD" });
        Object.assign(claims, { sub: "idp-sub-LINKDIFF", email: uniq("outro-email"), email_verified: true });
        const r = await link(u); const accs = await prisma.account.count({ where: { userId: ru.json.user.id, providerId: "mockidp" } });
        if (r.status === undefined) return fail(`fluxo de link nao chegou ao callback (step ${r.step})`);
        return accs === 0 ? ok(`link com e-mail diferente bloqueado (${r.status}); nenhuma account criada`) : res("link com e-mail diferente foi aceito");
      });
      await T(G, "OA-08", "OAuth de usuario COM 2FA: sessao criada SEM desafio de 2o fator (bypass) - AAL da CONTIFISC continua 1; step-up eleva", async () => {
        const email = uniq("oa2fa"); const u = new Client("oa2fa"); const ru = await u.post("/api/auth/sign-up/email", { email, password: PW, name: "OA2FA" });
        const uid = ru.json.user.id;
        const e = await u.post("/api/auth/two-factor/enable", { password: PW }); const totp = OTPAuth.URI.parse(e.json.totpURI); await u.post("/api/auth/two-factor/verify-totp", { code: totp.generate() });
        const conta = await novaConta(); await vincular(conta, { subject: uid });
        // login OAuth com o MESMO e-mail (usuario existe; sem implicit linking => precisa estar linkado explicitamente antes)
        Object.assign(claims, { sub: "idp-sub-OA2FA", email, email_verified: true }); await link(u);
        const o = new Client("oa2fa-login"); const r = await signIn(o);
        const s = await sess(o); const p = await idp2.resolve({ headers: hdr(o) }, { bypassSessionCache: true });
        const negaAdmin = p && !satisfiesAuthenticationLevel(p, { minLevel: 2 });
        const step = p ? await idp2.stepUp({ headers: hdr(o) }, { factor: "totp", code: totp.generate() }) : false;
        const p2 = await idp2.resolve({ headers: hdr(o) }, { bypassSessionCache: true });
        return (s?.session && p.authenticationLevel === 1 && p.factors.join() === "oauth" && negaAdmin && step && p2.authenticationLevel === 2)
          ? res(`sessao OAuth criada direto (sem 2FA) mesmo com 2FA habilitado => provedor NAO impoe o 2o fator no caminho OAuth; CONTIFISC atesta nivel=${p.authenticationLevel} [oauth] e nega ops aal2; apos step-up TOTP nivel=${p2.authenticationLevel}`) : fail(JSON.stringify({ sess: !!s?.session, lvl: p?.authenticationLevel, negaAdmin, step, lvl2: p2?.authenticationLevel, st: r.status }));
      });
      await T(G, "OA-09", "amr/acr do IdP (ex.: 'mfa') NAO chegam a sessao do provedor => CONTIFISC nao pode confiar em garantia declarada pelo IdP", async () => {
        Object.assign(claims, { sub: "idp-sub-AMR", email: uniq("amr"), email_verified: true, amr: ["mfa", "otp"], acr: "urn:mace:incommon:iap:silver" });
        const c = new Client("amr"); await signIn(c); const s = await sess(c);
        const p = await idp2.resolve({ headers: hdr(c) }, { bypassSessionCache: true });
        return (s?.session && p.authenticationLevel === 1 && !("amr" in (s.session ?? {}))) ? res("mesmo com amr=['mfa','otp'] no id_token, a sessao do provedor nao expoe amr/acr; nivel CONTIFISC=1. Para confiar no MFA do IdP seria preciso capturar o id_token no callback (hook proprio) e validar emissor/politica - NAO feito; recomendacao: tratar OAuth como aal1 + step-up proprio") : fail("amr propagado?");
      });
      await T(G, "OA-10", "novo usuario OAuth sem vinculo => sem acesso; nenhuma ContaAcesso criada", async () => {
        Object.assign(claims, { sub: "idp-sub-NOVO", email: uniq("novo"), email_verified: true });
        const n0 = await prisma.contaAcesso.count(); const c = new Client("novo"); await signIn(c);
        const p = await principalFromRequest(idp2, { headers: hdr(c) }); const n1 = await prisma.contaAcesso.count();
        return (!p.ok && p.reason === "IDENTIDADE_SEM_CONTA" && n0 === n1) ? ok("IDENTIDADE_SEM_CONTA; contas antes/depois iguais") : fail(p.reason);
      });
    } finally { await srv2.close(); }
    await T(G, "OA-11", "Google OAuth real (client id/secret, consentimento, e-mail real)", async () => nc("NAO EXECUTADO: exige criar credencial OAuth no Google Cloud Console (acao humana). O comportamento do fluxo OIDC (sub, linking, e-mail, AAL) foi provado com IdP OIDC simulado; nao ha diferenca esperada de protocolo, mas nao foi comprovado contra o Google."));
  } finally { await idpServer.stop(); }
  return results.filter((r) => r.group === G);
}

