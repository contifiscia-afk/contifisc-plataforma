# UPG-001 — Upgrade controlado Next.js 14.2.35 → Next.js 16.3.5 (+ UPG-001A: patch 16.3.6)

**Status do documento:** DRAFT
**Resultado UPG-001:** PASS — baseline final Next.js 16.3.6 (ver seções 12 e 16)
**Resultado UPG-001A:** PASS (ver seção 16)
**Branch:** `chore/next16-upgrade`
**Referência de rollback:** `82cad5136c36b5f44cd582cbf7e77f5949f4f27c` (checkpoint pós-Gate A, já publicado no `origin`)
**Escopo:** pré-requisito do Gate B. **Não** é o Gate B. Nenhuma integração de Better Auth, nenhuma alteração de banco/RLS.
ADR-003 permanece **DRAFT / NÃO APROVADO**.

---

## 1. Baseline (antes do upgrade, HEAD `82cad51`)

| Item | Resultado |
|---|---|
| `npm ci` / install | PASS |
| `npm run lint` | PASS (aviso do `next build` antigo: "Next.js plugin not detected" — ESLint do repositório nunca usou o plugin do Next) |
| `npm run typecheck` (`tsc -b`: types, integrations, ui) | PASS |
| `npm test` | PASS — 7 arquivos / 24 testes |
| `npm run build` (Next 14.2.35) | PASS — rotas `/` e `/_not-found` estáticas |
| Workspaces | types/integrations/ui PASS; core = apenas Prisma; ai = vazio |
| `npm audit` | 10 vulnerabilidades: 2 críticas (`next`, `vitest`), 5 altas (`next`→`postcss`, `prisma`, `@prisma/config`, `deepmerge-ts`, `vite`), 3 moderadas (`@vitest/mocker`, `esbuild`, `vite-node`) |
| Smoke funcional (servidor de produção, R-01…R-09) | 9/9 PASS |

## 2. Versões antes / depois

| Pacote | Antes | Depois |
|---|---|---|
| next | ^14.2.5 (14.2.35) | **16.3.5** (exata) |
| react / react-dom | ^18.3.1 (18.3.1) | **19.3.0** (exata) |
| @types/react / @types/react-dom | ^18.3.x | **19.3.0** (exata) |
| `@contifisc/ui` peer `react` | ^18.3.1 | ^19.2.1 |
| `@contifisc/ui` devDependencies | — | `@types/react` 19.3.0 (ver 6.3) |
| `apps/web` engines | — | `node >=20.9.0` |
| postcss (transitivo) | 8.5.26 | 8.5.23 (deriva do resolvedor; sem exigência do upgrade — ver 9) |
| TypeScript | inalterado | inalterado |
| Tailwind | 3.4.19 | 3.4.19 (inalterado) |
| ESLint | 8.57.1 | 8.57.1 (inalterado) |
| Node local | 24.19.0 | 24.19.0 |

## 3. Fontes oficiais consultadas

- nextjs.org/docs/app/guides/upgrading (version-15, version-16) e codemods
- nextjs.org/support-policy (14.x EOL; 15.x Maintenance LTS; 16.x Active LTS)
- react.dev/blog (React 19 upgrade guide)
- Advisory React2Shell CVE-2025-55182 (React 19.0–19.2.0 / Next 15–16 App Router; corrigido em React 19.2.1 e Next 16.0.7; 16.3.5/19.3.0 estão acima)

## 4. Breaking changes avaliadas (14 → 15 → 16)

| Mudança | Classificação | Evidência |
|---|---|---|
| Node.js ≥ 20.9 | APLICÁVEL (atendido) | CI Node 20; local 24.19; `engines` explícito adicionado |
| TypeScript ≥ 5.1 | APLICÁVEL (atendido) | build/tsc PASS |
| React 19 obrigatório na prática (docs oficiais; peer do Next 16 aceita ^18.2 ‖ ^19, mas guias exigem React ≥ 19) | APLICÁVEL | migrado para 19.3.0; harness Gate A com React 18 não foi usado como prova |
| APIs de request assíncronas (`cookies`, `headers`, `params`, `searchParams`) | NÃO APLICÁVEL hoje (app sem uso) — relevante ao Gate B | grep: nenhum uso; página estática |
| `middleware` → `proxy` (runtime Node) | NÃO APLICÁVEL hoje (não existe middleware) — relevante ao Gate B | nenhum arquivo `middleware.*` |
| Turbopack padrão em dev/build | APLICÁVEL | build/dev PASS com `transpilePackages: ['@contifisc/ui']` |
| `next lint` removido; `next build` não roda mais lint | APLICÁVEL | lint continua via ESLint CLI já existente (`npm run lint`); não foi removido |
| `next/image`, `next/font`, `unstable_*`, PPR, `experimental.*` | NÃO APLICÁVEL | nenhuma ocorrência |
| Caching padrão (fetch / GET route handlers não cacheados por padrão) | NÃO APLICÁVEL | sem fetch nem route handlers |
| `tsconfig`/`next-env.d.ts` reescritos pelo Next | APLICÁVEL | `next-env.d.ts` reescrito (ver 6); `tsconfig.json` não alterado |
| `.next/dev` como diretório de dev | APLICÁVEL (informativo) | `.next/` continua ignorado pelo Git |
| Geração automática de `AGENTS.md`/`CLAUDE.md` em `next dev` (novo no 16.x) | VERIFICAR EMPIRICAMENTE → observado | ver 9 (risco R-4) |

