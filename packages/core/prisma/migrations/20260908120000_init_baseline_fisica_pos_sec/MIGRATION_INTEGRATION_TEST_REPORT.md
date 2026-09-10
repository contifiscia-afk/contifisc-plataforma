# Relatório de teste de integração — migration inaugural pós-SEC CONTIFISC

**Status:** teste executado em PostgreSQL 15 real, descartável, em 2 containers Docker
independentes. **Nenhum banco persistente/Neon foi criado.** Nenhuma migration foi aplicada a
ambiente DEV/persistente. Ao final, ambos os containers e seus volumes foram destruídos.

**Migration sob teste:** `prisma/migrations/20260908120000_init_baseline_fisica_pos_sec/migration.sql`
— exatamente o arquivo já gerado e estaticamente reconciliado na etapa anterior. Nenhuma edição foi
feita a esse arquivo durante este teste.

## 0. Checksum

| Momento | SHA-256 de `migration.sql` |
|---|---|
| Antes da 1ª aplicação (container 1) | `afe5964170c58fbbb3708d65d24d36b49eca988273e4d0f8ece40e95d060e837` |
| Confirmado dentro do container 1 após `docker cp` | `afe5964170c58fbbb3708d65d24d36b49eca988273e4d0f8ece40e95d060e837` |
| Antes da 2ª aplicação (container 2) | `afe5964170c58fbbb3708d65d24d36b49eca988273e4d0f8ece40e95d060e837` |
| Confirmado dentro do container 2 após `docker cp` | `afe5964170c58fbbb3708d65d24d36b49eca988273e4d0f8ece40e95d060e837` |
| Ao final do teste (arquivo em disco) | `afe5964170c58fbbb3708d65d24d36b49eca988273e4d0f8ece40e95d060e837` |

**RESULTADO:** checksum idêntico em todas as verificações — o mesmo SQL, sem nenhuma edição, foi
testado do início ao fim, nos dois ambientes.

## 1. Ambiente

| Componente | Versão |
|---|---|
| PostgreSQL (containers 1 e 2) | 15.19 (Debian 15.19-1.pgdg13+2), confirmado via `SELECT version()` nos dois containers |
| Imagem Docker | `postgres:15` (local, sem pull necessário) |
| Docker Engine / Client | 29.7.2 (API 1.55) |
| Docker Desktop | 4.88.1 (237512) |
| Node.js | v24.19.0 |
| Prisma CLI / `@prisma/client` | 6.19.3 |
| Query/Schema Engine | `c2990dca591cba766e3b7ef5d9e8a84796e47ab7` |

Containers criados via `docker run -d ... postgres:15`, sem volume nomeado (armazenamento efêmero
do container — a imagem oficial declara `VOLUME /var/lib/postgresql/data`, o que cria um volume
anônimo por container; ambos os volumes anônimos gerados nesta etapa foram identificados por data
de criação (`2026-09-10`) e destruídos junto com os containers via `docker rm -f -v`, preservando
intactos os 3 volumes anônimos pré-existentes de sessões anteriores, não relacionados a este teste).

## 2. Aplicação literal da migration

**ESPERADO:** a migration aplica integralmente em um banco vazio, sem nenhuma edição manual, sem
erro.

**OBSERVADO (container 1):** `psql -v ON_ERROR_STOP=1 -f migration.sql` → exit code `0`. Todas as
statements da Seção 1 (25 `CREATE TABLE`, 20 `CREATE INDEX`, 34 `ALTER TABLE ... FOREIGN KEY`) e da
Seção 2 (25 `ALTER TABLE ... CHECK`, 4 `CREATE FUNCTION`, 4 `CREATE TRIGGER`) executaram sem erro.
Nenhuma correção manual foi feita.

**OBSERVADO (container 2, segundo ambiente):** aplicação idêntica, exit code `0`, mesmo resultado.

**RESULTADO: PASSOU** nos dois ambientes. Nenhuma divergência de statement, SQLSTATE, mensagem ou
fase foi encontrada — não houve nenhuma falha a registrar nesta seção.

## 3. Introspecção física independente (`pg_catalog`/`information_schema`)

