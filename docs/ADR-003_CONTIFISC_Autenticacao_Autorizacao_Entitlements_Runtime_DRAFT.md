# ADR-003 — Autenticação, Autorização, Entitlements e Runtime de Acesso

**Versão:** 0.2 (DRAFT) — v0.1 (rodada 1, discovery) + **§31 Rodada 2 (fechamento pré-PoC)**; onde houver
divergência entre seções, **prevalece o §31** (as seções afetadas trazem nota de remissão)
**Status:** **DRAFT — NÃO APROVADO.** Proposta de arquitetura para revisão humana. Nada aqui é decisão
vigente até aprovação formal explícita. Os identificadores `DP-xx` (decisão proposta) e `PD-xx`
(decisão pendente) só viram `ADR-D034+` se e quando aprovados.
**Tipo:** Architecture Decision Record — aditivo. **Não reabre** `ADR-001` V1.1, `ADR-002` V1.0,
`SEC-001` V1.0, `RLS-001`, `SECURITY_CONTEXT_CONTRACT.md` nem a RLS validada no Neon DEV.
**Data:** 2026-09-21
**Baseline Git do discovery:** `HEAD = c6b4861`, working tree limpo (antes da criação deste arquivo).
**Escopo desta rodada:** discovery + desenho. **Não** instala autenticação, não cria login/frontend, não
altera `schema.prisma`, não cria migration, não cria `contifisc_app`, não cria tabelas/seed/dados, não
altera RLS, não altera COT/MCD/DST/CDC, não inicia RGT/EVT/INT/Skills.
**Baseline obrigatória:** `SEC-001` V1.0, `ADR-001` V1.1, `ADR-002` V1.0, `RLS-001` V1.0,
`SECURITY_CONTEXT_CONTRACT.md`, `RLS_MATRIX.md`, `COT-001` V1.2, `MCD-001` V1.4, `DST-001` V1.3,
`CDC-001` V1.4, `RLS_NEON_DEPLOYMENT_REPORT.md` (ADENDO 6).

---

## 0. Sumário executivo

> **Atualização da Rodada 2 (§31).** Correções ao texto da rodada 1: (i) G-01/G-02/G-03/G-07 **não** são vulnerabilidades — foram
> reclassificados (§31.2); (ii) a auditoria será gravada por **função `SECURITY DEFINER` dedicada**, mantendo a tabela selada (§31.3);
> (iii) a RLS **não** precisa mudar (§31.4); (iv) UE na V1 = aplicação estrutural (§31.5); (v) **três planos** com roles e GRANTs separados (§31.6);
> (vi) `IdentidadeAcessoExterna` fechada (§31.7); (vii) Organizations do provedor **não** são usadas (§31.8); (viii) provedores reclassificados
> com docs oficiais — **Better Auth self-hosted e Clerk = finalistas**, Neon = viável/condicionado, Auth.js = eliminada (§31.9); **Next 14 é EOL** (§31.9.3);
> (ix) unidade de entitlement = **capability**, produto = fonte de grants (§31.10–31.11); (x) **RBAC híbrido** (§31.12); (xi) 8 PoCs → **4 gates** (§31.19).
> Os textos abaixo são o registro da rodada 1; em caso de conflito vale o §31.

A CONTIFISC já tem, **validado no Neon DEV**, o *piso* de isolamento: RLS `ENABLE`+`FORCE` em 25/25
tabelas, contexto transacional (`app.current_conta_acesso_id`, `app.current_tenant_id`) via `SET LOCAL`,
fail-closed, mediador `SECURITY DEFINER`. **Não existe nenhuma das camadas acima do banco**: não há
autenticação, sessão, papéis, permissões, entitlements, role de runtime, camada de acesso a dados nem
auditoria gravável. O `apps/web` é uma página estática (Next 14.2.35, sem middleware, sem API routes,
sem Server Actions).

Este ADR propõe uma arquitetura de acesso em **seis dimensões independentes** — autenticação, tenant,
entitlement, papel/permissão, unidade econômica, RLS — avaliadas por uma **cadeia determinística de nove
portões (G1–G9)**, com um único ponto de decisão (PDP) na camada de serviço, contexto transacional
estabelecido por um único helper (`withSecurityContext`) que **prova a concessão de tenant no próprio
banco** reutilizando a RLS já existente (sem alterá-la), e uma separação rígida entre
**autenticação ≠ autorização ≠ entitlement comercial ≠ isolamento de dados**.

Principais propostas (todas sujeitas a aprovação):

1. **Identidade externa desacoplada**: `IdentidadeExterna(provedor, external_subject) → ContaAcesso`; e-mail nunca é chave (§8).
2. **Provedor**: candidato preferencial a validar em PoC = **Better Auth self-hosted** atrás de uma porta
   `IdentityProvider` própria; **Auth.js não recomendado para projeto novo** (modo somente-segurança desde
   set/2025); Neon Auth e Clerk como alternativas com trade-offs explícitos (§9.4). **Sem instalar nada.**
3. **Entitlement ≠ dado**: entitlement controla *funcionalidade*, nunca a existência/acessibilidade do
   dado canônico; catálogo global (Módulo/Feature) + concessões por Tenant com vigência/estado/origem +
   ledger append-only (§11–§13).
4. **Equiparação Hospitalar = combinação (D)**: produto comercial **e** módulo funcional próprio
   (`equiparacao.*`) apoiado por motores compartilhados — não é "feature de Tributário PJ" nem módulo
   isolado (§11.3).
5. **RBAC com camada ABAC** no PDP; catálogo de permissões versionado em código na V1 (sem novas
   tabelas), materialização em banco só quando houver necessidade comprovada; exige reconciliar
   `CDC-SEC-003` V1.4 (§14).
6. **Usuários internos sem superusuário implícito**: concessões explícitas por Tenant, com vigência,
   recertificação e elevação *break-glass* justificada e auditada (§16).
7. **Runtime**: `contifisc_app` (NOSUPERUSER, NOBYPASSRLS, não-owner), endpoint pooled; roles separados
   para migração, provisionamento, plano de controle e armazenamento de autenticação (§17).
8. **Entitlement e permissão ficam na camada de aplicação**; o banco recebe apenas *least privilege por
   GRANT* sobre estruturas de acesso/entitlement. A RLS **não** vira monólito de autorização comercial
   (§19.3).
9. **Achados que exigem decisão** (§26): auditoria não é gravável pelo runtime; a RLS só *prova* a
   concessão na tabela `tenant`; a restrição por UE não é aplicada pela RLS; `Tenant`/`ContaAcesso` não
   têm `status`; `papel` é `String` aberto (DST-GAP-015).

---

## 1. Contexto — estado real do repositório (discovery)

### 1.1 Stack encontrada (somente leitura; nada instalado)

| Item | Estado real |
|---|---|
| Monorepo | npm workspaces (`apps/*`, `packages/*`); `package-lock.json`; sem Turborepo/pnpm |
| App web | `apps/web` — **Next.js 14.2.35** (App Router), React 18.3.1, Tailwind 3.4; **uma** página estática (`app/page.tsx`), `layout.tsx`; **sem** `middleware`, **sem** `route.ts`, **sem** Server Actions |
| TypeScript | 5.9.3 instalado (^5.5.4 declarado); `tsconfig.base.json` + `tsconfig.json` |
| Prisma | 6.19.3 (`@contifisc/core`, `type: module`); `datasource` com `relationMode = "foreignKeys"`; **nenhum código de runtime** que instancie `PrismaClient` |
| Pacotes | `core` (só schema/migrations/docs RLS), `types` (Uuid, Money, Competência, IdempotencyKey, SemVer, 3 interfaces canônicas), `ui` (Button, Card), `integrations` (ERPAdapter, IntegrationGateway — esqueletos), `ai` (README: reservado ao MIT) |
| Acoplamento | `apps/web` depende só de `@contifisc/ui`; **não** depende de `@contifisc/core` |
| Testes | `vitest` (`tests/types`, `tests/integrations`); nenhum teste de acesso/segurança em nível de app |
| Lint | ESLint 8 + `@typescript-eslint`; **sem** `no-restricted-imports` |
| CI | `.github/workflows` — dispara em `push` para **`main`** e `pull_request`; o branch local é **`master`** (observação: pushes em `master` não disparam CI; a verificar) |
| Node | 24.19.0 local; CI usa 20 |
| Env | `.env` (gitignored) só com `DATABASE_URL` (DIRECT) e `NODE_ENV`; **sem** `DATABASE_URL_POOLED`, sem secrets de sessão/auth |
| Autenticação | **inexistente** — nenhum pacote de auth instalado (`node_modules` só tem `next`, `react`, `react-dom` entre os candidatos) |
| Banco | Neon DEV PG 18.6 (AWS `us-east-2`), 26 tabelas, RLS 25/25, 30 policies, 0 dados; migrations `…0908120000` (baseline), `…150000` (ROLLED BACK), `…160000`, `…170000` |

### 1.2 Modelo de acesso atual (físico, `schema.prisma` + RLS)

| Estrutura | Estado | Observação relevante |
|---|---|---|
| `Tenant` | só `id` | sem `nome`/`status` (GAP-CDC-1.3-001) — não há como representar "Tenant suspenso" |
| `ContaAcesso` | só `id` | sem `tipo` (GAP-CDC-1.4-002), sem `status`, sem e-mail/provider (proposital, ADR-D025) |
| `ContaAcessoTenant` | `id, conta_acesso_id, tenant_id, papel(String)` | `UNIQUE(conta,tenant)` → **um papel por par**; sem vigência/status (GAP-CDC-1.4-001); FKs imutáveis, revogar = `DELETE` |
| `ContaAcessoUnidadeEconomica` | `id, conta_acesso_id, unidade_economica_id, papel` | ADR-C014 (triggers) exige concessão de tenant correspondente; **RLS não aplica a restrição por UE** |
| `EventoAuditoriaSeguranca` | só `id`; RLS ligada **sem nenhuma policy** | com `FORCE RLS` **nem o runtime consegue inserir** (GAP-CDC-1.3-002) |
| `CredencialAcesso`, `Sessao`, `PapelAcesso`, `Permissao` | **sem model** | diferidos; `CDC-SEC-003` proíbe `PapelAcesso`/`Permissao` como objetos separados (V1.4) |
| Módulos/entitlements/planos | **inexistentes** em qualquer documento canônico | CAF-001 lista apenas pilares e "Login funcional" como critério de aceite |

### 1.3 O que a RLS validada garante — e o que **não** garante (fronteira de confiança real)

Confirmado em `RLS_MATRIX.md`/migrations e nos smoke tests S01–S17:

- `tenant`: o **banco** verifica a concessão (`contifisc_conta_tem_acesso_tenant(conta, tenant.id)`); com
  só `app.current_conta_acesso_id` a conta enxerga os seus tenants.
- **Demais tabelas**: filtram por `app.current_tenant_id` (via `unidade_economica` ou coluna
  materializada). O banco **não** re-verifica, nessas tabelas, que a conta tem concessão para o tenant
  ativo (`SECURITY_CONTEXT_CONTRACT.md` §4, T46/T47): *"a defesa real está em nunca permitir a aplicação
  setar esse tenant sem grant"*. **Quem estabelece o contexto é o único garantidor.**
- `conta_acesso_tenant`: policy `tenant_id = contexto` → com o tenant ativo, **qualquer conta desse
  tenant lê todas as concessões do tenant** (inclusive papéis dos colegas); sem tenant ativo, a conta
  **não** consegue listar as próprias concessões. A leitura "meus tenants" deve usar a tabela `tenant`.
- `conta_acesso` é `GLOBAL_COMPARTILHADO` (policy permissiva): qualquer runtime lê/escreve contas.
- `app.current_unidade_economica_id` está **reservado e não usado** por nenhuma policy.
- Um `contifisc_app` ainda **não existe**; o provisionamento de `Tenant`/1ª concessão exige role
  `BYPASSRLS` (`contifisc_provisioning`, proposto e não criado).
- `contifisc_rls_mediator` existe (NOLOGIN, BYPASSRLS); `EXECUTE` nas funções SD para o runtime exige a
  janela atômica de membership documentada no ADENDO 6.

## 2. Problema

Sem uma arquitetura de acesso aprovada, qualquer implementação de login/autorização corre quatro riscos:

1. **Colapso de dimensões** (ex.: usar "Organization" do provedor como `Tenant`; usar plano comercial como
   permissão; usar e-mail como identidade canônica) — gerando dívida estrutural e brechas.
2. **Estabelecimento inseguro de contexto**: a RLS só é tão forte quanto quem seta os GUCs; hoje não há
   nenhuma API central que impeça queries fora de transação/contexto.
3. **Acoplamento comercial × dado**: bloquear dado canônico por falta de módulo quebraria motores que
   consomem dados de módulos não contratados (ex.: cálculo tributário usando fatos financeiros).
4. **Lacunas canônicas** que bloqueiam o desenho (status de Tenant/Conta, vigência de concessão,
   catálogo de papéis, auditoria gravável).

## 3. Objetivos

O1. Definir a cadeia completa de autorização e onde cada regra é aplicada.
O2. Definir identidade externa, autenticação, sessão e MFA sem acoplar o modelo canônico a um provedor.
O3. Definir modelo conceitual de módulos/features/entitlements suportando venda modular numa **única** aplicação.
O4. Definir RBAC/ABAC, granularidade e a interseção entitlement × permissão × UE.
O5. Definir acesso de usuários internos sem "superusuário implícito".
O6. Definir role de runtime, integração Prisma/pooling e API central de contexto transacional.
O7. Threat model, fluxos A–R, auditoria, impacto canônico, alternativas, gaps, PoC e critérios de aprovação.

## 4. Não objetivos

Implementar auth/login/frontend; fechar catálogo definitivo de módulos, permissões ou papéis; definir
preços/billing; alterar RLS ou o modelo físico; criar roles/tabelas/seed; decidir EVT/INT/RGT/Skills;
escolher definitivamente o provedor (recomendação condicionada a PoC); alterar baselines canônicas.

## 5. Princípios

P1. `identidade tributária ≠ identidade de acesso ≠ tenant ≠ UE` (SEC-001 §1) — **estendido** aqui:
`autenticação ≠ autorização ≠ entitlement comercial ≠ isolamento de dados`.
P2. **Negar por padrão**; nenhuma concessão, módulo ou permissão é implícita.
P3. **O cliente nunca é autoridade**: tenant, módulo, papel, UE e permissões vêm do servidor; o
navegador só *solicita*.
P4. **Autorização é reavaliada por requisição** contra o estado atual (não embutida em token de longa vida).
P5. **Defesa em profundidade**: UI (dica) → API/serviço (autoridade) → contexto transacional → RLS (piso).
Esconder menu **não** é segurança.
P6. **Entitlement controla funcionalidade, não a existência física do dado canônico.**
P7. Camadas com **ownership distinto**: quem administra catálogo/entitlement não é quem opera dados; quem
administra usuários do tenant não pode exceder o próprio poder (teto de delegação).
P8. **Fail-closed uniforme** e auditável; erros não devem permitir enumeração de tenants/recursos.
P9. **Menor privilégio no banco**: `contifisc_app` sem BYPASSRLS, sem ownership, sem DDL, sem escrita em
estruturas de controle de acesso/entitlement.
P10. **Portabilidade**: provedor de autenticação substituível sem migração do modelo canônico.

## 6. As seis dimensões e a cadeia de autorização

### 6.1 Dimensões (não devem ser confundidas)

| # | Dimensão | Pergunta | Autoridade / fonte de verdade | Onde é avaliada | Falha típica |
|---|---|---|---|---|---|
| 1 | Autenticação | Quem é o usuário? | Provedor de identidade + sessão server-side | Borda/serviço (G1) | 401 |
| 2 | Tenant | A quais tenants esta `ContaAcesso` pode acessar? | `ContaAcessoTenant` (+ `Tenant` ativo) | Serviço (G3/G4) + **prova no banco** (G8) | 403/404 |
| 3 | Entitlement | O Tenant pode usar esta funcionalidade *agora*? | Catálogo + concessões de entitlement (COMERCIAL) | Serviço/PDP (G5) | 403 `MODULO_NAO_HABILITADO` |
| 4 | Papel/Permissão | A conta pode fazer *isto* nestes módulos? | Papel (catálogo) + ABAC | Serviço/PDP (G6) | 403 `PERMISSAO_NEGADA` |
| 5 | Unidade Econômica | Há restrição a UEs específicas? | `ContaAcessoUnidadeEconomica` | Serviço/PDP (G7); RLS **não** aplica hoje | 403/404 |
| 6 | RLS | Quais registros o PostgreSQL permite? | Policies (ADR-002) | Banco (G9) | 0 linhas / erro RLS |

### 6.2 Cadeia formal (todas as condições são necessárias — conjunção, sem atalhos)

```
G1  Autenticado          sessão válida, não expirada, não revogada; nível de autenticação (MFA/step-up) suficiente
G2  ContaAcesso ativa    IdentidadeExterna ATIVA → ContaAcesso existente e ATIVA (não suspensa/encerrada)
G3  Tenant autorizado    ContaAcessoTenant(conta, tenant) existe e está vigente
G4  Tenant ativo         Tenant em estado operacional (não SUSPENSO/ENCERRADO)
G5  Entitlement          Entitlement(tenant, feature, agora) = HABILITADO  (módulo/feature/dependências/vigência)
G6  Permissão            permissão ∈ papel da concessão  ∧  predicados ABAC (segregação de funções, limites)
G7  UE permitida         se existir restrição: UE ∈ UEs listadas; senão: todas as UEs do tenant
G8  Contexto verificado  contexto transacional estabelecido; concessão de tenant PROVADA pelo banco (§18.2)
G9  RLS                  PostgreSQL filtra/valida os registros (piso independente de G1–G8)
```

**Ordem de avaliação** (barata e não-vazadora primeiro): G1 → G2 → (resolver tenant/UE **da sessão
server-side**, nunca do payload) → G3/G4 → G5 → G6 → G7 → G8 → G9. Entitlement é *tenant-scoped*, logo só
faz sentido após G3/G4. Cada negação gera evento de auditoria com o **portão** que falhou (§22).

**Invariantes (testáveis):**

- I1. `G9` nunca é relaxada por `G1–G8`; nenhum "sucesso" de portão superior desliga a RLS.
- I2. `G7` **só restringe**: nunca amplia G3 (CDC-REL-SEC-001, ADR-C014).
- I3. `G5` nunca é derivado de `G6` e vice-versa: permissão sem entitlement **nega**; entitlement sem permissão **nega**.
- I4. Nenhum portão lê estado de **claims do cliente** como fonte de verdade.
- I5. Ausência de módulo ≠ ausência de dado: `G5` não altera o que o banco armazena nem o que *motores
  internos* podem ler para o mesmo tenant (§13).
- I6. Toda negação é **determinística** e reproduzível dado (estado, relógio do servidor).

### 6.3 Taxonomia de negação (interna) × resposta externa

| Portão | Código interno | HTTP externo | Observação anti-enumeração |
|---|---|---|---|
| G1 | `NAO_AUTENTICADO` / `MFA_REQUERIDO` | 401 | — |
| G2 | `CONTA_INATIVA` | 403 | mensagem genérica |
| G3 | `TENANT_NAO_AUTORIZADO` | **404** (recurso) / 403 (troca de tenant) | não revelar existência de tenant/recurso alheio |
| G4 | `TENANT_INATIVO` | 403 | mensagem própria (é informação legítima ao usuário do tenant) |
| G5 | `MODULO_NAO_HABILITADO` / `ENTITLEMENT_EXPIRADO` | 403 | mensagem própria (venda/renovação); **auditar** |
| G6 | `PERMISSAO_NEGADA` | 403 | — |
| G7 | `UE_FORA_DO_ESCOPO` | **404** | idem G3 |
| G8/G9 | `CONTEXTO_INVALIDO` / 0 linhas | 500 (bug) / 404 | erro de contexto é bug de plataforma: alarme |

## 7. Trust boundaries

```
[Navegador/cliente]  ── não confiável (tenant/módulo/papel/UE apenas SOLICITADOS)
        │  HTTPS, cookie de sessão (HttpOnly/Secure/SameSite)
[Edge/middleware Next]  ── NUNCA autoridade de autorização (só triagem grosseira de cookie)
        │
[Route Handlers / Server Actions]  ── PEP obrigatório (defineAction/requireAccess)
        │
[Serviço/PDP  authorize()]  ── autoridade de G1–G7; estabelece contexto (G8)
        │  Prisma → endpoint POOLED, role contifisc_app (NOBYPASSRLS)
[PostgreSQL]  ── piso G9 (RLS) + GRANT mínimo; provê prova de concessão (G8)
        ⋮
[Provedor de identidade]  ── confiável só para "quem é" (subject); nada sobre tenant/permissão
[Plano de controle CONTIFISC]  ── catálogo, entitlements, provisionamento; caminho e credenciais separados
```

**Premissa explícita:** o servidor de aplicação é *trusted* para afirmar a identidade da conta. A RLS **não
protege contra um servidor comprometido** que ponha o `conta_acesso_id` de outra pessoa; protege contra
bugs de escopo, IDOR, SQLi lateral e erros de filtro. Mitigação do servidor comprometido = separação de
credenciais, menor privilégio, auditoria e detecção (§21, §22).

## 8. Identidade externa e `ContaAcesso`

### 8.1 Modelo conceitual (sem alterar schema)

```
Provedor de identidade ── (provedor, external_subject) ──► IdentidadeExterna ──► ContaAcesso.id ──► ContaAcessoTenant …
```

