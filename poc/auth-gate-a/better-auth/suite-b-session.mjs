// SUITE B — Sessao: cookies, validacao server-side, expiracao, refresh, logout, revogacao, cache de cookie, CSRF, fixation, ban, recuperacao.
import { buildAuth, startServer, prisma, outbox } from "./lib/auth-factory.mjs";
import { Client } from "./lib/http.mjs";
import { betterAuthProvider } from "./lib/idp-betterauth.mjs";
import { T, ok, res, info, nc, fail, uniq, PW, hdr, sleep, results } from "./lib/t.mjs";

const G = "B-sessao";
async function withServer(opts, fn) {
  const auth = buildAuth(opts); const srv = await startServer(auth);
  try { return await fn(auth); } finally { await srv.close(); }
}
async function newUser(tag) {
  const c = new Client(tag); const email = uniq(tag);
  const r = await c.post("/api/auth/sign-up/email", { email, password: PW, name: tag });
  return { c, email, id: r.json?.user?.id, signUpCookies: r.setCookies };
}
async function login(email, tag = "login") {
  const c = new Client(tag); const r = await c.post("/api/auth/sign-in/email", { email, password: PW });
  return { c, r };
}
const sess = async (c, q = "") => (await c.get("/api/auth/get-session" + q)).json;