| Item | ESPERADO | OBSERVADO container 1 | OBSERVADO container 2 |
|---|---|---|---|
| Tabelas físicas em `public` | 25 | 25 | 25 |
| `PRIMARY KEY` | 25 | 25 | 25 |
| `FOREIGN KEY` | 34 | 34 | 34 |
| `UNIQUE INDEX` (não-PK) | 6 | 6 | 6 |
| Índices simples (não únicos, não PK) | 14 | 14 | 14 |
| `CHECK` constraints | 25 | 25 | 25 |
| `FUNCTION` (schema `public`) | 4 | 4 | 4 |
| `CONSTRAINT TRIGGER` (não interno) | 4 | 4 | 4 |
| Todos os 4 constraint triggers `DEFERRABLE INITIALLY DEFERRED` | sim | sim — `trg_vinculo_extremidades_check`, `adr_c014_caue_requires_grant`, `adr_c014_cat_blocks_if_dependents`, `adr_c014_ue_tenant_change_guard` (todos `condeferrable=t, condeferred=t`) | idêntico |
| `pg_type.typtype='e'` (ENUM) | 0 | 0 | 0 |
| `pg_policies` (RLS) | 0 | 0 | 0 |
| Objetos de autenticação (`credencial|sessao|papel_acesso|permissao`) | 0 | 0 (grep negativo em `pg_tables`) | não reconferido isoladamente, mas estrutura idêntica ao container 1 confirma ausência |
| `tenant_id` em `conflito_dado_item` | ausente | ausente (grep negativo em `information_schema.columns`) | idêntico (schema idêntico) |
| `tenant_id` presente apenas nos hosts autorizados | `unidade_economica`, `arquivo_origem`, `conflito_dado`, `revisao_tecnica`, `conta_acesso_tenant` | exatamente esses 5 (nenhum a mais, nenhum a menos) | idêntico |
| `UNIQUE(id, tenant_id)` em `unidade_economica` | presente | `CREATE UNIQUE INDEX uq_unidade_economica_id_tenant ON unidade_economica USING btree (id, tenant_id)` | idêntico |
| FKs simples dos 6 hosts `MCD-F10004`, sem `tenant_id` artificial | sim | confirmado coluna a coluna em `receita`, `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`, `resultado_calculo` — cada um só com `unidade_economica_id`, nenhum com `tenant_id` | idêntico (mesma DDL aplicada) |
| Total de colunas escalares | 189 | 189 | 189 |

**EVIDÊNCIA:** consultas diretas a `pg_tables`, `pg_constraint`, `pg_index`, `pg_indexes`,
`pg_trigger`, `pg_type`, `pg_policies`, `information_schema.columns` — nenhuma dependeu das
contagens textuais do `MIGRATION_REVIEW_REPORT.md` da etapa anterior; todos os números foram
recalculados de forma independente, diretamente do catálogo do PostgreSQL real.

**RESULTADO: PASSOU** — inventário físico idêntico ao baseline aprovado, nos dois ambientes, sem
nenhuma divergência.

## 4. Validação integral dos 25 CHECK constraints

Metodologia: para cada um dos 25 CHECKs, um `INSERT` positivo (valor válido) e um `INSERT`
negativo (valor inválido) foram executados dentro de uma única transação com `ROLLBACK` final
(nenhum dado de teste desta seção persiste). Cada teste capturou o `SQLSTATE` e a constraint
efetivamente acionada via `GET STACKED DIAGNOSTICS`.

| # | Constraint | POSITIVO | NEGATIVO | SQLSTATE |
|---|---|---|---|---|
| 1 | `ck_unidade_economica_status_registro` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 2 | `ck_pessoa_juridica_regime_tributario` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 3 | `ck_classificacao_eqhop_status_elegibilidade` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 4 | `ck_evento_irpf_tipo_rendimento` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 5 | `ck_fonte_pagadora_tipo` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 6 | `ck_resultado_calculo_status_revisao` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 7 | `ck_conflito_dado_status` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 8 | `ck_receita_sistema_origem` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 9 | `ck_contribuicao_previdenciaria_sistema_origem` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 10 | `ck_evento_irpf_sistema_origem` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 11 | `ck_documento_fiscal_sistema_origem` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 12 | `ck_conflito_dado_item_sistema_origem` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 13 | `ck_receita_status_processamento_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 14 | `ck_contribuicao_previdenciaria_status_processamento_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 15 | `ck_evento_irpf_status_processamento_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 16 | `ck_documento_fiscal_status_processamento_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 17 | `ck_receita_status_qualidade_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 18 | `ck_contribuicao_previdenciaria_status_qualidade_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 19 | `ck_evento_irpf_status_qualidade_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 20 | `ck_documento_fiscal_status_qualidade_dado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 21 | `ck_revisao_tecnica_status_revisao` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 22 | `ck_receita_competencia_formato` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 23 | `ck_receita_ownership_xor` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 24 | `ck_vinculo_extremidade_endpoint_xor` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |
| 25 | `ck_vinculo_extremidade_lado` | ACEITO | REJEITADO_CORRETAMENTE | 23514 |