| Conceito | Papel | Classe |
|---|---|---|
| `ContaAcesso` | identidade **canônica** CONTIFISC (COT-OBJ-017); estável, imutável (`id`) | CANÔNICA/SEGURANÇA |
| `IdentidadeExterna` (nova, proposta) | vínculo explícito `(provedor, external_subject)` ↔ `ContaAcesso`; `UNIQUE(provedor, external_subject)`; estado `ATIVA/REVOGADA`; carimbos de vínculo/revogação; **e-mail NÃO é chave** | SEGURANÇA |
| Registro do provedor (usuário, sessão, credenciais) | propriedade do provedor/biblioteca | OPERACIONAL (fora do canônico) |

Regras propostas (**DP-01**):

- `external_subject` é opaco e estável **por provedor**; nunca é `ContaAcesso.id` nem e-mail.
- **Múltiplos provedores/identidades por conta** são suportados (ex.: senha+passkey do mesmo provedor;
  Google + login corporativo), sempre via vínculo explícito.
- **Mudança de e-mail** no provedor não altera a conta canônica nem o vínculo.
- **Account linking** só por fluxo explícito: usuário já autenticado + *step-up* (reautenticação recente) +
  verificação do novo fator; nunca "auto-link por e-mail igual" (vetor clássico de account takeover).
- **Identidade órfã** (autenticou no provedor, sem `IdentidadeExterna`/sem `ContaAcesso` ativa): resulta em
  estado *"sem acesso"* — **nenhuma** conta/tenant é criado por auto-cadastro (ver PD-01 sobre onboarding).
- **Duplicidade**: `UNIQUE` impede o mesmo `(provedor, subject)` em duas contas; fusão de contas é
  operação administrativa auditada (nunca automática).
- **Revogação**: revogar `IdentidadeExterna` **e** encerrar sessões no provedor; a conta pode permanecer
  (auditoria/histórico) mas sem meio de login. Recuperação = novo vínculo via convite/admin, com auditoria.
- **MFA**: pertence ao provedor, mas **a exigência** (política) pertence à CONTIFISC: `G1` verifica o
  *nível de autenticação* da sessão (ex.: `aal2`) conforme papel/operação (§9.3).
- **Onde armazenar**: schema dedicado (`contifisc_auth`, PD-07) acessível **somente** pelo role de
  autenticação — não em `public`, para não estender a matriz RLS de 25 tabelas sem decisão.

### 8.2 Relação com `PessoaFisica`

`ContaAcesso` **não** é `PessoaFisica` (CDC-PER-001). Uma associação *opcional* PF↔Conta existe no
diagrama do COT; seu uso (ex.: o profissional de saúde é ao mesmo tempo titular tributário e usuário)
fica **PD-08** — se adotada, é vínculo explícito e nunca dá acesso a fatos da PF por si só (SEC-001 §3).

## 9. Autenticação

### 9.1 Sessão

**DP-02 — sessão server-side com cookie opaco** (não JWT auto-suficiente com permissões):

- Cookie `__Host-` (Secure, HttpOnly, SameSite=Lax, Path=/), valor opaco → registro de sessão no banco de
  autenticação: `conta/identidade`, `criada_em`, `ultima_atividade`, `expira_idle`, `expira_absoluta`,
  `aal` (nível de autenticação), `tenant_ativo`, `ue_ativa`, `revogada_em`, `device/UA hash`.
- **Rotação do identificador no login e em elevação de privilégio** (mitiga *session fixation*).
- Timeouts idle + absoluto; *logout* e "encerrar todas as sessões" revogam no servidor.
- `tenant_ativo`/`ue_ativa` são **estado server-side**, definidos apenas pelos endpoints de troca (§20-H/I),
  **nunca** lidos de header/body/cookie editável.
- Autorização recalculada por requisição a partir do banco (G2–G7), com cache **curto** (≤ 60 s, chaveado
  por `conta+tenant`, invalidado por evento de revogação) → *"permissão revogada com sessão ativa"* passa a
  ter janela máxima explícita e auditável (§21).
- **Cross-site**: `SameSite=Lax` + verificação de `Origin` em mutações; Server Actions exigem
  autorização **dentro** de cada action (são endpoints POST públicos).
- **Middleware Next.js não é PEP.** Já houve classe de falhas de bypass de middleware no ecossistema
  Next.js (ex.: CVE-2025-29927, corrigida em versões posteriores — *verificar cobertura da 14.2.35 na PoC*):
  o middleware só descarta requisições sem cookie; **toda** rota/action verifica de novo.

### 9.2 Recuperação, revogação e credenciais

Recuperação por token de curta duração/uso único ligado a canal verificado (SEC-001 §13); credenciais
nunca armazenadas em claro; toda sessão e fator revogável independentemente; troca de fator sensível exige
*step-up*; recuperação de conta **privilegiada** exige verificação administrativa.

### 9.3 MFA e política de nível de autenticação (PD-03)

Proposta: MFA **obrigatório** para (a) usuários internos CONTIFISC, (b) administradores de tenant e
qualquer papel com `admin.*`/`*.aprovar`, (c) operações sensíveis (troca de fator, concessão de acesso,
exportação em massa, elevação) via *step-up*; **fortemente recomendado** (política por tenant) aos demais
(dados de saúde/tributários de PF são sensíveis sob LGPD). Passkeys como fator preferencial.

### 9.4 Comparação de provedores (não instalar; decisão só após PoC)

> **Superado pelo §31.9** (comparação refeita com documentação **oficial** em 2026-09-21). Correções: Clerk — MFA e passkeys **não** estão no plano Free (estão no Pro) e
> roles customizados exigem add-on; Neon Auth — MFA/passkeys **não declarados** na doc oficial e branches **clonam** usuários/sessões; Better Auth — OAuth/passkey **não** passam pelo desafio 2FA por padrão.
> Classificação final: Better Auth = FINALISTA · Clerk = FINALISTA · Neon = VIÁVEL (condicionado) · Auth.js = ELIMINADA.

Fontes: docs oficiais Neon e Better Auth + análises comparativas de terceiros (§30). Itens de terceiros
estão marcados **[T]** e **precisam ser confirmados em fonte oficial/PoC** antes da decisão.

| Critério | Auth.js (NextAuth) | Better Auth (self-hosted) | Clerk (SaaS) | Neon Auth (Better Auth gerenciado) |
|---|---|---|---|---|
| Situação | Desde set/2025 sob o time do Better Auth em **modo somente-segurança**; guia para projetos novos aponta ao Better Auth. Correções de segurança em jul/2026 (homóglifo de e-mail, `getToken`, cookies OAuth) | v1 desde 2025, ativo, adoção crescente **[T]** | SaaS maduro, novo pricing fev/2026 **[T]** | **GA**; baseado em Better Auth 1.4.x (docs Neon) |
| Next.js App Router / sessões server-side | Sim (JWT ou banco) | Sim (sessão em banco por padrão) | Sim (middleware+helpers; sessão JWT curta + estado no vendor) | Sim (SDK de servidor dedicado) |
| MFA / passkeys | via provedores/adapters, menos integrado | TOTP e passkeys como plugins **[T]** | TOTP/passkeys; em planos pagos MFA/passkey podem ser add-on **[T]** | herda Better Auth; **cobertura de MFA/passkey a confirmar** (a página de overview não detalha) |
| OAuth / e-mail / recuperação | Amplo | Amplo (plugins) | Amplo + SSO/SAML | E-mail/senha + OAuth (Google citado) |
| `subject` estável | `sub` do provedor OAuth / id do adapter | id do usuário (própria tabela) | `user_…` estável do vendor | id em `neon_auth` |
| Prisma | Adapter oficial | Adapter Prisma documentado | n/a (dados no vendor) | **Não documentado** (implementação interna Kysely **[T]**); dados em schema `neon_auth` |
| Neon/PG | Qualquer PG | Qualquer PG (tabelas suas) | n/a | **Dados no seu banco Neon** (`neon_auth`), acompanham *branches* |
| Multi-tenant | DIY | Plugin `organization` **[T]** — *não usar como Tenant* | "Organizations" — **risco de conflar Organization=Tenant** | orgs/roles do Better Auth (detalhe não documentado) |
| Segurança/operação | Você opera; modo manutenção | Você opera (patching, sessões, backups) | Vendor opera; superfície de vendor | Neon opera; **IP Allow/Private Networking não suportados**; só AWS |
| LGPD/residência | Seus dados | Seus dados (região do seu PG: hoje AWS us-east-2) | Dados de usuários no vendor (EUA) **[T]** | No seu Neon (AWS); **branches clonam usuários/sessões** → cuidado com dados reais em DEV/preview |
| Lock-in / migração | Baixo | Baixo (dados seus; camada de porta própria) | **Alto** (usuários/hashes no vendor; export limitado **[T]**) | **Alto ao Neon**; migração para Better Auth self-hosted plausível, com esforço |
| Custo | Zero | Zero de licença; custo operacional | Free até 50 mil MAU; Pro $25/mês + $0,02/MAU **[T]** | Free 60 mil MAU; Launch/Scale 1 mi MAU |
| Maturidade p/ este caso | **Não recomendado para novo** | **Candidato preferencial** | Alternativa "compre e não opere" | Alternativa se simplicidade operacional > lock-in |

**Recomendação (PD-04, não aprovada):** rodar **PoC-3** com **Better Auth self-hosted**, sempre atrás de uma
porta própria `IdentityProvider`/`SessionResolver` (a aplicação só conhece `subject` → `IdentidadeExterna` →
`ContaAcesso`), de modo que trocar para Neon Auth ou Clerk seja implementação de adapter, não refatoração de
autorização. Registrar como requisito: **não** usar `organization`/roles do provedor como fonte de verdade de
Tenant/papel (a fonte é `ContaAcessoTenant` + catálogo CONTIFISC). Verificar na PoC: compatibilidade com
**Next 14.2.35** (várias bibliotecas assumem Next ≥15; ver PD-09), Prisma 6.19, latência de revogação, e o
schema de tabelas que a biblioteca exige (para decidir schema `contifisc_auth`).

## 10. Tenant

Preserva-se integralmente: `Tenant` = **boundary técnica de isolamento** (SEC-001 §1); **não** é cliente,
organização, empresa, UE nem assinatura comercial. O navegador pode *solicitar* um `tenant_id`; **não é
autoridade**. O backend valida `ContaAcesso → ContaAcessoTenant → Tenant` (G3/G4) e só então estabelece o
contexto, com **prova no banco** (§18.2).

Consequências do desenho:

- Um "cliente comercial" pode mapear para 1..N `Tenant` (ou N clientes para 1 tenant); a relação
  comercial vive em estruturas **COMERCIAIS** separadas — nunca em `Tenant`.
- `Tenant` precisa de um **estado de segurança** (`ATIVO/SUSPENSO/ENCERRADO`) — kill switch e pré-requisito
  de G4 (**PD-05**: o estado de `Tenant` é atributo de segurança, não comercial; exige CR canônico —
  GAP-CDC-1.3-001).
- Troca de tenant é operação explícita, autorizada e auditada (§20-H); nunca por parâmetro livre.
- Descoberta de tenants da conta: consulta a `tenant` sob **apenas** `app.current_conta_acesso_id` (a RLS
  do próprio banco devolve só os tenants concedidos — prova por construção).

## 11. Módulos, features, produtos e Skills

### 11.1 Quatro conceitos distintos

| Conceito | Definição | Quem define/consome | Exemplo (não congelado) |
|---|---|---|---|
| **Produto comercial** | O que se vende/contrata (pode ser um bundle) | Comercial; plano/contrato | "Equiparação Hospitalar"; "Pacote Clínica" |
| **Módulo funcional** | Unidade de produto/UX/permissão: agrupa capacidades e define um *namespace* de permissões e navegação | Produto/engenharia | `equiparacao`, `financeiro`, `tributario_pj` |
| **Feature/Capability** | Capacidade fina, habilitável isoladamente (inclusive *premium*) dentro de um módulo | Produto/engenharia | `equiparacao.classificar`, `equiparacao.simular`, `tributario.calcular` |
| **Skill / motor de inteligência** | Implementação computacional (ATI/GTI/MIT) que **consome o Modelo Canônico** (CAF-001) | Engenharia | motor de classificação EqHosp; motor de apuração Presumido |

**Não são equivalentes**: um produto pode habilitar vários módulos; um módulo tem várias features; uma
feature pode usar várias Skills; uma Skill pode servir várias features de módulos distintos (**motores
compartilhados**) e **não** é, por si só, unidade de entitlement.

### 11.2 Catálogo funcional de referência (não congelado)

Tributário PJ; Equiparação Hospitalar; Simples Nacional/Fator R; Tributário PF; Carnê-Leão; IRPF; INSS/
recuperação de teto; Financeiro; Faturamento/Glosas; Conformidade (fonte: prompt de negócio + pilares do
CAF-001). Nenhum destes nomes é vinculante para este ADR.

### 11.3 Análise: Equiparação Hospitalar é A, B, C ou D?

| Opção | Aderência | Problemas |
|---|---|---|
| A — só módulo | Serve à venda avulsa (Cliente A do exemplo) | Ignora que depende de motores tributários comuns; risco de duplicar cálculo |
| B — feature dentro de Tributário PJ | Reflete o vínculo técnico (regime Presumido; presunções 8%/12%) | **Não** permite vender/contratar avulso nem ter `equiparacao.*` próprio; força "pacote" |
| C — produto independente apoiado pelo tributário | Reflete a venda | Sem módulo próprio, perde namespace de permissão/navegação/ciclo de vida |
| **D — combinação (recomendada)** | Produto comercial **+** módulo funcional próprio (`equiparacao`) **+** features (classificar, simular, conformidade, revisar) **+** dependência de *motor* compartilhado (não de *módulo*) | Exige distinguir *dependência de entitlement* de *dependência de motor* |

> **Revisado no §31.10 (DP-03 revisada):** a unidade técnica é a **capability**; o produto é fonte de concessões; o módulo é agrupamento (apresentação, Classe C); o motor é dependência técnica.
> A frase "módulo funcional próprio" abaixo **não** está mais fixada.

**Recomendação (DP-03/PD-06):** **D.** Evidências: (i) o schema já tem objeto canônico próprio
(`ClassificacaoEquiparacaoHospitalar`) e status EqHop no DST; (ii) o caso de uso comercial exige venda
avulsa; (iii) existem duas capacidades distintas (diagnóstico de elegibilidade/conformidade × simulação
de economia), naturalmente **features**. Regra: o módulo `equiparacao` **não exige** `tributario_pj`
habilitado para operar; ele consome o **motor** tributário como capacidade interna (§13). Se um dia
regra comercial exigir bundle, isso é dependência de **plano/produto**, não de arquitetura.

## 12. Entitlements — modelo conceitual (nenhuma tabela criada)

### 12.1 Pergunta que o mecanismo responde

```
pode_usar(tenant, feature, instante) → HABILITADO  |  NEGADO(motivo)
```

Função **determinística**: mesmo estado + mesmo instante → mesma resposta. O instante é o relógio do
**servidor** (UTC), fixado uma vez no início da requisição; vigência semiaberta `[início, fim)`.

### 12.2 Estruturas conceituais (comparação de modelagens)

| Opção | Descrição | Avaliação |
|---|---|---|
| **1. `Modulo` + `Feature` + `TenantModulo` + `TenantFeature`** | catálogo tipado + concessões em dois níveis | Semântica clara (módulo base vs feature premium); mais tabelas |
| **2. `TenantEntitlement(tenant, chave, …)`** com chave hierárquica `modulo` ou `modulo.feature` | uma tabela de concessões; catálogo em código | **Mais enxuta**, mesma semântica; requer validar `chave` contra o catálogo em código |
| 3. Flags/JSON por tenant | mapa livre | **Rejeitada**: sem vigência, sem dependências, sem ledger, sem auditoria |
| 4. Delegar a billing externo (entitlements de terceiro) | fonte externa | Adiar; a CONTIFISC deve ter **porta** própria para não acoplar (billing não é escopo) |

**DP-04:** o **catálogo** (módulos, features, dependências, permissões, papéis-template) é **versionado em
código** (tipado, testável, revisado em PR) — a existência de uma feature está acoplada a deploy de código,
logo a fonte de verdade da *existência* é o código; o **banco guarda apenas concessões** referenciando chaves
do catálogo. A escolha entre as opções 1 e 2 fica para a PoC-4 (a semântica abaixo vale para ambas).

### 12.3 Atributos da concessão de entitlement

| Atributo | Valores / semântica |
|---|---|
| `estado` | `ATIVO`, `TRIAL`, `SUSPENSO`, `CANCELADO` (explícitos); `EXPIRADO`/`TRIAL_ENCERRADO` são **derivados** de `fim < agora` |
| `vigencia_inicio` / `vigencia_fim` | `fim` nulo = sem prazo; **override e trial exigem `fim`** |
| `origem` | `CONTRATO`, `PLANO`, `TRIAL`, `CORTESIA`, `OVERRIDE_ADMIN`, `MIGRACAO` |
| `plano_ref` | referência opaca a plano/contrato (sem semântica de billing) |
| `concedido_por`, `motivo`, `ticket` | obrigatórios para `OVERRIDE_ADMIN`/`CORTESIA` |
| `efeito` | `CONCEDE` ou `NEGA` (negação explícita por feature — *kill switch* granular) |
| histórico | **ledger append-only** de toda mudança (quem, quando, antes/depois, motivo) — responde "estava habilitado em D?" para reprocessamentos e disputas |

### 12.4 Regra de resolução (deny-overrides)

1. Tenant não `ATIVO` (G4) → NEGADO.
2. Concessão `NEGA` vigente para a feature (ou módulo) → NEGADO.
3. Dependências (módulo/feature requerido, transitivo, **sem ciclos**, validadas no catálogo) não satisfeitas → NEGADO(`DEPENDENCIA`).
4. Concessão `CONCEDE` vigente para a feature → HABILITADO.
5. Concessão `CONCEDE` vigente para o módulo **e** a feature é `BASE` desse módulo → HABILITADO.
6. Feature `PREMIUM` sem concessão explícita (ou plano que a inclua) → NEGADO.
7. Default → NEGADO.

### 12.5 Ciclo de vida

- **Trial**: mesma estrutura, `origem=TRIAL`, `fim` obrigatório; encerra por derivação temporal (sem job crítico).
- **Suspensão** (segurança/inadimplência) → bloqueio imediato; **expiração/cancelamento** → comportamento pós-fim
  é decisão **PD-10**: proposta = *somente leitura* dos resultados já produzidos por período de carência
  configurável, sem novas operações/cálculos; suspensão = bloqueio total.
- **Upgrade/downgrade**: novas concessões/ledger; nunca migração de dados (§13, §23).
- **Overrides administrativos**: só no plano de controle; aprovador ≠ solicitante; vigência obrigatória; alerta e
  evento auditável; **um tenant nunca concede entitlement a si mesmo** (P7).

### 12.6 Ownership, RLS e privilégios (proposta para o ADR físico futuro)

Catálogo em código (sem tabela). Concessões e ledger: tenant-scoped (RLS por `tenant_id`, leitura pelo
tenant) com **escrita exclusiva do plano de controle** (via GRANT, não via RLS): o runtime `contifisc_app`
recebe `SELECT` apenas. Isso **não** altera a RLS existente; exigirá migration + entradas na matriz RLS num
ADR físico posterior (ADR-004), fora desta rodada.

### 12.6b Escopo por UE (PD-11)

Baseline = por **Tenant**. Cobrança/licença por UE (ex.: "múltiplas UEs") pode exigir escopo `UE`; o modelo
deve manter um campo de escopo extensível para não exigir remodelagem. Não incluído na V1.

## 13. Fronteira entre dado canônico e funcionalidade

**DP-11 — Entitlement controla FUNCIONALIDADE; nunca a existência ou a acessibilidade física do dado canônico.**

| Acesso ao dado | Governado por | Exige entitlement do módulo *dono* do dado? |
|---|---|---|
| (a) Usuário pela UI/API | G1–G9 (feature entitled + permissão + UE + RLS) | **Sim**, da feature que o expõe |
| (b) Motor/Skill em nome do tenant | fronteira de Tenant (RLS) + **contrato de dependências canônicas** da Skill + entitlement da **feature que dispara** o motor | **Não** — ex.: cálculo tributário lê fatos financeiros sem o módulo Financeiro |
| (c) Ingestão/importação | feature de importação habilitada + contexto de tenant | Não do módulo consumidor |

Consequências:

- Nenhuma tabela, coluna, policy ou FK referencia entitlement; a RLS/ADR-002 permanece intocada.
- **Downgrade/cancelamento** remove *features*, não dados; motores continuam a ler o canônico do tenant.
- **Vazamento indireto**: um resultado exibido sob uma feature pode incorporar informação de módulo não
  contratado (ex.: valor de receita/insumo financeiro). **PD-12**: política de exibição — proposta: exibir
  insumos apenas como referência necessária à explicação/rastreabilidade (CAF-001 princípio 5), sem abrir
  tela/edição do módulo não contratado; exportações e relatórios pertencem à feature que os gera.
- **Escrita cruzada**: criar um fato canônico (ex.: `Receita`) é operação do *domínio*, invocável por
  qualquer feature entitled que precise dele — não por telas do módulo dono.
- Retenção/exclusão de dados segue política LGPD própria, **não** o estado comercial do plano.

## 14. Papéis e permissões

### 14.1 Estado canônico e conflito a resolver

- `ContaAcessoTenant.papel` e `ContaAcessoUnidadeEconomica.papel` são **`String` aberto** (DST-GAP-015; nenhum
  enum).
- `CDC-SEC-003` V1.4: *"Não criar `PapelAcesso` ou `Permissao` como objetos separados — `papel` é um atributo
  direto"*. `SEC-001` §12 descreve `PapelAcesso`/`Permissao` conceitualmente. Existe, portanto, **tensão
  documental** entre o CDC V1.4 e a necessidade de permissões granulares (GAP a resolver por CR — **PD-13**).