## 5. Codemods

- `@next/codemod next-lint-to-eslint-cli --dry` foi executado como **avaliação**. Apesar de `--dry`, alterou a árvore (adicionou `eslint ^9` e `eslint-config-next ^14.2.5` em `apps/web/package.json` e criou `apps/web/eslint.config.mjs`), o que provocou `ERESOLVE`. Diff registrado e **revertido integralmente**; o codemod **não foi aplicado**. Motivo: o lint do repositório já é ESLint CLI 8 com `.eslintrc.json` e não usa `next lint`.
- Nenhum outro codemod foi necessário (sem APIs afetadas).

## 6. Mudanças executadas (arquivos)

| Arquivo | Alteração | Motivo | Breaking | Risco |
|---|---|---|---|---|
| `apps/web/package.json` | next/react/react-dom/@types → versões exatas 16.3.5 / 19.3.0; `engines.node >=20.9.0` | Alvo do upgrade; Node explícito | React 19, Next 16 | Baixo |
| `packages/ui/package.json` | peer `react` ^19.2.1; devDep `@types/react` 19.3.0 | Evitar duas cópias de React; `packages/ui` precisa resolver tipos do React a partir da raiz (sem isto `next build` falhava com TS7016) | React 19 | Baixo |
| `package-lock.json` | Regenerado | Consequência das versões; `npm ci` reproduz sem alteração | — | Baixo |
| `apps/web/next-env.d.ts` | Reescrito pelo Next 16 (imports de `.next/types/routes.d.ts` e `root-params.d.ts`; novo link de doc) | Arquivo gerado pelo Next e versionado | — | Baixo |
| `docs/UPG-001_NEXTJS_14_TO_16.md` | Novo | Documentação exigida | — | — |

Inalterados: `apps/web/next.config.js`, `apps/web/tsconfig.json`, código-fonte de `apps/web/app` e `packages/ui/src`, `.github/workflows`, `schema.prisma`, migrations, RLS.

### 6.1 Cadeia de resolução de React
`npm ls`: uma única cópia de `react` 19.3.0 e `react-dom` 19.3.0; `@types/react` 19.3.0 única. `npm ci` PASS e lockfile inalterado.

