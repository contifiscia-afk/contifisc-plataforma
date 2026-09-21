# GATE A — IDENTITY / AUTH — Relatório da PoC comparativa de provedores

**ADR:** ADR-003 (DRAFT / NÃO APROVADO) · **Data:** 2026-09-21 · **Status deste relatório:** resultado do Gate A
(não aprova o ADR-003; não inicia o Gate B). PoC 100 % descartável em `poc/auth-gate-a/`.

## 0. Resultado em uma página

| Candidato | Como foi avaliado | Classificação |
|---|---|---|
| **A. Better Auth self-hosted 1.7.5** | **Empírico**: 84 testes de suíte + 17 verificações Next (16.3.5: 7 HTTP + 3 em navegador real; 14.2.35: 7 HTTP) + experimento de schema separado (6 passos) | **APROVADO COM CONDIÇÕES** |
| **B. Neon Managed Better Auth** | **Somente documental** (serviço externo ⇒ ação humana). Documentação oficial: **MFA "planejado", passkeys não listados, sem hooks de sessão, plugins fixos** | **NÃO APROVADO** (FAIL relevante no critério AAL/MFA; reavaliar quando MFA estiver disponível) |
| **C. Clerk** | **Somente documental** (serviço externo ⇒ ação humana). Documentação sugere primitivas nativas de step-up (`fva`, *reverification*) — **não comprovadas** | **NÃO APROVADO por evidência insuficiente** (não é reprovação técnica) |

**Recomendação técnica do Gate A:** seguir com **Better Auth self-hosted**, sempre atrás da porta `IdentityProvider`, **sob
as 11 condições do §28**. Clerk permanece a única alternativa gerenciada plausível; só entra em disputa se a PoC humana
(`HUMAN_ACTIONS.md` H-1) provar step-up para sessão OAuth-only e revogação ≤ 60 s. Neon Managed Better Auth **não** atende
hoje ao requisito de MFA obrigatório (PD-03).

**Gate A = PASS COM CONDIÇÕES** para o candidato A (§28). Nenhum bloqueio de arquitetura foi encontrado; achados relevantes
viram **condições de integração**, todos comprovados com testes reproduzíveis.

---

## 1. Baseline Git

`HEAD = c6b4861` (confirmado antes de qualquer trabalho); único arquivo novo então: o ADR-003 DRAFT. Sem pull, push,
commit, reset ou checkout. Estado final em §30–31.

## 2. Ambiente da PoC

- Área isolada `poc/auth-gate-a/` (fora dos workspaces npm; `.gitignore` próprio; nenhum `package.json` do repositório alterado).
- **PostgreSQL 18.6** em container descartável `contifisc-gatea-pg` (porta 55450); schema de PoC com tabelas do Better Auth (geradas pela CLI oficial) e tabelas **CONTIFISC de PoC** (`conta_acesso`, `identidade_acesso_externa`, `tenant`, `conta_acesso_tenant`, `sessao_evidencia_auth`) — **não** são o schema oficial.
- Reset automático do banco a cada suíte, com trava (só roda se `DATABASE_URL` for `localhost:55450`).
- IdP OIDC **simulado** (`oauth2-mock-server`) e autenticador WebAuthn **por software** (ES256) — ver limites em §24.
- Neon DEV oficial, RLS, `schema.prisma`, migrations e roles oficiais: **intocados**.

## 3. Versões testadas

`better-auth` 1.7.5 · `@better-auth/prisma-adapter` 1.7.5 · `@better-auth/passkey` 1.7.5 · Prisma 6.19.3 (mesma do repositório) ·
`next` 16.3.5 (com **React 18.3.1**) e 14.2.35 · `pg` 8.23.0 · Node 24.19.0 · PostgreSQL 18.6.
Mais recentes no registro npm em 2026-09-21: `better-auth` 1.7.5; `next` 16.3.5; `react` 19.3.0. **Neon Managed Better Auth está fixado em 1.4.18** (docs Neon) — 3 minor atrás.

## 4. Fontes oficiais (consultadas em 2026-09-21)