- Compatibilização proposta (**DP-04**): o **catálogo** (permissões, papéis-template, composição) vive em
  código; `papel` continua sendo a **chave** de um papel do catálogo. Sem alteração de schema. Papel
  desconhecido ⇒ **nenhuma permissão** (fail-closed).

### 14.2 Alternativas

| Opção | Descrição | Prós | Contras |
|---|---|---|---|
| A. RBAC estático em código | papéis/permissões no catálogo versionado | zero schema novo; auditável em PR; rápido | mudanças exigem deploy; sem papéis por tenant |
| B. RBAC global em banco | tabelas `PapelAcesso/Permissao/PapelPermissao` (catálogo da plataforma) | mudança sem deploy; UI de admin | novo canônico; drift entre código e banco; conflita com CDC-SEC-003 |
| C. Papéis customizáveis por tenant | cada tenant define papéis | flexibilidade comercial | superfície de escalonamento; RLS extra; suporte caro |
| D. Policy engine (OPA/Cedar/Oso) | regras declarativas externas | expressividade, auditoria de política | operação/ferramenta nova; prematuro |
| **E. RBAC (A) + ABAC leve no PDP** | papéis fixos + predicados contextuais | cobre segregação/UE/limites sem engine | regras ABAC em código (testar bem) |

> **Revisado no §31.12:** comparação refeita por mérito (o CDC é versionável). Resultado: **híbrido** — definições (permissões/papéis-padrão) em código com snapshot test; atribuições
> persistidas em `papel`; persistência de definições diferida com gatilhos. Não depende mais do argumento "CDC-SEC-003 proíbe".

**Recomendação: E**, com caminho de evolução A→B só quando houver necessidade comprovada (PD-13) e D só se as
regras ABAC crescerem além de um limite acordado (§19.4).

### 14.3 Granularidade e nomenclatura (não congelada)

`<módulo>.<ação>` ou `<módulo>.<recurso>.<ação>`; ações por criticidade
(`visualizar` < `operar` < `revisar`/`classificar` < `aprovar` < `administrar`). Exemplos apenas ilustrativos:
`financeiro.{visualizar,operar,aprovar}`, `equiparacao.{visualizar,classificar,revisar,aprovar}`,
`tributario.{simular,calcular,revisar,aprovar}`, `admin.{usuarios,modulos,permissoes}`.
Separar dois espaços: **funcionais** (`<módulo>.*`, exigem G5) e **administrativos** (`admin.*`, não dependem de
módulo comercial — para que um tenant suspenso/expirado ainda possa administrar acessos e regularizar; sujeitos
ao estado do Tenant conforme política).

### 14.4 Composição e concessões

`UNIQUE(conta, tenant)` + `papel` único = **um papel por concessão**. V1: papéis **compostos no catálogo**
(inclusão/herança controlada). Múltiplos papéis simultâneos (`ContaAcessoPapel`) = **PD-14**.

### 14.5 ABAC no PDP (atributos sempre do servidor)

Segregação de funções (quem classifica/cria ≠ quem aprova — SEC-001 §12); UE dentro do escopo (G7);
"registro próprio"; limites/thresholds; estado do workflow do objeto (ex.: `RevisaoTecnica`); nível de
autenticação (`aal`) exigido pela operação; condições opcionais (janela/rede) para papéis internos.

### 14.6 Teto de delegação

Ninguém concede papel/permissão que **não possui**; concessão só em tenants onde possui `admin.usuarios`;
concessão ≤ próprio conjunto; toda concessão/revogação auditada; papéis internos só concedidos por plano de
controle/administração interna.

## 15. Interseção entitlement × permissão × UE (PDP)

Interface conceitual (não é código a criar agora):

```
authorize(principal, acao{permissao, feature}, alvo{tenant(da sessão), ue?, recurso?}) →
    Decisao{ permitido | negado, portao, motivo, obrigacoes[] }
capacidades(principal, tenant) → { modulos[], features[], permissoes[] }   // só para renderizar UI (dica)
```

- **Único PDP** (`deny-overrides`), **puro** sobre um *snapshot* consistente lido uma vez por requisição
  (concessão de tenant, estado de tenant/conta, entitlement, papel, restrição de UE).
- **Não** consulta o provedor de identidade; **não** lê claims do cliente.
- Suíte matricial de testes: cada portão G1–G7 falhando isoladamente e em combinação; "direct URL a módulo não
  contratado" como teste obrigatório.
- Decisões `negado` sempre auditadas; `permitido` auditadas para ações sensíveis (§22).
- Localização do código: pacote novo (ex.: `packages/security`) — **PD-15**, não criado.

## 16. Usuários internos CONTIFISC

### 16.1 Princípios (DP-09)

- **Sem superusuário de aplicação implícito.** Conta interna = `ContaAcesso` como as demais (tipo `HUMANA`,
  GAP-CDC-1.4-002) com **concessões explícitas por Tenant** (a "carteira" é o conjunto de concessões).
- Concessões internas têm **vigência e recertificação periódica** (ex.: trimestral) — depende de GAP-CDC-1.4-001.
- Papéis internos distintos dos de cliente (ex.: administrador, contador, fiscal, contábil, DP, revisor,
  consultor, estagiário) — **catálogo não congelado**; estagiário = leitura/rascunho com ABAC
  "requer aprovação"; consultor temporário = concessão com `fim`.
- **MFA obrigatório**; `aal` mínimo por papel; sessões internas com timeouts menores.
- Todo acesso a tenant de cliente por conta interna gera evento na **ativação do contexto** (§20-P).

### 16.2 Três planos (credenciais e caminhos separados)

| Plano | Função | Role/credencial | Acesso a dados de negócio |
|---|---|---|---|
| Controle | catálogo, entitlements, provisionamento de tenants, convites, overrides | `contifisc_provisioning` (BYPASSRLS, uso restrito) | **Não por padrão** |
| Administração de acesso | usuários/papéis/UE dentro do tenant | `contifisc_iam` (proposto, NOBYPASSRLS — PD-17) ou `contifisc_app` com GRANT restrito | Não |
| Dados | operação dos módulos | `contifisc_app` (NOBYPASSRLS) | Sob G1–G9 |

### 16.3 Elevação de emergência (*break-glass*) — PD-16

Acesso a tenant **sem** concessão regular só por **concessão temporária ordinária** (mesma cadeia G3, sem
bypass de RLS, sem "valor mágico"): justificativa/ticket obrigatórios, aprovador distinto do solicitante,
duração curta (parâmetro), escopo mínimo (tenant/UE, leitura), revogação automática, notificação ao admin do
tenant (política), auditoria reforçada e revisão pós-uso.

### 16.4 Tenant interno

O escritório pode ter um `Tenant` próprio (dados/regras internas), tratado como qualquer tenant; **pertencer**
a ele nunca implica acesso a tenants de clientes (MCD §8: os dois `tenant_id` não se confundem) — **PD-21**.

## 17. Runtime PostgreSQL, Prisma e pooling

### 17.1 Roles (proposta; nenhum criado nesta rodada)

| Role | Uso | Atributos-chave | Privilégios |
|---|---|---|---|
| `contifisc_migration` (hoje `neondb_owner`) | migrations, **DIRECT** | dono dos objetos; fora do runtime | DDL |
| **`contifisc_app`** | runtime dos dados de negócio (endpoint **POOLED**) | `LOGIN`, **NOSUPERUSER, NOBYPASSRLS**, NOCREATEROLE/DB, **não-owner**, sem membership persistente no mediator | `USAGE` em `public`; DML nas tabelas de negócio; `SELECT` em concessões de entitlement; `EXECUTE` nas 2 funções SD; **sem** escrita em estruturas de acesso/entitlement |
| `contifisc_provisioning` | plano de controle | BYPASSRLS, credencial distinta, processo/rota separados | `tenant`, `conta_acesso*`, entitlements |
| `contifisc_iam` *(opcional, PD-17)* | administrar concessões dentro do tenant | NOBYPASSRLS | DML só em `conta_acesso_tenant`/`conta_acesso_unidade_economica` |
| `contifisc_auth` | armazenamento da biblioteca de autenticação (schema `contifisc_auth`) | NOBYPASSRLS; sem acesso às tabelas de negócio | schema próprio |
| escrita de auditoria | ver §22 | função SD ou INSERT-only | só inserir |
| `contifisc_rls_mediator` | interno (existente) | NOLOGIN, BYPASSRLS | nunca usado pela aplicação |

Achado de desenho: como `conta_acesso_tenant` tem policy `FOR ALL` por `tenant_id = contexto`, **qualquer**
código com contexto de tenant conseguiria inserir concessões *desse* tenant (escalonamento **dentro** do
tenant). A RLS isola tenants; **não** impede escalonamento interno — daí o GRANT restritivo/`contifisc_iam` +
`admin.usuarios` no PDP (defesa em profundidade, sem alterar policies).

### 17.2 Prisma e Neon

- Um único módulo instancia o `PrismaClient` do `contifisc_app` com a URL **pooled** (`-pooler`,
  `pgbouncer=true`); o plano de controle usa **outro** cliente/credencial, em rota/processo isolado.
- Migrations e tarefas longas: **DIRECT** + owner (nunca do runtime web).
- Transações interativas com `timeout`/`maxWait` explícitos; importações longas em lotes por transação.
- Serverless: pool pequeno por instância (`connection_limit`); o pooler do Neon absorve o resto.
- Compatibilidade de `SET LOCAL` com o pooler e com `$transaction` já validada (S14/S16/S17).
- **DP-06 (parte)**: setar GUC com `set_config(nome, $1, true)` **parametrizado** (equivalente transacional a
  `SET LOCAL`) em vez de interpolar string; validar UUID no helper antes de enviar.
- Segredos por role e por ambiente, fora do repositório, rotacionáveis; **nunca** dados reais em branches DEV/
  preview (SEC-001 §18; branches clonam dados — inclusive `neon_auth`, se adotado).

## 18. Contexto transacional e API central

### 18.1 Contexto (preservado, sem alteração da RLS)

`app.current_conta_acesso_id` (conta autenticada) e `app.current_tenant_id` (tenant ativo), **sempre**
transacionais; nunca `SET SESSION`. `app.current_unidade_economica_id` continua **reservado**, sem uso, salvo
nova decisão formal (**PD-18**).

### 18.2 Algoritmo `withSecurityContext` (DP-06)

```
withSecurityContext(principal, { tenantId, ueId? }, fn):
  BEGIN (Prisma $transaction interativa, timeout explícito)
  1. set_config('app.current_conta_acesso_id', principal.contaId, true)
  2. PROVA DE CONCESSÃO NO BANCO:  SELECT count(*) FROM tenant WHERE id = :tenantId
        → deve ser 1 (a RLS de `tenant` só devolve tenants concedidos à conta, via função SD do ADR-002)
        → senão: abortar TENANT_NAO_AUTORIZADO + auditar (tentativa cross-tenant)
  3. set_config('app.current_tenant_id', :tenantId, true)
  4. fn(tx: TenantScopedTx)          // tipo de marca: só existe dentro do helper
  COMMIT/ROLLBACK  → GUCs desaparecem
```

Propriedades: (i) o banco — não a aplicação — prova a concessão antes de qualquer leitura tenant-scoped, **sem
alterar policy alguma**; (ii) protege contra bug de escopo/IDOR na escolha do tenant; (iii) **não** protege
contra servidor comprometido que forje `principal.contaId` (§7); (iv) custo de uma consulta adicional
(combinável em CTE); (v) idêntico em DIRECT e POOLED; (vi) troca de tenant = **nova** chamada, nunca dentro da
mesma transação.

### 18.3 Reduzir a possibilidade de query fora de contexto

1. `PrismaClient` **não exportado**: a API pública do pacote de dados expõe só
   `withSecurityContext(...)` e (no plano de controle) `withControlPlane(...)`.
2. `no-restricted-imports` (ESLint) proibindo `@prisma/client` fora desse pacote.
3. Repositórios exigem o tipo `TenantScopedTx` (impossível de obter fora do helper).
4. Proibir `$queryRawUnsafe`/`$executeRawUnsafe` fora do helper (lint + revisão).
5. Extensão Prisma (`$extends`) que rejeita operações fora de transação com contexto (camada extra; raw queries
   a burlam — por isso não é a única).
6. **Teste arquitetural** (vitest) que varre imports e falha a build.
7. Rede final: o banco é **fail-closed** (sem contexto ⇒ 0 linhas), já comprovado (S04/S05).
8. Checklist de PR para novas rotas/actions.

### 18.4 Jobs, workers e integrações

Contexto explícito por unidade de trabalho (SEC-001 §15); execução com **conta de serviço** (`ContaAcesso` tipo
`SERVICO` — GAP-CDC-1.4-002) + concessão de tenant; tarefas cross-tenant **iteram tenants**, cada um numa
transação própria; **nunca** `BYPASSRLS` no runtime.

### 18.5 Restrição por UE (G7) — PD-18

**V1 (recomendada):** aplicada no PDP e nos repositórios (filtro obrigatório por UEs permitidas, via helper),
com testes; a RLS não muda. **Alternativa:** ativar `app.current_unidade_economica_id` com policies adicionais
(extensão do ADR-002; exige nova PoC de RLS) — adiada, pois seria reabrir o desenho da RLS sem necessidade
comprovada.

## 19. Onde cada regra é aplicada

### 19.1 Matriz de enforcement

| Regra | UI | Middleware | Handler/Action | Serviço/PDP | Repositório | GRANT (DB) | RLS |
|---|---|---|---|---|---|---|---|
| Autenticado (G1) | esconde | triagem de cookie | **verifica** | verifica | — | — | — |
| Conta ativa (G2) | — | — | — | **decide** | — | — | — |
| Tenant autorizado/ativo (G3/G4) | seletor | — | — | **decide** | usa contexto | — | **prova (G8)** |
| Entitlement (G5) | esconde menu (dica) | — | **exige** | **decide** | — | escrita só plano de controle | — |
| Permissão (G6) | esconde ação (dica) | — | **exige** | **decide** | — | — | — |
| UE (G7) | filtra | — | — | **decide** | **filtra** | — | (futuro, PD-18) |
| Isolamento (G9) | — | — | — | — | — | menor privilégio | **impõe** |
| Auditoria | — | — | dispara | **grava** | — | insert-only | — |

**Regra mínima:** esconder menu **não** é segurança. Uma chamada direta a rota/Server Action/RSC de módulo não
contratado ou sem permissão **deve ser negada pela API** (teste obrigatório). **Server Components também são
PEP**: leitura de dados em RSC passa pelo PDP e por `withSecurityContext`.

### 19.2 Padrão de uso (conceitual)

Toda rota/action é declarada por um wrapper (ex.: `defineAction({ feature, permissao, aal, handler })`) que
executa G1→G7 e abre o contexto; código de negócio nunca vê `principal`/`tenant` vindos do cliente.

### 19.3 Por que entitlement/permissão **não** vão para a RLS (justificativa formal)

1. **Papéis distintos**: RLS é *piso de isolamento* (barato de provar, estável, sem regra comercial);
   entitlement muda por tempo/contrato e tem semântica de produto.
2. **Acoplamento e disponibilidade**: um erro em dado comercial passaria a *derrubar isolamento/dados*
   (ou, pior, a abrir) — mistura de blast radius.
3. **Mediador `SECURITY DEFINER`** já é mecanismo de exceção mínimo (ADR-002); estendê-lo a regras comerciais
   aumentaria a superfície privilegiada.
4. **Motores** precisam ler dados de módulos não contratados (§13) — um gate por módulo na RLS os quebraria.
5. **Desempenho e testabilidade** da RLS (25/25, 30 policies validadas) seriam afetados.

Enforcement parcial no banco **aceito**: `GRANT` (quem pode escrever estruturas de acesso/entitlement) e
constraints/triggers já existentes (ADR-C005/C014). **Reavaliar** apenas se surgirem múltiplos clientes de banco
fora do PDP (§19.4).

### 19.4 Policy engine eventual

Adotar OPA/Cedar/Oso somente se: >1 serviço/linguagem consumir decisões, ou a lógica ABAC exceder limite
acordado, ou houver requisito de auditoria/versão de política independente do código. **Não** na V1.

## 20. Fluxos obrigatórios (A–R)

**A. Login** — (1) usuário autentica no provedor (senha/passkey/OAuth; MFA conforme política); (2) aplicação
recebe `(provedor, subject)`; (3) resolve `IdentidadeExterna → ContaAcesso` (ausente/inativa ⇒ estado
"sem acesso", nunca cria conta); (4) cria sessão server-side, rotaciona ID; (5) **evento** `LOGIN_OK`
(ou `LOGIN_FALHA`, com contador anti-abuso).

**B. Primeiro acesso** — convite emitido por admin (token de uso único, expira) → usuário autentica/registra no
provedor → vínculo `IdentidadeExterna` criado pelo servidor ao consumir o convite → concessão(ões) de tenant
criada(s) por quem convidou dentro do **teto de delegação** → MFA enrolment obrigatório se o papel exigir.
Onboarding autoatendido = **PD-01**.

**C. Resolução `ContaAcesso`** — `subject → IdentidadeExterna(ATIVA) → ContaAcesso(ATIVA)`; falhas ⇒ negação
G2 auditada.

**D. Seleção de tenant** — lista via `SELECT` em `tenant` sob **apenas** o contexto de conta (RLS entrega só os
concedidos); usuário escolhe; servidor valida (G3/G4) e grava `tenant_ativo` **na sessão**; evento
`TENANT_ATIVADO`.

**E. Descoberta de módulos** — `capacidades(principal, tenant)` calcula módulos/features/permissões efetivos
(G5∩G6∩G7); usado **só** para renderizar UI (dica).

**F. Entrada em módulo** — requisição → PEP (`defineAction`/RSC) → G1..G7 → `withSecurityContext` → dados. Sem
G5 ⇒ 403 `MODULO_NAO_HABILITADO` + auditoria.

**G. Autorização de operação** — mesmo pipeline, agora incluindo ABAC (segregação, estado do workflow, `aal`);
operações sensíveis exigem *step-up*.

**H. Troca de tenant** — endpoint dedicado: revalida G3/G4 para o **novo** tenant; encerra o contexto anterior
(nunca reutiliza transação); limpa cache de capacidades; evento `TENANT_TROCADO` (origem→destino).

**I. Restrição de UE** — se há linhas em `ContaAcessoUnidadeEconomica` para (conta, tenant) ⇒ escopo =
UEs listadas (nunca amplia); UE ativa da sessão validada no PDP; consultas filtradas no repositório.

**J. Usuário sem módulo** — tenant sem feature ⇒ menu oculto (dica) **e** API nega (G5); mensagem orientada a
contratação; evento `ACESSO_NEGADO_MODULO`.

**K. Usuário sem permissão** — módulo habilitado, permissão ausente ⇒ 403 `PERMISSAO_NEGADA`; evento
`ACESSO_NEGADO_PERMISSAO`.

**L. Tenant sem entitlement** — caso de J no nível do tenant; para tenant `SUSPENSO`/`ENCERRADO` ⇒ G4 nega
todo o plano de dados (exceto o que a política permitir para regularização/`admin.*`).

**M. Módulo suspenso/expirado** — G5 nega operações; conforme PD-10, leitura de resultados históricos pode ser
preservada; evento com motivo (`SUSPENSO`/`EXPIRADO`/`TRIAL_ENCERRADO`).

**N. Revogação de acesso** — remover `ContaAcessoTenant` (ou encerrar vigência) / desativar conta / revogar
identidade ⇒ **invalidar cache de autorização** e **revogar sessões afetadas** no servidor; efeito ≤ TTL do
cache (ou imediato por evento). Evento `CONCESSAO_REVOGADA`.

**O. Logout** — revoga a sessão no servidor (não só apaga cookie); evento `LOGOUT`; opção "encerrar todas".

**P. Usuário interno** — login com MFA obrigatório; seleção de tenant só entre os **concedidos** (carteira);
ativação de contexto gera evento reforçado; acesso sem concessão só por *break-glass* (§16.3).

**Q. Administração de usuários** — `admin.usuarios` no tenant; convidar/alterar papel/UE/revogar dentro do teto
de delegação; via caminho de administração de acesso (`contifisc_iam`/GRANT restrito); *step-up*; auditoria
completa (antes/depois).

**R. Administração de módulos** — **plano de controle apenas** (nunca o tenant a si mesmo): conceder/suspender/
override com justificativa, vigência e dupla aprovação; ledger + evento; invalida cache de entitlement.

## 21. Threat model

