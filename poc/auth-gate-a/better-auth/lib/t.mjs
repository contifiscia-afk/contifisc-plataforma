// Mini-framework de testes do Gate A. Registra PASS / FAIL / PASS_COM_RESSALVA / NAO_COMPROVADO / INFO com evidencia (sem segredos).
import fs from "node:fs";
export const results = [];
export const S = { PASS: "PASS", FAIL: "FAIL", RES: "PASS_COM_RESSALVA", NC: "NAO_COMPROVADO", INFO: "INFO" };
export function rec(group, id, status, title, evidence) {
  results.push({ group, id, status, title, evidence: evidence ?? "" });
  console.log(`${status.padEnd(17)} ${id.padEnd(8)} ${title}${evidence ? " :: " + evidence : ""}`);
}
export async function T(group, id, title, fn) {
  try {
    const r = await fn();
    if (r === true) rec(group, id, S.PASS, title);
    else if (r === false) rec(group, id, S.FAIL, title);
    else if (r && r.status) rec(group, id, r.status, title, r.evidence);
    else rec(group, id, S.FAIL, title, "retorno invalido");
  } catch (e) {
    rec(group, id, S.FAIL, title, "EXCECAO " + String(e.message).replace(/\s+/g, " ").slice(0, 220));
  }
}
export const ok = (evidence) => ({ status: S.PASS, evidence });
export const res = (evidence) => ({ status: S.RES, evidence });
export const info = (evidence) => ({ status: S.INFO, evidence });
export const nc = (evidence) => ({ status: S.NC, evidence });
export const fail = (evidence) => ({ status: S.FAIL, evidence });
export function save(file) { fs.writeFileSync(file, JSON.stringify(results, null, 2)); }
export const uniq = (tag) => `${tag}.${Date.now().toString(36)}.${Math.random().toString(36).slice(2, 6)}@example.test`;
export const PW = "Correct-Horse-Battery-9!";
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const hdr = (client) => new Headers({ cookie: client.cookieHeader() });