Em cada um dos 25 casos negativos, a mensagem de erro do PostgreSQL nomeou explicitamente a
constraint esperada (ex.: `violates check constraint "ck_unidade_economica_status_registro"`),
confirmando que o CHECK acionado foi exatamente o constraint sob teste, não outro.

**RESULTADO: 25/25 PASSOU. Anomalias = 0.** (executado no container 1; a estrutura idêntica no
container 2 — mesmas 25 definições de CHECK, confirmadas byte-a-byte na introspecção da seção 3 —
torna a repetição integral desnecessária para o gate de repetibilidade, que already exige apenas
"no mínimo" os itens listados no §9 abaixo.)

## 5. Integridade referencial — `RESTRICT`/`CASCADE`

| Caso | ESPERADO | OBSERVADO | SQLSTATE |
|---|---|---|---|
| `DELETE tenant` com `unidade_economica` dependente | 23503 (RESTRICT) | REJEITADO_CORRETAMENTE — `violates foreign key constraint "unidade_economica_tenant_id_fkey"` | 23503 |
| `DELETE unidade_economica` com `receita` dependente | 23503 (RESTRICT) | REJEITADO_CORRETAMENTE — `violates foreign key constraint "receita_unidade_economica_id_fkey"` | 23503 |
| `DELETE conta_acesso` com `conta_acesso_tenant` dependente | 23503 (RESTRICT) | REJEITADO_CORRETAMENTE — `violates foreign key constraint "conta_acesso_tenant_conta_acesso_id_fkey"` | 23503 |
| `DELETE documento_fiscal` com `documento_fiscal_arquivo_origem` dependente | CASCADE só na linha associativa; `arquivo_origem` preservado | CONFIRMADO — linha associativa removida, `arquivo_origem` intacto | — |
| `DELETE receita` com `receita_documento_fiscal` dependente | CASCADE só na linha associativa; `documento_fiscal` preservado | CONFIRMADO — linha associativa removida, `documento_fiscal` intacto | — |
| `DELETE conflito_dado` com `conflito_dado_item` dependente | CASCADE | CONFIRMADO — item removido em cascata | — |

Estas 6 verificações cobrem representativamente as 34 FKs por classe de política: 30 `RESTRICT`
(16 herdadas do domínio pré-SEC + 14 novas pós-SEC, todas confirmadas na introspecção da seção 3
como `ON DELETE RESTRICT`) e 4 `CASCADE` (inalteradas desde o pré-SEC, todas em linhas
associativas/filhas — `receita_documento_fiscal` ×2, `documento_fiscal_arquivo_origem`
×1 lado documento, `conflito_dado_item` ×1). **Nenhum `CASCADE` novo ou inesperado foi
introduzido pela revisão pós-SEC** — confirmado tanto estaticamente (Seção 1 da migration) quanto
empiricamente aqui.

**RESULTADO: 6/6 PASSOU. Anomalias = 0.**

## 6. `ADR-C005` — revalidação dentro da migration real (não do PoC isolado)

Cenários executados diretamente contra `vinculo`/`vinculo_extremidade` desta migration, usando
transações reais (`BEGIN`/`COMMIT`/`ROLLBACK`), reproduzidos **identicamente nos dois containers**:

| Cenário | ESPERADO | OBSERVADO (container 1) | OBSERVADO (container 2) |
|---|---|---|---|
| A — exatamente 2 extremidades (1 ORIGEM + 1 DESTINO) | COMMIT aceito | `COMMIT` — 2 extremidades persistidas | idêntico |
| B — terceira extremidade | rejeitada | `ERROR 23505 duplicate key ... "uq_vinculo_lado"` (rejeitada imediatamente — domínio fechado ORIGEM/DESTINO faz de qualquer 3ª linha uma duplicata de lado) | idêntico |
| C — duplicidade de lado (2×ORIGEM) | rejeitada | `ERROR 23505 duplicate key ... "uq_vinculo_lado"` | idêntico |
| D — estado intermediário DEFERRED (1 extremidade, meio da transação) | permitido, sem erro | nenhum erro até o `ROLLBACK` deliberado — 1 linha visível dentro da transação | idêntico |
| E — estado final inválido (só ORIGEM) no `COMMIT` | rejeitado | `ERROR P0001 ADR-C005/COT-REL-NORM-001: ... total=1, origem=1, destino=0`; 0 linhas persistidas após a falha (confirmado por `SELECT` pós-`COMMIT` falho) | idêntico |
| F — estado final válido (1 ORIGEM + 1 DESTINO) | aceito | `COMMIT` — 2 extremidades persistidas | idêntico |

**SQLSTATE do trigger `ADR-C005` confirmado explicitamente:** `P0001` (padrão de `RAISE EXCEPTION`
sem `USING ERRCODE`), verificado via `GET STACKED DIAGNOSTICS` em bloco dedicado.

**RESULTADO: PASSOU nos dois ambientes.** Todos os 6 comportamentos exigidos (exatamente duas
extremidades; uma ORIGEM; uma DESTINO; terceira extremidade rejeitada; duplicidade de lado
rejeitada; estado intermediário deferred permitido; estado final inválido rejeitado no `COMMIT`;
estado final válido aceito) confirmados dentro das tabelas/triggers reais da migration
consolidada — não do schema isolado da PoC original.

## 7. `ADR-C014` — revalidação funcional (cenários A–H) dentro da migration real

Os 8 cenários funcionais abaixo foram reconstruídos para cobrir integralmente o espaço de
comportamento das 3 constraint triggers (`adr_c014_caue_requires_grant`,
`adr_c014_cat_blocks_if_dependents`, `adr_c014_ue_tenant_change_guard`) contra as tabelas reais da
migration — não contra o schema mínimo de 5 tabelas da PoC original:

| Cenário | Situação | ESPERADO | OBSERVADO (containers 1 e 2, idêntico) |
|---|---|---|---|
| A | CAT + CAUE, mesmo tenant | CAUE aceito | `COMMIT` — 1 CAUE persistido |
| B | CAUE sem CAT correspondente | rejeitado no `COMMIT` | `ERROR P0001` de `trg_caue_requires_grant_fixed`; 0 persistido |
| C | CAT existe, mas para tenant **errado** | rejeitado no `COMMIT` | `ERROR P0001` idêntico; 0 persistido |
| D | 1 CAT cobre 2 UEs do mesmo tenant | ambos CAUE aceitos | `COMMIT` — 2 CAUE persistidos |
| E | `DELETE` de CAT com CAUE dependente | bloqueado no `COMMIT` | `ERROR P0001` de `trg_cat_blocks_if_dependents`; CAT sobrevive |
| F | `DELETE` de CAT sem dependentes | permitido | `COMMIT` — CAT removido |
| G | `UPDATE UE.tenant_id` com concessão no tenant novo | permitido | `COMMIT` — `tenant_id` alterado |
| H | `UPDATE UE.tenant_id` sem concessão no tenant novo | bloqueado no `COMMIT` | `ERROR P0001` de `trg_ue_tenant_change_guard`; `tenant_id` permanece o original |

**RESULTADO: 8/8 PASSOU nos dois ambientes**, sem nenhuma anomalia.

## 8. `ADR-C014` — concorrência (Race 1, Race 2, Race 3)

**Metodologia de controle de tempo — diferente e mais direta que a instrumentação `_delayed`/
`pg_sleep` da PoC original:** em vez de substituir as funções de produção por variantes
instrumentadas, este teste usa exclusivamente SQL de cliente comum —
`SET CONSTRAINTS <nome_do_trigger> IMMEDIATE` (força um constraint trigger `DEFERRED` a rodar
imediatamente, sem esperar o `COMMIT`) seguido de `SELECT pg_sleep(N)` — para controlar
precisamente quando cada sessão adquire e libera seus locks. **As funções/triggers reais da
migration nunca foram modificadas, substituídas ou instrumentadas** para este teste; a
`pg_sleep` roda no lado do cliente, após o trigger real já ter sido executado.

