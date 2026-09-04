# ADR-001 — Schema Físico PostgreSQL/Prisma da CONTIFISC

**Versão:** 1.1  
**Status:** APROVADO — revisão pós-SEC; define a representação física da baseline canônica
pós-SEC, sem ainda alterar `schema.prisma`, criar migration, ou tocar banco.  
**Tipo:** Architecture Decision Record  
**Supersede:** ADR-001 V1.0 (incluindo Errata de publicação e Errata controlada nº2)  
**Baseline obrigatória:** `SEC-001` V1.0, `SEC-CHANGE-REQUEST-001` V1.1, `COT-001` V1.2,
`MCD-001` V1.4, `DST-001` V1.3, `CDC-001` V1.4, `SEC-CR-001_RECONCILIACAO_FINAL_V1.0.md`  
**Escopo:** decisões físicas de persistência relacional para a baseline canônica **completa**
(domínio tributário + domínio de segurança/tenant); não altera o domínio canônico, não cria
`schema.prisma`, migration, RLS, autenticação ou aplicação.

> Este ADR traduz a baseline canônica pós-SEC para PostgreSQL/Prisma. Quando houver conflito, COT/MCD/CDC/DST prevalecem. O schema físico não pode criar significado tributário ou de segurança novo.

## 0. O que esta revisão faz e não faz

**Faz:** define como `Tenant`, `UnidadeEconomica.tenant_id`, `unidade_economica_id` transversal,
`tenant_id` transversal, `ContaAcesso`, `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica` e
`EventoAuditoriaSeguranca` serão representados fisicamente; define a matriz de estratégia RLS
completa (25 tabelas); define a estratégia de contexto de sessão; formaliza a decisão sobre a
migration inaugural pós-SEC.

**Não faz:** não escreve `CREATE POLICY`, não altera `schema.prisma`, não cria migration, não
implementa autenticação, não decide fornecedor de auth, não resolve nenhum gap de vocabulário
DST/CDC por decisão física, não antecipa `OBS-001`/`EVT-001`/`INT-001`.

**Preservação:** todas as decisões físicas da V1.0 (incluindo as duas erratas) permanecem
vigentes e são reproduzidas nesta versão, exceto onde esta revisão registra explicitamente uma
extensão ou, em um único ponto (§13, mutabilidade de `MCD-F10004`), uma nota de política dividida
— nunca uma reabertura de decisão sem conflito concreto com a baseline pós-SEC.

---

### Errata de publicação V1.0 (preservada, histórico)

Antes da aprovação da V1.0, a publicação foi corrigida em quatro pontos, sem mudança conceitual:
(1) fixado `relationMode = "foreignKeys"` (`ADR-D013`); (2) `ADR-D007` corrigido para citar
`NUMERIC(7,4)` diretamente; (3) `competencia` corrigida de `CHAR(7)` para `VARCHAR(7)`; (4)
declarada `PostgreSQL >= 15` (`ADR-D014`).

### Errata controlada nº2 (preservada, histórico) — Estratégia física dos campos transversais MCD-F9001..F9010

**Data:** 2026-08-31. Incorporou `ADR-D015..D019` e os gaps `ADR-GAP-007`/`ADR-GAP-008`
(proveniência/estado duplo/registro canônico/data do fato/evidência RAW transversal dos 10
campos `DOM-SYS`). Ver o texto integral desta errata no histórico (`docs/legacy/ADR-001_..._V1.0.md`
após esta publicação) — reproduzida sem alteração nas decisões `ADR-D015..D019` e nos gaps
`ADR-GAP-007`/`ADR-GAP-008` (§2/§14 desta V1.1).

---

## 1. Contexto e decisão

A CONTIFISC utilizará PostgreSQL como banco relacional canônico e Prisma como tooling de
acesso/migrations. Prisma não é a autoridade do modelo: constraints que ele não expressa
nativamente serão materializadas por SQL PostgreSQL versionado dentro da migration. O GTI
permanece um grafo lógico/read model derivado do modelo relacional.

**Extensão pós-SEC:** a partir desta revisão, o mesmo princípio se aplica ao domínio de
segurança/tenant — `Tenant`, isolamento e autorização são decisões físicas subordinadas à baseline
canônica (`SEC-001`/`SEC-CHANGE-REQUEST-001`/`COT`/`MCD`/`CDC`), nunca inventadas pelo schema.

## 2. Decisões físicas fundamentais

### 2.1 Decisões preservadas da V1.0 (nenhuma reaberta sem conflito concreto)

| ID | Tema | Decisão | Justificativa |
|---|---|---|---|
| ADR-D001 | Banco relacional | PostgreSQL | Baseline canônica é relacional; GTI é read model lógico. |
| ADR-D002 | ORM/tooling | Prisma subordinado ao PostgreSQL | Constraints não suportadas pelo Prisma são SQL explícito versionado. |
| ADR-D003 | Nomes físicos | snake_case em português canônico | Rastreabilidade MCD→DB. |
| ADR-D004 | PK | id UUID | Identidade canônica e integração distribuída. |
| ADR-D005 | FK | `<objeto>_id` UUID | Mesmo nome canônico do MCD. |
| ADR-D006 | Valores monetários | NUMERIC(18,2) | Float/double proibidos. |
| ADR-D007 | Percentuais | NUMERIC(7,4) | Escala fixada pelo MCD-001 §5. |
| ADR-D008 | Competência | VARCHAR(7) + CHECK YYYY-MM | Não é DATE; primeiro dia fictício proibido. |
| ADR-D009 | Timestamps | TIMESTAMPTZ | Persistência temporal inequívoca. |
| ADR-D010 | Enums | Texto/código + CHECK/lookup conforme estabilidade | Evita acoplamento a PostgreSQL ENUM; Enum/Ref aberto não recebe CHECK fechado. |
| ADR-D011 | Soft lifecycle | Sem hard delete por padrão | Fatos/evidências/auditoria preservam histórico. |
| ADR-D012 | Proveniência | Metadados preservados; RAW imutável | Reprocessamento não destrói evidência. |
| ADR-D013 | Prisma relationMode | `foreignKeys` obrigatório | Integridade referencial no PostgreSQL, nunca emulada no client. |
| ADR-D014 | Versão PostgreSQL | `>= 15` | Baseline técnica para `gen_random_uuid()` nativo etc. |
| ADR-D015 | Proveniência de origem (F9001/F9002/F9003) | Coluna em `receita`/`contribuicao_previdenciaria`/`evento_irpf`/`documento_fiscal` | Sem entidade genérica de proveniência. |
| ADR-D016 | Estado duplo (F9004/F9010) | Coluna nos mesmos 4 objetos, eixos independentes | Nenhuma sincronização entre processamento/qualidade. |
| ADR-D017 | Registro canônico (F9007) | Coluna `registrado_em` em 16 objetos | `unidade_economica`/`classificacao_equiparacao_hospitalar` confirmados equivalentes; `resultado_calculo`/`revisao_tecnica` pendentes (`ADR-GAP-008`). |
| ADR-D018 | Data do fato (F9008) | Coluna `data_fato` em `receita`/`contribuicao_previdenciaria`/`evento_irpf` | Três fatos puros. |
| ADR-D019 | Evidência RAW transversal (F9009) | Via relacionamento existente em `documento_fiscal`; gap nos demais (`ADR-GAP-007`) | Sem FK por inferência. |

**Nenhuma das decisões acima conflita com a baseline pós-SEC** — todas seguem vigentes sem
alteração.

### 2.2 Novas decisões físicas pós-SEC

