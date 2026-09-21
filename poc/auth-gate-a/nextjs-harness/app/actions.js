"use server";
import { headers } from "next/headers";
import { auth } from "../lib/auth";

// Server Action = endpoint POST publico: a autorizacao acontece AQUI dentro (nunca so no proxy/menu).
export async function whoAmIAction() {
  const s = await auth.api.getSession({ headers: await headers() });
  return s ? { ok: true, subject: s.user.id } : { ok: false, error: "UNAUTHENTICATED" };
}
export async function signInAction(formData) {
  await auth.api.signInEmail({ body: { email: String(formData.get("email")), password: String(formData.get("password")) }, headers: await headers() });
}
