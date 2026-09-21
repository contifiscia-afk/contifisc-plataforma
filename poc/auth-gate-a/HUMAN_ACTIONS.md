# AÇÃO HUMANA NECESSÁRIA — Gate A (subtestes que dependem de serviços externos)

Estes subtestes **não foram executados** porque exigem criar contas/projetos/credenciais em serviços externos,
habilitar serviço ou usar hardware — ações que o processo proíbe automatizar. Nenhum valor secreto deve ser colado
em chat, commit, log ou arquivo versionado; use variáveis de ambiente locais.

## H-1 — Clerk (PoC da alternativa C)
**Por que humano:** criar uma *application* Clerk exige conta Clerk e gera chaves (publishable/secret). O "keyless mode"
também cria uma aplicação temporária nos servidores da Clerk — igualmente proibido sem sua decisão.

**Passos:**
1. Criar conta em clerk.com e uma aplicação **de desenvolvimento** (plano Free; ver limitações abaixo).
2. No Dashboard: manter **Organizations desativadas**; ativar e-mail+senha, **Authenticator app (TOTP)** e **Backup codes**;
   **Passkeys** e **MFA** só existem a partir do plano **Pro** (página oficial de preços em 2026-09-21) — decidir se vale
   contratar apenas para o teste.
3. Exportar para o ambiente local (nunca versionar): `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`.
4. Avisar; o harness `nextjs-harness/` será estendido com um adapter `IdentityProvider` para Clerk e executar:
   `fva` + `has({reverification})` (nível `strict_mfa`) em sessão senha+TOTP, OAuth-only e passkey; revogação
   (`revokeSession`) com medição da latência (esperado ≤ 60 s); webhooks de usuário; exportação CSV (com hashes);
   subject/`iss`; confirmar que Organizations desligadas não afetam nada.

**Teste que decide:** *reverification/step-up em sessão OAuth-only* (a doc oficial não trata) e *latência real de revogação*.

## H-2 — Neon Managed Better Auth ("Neon Auth")
**Por que humano:** habilitar Neon Auth exige o Console/API do Neon em um **projeto/branch descartável**. Criar projeto
Neon ou ativar o serviço no projeto oficial não é feito automaticamente.

**Passos:**
1. No Console Neon, criar um **projeto novo e descartável** (região AWS) — não usar o projeto `contifisc-dev` oficial.
2. `Auth` → habilitar Managed Better Auth; copiar `NEON_AUTH_BASE_URL` e `NEON_AUTH_COOKIE_SECRET` para ambiente local.
3. Avisar; será executado: presença/ausência de 2FA e passkeys na UI/SDK; `Plugins (beta)` disponíveis; webhooks
   (`user.before_create`) e se existe algo equivalente a *hook de sessão*; criação de branch e verificação de que usuários
   e sessões são **clonados**; leitura do schema `neon_auth` via SQL e possibilidade de escrita; revogação de sessão;
   exportação; comportamento com Prisma.

**Teste que decide:** *existência de MFA/TOTP e de qualquer forma de provar nível de autenticação por sessão*. Pela
documentação oficial atual, MFA está "planejado" e passkeys não constam → provável reprovação enquanto isso não mudar.

## H-3 — Google OAuth real
Criar credencial OAuth (client id/secret) no Google Cloud Console (tela de consentimento em modo teste), redirect
`http://localhost:3400/api/auth/callback/google`. Exercitar: `sub` estável, mudança de e-mail, linking, MFA/AAL (`amr`).
Nesta PoC o fluxo OIDC foi provado com **IdP simulado**; não se espera diferença de protocolo, mas não foi comprovado contra o Google.

## H-4 — Passkey com autenticador real
Rodar o harness `nextjs-harness/` em `localhost` num navegador com Touch ID / Windows Hello / YubiKey e registrar+autenticar
uma passkey (UV real). Nesta PoC o protocolo foi exercitado com autenticador por software (ES256, attestation `none`).

## H-5 — Neon DEV oficial (Gate B, **fora deste gate**)
Better Auth com role dedicado `contifisc_auth` e schema `contifisc_auth` no Neon real (pooled/direct) — só no Gate B e com autorização própria.
