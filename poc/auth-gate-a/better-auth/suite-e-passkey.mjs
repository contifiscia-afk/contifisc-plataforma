// SUITE E — Passkeys (WebAuthn) com autenticador por SOFTWARE. Foco: UV, AAL, revogacao, replay, interacao com 2FA.
import * as OTPAuth from "otpauth";
import { buildAuth, startServer, prisma, BASE } from "./lib/auth-factory.mjs";
import { Client } from "./lib/http.mjs";
import { betterAuthProvider } from "./lib/idp-betterauth.mjs";
import { SoftAuthenticator } from "./lib/softauth.mjs";
import { satisfiesAuthenticationLevel } from "./lib/aal-policy.mjs";
import { T, ok, res, info, nc, fail, uniq, PW, hdr, results } from "./lib/t.mjs";

const G = "E-passkey";
async function newUser(tag) { const c = new Client(tag); const email = uniq(tag); const r = await c.post("/api/auth/sign-up/email", { email, password: PW, name: tag }); return { c, email, id: r.json?.user?.id }; }
const sess = async (c) => (await c.get("/api/auth/get-session")).json;

async function registerPasskey(user, authr, name = "PoC key") {
  const o = await user.c.get("/api/auth/passkey/generate-register-options");
  if (!o.json?.challenge) return { ok: false, step: "options", status: o.status, text: o.text.slice(0, 120) };
  const v = await user.c.post("/api/auth/passkey/verify-registration", { response: authr.register(o.json.challenge), name });
  return { ok: v.status === 200, status: v.status, json: v.json, text: v.text.slice(0, 160) };
}
async function passkeyLogin(authr, opts) {
  const c = new Client("pk-login");
  const o = await c.get("/api/auth/passkey/generate-authenticate-options");
  if (!o.json?.challenge) return { c, ok: false, step: "options", status: o.status };
  const a = authr.assert(o.json.challenge, opts);
  const v = await c.post("/api/auth/passkey/verify-authentication", { response: a });
  return { c, ok: v.status === 200, status: v.status, text: v.text.slice(0, 160), assertion: a, challenge: o.json.challenge };
}

