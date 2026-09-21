# PoC DESCARTÁVEL — Gate A (Identity / Auth) — ADR-003

> **Nada aqui faz parte do produto.** Fica fora dos workspaces npm (`apps/*`, `packages/*`), não altera
> `package.json`/`package-lock.json` do repositório, não toca o Neon DEV oficial, o `schema.prisma`
> oficial, a RLS, roles oficiais nem documentos canônicos. Relatório: `docs/poc/GATE_A_IDENTITY_AUTH_REPORT.md`.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `contracts/identity-provider.ts` | Contrato conceitual `IdentityProvider` / `AuthenticatedIdentity` (typecheck `tsc --strict` OK) |
| `better-auth/` | Harness do Better Auth **self-hosted** (Node + Prisma 6.19.3 + PG18 descartável) e as suítes A–G |
| `nextjs-harness/` | Mesma integração em **Next 16.3.5 + React 18.3.1** (App Router, RSC, Server Action, `proxy`) |
| `nextjs-harness-14/` | Mesma app em **Next 14.2.35** (versão atual do repositório; `middleware`) |
| `results/` | Resultados JSON de cada suíte (sem cookies/tokens/segredos) |
| `HUMAN_ACTIONS.md` | Testes que exigem serviço externo/ação humana (Neon Auth, Clerk, Google, autenticador real) |

## Versões testadas

`better-auth` 1.7.5 · `@better-auth/prisma-adapter` 1.7.5 · `@better-auth/passkey` 1.7.5 · `prisma`/`@prisma/client` 6.19.3 ·
`oauth2-mock-server` 9.2.0 · `otpauth` 9.5.2 · `next` 16.3.5 e 14.2.35 · `react` 18.3.1 · `pg` 8.23.0 · Node 24.19.0 ·
PostgreSQL 18.6 (container `postgres:18`, porta 55450, descartável).

## Variáveis de ambiente (apenas NOMES; valores nunca versionados)

`DATABASE_URL` (PG descartável), `DATABASE_URL_MS` (banco descartável do experimento multi-schema),
`BETTER_AUTH_URL`, `BETTER_AUTH_SECRET` (gerado em memória pelas suítes; no harness Next vem de `.env.local`, ignorado pelo Git).
`.env`, `.env.local` e derivados estão no `.gitignore` do PoC. Nenhuma API key, client secret, senha real, token ou cookie é persistido.

## Reprodução (PowerShell)

```powershell
# 1) PostgreSQL 18 descartável (senha/porta apenas do PoC)
docker run -d --name contifisc-gatea-pg -e POSTGRES_PASSWORD=poc -e POSTGRES_DB=gatea -p 55450:5432 postgres:18

# 2) Better Auth (suítes A,B,C,D,E,G); cada execução RESETA o banco descartável (trava: só localhost:55450)
cd poc/auth-gate-a/better-auth
npm install --save-exact --ignore-scripts        # usa package-lock.json
npx prisma generate; npx prisma db push --skip-generate
foreach ($s in 'a','b','c','d','e','g') { node --env-file=.env run-suite.mjs $s }

# 3) Experimento schema separado (PD-07): precisa de um banco `gatea_ms` com schema `contifisc_auth`
node ms-schema-test.mjs

# 4) Next (build + servidor de produção + testes HTTP)
cd ../nextjs-harness ; npm install --ignore-scripts ; npx next build ; npx next start -p 3401 ; node test-http.mjs
```

## Limpeza

`docker stop contifisc-gatea-pg` (e remover o container manualmente); apagar `poc/auth-gate-a/**/node_modules`,
`.next`, `generated` e `.env*`. Nada persiste fora desta pasta e do container.

## Suítes

| Suíte | Foco |
|---|---|
| A | identidade externa → `ContaAcesso`; 2 usuários/mesmo tenant; 1 usuário/2 tenants; interno; revogação D/E/F independente do provedor; vigência |
| B | sessão: cookies, validação server-side, expiração, refresh, logout, revogação, cookie cache, CSRF, fixation, ban, recuperação |
| C | MFA/TOTP, backup code, lockout, AAL calculado pela CONTIFISC, step-up, remoção/recuperação de MFA |
| D | OAuth/OIDC (IdP **simulado** local): subject, linking implícito × explícito, e-mail alterado, bypass de 2FA, `amr` |
| E | passkeys (WebAuthn) com autenticador **por software**: UV, replay, contador, origem, revogação |
| G | cadastro fechado, rate limit, tokens em repouso, hash, exportação, Organizations ausentes, versões |