| ID | Tema | Decisão | Justificativa |
|---|---|---|---|
| **ADR-D020** | `Tenant` físico | Tabela `tenant` com apenas `id UUID PRIMARY KEY`. Nenhuma coluna de negócio (`nome`, `status`) — bloqueado até Change Request de autenticação/RBAC (`GAP-CDC-1.3-001`). | `MCD-F10001`/`CDC-SEC-001`: representação mínima deliberada, mesmo padrão já usado para `classificacao_equiparacao_hospitalar` na V1.0 (nenhuma coluna especulativa). |
| **ADR-D021** | `UnidadeEconomica.tenant_id` | Coluna `tenant_id UUID NOT NULL`, FK simples para `tenant(id)` (`RESTRICT` — ver §8), **mais** `UNIQUE(id, tenant_id)` como chave candidata (`ADR-C011`, §5). | `MCD-F10002`: âncora raiz do isolamento, sempre presente, nunca nula. A chave candidata viabiliza uma futura FK composta a partir de qualquer tabela que venha a materializar `tenant_id` denormalizado junto de `unidade_economica_id` — sem forçar essa denormalização agora (§4 explica por que não existe hoje). |
| **ADR-D022** | `unidade_economica_id` nos 6 hospedeiros de `MCD-F10004` | Coluna `unidade_economica_id UUID NOT NULL` em `receita`, `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`, `resultado_calculo`. FK **simples** para `unidade_economica(id)` — **não composta** (ver §4 para a justificativa detalhada). `ON DELETE RESTRICT` em todos os 6 (fato/evidência/resultado nunca desaparece por cascade). | `SEC-001` §11 classifica estas 6 tabelas como `TENANT_DERIVADO_POR_RLS` — o isolamento por tenant nestas tabelas é feito por **join de 1 hop até `unidade_economica.tenant_id`** dentro da política RLS (§9), nunca por uma coluna `tenant_id` própria. Adicionar uma coluna `tenant_id` denormalizada a estas 6 tabelas reabriria essa classificação já aprovada sem conflito concreto — não decidido por este ADR. |
| **ADR-D023** | `tenant_id` materializado em `ArquivoOrigem`/`ConflitoDado`/`RevisaoTecnica` | Coluna `tenant_id UUID NOT NULL` em `arquivo_origem`, `conflito_dado`, `revisao_tecnica`. FK simples para `tenant(id)`, `ON DELETE RESTRICT`. **Nunca populada por valor arbitrário do cliente/API** — ver §5 para o mecanismo de proveniência. | `MCD-F10003`/`SEC-001` §5/§6/§8: metadado transversal de segurança, carimbado pelo contexto operacional que cria o registro. `SEC-001` §11 classifica estas 3 como `TENANT_ID_MATERIALIZADO`. |
| **ADR-D024** | `ConflitoDadoItem` — reafirmação | **Nenhuma coluna nova.** Tenant deriva exclusivamente via `conflito_dado_id → conflito_dado.tenant_id` (join, não coluna própria). | `MCD-F8651` (FK já vigente, `NOT NULL`); `SEC-001` §7; `SEC-001` §11 classifica como `TENANT_DERIVADO_DO_PAI`. A referência polimórfica (`objeto_id`/`tipo_objeto`) permanece exceção controlada de auditoria — nunca fonte de tenant. |
| **ADR-D025** | `ContaAcesso` físico | Tabela `conta_acesso` com apenas `id UUID PRIMARY KEY`. **Nenhuma coluna de autenticação** — sem `senha`/`hash`/`email`/`oauth_provider`/`refresh_token`/`mfa_*`/`sessao_id`/qualquer campo específico de Auth.js ou outro provedor. `tipo` (`HUMANA`/`SERVICO`, `SEC-001` §13) não incorporado — `GAP-CDC-1.4-002`. | `MCD-F10007`/`CDC-SEC-005`: identidade canônica mínima, exatamente o aprovado na correção pós-SEC. |
| **ADR-D026** | `ContaAcessoTenant` físico | Tabela `conta_acesso_tenant`: `id UUID PK`, `conta_acesso_id UUID NOT NULL FK→conta_acesso(id)`, `tenant_id UUID NOT NULL FK→tenant(id)`, `papel TEXT NOT NULL` (Enum/Ref aberto, **sem CHECK fechado** — `DST-GAP-015`). `UNIQUE(conta_acesso_id, tenant_id)` (`ADR-C012`). `ON DELETE RESTRICT` em ambas as FKs (revogar uma concessão é uma operação explícita de aplicação, nunca um efeito colateral de excluir a conta ou o tenant). | `MCD-F10008` (`conta_acesso_id`)/`MCD-F10009` (`id`)/`MCD-F10010` (`tenant_id`)/`MCD-F10005` (`papel`), `CDC-SEC-003`, `CDC-REL-SEC-005`. |
| **ADR-D027** | `ContaAcessoUnidadeEconomica` físico | Tabela `conta_acesso_unidade_economica`: `id UUID PK`, `conta_acesso_id UUID NOT NULL FK→conta_acesso(id)`, `unidade_economica_id UUID NOT NULL FK→unidade_economica(id)`, `papel TEXT NOT NULL`. `UNIQUE(conta_acesso_id, unidade_economica_id)` (`ADR-C013`). `ON DELETE RESTRICT` em ambas as FKs. **Mecanismo adicional obrigatório** (`ADR-C014`, §5/§8): toda linha desta tabela deve corresponder a uma linha de `conta_acesso_tenant` para o mesmo `conta_acesso_id` e o `tenant_id` da UE referenciada — não expressável por FK simples (ver §8). | `MCD-F10008` (`conta_acesso_id`)/`MCD-F10011` (`id`)/`MCD-F10012` (`unidade_economica_id`)/`MCD-F10005` (`papel`), `CDC-SEC-004`, `CDC-REL-SEC-006/007`. |
| **ADR-D028** | Contexto de sessão RLS | `SET LOCAL app.current_tenant_id = '<uuid>'` como **primeira instrução de toda transação** que toca dado tenant-scoped. Leitura via `current_setting('app.current_tenant_id', true)` (o segundo argumento `true` faz retornar `NULL`/string vazia em vez de erro quando não setado — necessário para o comportamento fail-closed). Nunca `SET` de sessão. | `SEC-001` §14: `SET LOCAL` é transacional (revertido automaticamente em `COMMIT`/`ROLLBACK`), mitigando estruturalmente o risco de contexto residual em conexões de pool — o principal vetor de falha do modelo, já identificado pelo `SEC-001`. |
| **ADR-D029** | `EventoAuditoriaSeguranca` físico | Tabela `evento_auditoria_seguranca` com apenas `id UUID PRIMARY KEY`. **Nenhuma outra coluna** — ator, tenant, UE, operação, objeto afetado, instante e resultado permanecem bloqueados (`GAP-CDC-1.3-002`, dependente de Change Request de autenticação/RBAC e, para o ator, de `OBS-001`). Tabela `INSERT`-only por convenção de aplicação (ver §8) — nenhum mecanismo de `REVOKE UPDATE/DELETE` a nível de role é decidido por este ADR (isso é uma decisão de provisionamento de banco/role, não de schema, e depende de haver colunas reais para auditar). | `MCD-F10006`/`CDC-SEC-002`. Não antecipa `EVT-001` (arquitetura de eventos de domínio genérica) nem confunde com log técnico ou `Sessao` (`SEGURANCA_OPERACIONAL`, fora do modelo canônico). |
| **ADR-D030** | Mapeamento físico de mutabilidade | Ver §13 (seção dedicada, por exigência explícita da revisão). | `MCD-001` V1.4 §8.1 — política de mutabilidade dividida de `MCD-F10004`. |

## 3. Mapeamento de objetos/estruturas para relações físicas

### 3.1 Domínio tributário (preservado da V1.0, sem alteração)

| Relação física | COT | CDC | Observação |
|---|---|---|---|
| unidade_economica | COT-OBJ-001 | CDC-UE-001 | Ganha `tenant_id` (`ADR-D021`). |
| pessoa_fisica | COT-OBJ-002 | CDC-PER-001 | Sem alteração — identidade global. |
| pessoa_juridica | COT-OBJ-003 | CDC-EMP-001 | Sem alteração — identidade global. |
| vinculo | COT-OBJ-004 | CDC-REL-001 | Sem alteração. |
| vinculo_extremidade | COT-SUP-001 | CDC-REL-002 | Sem alteração — `ADR-C005` validada (ver §5.1). |
| receita | COT-OBJ-005 | CDC-REC-001 | Ganha `unidade_economica_id` (`ADR-D022`). |
| documento_fiscal | COT-OBJ-006 | CDC-FIS-001 | Ganha `unidade_economica_id` (`ADR-D022`). |
| receita_documento_fiscal | COT-SUP-002 | CDC-FIS-002 | Sem alteração. |
| arquivo_origem | COT-OBJ-007 | CDC-ARQ-001 | Ganha `tenant_id` (`ADR-D023`). |
| documento_fiscal_arquivo_origem | COT-SUP-003 | CDC-FIS-003 | Sem alteração. |
| classificacao_equiparacao_hospitalar | COT-OBJ-008 | CDC-EH-001 | Sem alteração. |
| contribuicao_previdenciaria | COT-OBJ-009 | CDC-PRE-001 | Ganha `unidade_economica_id` (`ADR-D022`). |
| vinculo_previdenciario | COT-OBJ-010 | CDC-PREV-001 | Ganha `unidade_economica_id` (`ADR-D022`). |
| evento_irpf | COT-OBJ-011 | CDC-IRP-001 | Ganha `unidade_economica_id` (`ADR-D022`). |
| fonte_pagadora | COT-OBJ-012 | CDC-FPG-001 | Sem alteração — identidade global. |
| cenario_tributario | COT-OBJ-013 | CDC-PLN-001 | Sem alteração. |
| resultado_calculo | COT-OBJ-014 | CDC-CAL-001 | Ganha `unidade_economica_id` **imutável** (`ADR-D022`+`ADR-D030`). |
| conflito_dado | COT-OBJ-015 | CDC-CFD-001 | Ganha `tenant_id` (`ADR-D023`). |
| conflito_dado_item | COT-SUP-004 | CDC-CFD-002 | Sem alteração (`ADR-D024`). |
| revisao_tecnica | COT-OBJ-016 | CDC-REV-001 | Ganha `tenant_id` (`ADR-D023`). |

### 3.2 Domínio de segurança (novo nesta revisão)

