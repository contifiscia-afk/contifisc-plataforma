// PoC DESCARTAVEL (Gate A / ADR-003). Fabrica de instancias Better Auth self-hosted.
// Nada aqui vai para o produto. Segredos: gerados em memoria por execucao; nunca persistidos.
import http from "node:http";
import crypto from "node:crypto";
import { betterAuth } from "better-auth";
import { createAuthMiddleware } from "better-auth/api";
import { toNodeHandler } from "better-auth/node";
import { prismaAdapter } from "@better-auth/prisma-adapter";
import { twoFactor, admin, genericOAuth } from "better-auth/plugins";
import { passkey } from "@better-auth/passkey";
import { PrismaClient } from "@prisma/client";

export const prisma = new PrismaClient();
export const PORT = 3400;
export const BASE = `http://localhost:${PORT}`;
export const outbox = { resetTokens: [], changeEmail: [], verify: [] }; // e-mails "enviados" (capturados em memoria)

// Mapeamento CONTIFISC (NAO do provedor) de "como a sessao foi criada" -> metodo/AAL.
// O AAL e CALCULADO pela CONTIFISC a partir do endpoint que criou a sessao - o provedor nao expoe AAL.
export function classifyAuthEndpoint(path, extra = {}) {
  if (path === "/sign-in/email" || path === "/sign-up/email") return { metodos: ["pwd"], aal: 1 };
  if (path === "/two-factor/verify-totp") return { metodos: ["pwd", "totp"], aal: 2 };
  if (path === "/two-factor/verify-backup-code") return { metodos: ["pwd", "backup_code"], aal: 2 };
  if (path === "/two-factor/verify-otp") return { metodos: ["pwd", "otp"], aal: 2 };
  if (path === "/passkey/verify-authentication") return { metodos: ["passkey"], aal: extra.passkeyUV ? 2 : 1 };
  if (path.startsWith("/oauth2/callback") || path.startsWith("/callback/")) return { metodos: ["oauth"], aal: 1 };
  return null;
}

export function buildAuth(opts = {}) {
  const {
    secret = crypto.randomBytes(32).toString("hex"),
    sessionExpiresIn = 60 * 60 * 24 * 7,
    sessionUpdateAge = 60 * 60 * 24,
    cookieCache = false,
    freshAge,
    disableImplicitLinking = false,
    useSecureCookies = false,
    oauthProviders = [],
    passkeyUV = "preferred",
    baseURL = BASE,
    evidenceLog = [],
    disableSignUp = false,
    rateLimit,
  } = opts;

  const auth = betterAuth({
    baseURL,
    secret,
    trustedOrigins: [BASE],
    database: prismaAdapter(prisma, { provider: "postgresql" }),
    emailAndPassword: {
      enabled: true,
      disableSignUp,
      requireEmailVerification: false,
      minPasswordLength: 12,
      sendResetPassword: async ({ user, token }) => { outbox.resetTokens.push({ email: user.email, token }); },
      revokeSessionsOnPasswordReset: true,
    },
    user: {
      // PoC: e-mail e MUTAVEL. (Sem verificacao so para testar a mutabilidade do e-mail; em producao exigir verificacao.)
      changeEmail: { enabled: true, updateEmailWithoutVerification: true },
      deleteUser: { enabled: true },
    },
    emailVerification: {
      sendVerificationEmail: async ({ user, token }) => { outbox.verify.push({ email: user.email, token }); },
    },
    session: {
      expiresIn: sessionExpiresIn,
      updateAge: sessionUpdateAge,
      ...(freshAge !== undefined ? { freshAge } : {}),
      cookieCache: cookieCache ? { enabled: true, maxAge: cookieCache } : { enabled: false },
    },
    account: { accountLinking: { enabled: true, disableImplicitLinking, trustedProviders: [] } },
    advanced: { useSecureCookies },
    ...(rateLimit ? { rateLimit } : {}),
    plugins: [
      twoFactor({ issuer: "CONTIFISC-PoC" }),
      admin(),
      passkey({
        rpID: "localhost",
        rpName: "CONTIFISC-PoC",
        origin: BASE,
        authenticatorSelection: { userVerification: passkeyUV, residentKey: "preferred" },
      }),
      genericOAuth({ config: oauthProviders }),
    ],
    hooks: {
      // CONTIFISC registra a EVIDENCIA de autenticacao por sessao (base do AAL). O provedor nao a fornece.
      after: createAuthMiddleware(async (ctx) => {
        const s = ctx.context.newSession;
        if (!s) return;
        // Passkey: a CONTIFISC le o flag UV (user verification) do authenticatorData da PROPRIA assercao
        // (so vale apos o provedor verificar a assinatura; newSession so existe em caso de sucesso).
        const extra = {};
        if (ctx.path === "/passkey/verify-authentication") {
          try { const ad = Buffer.from(ctx.body?.response?.response?.authenticatorData ?? "", "base64url"); extra.passkeyUV = ad.length > 32 && (ad[32] & 0x04) !== 0; } catch { /* ignora */ }
        }
        const cls = classifyAuthEndpoint(ctx.path, extra);
        evidenceLog.push({ path: ctx.path, sessionId: s.session.id, cls });
        if (!cls) return;
        await prisma.sessaoEvidenciaAuth.upsert({
          where: { session_id: s.session.id },
          update: { metodos: cls.metodos, aal: cls.aal },
          create: { session_id: s.session.id, metodos: cls.metodos, aal: cls.aal },
        });
      }),
    },
  });
  return auth;
}

export async function startServer(auth, extraRoutes) {
  const handler = toNodeHandler(auth);
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, BASE);
    if (extraRoutes && (await extraRoutes(req, res, url))) return;
    if (url.pathname.startsWith("/api/auth")) return handler(req, res);
    res.statusCode = 404; res.end("not found");
  });
  await new Promise((r) => server.listen(PORT, r));
  return { server, close: () => new Promise((r) => { server.closeAllConnections?.(); server.close(r); }) };
}

