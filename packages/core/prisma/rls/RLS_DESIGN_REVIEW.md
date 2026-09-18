# RLS_DESIGN_REVIEW — CONTIFISC pós-SEC

**Status:** REVISÃO DE DESENHO. Nenhuma alteração foi feita ao Neon DEV, ao `schema.prisma` ou à
migration inaugural pós-SEC (`20260908120000_init_baseline_fisica_pos_sec`) por este documento.

## 1. Estado do ambiente verificado nesta revisão (não apenas confiado no prompt)

| Item | Verificado como | Como |
|---|---|---|
| `git status` do repo local | Limpo, `HEAD` em `0d3f1a4` | `git status --short` / `git log --oneline -3` |
| Migrations ativas | Apenas `20260908120000_init_baseline_fisica_pos_sec` | `Get-ChildItem prisma/migrations` |
| Migration pré-SEC removida da cadeia ativa | Confirmado ausente do diretório ativo; recuperável em `git log`/histórico (commit `0d3f1a4`, mensagem explica o motivo) | Não restaurada nesta revisão |
| `schema.prisma` tem 25 models, `tenant_id` materializado exatamente em 5 (`UnidadeEconomica`, `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`, `ContaAcessoTenant`) | Confirmado por grep direto no arquivo, não por relatório anterior | `Grep "^model |tenant_id|unidade_economica_id"` |
| `migration.sql` aplicada não contém `CREATE POLICY`/`ENABLE ROW LEVEL SECURITY` | Confirmado | `Grep "POLICY|ROW LEVEL SECURITY"` — zero ocorrências fora de comentários |
| `ADR-C014` (triggers `trg_caue_requires_grant_fixed`/`trg_cat_blocks_if_dependents`/`trg_ue_tenant_change_guard`) já presentes na migration aplicada | Confirmado — **já ativos no Neon DEV**, aplicados junto da baseline inaugural | `Grep` no `migration.sql` |
| `F9005`/`F9006` | Não tocados — nenhuma referência nova a `versao_schema`/`correlation_id` foi criada por este trabalho | Inspeção do `schema.prisma`/matriz |
| Docker local | Daemon não estava em execução nesta máquina durante esta sessão | `docker ps` retornou erro de conexão |

**Nota sobre Docker:** por não haver Docker Desktop ativo nesta sessão, **nenhum teste da
suíte (`RLS_TEST_PLAN.md`) foi executado empiricamente** — nem contra PostgreSQL descartável, nem
contra o Neon DEV (que de qualquer forma está fora de escopo para esta etapa). Os 25+ testes estão
**especificados e prontos para execução**, não executados. Isso é registrado como limitação desta
revisão, não omitido.

## 2. Reconciliação (item 16 do prompt original)

| Verificação | Resultado |
|---|---|
| A) 25 models reais do Prisma listados | ✓ (RLS_MATRIX.md) |
| B) Mapeamento para classificação SEC | ✓ 25/25, idêntico a `ADR-001` V1.1 §9.1 |
| C) `tenant_id` real reconciliado | ✓ grep direto — 5 tabelas: `unidade_economica`, `arquivo_origem`, `conflito_dado`, `revisao_tecnica`, `conta_acesso_tenant` |
| D) Caminhos de tenant derivado reconciliados | ✓ — ver coluna "Caminho relacional" da matriz; nomes de FK confirmados por leitura direta do `schema.prisma` (não assumidos) |
| E) `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` reconciliados | ✓ — `ADR-C012`/`C013` (`UNIQUE`) presentes; `ADR-C014` reconciliado (item F) |
| F) `ADR-C014` reconciliado | ✓ — triggers já ativos na migration aplicada; RLS de `conta_acesso_unidade_economica` desenhada para **coexistir**, não substituir (§D3 abaixo) |
| G) 6 hosts de `MCD-F10004` reconciliados | ✓ — `receita`, `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`, `resultado_calculo`, todos com FK simples confirmada, nenhum com `tenant_id` redundante (grep negativo) |
| H) `F9005`/`F9006` intocados | ✓ |
| I) `schema.prisma` × banco DEV estruturalmente equivalentes | ✓ — banco DEV foi criado a partir exatamente desta `migration.sql` (verificado nesta sessão: 26 tabelas, incluindo `_prisma_migrations`) |
| J) Migration history atual | ✓ — 1 migration ativa, `prisma migrate deploy` aplica limpo (verificado na etapa anterior da sessão) |