| Relação física | COT | CDC | Observação |
|---|---|---|---|
| tenant | COT-OBJ-019 | CDC-SEC-001 | `ADR-D020`. |
| conta_acesso | COT-OBJ-017 | CDC-SEC-005 | `ADR-D025`. **Antes fora do primeiro schema (V1.0 §3); agora dentro, com escopo mínimo.** |
| conta_acesso_tenant | COT-SUP-005 | CDC-SEC-003 | `ADR-D026`. |
| conta_acesso_unidade_economica | COT-SUP-006 | CDC-SEC-004 | `ADR-D027`. |
| evento_auditoria_seguranca | COT-OBJ-020 | CDC-SEC-002 | `ADR-D029`. |

**Ainda fora do schema autorizado por este ADR:** `credencial_acesso` (`COT-OBJ-018`) — sem
nenhum campo MCD; permanece integralmente diferido. Nenhuma tabela física é proposta para ele.

**Total de relações físicas propostas nesta revisão: 25** (20 do domínio tributário + 5 do
domínio de segurança).

## 4. Contexto UE nos fatos — por que a FK é simples, não composta

Os 6 hospedeiros de `MCD-F10004` (`receita`, `contribuicao_previdenciaria`,
`vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`, `resultado_calculo`) recebem:

| Aspecto | Decisão |
|---|---|
| Tipo físico | `UUID` |
| FK | Simples: `unidade_economica_id → unidade_economica(id)` |
| Nullability | `NOT NULL` em todos os 6 (conforme MCD/CDC, obrigatoriedade `Sim`/`required`) |
| Comportamento de delete | `RESTRICT` — fato/evidência/resultado nunca desaparece por cascade (`ADR-D011`, política já vigente desde a V1.0 §8) |
| Compatibilidade com tenant | Via **join de 1 hop** na política RLS (§9), não via coluna própria |

**Por que nenhuma FK composta `(unidade_economica_id, tenant_id) → unidade_economica(id, tenant_id)`
é criada nestas 6 tabelas nesta revisão:** essa FK composta só é definível se a própria tabela
possuir uma coluna `tenant_id`. **Nenhuma das 6 tabelas possui essa coluna** — e adicioná-la agora
seria uma decisão de denormalização não aprovada, que reabriria a classificação já aprovada em
`SEC-001` §11 (`TENANT_DERIVADO_POR_RLS` para estas 6, distinta de `TENANT_ID_MATERIALIZADO` para
`ArquivoOrigem`/`ConflitoDado`/`RevisaoTecnica`). A estrutura necessária para uma eventual FK
composta futura é preparada do lado de `unidade_economica` (`UNIQUE(id, tenant_id)`, `ADR-C011`,
§5) — mas seu uso como alvo de uma FK composta a partir destes 6 hospedeiros fica **explicitamente
não decidido**, condicionado a uma futura decisão de denormalizar `tenant_id` nessas tabelas, que
não é feita por este ADR.

**Nenhum objeto atual possui `unidade_economica_id` e `tenant_id` simultaneamente como colunas
próprias** — verificado contra o catálogo `MCD-001` V1.4 completo. A instrução de "impedir
fisicamente combinação cross-tenant quando ambos coexistirem" não tem, portanto, alvo aplicável
nesta revisão; a garantia de que `unidade_economica_id` aponta para uma UE do tenant correto é
inteiramente responsabilidade da política RLS (join), não de uma constraint declarativa de linha
única nestas 6 tabelas.

## 5. Constraints obrigatórias

### 5.1 Preservadas da V1.0 (`ADR-C001..C010`) — sem alteração

| ID | Relação | Constraint | Status |
|---|---|---|---|
| ADR-C001 | receita | CHECK XOR PF/PJ | Validado (`INTEGRATION_TEST_REPORT.md` §4). |
| ADR-C002 | vinculo_extremidade | CHECK XOR de endpoint | Validado. |
| ADR-C003 | vinculo_extremidade | UNIQUE(vinculo_id, lado_extremidade) | Validado. |
| ADR-C004 | vinculo_extremidade | CHECK lado_extremidade | Validado. |
| ADR-C005 | vinculo | Constraint trigger `DEFERRABLE INITIALLY DEFERRED` — exatamente 2 extremidades (ORIGEM+DESTINO) | **Validado empiricamente** — PoC em PostgreSQL 15 descartável, 9 cenários, reproduzido em 2 bancos independentes (`INTEGRATION_TEST_REPORT.md` §5, §10). Nenhuma alteração proposta. |
| ADR-C006 | receita_documento_fiscal | UNIQUE(receita_id, documento_fiscal_id) | Validado. |
| ADR-C007 | documento_fiscal_arquivo_origem | Unicidade mínima | Validado; revisão pendente quando `papel_arquivo` fechar. |
| ADR-C008 | classificacao_equiparacao_hospitalar | PK própria + histórico não destrutivo | Validado. |
| ADR-C009 | competencia | CHECK formato/mês | Validado. |
| ADR-C010 | conflito_dado_item | Validação de referência polimórfica por serviço de domínio | Validado (sem FK genérica). |

**Nenhuma constraint validada pelo PoC `ADR-C005` é reaberta.** O achado operacional do teste de
integração (§5 do relatório: o trigger, por não ter exceção para remoção completa, impede
esvaziar as extremidades de um `Vinculo` até 0 dentro de uma transação simples) permanece
registrado como consideração para um futuro mecanismo de exclusão/lifecycle — fora do escopo desta
revisão, não uma falha da regra.

### 5.2 Novas constraints pós-SEC

| ID | Relação | Constraint | Objetivo | Implementação | Status |
|---|---|---|---|---|---|
| **ADR-C011** | unidade_economica | `UNIQUE(id, tenant_id)` | Chave candidata para viabilizar uma futura FK composta a partir de qualquer tabela que venha a denormalizar `tenant_id` junto de `unidade_economica_id` (não aplicada por nenhuma tabela nesta revisão — §4). | `@@unique([id, tenant_id])` no Prisma; `UNIQUE` nativo no PostgreSQL. | Proposta, **não validada por PoC** — é uma `UNIQUE` simples sobre uma coluna já `NOT NULL`/já `UNIQUE` isoladamente (`id`); risco de incompatibilidade é baixo, mas nenhuma migration real a testou ainda. |
| **ADR-C012** | conta_acesso_tenant | `UNIQUE(conta_acesso_id, tenant_id)` | No máximo uma concessão por par — materializa `CDC-REL-SEC-005`. | `@@unique` no Prisma + `UNIQUE` no PostgreSQL. | Proposta, não validada por PoC — mesma natureza simples de `ADR-C006`/`C007`, já validados para o mesmo padrão estrutural (par de FKs). |
| **ADR-C013** | conta_acesso_unidade_economica | `UNIQUE(conta_acesso_id, unidade_economica_id)` | No máximo uma restrição por par — materializa `CDC-REL-SEC-006`. | Idem `ADR-C012`. | Proposta, não validada por PoC. |
| **ADR-C014** | conta_acesso_unidade_economica × conta_acesso_tenant | Toda linha de `conta_acesso_unidade_economica` deve corresponder a uma linha de `conta_acesso_tenant` com o mesmo `conta_acesso_id` e o `tenant_id` da `unidade_economica` referenciada — materializa `CDC-REL-SEC-007` ("restrição sem concessão prévia é dado inválido"). | **Não expressável por FK simples nem por FK composta direta** — exige resolver `unidade_economica_id → unidade_economica.tenant_id` (um join) e então verificar a existência de `(conta_acesso_id, tenant_id_resolvido)` em outra tabela. Mecanismo proposto: **constraint trigger** (mesma classe de mecanismo já validada por `ADR-C005`), avaliada em `INSERT`/`UPDATE` de `conta_acesso_unidade_economica`. Pode ser `DEFERRABLE` ou não-diferida — a decidir na PoC, já que (diferente de `Vinculo`, que precisa de duas linhas simultâneas) esta validação não depende de uma segunda linha ainda não inserida na mesma transação. | **Não implementada. Não validada — exige sua própria PoC antes de qualquer migration**, seguindo o mesmo padrão metodológico já usado para `ADR-C005` (ADR propõe → PoC isolada valida → só então migration). |
| **ADR-C015** | (nenhuma constraint SQL nova) | Imutabilidade de campos `Imutável`, incluindo `resultado_calculo.unidade_economica_id` | Ver §13 — **decisão explícita de não criar mecanismo de trigger de imutabilidade nesta revisão**, por consistência com o tratamento já vigente (nenhum dos demais campos `Imutável` do baseline V1.0 tem trigger de imutabilidade; a garantia é de aplicação/contrato, não de banco). | N/A | Decisão física registrada, sem ID de constraint SQL — ver §13 para o raciocínio completo. |

### 5.3 Nota sobre `ADR-C014` e o princípio de não invenção