| Fonte | Usada para | Limitação/nota |
|---|---|---|
| [Next.js Support Policy](https://nextjs.org/support-policy) | 14.x = **End-of-Life**; 15.x Maintenance LTS; 16.x Active LTS | — |
| [Better Auth — Next.js](https://www.better-auth.com/docs/integrations/next) | versões/middleware/`proxy`; cookie-only não valida | sem versão mínima declarada |
| [Better Auth — Users & Accounts](https://www.better-auth.com/docs/concepts/users-accounts) | linking implícito, change email, delete user | — |
| [Better Auth — Session management](https://www.better-auth.com/docs/concepts/session-management) | cookie cache, revogação, `freshAge` | — |
| [Better Auth — Two-Factor](https://www.better-auth.com/docs/plugins/2fa) · [Passkey](https://www.better-auth.com/docs/plugins/passkey) · [Admin](https://www.better-auth.com/docs/plugins/admin) · [Organization](https://www.better-auth.com/docs/plugins/organization) · [Generic OAuth](https://www.better-auth.com/docs/plugins/generic-oauth) · [Hooks](https://www.better-auth.com/docs/concepts/hooks) · [Prisma adapter](https://www.better-auth.com/docs/adapters/prisma) | comportamentos | docs de hooks não cobrem *database hooks* |
| [Neon — Managed Better Auth](https://neon.com/docs/auth/overview) · [Plugins](https://neon.com/docs/auth/guides/plugins) · [Roadmap](https://neon.com/docs/auth/roadmap) · [Webhooks](https://neon.com/docs/auth/guides/webhooks) · [Branching](https://neon.com/docs/auth/branching-authentication) · [Next.js](https://neon.com/docs/auth/quick-start/nextjs) · [Migração](https://neon.com/docs/auth/migrate/from-legacy-auth) | capacidades/limites | plugin 2FA/passkeys **não mencionados**; roadmap: MFA "planejado" |
| [Clerk — Pricing](https://clerk.com/pricing) · [Reverification](https://clerk.com/docs/guides/secure/reverification) · [Session tokens](https://clerk.com/docs/guides/sessions/session-tokens) · [Organizations](https://clerk.com/docs/organizations/overview) · [Next.js quickstart](https://clerk.com/docs/nextjs/getting-started/quickstart) · [revokeSession](https://clerk.com/docs/reference/backend/sessions/revoke-session) | capacidades/custos | página de session tokens não trata revogação; revogação ≤ 60 s vem de trecho de busca em página oficial ("How Clerk works"), **não aberta integralmente** |
| npm registry (`npm view`) e `npm audit` | versões e vulnerabilidades | — |

Regra aplicada: **nenhum blog de terceiro** foi usado como autoridade para requisito de segurança. Itens sem afirmação oficial ficam **NÃO COMPROVADO**.

## 5. Better Auth self-hosted — resultados (empírico)

**Contagem** (suítes reproduzidas do zero, banco resetado a cada uma): A **21 PASS** · B **13 PASS + 3 RES** · C **10 PASS + 3 RES + 1 INFO + 1 NC** ·
D **7 PASS + 3 RES + 1 NC** · E **5 PASS + 4 RES + 2 NC** · G **4 PASS + 2 RES + 4 INFO** · **0 FAIL**. Next 16: 6 PASS + 1 RES (HTTP) + 3 PASS (navegador real) · Next 14: 6 PASS + 1 RES ·
Schema separado: 6/6 OK. (RES = PASS COM RESSALVA; NC = NÃO COMPROVADO.)

**Achados que viram condições (todos reproduzíveis):**

1. **O provedor não expõe AAL/método de autenticação por sessão** (tabela `session` sem essa informação) → a CONTIFISC registra evidência por hook `after` (`newSession`) e **calcula** o nível.
2. **OAuth e passkey não passam pelo desafio 2FA** (OA-08, PK-04) — como documentado; a evidência CONTIFISC mostra `aal1 [oauth]`.
3. **Linking implícito por e-mail (default) permite takeover quando o e-mail da vítima está verificado** (OA-04); com e-mail não verificado ⇒ `account_not_linked`. `disableImplicitLinking=true` bloqueia (OA-05).
4. **`userVerification: "required"` do plugin não é imposto no servidor** (PK-09): assertion sem UV foi aceita. A CONTIFISC lê o flag UV do `authenticatorData` da própria assertion (após a verificação do provedor).
5. **Cookie cache mantém sessão revogada** (SES-16) para quem copiou o cookie; `disableCookieCache` invalida.
6. **`/two-factor/disable` exige só a senha** (MFA-11): downgrade de MFA sem provar o 2º fator.
7. **Rate limit é desligado fora de produção** (OP-05); ligado, gera 429 (OP-06).
8. **`session.token` guardado em claro** (OP-01) — quem lê a tabela sequestra sessões.
9. **Sem rotação/limite de sessões** ao logar de novo (SES-06) e **sem binding de dispositivo** (SES-08).
10. **Replay do mesmo TOTP dentro da janela é aceito** (MFA-06).
11. **Step-up não é nativo** — mas é implementável com segurança sobre `auth.api.verifyTOTP` (MFA-08/09).

## 6. Neon Managed Better Auth — resultados (documental)

Nada foi executado (exige projeto/branch Neon — **ação humana H-2**). Da documentação oficial de 2026-09-21:

| Tema | O que a documentação diz |
|---|---|
| Situação/versão | GA; **Better Auth 1.4.18 fixado**; legado (Stack Auth) não aceita novos usuários |
| Plugins | "Você **não** instala/configura plugins do Better Auth diretamente"; subconjunto exposto pelo SDK: Admin, Email OTP, JWT, Magic Link, Open API, Phone Number (✅); Organization (⚠️ parcial). **Two-factor/2FA/TOTP e Passkeys: não mencionados** |
| MFA | **Roadmap: "Multi-factor authentication (MFA)" em "Coming Soon / Planned"** |
| Hooks | Somente **webhooks** (blocking: `user.before_create`, `send.otp`, `send.magic_link`; não bloqueantes: `user.created` etc.). **Sem hook de sessão/login**, logo sem o mecanismo que esta PoC usa para registrar evidência de AAL |
| Dados | Schema `neon_auth` no **nosso** banco (consultável por SQL); não declara se o app pode escrever |
| Branching | Cada branch tem ambiente de auth isolado, mas **usuários/sessões/config são CLONADOS na criação**; sem controle/anonimização documentados |
| Limites | Só AWS; sem IP Allow/Private Networking; Free 60 mil MAU; Launch/Scale 1 M MAU |
| Next.js | App Router; recomenda Next 16 (`proxy.ts`); versões anteriores `middleware.ts` |
| ORM/Prisma | **Não mencionado** |
| Revogação/exportação/hooks/SSO/custom domains | **Não declarados** |

**Conclusão:** o requisito obrigatório PD-03 (MFA para internos/admin) **não pode ser atendido hoje**; sem MFA não há AAL2 e sem hooks a CONTIFISC não consegue nem registrar evidência de nível. **FAIL relevante em AAL/MFA** (critério de reprovação do Gate A: "impossível saber nível de autenticação para operação sensível").

## 7. Clerk — resultados (documental)

Nada foi executado (exige aplicação Clerk e chaves — **ação humana H-1**). Da documentação oficial:

| Tema | O que a documentação diz | Status |
|---|---|---|
| Subject | `sub` = id do usuário (`user_…`); `sid` = sessão; `iss` (instância) | NÃO COMPROVADO (não exercitado) |
| Nível de autenticação | Claim **`fva`** (idade de verificação de fatores) + `reverification` (janelas 1–10 min; `has({reverification:'strict_mfa'|'strict'|'moderate'|'lax'})`); fatores válidos: 1º (senha/e-mail/telefone) e 2º (telefone/authenticator/backup) | Documental promissor; **NÃO COMPROVADO** |
| OAuth-only | Doc de reverification **não trata** usuários só-OAuth; "sem fator reverificável não consegue reverificar" | **NÃO COMPROVADO / risco** |
| Passkeys | Não podem ser inscritas como MFA dedicado, mas podem ser configuradas para **satisfazer** o requisito multi-fator no login | Documental |
| MFA/Passkeys — plano | **Não** no Free; **sim** no Pro (US$ 25/mês; +US$ 0,02/MRU acima de 50 mil) | Oficial |
| Organizations | Recurso **opt-in** (habilitável por comando/Dashboard); básico no Free/Pro; **roles customizados = add-on US$ 100/mês** | Oficial; será mantido **desligado** |
| Sessão/revogação | Token de sessão de **60 s** (Frontend SDK renova a cada 50 s); revogar impede novos tokens; estado de autenticação "nunca inválido por mais de 60 s" (trecho oficial via busca) ; `revokeSession` documentado, sem bulk/ban na página | Documental; latência **NÃO COMPROVADA** |
| Exportação | Export CSV pelo Dashboard **com hashes de senha** (changelog oficial); TOTP/passkeys: **não declarado** | Parcial |
| Next.js | Docs citam `proxy.ts` (16) e `middleware.ts` ("15 e anteriores"); sem versão mínima | NÃO COMPROVADO p/ Next 14 |
| Dependência SaaS | Usuários/sessões no vendor; residência de dados **não avaliada** | Risco de lock-in |

**Conclusão:** candidato **plausível**, com primitivas de step-up nativas que o Better Auth não tem — mas **nada foi provado**. Sem PoC humana, não há base para aprová-lo.

## 8. Matriz de identidade (testes empíricos — Better Auth)

| Requisito | Teste | Resultado |
|---|---|---|
| Subject estável; e-mail mutável | ID-01 | PASS — `user.id` igual após troca de e-mail; ContaAcesso igual |
| E-mail reciclado não herda acesso | ID-02 | PASS |
| Sem vínculo ⇒ sem acesso; sem auto-criação de conta | ID-03, OA-10 | PASS (`IDENTIDADE_SEM_CONTA`; contas antes = depois) |
| `subject` adulterado ⇒ fail-closed | ID-04 | PASS |
| Identidade revogada / conta suspensa com sessão do provedor válida | ID-05/06, RV-D/E | PASS |
| Usuário removido no provedor | ID-07 | PASS — sessões somem; vínculo órfão **detectado** por reconciliação; `ContaAcesso` preservada |
| Segunda identidade / múltiplos provedores | ID-08 | PASS — 2 usuários BA + 1 "clerk" simulado → mesma `ContaAcesso` |
| Unicidade `(provedor, emissor, subject)` | ID-09 | PASS |
| Role/`admin` do provedor não define papel | ID-10 | PASS |
| Cadastro público fechado; criação só administrativa | OP-07 | PASS (`EMAIL_PASSWORD_SIGN_UP_DISABLED`; `admin/create-user` ok) |

## 9. Matriz de sessão (Better Auth)

| Item | Teste | Resultado |
|---|---|---|
| Cookie `HttpOnly; SameSite=Lax; Path=/`; assinado; `__Secure-`+`Secure` com `useSecureCookies` | SES-01, SES-13 | PASS |
| Validação server-side; cookie adulterado/cru inválido | SES-02 | PASS |
| Logout revoga no servidor (cookie copiado deixa de valer) | SES-03 | PASS |
| Revogar uma / outras / todas | SES-04, SES-12 | PASS (também via adapter) |
| Fixation (cookie forjado pré-login) | SES-05 | PASS — login emite token novo |
| Login repetido não revoga sessão anterior | SES-06 | **PASS COM RESSALVA** |
| CSRF (`Origin` de terceiro / ausente) | SES-07 | PASS — 403 `INVALID_ORIGIN` / `MISSING_OR_NULL_ORIGIN` |
| Replay com outro UA/IP | SES-08 | **PASS COM RESSALVA** — sem device binding |
| Ban (admin) revoga sessões e bloqueia login | SES-09 | PASS |
| Reset de senha: token de uso único; revoga **todas** as sessões | SES-10 | PASS |
| Troca de senha com `revokeOtherSessions` | SES-11 | PASS |
| Expiração absoluta | SES-14 | PASS |
| Refresh (`updateAge`) | SES-15 | PASS |
| Cookie cache × revogação | SES-16 | **PASS COM RESSALVA** — sessão revogada segue "válida" no cache; bypass invalida |
| Next 16/14: RSC, Route Handler, `proxy`/`middleware`, cookie forjado | NX-01…07 | PASS; NX-05 **RES**: o proxy só checa existência do cookie |
| Server Action (login com `nextCookies`, ação autenticada e pós-logout) em navegador real | NX-08…10 | PASS |

## 10. Matriz MFA / AAL

`AAL` abaixo = nível **atestado pela CONTIFISC** (o provedor não o fornece). Política adotada na PoC: senha=aal1; senha+TOTP/backup=aal2; OAuth=aal1; passkey=aal2 **somente com UV lido do `authenticatorData`**, senão aal1; step-up eleva por janela finita.

| Método de login | MFA possível? | MFA obrigatório? | AAL observável? | Step-up possível? | Revogável? | Evidência |
|---|---|---|---|---|---|---|
| Senha | Sim (TOTP) | **Não impõe** (usuário sem 2FA loga aal1; a CONTIFISC nega ops aal2) | Sim, via hook CONTIFISC (`[pwd]` aal1) | Sim (adapter `stepUp`) | Sim | MFA-13, MFA-08 |
| Senha + TOTP | — | — | Sim (`[pwd,totp]` aal2) | — | Sim | MFA-04 |
| Senha + backup code | — | — | Sim (`[pwd,backup_code]` aal2), uso único | — | Sim | MFA-07 |
| OAuth | Não passa pelo desafio 2FA | Não | Sim (`[oauth]` aal1); **`amr` do IdP não chega à sessão** | **Sim** (TOTP sobre sessão existente) | Sim | OA-08, OA-09 |
| OAuth + step-up | — | — | Sim (aal2 na janela; volta a aal1 ao expirar) | — | Sim | OA-08, MFA-08 |
| Passkey (UV=true) | — | — | Sim (`[passkey]` aal2, UV lido da assertion) | — | Sim (credencial e sessão) | PK-02 |
| Passkey (UV=false) | — | — | Sim (aal1) — o provedor **aceita** | Sim | Sim | PK-03, PK-09 |
| Recovery (reset de senha) | 2FA continua exigido no login seguinte | — | reset revoga todas as sessões | — | Sim | SES-10 |
| Perda de fator (sem backup) | **Sem fluxo nativo** | — | pós-reset admin ⇒ aal1 | — | — | MFA-12 (RES) |

Observações: (i) o **downgrade de MFA** exige só senha (MFA-11) — a CONTIFISC deve exigir step-up; (ii) TOTP: erros sucessivos disparam bloqueio do desafio (MFA-05: 5 falhas ⇒ novas tentativas rejeitadas), mas o **replay do mesmo código** na janela é aceito (MFA-06); (iii) segredo TOTP e backup codes estão **cifrados** com o secret do provedor (MFA-02); (iv) OTP por e-mail/SMS **NÃO COMPROVADO** (MFA-15).

**Como a CONTIFISC prova AAL sem AAL do provedor:** hook `after` grava `sessao_evidencia_auth(session_id, metodos, aal)` só quando o provedor cria a sessão com sucesso (`newSession`); step-up grava `aal_elevado_ate`; o adapter devolve `authenticationLevel`, `factors`, `lastFactorVerifiedAt`; a política `satisfiesAuthenticationLevel` decide. **Se o hook falhar ou faltar, o adapter devolve aal1 (fail-closed).**

## 11. Passkeys

Registro exige sessão (PK-01) e persiste chave pública/contador; login sem senha (PK-02); replay, clone (contador não monotônico) e origem falsa **rejeitados** (PK-05/06/08); revogação da credencial impede novo login, mas **sessões já criadas continuam** (PK-07 RES); **UV não é imposto no servidor** mesmo com `required` (PK-09); passkey de usuário com TOTP não pede TOTP (PK-04 RES); recuperação de conta só-passkey e autenticador **real**: NÃO COMPROVADO (PK-10/11).

## 12. OAuth

IdP OIDC simulado: `accountId` = `sub` estável; `user.id` do provedor é o subject CONTIFISC (OA-01/02); mudança de e-mail no IdP com mesmo `sub` ⇒ mesma conta (OA-03); linking implícito — takeover com e-mail da vítima **verificado** (OA-04 RES) e bloqueio com `disableImplicitLinking` (OA-05); linking explícito ok (OA-06); e-mail diferente no link é rejeitado por padrão (OA-07); OAuth de usuário com 2FA cria sessão direto (OA-08 RES); `amr`/`acr` do IdP não chegam à sessão (OA-09 RES); Google real **NÃO COMPROVADO** (OA-11).

## 13. Revogação (A–F do prompt)

| Cenário | Resultado |
|---|---|
| A logout | PASS (SES-03) |
| B revogar sessão atual | PASS (SES-04/12) |
| C revogar todas | PASS (SES-04/12) |
| D `ContaAcesso` desativada | PASS (RV-D) — nega mesmo com sessão do provedor válida |
| E identidade externa revogada | PASS (RV-E) |
| F acesso ao Tenant removido | PASS (RV-F) |
| + tenant suspenso | PASS (RV-G) |

D, E e F **independem do provedor**: dependem só das tabelas CONTIFISC, avaliadas a cada requisição.

## 14. Dois usuários no mesmo Tenant (TN-01/TN-02)

A (sócio) e B (financeiro) autenticam; resolvem `ContaAcesso` **distintas**; ambos apontam para o **mesmo** Tenant; papéis distintos (`cliente.socio_admin` × `financeiro.operador`) vêm **exclusivamente** de `conta_acesso_tenant`; `user.role='admin'` do provedor não alterou nada (ID-10); **0** tabelas de organização. Capabilities futuras podem divergir por conta.

## 15. Um usuário em dois Tenants (TN-03)

Conta C com Tenants X e Y: **1 sessão** antes e depois; troca X↔Y sem reautenticar; Z ⇒ `TENANT_NAO_AUTORIZADO`; nenhum `organization id` participou.

## 16. Usuário interno (IN-01/IN-02)

Conta D (`categoria=INTERNO`) autentica **como qualquer outra** (`[pwd]` aal1), mas: 0 tenants; 4/4 tenants negados. Acesso só por **concessão administrativa explícita com vigência**: concedida ⇒ permitido; vencida ⇒ negado **sem varredor** (a linha permanece na tabela).

## 17. Organizations / Teams

O Better Auth funciona **sem** o plugin `organization` (nenhum teste exigiu), sem tabelas/campos de organização, sessão sem `activeOrganizationId` (OP-04, TN-01). Neon: organização "parcialmente suportada" e "pré-configurada" (tentação de multi-tenant) — **não testada**. Clerk: opt-in, será mantida desligada. **Regra mantida:** nenhum id de organização do provedor entra em `withSecurityContext`, PDP, RLS ou `ContaAcessoTenant`.

## 18. `IdentityProvider` proposto

Arquivo: `poc/auth-gate-a/contracts/identity-provider.ts` (typecheck `tsc --strict` OK; nomes não congelados).

- `AuthenticatedIdentity { provider, issuer, subject, sessionId, authenticatedAt, sessionExpiresAt?, authenticationLevel(1|2|3), factors[], lastFactorVerifiedAt?, evidence }`.
- `IdentityProvider { resolve(request, {bypassSessionCache}), revokeSession(id), revokeAllSessions(subject), stepUp?() }`.
- `satisfiesAuthenticationLevel(identity, {minLevel, maxFactorAgeSeconds}, now)` — **independente do fornecedor**.
- Adapter Better Auth implementado e exercitado (`lib/idp-betterauth.mjs`); um segundo adapter (`clerk`) foi **simulado só na camada de identidade** (ID-08) — o adapter real de Clerk **não foi executado**.

**Saída que o Gate A entrega ao Gate B:** `ResolvedPrincipal { contaAcessoId (ContaAcesso ATIVA via IdentidadeAcessoExterna ATIVA), identity: AuthenticatedIdentity }` — sem tenant, sem papel, sem organização. O Gate B estabelece `withSecurityContext` (conta → sonda de `tenant` → tenant) a partir dele.

## 19. Vigência (VG-01/VG-02/IN-02)

Predicado `inicio_vigencia <= now() AND (fim_vigencia IS NULL OR now() < fim_vigencia)` avaliado **no momento da decisão** com o relógio do **banco**.
Fronteiras verificadas: −1 ms do início = negado; **exatamente no início = permitido**; meio = permitido; fim −1 ms = permitido; **exatamente no fim = negado**; após o fim = negado; sem fim = permitido após o início e negado antes.
Futura=negado, ativa=permitido, vencida=negado; a função de decisão **não recebe instante do cliente**. Concessão vencida permanece na tabela e é negada **sem nenhum job** (IN-02). *Jobs ficam só para housekeeping/alertas.*

## 20. Lock-in e migração

| Item | Better Auth self-hosted | Neon Managed | Clerk |
|---|---|---|---|
| Onde estão os dados | **Nosso banco** (tabelas próprias; schema `contifisc_auth` comprovado) | Nosso Neon (`neon_auth`); escrita não declarada | Vendor |
| Usuários/sessões/contas OAuth | SELECT direto (OP-03) | SQL de leitura (declarado) | CSV do Dashboard; API |
| Hash de senha | scrypt customizado (`salt:key` hex) — importador compatível **ou** reset (OP-02) | não declarado | CSV inclui hashes (changelog oficial) |
| Segredos TOTP | cifrados com `BETTER_AUTH_SECRET` (exportáveis com o secret) | não aplicável (sem MFA) | não declarado |
| Passkeys | `credentialID` + chave pública (portáveis se mesmo RP ID/origem) | não declarado | não declarado |
| Sessões | descartáveis (reautenticar) | descartáveis | descartáveis |
| Troca de provedor | **Viável** — `IdentidadeAcessoExterna` desacopla `ContaAcesso`; novo vínculo por processo verificado (e-mail não é ponte) | idem (se eleito) | idem |

## 21. Custo (apenas valores oficiais atuais)

Better Auth: licença MIT (custo = operação: hospedagem do PG, patching, backups, monitoramento). Neon Managed: Free 60 mil MAU; Launch/Scale 1 M MAU; só AWS. Clerk: Free 50 mil MRU (sem MFA/passkeys); Pro US$ 25/mês (US$ 20 anual) + US$ 0,02/MRU acima de 50 mil; B2B Authentication Enhanced US$ 100/mês (custom roles); SSO/SAML US$ 75/mês por conexão adicional; Administration US$ 100/mês. **Preço não foi critério de escolha.**

## 22. Scorecard técnico

Legenda: **PASS · PASS COM RESSALVA · NÃO COMPROVADO · FAIL**. *(Sem notas numéricas; sem soma.)*

| Critério | A. Better Auth self-hosted | B. Neon Managed BA | C. Clerk |
|---|---|---|---|
| Segurança | **PASS COM RESSALVA** — cookies/CSRF/fixation/ban/reset ok; ressalvas §5 (1–10) | NÃO COMPROVADO | NÃO COMPROVADO |
| AAL / MFA | **PASS COM RESSALVA** — AAL derivável via hooks; step-up implementável; UV lido; OAuth=aal1 | **FAIL** — MFA planejado; passkeys/hooks ausentes ⇒ AAL indemonstrável | NÃO COMPROVADO (documental promissor: `fva`, reverification) |
| Integração arquitetural | **PASS** — `IdentityProvider` + adapter; 0 dependência de org/papel/e-mail | NÃO COMPROVADO | NÃO COMPROVADO |
| Independência de Tenant | **PASS** | NÃO COMPROVADO (org "pré-configurada") | NÃO COMPROVADO (org opt-in) |
| Sessões / revogação | **PASS COM RESSALVA** — cookie cache; sem device binding; sem limite de sessões | NÃO COMPROVADO | NÃO COMPROVADO (doc: ≤ 60 s) |
| Next.js | **PASS** — 16.3.5 (+React 18.3.1) e 14.2.35; RSC/Route Handler/Server Action/proxy | PASS COM RESSALVA documental (recomenda 16) — NÃO COMPROVADO | NÃO COMPROVADO |
| Prisma / Neon | **PASS COM RESSALVA** — Prisma 6.19.3 + multiSchema ok em PG18; **Neon real (pooled/direct): NÃO COMPROVADO** | NÃO COMPROVADO (Prisma não mencionado) | n/a |
| Extensibilidade | **PASS** — hooks, plugins, acesso ao banco | **FAIL** (para o requisito) — sem hooks de sessão; plugins fixos | NÃO COMPROVADO |
| Operação | **PASS COM RESSALVA** — nós operamos (patching, rate limit, backups, monitoramento, schema) | PASS documental (gerenciado); limites: só AWS, sem IP Allow | PASS documental (vendor) |
| Lock-in | **PASS** — dados no nosso banco | NÃO COMPROVADO / risco alto (Neon; sem export declarado) | NÃO COMPROVADO / risco alto (SaaS) |
| Migração futura | **PASS COM RESSALVA** — vínculo desacoplado; hashes/TOTP exigem importador ou reenrolamento | NÃO COMPROVADO | NÃO COMPROVADO |
| Custo | PASS (MIT; custo operacional) | PASS (limites oficiais) | PASS (valores oficiais; MFA/passkeys só no Pro) |

## 23. Riscos

1. **Operação própria** do provedor de auth (patches, rate limit, backups, chaves) — mitigar com CI, monitoramento e runbook.
2. **`session.token` em claro** — tabela em schema/role dedicado; backup criptografado.
3. **AAL depende de hook CONTIFISC** — falha do hook ⇒ aal1 (fail-closed); cobrir com teste de contrato a cada upgrade do provedor.
4. **Superfície de API muda entre versões** (na 1.7.5 o fluxo do OAuth genérico é `/sign-in/social` + `/link-social`, diferente do que a documentação de plugin sugere; descoberto empiricamente) — pin de versão + suíte de regressão.
5. **Neon real não testado** com Better Auth (pooled/direct, transações do adapter) — Gate B.
6. **Autenticador real e Google real não testados** (só simulados).
7. **Servidor de aplicação comprometido** continua podendo afirmar qualquer conta (risco arquitetural, fora do provedor).
8. **Vulnerabilidades de cadeia de dev** do Prisma 6.19.3 (`deepmerge-ts`, dev-time) — mesmas do repositório.
9. **Next 14.2.35 (EOL)**: `npm audit` acusa `next` **crítico** e `postcss` alto tanto no repositório principal quanto no harness Next 14; o harness **Next 16.3.5 = 0 vulnerabilidades**.

## 24. Testes NÃO executados e motivo

| Teste | Motivo |
|---|---|
| PoC Neon Managed Better Auth | Exige projeto/branch Neon novo — **ação humana** |
| PoC Clerk | Exige aplicação Clerk e chaves — **ação humana**; keyless também cria app externo |
| Google OAuth real | Exige credencial no Google Cloud — **ação humana** (OIDC provado com IdP simulado) |
| Passkey com autenticador real; recuperação de conta só-passkey | Exige hardware/navegador — **ação humana** |
| OTP por e-mail/SMS como 2º fator | Sem canal de envio na PoC |
| Better Auth no **Neon DEV real** (pooled/direct) | Fora do Gate A (Gate B; não alterar Neon oficial) |
| Ataques de sessão em navegador (XSS/roubo real) | Fora do escopo; coberto por análise de cookies/flags |
| Adapter real de Clerk/Neon para `IdentityProvider` | Sem serviço |

## 25. Ações humanas necessárias

Ver `poc/auth-gate-a/HUMAN_ACTIONS.md` (H-1 Clerk, H-2 Neon Managed BA, H-3 Google, H-4 passkey real, H-5 Neon oficial no Gate B). **Nenhuma é necessária** para a recomendação atual; H-1 só se Bruno quiser manter o Clerk como alternativa comparável.

## 26. Classificação dos candidatos

| Candidato | Classificação | Justificativa |
|---|---|---|
| Better Auth self-hosted | **APROVADO COM CONDIÇÕES** | Todos os critérios PASS/PASS COM RESSALVA; 0 FAIL; ressalvas viram as 11 condições do §28 |
| Neon Managed Better Auth | **NÃO APROVADO** | FAIL em AAL/MFA (MFA planejado; sem hooks; passkeys não listados); reavaliar após MFA/hooks GA |
| Clerk | **NÃO APROVADO (evidência insuficiente)** | Nenhum teste executado; documentação promissora; PoC humana pendente |

## 27. Recomendação técnica do Gate A

**Better Auth self-hosted, atrás de `IdentityProvider`,** porque é o único candidato **comprovado** nos requisitos que mais importam: identidade por `subject` (não e-mail), independência total de Tenant/Organization/papel, revogação independente do provedor, e **AAL demonstrável** (via hooks) com step-up implementável. Os candidatos gerenciados não são equivalentes hoje: Neon falha em MFA; Clerk é uma incógnita. **Se dois candidatos ficassem equivalentes**, o teste que decidiria seria: *step-up/reverification em sessão OAuth-only e latência real de revogação no Clerk* (H-1).

## 28. ENCERRAMENTO FORMAL — decisão do Gate A e condições obrigatórias

### 28.1 Decisão

```
GATE A = PASS COM CONDIÇÕES
```

- **Provedor selecionado para continuidade:** **Better Auth self-hosted**, **obrigatoriamente atrás da abstração CONTIFISC `IdentityProvider`**.
- **Clerk:** permanece **alternativa futura** (só volta à disputa se a PoC humana H-1 provar step-up em sessão OAuth-only e revogação ≤ 60 s).
- **Neon Managed Better Auth:** **não será adotado nesta etapa** (FAIL em AAL/MFA; reavaliar quando MFA/hooks estiverem disponíveis).
- **ADR-003:** permanece **DRAFT / NÃO APROVADO**. Este encerramento não o aprova.

### 28.2 Arquitetura de identidade

```
Better Auth
   → IdentityProvider (CONTIFISC)
      → IdentidadeAcessoExterna (provedor + emissor + subject_externo)
         → ContaAcesso
```

O provedor de autenticação **NÃO é autoridade** sobre: **Tenant · ContaAcessoTenant · entitlement · papel · permissão · Unidade Econômica · RLS**.
Ele responde apenas "quem é esta identidade?"; a CONTIFISC responde "qual `ContaAcesso`?" e, depois, "quais Tenants, capabilities, permissões e UEs?".

### 28.3 Condições obrigatórias C1–C11 (requisitos formais do Gate A)

| # | Requisito formal | Evidência do Gate A que o motiva | Situação |
|---|---|---|---|
| **C1** | `disableImplicitLinking=true`. | OA-04 (takeover com e-mail da vítima verificado), OA-05 (bloqueado) | Requisito de configuração |
| **C2** | Linking adicional **somente explícito, autenticado, com step-up e auditoria**. | OA-06/OA-07; MFA-08 (step-up) ; auditoria = DP-12 do ADR (não exercitada no Gate A) | Requisito de integração |
| **C3** | **Cookie cache não é autoridade** para decisões de segurança; a sessão é validada **server-side** nas operações protegidas. | SES-16 (sessão revogada "válida" no cache), NX-05 (proxy só checa existência do cookie) | Requisito de integração |
| **C4** | **AAL é calculado/normalizado pela CONTIFISC.** OAuth **não** recebe automaticamente aal2. Passkey **só** recebe aal2 mediante evidência adequada de *user verification*. | OA-08/OA-09 (OAuth=aal1; `amr` não chega à sessão), PK-02/03/09 (UV lido da assertion; servidor não o impõe), MFA-04 | Requisito de integração |
| **C5** | **Operações sensíveis exigem step-up.** | MFA-08/09 (step-up implementável), MFA-11 (`/two-factor/disable` só com senha) | Requisito de integração |
| **C6** | **Rate limiting explicitamente habilitado e testado.** | OP-05 (desligado fora de produção), OP-06 (429 quando ligado) | Requisito de configuração + teste |
| **C7** | **Cadastro público desabilitado**; criação de usuário por convite ou fluxo administrativo controlado. | OP-07, ID-03 | Requisito de configuração |
| **C8** | Dados do Better Auth **isolados em schema próprio** (conceitualmente `contifisc_auth`), com privilégios próprios. | Experimento multiSchema (6/6 OK, Prisma 6.19.3), OP-01 (`session.token` em claro) | Requisito de integração (ADR-004) |
| **C9** | Política de sessões contempla **expiração, revogação, suspensão e eventos relevantes**. | SES-04/06/08/09/10/11/14/15, RV-D/E/F/G | Requisito de integração |
| **C10** | **Versões de autenticação fixadas**; a **suíte do Gate A integra o CI** quando a autenticação for incorporada. | Mudança de superfície de API entre versões (OAuth genérico em `/sign-in/social`); `npm audit` | Requisito de processo |
| **C11** | **Antes da integração definitiva:** (a) upgrade Next.js; (b) validação no Neon real; (c) pooled/direct; (d) Google/OAuth real; (e) autenticador/passkey real. | §24 e `HUMAN_ACTIONS.md` (H-3, H-4, H-5) | **Pendente — pré-integração** |

### 28.4 Decisões arquiteturais fechadas neste encerramento

1. **Vigência** — a autorização temporal é determinada **no momento da decisão**:

   ```
   inicio_vigencia <= agora
   AND ( fim_vigencia IS NULL OR agora < fim_vigencia )
   ```

   O **relógio do browser não é autoridade** (o relógio é o do servidor/banco). **Job/varredor não é o mecanismo primário de revogação**
   (só housekeeping, alertas, materializações). Comprovado: VG-01 (fronteiras exatas), VG-02, IN-02 (concessão vencida permanece na tabela e é negada sem nenhum job).
2. **Control plane** — **`BYPASSRLS` NÃO está aprovado como premissa.** O desenho futuro deve preferir funções específicas, privilégios mínimos, roles especializadas, autorização explícita e auditoria.
   Qualquer necessidade de `BYPASSRLS` deverá ser **demonstrada empiricamente e aprovada separadamente**. Operações administrativas futuras que exigirão privilégio especial (sem grants genéricos): criar Tenant + 1ª
   concessão; conceder papéis internos; gravar entitlements; suspender/reativar conta ou tenant; criar/revogar `IdentidadeAcessoExterna`; break-glass; fusão de contas.
3. **Next.js** — o **Next 14.2.35 apresentou compatibilidade funcional na PoC** (NX-01…07), **mas não será utilizado para a integração definitiva da autenticação** (EOL; `npm audit` acusa `next` crítico).
   **Antes do Gate B** haverá etapa própria: **UPGRADE CONTROLADO NEXT.JS 14 → NEXT.JS 16, com regressão completa.** **Esse upgrade NÃO foi feito** neste checkpoint. (No harness, o Next 16.3.5 aceitou React 18.3.1 e teve 0 vulnerabilidades.)
4. **Saída formal do Gate A para o Gate B**:

   ```
   AuthenticatedIdentity
           ↓
   IdentityProvider
           ↓
   ResolvedPrincipal { contaAcessoId, identity }
   ```

   **Tenant NÃO está embutido no principal autenticado**: será selecionado e validado posteriormente pela CONTIFISC (Gate B: `withSecurityContext`). O **Gate B NÃO foi iniciado**.
## 29. Arquivos criados

`docs/poc/GATE_A_IDENTITY_AUTH_REPORT.md` (este) · `poc/auth-gate-a/` (README, HUMAN_ACTIONS, `.gitignore`, `contracts/identity-provider.ts`, `better-auth/` [lib, suítes A–G, `ms-schema-test.mjs`, Prisma schema, package(.lock)], `nextjs-harness/`, `nextjs-harness-14/`, `results/*.json`) ·
adendo curto no ADR-003 (§32). Nenhum arquivo rastreado foi alterado.

## 30. `git diff --stat` (estado ANTES do commit de checkpoint)

```
(vazio) — nenhum arquivo rastreado foi alterado (package.json, package-lock.json, apps/, packages/ intactos).
```

## 31. `git status --short`

```
?? docs/ADR-003_CONTIFISC_Autenticacao_Autorizacao_Entitlements_Runtime_DRAFT.md
?? docs/poc/
?? poc/auth-gate-a/
```

`HEAD = c6b4861` inalterado. O Git enxerga **58** arquivos novos (56 fora `package-lock.json`, varridos por padrões de credencial: **nenhum match**; `results/*.json` sem tokens/cookies).
`.env`, `.env.local`, `node_modules`, `.next`, `generated`, `*.log` e `*.pid` estão **ignorados** (verificado por `git check-ignore`). Container do PoC parado; portas 3400/3401/3402/3500/55450 livres.
Não houve commit nem push.