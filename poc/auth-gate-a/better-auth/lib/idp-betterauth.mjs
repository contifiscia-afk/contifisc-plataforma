// Adapter Better Auth -> contrato IdentityProvider (PoC). O dominio CONTIFISC so ve AuthenticatedIdentity.
import { prisma } from "./auth-factory.mjs";

export function betterAuthProvider(auth, { issuer = "poc-local", elevationWindowSeconds = 600 } = {}) {
  return {
    provider: "better_auth",
    issuer,
    async resolve(request, options = {}) {
      // Validacao SERVER-SIDE (nao apenas "cookie existe"). bypassSessionCache evita cookie cache stale.
      const s = await auth.api.getSession({
        headers: request.headers,
        query: options.bypassSessionCache ? { disableCookieCache: true } : undefined,
      });
      if (!s?.session) return null;
      const ev = await prisma.sessaoEvidenciaAuth.findUnique({ where: { session_id: s.session.id } });
      const now = Date.now();
      const elevated = ev?.aal_elevado_ate && ev.aal_elevado_ate.getTime() > now;
      const level = ev ? (elevated ? Math.max(ev.aal, 2) : ev.aal) : 1;
      return {
        provider: "better_auth",
        issuer,
        subject: s.user.id,               // id estavel do provedor (NUNCA e-mail)
        sessionId: s.session.id,
        authenticatedAt: s.session.createdAt instanceof Date ? s.session.createdAt : new Date(s.session.createdAt),
        sessionExpiresAt: new Date(s.session.expiresAt),
        authenticationLevel: level,
        factors: ev?.metodos ?? [],
        lastFactorVerifiedAt: elevated ? new Date(ev.aal_elevado_ate.getTime() - elevationWindowSeconds * 1000) : undefined,
        evidence: ev ? "contifisc_hook" : "unknown",
      };
    },
    async revokeSession(sessionId) { await prisma.session.deleteMany({ where: { id: sessionId } }); },
    async revokeAllSessions(subject) { const r = await prisma.session.deleteMany({ where: { userId: subject } }); return r.count; },
    // Step-up CONTIFISC: reverifica TOTP via API do provedor e registra elevacao (janela finita). Sem hook do provedor.
    async stepUp(request, { factor, code }) {
      if (factor !== "totp" && factor !== "backup_code") return false;
      try {
        const s = await auth.api.getSession({ headers: request.headers, query: { disableCookieCache: true } });
        if (!s?.session) return false;
        const call = factor === "totp" ? auth.api.verifyTOTP : auth.api.verifyBackupCode;
        await call({ headers: request.headers, body: { code } });
        await prisma.sessaoEvidenciaAuth.upsert({
          where: { session_id: s.session.id },
          update: { aal_elevado_ate: new Date(Date.now() + elevationWindowSeconds * 1000) },
          create: { session_id: s.session.id, metodos: [], aal: 1, aal_elevado_ate: new Date(Date.now() + elevationWindowSeconds * 1000) },
        });
        return true;
      } catch { return false; }
    },
  };
}