`ADR-C014` é a única constraint desta revisão que **não pode ser declarada** apenas como decisão
— precisa da mesma disciplina empírica já usada para `ADR-C005`: proposta no ADR, validada por PoC
isolada em PostgreSQL descartável, e só então elegível para entrar em uma migration real. Este ADR
**não a implementa nem a testa** — apenas a especifica e determina que ela bloqueia a materialização
física de `conta_acesso_unidade_economica` até ser validada (ver §14, classificação de impacto).

## 6. Prisma versus PostgreSQL

Preservado da V1.0, com uma linha nova:

| Recurso | Prisma | PostgreSQL | Política |
|---|---|---|---|
| PK/FK | Modelável | Nativo | Declarar em ambos. |
| UNIQUE composto | `@@unique` | UNIQUE | Declarar no Prisma e validar migration. `ADR-C011`/`C012`/`C013` seguem este padrão. |
| CHECK XOR | Não representável no schema | CHECK | SQL manual. |
| CHECK competência | Não representável | CHECK | SQL manual. |
| Constraint trigger diferida | Não | Trigger/function | SQL manual + testes de integração (`ADR-C005`, validado). |
| **Constraint trigger de dependência cross-table (`ADR-C014`)** | **Não representável de nenhuma forma** — Prisma não tem conceito de trigger nem de validação condicionada a outra tabela | Trigger/function | SQL manual + PoC própria antes de qualquer migration — nova categoria de constraint para este projeto, mais complexa que `ADR-C005` por envolver duas tabelas e um join de resolução. |
| Partial index | Limitado | Nativo | SQL manual quando aprovado. |
| Decimal | Decimal | NUMERIC | Usar Decimal ponta a ponta. |
| Enum aberto | Não usar enum fechado | TEXT/REF | Sem inventar valores — inclui `papel` (`ADR-D026`/`D027`). |
| relationMode | `foreignKeys` (obrigatório) | FK nativa | `relationMode = "prisma"` proibido. |
| **RLS** | **Nenhum suporte nativo** — Prisma não modela `ENABLE ROW LEVEL SECURITY` nem `CREATE POLICY` | Nativo (`pg_policies`) | 100% SQL manual, fora do `schema.prisma`, versionado na migration (§9). |
| **Contexto de sessão (`SET LOCAL`)** | **Não gerenciado pelo Prisma** — precisa ser emitido como raw query no início de cada transação | `current_setting()`/`set_config()` | Camada de aplicação (middleware Prisma ou wrapper de transação) deve emitir `SET LOCAL app.current_tenant_id` antes de qualquer outra instrução da transação — decisão de implementação, não deste ADR. |

## 7. Índices

Preservado da V1.0 (`IDX-001..005`), mais:

| ID | Alvo | Estratégia | Motivo |
|---|---|---|---|
| IDX-001 | Todas FKs | B-tree | PostgreSQL não indexa FK automaticamente — inclui as novas FKs de `tenant_id`/`unidade_economica_id`/`conta_acesso_id` desta revisão. |
| IDX-002 | Fatos por competência | (owner/fonte, competencia) conforme objeto | Consultas fiscais/temporais. |
| IDX-003 | Proveniência | (sistema_origem, identificador_origem) quando aplicável | Idempotência/reconciliação; unique apenas se contrato da fonte garantir unicidade. |
| IDX-004 | Documento fiscal | Chaves fiscais/identificadores normalizados conforme MCD | Busca e deduplicação; constraint concreta depende dos campos MCD. |
| IDX-005 | Status | Índice isolado somente se seletividade justificar | Evitar indexação automática de enums de baixa cardinalidade. |
| **IDX-006** *(novo)* | `unidade_economica.tenant_id` | B-tree | Toda política RLS `TENANT_DERIVADO_POR_RLS` (§9) fará join por este campo — sem índice, cada leitura tenant-scoped nos 6 hospedeiros de `MCD-F10004` degradaria para scan. |
| **IDX-007** *(novo)* | `arquivo_origem.tenant_id`, `conflito_dado.tenant_id`, `revisao_tecnica.tenant_id` | B-tree | Filtro direto de RLS (`TENANT_ID_MATERIALIZADO`). |
| **IDX-008** *(novo)* | `conta_acesso_tenant(conta_acesso_id, tenant_id)`, `conta_acesso_unidade_economica(conta_acesso_id, unidade_economica_id)` | Já cobertos pelas `UNIQUE` de `ADR-C012`/`C013` (um índice único serve de índice de consulta) | Resolução de autorização (quais tenants/UEs uma conta acessa) é consultada a cada requisição — a `UNIQUE` já fornece o índice necessário, sem índice adicional. |

## 8. Política de deleção e histórico

Preservado da V1.0 (`§8`), estendido para o domínio de segurança:

| Classe | Política padrão | Regra |
|---|---|---|
| Fatos tributários, evidência RAW, associações N:N, Vinculo, Cenários | Inalterado da V1.0 | Ver tabela original. |
| **`tenant`** | `RESTRICT` em qualquer FK que aponte para ele | Um `Tenant` referenciado por qualquer `UnidadeEconomica`, `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica` ou `ContaAcessoTenant` não pode ser excluído por cascade — exclusão de tenant é uma operação administrativa própria, fora do escopo deste ADR. |
| **`conta_acesso`** | `RESTRICT` em `conta_acesso_tenant`/`conta_acesso_unidade_economica` | Revogar todas as concessões de uma conta é uma operação explícita (excluir as linhas de associação), não um efeito colateral de excluir a `ContaAcesso`. |
| **`conta_acesso_tenant`/`conta_acesso_unidade_economica`** | Exclusão direta permitida (linha de associação, não fato tributário) | Revogação de acesso é uma operação de segurança legítima — ao contrário de fatos tributários, não há razão para preservar uma concessão revogada como linha ativa; auditoria da revogação é responsabilidade de `EventoAuditoriaSeguranca` (quando detalhado), não da preservação da própria linha de concessão. |
| **`evento_auditoria_seguranca`** | **`INSERT`-only por convenção de aplicação** — nenhuma política de `UPDATE`/`DELETE` é decidida nesta revisão (a tabela só tem `id`; não há o que atualizar) | Trilho de auditoria de segurança é, por natureza (`SEC-001` §16), append-only. A garantia física completa (ex.: `REVOKE UPDATE, DELETE` do role de aplicação) depende de a tabela ter colunas reais e de uma decisão de provisionamento de banco — registrada como pendência para quando `EventoAuditoriaSeguranca` for detalhado, não decidida agora. |

**Proveniência de `tenant_id` materializado (`ADR-D023`) — nunca valor arbitrário do
cliente/API:** o valor de `tenant_id` em `arquivo_origem`/`conflito_dado`/`revisao_tecnica` deve
ser **preenchido pela camada de aplicação a partir do contexto de sessão autenticado** (a mesma
variável `app.current_tenant_id` usada pela RLS, §9) no momento do `INSERT` — nunca aceito como
campo de payload vindo diretamente de uma requisição de API. Isso é uma responsabilidade da camada
de execução/aplicação, **não expressável como constraint SQL declarativa** (o banco não sabe
distinguir "veio do payload" de "veio da sessão"): a verificação de que o `tenant_id` inserido
corresponde ao contexto de sessão fica delegada à política RLS de `INSERT` (`WITH CHECK`, quando
as policies forem escritas) — este ADR apenas determina o requisito e o mecanismo esperado
(`WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid)`), sem criar a policy.

**Mecanismo para `ADR-D027`/`ADR-C014` (restrição de UE requer concessão de Tenant):** como
detalhado em §5.3, este é o único invariante desta revisão que precisa de um mecanismo de banco
ainda não validado (constraint trigger cross-table). Até essa PoC ser conduzida, a garantia
equivalente deve ser reforçada pela camada de aplicação (nunca criar uma linha de
`conta_acesso_unidade_economica` sem antes verificar a existência da concessão de Tenant
correspondente) — mas isso é uma mitigação de aplicação, **não um substituto** da constraint física
planejada.

## 9. Multi-tenant e segurança — estratégia física de RLS (conceitual, sem policies)

A baseline canônica pós-SEC está reconciliada (`SEC-CR-001_RECONCILIACAO_FINAL_V1.0.md`:
`BASELINE CANÔNICA PÓS-SEC RECONCILIADA — APTA PARA ADR`). Esta seção define a **estratégia**
física de RLS — **nenhuma `CREATE POLICY` é escrita nesta revisão.**

### 9.1 Matriz completa de classificação (25 tabelas)