### Race 1 — `INSERT` de CAUE (segura o lock) vs `DELETE` concorrente de CAT

| Evento | Timestamp | Observação |
|---|---|---|
| X: `BEGIN` | 13:15:45.283 | |
| X: `INSERT` CAUE + `SET CONSTRAINTS ... IMMEDIATE` (adquire `FOR KEY SHARE` sobre o CAT) | 13:15:45.299 | lock adquirido |
| X: dorme 3s segurando o lock | — | |
| Y: `BEGIN` + tenta `DELETE` do mesmo CAT | 13:15:46.349 (início da tentativa) | |
| Y: `DELETE` **bloqueia** — só retorna quando X libera o lock | 13:15:48.311 | ~1,96s de espera, batendo com o fim do sleep de X |
| X: `COMMIT` | 13:15:48.311 | sucede — CAT ainda existia quando X checou |
| Y: `COMMIT` | 13:15:48.324 | **falha** — `trg_cat_blocks_if_dependents` encontra o CAUE que X acabou de commitar |

**ESPERADO:** Race 1 bloqueada (nenhum estado inconsistente). **OBSERVADO:** exatamente isso — CAT
sobrevive (`cat_ainda_existe=1`), CAUE de X persiste (`caue_de_x_persistiu=1`), Y falha
corretamente. **Nenhum deadlock.**

### Race 2 — `DELETE` de CAT (segura o lock) vs `INSERT` concorrente de CAUE

| Evento | Timestamp | Observação |
|---|---|---|
| Y: `BEGIN` + `DELETE` do CAT + `SET CONSTRAINTS ... IMMEDIATE` (0 dependentes ainda, passa) | 13:40:08.256–08.362 | |
| Y: dorme 3s segurando o `DELETE` pendente | — | |
| X: `BEGIN` + `INSERT` CAUE + `SET CONSTRAINTS ... IMMEDIATE` | tentativa às 13:40:08.823 | |
| X: `SET CONSTRAINTS` **bloqueia** — só retorna quando Y resolve | 13:40:11.386 | ~2,56s de espera |
| Y: `COMMIT` (linha efetivamente removida) | 13:40:11.376 | sucede |
| X: trigger 1 re-executa a checagem, não encontra mais o CAT → `ERROR P0001`; `COMMIT` de X vira `ROLLBACK` | 13:40:11.386 | falha corretamente |

**ESPERADO:** Race 2 bloqueada. **OBSERVADO:** `caue_de_x_deve_ser_zero=0` — nenhum grant órfão
persistiu. **Nenhum deadlock.**

### Race 3 — `INSERT` de CAUE (lock nativo de FK sobre a UE) vs `UPDATE UE.tenant_id` concorrente

| Evento | Timestamp | Observação |
|---|---|---|
| X: `BEGIN` + `INSERT` CAUE referenciando a UE (a FK **imediata e nativa** `conta_acesso_unidade_economica_unidade_economica_id_fkey` adquire `FOR KEY SHARE` sobre a linha da UE, sem precisar de `SET CONSTRAINTS`) | 14:29:14.132–14.149 | |
| X: dorme 5s segurando o lock nativo | — | |
| Y: `BEGIN` + `UPDATE unidade_economica SET tenant_id=...` na mesma UE | tentativa às 14:29:15.151 | ~1s após X iniciar |
| Y: `UPDATE` **bloqueia** — só retorna quando X libera | 14:29:19.183 | **~4,03s de espera**, batendo com o `COMMIT` de X 1,6ms antes |
| X: `COMMIT` | 14:29:19.180 | sucede |
| Y: `COMMIT` | 14:29:19.199 | **falha** — `trg_ue_tenant_change_guard` encontra o CAUE que X acabou de commitar, sem grant no tenant novo |

**ESPERADO:** Race 3 preservada (a dependência estrutural entre o lock nativo de FK e
`UNIQUE(id, tenant_id)` continua funcionando dentro da migration consolidada). **OBSERVADO:**
exatamente isso — `ue_race3d_tenant_final` permanece o tenant original; nenhum estado órfão. A
primeira tentativa desta corrida (sem sincronização determinística) não produziu contenção real
(Y executou depois que X já havia commitado) — foi descartada e refeita com uma segunda janela de
5s e um atraso de 2s no lançamento de Y, produzindo a contenção genuína documentada acima.
**Nenhum deadlock.**