## 3. Achados

### D1 — `GLOBAL_COMPARTILHADO` como policy permissiva explícita vs. RLS desabilitada — **MENOR**

`ADR-001` V1.1 §10 deixa em aberto: "sem RLS de tenant (**ou** com RLS permissivo — a decidir na
implementação, sem impacto na garantia de isolamento)". Esta revisão **decide** pela segunda opção
(RLS habilitada + policy `USING (true) WITH CHECK (true)` explícita) para `pessoa_fisica`,
`pessoa_juridica`, `fonte_pagadora`, `conta_acesso`. Motivo: mantém `FORCE ROW LEVEL SECURITY`
uniforme nas 25 tabelas (auditável — toda tabela tem RLS habilitada, a diferença fica na policy, não
na ausência de RLS) e documenta a decisão de forma explícita em vez de silenciosa.

**Impacto:** nenhum na garantia de isolamento (§10 do ADR já explica por quê — o isolamento vive
nos fatos, não nas identidades). Classificado `MENOR` porque é uma decisão de forma, não de
segurança, e precisa apenas de confirmação humana no gate — não bloqueia.

### D2 — `tenant` (categoria `RAIZ_PROPRIA_VISIVEL_POR_CONCESSAO`) — **RESOLVIDO NO DESENHO** (era `RELEVANTE`)

**Atualização:** resolvido por `SECURITY_CONTEXT_CONTRACT.md`, que define uma segunda variável de
sessão (`app.current_conta_acesso_id`, AUTHENTICATED ACCOUNT CONTEXT) além de
`app.current_tenant_id` (ACTIVE TENANT CONTEXT, `ADR-D028`, inalterado). A policy definitiva de
`tenant` agora verifica a concessão real via `EXISTS` contra `conta_acesso_tenant`, sem depender de
`app.current_tenant_id`. Resolvido **sem** implementar autenticação real e **sem** alterar nenhum
objeto canônico — a segunda variável é um mecanismo físico de sessão da mesma classe já autorizada
por `ADR-001` §9.2/§9.4 para a primeira. Texto original do achado, preservado para rastreabilidade:

A categoria conceitual do `ADR-001` V1.1 §9.1 item 21 prevê visibilidade de `tenant` por
**concessão explícita** via `conta_acesso_tenant` (join reverso a partir da identidade da
`ContaAcesso` autenticada). Isso exige que o contexto de sessão carregue **duas** informações: o
tenant ativo (`app.current_tenant_id`, já definido por `ADR-D028`) **e** a identidade da
`ContaAcesso` da sessão — que **não existe hoje** porque autenticação está deliberadamente fora de
escopo desta etapa (e desta plataforma, ainda).

Esta revisão propõe uma **simplificação provisória**: `tenant` visível apenas quando
`id = current_setting('app.current_tenant_id', true)::uuid` — ou seja, a própria linha do tenant
ativo da sessão, sem resolver a concessão via `ContaAcesso`. Isso é suficiente para o único uso
necessário hoje (uma transação com contexto de tenant X consegue fazer `JOIN` até a própria linha
de `tenant`), mas **não implementa** "quais tenants esta conta pode enxergar" no plural — pergunta
que só faz sentido quando autenticação existir.

**Por que é `RELEVANTE`, não `CRITICAL`:** não há risco de vazamento cross-tenant (a simplificação
é estritamente mais restritiva que a versão conceitual, nunca mais permissiva) nem corrupção de
dado. É uma ambiguidade arquitetural real que precisa de confirmação humana explícita antes de
qualquer aplicação — a policy provisória pode precisar ser reescrita quando autenticação chegar, o
que é esperado e não um defeito desta revisão, mas deve ser decidido conscientemente, não herdado
silenciosamente de um rascunho.

**Recomendação:** aprovar a simplificação como *interina* (documentada como tal na própria policy,
`tenant_isolation_provisorio`, nome deliberadamente diferente de `tenant_isolation` usado nas
demais 23 tabelas com policy) e reabrir quando o Change Request de autenticação/RBAC
(`GAP-CDC-1.3-001`) for iniciado.