| # | Tabela | Estratégia | Mecanismo de derivação de tenant |
|---|---|---|---|
| 1 | `unidade_economica` | `TENANT_ID_RAIZ` | Coluna própria `tenant_id`. |
| 2 | `pessoa_fisica` | `GLOBAL_COMPARTILHADO` | Sem tenant — identidade global (`SEC-001` §3). |
| 3 | `pessoa_juridica` | `GLOBAL_COMPARTILHADO` | Idem. |
| 4 | `fonte_pagadora` | `GLOBAL_COMPARTILHADO` | Idem. |
| 5 | `vinculo` | `TENANT_DERIVADO_POR_RLS` | Join até `vinculo_extremidade` → `unidade_economica.tenant_id` (quando a extremidade for UE; exceção residual quando nenhuma extremidade for UE, `DST-GAP-003`/`GAP-SEC-CR1-002`). |
| 6 | `vinculo_extremidade` | `TENANT_DERIVADO_POR_RLS` | Join até `unidade_economica.tenant_id` via `unidade_economica_id`. |
| 7 | `receita` | `TENANT_DERIVADO_POR_RLS` | Join até `unidade_economica.tenant_id` via `unidade_economica_id` (`MCD-F10004`). |
| 8 | `contribuicao_previdenciaria` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 9 | `vinculo_previdenciario` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 10 | `evento_irpf` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 11 | `documento_fiscal` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 12 | `arquivo_origem` | `TENANT_ID_MATERIALIZADO` | Coluna própria `tenant_id`. |
| 13 | `receita_documento_fiscal` | `TENANT_DERIVADO_POR_RLS` | Join via `receita_id` (ou `documento_fiscal_id`) até `unidade_economica.tenant_id`. |
| 14 | `documento_fiscal_arquivo_origem` | `TENANT_DERIVADO_POR_RLS` | Join via `documento_fiscal_id`. |
| 15 | `classificacao_equiparacao_hospitalar` | `TENANT_DERIVADO_POR_RLS` | Join via `receita_id`. |
| 16 | `cenario_tributario` | `TENANT_DERIVADO_POR_RLS` | Join via `unidade_economica_id` (coluna própria pré-existente, `MCD-F8005`). |
| 17 | `resultado_calculo` | `TENANT_DERIVADO_POR_RLS` | Join via `unidade_economica_id` (`MCD-F10004`). |
| 18 | `conflito_dado` | `TENANT_ID_MATERIALIZADO` | Coluna própria `tenant_id`. |
| 19 | `conflito_dado_item` | `TENANT_DERIVADO_DO_PAI` | Join via `conflito_dado_id` → `conflito_dado.tenant_id`. |
| 20 | `revisao_tecnica` | `TENANT_ID_MATERIALIZADO` | Coluna própria `tenant_id`. |
| **21** | **`tenant`** | **`RAIZ_PROPRIA_VISIVEL_POR_CONCESSAO`** *(nova categoria)* | A própria linha **é** o tenant — não tem `tenant_id` de saída. Visibilidade: uma `ContaAcesso` só deve ver linhas de `tenant` para as quais possui concessão em `conta_acesso_tenant` (join reverso). Não é "derivado de", é "visível através de". |
| **22** | **`conta_acesso`** | **`GLOBAL_COMPARTILHADO`** | Sem tenant — mesma categoria de `pessoa_fisica`/`pessoa_juridica`/`fonte_pagadora`: uma `ContaAcesso` pode ter concessões em múltiplos tenants (funcionário CONTIFISC multi-cliente). O isolamento acontece nas tabelas de associação e nos fatos, nunca na existência da conta em si. |
| **23** | **`conta_acesso_tenant`** | **`TENANT_ID_MATERIALIZADO`** | Coluna própria `tenant_id` (`MCD-F10010`). |
| **24** | **`conta_acesso_unidade_economica`** | **`TENANT_DERIVADO_POR_RLS`** | Join via `unidade_economica_id` → `unidade_economica.tenant_id`. Adicionalmente depende de `conta_acesso_tenant` para a regra de negócio (não de RLS) de que a restrição pressupõe uma concessão (`ADR-C014`). |
| **25** | **`evento_auditoria_seguranca`** | **`BLOQUEADO — SEM CAMPOS PARA POLICY`** | Tabela só tem `id`; nenhuma policy de tenant é definível até `ator`/`tenant`/`UE` serem incorporados (`GAP-CDC-1.3-002`). RLS deve ser **habilitado com zero policies** (fail-closed por ausência de regra, não por regra explícita) até então. |

`credencial_acesso` não aparece na matriz — nenhuma tabela física existe para ele nesta revisão.

**Totais:** `TENANT_ID_RAIZ`=1 · `GLOBAL_COMPARTILHADO`=4 · `TENANT_DERIVADO_POR_RLS`=13 ·
`TENANT_ID_MATERIALIZADO`=4 · `TENANT_DERIVADO_DO_PAI`=1 · `RAIZ_PROPRIA_VISIVEL_POR_CONCESSAO`=1 ·
`BLOQUEADO`=1. **`1+4+13+4+1+1+1 = 25`** ✓ — confere com as 25 relações físicas de §3.

### 9.2 Contexto de sessão/conexão

**Variável:** `app.current_tenant_id` (GUC de aplicação, via `SET LOCAL`, nunca `SET` de sessão —
`ADR-D028`). Leitura: `current_setting('app.current_tenant_id', true)`.

### 9.3 Comportamento fail-closed quando o contexto estiver ausente

Toda policy RLS deve ser escrita de forma que `current_setting('app.current_tenant_id', true)`
retornando `NULL`/vazio resulte em **nenhuma linha visível** — nunca em "ver tudo". Isso significa:
nenhuma policy pode usar um padrão como `tenant_id = COALESCE(current_setting(...), tenant_id)`
(que efetivamente desativaria o filtro quando o contexto está ausente) — o padrão correto é
`tenant_id = current_setting('app.current_tenant_id', true)::uuid`, que **falha a comparação**
(retorna `false`, não erro) quando o contexto é nulo, negando acesso por padrão.

### 9.4 Connection pooling

Risco reafirmado de `SEC-001` §14: uma conexão de pool reutilizada entre transações de tenants
diferentes, se `app.current_tenant_id` não for resetado, pode vazar contexto residual. `SET LOCAL`
mitiga isso estruturalmente (escopo de transação, revertido automaticamente em `COMMIT`/`ROLLBACK`
mesmo sem `RESET`) — mas a camada de aplicação/Prisma **deve garantir** que `SET LOCAL` seja a
**primeira instrução de toda transação** que toca dado tenant-scoped, nunca assumido como já
definido por uma transação anterior na mesma conexão física. Esta é uma responsabilidade de
implementação (middleware/wrapper de transação), não resolvida por este ADR.

### 9.5 Operações administrativas

`SEC-001` §12 exige que acesso administrativo interno da CONTIFISC seja **nomeado e auditado**,
nunca um papel "vê tudo" implícito. Fisicamente, isso implica que operações administrativas
cross-tenant **não devem contornar RLS via um valor mágico de `app.current_tenant_id`** (ex.: um
UUID reservado que as policies tratem como "todos os tenants") — esse padrão criaria um bypass
disfarçado de tenant normal, sem auditoria distinta. A estratégia preferencial (a decidir/validar
em uma futura PoC, não neste ADR) é um **role PostgreSQL distinto** para operação administrativa,
usado apenas através de caminhos de aplicação explicitamente auditados (gerando
`EventoAuditoriaSeguranca` quando esse objeto estiver detalhado) — nunca o role padrão da
aplicação.

### 9.6 Objetos globais compartilhados

Ver §10.

---

**Reafirmação:** nenhuma policy SQL (`CREATE POLICY`) é criada por este ADR. A matriz acima é a
especificação que uma futura migration deverá implementar — sujeita a nova revisão se a
implementação revelar incompatibilidade (mesmo padrão metodológico já usado para `ADR-C005`).

## 10. Objetos globais — por que RLS nos fatos impede vazamento cross-tenant

`pessoa_fisica`, `pessoa_juridica` e `fonte_pagadora` permanecem **sem RLS de tenant** (ou com RLS
permissivo — a decidir na implementação, sem impacto na garantia de isolamento, já que a garantia
não depende de restringir a visibilidade destas tabelas em si). `conta_acesso` (nova nesta
revisão) segue a mesma categoria.

**Mecanismo de proteção:** o isolamento por tenant não depende de restringir quem pode ver uma
linha de `pessoa_fisica`/`pessoa_juridica`/`fonte_pagadora`/`conta_acesso` — depende de restringir
quem pode ver os **fatos** que referenciam essas identidades. Um `ContaAcesso` do Tenant A pode,
em tese, enxergar (ou fazer `JOIN` com) uma linha de `pessoa_fisica` que também é referenciada por
um fato do Tenant B — mas a política RLS do fato em si (`receita`, `evento_irpf` etc., classe
`TENANT_DERIVADO_POR_RLS`, §9.1) impede que esse `ContaAcesso` **veja o fato do Tenant B**,
independentemente de conseguir "enxergar" a `PessoaFisica` compartilhada. Em outras palavras: a
existência de uma identidade global compartilhada nunca é, por si só, uma concessão de acesso a
fatos — exatamente o princípio já formalizado em `SEC-001` §3 e reafirmado em `MCD-001`/`CDC-001`
(`CDC-PER-001`/`CDC-EMP-001`/`CDC-FPG-001`). A RLS física apenas torna esse princípio executável:
o filtro que importa está sempre na tabela de fato, nunca na tabela de identidade global.

## 11. `EventoAuditoriaSeguranca` físico

