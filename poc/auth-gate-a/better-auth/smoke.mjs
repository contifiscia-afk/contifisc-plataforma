// Fumaça: descobre o comportamento real da API antes da suíte. Nao imprime cookies/tokens.
import { buildAuth, startServer, prisma } from "./lib/auth-factory.mjs";
import { Client } from "./lib/http.mjs";

const auth = buildAuth();
const { close } = await startServer(auth);
try {
  const c = new Client("u1");
  const email = `smoke.${Date.now()}@example.test`;
  let r = await c.post("/api/auth/sign-up/email", { email, password: "Correct-Horse-Battery-9", name: "Smoke" });
  console.log("sign-up", r.status, Object.keys(r.json ?? {}), "cookies:", c.cookieNames());
  console.log("setCookie flags:", JSON.stringify(r.setCookies));
  r = await c.get("/api/auth/get-session");
  console.log("get-session", r.status, "user.id?", !!r.json?.user?.id, "session keys:", Object.keys(r.json?.session ?? {}));
  const rows = await prisma.sessaoEvidenciaAuth.findMany();
  console.log("evidencia:", rows.map((x) => ({ metodos: x.metodos, aal: x.aal })));
  r = await c.post("/api/auth/sign-out");
  console.log("sign-out", r.status);
  r = await c.get("/api/auth/get-session");
  console.log("get-session pos-logout", r.status, JSON.stringify(r.json));
  // CSRF: Origin errado
  const c2 = new Client("evil");
  r = await c2.post("/api/auth/sign-in/email", { email, password: "Correct-Horse-Battery-9" }, { origin: "http://evil.example" });
  console.log("sign-in origin evil", r.status, JSON.stringify(r.json));
} finally {
  await close();
  await prisma.$disconnect();
}