### D3 — RLS e `ADR-C014` coexistem sem enfraquecimento — verificado, não é achado

A trigger `trg_caue_requires_grant_fixed` (já ativa na migration aplicada) garante o invariante de
negócio "toda `ContaAcessoUnidadeEconomica` pressupõe uma `ContaAcessoTenant` correspondente" —
independente de RLS. A policy de `conta_acesso_unidade_economica` (RLS_MATRIX item 24) garante
apenas "uma sessão só vê/escreve linhas cuja UE pertence ao tenant ativo". Os dois mecanismos
operam em camadas diferentes (trigger = invariante estrutural entre duas tabelas; RLS = filtro de
visibilidade por sessão) e não têm sobreposição de responsabilidade nem conflito de lock — nenhuma
das novas policies desta revisão remove, contorna ou compete com os locks/triggers do `ADR-C014`
(nenhuma policy usa `FOR UPDATE`/lock explícito que pudesse interagir com o `FOR KEY SHARE` interno
das triggers).

### D4 — Exceção residual `Vinculo`/`VinculoExtremidade` sem extremidade UE — **NÃO É ACHADO NOVO**

Já reconhecida e classificada `NAO_BLOQUEANTE` pelo próprio `ADR-001` V1.1 §14
(`GAP-SEC-CR1-002`/`DST-GAP-003`). A policy desta revisão implementa o comportamento fail-closed
mais seguro para o caso não resolvido (linha fica invisível a todos, nunca vaza) — reproduzido aqui
apenas para rastreabilidade, não reclassificado.

### D5 — Suíte de testes não executada empiricamente nesta sessão — **MENOR**

Ver §1 (Docker indisponível). Não afeta a corretude do desenho (que segue diretamente a matriz já
aprovada por `ADR-001`), mas significa que **nenhuma evidência empírica** (ao contrário da
disciplina já usada para `ADR-C005`/`ADR-C014`) respalda ainda este draft. Recomendação: rodar
`RLS_TEST_PLAN.md` completo em PostgreSQL 15 descartável antes de qualquer aplicação real — mesma
metodologia já validada no projeto.

### D6 — Pooling Neon × `SET LOCAL`: análise arquitetural, não teste empírico contra o pooler real — **MENOR**

O pooler do Neon opera em modo transacional (PgBouncer transaction-mode): uma conexão física é
emprestada a um cliente lógico apenas durante a duração de uma transação, e devolvida ao pool
imediatamente após `COMMIT`/`ROLLBACK`. `SET LOCAL` é escopado à transação e é revertido
automaticamente nesse mesmo instante — por construção, não sobrevive à devolução da conexão ao
pool, o que é exatamente a propriedade que evita o vazamento de contexto residual entre tenants
diferentes reaproveitando a mesma conexão física (o risco central identificado por `SEC-001` §14 e
`ADR-001` §9.4). Isso é consistente com o comportamento documentado do PgBouncer/Postgres em geral,
mas **não foi testado empiricamente contra o endpoint pooled real do Neon** nesta sessão (exigiria
tocar a conexão pooled do Neon DEV para fins de teste, ou reproduzir PgBouncer em ambiente
descartável — nenhum dos dois foi feito). **Nenhuma incompatibilidade foi encontrada** — portanto
não há motivo para acionar a regra "parar e classificar como RELEVANTE" do escopo original; a
lacuna é de evidência empírica, não de desenho.

### D7 — Leitura de contexto sem tratamento de exceção (achado desta rodada, corrigido) — **MENOR, corrigido no próprio desenho**

O padrão original (`current_setting(...)::uuid` inline em cada policy) lança exceção em vez de
retornar `NULL` quando o GUC contém texto não-UUID. Corrigido por `SECURITY_CONTEXT_CONTRACT.md`
§3: duas funções `STABLE` (`contifisc_current_tenant_id()`/`contifisc_current_conta_acesso_id()`)
substituem todo uso inline nas 24 tabelas. Nenhum predicado lógico mudou — apenas robustez.
Classificado `MENOR` porque não era um risco de vazamento (um erro de query nunca expõe dado de
outro tenant), mas quebrava a garantia de "fail-closed sempre silencioso"; já corrigido nesta
mesma revisão, não fica pendente para o gate.

