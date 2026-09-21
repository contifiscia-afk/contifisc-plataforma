// SUITE C - MFA / AAL / step-up (Better Auth self-hosted). A CONTIFISC calcula o AAL; o provedor nao o expoe.
import * as OTPAuth from "otpauth";
import { buildAuth, startServer, prisma } from "./lib/auth-factory.mjs";
import { Client } from "./lib/http.mjs";
import { betterAuthProvider } from "./lib/idp-betterauth.mjs";
import { satisfiesAuthenticationLevel } from "./lib/aal-policy.mjs";
import { T, ok, res, info, nc, fail, uniq, PW, hdr, sleep, results } from "./lib/t.mjs";

const G = "C-mfa-aal";
const totpFrom = (uri) => OTPAuth.URI.parse(uri);
async function newUser(tag) {
  const c = new Client(tag); const email = uniq(tag);
  const r = await c.post("/api/auth/sign-up/email", { email, password: PW, name: tag });
  return { c, email, id: r.json?.user?.id };
}
async function enroll2fa(u) {
  const e = await u.c.post("/api/auth/two-factor/enable", { password: PW });
  const totp = totpFrom(e.json.totpURI);
  const v = await u.c.post("/api/auth/two-factor/verify-totp", { code: totp.generate() });
  return { enable: e, totp, backupCodes: e.json.backupCodes, verify: v };
}
const sess = async (c) => (await c.get("/api/auth/get-session")).json;
async function userWithPreSession(tag) {
  const u = await newUser(tag);
  const pre = new Client(tag + "-pre"); await pre.post("/api/auth/sign-in/email", { email: u.email, password: PW }); // sessao aal1 criada ANTES do 2FA
  const enr = await enroll2fa(u);                                                                                    // 2FA habilitado por OUTRA sessao (u.c)
  return { u, pre, enr };
}