| # | Ameaça | Vetor | Mitigação principal | Portão/camada | Resíduo / observação |
|---|---|---|---|---|---|
| T1 | Tenant spoofing | `tenant_id` em body/header/cookie/URL | tenant vem da **sessão server-side**; troca só por endpoint validado; prova no banco (§18.2) | G3/G8 | servidor comprometido forja conta (§7) |
| T2 | Module spoofing | parâmetro/flag de módulo, rota direta | entitlement lido do servidor; PEP em toda rota/action/RSC | G5 | — |
| T3 | Permission spoofing | claim editável, papel no token | permissões calculadas por requisição, do banco; nunca claims | G6 | janela = TTL do cache |
| T4 | IDOR | id de recurso de outro tenant/UE | RLS (piso) + resposta 404 + filtro por UE no repositório | G7/G9 | validar em teste por recurso |
| T5 | Privilege escalation (vertical) | conceder-se papel/entitlement | teto de delegação; entitlements só plano de controle; GRANT/`contifisc_iam` | §14.6, §17 | RLS não impede escalonamento interno ao tenant — mitigado por GRANT+PDP |
| T6 | Confused deputy | motor/job age com privilégio maior que o solicitante | job com conta de serviço + concessão explícita; contexto por unidade de trabalho; sem BYPASSRLS no runtime | §18.4 | revisar contrato de Skills |
| T7 | Session fixation | ID de sessão pré-login | rotação no login/elevação; `__Host-` cookie | G1 | — |
| T8 | Session theft | XSS, cookie roubado, malware | HttpOnly/Secure/SameSite, CSP, timeouts, vínculo com device/UA (sinal), *step-up* em ações sensíveis, "encerrar todas" | G1 | risco residual aceito, monitorado |
| T9 | Cross-tenant | falha de filtro na app | RLS 25/25 + prova de concessão | G8/G9 | validado S01–S17 |
| T10 | Módulo não contratado por URL direta | navegar a `/modulo/x` | PEP no servidor, não menu | G5 | teste obrigatório |
| T11 | Permissão revogada, sessão ativa | sessão longa | autorização por requisição + cache curto + invalidação por evento; revogação de sessões | G2–G7 | janela ≤ TTL (parametrizar) |
| T12 | Tenant suspenso | uso após suspensão | G4 em toda requisição; kill switch | G4 | — |
| T13 | Módulo expirado / trial encerrado | relógio, cache | vigência avaliada pelo servidor no instante da requisição; expiração derivada | G5 | skew de relógio (NTP) |
| T14 | Troca de tenant abusiva | reuso de contexto/estado | nova transação; revalida G3/G4; evento; limpa cache | §20-H | — |
| T15 | Troca de UE abusiva | UE fora do escopo | UE ativa validada no PDP; filtro obrigatório | G7 | PD-18 |
| T16 | Query fora de transação | uso direto de `PrismaClient` | cliente não exportado, lint, teste arquitetural, DB fail-closed | §18.3 | raw SQL em código novo — revisão |
| T17 | GUC residual em pool | reuso de conexão | somente transacional (`set_config(...,true)`/`SET LOCAL`) | G8 | validado S12/S13/S17 |
| T18 | Service/admin path abusado | rota administrativa exposta | plano de controle isolado, credencial/role separados, MFA, allowlist, auditoria | §16.2 | proteger rede/segredos |
| T19 | Funcionário interno abusa de acesso | carteira ampla | concessões explícitas + vigência + recertificação + auditoria + alertas de volume/horário + *break-glass* controlado | §16 | risco humano residual |
| T20 | Alteração indevida de entitlement | admin comercial malicioso/erro | plano de controle; dupla aprovação em override; ledger append-only; alertas | §12.5 | — |
| T21 | Alteração indevida de papel/permissão | admin de tenant | teto de delegação; auditoria antes/depois; catálogo em código (PR) | §14 | — |
| T22 | Account takeover por linking | auto-link por e-mail | linking só explícito com step-up; e-mail não é chave | §8 | — |
| T23 | Enumeração de tenants/recursos | diferenças 403/404 | resposta uniforme (404) para G3/G7 | §6.3 | tempo de resposta |
| T24 | Bypass de middleware | header/rota especial | middleware não é autoridade; PEP em toda rota; manter Next atualizado | §9.1 | ver PD-09 |
| T25 | Comprometimento do provedor de identidade | conta de vendor | porta `IdentityProvider`; vínculo explícito; MFA; revogação central; nenhuma autoridade de tenant no provedor | §8/§9 | dependência de terceiro (Clerk/Neon) |
| T26 | Auditoria adulterada/perdida | UPDATE/DELETE, falha de gravação | insert-only + imutabilidade; falha de gravação em ação sensível ⇒ operação **falha** (fail-closed) | §22 | depende de PD-19 |
| T27 | Vazamento entre módulos (dado derivado) | resultado exibe insumo não contratado | política PD-12; exports pertencem à feature | §13 | — |
| T28 | Dados reais em DEV/preview | branch clona produção/`neon_auth` | proibição + anonimização; ambientes separados | §17.2 | processo |

## 22. Auditoria

### 22.1 Três trilhas distintas (não confundir)

| Trilha | Conteúdo | Destino | Observação |
|---|---|---|---|
| **`EventoAuditoriaSeguranca`** (COT-OBJ-020) | eventos de segurança: quem, em qual tenant/UE, o quê, resultado | tabela de auditoria imutável | é o escopo deste ADR |
| **Logs técnicos** | erros, latência, traces | observabilidade (OBS-001 futuro) | **nunca** com segredos/PII sensível/dados de tenant |
| **Eventos de domínio** (futuro EVT-001) | fatos de negócio ("Receita registrada") | barramento/EVT | **não** antecipados aqui; reconciliação futura |

### 22.2 Eventos mínimos

`LOGIN_OK`, `LOGIN_FALHA`, `LOGOUT`, `SESSAO_REVOGADA`, `MFA_ALTERADO`, `IDENTIDADE_VINCULADA/REVOGADA`,
`TENANT_ATIVADO/TROCADO`, `TENTATIVA_CROSS_TENANT`, `ACESSO_NEGADO_MODULO`, `ACESSO_NEGADO_PERMISSAO`,
`ACESSO_NEGADO_UE`, `CONCESSAO_TENANT_CRIADA/REVOGADA`, `RESTRICAO_UE_CRIADA/REVOGADA`,
`PAPEL_ALTERADO`, `ENTITLEMENT_CONCEDIDO/SUSPENSO/EXPIRADO/REVOGADO`, `OVERRIDE_ENTITLEMENT`,
`ELEVACAO_ABERTA/ENCERRADA`, `ACESSO_ADMINISTRATIVO`, `ACESSO_INTERNO_A_TENANT`, `EXPORTACAO_SENSIVEL`.

### 22.3 Campos (a formalizar por CR — GAP-CDC-1.3-002)

ator (`ContaAcesso`), `tenant_id` (**anulável** para eventos pré-tenant como falha de login), `unidade_economica_id`
(quando aplicável), operação/portão, objeto afetado (tipo+id), resultado (`PERMITIDO/NEGADO`+motivo), instante,
`request_id`/correlação, origem (IP truncado/hash, UA hash), `aal`, valores antes/depois em mudanças de acesso
(sem segredos).

### 22.4 Escrita e imutabilidade — **achado**

Hoje a tabela tem RLS **sem policy**: nem o runtime nem qualquer não-BYPASSRLS consegue inserir. Opções (PD-19):
(a) função `SECURITY DEFINER` mínima `registrar_evento_seguranca(...)` com `EXECUTE` só ao(s) role(s) de app
(mesmo padrão do ADR-D032); (b) policy `INSERT`-only + `GRANT INSERT` (sem UPDATE/DELETE); (c) role dedicado de
escrita. **Recomendação:** (a) ou (b) — a decidir com PoC-6; em todos os casos: **sem UPDATE/DELETE**
(REVOKE + trigger de imutabilidade), possível encadeamento de hash e exportação WORM; para ações sensíveis a
**falha de gravação impede a operação** (fail-closed). Visibilidade: eventos pré-tenant só ao plano de controle;
eventos de tenant a admins do tenant (transparência sobre acessos internos — PD-20). Retenção definida por
política LGPD; mudança na RLS/ADR-002 seria **aditiva** (ADR-002 V1.1), não reabertura.

## 23. Modelo de negócio — o que a arquitetura suporta

| Capacidade futura | Suporte | Como / limite |
|---|---|---|
| Venda por módulo | Sim | `TenantModulo`/chave `modulo` |
| Planos e bundles | Sim | `plano_ref` + expansão do plano em concessões; catálogo de planos é COMERCIAL, separado |
| Trial | Sim | `origem=TRIAL`, `fim` obrigatório, expiração derivada |
| Upgrade/downgrade | Sim | novas concessões + ledger; **sem migração de dados** (§13) |
| Módulo temporário | Sim | vigência com `fim` |
| Feature premium | Sim | `tipo=PREMIUM` exige concessão explícita |
| Cliente híbrido PF/PJ | Sim | módulos PF e PJ coexistem no mesmo tenant; UEs/vínculos já modelam PF/PJ |
| Múltiplas UEs | Sim | N UEs por tenant; licença por UE só com PD-11 |
| Múltiplos usuários | Sim | N concessões; licença por assento = métrica de contagem (fora do escopo) |
| Expansão comercial sem migração | **Sim (P6)** | dado canônico independe de entitlement |
| Billing/preços | **Não** | fora de escopo; só *porta* para fonte externa de contrato |

## 24. Impacto canônico — COT / MCD / DST / CDC / SEC (nenhum alterado nesta rodada)

### 24.1 Classificação das estruturas propostas

