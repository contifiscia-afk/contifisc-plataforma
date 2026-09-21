// Cliente HTTP minimo com cookie jar (PoC). Nunca loga valores de cookie/token.
import { BASE } from "./auth-factory.mjs";

export class Client {
  constructor(name = "client", origin = BASE) { this.name = name; this.jar = new Map(); this.origin = origin; }
  cookieHeader() { return [...this.jar.entries()].map(([k, v]) => `${k}=${v}`).join("; "); }
  absorb(res) {
    const list = res.headers.getSetCookie?.() ?? [];
    const attrs = [];
    for (const sc of list) {
      const [pair, ...rest] = sc.split(";").map((s) => s.trim());
      const i = pair.indexOf("=");
      const k = pair.slice(0, i), v = pair.slice(i + 1);
      const flags = Object.fromEntries(rest.map((r) => { const [a, b] = r.split("="); return [a.toLowerCase(), b ?? true]; }));
      attrs.push({ name: k, flags });
      if (v === "" || flags["max-age"] === "0" || (flags.expires && new Date(flags.expires) < new Date())) this.jar.delete(k);
      else this.jar.set(k, v);
    }
    return attrs;
  }
  async req(method, path, { body, headers = {}, origin = this.origin, noOrigin = false, redirect = "manual" } = {}) {
    const h = { ...headers };
    const ck = this.cookieHeader();
    if (ck) h.cookie = ck;
    if (!noOrigin && method !== "GET") h.origin = origin;
    if (body !== undefined) h["content-type"] = "application/json";
    const doFetch = () => fetch(BASE + path, { method, headers: h, body: body !== undefined ? JSON.stringify(body) : undefined, redirect });
    let res; try { res = await doFetch(); } catch (e) { if (String(e.message).includes("fetch failed")) res = await doFetch(); else throw e; } // socket keep-alive obsoleto entre servidores do harness
    const setCookies = this.absorb(res);
    let json = null; const text = await res.text();
    try { json = JSON.parse(text); } catch { /* nao-JSON */ }
    return { status: res.status, json, text, setCookies, headers: res.headers };
  }
  get(path, o) { return this.req("GET", path, o); }
  post(path, body = {}, o = {}) { return this.req("POST", path, { body, ...o }); }
  hasCookie(substr) { return [...this.jar.keys()].some((k) => k.includes(substr)); }
  cookieNames() { return [...this.jar.keys()]; }
  clone(name) { const c = new Client(name, this.origin); c.jar = new Map(this.jar); return c; }
}