export async function run() {
  // ===== servidor com UV "preferred" (default do plugin) =====
  let auth = buildAuth({ passkeyUV: "preferred" }); let srv = await startServer(auth); let idp = betterAuthProvider(auth);
  try {
    const U = await newUser("pk"); const authrUV = new SoftAuthenticator({ origin: BASE, uv: true });
    await T(G, "PK-01", "registro de passkey exige sessao; credencial persistida (chave publica, contador, tipo)", async () => {
      const semSessao = await new Client("anon").get("/api/auth/passkey/generate-register-options");
      const r = await registerPasskey(U, authrUV);
      const row = await prisma.passkey.findFirst({ where: { userId: U.id } });
      return (semSessao.status >= 400 && r.ok && row?.publicKey && row.counter === 0) ? ok(`sem sessao=${semSessao.status}; registro 200; passkey persistida (publicKey, counter=${row.counter}, deviceType=${row.deviceType}, backedUp=${row.backedUp})`) : fail(JSON.stringify({ semSessao: semSessao.status, r }));
    });
    await T(G, "PK-02", "login com passkey (UV=true) cria sessao SEM senha; CONTIFISC atesta [passkey] aal=2 lendo o flag UV do authenticatorData", async () => {
      const l = await passkeyLogin(authrUV); if (!l.ok) return fail(JSON.stringify({ step: l.step, st: l.status, t: l.text }));
      const p = await idp.resolve({ headers: hdr(l.c) }, { bypassSessionCache: true });
      return (p?.factors.join() === "passkey" && p.authenticationLevel === 2 && satisfiesAuthenticationLevel(p, { minLevel: 2 })) ? ok(`sessao criada; fatores=${p.factors}; nivel=${p.authenticationLevel} (UV lido do authenticatorData pela CONTIFISC)`) : fail(JSON.stringify(p));
    });
    await T(G, "PK-03", "assercao SEM UV (UV=false) com userVerification='preferred': provedor ACEITA; CONTIFISC atesta so aal=1", async () => {
      const u2 = await newUser("pk-nouv"); const nouv = new SoftAuthenticator({ origin: BASE, uv: false });
      const reg = await registerPasskey(u2, nouv);
      const l = await passkeyLogin(nouv); const p = l.ok ? await idp.resolve({ headers: hdr(l.c) }, { bypassSessionCache: true }) : null;
      if (!reg.ok) return fail("registro sem UV recusado: " + reg.text);
      if (!l.ok) return ok(`assercao sem UV RECUSADA pelo provedor (${l.status})`);
      return (p.authenticationLevel === 1) ? res(`provedor aceitou assercao sem UV (login ${l.status}); sem UV nao ha 2o fator => CONTIFISC atesta nivel=${p.authenticationLevel} (nao presume aal2 por 'ser passkey')`) : fail("nivel indevido");
    });
    await T(G, "PK-04", "usuario com TOTP habilitado + passkey: login por passkey NAO passa pelo desafio TOTP (politica CONTIFISC decide via UV)", async () => {
      const u3 = await newUser("pk-2fa"); const e = await u3.c.post("/api/auth/two-factor/enable", { password: PW }); const totp = OTPAuth.URI.parse(e.json.totpURI); await u3.c.post("/api/auth/two-factor/verify-totp", { code: totp.generate() });
      const a3 = new SoftAuthenticator({ origin: BASE, uv: true }); await registerPasskey(u3, a3);
      const l = await passkeyLogin(a3); const p = l.ok ? await idp.resolve({ headers: hdr(l.c) }, { bypassSessionCache: true }) : null;
      return (l.ok && p && p.factors.join() === "passkey") ? res(`sessao criada direto via passkey sem pedir TOTP (nivel CONTIFISC=${p.authenticationLevel}, fator unico 'passkey'). Aceitavel somente se a politica CONTIFISC tratar passkey+UV como aal2; caso contrario exigir step-up`) : fail(JSON.stringify({ ok: l.ok, st: l.status, t: l.text }));
    });
    await T(G, "PK-05", "replay: reapresentar a MESMA assercao (mesmo challenge/contador) e rejeitado", async () => {
      const l = await passkeyLogin(authrUV); if (!l.ok) return fail("login base falhou");
      const c2 = new Client("replay"); const o2 = await c2.get("/api/auth/passkey/generate-authenticate-options");   // novo challenge
      const r = await c2.post("/api/auth/passkey/verify-authentication", { response: l.assertion });                  // assercao antiga (challenge antigo)
      return r.status >= 400 ? ok(`replay rejeitado (${r.status})`) : fail(`replay aceito (${r.status})`);
    });
    await T(G, "PK-06", "contador nao-monotonico (clone): assercao com contador <= armazenado e rejeitada", async () => {
      const a = new SoftAuthenticator({ origin: BASE, uv: true }); const u4 = await newUser("pk-clone"); await registerPasskey(u4, a);
      const l1 = await passkeyLogin(a);                       // counter 1
      const l2 = await passkeyLogin(a, { bumpCounter: false }); // reusa contador 1 (regressao/clone)
      const row = await prisma.passkey.findFirst({ where: { userId: u4.id } });
      return (l1.ok && !l2.ok) ? ok(`1o login ok (contador ${row.counter}); reuso do contador rejeitado (${l2.status})`) : res(`contador repetido aceito: l1=${l1.status} l2=${l2.status}`);
    });
    await T(G, "PK-07", "revogacao da passkey: apos delete, login com a credencial falha; sessoes existentes seguem ate revogacao explicita", async () => {
      const a = new SoftAuthenticator({ origin: BASE, uv: true }); const u5 = await newUser("pk-del"); await registerPasskey(u5, a);
      const before = await passkeyLogin(a); const list = await u5.c.get("/api/auth/passkey/list-user-passkeys"); const pkId = list.json?.[0]?.id;
      const del = await u5.c.post("/api/auth/passkey/delete-passkey", { id: pkId });
      const after = await passkeyLogin(a); const sessAntiga = await sess(before.c);
      return (before.ok && del.status === 200 && !after.ok) ? (sessAntiga?.session ? res(`delete 200; login com a credencial removida=${after.status}; sessao criada antes CONTINUA valida => revogar sessoes junto (CONTIFISC)`) : ok("delete 200; login falha; sessao antiga encerrada")) : fail(JSON.stringify({ b: before.ok, del: del.status, a: after.status }));
    });
    await T(G, "PK-08", "origem/RP ID errados sao rejeitados (anti-phishing)", async () => {
      const a = new SoftAuthenticator({ origin: BASE, uv: true }); const u6 = await newUser("pk-orig"); await registerPasskey(u6, a);
      const c = new Client("phish"); const o = await c.get("/api/auth/passkey/generate-authenticate-options");
      const evil = a.assert(o.json.challenge, { overrideOrigin: "https://evil.example" });
      const r = await c.post("/api/auth/passkey/verify-authentication", { response: evil });
      return r.status >= 400 ? ok(`assercao com origin=https://evil.example rejeitada (${r.status})`) : fail("origin falso aceito");
    });
  } finally { await srv.close(); }

  // ===== servidor com UV "required" =====
  auth = buildAuth({ passkeyUV: "required" }); srv = await startServer(auth); idp = betterAuthProvider(auth);
  try {
    await T(G, "PK-09", "userVerification='required' no plugin: o SERVIDOR rejeita assercao sem UV? (achado: nao impoe)", async () => {
      const u = await newUser("pk-req"); const nouv = new SoftAuthenticator({ origin: BASE, uv: false });
      const reg = await registerPasskey(u, nouv);
      const uvOk = new SoftAuthenticator({ origin: BASE, uv: true }); const u2 = await newUser("pk-req2"); const regOk = await registerPasskey(u2, uvOk);
      const l1 = reg.ok ? await passkeyLogin(nouv) : { ok: false, status: "registro recusado" }; const l2 = regOk.ok ? await passkeyLogin(uvOk) : { ok: false, status: "registro falhou" };
      return (!l1.ok && l2.ok) ? ok(`sem UV: ${reg.ok ? "login " : ""}rejeitado (${l1.status}); com UV: login ${l2.status}. Recomendado: userVerification='required' para papeis que exigem aal2`) : res(`sem UV ok=${l1.ok}(${l1.status}) com UV ok=${l2.ok}(${l2.status})`);
    });
  } finally { await srv.close(); }
  await T(G, "PK-10", "recuperacao de conta so-passkey (perda do dispositivo)", async () => nc("nao ha fluxo nativo de recuperacao para conta sem senha: exigiria identity proofing administrativo (CONTIFISC) + novo vinculo/credencial; nao testado como fluxo ponta-a-ponta"));
  await T(G, "PK-11", "passkey em autenticador REAL (Touch ID/Windows Hello/YubiKey)", async () => nc("NAO EXECUTADO: exige autenticador fisico/navegador (acao humana). O protocolo foi exercitado com autenticador por software ES256 (attestation none) contra o servidor real."));
  return results.filter((r) => r.group === G);
}