| Estrutura proposta | Classe | Documento(s) que exigiriam versionamento |
|---|---|---|
| `IdentidadeExterna` (provedor+subject → conta; estado) | **SEGURANÇA** | COT (novo objeto SEC), MCD (campos), DST (termo/enum estado), CDC (contrato) |
| Registros do provedor (usuário, credencial, sessão) | **OPERACIONAL** (fora do canônico) | `COT-OBJ-018 CredencialAcesso` precisa ser **reclassificado** (delegado ao provedor) ou substituído por `IdentidadeExterna`; SEC-001 §13 (entidade `Sessao`) idem |
| `ContaAcesso.tipo` (HUMANA/SERVICO), `ContaAcesso.status` | **CANÔNICA/SEGURANÇA** | MCD, CDC-SEC-005, DST (GAP-CDC-1.4-002) |
| `Tenant.status` (segurança) | **CANÔNICA/SEGURANÇA** | MCD, CDC-SEC-001 (GAP-CDC-1.3-001), DST |
| Vigência/estado de `ContaAcessoTenant`/`…UnidadeEconomica` | **CANÔNICA/SEGURANÇA** | MCD, CDC-SEC-003/004 (GAP-CDC-1.4-001) |
| `papel` — catálogo (chaves de papel) | **SEGURANÇA/SUPORTE** | DST (fechar/parcialmente fechar DST-GAP-015), CDC-SEC-003 |
| `Permissao`, `PapelAcesso`, composição (se materializados) | **SEGURANÇA** | COT, MCD, CDC-SEC-003 (**revoga regra "não criar…"**), DST |
| Catálogo de Módulo/Feature/Dependência | **COMERCIAL/OPERACIONAL** (em código) | nenhum canônico tributário; ADR físico se houver tabelas |
| Plano/Produto (bundles) | **COMERCIAL** | fora do canônico tributário |
| `TenantModulo`/`TenantFeature` (ou `TenantEntitlement`) + ledger | **COMERCIAL + SEGURANÇA** (tenant-scoped) | novo bloco COT/MCD/CDC/DST **fora** do domínio tributário (proposta: domínio `DOM-ENT`) + entrada na RLS_MATRIX |
| `ConviteAcesso` | **OPERACIONAL/SEGURANÇA** | ADR físico |
| Elevação/*break-glass* | **SEGURANÇA** | pode ser concessão temporária ordinária (sem objeto novo) |
| `EventoAuditoriaSeguranca` (campos completos) | **SEGURANÇA** | MCD, CDC-SEC-002 (GAP-CDC-1.3-002), DST; depende de OBS-001 para ator |
| Sessão (do provedor) | **OPERACIONAL** | — |

### 24.2 Documentos a versionar no futuro (proposta, não executada)

`SEC-001` V1.1 (adendo: identidade externa, entitlement, provedor, reconciliação papel/permissão);
`COT-001` V1.3; `MCD-001` V1.5; `DST-001` V1.4; `CDC-001` V1.5; **`ADR-004`** (físico: IAM, entitlements,
roles, auditoria); `ADR-002` V1.1 (**aditivo**: GRANTs, caminho de escrita da auditoria, eventual contexto de UE);
`RLS-001`/`RLS_MATRIX` (novas tabelas); `CAF-001` (refinar "Login funcional" como critério de aceite);
relação futura com `OBS-001`/`EVT-001`.

## 25. Alternativas consideradas e trade-offs

| Tema | Alternativa rejeitada/adiada | Motivo |
|---|---|---|
| Local da autorização | Só aplicação | Viola SEC-001 §14 (defesa em profundidade) |
| Local da autorização | Tudo na RLS (inclusive entitlement) | §19.3: mistura piso de isolamento com regra comercial; quebra motores; aumenta superfície privilegiada |
| Módulo × dado | "Módulo não contratado = dado inacessível/inexistente" | Quebra Skills; acopla comercial ao canônico; impede expansão sem migração |
| Tenant | Usar "Organization" do provedor como Tenant | Tenant é boundary técnica (SEC-001 §1); prende o modelo ao provedor |
| Token | JWT com permissões/entitlements embutidos | Revogação lenta; T3/T11; claims viram fonte de verdade |
| Sessão | JWT stateless como única sessão | Dificulta revogação imediata, "encerrar todas" e rotação |
| Identidade | E-mail como chave / `external_subject = ContaAcesso.id` | T22; acopla ao provedor; impede múltiplas identidades |
| RBAC | Papéis por tenant (C) na V1 | Superfície de escalonamento; custo de suporte |
| RBAC | Policy engine (D) na V1 | Prematuro |
| Internos | "Superusuário de aplicação" / tenant interno que vê tudo | Contradiz SEC-001 §12; risco sistêmico |
| Runtime | Runtime como owner/BYPASSRLS | Anula a RLS |
| Contexto | `SET SESSION` | Vaza em pool (proibido) |
| Provedor | Auth.js para projeto novo | Modo somente-segurança (§9.4) |
| Entitlement | Flags/JSON livres | Sem vigência/dependência/auditoria |
| UE | Aplicar restrição na RLS já | Reabre a RLS sem necessidade comprovada (PD-18) |

**Trade-offs principais:** autorização na aplicação (flexível, testável) vs. garantia no banco (menos
flexível) — mitigado por GRANT + RLS piso + prova de concessão; catálogo em código (auditável, exige deploy) vs.
em banco (dinâmico, drift) — escolhido código na V1; provedor gerenciado (menos operação, mais lock-in) vs.
self-hosted (mais controle, mais operação) — decidir em PoC.

## 26. Gaps identificados

> **Reclassificados no §31.2 (A–F).** Nenhum é vulnerabilidade. G-01, G-02 e G-03 eram **deliberadamente deferidos** na baseline; G-07 é consequência esperada do desenho da RLS (isola tenants, não privilégios).
> O texto "achado" usado nesta tabela deve ser lido segundo o §31.2.

| ID | Gap | Impacto | Onde tratar |
|---|---|---|---|
| G-01 | `EventoAuditoriaSeguranca` só `id` e **não gravável** pelo runtime | sem auditoria de segurança | CR canônico + PD-19 |
| G-02 | RLS só *prova* concessão em `tenant`; demais tabelas confiam no GUC | contexto forjado por bug/servidor | mitigado por §18.2; residual §7 |
| G-03 | Restrição por UE não aplicada pela RLS | IDOR intra-tenant por UE | PD-18 (app-layer V1) |
| G-04 | `Tenant`/`ContaAcesso` sem `status`; `ContaAcesso` sem `tipo` | G2/G4 sem base canônica | PD-05 (GAP-CDC-1.3-001, 1.4-002) |
| G-05 | Concessões sem vigência/estado | sem expiração/recertificação de acessos internos | PD-02 (GAP-CDC-1.4-001) |
| G-06 | `papel` aberto (DST-GAP-015); CDC-SEC-003 proíbe `PapelAcesso`/`Permissao` | sem catálogo aprovado | PD-13 |
| G-07 | `conta_acesso_tenant` legível por qualquer conta do tenant; escrevível pelo runtime com contexto | exposição de papéis dos colegas; escalonamento interno | GRANT/`contifisc_iam`, PDP; possível ADR-002 V1.1 |
| G-08 | `conta_acesso` permissiva para qualquer runtime | criação/leitura irrestrita de contas | GRANT (sem INSERT/UPDATE/DELETE p/ runtime) |
| G-09 | `contifisc_app`, `contifisc_provisioning`, `contifisc_auth` inexistentes | sem runtime real | PoC-1; ADR-004 |
| G-10 | Nenhuma camada de acesso a dados (PrismaClient não instanciado) | risco de queries fora de contexto | §18.3 |
| G-11 | Next 14.2.35 (linha antiga); libs modernas assumem Next ≥15 | compatibilidade/segurança | PD-09 |
| G-12 | CI dispara em `main`, branch é `master` | pushes sem CI | corrigir (fora do escopo) |
| G-13 | Sem `.gitattributes` com `autocrlf=true` | risco de alterar checksum de migrations | recomendação (relatório RLS) |
| G-14 | Sem `DATABASE_URL_POOLED` nem gestão de segredos por role | runtime sem configuração | ADR-004/PoC-1 |
| G-15 | Sem política de retenção/LGPD para identidades/auditoria | conformidade | PD-20/PD-22 |
| G-16 | Dados de `neon_auth` clonados em branches (se Neon Auth) | PII em DEV | PD-22 |

## 27. Decisões

### 27.1 Decisões **propostas** (aguardam aprovação)

> Rodada 2: **DP-01, DP-03 e DP-04 foram revisadas**; **DP-12 a DP-16 são novas** (§31.3, §31.5, §31.8, §31.9.3, §31.11). Lista consolidada e classificação de PDs em §31.18.

| ID | Proposta |
|---|---|
| **DP-01** | Identidade externa desacoplada: `(provedor, external_subject) → ContaAcesso`; e-mail nunca é chave; linking explícito com step-up; sem auto-cadastro de contas/tenants |
| **DP-02** | Sessão server-side com cookie opaco; tenant/UE ativos são estado do servidor; autorização recalculada por requisição (cache curto + invalidação) |
| **DP-03** | Equiparação Hospitalar = **D**: produto **e** módulo funcional próprio; dependência de motor compartilhado ≠ dependência de módulo |
| **DP-04** | Catálogo (módulos, features, dependências, permissões, papéis-template) **versionado em código**; concessões em banco por chave; `papel` = chave de papel do catálogo (sem schema novo na V1) |
| **DP-05** | Cadeia G1–G9 com **PDP único** `deny-overrides`; 404 anti-enumeração para G3/G7 |
| **DP-06** | `withSecurityContext` com **prova de concessão pela RLS de `tenant`** + `set_config(…, true)` parametrizado; `PrismaClient` não exportado; lint + teste arquitetural |
| **DP-07** | Entitlement e permissão aplicados na **aplicação**; banco = GRANT de menor privilégio + RLS piso; RLS não vira monólito comercial |
| **DP-08** | Roles separados: migration, `contifisc_app`, provisionamento, (opcional) IAM, auth; `contifisc_app` NOBYPASSRLS/não-owner |
| **DP-09** | Usuários internos: sem superusuário implícito; concessões explícitas com vigência/recertificação; MFA; *break-glass* como concessão temporária auditada |
| **DP-10** | Auditoria em três trilhas separadas; `EventoAuditoriaSeguranca` insert-only; falha de gravação em ação sensível ⇒ falha da operação |
| **DP-11** | Entitlement controla funcionalidade, **não** o dado canônico; motores leem o canônico do tenant independente de módulos contratados |

### 27.2 Decisões **pendentes** (exigem aprovação/insumo de negócio)

> **Reclassificadas no §31.18** em Classe A (decidir agora), B (decidir na PoC) e C (deferir). Esta tabela permanece como registro da rodada 1.

| ID | Pergunta |
|---|---|
| PD-01 | Onboarding: somente convite/admin, ou também autoatendimento? |
| PD-02 | Vigência/estado/recertificação de concessões (GAP-CDC-1.4-001) — prazos e regras |
| PD-03 | Política de MFA por papel/tenant |
| PD-04 | Provedor de autenticação (após PoC-3): Better Auth self-hosted × Neon Auth × Clerk |
| PD-05 | Estado de `Tenant` (`ATIVO/SUSPENSO/ENCERRADO`) e de `ContaAcesso`; `tipo` HUMANA/SERVICO |
| PD-06 | Catálogo de módulos/features e fronteiras (nomes e granularidade) |
| PD-07 | Schema/role de armazenamento de autenticação (`contifisc_auth`) |
| PD-08 | Associação opcional `PessoaFisica ↔ ContaAcesso` |
| PD-09 | Upgrade do Next (14 → 15/16) antes de adotar auth |
| PD-10 | Comportamento pós-expiração: somente leitura (com carência) × bloqueio total |
| PD-11 | Entitlement/licença por UE |
| PD-12 | Política de exibição de insumos de módulos não contratados |
| PD-13 | Materializar `PapelAcesso/Permissao` em tabelas (revoga regra do CDC-SEC-003) |
| PD-14 | Múltiplos papéis por conta/tenant |
| PD-15 | Pacote/localização do PDP (`packages/security`?) |
| PD-16 | Parâmetros do *break-glass* (duração, aprovação, notificação) |
| PD-17 | Criar `contifisc_iam` separado de `contifisc_app` |
| PD-18 | Restrição por UE: só aplicação (V1) × `app.current_unidade_economica_id` + policies |
| PD-19 | Caminho de escrita da auditoria (função SD × INSERT-only × role dedicado) e campos |
| PD-20 | Visibilidade da auditoria por tenant; transparência de acessos internos |
| PD-21 | Existência/uso de tenant interno CONTIFISC |
| PD-22 | LGPD: residência (AWS us-east-2 hoje), `neon_auth`/branches, retenção de identidades |

## 28. Plano de PoC (descartável; **nada executado nesta rodada**)

> **Substituído pelos 4 Gates A–D do §31.19** (Identity/Auth · Runtime/Security Context · Entitlements/Authorization · Audit/Adversarial E2E). As PoC-1…PoC-8 abaixo são o registro da rodada 1 e
> foram absorvidas: PoC-3→Gate A; PoC-1/PoC-2→Gate B; PoC-4/PoC-5/PoC-7 (parte)→Gate C; PoC-6/PoC-7/PoC-8→Gate D.

| PoC | Objetivo | Ambiente | Critério de sucesso |
|---|---|---|---|
| **PoC-1** | Criar `contifisc_app` real (NOBYPASSRLS, não-owner) + GRANTs mínimos + provisionamento do `EXECUTE` (janela do ADENDO 6) | PG18 estilo Neon (2 execuções) e depois Neon DEV | S01–S17 repetidos **como `contifisc_app` via login real** (não `SET LOCAL ROLE`); nenhuma escrita em estruturas de acesso |
| **PoC-2** | `withSecurityContext` (prova de concessão, `set_config` parametrizado, `TenantScopedTx`) | Prisma 6.19, DIRECT e POOLED | conta sem concessão ⇒ falha no passo 2; sem resíduo entre transações; sem query fora de contexto (teste arquitetural falha em violação) |
| **PoC-3** | Provedor: Better Auth self-hosted atrás de `IdentityProvider`; (opcional) Neon Auth em branch descartável; MFA TOTP/passkey; sessão; revogação | Next 14.2.35 **e** Next 15/16 | login→`ContaAcesso` via `IdentidadeExterna`; latência de revogação ≤ TTL; MFA `aal`; schema exigido pela lib mapeado; nenhum dado real |
| **PoC-4** | Resolvedor de entitlement (puro) + ledger; opções 1×2 | Vitest (sem banco) + PG18 descartável | propriedades: determinismo, deny-overrides, dependências sem ciclo, vigência `[i,f)`, trial, override com aprovador; 100% dos casos de §12.4 |
| **PoC-5** | PDP + matriz de portões + rotas de teste | Next + Vitest | cada portão nega isoladamente; **URL direta a módulo não contratado ⇒ 403**; 404 anti-enumeração; RSC/Server Action também protegidos |
| **PoC-6** | Auditoria gravável (função SD × INSERT-only) e imutabilidade | PG18 estilo Neon | runtime insere, não altera/apaga; evento pré-tenant; falha de gravação ⇒ operação falha |
| **PoC-7** | Interno + *break-glass* como concessão temporária | PG18 + PDP | expira sozinho; sem bypass de RLS; auditoria reforçada |
| **PoC-8** | Testes adversariais do threat model (T1–T28 selecionados) | integração | IDOR, tenant/módulo/permissão spoofing, sessão com permissão revogada, GUC residual: todos bloqueados |

Regras das PoCs: sem dados reais; ambientes descartáveis; Neon só onde explicitamente autorizado; scripts
revisados antes de executar (lição do ADENDO 6); reproduzir **ACLs de schema do provedor**.

## 29. Critérios de aprovação do ADR-003

1. Decisões DP-01…DP-11 revisadas e aprovadas (ou emendadas) explicitamente.
2. Cada PD-xx com resposta, adiamento consciente ou dono/data.
3. Reconciliação canônica planejada: CRs para GAP-CDC-1.3-001/002, 1.4-001/002 e DST-GAP-015; decisão sobre
   CDC-SEC-003 (PD-13).
4. PoC-1, PoC-2, PoC-3, PoC-5 e PoC-6 aprovadas (mínimo) antes de qualquer código de produção de auth.
5. Confirmação de que a RLS/ADR-002 permanece **inalterada** (ou emendas aditivas formalizadas em ADR-002 V1.1).
6. Threat model revisado e testes adversariais definidos.
7. Provedor escolhido com base em PoC e fontes oficiais (não apenas comparativos de terceiros).
8. Plano de LGPD/residência/retenção aprovado (PD-22).

## 30. Fontes consultadas

Repositório (somente leitura): `package.json`, `apps/web/*`, `packages/*`, `packages/core/prisma/schema.prisma`,
`RLS_MATRIX.md`, `SECURITY_CONTEXT_CONTRACT.md`, migrations `…160000`/`…170000`, `docs/SEC-001_*`, `ADR-001` V1.1,
`ADR-002`, `RLS-001`, `COT-001` V1.2, `MCD-001` V1.4, `DST-001` V1.3, `CDC-001` V1.4, `CAF-001`.

Web (consulta em 2026-09-21; itens de terceiros **[T]** a confirmar em PoC/fonte oficial):
- [Auth.js is now part of Better Auth](https://better-auth.com/blog/authjs-joins-better-auth) · [Auth.js security update: July 2026](https://better-auth.com/blog/security-update-july-2026)
- [Neon — Managed Better Auth (docs)](https://neon.com/docs/auth/overview) · [Neon — NextAuth.js × Neon Auth × Better Auth](https://neon.com/guides/nextauth-neon-auth-better-auth-postgres) · [Neon Auth](https://neon.com/auth)
- [Prisma + Better Auth + Next.js (docs)](https://www.prisma.io/docs/guides/authentication/better-auth/nextjs)
- [Clerk — Multi-tenancy](https://clerk.com/multi-tenancy) · [Clerk — Organizations](https://clerk.com/organizations)
- [T] [LogRocket — auth libraries Next.js 2026](https://blog.logrocket.com/best-auth-library-nextjs-2026/) · [Makerkit — Better Auth vs Clerk](https://makerkit.dev/blog/tutorials/better-auth-vs-clerk) · [BuildMVPFast — decision tree](https://www.buildmvpfast.com/blog/better-auth-vs-clerk-vs-authjs-nextjs-decision-tree-2026)

---

## 31. Rodada 2 — Fechamento Arquitetural Pré-PoC

**Status desta seção:** DRAFT / NÃO APROVADO (o ADR-003 inteiro permanece DRAFT v0.2). Esta seção **prevalece**
sobre §§9.4, 11.3, 12–14, 26–28 nos pontos em que divergir (cada um desses trechos recebeu uma nota de
remissão). Nada foi implementado: nenhuma dependência, migration, `schema.prisma`, RLS, role, função, policy,
dado, middleware, API ou Neon foi tocado; nenhum documento canônico (COT/MCD/DST/CDC/SEC) foi alterado.

### 31.0 Integridade da rodada

Baseline confirmada antes de qualquer alteração: `HEAD = c6b4861`; único arquivo novo = este ADR
(1.041 linhas, SHA-256 `C0484EBE…54C7DC5`). Sem pull/push/commit/reset. O trabalho da rodada é
exclusivamente documental neste arquivo.

### 31.1 Revisão crítica do DRAFT v0.1 — correções

| # | Ponto do v0.1 | Problema | Correção na Rodada 2 |
|---|---|---|---|
| 1 | G-01/G-02/G-03/G-07 chamados de "achados" com tom de falha | G-01, G-02, G-03 foram **deliberadamente deferidos** (ADR-D028/D029, `SECURITY_CONTEXT_CONTRACT` §2 e §8, matriz RLS item 25). Não são vulnerabilidades da baseline | Reclassificados em §31.2 (A–F) |
| 2 | §26 sugeria a prova de concessão como "compensação" de falha da RLS | O contrato aprovado já atribui ao backend confiável o estabelecimento do contexto; o `withSecurityContext` é a **realização** dessa obrigação, não remendo | §31.4 |
| 3 | DP-04/§14 aceitou "RBAC em código" em razão do CDC-SEC-003 | O CDC é baseline **versionável**; a escolha deve ser por mérito | §31.12 (comparação A/B/C refeita; resultado híbrido com critérios de evolução) |
| 4 | DP-03 fixou Equiparação como "módulo funcional próprio" | Risco de congelar fronteira técnica por conveniência comercial | §31.10 (unidade técnica = capability; módulo = agrupamento; produto = fonte de concessão) |
| 5 | PD-09 (Next 14) tratado como incompatibilidade provável | Fontes oficiais mostram **EOL**, não incompatibilidade objetiva | §31.9.3 |
| 6 | Tabela de provedores misturava blogs de terceiros | Exigência de documentação oficial atual | §31.9 (docs oficiais; item não declarado = "não declarado") |
| 7 | Clerk: "MFA/passkeys podem ser add-on" | Impreciso | Página oficial de preços: **MFA e passkeys não estão no plano Free; estão no Pro**; roles customizados exigem add-on pago |
| 8 | Um único role para "administração" difuso | G-07 não estava fechado | §31.6 (três planos, roles e GRANTs) |
| 9 | Auditoria: três opções sem decisão | G-01 aberto | §31.3 (decisão: função `SECURITY DEFINER` + escrita do plano de controle; tabela permanece selada) |
| 10 | 8 PoCs independentes | Sobreposição | §31.19 (4 gates) |

### 31.2 Reclassificação dos gaps

Legenda: **A** gap real · **B** decisão deliberadamente deferida · **C** consequência arquitetural esperada ·
**D** risco operacional · **E** vulnerabilidade · **F** necessidade da nova etapa.

| ID | Gap | Classe(s) | Justificativa | Tratamento |
|---|---|---|---|---|
| **G-01** | `EventoAuditoriaSeguranca` sem policy/gravação | **B + F** | Deliberado (ADR-D029; matriz RLS item 25 "BLOQUEADO — SEM CAMPOS PARA POLICY"; `GAP-CDC-1.3-002`). Torna-se necessidade agora porque SEC-001 §16 exige auditoria de segurança. **Não é vulnerabilidade** | §31.3 |
| **G-02** | Demais tabelas confiam em `app.current_tenant_id` | **C (+ D)** | Contrato aprovado: "quem popula: camada de aplicação/middleware de transação" (`SECURITY_CONTEXT_CONTRACT` §8; ADR-D028). Risco operacional apenas se a camada de contexto tiver defeito | §31.4 — **sem alteração de RLS** |
| **G-03** | Restrição por UE não aplicada pela RLS | **B + F** | UE deferida (`SECURITY_CONTEXT_CONTRACT` §2: variável reservada, sem uso). UE é *restrição de escopo*, não fronteira de isolamento | §31.5 |
| **G-04** | `Tenant`/`ContaAcesso` sem `status`/`tipo` | **A + F** | Lacuna real (GAP-CDC-1.3-001, 1.4-002) que bloqueia G2/G4 | CR canônico futuro (§31.18, PD-05) |
| **G-05** | Concessões sem vigência | **B + F** | GAP-CDC-1.4-001 deferido; necessário para acessos internos/break-glass | §31.13, PD-02 |
| **G-06** | `papel` aberto / CDC-SEC-003 | **B + F** | DST-GAP-015 deferido; necessário para RBAC | §31.12 |
| **G-07** | `conta_acesso_tenant` legível/escrevível pelo runtime com contexto | **C + A** | Consequência do desenho (RLS isola *tenants*, não *privilégios internos*). Falta a separação de planos por privilégio SQL | §31.6 |
| **G-08** | `conta_acesso` permissiva | **C + D** | Categoria `GLOBAL_COMPARTILHADO` deliberada | GRANT por plano (§31.6) |
| **G-09** | `contifisc_app` etc. inexistentes | **F** | Escopo desta etapa | §31.14 |
| **G-10** | Sem camada de dados / PrismaClient | **F** | Escopo desta etapa | §31.15 |
| **G-11** | Next 14.2.35 | **A (EOL) + D** | Política oficial: EOL | §31.9.3 |
| **G-12** | CI dispara em `main`, branch é `master` | **D** | Operacional | Corrigir à parte |
| **G-13** | `autocrlf=true` sem `.gitattributes` | **D** | Já recomendado no relatório RLS | Corrigir à parte |
| **G-14** | Sem `DATABASE_URL_POOLED` nem segredos por role | **F** | Escopo desta etapa | §31.14 |
| **G-15** | Sem política de retenção/LGPD para identidade/auditoria | **A** | Lacuna real | PD-22 (Classe C com salvaguardas) |
| **G-16** | `neon_auth` clonado em branches | **D** (condicional) | Só se Neon Auth for adotado; confirmado pela doc oficial | §31.9 |

Nenhum gap foi classificado **E (vulnerabilidade)**. `CRITICAL = 0`.

### 31.3 G-01 — Caminho seguro de gravação da auditoria

**Requisitos**: append-only; nenhum UPDATE/DELETE por ninguém do runtime; campos de **autoria, tenant, papel de
origem e instante definidos pelo servidor/banco** (não pelo chamador); não conceder `INSERT` genérico; mesmo
caminho para os três planos; evento de negação deve sobreviver ao rollback da operação de negócio.

| Critério | A. `INSERT` direto + policy | B. Função `SECURITY DEFINER` | C. Serviço/canal administrativo | **D. Combinação (recomendada)** |
|---|---|---|---|---|
| Spoofing de conta | Policy `WITH CHECK conta = GUC` mitiga | Função **lê a conta do GUC** (parâmetro inexistente) — não spoofável pelo chamador | Depende do canal | B |
| Spoofing de tenant | idem via `WITH CHECK` | idem (GUC) | idem | B |
| Adulteração do evento | Runtime controla todas as colunas permitidas (precisa trigger para carimbar) | Função **carimba** `id`, instante (`clock_timestamp()`), autoria, `origem_plano` (derivada de `current_user`) | Depende | B |
| Campos "do servidor" | Exige trigger `BEFORE INSERT` + GRANT por coluna | Nativo: parâmetros mínimos (`tipo`, `resultado`, `objeto`, `detalhe`) | Nativo | B |
| Timestamps | Trigger | `clock_timestamp()` no banco | Serviço | B |
| Append-only | REVOKE UPDATE/DELETE + trigger | Tabela **sem nenhum GRANT** ao runtime: só `EXECUTE` da função | Serviço único escritor | B |
| UPDATE/DELETE | Bloqueados por GRANT | Inexistentes para o runtime | Idem | B |
| Privilégios necessários ao runtime | `INSERT` na tabela (superfície maior) | **Somente `EXECUTE`** | Nenhum no DB | B |
| Ownership/RLS | Exige **nova policy** em tabela hoje "selada" (muda a RLS) | Tabela permanece **RLS sem policy** (zero mudança de RLS); função pertence a role `NOLOGIN BYPASSRLS` dedicado | Nenhuma mudança | B / C |
| Auditabilidade | Boa | Boa; função versionada em migration | Boa, mas mais infra | — |
| Uso pelo runtime | Sim | Sim | Indireto (fila/outbox) | B |
| Uso pelo plano de controle | Sim (BYPASSRLS) | Sim (mesma função, com contexto do operador) | Sim | B |
| Atomicidade com a operação | Sim (mesma transação) | Sim (mesma transação) | Não (assíncrono) | B para sucesso sensível |
| Sobrevive ao rollback (negações) | Só em tx própria | Só em tx própria | Sim | B em transação curta separada |
| Complexidade/risco | Média; altera RLS | Baixa/média; padrão já aprovado (ADR-D031/D032) | Alta (infra nova) | Média |

**Decisão proposta (DP-12 — Classe A):**

1. **Uma única via de escrita para todos os planos**: função `SECURITY DEFINER` mínima
   (`registrar_evento_seguranca`), `EXECUTE` apenas aos roles de aplicação/administração/controle/auth;
   **`REVOKE ALL` da tabela** para todos eles. **Nenhuma policy nova** e nenhuma mudança na RLS existente —
   a tabela permanece "RLS ligada, zero policies".
2. **Owner da função = role dedicado `contifisc_audit_writer`** (`NOLOGIN`, `BYPASSRLS`, só `INSERT` na tabela),
   **não** o mediator (ADR-D031 restringe o mediator a 2 funções de leitura; estendê-lo violaria seu privilégio mínimo).
   Registro formal exige **ADR-002 V1.1 aditivo** (nova decisão física), não reabertura.
3. **Campos carimbados no banco**: `id`, instante (`clock_timestamp()`), `conta_acesso_id` (lido do GUC
   `app.current_conta_acesso_id`; nulo apenas para eventos pré-autenticação da lista fechada), `tenant_id` (lido do GUC;
   nulo para eventos sem tenant), `origem_plano` (derivado do `current_user`: DATA/ACESSO/CONTROLE/AUTH).
   O chamador informa só `tipo` (lista fechada validada na função), `resultado`, `objeto_tipo/objeto_id`,
   `motivo`, `request_id` e `detalhe` (JSON com **allowlist de chaves por tipo** e limite de tamanho — nunca segredos).
4. **Imutabilidade defensiva**: sem GRANT de UPDATE/DELETE/TRUNCATE ao runtime; trigger `BEFORE UPDATE OR DELETE`
   que sempre falha (cinto-e-suspensório contra o owner acidental). Contra o owner malicioso: **encadeamento de
   hash** por linha (tamper-evidence) — Classe B (evidência no Gate D); exportação para armazenamento WORM — Classe C.
5. **Semântica transacional**:
   - Operação sensível **permitida** → evento gravado **na mesma transação** ⇒ falha de auditoria **aborta** a operação (fail-closed).
   - **Negação** (portão G1–G7) e eventos de login/logout → gravados em **transação curta própria** (sobrevivem ao rollback).
     Se a gravação de uma negação falhar: a negação **permanece** (deny continua deny), erro vai ao log técnico com alerta — a auditoria
     não pode virar vetor de DoS nem de bypass.
6. **Leitura**: V1 restrita ao plano de controle/oficiais de segurança (relatórios). Visibilidade por tenant e
   transparência de acessos internos = Classe C (PD-20).
7. **Escritor por canal (C) não é necessário na V1** (adiciona infra). Reavaliar se surgir requisito de imutabilidade
   externa forte.

**Dependência canônica**: os campos exigem CR (`GAP-CDC-1.3-002`) — ver §31.18/PD-19. A decisão de *caminho* é
independente da lista final de campos.

### 31.4 G-02 — `app.current_tenant_id` e suficiência do `withSecurityContext`

**Pergunta:** `withSecurityContext` + validação `ContaAcesso→ContaAcessoTenant→Tenant` + `SET LOCAL` + `FORCE RLS` é
suficiente?

**Conclusão: sim, para o modelo de ameaça aprovado (backend confiável), e nenhuma alteração de RLS é necessária.**

Fundamentos:

- `FORCE RLS` + `SET LOCAL` já garantem **fail-closed** e ausência de resíduo entre transações (S04/S05/S12/S13/S17).
- O contrato aprovado delega ao backend a obrigação de estabelecer o contexto **a partir do resultado de
  autenticação e da concessão verificada**; `withSecurityContext` é a implementação central dessa obrigação.
- **Membership check dentro de todas as policies foi analisado e rejeitado** (não é necessidade demonstrada):
  1. *Recursão/acoplamento*: policies que consultam tabelas com RLS repetem os achados C1/C2 (recursão; reacoplamento de contexto);
  2. *Mediador*: exigiria estender funções `SECURITY DEFINER` a mais 22 tabelas, ampliando a superfície privilegiada (ADR-D032 limitou-a a 2 tabelas de propósito);
  3. *Desempenho*: uma chamada de função por linha/consulta em todas as tabelas;
  4. *Manutenção*: 25 policies a manter e revalidar; risco de regressão da baseline já validada.
  Além disso **não fecharia a lacuna que resta** (servidor comprometido forjando a conta) — o GUC da conta continuaria sendo afirmado pelo backend.
- **Ordem exata exigida pela RLS atual** (consequência direta das policies existentes):
  1. `conta` (GUC) → 2. **sonda `tenant`** (a policy de `tenant` só usa a conta; a RLS entrega apenas tenants concedidos) →
  3. `tenant` (GUC) → 4. **só então** ler `conta_acesso_tenant` (papel, vigência, origem) e as restrições de UE — porque a policy de
  `conta_acesso_tenant` é `tenant_id = contexto` (com apenas a conta setada a leitura devolve 0 linhas).
  Ou seja: a "validação prévia ContaAcesso→ContaAcessoTenant→Tenant" **não pode ser feita antes do contexto** sem um
  caminho privilegiado; feita por esta ordem, a sonda de `tenant` **é** a verificação de concessão feita pelo banco, sem privilégio extra.
- A sonda **prova a existência** da concessão, **não a vigência** nem o estado — vigência/estado/papel são verificados
  no passo 4 e no PDP (G3/G4). Um par (concessão expirada e ainda presente na tabela) passaria a sonda; por isso a
  vigência é avaliada pela aplicação **e** há varredor de expiração (§31.13). Se a PoC (Gate B/C) mostrar necessidade real,
  a única alteração de RLS a considerar é **aditiva e mínima**: incluir `vigencia_fim` na função `contifisc_conta_tem_acesso_tenant`
  (nova migration + revalidação). **Default: não alterar.**
- **Risco residual aceito**: servidor de aplicação comprometido pode afirmar qualquer conta (§7). Mitigações: segregação de credenciais por plano, menor
  privilégio, auditoria, detecção. **Endurecimento avaliado e diferido (Classe C):** "context binding" (o backend assina o contexto e o
  banco verifica) protegeria contra *injeção de SQL que consiga executar `set_config`*, custo e complexidade altos frente ao risco (queries
  parametrizadas, sem SQL dinâmico; `set_config` só no helper).

**Classificação final de G-02:** consequência arquitetural esperada (C) com risco operacional mitigado por API central (D). Sem mudança de RLS.

### 31.5 G-03 — Unidade Econômica na autorização V1

**Fato estrutural que decide a questão:** as tabelas tenant-scoped **não são uniformemente UE-escopadas**. Os 6
hospedeiros de `MCD-F10004` têm UE; `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica` têm **só tenant** (uma evidência
pode cobrir várias UEs — SEC-001 §5/§6); `Vinculo`/`VinculoExtremidade` derivam de extremidades. Logo **a UE não pode ser uma
fronteira absoluta de isolamento**: é uma **restrição de escopo** aplicável aos fatos com contexto de UE.

| Critério | A. Só aplicação | B. RLS | C. Híbrido |
|---|---|---|---|
| Semântica "conjunto permitido" (ADR: existindo ≥1 restrição, só as UEs listadas) | Natural (lista) | `app.current_unidade_economica_id` modela **uma UE ativa**, não um **conjunto**; conjunto exigiria consultar `conta_acesso_unidade_economica` (tabela com RLS) ⇒ **novo mediador `SECURITY DEFINER` + mudança em ≥6 policies** | Idem B para o piso |
| Cobertura das tabelas sem UE (arquivos/conflitos/revisões) | Decisão explícita por permissão | **Impossível** filtrar por UE | Idem |
| Reabre a RLS validada? | Não | **Sim** (nova PoC RLS completa) | Sim, parcialmente |
| Risco de regressão | Baixo | Alto | Médio |
| Robustez contra bug de app | Depende de repositório/testes | Piso do banco | Piso do banco |
| Custo | Baixo | Alto | Médio/alto |

**Decisão proposta (DP-13 — Classe A): V1 = A (aplicação), com aplicação estrutural — evolução futura = C.**

- Escopo de UE calculado no `withSecurityContext` (passo 4) e entregue ao callback como parte do `TenantScopedTx` (`ueScope`:
  `TODAS` ou lista). **Repositórios das 6 tabelas com UE só aceitam consulta via helper que injeta `unidade_economica_id IN (ueScope)`**
  (impossível omitir pelo tipo). Teste arquitetural e testes de contrato por repositório (Gate C).
- **Objetos sem UE unívoca** (arquivos de origem, conflitos, revisões): conta **com** restrição de UE **não** os acessa por padrão
  (negar por padrão — P2), até que cada módulo defina, por permissão explícita, uma regra segura (ex.: só itens ligados a UEs do escopo).
- **Invariantes preservadas**: UE só **restringe**; nunca amplia G3, nunca substitui `ContaAcessoTenant`, nunca substitui a RLS de tenant;
  **ADR-C014 intacto** (triggers continuam garantindo restrição ⇒ concessão de tenant).
- **Evolução (C, Classe C, gatilhos)**: introduzir, via ADR-002 V1.1 aditivo, **políticas `RESTRICTIVE`** usando
  `app.current_unidade_economica_id` como *piso adicional* nos fatos mais sensíveis, **quando** (i) existirem clientes reais com contas
  restritas por UE **e** (ii) testes do Gate C/D demonstrarem falha ou risco não coberto pela camada de aplicação. Até lá, a variável
  permanece **reservada**.

### 31.6 G-07 — Planos: DATA, ACCESS ADMINISTRATION e CONTROL

**Princípio:** RLS isola **tenants**; **privilégios SQL (GRANT)** separam **capacidades**. O runtime de dados **não** pode conceder acesso
a si nem a terceiros. Três planos, três credenciais.

| Plano | Função | Role (proposto) | Atributos | O que pode escrever |
|---|---|---|---|---|
| **DATA** | operação dos módulos sobre dados de negócio | `contifisc_app` | LOGIN, NOSUPERUSER, **NOBYPASSRLS**, não-owner, POOLED | DML nas tabelas de negócio; **SELECT** em estruturas de acesso/entitlement; `EXECUTE` das funções SD e da auditoria; **nada** em `conta_acesso*`/entitlement |
| **ACCESS ADMINISTRATION** | usuários, papéis, restrições de UE **dentro do tenant ativo**; convites; vínculo de identidade | `contifisc_access_admin` | LOGIN, NOSUPERUSER, **NOBYPASSRLS** (sujeito à RLS do tenant), POOLED | DML **só** em `conta_acesso_tenant`, `conta_acesso_unidade_economica` (+ `conta` e vínculo de identidade no fluxo de convite); `EXECUTE` auditoria |
| **CONTROL** | provisionamento de Tenant/1ª concessão, entitlements, concessões internas/break-glass, suspensão de conta/tenant | `contifisc_control` | LOGIN, NOSUPERUSER, **BYPASSRLS**, rota/processo/rede separados, MFA forte | Tudo do controle; **não** lê dados de negócio por padrão |
| AUTH (armazenamento do provedor) | tabelas do provedor de identidade | `contifisc_auth` | LOGIN, NOBYPASSRLS, sem acesso a `public` | schema próprio |
| Auditoria (owner da função) | `registrar_evento_seguranca` | `contifisc_audit_writer` | **NOLOGIN**, BYPASSRLS, só INSERT | — |
| Migração | DDL | `contifisc_migration` (hoje `neondb_owner`) | owner; **DIRECT**; só CI/ops | DDL |
| Mediador RLS | funções SD do ADR-002 | `contifisc_rls_mediator` (existente) | NOLOGIN, BYPASSRLS | — |

**Matriz de privilégios de tabela (proposta):**

| Tabela | `contifisc_app` | `contifisc_access_admin` | `contifisc_control` |
|---|---|---|---|
| tabelas de negócio (23) | DML | — | — |
| `tenant` | SELECT | SELECT | ALL |
| `conta_acesso` | SELECT | INSERT, UPDATE(status) | ALL |
| `conta_acesso_tenant` | SELECT | INSERT, UPDATE(papel/vigência), DELETE | ALL |
| `conta_acesso_unidade_economica` | SELECT | INSERT, DELETE | ALL |
| concessões de entitlement / ledger | SELECT (tenant) | — | ALL |
| identidade externa / sessões (schema auth) | — | INSERT/UPDATE vínculo | leitura |
| `evento_auditoria_seguranca` | **nenhum** (só função) | **nenhum** (só função) | **nenhum** (só função) |

**Guardrails adicionais:**

- **Teto de delegação** no PDP (§14.6): concessão ≤ permissões do concedente, apenas no tenant ativo; RLS `WITH CHECK tenant_id = contexto` já impede
  concessões em **outro** tenant.
- **Papéis internos (`interno.*`) só via controle**: proposta de *trigger* aditivo em `conta_acesso_tenant` que rejeita `papel` de namespace interno
  quando `current_user` ≠ `contifisc_control` (defesa do banco contra escalonamento por rota de administração de tenant) — Classe B (Gate B/C).
- Toda operação de administração exige `admin.*` no PDP, `aal` elevado/step-up e auditoria antes/depois.
- **O que cada plano administra:** *usuários/convites/UE/papéis dentro do tenant* → ACCESS; *Tenant (criar/suspender), entitlements, catálogo materializado,
  concessões internas, break-glass* → CONTROL; *dados* → DATA. **Entitlements nunca** são gravados por DATA nem por ACCESS.
- Requer **nova migration de GRANT/REVOKE** (ADR-004) — fora desta rodada; não altera policies.

### 31.7 `IdentidadeAcessoExterna` — decisão de identidade

**Decisão (DP-01 revisada — Classe A).** Estrutura conceitual **`IdentidadeAcessoExterna`**:

| Campo | Semântica |
|---|---|
| `id` | identificador próprio (UUID) |
| `provedor` | chave controlada da fonte de identidade (ex.: `better_auth`, `clerk`, `neon_auth`) |
| `emissor` | instância/ambiente do provedor (issuer/projeto) — evita colisão entre ambientes/instâncias |
| `subject_externo` | id estável e **opaco** do usuário no provedor (nunca normalizado, nunca e-mail) |
| `conta_acesso_id` | FK para `ContaAcesso` |
| `estado` | `PENDENTE` (criada por convite, sem 1º login) → `ATIVA` ↔ `SUSPENSA` → `REVOGADA` (terminal) |
| `criado_em`, `atualizado_em`, `revogada_em`, `motivo_revogacao` | carimbos/rastro |
| metadata mínima | `metodo_verificacao_vinculo` (convite/admin/migracao); **sem** e-mail, nome, telefone (minimização LGPD) |

- **Unicidade**: `UNIQUE(provedor, emissor, subject_externo)`. Vários vínculos `ATIVA` por `ContaAcesso` são permitidos (duas fontes de login,
  migração de provedor). Um vínculo `REVOGADA` **nunca** é reatribuído a outra conta.
- **O vínculo é com o *usuário do provedor* (sujeito da sessão)**, não com cada método de login. Login por senha, OAuth ou passkey do mesmo usuário
  do provedor resolvem no **mesmo** `subject`; account linking *interno* ao provedor não cria nova identidade CONTIFISC.
- **Múltiplos provedores**: cada fonte tem seu vínculo; ambos resolvem para a mesma `ContaAcesso`.
- **Account linking / adicionar identidade**: só usuário já autenticado + *step-up* + verificação do novo fator/convite; **nunca** por igualdade de e-mail.
- **Mudança de e-mail no provedor**: sem efeito no vínculo nem na conta.
- **Duplicidade**: barrada pela unicidade; fusão de contas = operação de CONTROLE, auditada, manual.
- **Revogação**: revoga o vínculo **e** as sessões no provedor; conta e histórico permanecem.
- **Recuperação**: nova identidade do mesmo humano exige **novo vínculo** por convite/verificação administrativa (identity proofing), com o antigo revogado.
- **Identidade órfã** (autenticou no provedor, sem vínculo `ATIVA`): **sem acesso**, sem criação automática de conta; evento `LOGIN_SEM_CONTA`.
- **Exclusão do usuário no provedor**: vínculo fica sem sujeito possível → rotina de reconciliação marca `SUSPENSA/REVOGADA` e alerta; a `ContaAcesso` é preservada (auditoria).
- **Troca futura de provedor**: novo vínculo por processo verificado (lista de migração mapeada por administrador ou reconvite); **e-mail não é ponte automática**; janela de coexistência (dois vínculos `ATIVA`) e depois revogação do antigo.
- **Onde vive**: schema de identidade (`contifisc_auth`, Classe B/PD-07), **fora** de `public` — não estende a matriz RLS de 25 tabelas nesta etapa.

**Classificação: SEGURANÇA** (domínio SEC; registro **canônico de segurança** — vínculo autoritativo e durável, referenciado por auditoria e administração —, não dado
tributário). Não é OPERACIONAL: o registro de usuário/credencial/sessão *do provedor* é o operacional; este vínculo sobrevive à troca de provedor. Não é SUPORTE
(não é mera associação N:N de apoio a fatos). Requer objeto novo no COT (SEC), campos MCD, contrato CDC e termos/estados DST em versão futura; **substitui na prática** o papel de
`CredencialAcesso` (COT-OBJ-018) enquanto a autenticação for delegada.

### 31.8 Tenant — autoridade e conceitos de Organization/Team/Workspace

**Reafirmado (sem correção):** `Tenant` = **boundary técnica de isolamento** (SEC-001 §1); não é cliente, organização, empresa, UE nem assinatura
comercial. **Autoridade final** sobre "quem acessa qual tenant" = `ContaAcessoTenant` (+ estado do `Tenant`) verificada pelo backend e provada pela RLS.
O navegador solicita; o servidor decide.

**Organization/Workspace/Team do provedor** (Better Auth `organization`, Clerk *Organizations*, equivalentes): **Decisão (DP-14 — Classe A): não utilizar na V1 (opção A).**

| Opção | Avaliação |
|---|---|
| **A. Não usar** | Fonte única da verdade; sem dependência do modelo do provedor; sem tabelas/planos extras. Better Auth: plugin `organization` é opcional e "pode ser desabilitado sem efeitos colaterais"; Clerk: Organizations é recurso habilitável, e **custom roles exigem add-on pago** |
| B. Só conveniência de UI | Aceitável **no futuro**, se for meramente apresentação (rótulo/seletor) sem entrar em nenhuma decisão de autorização |
| C. Espelhar | Cria duas fontes de verdade e problemas de sincronização; adiar |
| D. Integrar como autoridade | **Rejeitado** — substituiria silenciosamente `ContaAcessoTenant`; prende o modelo ao provedor (Clerk: "organização ativa" por aba/token) |

Regra: **nenhum identificador de organização/workspace do provedor pode aparecer como entrada do PDP**; o `tenant_ativo` é estado
server-side da sessão CONTIFISC, validado por `withSecurityContext`. A adoção futura de B/C exige ADR próprio.

### 31.9 Provedores de autenticação — revisão com documentação oficial (2026-09-21)

Todas as afirmações abaixo vêm de **documentação/páginas oficiais** (lista em §31.21). Item não documentado = **"não declarado"** (não presumido).

#### 31.9.1 Comparação

| Critério | A. Better Auth self-hosted | B. Neon Managed Better Auth (Neon Auth) | C. Clerk | D. Auth.js |
|---|---|---|---|---|
| Situação | Ativo; Auth.js passou à sua tutela | **GA**; sobre Better Auth **1.4.18** (versão fixada); o "Neon Auth" legado (Stack Auth) não aceita novos usuários | SaaS | Modo somente-segurança desde set/2025 (equipe Better Auth); avisos de segurança em jul/2026 |
| Next.js | Docs citam Next **13–15.1** (middleware Edge), **15.2+** (runtime Node), **16** (`proxy.ts`); sem versão mínima declarada | Exige App Router; recomenda **Next 16** (`proxy.ts`); versões anteriores usam `middleware.ts` | Docs citam Next 16 (`proxy.ts`) e "15 e anteriores" (`middleware.ts`); sem versão mínima declarada | Suporta Next |
| Sessão server-side | Sessão no banco; `auth.api.getSession`; **cookie cache pode manter sessão revogada até `maxAge`** (mitigar: desligar/`maxAge` curto/`disableCookieCache`); `freshAge` p/ ações sensíveis; revogação (uma/outras/todas) | Sessões em `neon_auth` (consultáveis por SQL); `auth.getSession()` | Token de sessão do vendor | JWT ou banco |
| MFA | Plugin 2FA: TOTP, OTP (e-mail/SMS), backup codes; **OAuth/passkey/magic link não passam pelo desafio 2FA por padrão** | **Não declarado** | **Só no Pro (não no Free)** | Não nativo |
| Passkeys | Pacote `@better-auth/passkey` (WebAuthn/SimpleWebAuthn) | **Não declarado** | **Só no Pro** | Não nativo |
| OAuth / e-mail | Sim (plugins) | E-mail/senha + OAuth (Google "pronto"); mais provedores configuráveis | Sim | Amplo |
| `subject` estável | id do usuário (sua tabela) | id em `neon_auth` | id do vendor | id do adapter/`sub` |
| Prisma 6 | `@better-auth/prisma-adapter`; Prisma ≤6 não exige driver adapter; CLI **gera** schema, **migração é do Prisma**; schema não-`public`: **não mencionado** | Guia oficial **não menciona ORM** | n/a (dados no vendor) | Adapter |
| POOLED/DIRECT (Neon) | Sua conexão (você escolhe); recomendável POOLED para runtime, DIRECT p/ migração | Dados no seu Neon; auth opera via SDK/`NEON_AUTH_BASE_URL` | n/a | Qualquer PG |
| Extensibilidade / plugins | Ampla (plugins próprios, hooks) | "Plugins suportados; mais serão adicionados" — **hooks no gerenciado: não claro** | Configuração do vendor | DIY |
| Branches / preview | Suas tabelas (sem conceito de branch) | **Cada branch tem ambiente de auth isolado, mas usuários/sessões/config são CLONADOS na criação**; sem controle de anonimização documentado; sessões não migram entre branches | n/a | n/a |
| Dados de identidade | Seu banco (região do seu PG; hoje AWS us-east-2) | Seu Neon (AWS); **sem IP Allow/Private Networking; só AWS** | No vendor (residência não avaliada nesta rodada) | Seu banco |
| Lock-in / migração | Baixo; porta própria | **Alto ao Neon**; sem export declarado (só "eject" do legado p/ Stack Auth) | **Alto** (usuários no vendor; portabilidade não declarada na página consultada) | Baixo |
| Organizations/Teams | Plugin **opcional**, desabilitável sem efeitos | Organizações: detalhamento não claro | Organizations (básico no Free/Pro); **roles customizados = add-on** | DIY |
| Custo | Licença zero; custo operacional (patching, backups, sessões) | Free 60 mil MAU; Launch/Scale 1 M MAU | Free 50 mil MRU; Pro $25/mês + $0,02/MRU; add-ons ($100/mês B2B Enhanced; SSO por conexão) | Zero |
| Operação | Você opera | Neon opera | Vendor opera | Você opera |

#### 31.9.2 Classificação (sem escolher vencedor definitivo — depende de PoC)

| Opção | Classe | Justificativa técnica |
|---|---|---|
| **A. Better Auth self-hosted** | **FINALISTA** | Dados no nosso banco, Prisma 6 suportado, plugins de MFA/passkeys documentados, sessão com revogação, organização opcional/desabilitável, baixo lock-in. Riscos a provar: `aal` (OAuth/passkey ≠ 2FA por padrão), cookie cache × revogação, schema em `contifisc_auth`, Next alvo |
| **C. Clerk** | **FINALISTA** (referência gerenciada) | Maturidade, MFA/passkeys (Pro), sem operação de auth. Riscos: lock-in e residência de dados de usuário, custo por MRU, Organizations tentam ocupar o lugar do Tenant (será **desabilitado**), roles customizados pagos (não usaremos). Serve para provar que a **porta `IdentityProvider`** realmente é agnóstica |
| **B. Neon Managed Better Auth** | **VIÁVEL (não finalista até evidência)** | Simplicidade e RLS/JWT compatíveis, mas **MFA e passkeys "não declarados"** — requisito **obrigatório** (PD-03) —, versão do Better Auth fixada, sem story de ORM, branches clonam usuários/sessões (risco de PII em DEV), só AWS, sem IP Allow, lock-in ao Neon. **Promove-se a finalista** se, **antes do Gate A**, houver evidência oficial (documentação/suporte) de MFA + passkeys + hooks |
| **D. Auth.js** | **ELIMINADA** para adoção nova | Modo somente-segurança; correções de segurança recentes; a própria orientação aponta ao Better Auth. Mantida só como referência histórica |

#### 31.9.3 Next.js 14 — bloqueador?

| Dimensão | Fato | Conclusão |
|---|---|---|
| **Incompatibilidade objetiva** | Better Auth documenta middleware Edge para Next 13–15.1 (checagem apenas de cookie) e Node 15.2+; Clerk documenta `middleware.ts` para "15 e anteriores"; Neon documenta `middleware.ts` em versões anteriores à 16. **Nenhuma doc consultada declara Next 14 incompatível** | **Não há incompatibilidade objetiva demonstrada** |
| **Recomendação do fornecedor** | Neon recomenda Next 16; Better Auth orienta validação completa de sessão em `proxy.ts` (16) ou runtime Node (15.2+); em Next mais antigo só checagem de **existência** de cookie (não valida) | Melhor prática exige ≥15.2/16 para validação em borda; nosso PEP na camada de rota/serviço **não depende disso** |
| **Fim de suporte** | Política oficial do Next.js: **14.x = End-of-Life**; 15.x = Maintenance LTS (~2 anos desde 21/10/2024, ou seja, até ~out/2026); **16.x = Active LTS** | **EOL é fato**, não opinião |
| **Risco de segurança** | Framework EOL não recebe correções; a plataforma manipula dados fiscais/saúde e segurança de acesso | **Inaceitável para produção com autenticação** |
| **Conveniência** | Node runtime/`proxy.ts`, APIs mais novas, docs alinhadas | Secundária |

**Decisão (DP-15 — Classe A):** (1) o upgrade **não é necessário para o desenho nem para executar as PoCs** — os gates rodam em **workspace descartável**
(não no `apps/web` do repositório) já na **versão-alvo** (Next 16; Next 15.5 como fallback), com uma verificação rápida adicional em 14.2.35 para registrar
compatibilidade; (2) **o upgrade é pré-requisito para qualquer autenticação em produção**, por EOL — tarefa **separada e controlada** (fora do escopo do ADR-003),
recomendando **Next 16** (Next 15 sai de Maintenance LTS em ~1 mês, na data da política); (3) a compatibilidade React (o repositório usa **React 18.3.1**; a exigência de
React 19 para o Next-alvo **deve ser verificada** na doc oficial da versão escolhida) e Tailwind/UI entram nessa tarefa. **Não foi feito upgrade.**

### 31.10 Produto × Módulo × Feature × Skill; Equiparação Hospitalar

**Quatro conceitos (formalizados):**

| Conceito | Definição | Unidade de que decisão? |
|---|---|---|
| **Produto comercial** | O que pode ser vendido/contratado (avulso ou bundle). Uma **fonte de concessões** | Comercial: origem de grants |
| **Módulo funcional** | Agrupamento funcional/navegação da aplicação (apresentação e organização) | **Não** é unidade de entitlement nem de autorização |
| **Feature/Capability** | Capacidade individual habilitável; carrega chave estável (ex.: `equiparacao.classificar`) | **Unidade de entitlement** e âncora de permissões |
| **Skill/Motor** | Lógica especializada de cálculo/inteligência, versionada (`engine_id`, `engine_version`, `rule_set` já existem em `ResultadoCalculo`) | Dependência **técnica**, não comercial |

**Relações (regras):**

- Um **produto** habilita capabilities de **módulos diferentes**; um **módulo** agrupa capabilities de **produtos diferentes**.
- Uma **capability** pode depender de **motores compartilhados** (`motores[]`) — dependência técnica, **sem** exigir entitlement de outro produto/módulo.
- Uma **Skill/motor** pode atender **várias** capabilities/produtos; **não** é entitlement isolado (é habilitada pela capability que a aciona).
- Dependências de **entitlement** entre capabilities (`requer[]`) são **exceção** (pré-requisito funcional real), nunca "porque usa o mesmo motor".

**Equiparação Hospitalar — revisão (sem congelar "módulo técnico"):**

| Aspecto | Conclusão |
|---|---|
| Produto comercial autônomo | **Sim** — pode ser vendido sozinho (exemplo Cliente A) |
| Representação técnica | **Conjunto de capabilities** com namespace próprio (`equiparacao.*`): p.ex. classificar, simular economia, diagnosticar conformidade, revisar. A existência de objeto canônico próprio (`ClassificacaoEquiparacaoHospitalar`) e de status EqHop no DST sustenta o namespace |
| Módulo funcional | **Decisão de apresentação/UX adiada (Classe C)**: pode virar módulo próprio ou ficar agrupada com tributário PJ na navegação **sem afetar** entitlement/permissão, pois estes ancoram em capability |
| Motores compartilhados | Consome o **motor tributário** (presunções, apuração) por dependência técnica; **não** exige Tributário PJ habilitado; **sem duplicação** do motor |
| Cliente sem Tributário PJ | Usa Equiparação; motores rodam sobre o canônico do tenant |

**DP-03 (revisada, Classe A):** unidade técnica de entitlement = **capability**; produto = **fonte** de grants; módulo = agrupamento (Classe C); motor = dependência técnica. A representação de
Equiparação **não** é fixada por conveniência comercial: ela é definida pelas capabilities e pelos motores que realmente usa.

### 31.11 Entitlements — modelo mínimo V1

**Comparação:**

| Opção | Avaliação |
|---|---|
| A. Por módulo | Grosseira demais (features premium, bundles cruzados); acopla a apresentação ao comercial |
| B. Por feature/capability | Precisa e determinística; operar "muitas flags" é oneroso sem agrupamento |
| C. Híbrido módulo+feature | Duas resoluções e regras de precedência; ambíguo |
| **D. Produto → grants de capabilities** | Produto é conveniência comercial que **expande** em grants; a avaliação continua num único nível (capability) |

**Decisão (DP-16 — Classe A): avaliação em nível de capability (B) com concessões originadas por produto (D); módulo apenas agrupa.**

**Modelo mínimo V1 (conceitual; sem tabelas nesta rodada):**

- **Catálogo em código** (versionado, testado): `Capability(chave, módulo_agrupador?, motores[], requer[], tipo{OPERATIVA,CONSULTA})`;
  `Produto(chave, capabilities[])` (V1: sem `Plano` — plano = produto/bundle).
- **Concessões persistidas por tenant** (`TenantEntitlementGrant`): `tenant_id`, `capability`, `efeito{CONCEDE,NEGA}`,
  `origem{PRODUTO,TRIAL,CORTESIA,OVERRIDE,MIGRACAO}`, `origem_ref` (chave do produto/contrato), `vigencia_inicio`, `vigencia_fim`
  (obrigatório em TRIAL/CORTESIA/OVERRIDE), `estado{ATIVO,SUSPENSO,CANCELADO}`, `motivo`, `concedido_por`, timestamps.
- **Ledger append-only** (`EntitlementEvento`) de toda mudança (quem/quando/antes/depois/motivo).
- **Materialização na concessão**: conceder um produto **grava um grant por capability** (atômico, auditado) → a resposta histórica não muda se a definição do produto mudar;
  incluir uma capability nova num produto **não** vaza automaticamente para tenants existentes — exige operação explícita de **propagação** (controle, auditada).

**Regra determinística** `pode_usar(tenant, capability, instante)`: (1) Tenant não `ATIVO` → NEGADO; (2) `NEGA` vigente → NEGADO; (3) `requer[]` não satisfeitas → NEGADO;
(4) `CONCEDE` vigente com `estado ∈ {ATIVO, TRIAL-vigente}` → HABILITADO; (5) default → NEGADO. Relógio do servidor, UTC, instante fixado na requisição; vigência `[início, fim)`.

**Suporte futuro:** módulo individual (conceder as capabilities do módulo); **bundles** (produto com capabilities de módulos distintos); **planos** (produtos); **trial** (`origem=TRIAL`, `fim` obrigatório);
**upgrade/downgrade** (novos grants/cancelamentos + ledger, **sem migração de dados**); **suspensão/cancelamento** (`estado`); **vigência**; **premium** (capability fora do produto base); **concessão temporária** (`fim`);
**override administrativo** (`origem=OVERRIDE`, `fim` obrigatório, aprovador ≠ solicitante, só CONTROL).

**Escrita:** exclusiva do plano CONTROL (§31.6). **Leitura:** DATA/ACCESS por tenant. **Pós-expiração**: V1 bloqueia capabilities `OPERATIVA`; capabilities `CONSULTA` (leitura de resultados já produzidos)
seguem regra comercial definida depois (PD-10, Classe C) — o modelo já a suporta. **Entitlement controla funcionalidade, não o armazenamento do dado canônico (DP-11)**; **sem billing**.

### 31.12 Papéis e permissões — RBAC × ABAC × entitlement × RLS

**Comparação (refeita por mérito; o CDC é versionável):**

| Critério | A. Tudo em código | B. Tudo persistido | **C. Híbrido (recomendado)** |
|---|---|---|---|
| Segurança (superfície de alteração em runtime) | **Melhor**: definições imutáveis em runtime | Pior: papéis editáveis por admin ⇒ vetor de escalonamento | Boa: catálogo/papéis-padrão imutáveis; **atribuições** persistidas |
| Auditabilidade de *mudança de política* | Git/PR + versão do catálogo nos eventos | Ledger em banco | Git/PR (definições) + eventos de atribuição |
| Manutenção/flexibilidade | Mudança exige deploy | Sem deploy; UI de admin | Deploy p/ definições (raro); atribuição sem deploy |
| Multi-tenant / customização por cliente | Sem | Sim | **Adiada** com gatilho explícito |
| Papéis internos × clientes | Namespaces no catálogo | Tabelas + flag | Namespaces no catálogo (`interno.*`, `cliente.*`) |
| Versionamento | Snapshot + `catalogo_versao` | Versionar linhas | Snapshot + `catalogo_versao` |
| Segregação de funções | Predicados no PDP | Predicados no PDP | Predicados no PDP |
| Risco de privilege escalation | Baixo | **Alto** | Baixo |
| Impacto canônico | **Mínimo** (usa `papel` atual) | Alto: novos objetos; **revoga regra do CDC-SEC-003** | **Mínimo na V1**; caminho aberto para B |

**Decisão (DP-04 revisada / PD-13 — Classe A): Híbrido (C).**

- **Catálogo de permissões** e **papéis-padrão** (com composição) em **código** — a existência de uma permissão é indissociável do código que a protege.
  Snapshot test: **falha a build se o conjunto de permissões de um papel mudar sem atualização explícita do snapshot** e revisão de segurança (CODEOWNERS). Mudança semântica de papel ⇒
  **novo identificador de papel**, nunca alteração silenciosa (evita *privilege creep*).
- **Atribuições persistidas**: `ContaAcessoTenant.papel` (e `…UnidadeEconomica.papel`) continuam sendo a **chave** do papel do catálogo — **compatível com o CDC-SEC-003 V1.4 sem novos objetos**; DST-GAP-015 passa a
  "referência controlada ao catálogo de papéis" (não enum). **Papel desconhecido ⇒ nenhuma permissão** (fail-closed).
- **Persistência de definições de papel/permissão (B) fica diferida (Classe C)** com **gatilhos**: (i) cliente exige papéis customizados por tenant; (ii) volume de mudanças de papel/quarter justificar
  UI sem deploy; (iii) necessidade de auditar política por tenant no banco. Ao ativar: CR canônico (COT/MCD/CDC/DST) e revogação formal da regra de CDC-SEC-003.
- **Um papel por concessão** na V1 (`UNIQUE(conta,tenant)`); composição só no catálogo. Múltiplos papéis simultâneos = Classe C.
- **Eventos de decisão registram `catalogo_versao`** (reprodutibilidade).

**Quem decide o quê:**

| Decisão | RBAC (papel→permissão) | ABAC (atributos) | Entitlement | RLS |
|---|---|---|---|---|
| "O tenant pode usar esta capability agora?" | — | — | **Sim** | — |
| "Este papel pode executar esta ação?" | **Sim** | — | — | — |
| "Esta conta pode operar nesta UE?" | — | **Sim** (escopo de UE) | — | (futuro: piso, Classe C) |
| Segregação de funções (quem cria ≠ quem aprova) | — | **Sim** | — | — |
| Nível de autenticação/MFA exigido | — | **Sim** (`aal`) | — | — |
| Interno × cliente; restrições de papel interno | Namespace do papel | **Sim** (tipo de conta, origem) | — | — |
| Estado da conta/concessão/vigência | — | **Sim** (predicados G2/G3) | — | — |
| Estado do objeto/workflow (ex.: revisão já aprovada) | — | **Sim** | — | — |
| Quais **linhas** do tenant são visíveis | — | — | — | **Sim** |
| Concessão de tenant na tabela `tenant` | — | — | — | **Sim** |
| Invariantes estruturais (ADR-C005/C014) | — | — | — | Triggers (banco) |

**ABAC = predicados tipados em código**, registrados **por permissão** (ex.: `exige: [ue_no_escopo, aal>=2, segregacao("aprovar","criar")]`), avaliados no PDP.
**Sem policy engine genérico** na V1 (§19.4 mantido).

### 31.13 Usuários internos e *break-glass*

**Princípio (DP-09 reafirmado):** usuário interno **nunca** recebe acesso universal implícito.

- **Concessão explícita** por tenant (a "carteira"), papel do namespace `interno.*`, **escopo** (tenant e, se necessário, UEs), **vigência** e **MFA (aal2) obrigatório**.
- **Vigência = recertificação**: concessões internas têm `vigencia_fim` (padrão 90 dias, máximo 180); renovar exige **confirmação explícita do responsável da carteira** (nova concessão auditada). Sem renovação ⇒ expira.
- **Requer vigência nas concessões** (resolve `GAP-CDC-1.4-001` por CR canônico futuro): `vigencia_fim` (nulável), `origem` (`REGULAR`, `CONVITE`, `CARTEIRA_INTERNA`, `BREAK_GLASS`), `concedido_por`. **Revogar = `DELETE`** (mantém a regra canônica de imutabilidade); o rastro fica na auditoria.
- **Auditoria** reforçada: evento na **ativação do contexto** em tenant de cliente por conta interna; alertas de volume/horário atípico.
- **Papéis internos só são concedidos pelo plano CONTROL**; internos sem papel de administração **não** administram entitlements.

**Break-glass — mecanismo seguro (conceitual):**

Break-glass **nunca** é `BYPASSRLS`, superuser, owner ou "modo deus". É **uma concessão temporária ordinária** (`origem=BREAK_GLASS`) para um papel **somente leitura** (ex.: `interno.suporte_leitura`), que passa **pela mesma cadeia G1–G9**:

1. **Solicitação** com justificativa e **ticket**; escopo mínimo (tenant/UEs), duração curta (padrão 4 h, máximo 24 h — parâmetros ajustáveis, PD-16 Classe C).
2. **Aprovação por pessoa distinta** (`interno.aprovador_acesso`), com MFA **step-up** recente.
3. **Criação pelo CONTROL** da concessão com `vigencia_fim` (o solicitante **não** consegue criar/estender a si).
4. **Notificação** ao administrador do tenant (política) e evento `ELEVACAO_ABERTA`.
5. **Uso**: sessão `aal2` fresca; **cada** ativação de contexto e leitura sensível gera `ACESSO_INTERNO_A_TENANT` com marca break-glass; RLS e PDP aplicam-se integralmente (é um membro comum do tenant, só que temporário).
6. **Expiração**: PDP nega após `vigencia_fim`; **varredor** do CONTROL apaga concessões vencidas e **alerta** se existir linha vencida por mais de N minutos; `ELEVACAO_ENCERRADA`.
7. **Revisão pós-uso** obrigatória (prazo) por terceiro.

**Risco residual documentado:** a sonda de RLS não considera vigência (§31.4); a linha vencida ainda passaria pela sonda até o varredor removê-la — a aplicação nega (G3), e o varredor+alerta cobre o intervalo.
Se o Gate B/C provar insuficiente, a alteração **mínima e aditiva** da função `contifisc_conta_tem_acesso_tenant` (incluir vigência) fica como opção (nova migration + revalidação).

### 31.14 Runtime real (conceitual; nada criado)

- **`contifisc_app`**: `LOGIN`, `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEROLE/DB`, **não-owner**, **sem membership persistente** no mediator; `USAGE` em `public`; DML nas tabelas de negócio;
  `SELECT` em estruturas de acesso/entitlement; `EXECUTE` nas 2 funções SD (mediador) e na função de auditoria; sujeito a `FORCE RLS`.
- **Endpoints**: runtime (DATA e ACCESS) usa **POOLED** (`-pooler`, `pgbouncer=true`); **DIRECT** só para migrações e manutenção (owner). CONTROL usa POOLED ou DIRECT conforme a operação (sem sessão longa).
- **Prisma**: um único módulo instancia clientes; **um cliente por role** (data, access-admin, control), cada um com sua connection string; nenhum `PrismaClient` exportado; `$transaction` interativa com `timeout`/`maxWait`.
- **Provedor de auth** usa **conexão/role próprios** (`contifisc_auth`, schema `contifisc_auth`) — decisão de schema em PoC (Better Auth/Prisma não documentam schema não-`public`, PD-07).
- **Provisionamento do `EXECUTE`** nas funções SD (dono = mediador) segue a **janela atômica de membership** já validada (ADENDO 6) — procedimento de provisionamento, não capacidade do runtime.
- **Segredos**: um por role e por ambiente; nunca no repositório; DEV/preview sem dados reais.

### 31.15 Contrato conceitual de `withSecurityContext`

**Entradas:** `principal` (saída **confiável** do resolvedor de sessão: `{provedor, emissor, subject, sessionId, aal, métodos, authTime}`) + `pedido` (`tenantSolicitado?`, `ueSolicitada?`, `requestId`; **não confiáveis**).
Variantes: `withAccountContext` (sem tenant: listar meus tenants), `withSecurityContext` (DATA), `withAccessAdminContext` (ACCESS), `withControlPlane` (CONTROL).

**Fluxo (ordem **exata**, ditada pelas policies atuais):**

| Passo | Ação | Se falhar |
|---|---|---|
| 0 | (fora da tx) resolver `IdentidadeAcessoExterna(ATIVA)` → `conta_acesso_id` | `IDENTIDADE_SEM_CONTA` (auditar) |
| 1 | Abrir **transação interativa** (role do plano; POOLED) com `timeout` | erro de infraestrutura |
| 2 | `set_config('app.current_conta_acesso_id', conta, true)` — **UUID validado**, parametrizado | — |
| 3 | Ler `conta_acesso` (status/tipo) | `CONTA_INATIVA` → negar, auditar, **revogar sessões** |
| 4 | **Sonda de tenant:** `SELECT id FROM tenant WHERE id = $t` | 0 linhas ⇒ `TENANT_NAO_AUTORIZADO` (**inexistente e não autorizado são indistinguíveis**), auditar |
| 5 | `set_config('app.current_tenant_id', tenant, true)` | — |
| 6 | Ler estado do `Tenant` | ≠ `ATIVO` ⇒ `TENANT_INATIVO` |
| 7 | Ler a concessão (`conta_acesso_tenant`): papel, `vigencia_fim`, origem | ausente após sonda OK ⇒ **inconsistência** (alarme); vencida ⇒ `CONCESSAO_EXPIRADA` |
| 8 | Ler restrições de UE do par (conta, tenant) ⇒ `ueScope` | — |
| 9 | Ler grants de entitlement do tenant ⇒ snapshot no instante | — |
| 10 | **PDP** `authorize(...)` (puro) sobre o snapshot | negação ⇒ auditar (tx curta separada) + erro |
| 11 | `callback(tx: TenantScopedTx{principal, ueScope, snapshot})` | erro ⇒ rollback |
| 12 | Commit/rollback ⇒ **GUCs destruídos automaticamente** | — |

**Comportamento nos casos pedidos:**

| Caso | Comportamento |
|---|---|
| Tenant inexistente | Idêntico a não autorizado (passo 4) — sem enumeração |
| Tenant não autorizado | Passo 4; evento `TENANT_NEGADO`; resposta 404/403 conforme §6.3 |
| Conta desativada | Passo 3; nega; **revoga sessões** |
| Concessão expirada | Passo 7; nega; sinaliza ao varredor |
| Troca de tenant | **Nova chamada** (nova transação); endpoint `selecionarTenant` valida (passos 1–6) e só então atualiza `tenant_ativo` na sessão; nunca reutiliza transação/GUC |
| Erro durante o callback | Rollback integral; GUCs somem; erro de negócio **não** gera evento de segurança; falha de PDP gera |
| Conexão POOLED | `set_config(...,true)` é transacional ⇒ compatível com pooler transacional (validado S16/S17); `pgbouncer=true`; nunca `SET SESSION`/`SET` não-local |
| Transações aninhadas | **Não abre transação aninhada**: reentrância detectada por `AsyncLocalStorage`; mesmo (conta, tenant) ⇒ **reutiliza** a transação; contexto diferente ⇒ erro `CONTEXTO_ANINHADO_INVALIDO` |
| Transação longa | Vigência/estado avaliados **no início**; `timeout` curto (segundos); jobs longos processam em **lotes**, cada lote com contexto revalidado |
| Cache | Passos 7–9 podem usar cache **curto** entre requisições; passos 2, 4, 5 **nunca** |

Consultas 3, 6–9 podem ser agrupadas para reduzir round-trips (custo típico: 1 sonda + 1–2 leituras).

### 31.16 Ponto único de decisão `authorize`

Conceitual (o formato concreto pode diferir):

```
authorize({ conta, tenant, capability, action, recurso?, contexto{ue?, aal, requestId} }, snapshot) →
    Decisao{ permitir | negar, portao, motivo, obrigacoes[], catalogo_versao }
```

- **Puro** sobre o snapshot lido na mesma transação (passos 3–9); sem chamadas externas.
- Considera, quando aplicável: `ContaAcesso` (G2), `Tenant` (G3/G4), entitlement da **capability** (G5), papel→permissão da `action` (G6), ABAC (segregação, estado do objeto, tipo de conta, `aal`) e UE (G7).
- **DENY por padrão** e *deny-overrides*. `obrigacoes[]` pode exigir *step-up*, justificativa ou filtro de UE.
- **A UI só consome** `capacidades(...)` para apresentação; **API/backend reavaliam sempre** (PEP em rota/action/RSC).
- Registra `catalogo_versao` e o portão na negação.

### 31.17 Auditoria — eventos mínimos V1, origem e persistência

| Evento | Origem (fonte do fato) | Persistido em `EventoAuditoriaSeguranca` (via função §31.3)? | Observação |
|---|---|---|---|
| Login OK | Provedor autentica; **CONTIFISC** resolve vínculo e cria sessão | **Sim** | Registrado pela CONTIFISC (autoridade), não copiado do provedor |
| Falha de autenticação | **Provedor** (quando expõe hook/callback); senão só log do provedor | **Sim, quando observável** | Sem conta ⇒ `conta_acesso_id` nulo + `ator_ref` (hash); lista fechada de tipos pré-autenticação |
| Logout / sessão revogada | **CONTIFISC** (revogação server-side) | **Sim** | — |
| MFA/fator alterado | Provedor + CONTIFISC (política) | **Sim** | — |
| Seleção/troca de tenant | **CONTIFISC** | **Sim** | origem→destino |
| Acesso negado — tenant | **CONTIFISC** | **Sim** | Objeto solicitado marcado "não verificado" |
| Acesso negado — entitlement | **CONTIFISC** | **Sim** | motivo (`SUSPENSO/EXPIRADO/…`) |
| Acesso negado — permissão | **CONTIFISC** | **Sim** | — |
| Acesso negado — UE | **CONTIFISC** | **Sim** | — |
| Concessão/revogação de tenant | **CONTIFISC** (ACCESS/CONTROL) | **Sim** (mesma tx) | antes/depois |
| Concessão/revogação de restrição de UE | **CONTIFISC** (ACCESS) | **Sim** (mesma tx) | — |
| Alteração de entitlement | **CONTIFISC** (CONTROL) | **Sim** (mesma tx) **+ ledger** | ledger de entitlement é o registro de negócio; o evento é a trilha de segurança |
| Alteração de papel/permissão | **CONTIFISC** | **Sim** (mesma tx) | catálogo é código: mudança = release (versão registrada) |
| Break-glass (abrir/usar/encerrar) | **CONTIFISC** (CONTROL/DATA) | **Sim** | uso a cada ativação de contexto |
| Operação administrativa sensível | **CONTIFISC** | **Sim** (mesma tx) | suspensão de conta/tenant, fusão de contas, exportação sensível |

**Não confundir**: `EventoAuditoriaSeguranca` ≠ logs técnicos/observabilidade (OBS-001) ≠ eventos de domínio (EVT-001 futuro — a CAF-001 já prevê eventos de negócio, tratados à parte).
Logs do provedor são **complementares** e **não** substituem a trilha CONTIFISC (retenção, formato e autoridade diferentes).

### 31.18 Reclassificação de PD-01…PD-22

**Classe A — decidir agora (bloqueia desenho/PoC):** proposta conclusiva. **Classe B — decidir na PoC.** **Classe C — deferir.**

| PD | Tema | Classe | Decisão proposta (A) / evidência (B) / etapa futura (C) | Dependências |
|---|---|---|---|---|
| PD-01 | Onboarding | **A** | **V1 = somente convite/administração**; sem criação autoatendida de contas/tenants; autoatendimento é Classe C comercial | — |
| PD-02 | Vigência/estado/recertificação de concessões | **A** | Concessões ganham `vigencia_fim`, `origem`, `concedido_por` (CR de `GAP-CDC-1.4-001`); internas 90 d (máx. 180); revogar = `DELETE` + auditoria; **sem** coluna de estado na V1 | DP-09, §31.13; **evidência (B)**: varredor + alerta suficientes sem alterar a RLS (Gate B/C) |
| PD-03 | MFA | **A (política) / B (mecanismo)** | **aal2 obrigatório** para internos, `admin.*`, `*.aprovar`, controle e break-glass; recomendado por política de tenant nos demais. `aal` **calculado pela CONTIFISC** a partir dos métodos usados na sessão (não confiar em claim); **B:** como obter `amr`/método do Better Auth e da alternativa (OAuth/passkey não passam por 2FA por padrão) | PD-04 |
| PD-04 | Provedor | **B** | Finalistas: **Better Auth self-hosted** e **Clerk**; Neon condicionado a evidência de MFA/passkeys/hooks; Auth.js eliminada (§31.9) | Gate A |
| PD-05 | Estado de `Tenant`/`ContaAcesso`; `tipo` | **A** | `Tenant.status ∈ {ATIVO, SUSPENSO, ENCERRADO}`; `ContaAcesso.status ∈ {ATIVA, SUSPENSA, ENCERRADA}` e `tipo ∈ {HUMANA, SERVICO}` — atributos **de segurança** (não comerciais); CR canônico futuro (GAP-CDC-1.3-001, 1.4-002) | Necessário a G2/G4 e a jobs (conta de serviço) |
| PD-06 | Catálogo de módulos/features (nomes/granularidade) | **C** | Decisão de produto; PoCs usam capabilities **fictícias** (`demo.*`) | Produto/comercial |
| PD-07 | Schema/role de armazenamento de auth | **B** | Tentativa: schema `contifisc_auth` + role `contifisc_auth`; **evidência**: adapter/CLI do Better Auth com schema não-`public` e Prisma multi-schema | Gate A |
| PD-08 | Associação `PessoaFisica ↔ ContaAcesso` | **C** | Opcional; nunca concede acesso a fatos por si; avaliar quando houver caso de uso | — |
| PD-09 | Upgrade do Next | **A** | Next 14 **EOL** ⇒ upgrade obrigatório **antes de auth em produção** (alvo Next 16); **não** bloqueia desenho/PoC (workspace descartável) — DP-15 | §31.9.3 |
| PD-10 | Comportamento pós-expiração | **C** | V1: bloqueia `OPERATIVA`; `CONSULTA` conforme política comercial futura; modelo já suporta | Comercial |
| PD-11 | Entitlement por UE | **C** | Campo de escopo extensível; não V1 | Comercial |
| PD-12 | Exibição de insumos de módulo não contratado | **C** | Princípio mantido (mostrar só o necessário à explicação); definir por módulo | Design de módulos |
| PD-13 | Persistir `PapelAcesso/Permissao` | **A** | **Híbrido**: definições em código, atribuições persistidas; persistência de definições diferida com **gatilhos** (§31.12); **sem** revogar CDC-SEC-003 na V1 | — |
| PD-14 | Múltiplos papéis por conta/tenant | **A** | **Um papel por concessão** na V1; composição no catálogo; múltiplos = Classe C | PD-13 |
| PD-15 | Localização do PDP | **C** | Decidir na implementação; requisito: pacote **puro** (sem Next/Prisma), testável | — |
| PD-16 | Parâmetros do break-glass | **A (princípio) / C (parâmetros)** | Mecanismo fechado (§31.13); padrão 4 h/máx. 24 h, aprovador distinto, somente leitura; ajuste fino depois | PD-02 |
| PD-17 | Role separado de administração de acesso | **A** | **Sim**: `contifisc_access_admin` (§31.6) | G-07 |
| PD-18 | UE: RLS × aplicação | **A** | **V1 = aplicação estrutural**; evolução C com gatilhos (§31.5) | — |
| PD-19 | Caminho de escrita da auditoria e campos | **A (caminho) / B (evidência)** | **Função `SECURITY DEFINER` + role `contifisc_audit_writer`** (§31.3); campos exigem CR; **B:** hash chain/imutabilidade e fluxo tx curta/mesma tx | ADR-002 V1.1 |
| PD-20 | Visibilidade da auditoria por tenant/transparência | **C** | V1: leitura só por controle/segurança | PD-19 |
| PD-21 | Tenant interno CONTIFISC | **C** | Não necessário para auth/runtime; contas internas são globais com concessões explícitas | — |
| PD-22 | LGPD (residência, retenção, PII em branches) | **C** (com salvaguardas **A**) | Salvaguardas já fixas: **sem dados reais em DEV/preview**, minimização de identidade; residência/retenção dependem do provedor (PD-04) e de política legal | PD-04 |

**Novas decisões fechadas nesta rodada** (todas Classe A): DP-12 (auditoria), DP-13 (UE V1), DP-14 (Organizations do provedor não usadas), DP-15 (Next), DP-16 (entitlement = capability + produto→grants).
**Contagem (22 PDs):** **A puras: 8** (PD-01, 02, 05, 09, 13, 14, 17, 18) · **mistas: 3** — PD-03 (A política / B mecanismo), PD-16 (A princípio / C parâmetros), PD-19 (A caminho / B evidência) ·
**B puras: 2** (PD-04, PD-07) · **C: 9** (PD-06, 08, 10, 11, 12, 15, 20, 21, 22). Total 8+3+2+9 = 22.
Evidências que restam para a PoC (Classe B): escolha do provedor (PD-04), schema de auth (PD-07), mecanismo de `aal` (PD-03), imutabilidade/hash chain e fluxo transacional da auditoria (PD-19) e a suficiência
"varredor + aplicação" para vigência (PD-02). **Nenhuma Classe A depende de PoC** — dependem de **aprovação**.

### 31.19 Gates de PoC (substituem as 8 PoCs de §28)

Todos: **sem dados reais**; ambientes descartáveis; Neon só onde explicitamente autorizado; scripts revisados antes de executar (lição do ADENDO 6); reproduzir **ACLs de schema do provedor** (lição do ADENDO 4);
nada de segredos em logs; cada gate termina com **cleanup verificado** e relatório com hash dos artefatos.

#### GATE A — Identity / Auth
- **Objetivo:** provar autenticação e o **vínculo seguro** `provedor+subject → ContaAcesso`, com MFA e revogação.
- **Pré-condições:** decisões DP-01/DP-14/DP-15 e PD-01/03/05 aprovadas; workspace descartável com **Next-alvo** (16; 15.5 fallback) e verificação extra em 14.2.35; PG18 descartável estilo Neon; (opcional) branch Neon descartável **sem dados reais**.
- **Ambiente:** scratch app + PG18 (2 execuções independentes); Better Auth self-hosted **e** adapter Clerk (spike fino) atrás da porta `IdentityProvider`.
- **Testes:** login → resolução de conta via `IdentidadeAcessoExterna`; **e-mail não é chave** (troca de e-mail não altera vínculo; e-mails iguais **não** unem contas); duplicidade; identidade órfã ⇒ sem acesso; revogação de vínculo ⇒ sessão inválida ≤ TTL; `aal`: OAuth/passkey/2FA produzem `aal` correto **calculado pela CONTIFISC**; cookie cache × revogação; rotação de sessão no login; `getSessionCookie`-style não é autoridade; schema de auth em `contifisc_auth` (PD-07); evidência oficial sobre MFA/passkeys/hooks do Neon (para decidir finalismo); Organizations desabilitadas.
- **Evidências:** logs de teste, prints de esquema, matriz de resultados por provedor, hashes.
- **PASS:** todos os testes acima ok em ≥1 provedor finalista **e** porta agnóstica comprovada por 2 adapters; nenhuma decisão de autorização usa dado do provedor além de `subject`. **FAIL:** qualquer autorização baseada em claim/e-mail/organização do provedor; sessão revogada válida além do TTL definido.
- **Cleanup/rollback:** destruir containers/branches; nenhuma alteração no repositório principal.

#### GATE B — Runtime / Security Context
- **Objetivo:** provar `contifisc_app` **real** + Prisma + POOLED + `set_config` + RLS, e o `withSecurityContext`.
- **Pré-condições:** DP-06/DP-08/DP-13; PD-17; script de provisionamento revisado.
- **Ambiente:** PG18 estilo Neon (2×) **e**, com autorização separada, Neon DEV (DIRECT + POOLED).
- **Testes:** repetir **S01–S17 como login real** de `contifisc_app` (não `SET LOCAL ROLE`); sonda de tenant (sem concessão ⇒ nega; inexistente ≡ não autorizado); ordem exata dos passos; ausência de resíduo de GUC; reentrância/`AsyncLocalStorage`; transação aninhada; erro no callback; `EXECUTE` das funções SD sem membership persistente; **privilégios**: `contifisc_app` **não** grava em `conta_acesso*`/entitlement, `access_admin` não lê/escreve dados de negócio, `control` não é usado no runtime; trigger `interno.*`; concessão vencida presente ⇒ app nega e varredor remove; teste arquitetural (imports proibidos); performance da sonda.
- **Evidências:** saídas S01–S17 (direct/pooled), tabelas de GRANT (`information_schema`), traces de queries, hashes.
- **PASS:** todos os S01–S17 como `contifisc_app`; nenhuma capacidade de auto-concessão; nenhum resíduo. **FAIL:** qualquer escrita indevida, vazamento cross-tenant, GUC residual ou dependência de `BYPASSRLS` no runtime. Se a **vigência × sonda** for considerada risco real ⇒ propor a mudança **aditiva mínima** (ADR-002 V1.1).
- **Cleanup/rollback:** roles/objetos de teste removidos; janelas de membership revertidas e verificadas; DB vazio.

#### GATE C — Entitlements / Authorization
- **Objetivo:** provar capability + papel/permissão + ABAC + UE + **negação no backend**.
- **Pré-condições:** DP-04/05/13/16; PD-13/14/18; capabilities fictícias `demo.*` (PD-06 é C).
- **Ambiente:** Vitest (resolvedor puro) + PG18 descartável + rotas de teste no scratch app.
- **Testes:** resolvedor: determinismo, deny-overrides, dependências sem ciclo, vigência `[i,f)`, trial, override com aprovador, expiração derivada; produto→grants materializados; **cada portão G1–G7 negando isoladamente**; **URL direta / Server Action / RSC** a capability não contratada ⇒ 403; 404 anti-enumeração; snapshot test de papéis (falha ao mudar permissões); segregação de funções; UE: restrição só **restringe**, `ueScope` obrigatório nos repositórios, objetos sem UE negados a contas restritas, ADR-C014 preservado; conta interna vs cliente; `catalogo_versao` nas decisões.
- **Evidências:** matriz de casos (portão × resultado), cobertura, relatórios.
- **PASS:** 100% da matriz; nenhuma rota sem PEP (teste arquitetural). **FAIL:** qualquer caminho que permita capability/permissão/UE sem o portão correspondente.
- **Cleanup/rollback:** descartável.

#### GATE D — Audit / Adversarial E2E
- **Objetivo:** provar auditoria e a resistência a cenários adversariais fim a fim.
- **Pré-condições:** Gates A–C aprovados; DP-12 (função de auditoria) implementada **apenas em ambiente descartável**.
- **Ambiente:** PG18 estilo Neon (2×) + scratch app; (Neon DEV somente com autorização).
- **Testes:** gravação **somente** via função; runtime **sem** INSERT/UPDATE/DELETE/TRUNCATE na tabela; campos carimbados no banco (spoof de conta/tenant/instante/`origem_plano` falha); trigger de imutabilidade; hash chain (detectar adulteração); evento na mesma tx aborta operação se auditoria falha; negação sobrevive ao rollback; falha ao auditar negação **não** libera acesso; eventos pré-autenticação; adversariais: tenant/module/permission spoofing, IDOR, cross-tenant, URL direta, sessão antiga com permissão revogada (≤ TTL), tenant suspenso, módulo expirado, troca de tenant/UE, GUC residual, *break-glass* (abertura, uso, expiração, varredor, notificação), servidor forjando conta (**documentar risco residual**), interno abusando de carteira (alertas).
- **Evidências:** relatório de eventos por cenário, diffs de tabela, hashes, logs.
- **PASS:** todos os cenários bloqueados/registrados como esperado. **FAIL:** qualquer bypass, evento adulterável ou operação sensível sem trilha.
- **Cleanup/rollback:** ambientes destruídos; se Neon DEV foi usado: roles/dados/objetos de teste removidos e ACLs verificadas contra o estado anterior.

### 31.20 GO / NO-GO

| DECISÃO | STATUS | BLOQUEIA PoC? | RESPONSÁVEL | EVIDÊNCIA NECESSÁRIA |
|---|---|---|---|---|
| Identidade externa ↔ `ContaAcesso` (DP-01, §31.7) | **Proposta conclusiva** | Sim (até aprovação) | Bruno (aprova) / Arquitetura | — (evidência empírica: Gate A) |
| Autoridade sobre Tenant; Organizations do provedor não usadas (DP-14) | **Proposta conclusiva** | Sim (até aprovação) | Bruno / Arquitetura | — |
| Entitlement mínimo: capability + produto→grants (DP-16) | **Proposta conclusiva** | Sim (até aprovação) | Bruno + Comercial | Catálogo real → Classe C (PD-06) |
| RBAC híbrido + ABAC tipado (DP-04 rev.) | **Proposta conclusiva** | Sim (até aprovação) | Bruno / Arquitetura | Gate C |
| Administração de acessos: 3 planos e roles (§31.6; PD-17) | **Proposta conclusiva** | Sim (até aprovação) | Bruno / Arquitetura | Gate B |
| Caminho de auditoria (DP-12; PD-19) | **Proposta conclusiva** | Sim (até aprovação) | Bruno / Arquitetura | Gate D; ADR-002 V1.1 |
| UE na V1 = aplicação estrutural (DP-13) | **Proposta conclusiva** | Sim (até aprovação) | Bruno / Arquitetura | Gate C |
| Produto/módulo/feature/Skill (DP-03 rev.) | **Proposta conclusiva** | Sim (até aprovação) | Bruno + Comercial | Classe C (módulo) |
| Vigência/`status`/`tipo` (PD-02, PD-05) | **Proposta conclusiva** | Sim (até aprovação) | Bruno | CR canônico futuro (não bloqueia PoC em ambiente descartável) |
| MFA/`aal` (PD-03) | Política **fechada**; mecanismo em PoC | Não (mecanismo é do Gate A) | Bruno / Arquitetura | Gate A |
| Upgrade do Next (DP-15) | **Proposta conclusiva** | Não (PoC em workspace descartável) | Bruno (agendar) | Tarefa separada pré-produção |
| Provedor final (PD-04) | **Depende de PoC** | Não | Bruno | Gate A (finalistas A e C; Neon condicionado) |
| Schema de auth (PD-07) | **Depende de PoC** | Não | Arquitetura | Gate A |
| Catálogo real de módulos/features (PD-06), pós-expiração (PD-10), UE-entitlement (PD-11), exibição de insumos (PD-12), PF↔Conta (PD-08), visibilidade da auditoria (PD-20), tenant interno (PD-21), LGPD (PD-22), PDP location (PD-15) | **Deferidos (Classe C)** | Não | Bruno / Comercial / Jurídico | Etapas futuras |

**Riscos residuais (registrados):**

1. **Servidor de aplicação comprometido** pode afirmar qualquer conta (RLS não protege); mitigação por segregação de credenciais, menor privilégio, auditoria/detecção (§7).
2. **Vigência × sonda de RLS**: linha de concessão vencida ainda passa a sonda até o varredor removê-la; a aplicação nega (G3); opção de mudança aditiva mínima em Gate B/C.
3. **Escalonamento por rota de administração de tenant**: DB não valida chaves de papel (catálogo em código); mitigado por PDP + teto de delegação + trigger `interno.*` (a provar) + auditoria.
4. **Dependência do provedor**: cookie cache/sessão (Better Auth), evidência de MFA (Neon), lock-in e residência (Clerk) — a porta `IdentityProvider` reduz custo de troca, não elimina.
5. **Framework EOL (Next 14)** até o upgrade; **não** usar em produção com auth.
6. **Tabela de auditoria** protegida contra o runtime, mas não contra o owner malicioso — hash chain/exportação WORM (Gate D/Classe C).
7. **Objetos sem UE unívoca** exigem regra por módulo; até lá, contas restritas por UE não os acessam (negação por padrão).
8. Comparativo de provedores reflete a documentação em 2026-09-21; **reverificar** antes de decidir.

**Recomendação técnica:**

```
READY FOR PoC DESIGN
```

Justificativa: todas as decisões que bloqueiam o *desenho* das PoCs (Classe A) têm proposta conclusiva; o que resta depende de evidência empírica (Classe B — coberta pelos Gates A–D) ou é deferível (Classe C). **Condição:** a
**execução** das PoCs exige a aprovação explícita das propostas Classe A acima (o ADR-003 permanece DRAFT/NÃO APROVADO; esta recomendação **não** aprova o ADR nem autoriza implementação).

### 31.21 Fontes desta rodada (documentação oficial, consultadas em 2026-09-21)

- Next.js — [Support Policy](https://nextjs.org/support-policy) (14.x EOL; 15.x Maintenance LTS; 16.x Active LTS)
- Better Auth — [Next.js integration](https://www.better-auth.com/docs/integrations/next) · [Organization plugin](https://www.better-auth.com/docs/plugins/organization) · [Two-Factor](https://www.better-auth.com/docs/plugins/2fa) · [Passkey](https://www.better-auth.com/docs/plugins/passkey) · [Prisma adapter](https://www.better-auth.com/docs/adapters/prisma) · [Session management](https://www.better-auth.com/docs/concepts/session-management) · [Auth.js joins Better Auth](https://better-auth.com/blog/authjs-joins-better-auth) · [Auth.js security update jul/2026](https://better-auth.com/blog/security-update-july-2026)
- Neon — [Managed Better Auth (overview)](https://neon.com/docs/auth/overview) · [Next.js quick start](https://neon.com/docs/auth/quick-start/nextjs) · [Branching authentication](https://neon.com/docs/auth/branching-authentication) · [Migrate from legacy Neon Auth](https://neon.com/docs/auth/migrate/from-legacy-auth)
- Clerk — [Pricing](https://clerk.com/pricing) · [Organizations overview](https://clerk.com/docs/organizations/overview) · [Next.js quickstart](https://clerk.com/docs/nextjs/getting-started/quickstart)
- Repositório (somente leitura): `SECURITY_CONTEXT_CONTRACT.md`, `RLS_MATRIX.md`, `ADR-002`, `schema.prisma`, `SEC-001`, `CDC-001` V1.4 (CDC-SEC-002/003/004), `MCD-001` V1.4 §8.

---

## 32. Adendo — Gate A (Identity / Auth) — resultado

**Relatório:** `docs/poc/GATE_A_IDENTITY_AUTH_REPORT.md` · **PoC descartável:** `poc/auth-gate-a/`. O ADR-003 **permanece DRAFT / NÃO APROVADO**.

- **Encerramento formal do Gate A (checkpoint pré-upgrade):** **Gate A = PASS COM CONDIÇÕES**. Provedor para continuidade: **Better Auth self-hosted, obrigatoriamente atrás de IdentityProvider CONTIFISC**
  (Better Auth → IdentityProvider → IdentidadeAcessoExterna → ContaAcesso); o provedor **não** é autoridade sobre Tenant, ContaAcessoTenant, entitlement, papel, permissão, UE nem RLS. Clerk = alternativa futura;
  Neon Managed Better Auth = não adotado nesta etapa. Condições **C1–C11** e decisões fechadas (vigência no momento da decisão; sem BYPASSRLS como premissa; Next 14 → 16 antes do Gate B; principal sem Tenant)
  estão em docs/poc/GATE_A_IDENTITY_AUTH_REPORT.md §28. **O ADR-003 continua DRAFT / NÃO APROVADO.**
- **Resultado:** Better Auth self-hosted = **APROVADO COM CONDIÇÕES** (evidência empírica: 84 testes de suíte + 17 verificações Next); Neon Managed Better Auth = **NÃO APROVADO**
  (documentação oficial: MFA "planejado", passkeys não listados, sem hooks de sessão ⇒ AAL indemonstrável); Clerk = **NÃO APROVADO por evidência insuficiente** (PoC exige ação humana).
- **Correções incorporadas por decisão de Bruno** (prevalecem sobre §31.6 e §31.13): (A) `contifisc_control` **não** presume `BYPASSRLS` — operações privilegiadas via funções específicas,
  roles mínimos e auditoria; (B) vigência decidida **no momento da decisão** (`inicio <= now() AND (fim IS NULL OR now() < fim)`), **sem** varredor como mecanismo de revogação (comprovado no Gate A);
  (C) Next 14 → 16 é etapa posterior à escolha do provedor (Next 14 é EOL; harness Next 16 aceitou React 18.3.1).
- **Saída do Gate A para o Gate B:** `ResolvedPrincipal { contaAcessoId, identity: AuthenticatedIdentity }` (contrato `poc/auth-gate-a/contracts/identity-provider.ts`); sem tenant, papel ou organização.
- **PD-03/PD-07 (evidência de PoC):** AAL derivável só por hook CONTIFISC (o provedor não o expõe); tabelas do provedor em schema `contifisc_auth` funcionam com Prisma 6.19.3 multiSchema.
---

## Gate desta rodada

```
ADR-003 — DRAFT (v0.2) — NÃO APROVADO
Rodada 2 — Fechamento Arquitetural Pré-PoC: concluída (documental)
Recomendação técnica: READY FOR PoC DESIGN
```

Nenhuma implementação, tabela, role, função, policy, migration, dependência, seed, middleware, API ou alteração de baseline/RLS/Neon foi realizada.
`CRITICAL = 0`. Nenhum gap foi classificado como vulnerabilidade (§31.2). Decisões fechadas/propostas: DP-01…DP-16 (com revisões de DP-01, DP-03, DP-04);
pendências: 8 Classe A puras + 3 mistas aguardando **aprovação**, evidências de PoC (Classe B) cobertas pelos Gates A–D e 9 deferimentos (Classe C) — ver §31.18.