### 6.2 Deriva do lockfile
22 pacotes alterados (next/@next/*, react, react-dom, scheduler, styled-jsx, @swc/helpers, postcss 8.5.26→8.5.23, brace-expansion, tinyexec), 32 adicionados (`sharp` 0.35.x e `@img/*` opcionais do Next 16, `detect-libc`, `@emnapi/runtime`, @types 19 aninhados/hoisted), 11 removidos (@types 18, busboy, streamsearch, @swc/counter, loose-envify, js-tokens, `next/node_modules/postcss`, etc.). Aceito: postcss 8.5.23 satisfaz `^8.4.41` e não introduz vulnerabilidade (audit).

### 6.3 Por que `@types/react` na `packages/ui`
`packages/ui` resolve `react` pela raiz; após o upgrade os tipos ficaram aninhados em `apps/web/node_modules`. `tsc -b` incremental deu falso PASS por cache; `tsc -b --force` e `next build` (que type-checa `packages/ui/src` via `transpilePackages`) revelaram TS7016. A devDependency corrige a resolução (hoist para a raiz).

## 7. Verificações pós-upgrade

| Verificação | Resultado |
|---|---|
| Next 16 estável instalado | PASS (16.3.5) |
| React/ReactDOM combinação suportada | PASS (19.3.0, acima do patch do CVE-2025-55182) |
| Node | PASS (≥20.9; CI Node 20; local 24.19.0) |
| `npm ci` reprodutível | PASS |
| `npm run lint` (ESLint CLI) | PASS |
| `tsc -b --force` | PASS |
| `npm test` | PASS — 7 arquivos / 24 testes (igual ao baseline; nenhum teste removido) |
| `npm run build` limpo (Turbopack) | PASS, sem warnings; rotas `/`, `/_not-found` estáticas |
| `next dev` | PASS (`/` 200, `/nao-existe` 404) |
| Workspaces | types/integrations/ui PASS (`tsc -b --force`); core apenas Prisma; ai vazio |

## 8. Matriz de rotas — ANTES × DEPOIS (servidor de produção, smoke R-01…R-09)

| ID | Verificação | Antes | Depois | Resultado |
|---|---|---|---|---|
| R-01 | GET `/` 200 HTML | PASS | PASS | PASS |
| R-02 | Conteúdo da página | PASS | PASS | PASS |
| R-03 | `lang=pt-BR` e `<title>` | PASS | PASS | PASS |
| R-04 | meta description | PASS | PASS | PASS |
| R-05 | Tailwind gerado (classes de `@contifisc/ui`) | PASS | PASS | PASS |
| R-06 | Scripts de hidratação | PASS (5) | PASS (6) | PASS |
| R-07 | Rota inexistente 404 | PASS | PASS | PASS |
| R-08 | `/api/*` inexistente 404 | PASS | PASS | PASS |
| R-09 | POST `/` sem Server Action → 405 | PASS | PASS | PASS |

Diferenças observáveis (informativas, sem regressão): `cache-control` de `/` passou de `s-maxage=31536000, stale-while-revalidate` para `s-maxage=31536000`; `vary` inclui `next-router-segment-prefetch`; HTML 4785 → 5927 bytes (novos scripts/preload do Next 16). Continuam ausentes `x-content-type-options`/`x-frame-options` (já ausentes antes; ver 10).

## 9. `npm audit` antes × depois

| | Crítica | Alta | Moderada | Baixa | Total |
|---|---|---|---|---|---|
| Antes | 2 | 5 | 3 | 0 | 10 |
| Depois | 1 | 4 | 3 | 0 | 8 |

Removidas: `next` (crítica) e `postcss` (alta). Restantes, todas **pré-existentes e de ferramental**, nenhuma nova:
- `vitest` (crítica, via `@vitest/mocker`; exposição: servidor UI do Vitest — não usado; só dev/teste) + `vite`, `esbuild`, `vite-node`, `@vitest/mocker`; correção exige `vitest` 5 (major) — fora do escopo.
- `prisma` / `@prisma/config` / `deepmerge-ts` (alta; CLI/dev); correção proposta pelo npm é **downgrade** `prisma@6.12.0` — recusado.

`npm audit fix --force` **não** foi executado. Nenhuma vulnerabilidade crítica nova.

## 10. Revisão de segurança (insumo para o Gate B)

- **proxy (ex-middleware):** roda em runtime Node; o Gate B deve usar `proxy.ts`, não `middleware.ts`, e não tratar proxy como única barreira de autorização (validar sessão também no servidor/Server Actions).
- **`cookies()`/`headers()`:** assíncronos; sessão Better Auth deve ser lida com `await`.
- **Server Actions:** verificação de `Origin` vs `Host` é padrão; configurar `serverActions.allowedOrigins` apenas se houver proxy reverso; smoke R-09 confirma que POST sem ação não executa nada (405).
- **CSRF/redirects:** sem mudança; rever no Gate B.
- **Cache:** páginas dinâmicas por padrão em request-time APIs; páginas autenticadas não devem ser estáticas.
- **Headers de segurança** (`X-Content-Type-Options`, `X-Frame-Options`/CSP): ausentes antes e depois; item para o Gate B/hardening, fora deste upgrade.
- **React2Shell (CVE-2025-55182):** mitigado (React 19.3.0, Next 16.3.5); peer do `ui` restrito a ^19.2.1.

## 11. Vercel (apenas documental)

Sem `vercel.json` nem Dockerfile no repositório. Next 16 exige Node ≥ 20.9; a Vercel suporta Node 20/22/24 — o "Node.js Version" do projeto Vercel deve ser ≥ 20.x (verificar manualmente). Nenhum deploy, domínio ou variável de ambiente foi tocado. CI (`node-version: '20'`) compatível.

## 12. Riscos residuais

- R-1: `vitest`/`prisma` com vulnerabilidades pré-existentes de ferramental (ver 9); tratar em tarefa própria.
- R-2: Typecheck do `apps/web` ocorre só no `next build` (o `tsc -b` raiz não o inclui); `next-env.d.ts` referencia `.next/types/*` que só existem após build.
- R-3: Cache incremental do `tsc -b` pode mascarar erros de tipos após mudanças de dependências; usar `--force` em upgrades.
- R-4: `next dev` (16.3.x) gera `apps/web/AGENTS.md` e `apps/web/CLAUDE.md` (não versionados). Foram movidos para fora do repositório e **não** commitados; podem reaparecer em cada `next dev` (opção `agentRules: false` no `next.config` desliga — decisão deixada ao mantenedor, não aplicada para manter o escopo mínimo).
- R-5: `.github/workflows` dispara só em `push` para `main` e PRs; esta branch será validada em CI apenas via PR.
- R-6: Ambiente Windows exibe avisos `allow-scripts` do npm 11.17 (pré-existentes).

## 13. Rollback (não executado)

Referência: `82cad5136c36b5f44cd582cbf7e77f5949f4f27c`. Arquivos que seriam revertidos: `apps/web/package.json`, `packages/ui/package.json`, `package-lock.json`, `apps/web/next-env.d.ts`, `docs/UPG-001_NEXTJS_14_TO_16.md`. Depois: `npm ci`, remover `apps/web/.next`. Como o commit de upgrade não é publicado, basta abandonar a branch `chore/next16-upgrade`.

## 14. Confirmações

- Nenhuma alteração em `schema.prisma`, migrations, RLS, roles, grants, functions ou Neon DEV.
- Better Auth **não** está instalado no app principal (0 ocorrências em `package.json`/lockfile); harness do Gate A **não** copiado para `apps/`.
- Sem login, signup, middleware/proxy de auth, IdentityProvider real, tabelas de sessão, OAuth, passkeys ou MFA.
- Nenhum segredo, `.env` ou arquivo gerado indevido no diff.
- Sem deploy/publicação; commit de upgrade não publicado.

## 15. Resultado (UPG-001, antes do patch 16.3.6)

**UPG-001 = PASS.** Todos os critérios atendidos: Next 16 estável instalado, React 19.3.0 suportado, Node compatível, build/typecheck/lint/testes/workspaces PASS, sem regressão funcional observada, nenhuma vulnerabilidade crítica nova, sem alterações de DB/RLS, sem Better Auth, doc completo.

---

## 16. UPG-001A — Security Patch 16.3.6

**Motivo:** em 22/09/2026 a Vercel publicou o Next.js 16.3.6 corrigindo uma vulnerabilidade crítica de RCE em `next/og` `ImageResponse` (implementação Node.js), afetando as versões `>=16.2.0 <16.3.6`. A linha 16 precisava ser atualizada antes do Gate B.

**Data da consulta:** 2026-09-23.

**Fontes oficiais consultadas:**
- Registro npm de `next` (`registry.npmjs.org/next`): `16.3.6` publicado em `2026-09-22T16:19:00Z`, `dist-tags.latest = 16.3.6`.
- GitHub Releases, `vercel/next.js` tag `v16.3.6` (publicado em 2026-09-22T17:15:10Z): "This release contains a security fix for GHSA-vcvr-r3jv-pc5j: Remote Code Execution in next/og ImageResponse".
- GitHub Security Advisory `GHSA-vcvr-r3jv-pc5j`: RCE na implementação Node.js de `ImageResponse` (`next/og`) quando valores controlados pelo atacante entram no conteúdo/atributos/estilo de SVG durante a geração de imagem. Severidade **Crítica**, CVSS v4 **9.5**. Versões afetadas `>=16.2.0 <16.3.6`. Versão corrigida: **16.3.6**. A implementação Edge de `ImageResponse` não é afetada.

**Exposição do app principal:** nenhuma. `grep` em `apps/web` e `packages` não encontrou nenhum uso de `next/og` ou `ImageResponse`. O patch foi aplicado mesmo assim, por ser a linha 16 oficial recomendada e pré-requisito do Gate B.

### 16.1 Versão anterior / nova

| | Antes | Depois |
|---|---|---|
| `next` | 16.3.5 | **16.3.6** (exata) |

Nenhuma outra dependência (React, ReactDOM, TypeScript, Tailwind, ESLint, Prisma, Vitest, Vite) foi tocada. Next 16.3.6 não exigiu nenhuma outra alteração de código, config ou peer dependency.

### 16.2 Arquivos alterados

- `apps/web/package.json` — `next`: `16.3.5` → `16.3.6`.
- `package-lock.json` — apenas as entradas de `next`/`@next/*` (10 entradas, todas `16.3.5`→`16.3.6`; confirmado via diff que nenhuma outra linha de pacote foi tocada).
- `apps/web/next-env.d.ts` — sem diff no estado final (regenerado idêntico ao commit anterior pelo `next build`; durante a checagem de `next dev` ele foi reescrito temporariamente para apontar a `.next/dev/types/*`, e restaurado por um novo `next build`).

### 16.3 Instalação reprodutível

- `npm install` aplicou a mudança; `npm ci` posterior não alterou o lockfile (hash idêntico antes/depois do `ci`).
- `npm ls next` → uma única entrada, `next@16.3.6`.
- `npm ls react react-dom` → uma única árvore coerente, `react@19.3.0` / `react-dom@19.3.0` (deduped), igual ao baseline do UPG-001.
- `npm ls` (raiz) → sem `invalid`, `missing` ou `extraneous`.

### 16.4 Typecheck limpo

`tsc -b --force --pretty` → **PASS**, sem erros (não foi usado o cache incremental).

### 16.5 Regressão completa

| Verificação | Resultado |
|---|---|
| `npm run lint` | PASS |
| `tsc -b --force` | PASS |
| `npm test` | PASS — 7 arquivos / 24 testes (igual ao baseline) |
| `npm run build` (limpo, `.next` removido antes) | PASS — Turbopack, Next.js 16.3.6, rotas `/` e `/_not-found` estáticas |
| Workspaces (types/integrations/ui via `tsc -b --force`) | PASS |
| Smoke R-01…R-09 (servidor de produção) | **9/9 PASS**, hash/estrutura equivalentes ao UPG-001 (headers e tamanho do HTML idênticos ao pós-UPG-001) |
| `next dev` | PASS (`/` 200, título presente) |

Nenhuma divergência em relação ao baseline do UPG-001.

### 16.6 `npm audit`

| | Crítica | Alta | Moderada | Total |
|---|---|---|---|---|
| Pós-UPG-001 (antes do patch) | 1 | 4 | 3 | 8 |
| Pós-UPG-001A (16.3.6) | 1 | 4 | 3 | 8 |

O patch **não alterou** o resultado do `npm audit`: a vulnerabilidade do `next/og` corrigida pelo 16.3.6 não era listada pelo `npm audit` como advisory de dependência (é uma correção de código-fonte do próprio Next, não uma dependência desatualizada). As 8 vulnerabilidades remanescentes são as mesmas de ferramental (`vitest`/`vite`/`esbuild`/`prisma`/`deepmerge-ts`/`@prisma/config`/`@vitest/mocker`/`vite-node`), pré-existentes e não relacionadas a este patch. `npm audit fix --force` não foi executado.

### 16.7 `apps/web/AGENTS.md` / `apps/web/CLAUDE.md`

Comportamento confirmado idêntico ao registrado no UPG-001: `next dev` (16.3.6) volta a gerar `apps/web/AGENTS.md` e `apps/web/CLAUDE.md`. Os arquivos foram movidos para fora do repositório (não commitados). `agentRules` não foi alterado nesta etapa — permanece como dívida/configuração futura (risco R-4 da seção 12).

### 16.8 Banco / RLS / autenticação

- `git diff` confirma: nenhuma alteração em `schema.prisma`, migrations, políticas, roles, grants ou Neon DEV.
- Nenhuma migration executada; Neon DEV não modificado.
- Better Auth continua ausente do app principal (0 ocorrências em `package.json`/lockfile). Nenhum login, sessão, IdentityProvider, proxy/middleware de auth, OAuth, passkey, MFA ou tabela de auth foi criado.
- Gate B continua bloqueado.

### 16.9 Critérios de PASS (UPG-001A)

Todos os 14 critérios da seção 12 do prompt de execução foram atendidos: Next 16.3.6 instalado; `npm ci` reprodutível; árvore React íntegra; lint PASS; typecheck limpo PASS; 24/24 testes; build PASS; workspaces PASS; smoke 9/9 PASS; nenhuma regressão; nenhuma vulnerabilidade crítica nova; nenhuma alteração DB/RLS; Better Auth ausente; working tree só com alterações justificadas (`apps/web/package.json`, `package-lock.json`).

### 16.10 Resultado

**UPG-001A = PASS.**

## 17. Resultado geral

**UPG-001 = PASS — baseline final Next.js 16.3.6.**