`ADR-D029` (§2.2). Considerações adicionais:

- **Imutabilidade:** por convenção de aplicação (`INSERT`-only) — ver §8. Nenhum mecanismo de
  banco (trigger/`REVOKE`) é implementado nesta revisão porque a tabela ainda não tem colunas que
  justifiquem a proteção granular.
- **Retenção:** não decidida — depende de `SEC-001` §17 (LGPD, `ADR-GAP-006`, política de retenção
  por tipo de dado), ainda não fechada.
- **Índices:** nenhum proposto agora — dependem das colunas reais (provavelmente `tenant_id`,
  `ocorrido_em`, `ator_conta_acesso_id` seriam candidatos óbvios a índice quando existirem), mas
  especular índices sobre colunas inexistentes seria inventar estrutura.
- **Relacionamento com tenant/UE/ator:** nenhum FK físico existe ainda — bloqueado até
  `GAP-CDC-1.3-002` ser resolvido por um Change Request de autenticação/RBAC.
- **Não confundir com:** log técnico genérico (infraestrutura, fora do modelo canônico), `Sessao`
  (`SEGURANCA_OPERACIONAL`, não canônico, dependente do provedor de autenticação), ou um futuro
  `EVT-001` (arquitetura de eventos de domínio genérica — reconciliação entre os dois fica para
  quando `EVT-001` existir, não antecipada aqui).

## 12. `ResultadoCalculo` — preservação integral

- **Snapshot imutável:** preservado — `id`, `input_snapshot_hash`, `engine_id`, `engine_version`,
  `rule_set_id`, `rule_set_version`, `calculado_em` continuam `Imutável` (V1.0, inalterado).
