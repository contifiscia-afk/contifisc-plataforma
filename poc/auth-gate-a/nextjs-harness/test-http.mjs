// Teste HTTP do harness Next (producao). Nao imprime cookies/tokens.
import fs from "node:fs";
const B = "http://localhost:3401"; const results = [];
const rec = (id, status, title, ev = "") => { results.push({ group: "N-nextjs16", id, status, title, evidence: ev }); console.log(`${status.padEnd(17)} ${id.padEnd(7)} ${title}${ev ? " :: " + ev : ""}`); };
const jar = new Map(); const ck = () => [...jar].map(([k, v]) => `${k}=${v}`).join("; ");
const absorb = (r) => { for (const sc of r.headers.getSetCookie?.() ?? []) { const [p] = sc.split(";"); const i = p.indexOf("="); jar.set(p.slice(0, i), p.slice(i + 1)); } };
const html = async (path, cookie) => { const r = await fetch(B + path, { headers: cookie ? { cookie } : {}, redirect: "manual" }); return { st: r.status, loc: r.headers.get("location"), body: (await r.text()).replace(/<!-- -->/g, "") }; };
const email = `next.${Date.now()}@example.test`, PW = "Correct-Horse-Battery-9!";
try {
  let r = await fetch(B + "/api/auth/sign-up/email", { method: "POST", headers: { "content-type": "application/json", origin: B }, body: JSON.stringify({ email, password: PW, name: "next" }) });
  absorb(r); const j = await r.json();
  rec("NX-01", r.status === 200 && jar.size > 0 ? "PASS" : "FAIL", "Route Handler (App Router) do Better Auth: sign-up + Set-Cookie", `status ${r.status}; cookies=[${[...jar.keys()]}]`);
  const uid = j?.user?.id;
  let p = await html("/", ck()); rec("NX-02", p.body.includes(`session:${uid}`) ? "PASS" : "FAIL", "Server Component (RSC) valida a sessao no servidor via auth.api.getSession", `contem session:<id>=${p.body.includes(`session:${uid}`)}`);
  p = await html("/"); rec("NX-03", p.body.includes("no-session") ? "PASS" : "FAIL", "RSC sem cookie => no-session", "");
  p = await html("/protected"); rec("NX-04", p.st >= 300 && p.st < 400 ? "PASS" : "FAIL", "proxy: sem cookie => redirect (triagem grosseira)", `status ${p.st} -> ${p.loc}`);
  p = await html("/protected", "better-auth.session_token=cookie-forjado.assinatura-falsa");
  rec("NX-05", p.st === 200 && p.body.includes("UNAUTHORIZED-SERVER-SIDE") ? "PASS_COM_RESSALVA" : "FAIL", "proxy so checa EXISTENCIA do cookie: cookie forjado PASSA o proxy, mas a pagina (servidor) nega", `status ${p.st}; corpo=${p.body.includes("UNAUTHORIZED-SERVER-SIDE") ? "UNAUTHORIZED-SERVER-SIDE" : "outro"} => proxy NAO e autoridade; validar em toda rota/RSC/action`);
  p = await html("/protected", ck()); rec("NX-06", p.body.includes(`PROTECTED-OK:${uid}`) ? "PASS" : "FAIL", "sessao valida => pagina protegida renderiza (validacao no servidor)", "");
  const name = [...jar.keys()][0]; const tamp = `${name}=${jar.get(name).slice(0, -3)}AAA`;
  p = await html("/protected", tamp); rec("NX-07", p.body.includes("UNAUTHORIZED-SERVER-SIDE") ? "PASS" : "FAIL", "cookie adulterado (assinatura) => negado no servidor", "");
} catch (e) { rec("NX-ERR", "FAIL", "erro no teste", String(e.message).slice(0, 200)); }
fs.writeFileSync("../results/nextjs16-http.json", JSON.stringify(results, null, 2));
console.log("EMAIL_PARA_BROWSER=" + email);