### D8 — Provisionamento de `tenant`/primeira concessão exige role `BYPASSRLS` dedicado — **MENOR, documentado**

Consequência esperada de `FORCE ROW LEVEL SECURITY` + `WITH CHECK` baseado em concessão: não é
possível inserir o primeiro `Tenant` nem a primeira `ContaAcessoTenant` sem um role administrativo
que ignore RLS para esse caminho específico (proposto: `contifisc_provisioning`, não criado nesta
revisão). Documentado em `SECURITY_CONTEXT_CONTRACT.md` §5 e `RLS-001` §18. Não bloqueia o gate —
é arquitetura de roles, já marcada como pendente de decisão desde `RLS-001` §18/§20.

## 4. Contagem do gate

| Severidade | Quantidade | Itens |
|---|---|---|
| `CRITICAL` | 0 | — |
| `RELEVANTE` | 0 | (D2 resolvido nesta revisão) |
| `MENOR` | 5 | D1, D5, D6, D7 (corrigido no próprio desenho), D8 (documentado, não bloqueante) |

## 5. Conclusão do gate

Com **0 achados `CRITICAL` e 0 `RELEVANTE`**, a conclusão específica da resolução de D2 é:

```
RLS D2 — CONTEXTO DE SEGURANÇA DEFINIDO E APTO PARA PoC DESCARTÁVEL
```

**O que isso significa na prática:** o desenho de RLS (25/25 tabelas, incluindo a policy
definitiva de `tenant`) está completo e internamente consistente, sem achado `RELEVANTE` ou
`CRITICAL` pendente. **Isto ainda não autoriza aplicação real** — os achados `MENOR` (D5: suíte não
executada; D6: pooling não testado empiricamente contra o Neon real; D8: roles de provisionamento
não criados) continuam exigindo a PoC descartável (`RLS_TEST_PLAN.md`) antes de qualquer
`prisma migrate deploy` contra o Neon DEV, conforme `RLS-001` §26.

## 5.1. Atualização pós-PoC — 2 CRITICALS encontrados e corrigidos

A execução real da PoC descartável (`RLS_POC_REPORT.md`) encontrou 2 achados `CRITICAL` que a
revisão de desenho (puramente estática, acima) não detectou: recursão infinita em
`vinculo`/`vinculo_extremidade` (C1) e a policy de `tenant` reintroduzindo acoplamento a
`app.current_tenant_id` por composição de RLS entre tabelas (C2). Um terceiro problema estrutural
(C3, bloqueio total de `INSERT` de `Vinculo` novo) foi descoberto durante a correção de C1. Os 3
foram corrigidos com funções `SECURITY DEFINER` hardened e revalidados empiricamente, com
reprodutibilidade em 2 execuções — ver `RLS_POC_CORRECTION_REPORT.md` (gate:
`RLS PÓS-SEC — CORREÇÕES DO PoC VALIDADAS E APTAS PARA REVISÃO PRÉ-NEON`, `CRITICAL=0`/
`RELEVANTE=0`). Este documento e `RLS_MATRIX.md` foram atualizados para refletir o desenho
corrigido; a evidência original das falhas permanece preservada em `RLS_POC_REPORT.md`.

## 6. Como aplicar quando autorizado (não executado nesta sessão)

1. Resolver D2 (decisão humana).
2. Rodar `RLS_TEST_PLAN.md` completo em PostgreSQL 15 descartável (Docker), mesma metodologia de
   `ADR-C005`/`ADR-C014` — checksum, reprodutibilidade em 2 containers.
3. Só então mover `20260917130000_rls_tenant_isolation_DRAFT/` para um nome de migration Prisma
   real (padrão `<timestamp>_rls_tenant_isolation/`) e rodar `prisma migrate deploy` — **não**
   `prisma db push` (perderia o registro em `_prisma_migrations`).
4. Nunca aplicar diretamente ao Neon DEV sem antes ter rodado o passo 2 em ambiente descartável.