- **Coexistência de `cenario_tributario_id` e `unidade_economica_id`:** preservada — ambos podem
  estar presentes; **nenhum XOR** é criado por este ADR (`CDC-REL-SEC-003`, inalterado desde a
  correção pós-SEC). A consistência entre os dois (quando `cenario_tributario_id` presente, seu
  `unidade_economica_id` deve corresponder) é uma constraint candidata a `CHECK`/trigger — **não
  implementada nesta revisão**, registrada como decisão pendente de PoC futura, análoga a
  `ADR-C014` (dependeria de resolver `cenario_tributario_id → cenario_tributario.unidade_economica_id`
  e comparar com a coluna local — mesma classe de problema, mesma disciplina de "propor, depois
  validar por PoC, depois migrar").
- **`unidade_economica_id` agora `Imutável`** (não `Versionado`, diferente dos outros 5
  hospedeiros de `MCD-F10004`) — ver §13.
- **Nenhuma alteração de semântica para acomodar Prisma.** O Prisma modela a coexistência das duas
  FKs sem dificuldade (dois campos opcionais/obrigatórios independentes); nenhuma simplificação
  foi necessária.

## 13. Mutabilidade — mapeamento físico completo

A revisão pós-SEC exige explicitar o mecanismo de preservação histórica, não apenas rotular
colunas como "`UPDATE` permitido/proibido".

### 13.1 `Versionado`

**Mecanismo físico:** a coluna aceita `UPDATE` normalmente — **nenhum trigger ou CHECK impede a
alteração.** Esta é a mesma política já vigente desde a V1.0 para `pessoa_fisica_id`/
`pessoa_juridica_id` em `receita` e campos análogos — nenhum desses campos tem proteção de banco
contra `UPDATE`, e o baseline V1.0 nunca propôs uma.

**Preservação histórica — mecanismo real, não presumido:** o schema físico, por si só, **não
retém automaticamente o valor anterior** de uma coluna `Versionado` após um `UPDATE` — não existe,
no modelo canônico atual, uma tabela de histórico de campo ou um envelope de auditoria de mudança
de valor. A preservação de "o que era antes e por quê" depende do **processo** que precede a
correção: rotear a mudança através de `RevisaoTecnica` (que tem `justificativa`, `TEXT`, e é
imutável) ou `ConflitoDado`/`ConflitoDadoItem` (reconciliação), **antes** de emitir o `UPDATE` na
coluna de fato. Isso é uma exigência de processo de aplicação, **não verificável estruturalmente
pelo banco** com o modelo canônico atual — registrado como `ADR-GAP-009` (§14), não implementado
por invenção de uma tabela de histórico que o MCD não define.

**5 hospedeiros de `MCD-F10004` com esta política:** `receita`, `contribuicao_previdenciaria`,
`vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`.

### 13.2 `Imutável`

**Mecanismo físico:** **também sem trigger de banco** — a garantia é de aplicação/repositório
(nenhum caminho de código emite `UPDATE` para essa coluna) e de contrato (`CDC-001`, mutabilidade
`immutable`), exatamente como já é o caso para **todos** os campos `Imutável` já validados na
migration V1 pré-SEC (`id`, `valor_receita_bruta`, `hash_conteudo`, `input_snapshot_hash` etc.) —
nenhum deles tem um trigger de imutabilidade no schema já testado (`INTEGRATION_TEST_REPORT.md`
não relata nenhum). **Decisão explícita desta revisão:** não introduzir um mecanismo de trigger de
imutabilidade genérico agora, por consistência com o tratamento físico já validado de dezenas de
outros campos `Imutável` do mesmo baseline — introduzir um trigger só para
`resultado_calculo.unidade_economica_id` criaria uma inconsistência de mecanismo dentro da mesma
tabela (os demais campos `Imutável` de `resultado_calculo` não teriam trigger; só este teria), sem
um "conflito concreto" que justifique o tratamento desigual.

**Preservação histórica para `ResultadoCalculo`:** já garantida estruturalmente pelo próprio
desenho do objeto — uma correção de `unidade_economica_id` não é uma "correção de valor", é o
cálculo de um **novo** `ResultadoCalculo` (novo `id`, novo `input_snapshot_hash`). O resultado
anterior permanece intacto na tabela, nunca sobrescrito — a imutabilidade do campo é uma
consequência da imutabilidade do registro inteiro, não uma proteção isolada de coluna.

**Único hospedeiro de `MCD-F10004` com esta política:** `resultado_calculo`.

### 13.3 Explicitação obrigatória

A política de `MCD-F10004` **não é a mesma** nos 6 hospedeiros — 5 usam `Versionado` (sem trigger,
preservação histórica dependente de processo, `ADR-GAP-009`), 1 usa `Imutável` (sem trigger,
preservação histórica garantida pela própria imutabilidade do registro completo). Ambas as
políticas físicas são "sem trigger de banco" — a diferença real não está em "o banco impede ou
não", mas em **onde** a garantia de imutabilidade reside: para `resultado_calculo`, ela é
estrutural (o próprio objeto é um snapshot fechado); para os outros 5, ela é inexistente no banco
e delegada inteiramente ao processo de aplicação.

## 14. Gaps — reavaliação de impacto físico

Nenhum gap de DST/CDC é resolvido por decisão física nesta seção — apenas classificado quanto ao
impacto na próxima etapa.

| Gap | Tema | Bloqueia `schema.prisma`? | Bloqueia migration? | Bloqueia RLS? | Bloqueia autenticação? | Pode permanecer diferido? |
|---|---|---|---|---|---|---|
| ADR-GAP-001 | FontePagadora.identificador_fiscal | Não | Não | Não | Não | Sim |
| ADR-GAP-002 | papel_arquivo | Não | Não | Não | Não | Sim |
| ADR-GAP-003 | ConflitoDadoItem tipo_objeto/papel_no_conflito | Não | Não | Não | Não | Sim |
| ADR-GAP-004 | Identidade do revisor | Não | Não | Não (tenant de RevisaoTecnica já resolvido) | Não | Sim |
| ADR-GAP-005 | rule_set_id/regra_versao_id | Não | Não | Não | Não | Sim |
| ADR-GAP-006 | Retenção/anonimização LGPD | Não | Não | **Parcial** — não bloqueia a policy de isolamento por tenant, mas bloqueia qualquer futura policy/rotina de purge automatizada | Não | Sim, para o isolamento básico; não, para automação de retenção |
| ADR-GAP-007 | F9009 em Receita/Contrib/EventoIRPF | Não | Não | Não | Não | Sim |
| ADR-GAP-008 | F9007 em ResultadoCalculo/RevisaoTecnica | Não | Não | Não | Não | Sim |
| **ADR-GAP-009** *(novo)* | Preservação de histórico de campos `Versionado` (ex.: `MCD-F10004`) depende de processo, não de mecanismo físico | Não | Não | Não | Não | Sim — é um requisito de processo de aplicação, não um gap de schema |
| DST-GAP-015 / GAP-SEC-CR1-001 | Vocabulário de `papel` | Não (`TEXT`, sem CHECK — Enum/Ref aberto não recebe CHECK, `ADR-D010`) | Não | Não (RLS de isolamento não usa `papel`; um futuro modelo de permissão fina poderia, mas não faz parte desta baseline) | Não (não impede criar `conta_acesso`/associações) | Sim |
| GAP-SEC-CR1-002 | Vinculo sem extremidade UE | Não | Não | Não (a exceção residual já é coberta pela classificação `TENANT_DERIVADO_POR_RLS` de `vinculo`, com nota) | Não | Sim |
| GAP-SEC-CR1-003 | ResultadoCalculo sem UE nem Cenário simultaneamente | **Não** — este ADR mantém `NOT NULL` conforme a obrigatoriedade atualmente aprovada; se o cenário se confirmar real no futuro, exigirá uma migration para relaxar a constraint, não decidido agora | Não | Não | Não | Sim |
| GAP-CDC-1.3-001 | Tenant — detalhamento completo | Não (tabela mínima já é válida) | Não | Não (RLS de `tenant`, §9.1 item 21, não depende de `nome`/`status`) | **Sim, para autenticação completa** | Sim |
| **GAP-CDC-1.3-002** | EventoAuditoriaSeguranca — detalhamento completo | Não (tabela mínima já é válida) | Não | **Sim, para `evento_auditoria_seguranca` especificamente** (§9.1 item 25: `BLOQUEADO`) | **Sim, para o trilho de auditoria de login/logout/etc.** | Sim para a tabela existir; não para ela ser útil como trilho de auditoria real |
| GAP-CDC-1.3-004 / GAP-CDC-1.4-002 | ContaAcesso.tipo, CredencialAcesso | Não | Não | Não | **Sim, para autenticação completa** | Sim |
| GAP-CDC-1.4-001 | Vigência/status das associações de acesso | Não | Não | Não | Não | Sim |

**Nenhum gap listado bloqueia a definição do `schema.prisma` proposto ou a criação da próxima
migration** — os únicos itens com impacto real e explícito são: `ADR-C014` (bloqueia especificamente
a materialização de `conta_acesso_unidade_economica` até ter PoC própria — não é um "gap" de
vocabulário, é uma constraint física pendente de validação, listada em §5.2/§5.3, não nesta
tabela) e `GAP-CDC-1.3-002` (bloqueia apenas a RLS/utilidade de `evento_auditoria_seguranca`
especificamente, não o restante do schema).

## 15. Migration inaugural pós-SEC

### 15.1 Migrations e ambientes (preservado da V1.0 §12)

| ID | Regra |
|---|---|
| MIG-001 | Toda migration deve ser versionada e revisável; nenhuma alteração manual em produção. |
| MIG-002 | Prisma gera o esqueleto; SQL manual complementa CHECK, triggers, partial indexes ou recursos não expressáveis. |
| MIG-003 | SQL manual faz parte da migration e do code review; não pode existir como comando operacional solto. |
| MIG-004 | Migration destrutiva exige plano de backfill, compatibilidade e rollback/roll-forward. |
| MIG-005 | Schema físico deve ser validado contra COT/MCD/CDC/DST antes de merge — nesta revisão, inclui também `SEC-001`/`SEC-CHANGE-REQUEST-001`. |
| MIG-006 | Ambientes dev/test/staging/prod usam a mesma cadeia de migrations. |
| MIG-007 | Primeira migration só pode ser criada após aprovação explícita deste ADR — nesta revisão, após aprovação da V1.1 e da PoC de `ADR-C014` (§19). |
| MIG-008 | A versão do PostgreSQL efetivamente usada em desenvolvimento/staging/produção deve ser registrada e validada contra a baseline `PostgreSQL >= 15` (`ADR-D014`) antes da primeira migration. |
| MIG-009 | Antes de qualquer migration, confirmar que `schema.prisma` declara `relationMode = "foreignKeys"` (`ADR-D013`). |

### 15.2 Migration inaugural pós-SEC (nova decisão)

**Decisão formalizada:** a migration `20260901120000_init_baseline_fisica` (V1 pré-SEC) permanece
**artefato histórico validado** — aplicada e testada duas vezes em PostgreSQL 15 descartável
(`INTEGRATION_TEST_REPORT.md`), **nunca aplicada a nenhum banco persistente**. Ela **não será
estendida por uma segunda migration incremental** ("V1 incompleta → V2 SEC").

**A próxima migration, quando autorizada, deve ser uma baseline inaugural completa pós-SEC** —
uma única migration cobrindo as 20 tabelas do domínio tributário (com as extensões desta revisão:
`tenant_id`/`unidade_economica_id` novos) **e** as 5 tabelas do domínio de segurança, gerada como
um único `CREATE SCHEMA`/conjunto de `CREATE TABLE` coerente — não uma sequência de duas
migrations artificialmente separadas por V1/V2. Justificativa: como nenhuma baseline foi aplicada
a um banco persistente, não existe nenhum banco real "em V1" que precise de uma migration
incremental "para V2" — o primeiro banco persistente desta plataforma nasce diretamente na
baseline completa.

**Nota de tooling (não decidida por este ADR):** a pasta histórica
`prisma/migrations/20260901120000_init_baseline_fisica/` permanece no repositório como registro,
mas precisará ser tratada explicitamente na hora de gerar a migration real (removida do diretório
ativo de migrations do Prisma, ou o histórico de migrations resetado por um mecanismo equivalente,
como `prisma migrate resolve`) para que o Prisma não tente aplicá-la como um primeiro passo de uma
cadeia antes da baseline completa. A forma exata fica para o momento da criação real da migration,
não para este ADR.

## 16. Prisma — o que é representável, o que exige SQL manual, RLS ou aplicação

| Regra física | `schema.prisma` | SQL manual | Depende de RLS | Depende de aplicação |
|---|---|---|---|---|
| `tenant` (tabela mínima) | ✓ | — | — | — |
| `unidade_economica.tenant_id` (FK simples, `NOT NULL`) | ✓ | — | — | — |
| `unidade_economica` `UNIQUE(id, tenant_id)` (`ADR-C011`) | ✓ `@@unique` | — | — | — |
| `unidade_economica_id` nos 6 hospedeiros de `MCD-F10004` (FK simples) | ✓ | — | — | — |
| `tenant_id` materializado (`ArquivoOrigem`/`ConflitoDado`/`RevisaoTecnica`, FK simples) | ✓ | — | — | Preenchimento a partir do contexto de sessão no `INSERT` |
| `conta_acesso` (tabela mínima) | ✓ | — | — | — |
| `conta_acesso_tenant`/`conta_acesso_unidade_economica` (estrutura base + `UNIQUE`) | ✓ | — | — | — |
| `ADR-C014` (restrição UE requer concessão Tenant) | ✗ | ✓ (trigger, pendente de PoC) | — | Mitigação interina antes da PoC |
| `evento_auditoria_seguranca` (tabela mínima) | ✓ | — | — | — |
| Políticas RLS (todas as 25 tabelas) | ✗ (Prisma não modela RLS) | ✓ (`CREATE POLICY`, não escrita nesta revisão) | ✓ | — |
| Contexto de sessão (`SET LOCAL app.current_tenant_id`) | ✗ | — | ✓ (consumido pelas policies) | ✓ (emitido pelo middleware/wrapper de transação) |
| Fail-closed sem contexto | ✗ | ✓ (redigido dentro de cada policy) | ✓ | — |
| Operações administrativas (role separado) | ✗ | ✓ (provisionamento de role, futuro) | — | ✓ (caminho de aplicação auditado) |
| Mutabilidade `Versionado`/`Imutável` | ✗ (Prisma não impõe imutabilidade) | — | — | ✓ (disciplina de repositório/serviço) |
| Preservação histórica de campos `Versionado` (`ADR-GAP-009`) | ✗ | — | — | ✓ (rotear por `RevisaoTecnica`/`ConflitoDado` antes do `UPDATE`) |

**`schema.prisma` não é alterado por este ADR.** A tabela acima antecipa o que a próxima proposta
de schema deverá conter, sem criá-la.

## 17. Testes obrigatórios do schema (extensão)

Preservados da V1.0 (`§13`), mais os seguintes, obrigatórios antes de qualquer migration real do
domínio de segurança:

| Teste | Obrigatório |
|---|---|
| `UnidadeEconomica` rejeita `tenant_id` nulo | Sim |
| `UnidadeEconomica` aceita `UNIQUE(id, tenant_id)` sem conflito em inserções normais | Sim |
| `ArquivoOrigem`/`ConflitoDado`/`RevisaoTecnica` rejeitam `tenant_id` nulo | Sim |
| Os 6 hospedeiros de `MCD-F10004` rejeitam `unidade_economica_id` nulo | Sim |
| `ContaAcessoTenant` rejeita par `(conta_acesso_id, tenant_id)` duplicado | Sim |
| `ContaAcessoUnidadeEconomica` rejeita par `(conta_acesso_id, unidade_economica_id)` duplicado | Sim |
| `ADR-C014` (PoC dedicada): inserir `ContaAcessoUnidadeEconomica` sem `ContaAcessoTenant` correspondente rejeita | Sim, antes de qualquer migration que inclua `conta_acesso_unidade_economica` |
| `ADR-C014` (PoC dedicada): inserir `ContaAcessoUnidadeEconomica` com `ContaAcessoTenant` correspondente aceita | Sim |
| RLS (quando policies existirem, fora desta revisão): sessão sem `app.current_tenant_id` não vê nenhuma linha tenant-scoped | Sim, na etapa de implementação de RLS |
| RLS: sessão com `app.current_tenant_id` de um tenant não vê linhas de outro tenant, mesmo via join a identidade global compartilhada | Sim, na etapa de implementação de RLS |
| Testes de constraints PostgreSQL continuam exigindo PostgreSQL real — SQLite/mock não é evidência suficiente | Sim (reafirmado da V1.0) |

## 18. Gaps deliberadamente não resolvidos

Ver §14 para a tabela de impacto físico completa. Resumo dos IDs:

`ADR-GAP-001` a `ADR-GAP-008`: preservados da V1.0, sem alteração de tratamento.
`ADR-GAP-009` (novo): preservação de histórico de campos `Versionado` depende de processo de
aplicação, não de mecanismo físico — não resolvido por invenção de estrutura.

## 19. Ordem de implementação após aprovação

1. Claude sincroniza este ADR em `/docs` e faz auditoria cruzada com `SEC-001`/`COT`/`MCD`/`CDC`/`DST`.
2. Claude cria **PoC isolada** da constraint trigger `ADR-C014` (dependência
   `ContaAcessoUnidadeEconomica` → `ContaAcessoTenant`), em PostgreSQL descartável, seguindo a
   mesma metodologia de `ADR-C005` (containers efêmeros, checksum, reprodutibilidade em banco
   novo). A PoC de `ADR-C005` em si **não precisa ser refeita** — permanece validada.
2.1. Se a PoC de `ADR-C014` revelar incompatibilidade, este ADR deve ser revisado antes de
     substituir a constraint por validação apenas de aplicação.
3. Após validação, gerar proposta de `schema.prisma` completo (domínio tributário + segurança) e
   a **nova migration inaugural única** (§15), em branch/commit separado.
4. Revisar diff MCD→Prisma campo a campo e COT/CDC→constraints, incluindo os 6+3+5 campos/tabelas
   desta revisão.
5. Rodar testes PostgreSQL reais (§17).
6. Somente após revisão humana, autorizar merge/aplicação em ambiente de desenvolvimento.
7. RLS (policies reais) é uma etapa **separada e posterior** à migration inaugural — a matriz de
   §9 é a especificação, não a implementação.
8. Produção/multi-tenant permanece bloqueada até policies RLS reais existirem e serem testadas, e
   até autenticação real (Change Request específico) estar implementada.

## 20. Critérios de aceite do ADR (V1.1)

- [x] Não cria objeto ou campo canônico novo além dos já aprovados por `MCD-001` V1.4/`CDC-001` V1.4.
- [x] Mapeia os 25 objetos/estruturas da baseline pós-SEC sem vendor leakage.
- [x] Preserva integralmente as decisões físicas V1.0 não conflitantes (`ADR-D001..D019`,
  `ADR-C001..C010`, `IDX-001..005`, `MIG-001..009`).
- [x] Define `Tenant` físico distinto de `UnidadeEconomica`.
- [x] Define `UnidadeEconomica.tenant_id NOT NULL` + candidate key `UNIQUE(id, tenant_id)`.
- [x] Define os 6 hospedeiros de `MCD-F10004` com FK simples (não composta), com justificativa
  explícita de por que a FK composta não se aplica hoje.
- [x] Define `tenant_id` materializado em `ArquivoOrigem`/`ConflitoDado`/`RevisaoTecnica`, com
  proveniência de contexto de sessão, nunca payload de API.
- [x] Preserva `ConflitoDadoItem` sem `tenant_id` próprio.
- [x] Define `ContaAcesso` com identidade mínima, sem nenhum campo de autenticação.
- [x] Define `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` fisicamente completos, com
  unicidade lógica e o mecanismo (pendente de PoC) para a dependência estrutural entre as duas.
- [x] Define matriz RLS completa (25 tabelas), contexto de sessão, fail-closed, pooling, operações
  administrativas e objetos globais — sem escrever nenhuma policy.
- [x] Define `EventoAuditoriaSeguranca` físico mínimo, sem confundir com log técnico/Sessão/EVT-001.
- [x] Preserva `ResultadoCalculo` sem XOR.
- [x] Mapeia a política de mutabilidade dividida de `MCD-F10004`, com mecanismo explicado (não
  reduzida a UPDATE permitido/proibido).
- [x] Reavalia todos os gaps abertos quanto a impacto físico, sem resolver nenhum por decisão física.
- [x] Formaliza a migration inaugural pós-SEC como baseline única, não V1+V2.
- [x] Identifica o que é representável em Prisma, SQL manual, RLS ou aplicação.
- [x] Não altera `schema.prisma`, migration, banco, autenticação, RLS físico ou aplicação.

## 21. Consequências

**Positivas:** a baseline de segurança/tenant ganha uma tradução física completa e coerente com o
mesmo rigor já aplicado ao domínio tributário; a disciplina de "propor no ADR → validar por PoC →
só então migrar" (já comprovada com `ADR-C005`) se estende a `ADR-C014`; a decisão de não
denormalizar `tenant_id` nos 6 hospedeiros de `MCD-F10004` evita uma migração de dado futura
desnecessária caso essa denormalização nunca se prove necessária; a formalização da migration
inaugural única evita uma sequência artificial de migrations.

**Custos:** `ADR-C014` exige uma PoC nova e não trivial (trigger cross-table com resolução de
join) antes de qualquer migration que inclua `conta_acesso_unidade_economica`; a ausência de
denormalização de `tenant_id` nos 6 hospedeiros de `MCD-F10004` significa que toda leitura
tenant-scoped nessas tabelas paga o custo de um join adicional em tempo de execução (mitigado por
`IDX-006`); a preservação histórica de campos `Versionado` fica inteiramente a cargo de disciplina
de processo, sem rede de segurança física (`ADR-GAP-009`).

## 22. Gate

| Achado | Severidade |
|---|---|
| `ADR-C014` (dependência estrutural `ContaAcessoUnidadeEconomica` → `ContaAcessoTenant`) ainda não validada por PoC | `NAO_BLOQUEANTE` — mesmo padrão já usado para `ADR-C005` na V1.0: o ADR pode ser aprovado com uma constraint proposta e pendente de PoC própria; a PoC é o primeiro passo da ordem de implementação (§19), não um pré-requisito para a aprovação do ADR. |
| Nenhuma FK composta `(unidade_economica_id, tenant_id)` aplicada nos 6 hospedeiros de `MCD-F10004` nesta rodada | `EDITORIAL` — decisão explicitamente justificada (§4), não uma lacuna; a chave candidata (`ADR-C011`) já prepara a estrutura para uma decisão futura, se necessária. |
| `GAP-CDC-1.3-002` bloqueia policy RLS real de `evento_auditoria_seguranca` | `NAO_BLOQUEANTE` — não impede a criação da tabela mínima nem do restante do schema; apenas posterga a utilidade da tabela como trilho de auditoria real até o Change Request de autenticação/RBAC. |
| `ADR-GAP-009` (preservação de histórico de campos `Versionado` depende de processo, não de mecanismo físico) | `NAO_BLOQUEANTE` — gap de processo, não de schema; não impede `schema.prisma`, migration ou RLS. |
| Custo de join adicional em tempo de execução para os 6 hospedeiros de `MCD-F10004` (sem `tenant_id` denormalizado) | `NAO_BLOQUEANTE` — mitigado por `IDX-006`; decisão de performance, não de correção. |

**Contagem do gate:** `CRITICAL = 0`, `RELEVANTE = 0`.

Nenhum achado `CRITICAL` ou `RELEVANTE` foi encontrado. Todos os achados remanescentes são
`NAO_BLOQUEANTE` ou `EDITORIAL`, com causa e tratamento explícitos — nenhum gap foi fechado por
inferência, nenhuma decisão física validada da V1.0 foi reaberta sem conflito concreto.

### Conclusão do gate

```
ADR-001 PÓS-SEC CONSOLIDADO — APTO PARA ATUALIZAÇÃO DO SCHEMA PRISMA
```

**Esta conclusão autoriza exclusivamente a próxima etapa técnica** (§19: PoC da constraint
`ADR-C014` seguida da proposta de `schema.prisma`/migration completos) — **não autoriza**, por si
só, editar `schema.prisma`, criar migration, aplicar banco, escrever policies RLS reais ou
implementar autenticação.

## 23. Decisão solicitada

Aprovar, rejeitar ou solicitar alterações nesta revisão. **A aprovação autoriza apenas a próxima
etapa técnica (PoC da constraint `ADR-C014` + proposta de `schema.prisma`/migration completos);
não autoriza aplicação automática de migration, criação de policies RLS reais, nem go-live.**

---
**Governança:** COT define o que existe; MCD define os dados; CDC define contratos; DST define
significado; ADR define a implementação física. PostgreSQL/Prisma não podem alterar unilateralmente
as camadas anteriores.