export async function run() {
  // ---------------- servidor padrao ----------------
  await withServer({}, async (auth) => {
    const idp = betterAuthProvider(auth);
    const U = await newUser("ses");
    await T(G, "SES-01", "cookie de sessao: HttpOnly + SameSite=Lax + Path=/ ; Secure so em HTTPS (config); valor assinado", async () => {
      const c = U.signUpCookies.find((x) => x.name.includes("session_token"));
      const f = c?.flags ?? {};
      const signed = (U.c.jar.get(c.name) ?? "").includes(".");
      return (f.httponly && String(f.samesite).toLowerCase() === "lax" && f.path === "/" && signed) ? ok(`flags: HttpOnly, SameSite=Lax, Path=/, max-age=${f["max-age"]}s; valor assinado (token.assinatura); Secure ausente em http`) : fail(JSON.stringify(c));
    });
    await T(G, "SES-02", "validacao server-side: cookie adulterado/sem assinatura => sessao invalida", async () => {
      const name = [...U.c.jar.keys()].find((k) => k.includes("session_token")); const val = U.c.jar.get(name);
      const t1 = new Client("t1"); t1.jar.set(name, val.slice(0, -3) + (val.endsWith("AAA") ? "BBB" : "AAA"));
      const t2 = new Client("t2"); t2.jar.set(name, val.split(".")[0]);           // token cru, sem assinatura
      const s1 = await sess(t1), s2 = await sess(t2), s0 = await sess(U.c);
      return (s1 === null && s2 === null && s0?.session) ? ok("assinatura adulterada=null; token cru=null; original valido") : fail(JSON.stringify({ s1: !!s1, s2: !!s2 }));
    });
    await T(G, "SES-03", "logout revoga NO SERVIDOR: cookie roubado antes do logout deixa de valer", async () => {
      const { c } = await login(U.email, "lg"); const stolen = c.clone("stolen");
      const before = await sess(stolen); await c.post("/api/auth/sign-out"); const after = await sess(stolen);
      return (before?.session && after === null) ? ok("cookie copiado valia; apos sign-out => null (token removido no servidor)") : fail("sessao persistiu apos logout");
    });
    await T(G, "SES-04", "revogacao: outras sessoes / uma sessao / todas", async () => {
      const a = (await login(U.email, "a")).c, b = (await login(U.email, "b")).c, d = (await login(U.email, "d")).c;
      const ts = await sess(b); const tokenB = ts.session.token;
      let r = await a.post("/api/auth/revoke-session", { token: tokenB });
      const bAfter = await sess(b);                                   // revogada individualmente
      r = await a.post("/api/auth/revoke-other-sessions");
      const dAfter = await sess(d), aStill = await sess(a);           // d revogada, a mantida
      await a.post("/api/auth/revoke-sessions"); const aFinal = await sess(a);
      return (bAfter === null && dAfter === null && aStill?.session && aFinal === null) ? ok("revoke-session (b) ok; revoke-other-sessions (d) ok e a mantida; revoke-sessions (a) ok") : fail(JSON.stringify({ b: !!bAfter, d: !!dAfter, a: !!aStill, f: !!aFinal }));
    });
    await T(G, "SES-05", "fixation: cookie forjado pre-login nao vira sessao; login emite token NOVO", async () => {
      const atk = new Client("atk"); const name = "better-auth.session_token";
      atk.jar.set(name, "tokenConhecidoPeloAtacante.assinaturaFalsa");
      const victim = new Client("victim"); victim.jar = new Map(atk.jar);                 // navegador da vitima recebeu o cookie forjado
      const r = await victim.post("/api/auth/sign-in/email", { email: U.email, password: PW });
      const newTok = victim.jar.get(name);
      const atkSession = await sess(atk);                                                 // atacante tenta usar o valor que conhece
      return (r.status === 200 && newTok && newTok !== "tokenConhecidoPeloAtacante.assinaturaFalsa" && atkSession === null) ? ok("login sobrescreve o cookie com token novo gerado no servidor; valor do atacante invalido") : fail("fixation possivel");
    });
    await T(G, "SES-06", "login repetido: sessao ANTERIOR nao e revogada automaticamente (sem rotacao/limite)", async () => {
      const a = (await login(U.email, "r1")).c; const b = (await login(U.email, "r2")).c;
      const ta = (await sess(a)).session.token, tb = (await sess(b)).session.token;
      const aStill = await sess(a);
      await a.post("/api/auth/revoke-sessions");
      return (ta !== tb && aStill?.session) ? res("tokens distintos; sessao antiga continua valida ate revogacao explicita => CONTIFISC deve impor politica (max sessoes/revogar ao elevar privilegio)") : fail("comportamento inesperado");
    });
    await T(G, "SES-07", "CSRF: POST com Origin de terceiro e bloqueado (403 INVALID_ORIGIN)", async () => {
      const c = (await login(U.email, "csrf")).c;
      const r1 = await c.post("/api/auth/revoke-sessions", {}, { origin: "http://evil.example" });
      const r2 = await c.post("/api/auth/revoke-sessions", {}, { noOrigin: true });
      const still = await sess(c);
      const stillAfterEvil = !!still?.session;
      return (r1.status === 403 && stillAfterEvil) ? ok(`Origin evil => ${r1.status} ${r1.json?.code}; sem Origin => ${r2.status}${r2.json?.code ? " " + r2.json.code : ""}; sessao intacta apos tentativa evil`) : fail(`evil=${r1.status}`);
    });
    await T(G, "SES-08", "sessao roubada: replay com User-Agent diferente continua valido (sem binding de dispositivo)", async () => {
      const { c } = await login(U.email, "ua"); const other = c.clone("other-ua");
      const r = await other.get("/api/auth/get-session", { headers: { "user-agent": "OutroNavegador/9.9 (atacante)", "x-forwarded-for": "203.0.113.77" } });
      return r.json?.session ? res("BA registra ip/userAgent na sessao mas NAO os impoe => CONTIFISC precisa de sinal proprio (device binding/alerta) para T8 do threat model") : ok("sessao invalidada por mudanca de UA");
    });
    await T(G, "SES-09", "usuario banido (admin) => sessoes revogadas e novo login bloqueado", async () => {
      const adm = await newUser("adm"); await prisma.user.update({ where: { id: adm.id }, data: { role: "admin" } });
      const vic = await newUser("vic"); const vic2 = (await login(vic.email, "vic2")).c;
      const rBan = await adm.c.post("/api/auth/admin/ban-user", { userId: vic.id, banReason: "PoC" });
      const s1 = await sess(vic.c), s2 = await sess(vic2);
      const relog = await login(vic.email, "relog");
      await adm.c.post("/api/auth/admin/unban-user", { userId: vic.id });
      const relog2 = await login(vic.email, "relog2");
      return (rBan.status === 200 && s1 === null && s2 === null && relog.r.status >= 400 && relog2.r.status === 200) ? ok(`ban 200; 2 sessoes=null; login banido=${relog.r.status} ${relog.r.json?.code ?? ""}; apos unban=200`) : fail(JSON.stringify({ ban: rBan.status, s1: !!s1, s2: !!s2, relog: relog.r.status }));
    });
    await T(G, "SES-10", "recuperacao (reset de senha): token de uso unico; reset revoga TODAS as sessoes", async () => {
      const u = await newUser("rec"); const other = (await login(u.email, "rec2")).c;
      const r = await new Client("rq").post("/api/auth/request-password-reset", { email: u.email, redirectTo: "http://localhost:3400/reset" });
      const tok = outbox.resetTokens.filter((x) => x.email === u.email).at(-1)?.token;
      if (!tok) return fail(`sem token de reset (status ${r.status} ${r.text.slice(0, 80)})`);
      const NEWPW = "Nova-Senha-Forte-7!!";
      const rr = await new Client("rs").post("/api/auth/reset-password", { newPassword: NEWPW, token: tok });
      const reuse = await new Client("rs2").post("/api/auth/reset-password", { newPassword: "Outra-Senha-Forte-1!!", token: tok });
      const oldSess = await sess(u.c), oldSess2 = await sess(other);
      const relog = await new Client("nl").post("/api/auth/sign-in/email", { email: u.email, password: NEWPW });
      return (rr.status === 200 && reuse.status >= 400 && oldSess === null && oldSess2 === null && relog.status === 200) ? ok("reset 200; reuso do token=" + reuse.status + "; 2 sessoes antigas revogadas; login com nova senha ok") : fail(JSON.stringify({ rr: rr.status, reuse: reuse.status, o1: !!oldSess, o2: !!oldSess2, relog: relog.status }));
    });
    await T(G, "SES-11", "troca de senha com revokeOtherSessions revoga as demais sessoes", async () => {
      const u = await newUser("chg"); const other = (await login(u.email, "chg2")).c;
      const r = await u.c.post("/api/auth/change-password", { currentPassword: PW, newPassword: "Senha-Trocada-Forte-3!!", revokeOtherSessions: true });
      const o = await sess(other), me = await sess(u.c);
      return (r.status === 200 && o === null) ? ok(`change-password 200; outra sessao=null; sessao atual ${me?.session ? "mantida/renovada" : "encerrada"}`) : fail(`status ${r.status}`);
    });
    await T(G, "SES-12", "adapter CONTIFISC: revokeAllSessions(subject) e revokeSession(id) no provedor", async () => {
      const u = await newUser("rvk"); const b = (await login(u.email, "rvk2")).c;
      const p = await idp.resolve({ headers: hdr(u.c) });
      await idp.revokeSession(p.sessionId); const a1 = await sess(u.c), b1 = await sess(b);
      const n = await idp.revokeAllSessions(u.id); const b2 = await sess(b);
      return (a1 === null && b1?.session && b2 === null && n >= 1) ? ok("revokeSession derruba so a sessao alvo; revokeAllSessions derruba o restante (via adapter)") : fail(JSON.stringify({ a1: !!a1, b1: !!b1, b2: !!b2 }));
    });
  });

  // ---------------- cookies seguros (HTTPS) ----------------
  await withServer({ useSecureCookies: true }, async () => {
    await T(G, "SES-13", "config useSecureCookies: cookie com prefixo __Secure- e flag Secure", async () => {
      const u = await newUser("sec"); const c = u.signUpCookies.find((x) => x.name.includes("session_token"));
      return (c.name.startsWith("__Secure-") && c.flags.secure) ? ok(`nome=${c.name}; Secure=true; HttpOnly=${!!c.flags.httponly}; SameSite=${c.flags.samesite}`) : fail(JSON.stringify(c));
    });
  });

  // ---------------- expiracao ----------------
  await withServer({ sessionExpiresIn: 2, sessionUpdateAge: 60 * 60 }, async () => {
    await T(G, "SES-14", "expiracao absoluta: sessao expira no servidor (expiresIn=2s)", async () => {
      const u = await newUser("exp"); const a = await sess(u.c); await sleep(3200); const b = await sess(u.c);
      return (a?.session && b === null) ? ok("valida em t=0; invalida em t=3,2s (expiresIn=2s)") : fail(JSON.stringify({ a: !!a, b: !!b }));
    });
  });

  // ---------------- refresh (updateAge) ----------------
  await withServer({ sessionExpiresIn: 10, sessionUpdateAge: 1 }, async () => {
    await T(G, "SES-15", "refresh: uso apos updateAge estende expiresAt (sliding); sem uso expira", async () => {
      const u = await newUser("ref"); const e0 = new Date((await sess(u.c)).session.expiresAt).getTime();
      await sleep(2200); const e1 = new Date((await sess(u.c)).session.expiresAt).getTime();
      return (e1 > e0) ? ok(`expiresAt avancou ${(e1 - e0) / 1000}s apos uso (updateAge=1s, expiresIn=10s)`) : fail("sem refresh");
    });
  });

  // ---------------- cookie cache x revogacao ----------------
  await withServer({ cookieCache: 60 }, async (auth) => {
    const idp = betterAuthProvider(auth);
    await T(G, "SES-16", "cookieCache (maxAge=60s): sessao revogada continua 'valida' para o cookie roubado; bypass a invalida", async () => {
      const u = await newUser("cc"); const legit = (await login(u.email, "cc-legit")).c;
      const victim = (await login(u.email, "cc-victim")).c; await sess(victim);            // popula session_data
      const stolen = victim.clone("cc-stolen");
      const namesCache = stolen.cookieNames().filter((n) => n.includes("session_data")).length;
      await legit.post("/api/auth/revoke-sessions");                                       // usuario legitimo revoga TUDO
      const viaCache = await sess(stolen);                                                 // default: pode usar cache
      const viaBypass = await sess(stolen, "?disableCookieCache=true");
      const viaAdapter = await idp.resolve({ headers: hdr(stolen) }, { bypassSessionCache: true });
      const viaAdapterNoBypass = await idp.resolve({ headers: hdr(stolen) }, { bypassSessionCache: false });
      const stale = !!viaCache?.session;
      const detail = `cookie session_data presente=${namesCache > 0}; get-session default=${stale ? "AINDA VALIDA (stale)" : "invalida"}; disableCookieCache=${viaBypass ? "valida" : "invalida"}; adapter(bypass)=${viaAdapter ? "valida" : "invalida"}; adapter(sem bypass)=${viaAdapterNoBypass ? "valida" : "invalida"}`;
      if (viaBypass === null && viaAdapter === null) return stale ? res(detail + " => exige bypass do cache (ou cookieCache desligado) em toda decisao CONTIFISC") : ok(detail);
      return fail(detail);
    });
  });
  return results.filter((r) => r.group === G);
}