export async function run() {
  const auth = buildAuth({}); const srv = await startServer(auth);
  const idp = betterAuthProvider(auth, { elevationWindowSeconds: 3 });
  try {
    // ----- enrolamento -----
    const U = await newUser("mfa"); const s0 = await sess(U.c); // sessao criada ANTES do 2FA (aal1)
    let enr;
    await T(G, "MFA-01", "enrolamento TOTP: exige senha; retorna URI + backup codes; 2FA so 'ativo' apos 1a verificacao", async () => {
      const semSenha = await U.c.post("/api/auth/two-factor/enable", {});
      enr = await enroll2fa(U);
      const row = await prisma.user.findUnique({ where: { id: U.id } });
      return (semSenha.status >= 400 && enr.enable.status === 200 && Array.isArray(enr.backupCodes) && enr.backupCodes.length >= 8 && enr.verify.status === 200 && row.twoFactorEnabled === true)
        ? ok(`sem senha=${semSenha.status}; enable 200 (${enr.backupCodes.length} backup codes); verify-totp 200; twoFactorEnabled=true`) : fail(JSON.stringify({ semSenha: semSenha.status, en: enr.enable.status, v: enr.verify.status, flag: row.twoFactorEnabled }));
    });
    await T(G, "MFA-02", "segredo TOTP e backup codes em repouso NAO estao em claro (criptografados/derivados com o secret do provedor)", async () => {
      const tf = await prisma.twoFactor.findFirst({ where: { userId: U.id } });
      const secretB32 = enr.totp.secret.base32;
      const claro = tf.secret.includes(secretB32) || enr.backupCodes.some((b) => tf.backupCodes.includes(b));
      return !claro ? ok("twoFactor.secret e backupCodes != valores em claro (ciphertext); exportar exige o BETTER_AUTH_SECRET") : fail("segredo em claro");
    });

    // ----- login com 2FA -----
    await T(G, "MFA-03", "senha SOZINHA para usuario com 2FA nao cria sessao (twoFactorRedirect); AAL1 nao e emitido", async () => {
      const c = new Client("pwd-only"); const before = await prisma.session.count({ where: { userId: U.id } });
      const r = await c.post("/api/auth/sign-in/email", { email: U.email, password: PW });
      const after = await prisma.session.count({ where: { userId: U.id } });
      const g = await sess(c);
      return (r.json?.twoFactorRedirect === true && after === before && g === null) ? ok("twoFactorRedirect=true; sessoes antes/depois iguais; get-session=null") : fail(JSON.stringify({ r: r.json, before, after }));
    });
    let mfaClient;
    await T(G, "MFA-04", "senha + TOTP => sessao com evidencia CONTIFISC aal=2 [pwd,totp]; adapter atesta nivel 2", async () => {
      mfaClient = new Client("mfa-login");
      await mfaClient.post("/api/auth/sign-in/email", { email: U.email, password: PW });
      await sleep(0); const code = enr.totp.generate();
      const v = await mfaClient.post("/api/auth/two-factor/verify-totp", { code });
      const p = await idp.resolve({ headers: hdr(mfaClient) }, { bypassSessionCache: true });
      return (v.status === 200 && p?.authenticationLevel === 2 && p.factors.join() === "pwd,totp" && p.evidence === "contifisc_hook") ? ok(`verify-totp 200; nivel=${p.authenticationLevel}; fatores=${p.factors}; evidencia=${p.evidence}`) : fail(JSON.stringify({ st: v.status, p }));
    });
    await T(G, "MFA-05", "codigo TOTP errado rejeitado; lockout/contador de falhas", async () => {
      const c = new Client("bad"); await c.post("/api/auth/sign-in/email", { email: U.email, password: PW });
      const statuses = []; for (let i = 0; i < 6; i++) statuses.push((await c.post("/api/auth/two-factor/verify-totp", { code: "000000" })).status);
      const tf = await prisma.twoFactor.findFirst({ where: { userId: U.id } });
      const good = await c.post("/api/auth/two-factor/verify-totp", { code: enr.totp.generate() });
      return statuses.every((s) => s >= 400) ? (tf.lockedUntil || tf.failedVerificationCount > 0 ? ok(`6 erros => ${[...new Set(statuses)]}; failedVerificationCount=${tf.failedVerificationCount}; lockedUntil=${tf.lockedUntil ? "definido" : "nulo"}; codigo correto apos falhas=${good.status}`) : res(`erros rejeitados (${[...new Set(statuses)]}) mas sem contador visivel; correto apos falhas=${good.status}`)) : fail(String(statuses));
    });
    await T(G, "MFA-06", "replay do MESMO codigo TOTP na mesma janela", async () => {
      // dois logins consecutivos com o mesmo codigo (RFC 6238 §5.2 recomenda rejeitar reuso)
      await sleep(300);
      const code = enr.totp.generate();
      const c1 = new Client("r1"); await c1.post("/api/auth/sign-in/email", { email: U.email, password: PW }); const a = await c1.post("/api/auth/two-factor/verify-totp", { code });
      const c2 = new Client("r2"); await c2.post("/api/auth/sign-in/email", { email: U.email, password: PW }); const b = await c2.post("/api/auth/two-factor/verify-totp", { code });
      return (a.status === 200 && b.status === 200) ? res(`mesmo codigo aceito 2x na janela (${a.status}/${b.status}) => reuso NAO rejeitado pelo provedor; mitigacao: exigir step-up com codigo novo ou rate-limit CONTIFISC`) : ok(`1o=${a.status} 2o=${b.status} (reuso rejeitado)`);
    });
    await T(G, "MFA-07", "backup code: funciona como 2o fator (aal=2 [pwd,backup_code]) e e de uso unico", async () => {
      const code = enr.backupCodes[0];
      const c = new Client("bk"); await c.post("/api/auth/sign-in/email", { email: U.email, password: PW });
      const v = await c.post("/api/auth/two-factor/verify-backup-code", { code });
      const p = await idp.resolve({ headers: hdr(c) }, { bypassSessionCache: true });
      const c2 = new Client("bk2"); await c2.post("/api/auth/sign-in/email", { email: U.email, password: PW });
      const v2 = await c2.post("/api/auth/two-factor/verify-backup-code", { code });
      return (v.status === 200 && p?.authenticationLevel === 2 && p.factors.join() === "pwd,backup_code" && v2.status >= 400) ? ok(`1o uso=200 nivel=2 fatores=${p.factors}; reuso=${v2.status}`) : fail(JSON.stringify({ v: v.status, p: p?.factors, v2: v2.status }));
    });

    // ----- step-up -----
    await T(G, "MFA-08", "step-up de sessao EXISTENTE aal1: reverificar TOTP eleva para aal2 por janela finita; expira", async () => {
      const { u, pre, enr: e8 } = await userWithPreSession("stepup");            // usuario COM 2FA, sessao "pre" aal1
      const before = await idp.resolve({ headers: hdr(pre) }, { bypassSessionCache: true });
      const okStep = await idp.stepUp({ headers: hdr(pre) }, { factor: "totp", code: e8.totp.generate() });
      const during = await idp.resolve({ headers: hdr(pre) }, { bypassSessionCache: true });
      await sleep(3500);
      const after = await idp.resolve({ headers: hdr(pre) }, { bypassSessionCache: true });
      return (before?.authenticationLevel === 1 && okStep === true && during?.authenticationLevel === 2 && after?.authenticationLevel === 1)
        ? ok(`antes=${before.authenticationLevel}; stepUp=${okStep}; durante=${during.authenticationLevel}; apos janela(3s)=${after.authenticationLevel}`) : fail(JSON.stringify({ b: before?.authenticationLevel, okStep, d: during?.authenticationLevel, a: after?.authenticationLevel }));
    });
    await T(G, "MFA-09", "step-up com codigo errado nao eleva; sessao continua aal1", async () => {
      const { pre } = await userWithPreSession("stepbad");
      const bad = await idp.stepUp({ headers: hdr(pre) }, { factor: "totp", code: "111111" });
      const p = await idp.resolve({ headers: hdr(pre) }, { bypassSessionCache: true });
      return (bad === false && p.authenticationLevel === 1) ? ok("stepUp(errado)=false; nivel permanece 1") : fail(JSON.stringify({ bad, lvl: p?.authenticationLevel }));
    });
    await T(G, "MFA-10", "politica satisfiesAuthenticationLevel: aal1 nega, aal2 fresco permite, aal2 velho nega, step-up recente permite", async () => {
      const now = new Date(); const mk = (lvl, ageS, fa) => ({ authenticationLevel: lvl, authenticatedAt: new Date(now - ageS * 1000), lastFactorVerifiedAt: fa !== undefined ? new Date(now - fa * 1000) : undefined });
      const req = { minLevel: 2, maxFactorAgeSeconds: 300 };
      const r = [satisfiesAuthenticationLevel(mk(1, 10), req, now), satisfiesAuthenticationLevel(mk(2, 10), req, now), satisfiesAuthenticationLevel(mk(2, 4000), req, now), satisfiesAuthenticationLevel(mk(2, 4000, 30), req, now)];
      return (JSON.stringify(r) === JSON.stringify([false, true, false, true])) ? ok("[aal1=false, aal2-fresco=true, aal2-velho=false, aal2-velho+stepup-recente=true]") : fail(JSON.stringify(r));
    });

    // ----- remocao / recuperacao -----
    await T(G, "MFA-11", "remocao do MFA: /two-factor/disable exige so a SENHA (nao o 2o fator) => CONTIFISC deve impor step-up antes", async () => {
      const { u, pre } = await userWithPreSession("dis");
      const lvl = (await idp.resolve({ headers: hdr(pre) }, { bypassSessionCache: true })).authenticationLevel;    // sessao aal1: NAO provou o 2o fator
      // sessao aal1 (sem 2o fator) - simulamos a sessao pre-existente u.c (criada antes do 2FA)
      const r = await pre.post("/api/auth/two-factor/disable", { password: PW });
      const row = await prisma.user.findUnique({ where: { id: u.id } });
      return (r.status === 200 && row.twoFactorEnabled === false && lvl === 1) ? res("disable=200 com sessao aal1 + senha, sem provar o 2o fator => o provedor permite DOWNGRADE de MFA; a CONTIFISC deve exigir step-up (aal2 recente) e auditar antes de expor/permitir esta rota") : ok(`disable=${r.status} (protegido)`);
    });
    await T(G, "MFA-12", "perda do dispositivo/backup codes: sem fluxo de recuperacao no provedor => procedimento administrativo CONTIFISC (auditado)", async () => {
      const u = await newUser("lost"); await enroll2fa(u);
      // Procedimento administrativo simulado (remove o fator; usuario volta a aal1 e precisa reenrolar):
      await prisma.twoFactor.deleteMany({ where: { userId: u.id } }); await prisma.user.update({ where: { id: u.id }, data: { twoFactorEnabled: false } });
      const c = new Client("lost-l"); const r = await c.post("/api/auth/sign-in/email", { email: u.email, password: PW });
      const p = await idp.resolve({ headers: hdr(c) }, { bypassSessionCache: true });
      const bloqueiaAdmin = !satisfiesAuthenticationLevel(p, { minLevel: 2 });
      return (r.status === 200 && p.authenticationLevel === 1 && bloqueiaAdmin) ? res("apos reset administrativo o usuario loga com aal1 e a politica CONTIFISC bloqueia operacoes que exigem aal2 (MFA_REQUERIDO) ate reenrolar; o reset em si e um caminho de privilegio => exige aprovacao dupla + auditoria") : fail("estado inesperado");
    });
    await T(G, "MFA-13", "MFA obrigatorio: o provedor NAO impoe 'exigir 2FA para todos' - a CONTIFISC impoe via aal na politica", async () => {
      const u = await newUser("nomfa"); const p = await idp.resolve({ headers: hdr(u.c) }, { bypassSessionCache: true });
      const negadoAdmin = !satisfiesAuthenticationLevel(p, { minLevel: 2 });
      return negadoAdmin ? ok("usuario sem 2FA obtem sessao aal1 no provedor; politica CONTIFISC nega operacoes aal2 => MFA_REQUERIDO (a UI leva ao enrolamento)") : fail("aal2 indevido");
    });
    await T(G, "MFA-14", "freshAge (recencia da SESSAO) nao substitui step-up: mede criacao da sessao, nao reverificacao de fator", async () => {
      return info("session.freshAge (default 1 dia) e checado por rotas como delete-user com base em session.createdAt; nao ha 'reverificar fator' nativo => step-up e responsabilidade da CONTIFISC (MFA-08).");
    });
    await T(G, "MFA-15", "OTP por canal (e-mail/SMS) como 2o fator", async () => nc("plugin twoFactor suporta OTP via sendOTP, mas nao foi configurado nesta PoC (sem canal de envio); nao comprovado empiricamente"));
  } finally { await srv.close(); }
  return results.filter((r) => r.group === G);
}