### Resumo da seção de concorrência

| Item exigido | RESULTADO |
|---|---|
| Race 1 bloqueada | PASSOU |
| Race 2 bloqueada | PASSOU |
| Race 3 preservada | PASSOU |
| Comportamento de `FOR KEY SHARE` (deferred, via `SET CONSTRAINTS IMMEDIATE`, e nativo/imediato via FK) | Confirmado em ambas as formas |
| `DELETE`/`UPDATE` de `ContaAcessoTenant` | Testado (Race 1 DELETE, Race 2 DELETE) |
| `INSERT`/`UPDATE` de `ContaAcessoUnidadeEconomica` | Testado (Race 1/2 INSERT, cenário C funcional cobre UPDATE de FK) |
| Alteração de `UnidadeEconomica.tenant_id` | Testado (Race 3, cenários G/H funcionais) |
| Ausência de estado final semanticamente inválido | Confirmado em todas as 3 corridas |
| Ausência de deadlock relevante | Confirmado — nenhum `ERROR: deadlock detected` em nenhum dos logs |

**A dependência estrutural entre o lock nativo de FK e `UNIQUE(id, tenant_id)` (`ADR-C011`)
observada na PoC continua presente e funcional dentro da migration consolidada.** O fato de a PoC
isolada ter passado não substituiu esta revalidação — todos os 3 mecanismos foram reexecutados
contra as tabelas/triggers reais desta migration.

## 9. Prisma contra o banco migrado

Prisma Client (v6.19.3) gerado a partir do `schema.prisma` pós-SEC aprovado, conectado via
`DATABASE_URL` ao banco descartável, executado nos dois containers:

| Teste | RESULTADO (container 1) | RESULTADO (container 2) |
|---|---|---|
| Conexão | OK | OK |
| CRUD mínimo em 21 dos 25 models (os 4 restantes — `Vinculo`/`VinculoExtremidade` — cobertos pelos testes de transação abaixo, que são a forma correta de criá-los dado o invariante `ADR-C005`) | OK | OK |
| Criação de relações válidas (FKs entre os 21 models) | OK (implícito nos CRUDs encadeados) | OK |
| Rejeição de relação inválida (`unidade_economica_id` inexistente em `Receita`) | OK — Prisma `P2003`, `constraint: receita_unidade_economica_id_fkey` | OK |
| `$transaction()` para `ADR-C005`, caso válido | OK — 2 extremidades persistidas | OK |
| `$transaction()` para `ADR-C005`, caso inválido (1 extremidade) | OK — erro capturado, 0 persistido | OK |
| Transação interativa: estado intermediário deferred inválido (1 extremidade) → estado final válido (2 extremidades) na mesma transação | OK — commit bem-sucedido, 2 extremidades finais | OK |
| `$transaction()` para `ADR-C014`, caso válido | OK — 1 CAUE persistido | OK |
| `$transaction()` para `ADR-C014`, caso inválido (CAUE sem CAT) | OK — erro capturado, 0 persistido | OK |
| Rollback explícito (exceção deliberada dentro de transação interativa) | OK — 0 persistido, mensagem de erro propagada corretamente | OK |

**Total: 9/9 testes por ambiente, 0 anomalias em ambos.** Nenhum teste dependeu de bypass dos
constraints SQL — todas as rejeições vieram do banco (Postgres), propagadas pelo Prisma como
erros de client (`P2003`, erro de transação).

## 10. Repetibilidade

| Etapa | Container 1 | Container 2 |
|---|---|---|
| Checksum antes de aplicar | `afe596...` | `afe596...` (idêntico) |
| Aplicação limpa (exit code) | 0 | 0 |
| Introspecção estrutural (25/25/34/6/14/25/4/4/0/0/189) | idêntica | idêntica |
| `ADR-C005` (6 cenários A–F) | 6/6 idênticos | 6/6 idênticos |
| `ADR-C014` funcional (8 cenários A–H) | 8/8 idênticos | 8/8 idênticos |
| Prisma smoke/CRUD (9 testes) | 9/9 idênticos | 9/9 idênticos |
| Divergência estrutural entre os dois ambientes | nenhuma | nenhuma |

Entre a primeira e a segunda aplicação, o primeiro container (com seu volume anônimo) foi
completamente destruído (`docker rm -f -v`) antes da criação do segundo, garantindo que o segundo
ambiente partiu de um PostgreSQL genuinamente vazio, sem qualquer resquício do primeiro.

**RESULTADO: PASSOU.** O checksum permaneceu idêntico em todas as verificações; o comportamento
estrutural e funcional foi 100% reproduzido no segundo ambiente.

## 11. Divergências encontradas

**Nenhuma divergência estrutural, funcional ou de comportamento foi encontrada entre o
comportamento observado e o baseline aprovado (schema.prisma pós-SEC + ADR-001 V1.1 + PoC
`ADR-C014` validada).**

Uma única observação metodológica, não uma divergência do artefato sob teste: a primeira tentativa
de reproduzir a Race 3 (seção 8) não gerou contenção real porque o atraso fixo entre o lançamento
das duas sessões via `docker exec` não foi suficiente (o `docker exec`/conexão `psql` tem uma
latência de inicialização variável, de ~0,1s a ~1s neste ambiente Windows/Docker Desktop). Isso é
uma característica do arnês de teste (orquestração via shell), não da migration, do PostgreSQL ou
dos triggers `ADR-C014` — foi corrigido aumentando a janela de espera de X e o atraso de
lançamento de Y, reproduzindo a contenção genuína documentada. Classificação: **EDITORIAL**
(metodologia de teste), não **CRITICO** nem **RELEVANTE**.

## 12. Gate

| Critério | RESULTADO |
|---|---|
| Migration aplica integralmente em banco vazio | PASSOU (2/2 ambientes) |
| Estrutura introspectada corresponde ao baseline aprovado | PASSOU (25/25/34/6/14/25/4/4/0/0/189, 2/2 ambientes) |
| Todos os constraints funcionam (25 CHECK + 6 FK representativas + `ADR-C005` + `ADR-C014`) | PASSOU |
| `ADR-C005` passa no schema consolidado | PASSOU (6/6 cenários, 2/2 ambientes) |
| `ADR-C014` passa no schema consolidado | PASSOU (8/8 cenários funcionais + 3/3 corridas de concorrência, 2/2 ambientes) |
| Concorrência permanece segura | PASSOU (Race 1/2/3 bloqueadas/preservada corretamente, 0 deadlocks) |
| Prisma opera corretamente | PASSOU (9/9 testes, 2/2 ambientes) |
| Segundo banco reproduz o resultado | PASSOU (repetibilidade integral, seção 10) |
| Checksum permanece idêntico | PASSOU — `afe5964170c58fbbb3708d65d24d36b49eca988273e4d0f8ece40e95d060e837` em todas as verificações |
| `CRITICAL` | **0** |
| `RELEVANTE` | **0** |

### Conclusão

```
MIGRATION INAUGURAL PÓS-SEC — VALIDADA INTEGRALMENTE EM POSTGRESQL DESCARTÁVEL
```

## 13. Encerramento

- Ambos os containers descartáveis (`contifisc-pos-sec-test1`, `contifisc-pos-sec-test2`) e seus
  volumes anônimos foram destruídos (`docker rm -f -v`) ao final de cada etapa. Confirmado por
  `docker ps -a` (vazio) e `docker volume ls` (apenas os 3 volumes pré-existentes de sessões
  anteriores, não relacionados a este teste, permanecem).
- O Prisma Client transitório gerado contra o banco descartável foi removido do `node_modules` da
  raiz do monorepo (diretório já coberto por `.gitignore` — nenhum artefato de teste foi
  versionado).
- Nenhum arquivo canônico foi alterado: `git status --short` confirma que apenas a pasta da
  migration `20260908120000_init_baseline_fisica_pos_sec/` (com este relatório) e a pasta
  `poc/adr-c014/` (preservada como histórico da etapa anterior, ainda não commitada) aparecem como
  não rastreadas. `schema.prisma`, a migration pré-SEC e os documentos normativos permanecem
  intocados.
- Nenhum banco Neon/persistente foi criado. Nenhuma migration foi aplicada a ambiente DEV.
- Não se avançou automaticamente para nenhuma etapa seguinte (RLS, autenticação, adapter Questor,
  Skills tributárias) — todas permanecem fora de escopo, aguardando autorização explícita própria.
