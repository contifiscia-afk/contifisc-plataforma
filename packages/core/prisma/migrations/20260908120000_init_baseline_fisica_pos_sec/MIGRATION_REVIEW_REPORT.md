# Relatório de revisão estática — migration inaugural pós-SEC CONTIFISC

**Status:** ARTEFATO DE REVISÃO. NÃO APLICADA A NENHUM BANCO. Nenhum `prisma migrate dev`,
`prisma migrate deploy` ou `prisma db push` foi executado. Nenhum Neon/banco persistente foi
criado ou tocado.
**Migration:** `prisma/migrations/20260908120000_init_baseline_fisica_pos_sec/migration.sql`
**Gerada a partir de:** `prisma/schema.prisma` pós-SEC (25 models, 0 enums, commit `f66d95c`).
**Comando usado:** `prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script`
— não exigiu conexão com banco real nem shadow database.

Esta migration representa DIRETAMENTE o baseline físico pós-SEC aprovado. A migration pré-SEC
(`20260901120000_init_baseline_fisica`) permanece artefato histórico de validação — não aplicada,
não usada como primeira etapa de uma cadeia V1→V2 corretiva.

## 1. Como a migration foi gerada

Idêntico ao método já usado e revisado na migration pré-SEC: `prisma migrate diff --from-empty`
computa o SQL inteiramente a partir do motor de schema do Prisma, comparando um estado vazio ao
`schema.prisma` pós-SEC atual — não requer banco de dados, shadow database, nem `DATABASE_URL`
válido apontando para um servidor real. A saída (`--script`) é SQL puro, sem histórico de
migration "aplicada". O comando funcionou integralmente offline (Prisma 6.19.3).

## 2. Estrutura do arquivo de migration

- **Seção 1** — SQL gerado automaticamente pelo Prisma: `CREATE SCHEMA`, 25 `CREATE TABLE`, 25
  `PRIMARY KEY`, 20 `CREATE INDEX` (6 `UNIQUE` + 14 simples), 34 `ALTER TABLE ... FOREIGN KEY`.
  Nenhuma edição manual nesta seção — é a saída literal do `prisma migrate diff`.
- **Seção 2A** — SQL manual de domínio, reproduzido byte-a-byte da migration pré-SEC: 25 `CHECK`,
  1 `FUNCTION` (`fn_check_vinculo_extremidades`), 1 `CONSTRAINT TRIGGER`
  (`trg_vinculo_extremidades_check`, `ADR-C005`).
- **Seção 2B** — SQL manual novo de segurança/multi-tenant: 3 `FUNCTION` + 3 `CONSTRAINT TRIGGER`
  (`ADR-C014`, portadas sem instrumentação de teste da variante candidata validada por PoC) + 1
  comentário de documentação sobre a dependência estrutural `UNIQUE(id, tenant_id)` (Corrida 3).

Cada item das Seções 2A/2B corresponde a uma linha específica de `ADR_TO_SQL_MATRIX.md`, sem
nenhuma constraint inventada além do que `ADR-001` V1.1 e a PoC `ADR-C014` já autorizam.

## 3. SQL manual obrigatório — checklist de cobertura

| Item exigido | Presente | Constraint |
|---|---|---|
| 25 models físicos aprovados | Sim | 25 `CREATE TABLE` |
| Ausência de ENUM Prisma/PostgreSQL | Sim | 0 `CREATE TYPE`, 0 `enum` nativo |
| `Tenant`/`ContaAcesso` mínimos | Sim | `tenant`/`conta_acesso`, somente `id` |
| `UnidadeEconomica.tenant_id NOT NULL` | Sim | coluna `NOT NULL` + FK `unidade_economica_tenant_id_fkey` |
| Chave candidata `UNIQUE(id, tenant_id)` (`ADR-C011`) | Sim | `uq_unidade_economica_id_tenant` |
| `MCD-F10004` nos 6 hospedeiros, FK simples, sem `tenant_id` no hospedeiro | Sim | 6 FKs simples; confirmado por grep negativo de `tenant_id` nos 6 `CREATE TABLE` |
| `tenant_id` materializado só em ArquivoOrigem/ConflitoDado/RevisaoTecnica | Sim | 3 colunas + 3 FKs; confirmado por grep — nenhuma outra tabela tem `tenant_id` além destas + `UnidadeEconomica` + `ContaAcessoTenant` |
| Ausência de `tenant_id` em `ConflitoDadoItem` | Sim | confirmado — `CREATE TABLE "conflito_dado_item"` não tem a coluna |
| `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` + `UNIQUE` (`ADR-C012`/`ADR-C013`) | Sim | `uq_conta_acesso_tenant`, `uq_conta_acesso_unidade_economica` |
| `ADR-C005` reproduzido byte-a-byte | Sim — texto idêntico à migration pré-SEC | `fn_check_vinculo_extremidades()` + `trg_vinculo_extremidades_check` |
| `ADR-C014` — variante CANDIDATA validada por PoC, sem instrumentação `_delayed` | Sim | `trg_caue_requires_grant_fixed()` (com `FOR KEY SHARE`) + `trg_cat_blocks_if_dependents()` + `trg_ue_tenant_change_guard()`, 3 `CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED` |
| Nenhuma variante `_delayed`/`pg_sleep` (instrumentação de teste) na migration | Sim | confirmado por grep — 0 ocorrências em código executável (só em texto de comentário explicando a exclusão) |
| Documentação da dependência estrutural Corrida 3 junto de `UNIQUE(id, tenant_id)` | Sim | comentário SQL dedicado antes do bloco `ADR-C014` |
| Todos os 25 CHECKs de domínio pré-SEC preservados | Sim — idênticos à migration pré-SEC | ver `ADR_TO_SQL_MATRIX.md` Parte A |
| Nenhum `CREATE POLICY`/`ENABLE ROW LEVEL SECURITY` | Sim | confirmado — 0 ocorrências reais (só em comentário do cabeçalho listando o que está fora de escopo) |
| Nenhum model/tabela de autenticação (`CredencialAcesso`, `Sessao`, `PapelAcesso`, `Permissao`) | Sim | confirmado por grep — 0 ocorrências reais (só em comentário do cabeçalho) |
| Nenhum PostgreSQL ENUM criado | Sim | 0 ocorrências de `CREATE TYPE` |

## 4. Gaps preservados (não implementados nesta migration)

- **`ADR-GAP-007`** — MCD-F9009 (`arquivo_origem_id`) não foi criado como FK em `receita`,
  `contribuicao_previdenciaria`, `evento_irpf`.
- **`ADR-GAP-008`** — MCD-F9007 (`registrado_em`) não foi criado em `resultado_calculo` nem
  `revisao_tecnica`.
- **F9005/F9006** (`versao_schema`/`correlation_id`) — nenhuma coluna, tipo, tabela ou JSON
  genérico criado. `EVT-001`/`INT-001` não iniciados. **Únicos gaps MCD pertinentes a esta etapa**,
  confirmado pela reconciliação dos 151 IDs (ver §7).
- **Consistência `ResultadoCalculo.unidade_economica_id` × `CenarioTributario.unidade_economica_id`**
  — nenhuma constraint física nem candidata formal, mesma classe de `ADR-C014` porém sem PoC
  proposta ainda.
- **RLS (`CREATE POLICY`/`ENABLE ROW LEVEL SECURITY`)** — não fisicamente autorizada por `ADR-001`
  V1.1 nesta etapa; os 14 `@@index` novos preparam a leitura filtrada, mas nenhuma policy foi
  escrita.
- **Autenticação** — `CredencialAcesso`/`Sessao`/`PapelAcesso`/`Permissao` continuam ausentes do
  schema e da migration.
- Todos os 15 campos `DST-GAP-*`/`GAP-CDC`/`ADR-GAP-005` (Enum/Ref abertos, incl. o novo
  `DST-GAP-015` de `papel`) permanecem `TEXT` livre, sem `CHECK` — nenhuma lista fechada foi
  inventada.

## 5. Integridade referencial — revisão de FKs e políticas `onDelete`

Contagem por política (34 FKs totais, confirmado por contagem estática):

| Política | Quantidade | Objetos |
|---|---|---|
| `RESTRICT` | 30 | 16 herdadas do domínio pré-SEC + 14 novas pós-SEC (`unidade_economica.tenant_id`, 6× `unidade_economica_id` nos hospedeiros `MCD-F10004`, 3× `tenant_id` materializado, `conta_acesso_tenant.*` ×2, `conta_acesso_unidade_economica.*` ×2) |
| `CASCADE` | 4 | Inalteradas desde o pré-SEC: `receita_documento_fiscal.receita_id`, `receita_documento_fiscal.documento_fiscal_id`, `documento_fiscal_arquivo_origem.documento_fiscal_id`, `conflito_dado_item.conflito_dado_id` — todas em linhas associativas/filhas, nunca em fato/evidência/segurança |

Confirmações explícitas exigidas:

- **Nenhum `CASCADE` novo foi introduzido pela revisão pós-SEC:** confirmado — as 14 novas FKs
  (domínio de segurança/multi-tenant) usam exclusivamente `RESTRICT`.
- **Fatos tributários e objetos de segurança não usam cascade destrutivo:** confirmado. Nenhuma FK
  que referencia `UnidadeEconomica`, `Tenant`, `ContaAcesso` como tabela "pai" usa `CASCADE`.
- **Relações N:N/associativas têm `UNIQUE` apropriado:** confirmado — `uq_receita_documento_fiscal`,
  `uq_documento_fiscal_arquivo_origem` (pré-SEC) e `uq_conta_acesso_tenant`,
  `uq_conta_acesso_unidade_economica` (pós-SEC) presentes.
- **Nenhuma relação física polimórfica foi criada:** confirmado — `ConflitoDadoItem.objeto_id` e
  `RevisaoTecnica.objeto_revisado_id` continuam sem `FOREIGN KEY` na migration (0 ocorrências).
- **`ConflitoDadoItem` continua sem `tenant_id` próprio:** confirmado por inspeção direta do bloco
  `CREATE TABLE "conflito_dado_item"`.

## 6. Verificações estáticas (análise textual/regex do SQL, sem aplicar em banco)

| Métrica | Valor |
|---|---|
| `CREATE TABLE` | 25 |
| `PRIMARY KEY` | 25 |
| `FOREIGN KEY` (`ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY`) | 34 |
| `UNIQUE INDEX` | 6 |
| Índice simples (não único) | 14 |
| `CHECK` (`ALTER TABLE ... ADD CONSTRAINT ... CHECK`) | 25 |
| `FUNCTION` (`CREATE OR REPLACE FUNCTION`) | 4 (`fn_check_vinculo_extremidades`, `trg_caue_requires_grant_fixed`, `trg_cat_blocks_if_dependents`, `trg_ue_tenant_change_guard`) |
| `CONSTRAINT TRIGGER` | 4 (`trg_vinculo_extremidades_check`, `adr_c014_caue_requires_grant`, `adr_c014_cat_blocks_if_dependents`, `adr_c014_ue_tenant_change_guard`) — todos `DEFERRABLE INITIALLY DEFERRED` |
| `CREATE TYPE` (ENUM PostgreSQL) | 0 |
| Ocorrências reais de `ENUM` fora de comentário | 0 (2 ocorrências totais, ambas em comentário de documentação) |
| `CREATE POLICY` / `ENABLE ROW LEVEL SECURITY` | 0 reais (1 e 0 ocorrências, respectivamente; a única menção a `CREATE POLICY` está no comentário do cabeçalho listando o que está fora de escopo) |
| Referências a `CredencialAcesso`/`Sessao`/`PapelAcesso`/`Permissao` como objeto SQL | 0 (única ocorrência é textual, no comentário do cabeçalho, listando-os como ausentes) |
| `_delayed` / `pg_sleep` (instrumentação de teste da PoC) | 0 em código executável (2 ocorrências totais, ambas em comentário explicando que foram excluídas) |
| Total de colunas escalares nas 25 tabelas | 189 (idêntico à contagem de campos escalares do `schema.prisma` pós-SEC — `SCHEMA_POS_SEC_RECONCILIATION_REPORT.md` §22) |
| Integridade de FKs (tabela/coluna de origem e destino existem) | Sem erros |
| Parênteses balanceados | Sim (317 = 317) |
| FKs `ON DELETE RESTRICT` / `ON DELETE CASCADE` | 30 / 4 (soma 34, ver §5) |

Todas as verificações passaram sem inconsistência.

## 7. Reconciliação com os 151 IDs MCD e os 22 `MAPPED_WITH_SQL_CONSTRAINT`

Base: `SCHEMA_POS_SEC_RECONCILIATION_REPORT.md` §17 (127 `MAPPED` / 22
`MAPPED_WITH_SQL_CONSTRAINT` / 2 `DEFERRED_BY_GAP` = 151). Verificação de que cada um dos 22 itens
`MAPPED_WITH_SQL_CONSTRAINT` tem CHECK/trigger correspondente **nesta migration**:

| ID MCD | Campo | Constraint física nesta migration | Presente |
|---|---|---|---|
| MCD-F0003 | status_registro | `ck_unidade_economica_status_registro` | Sim |
| MCD-F2004 | regime_tributario | `ck_pessoa_juridica_regime_tributario` | Sim |
| MCD-F2522 | lado_extremidade | `ck_vinculo_extremidade_lado` | Sim |
| MCD-F2523 | unidade_economica_id (endpoint) | `ck_vinculo_extremidade_endpoint_xor` | Sim |
| MCD-F2524 | pessoa_fisica_id (endpoint) | `ck_vinculo_extremidade_endpoint_xor` | Sim |
| MCD-F2525 | pessoa_juridica_id (endpoint) | `ck_vinculo_extremidade_endpoint_xor` | Sim |
| MCD-F3004 | competencia | `ck_receita_competencia_formato` | Sim |
| MCD-F3010 | pessoa_fisica_id (Receita) | `ck_receita_ownership_xor` | Sim |
| MCD-F3011 | pessoa_juridica_id (Receita) | `ck_receita_ownership_xor` | Sim |
| MCD-F7202 | tipo_fonte_pagadora | `ck_fonte_pagadora_tipo` | Sim |
| MCD-F5001 | status_elegibilidade_equiparacao_hospitalar | `ck_classificacao_eqhop_status_elegibilidade` | Sim |
| MCD-F7002 | tipo_rendimento_irpf | `ck_evento_irpf_tipo_rendimento` | Sim |
| MCD-F8209 | status_revisao (ResultadoCalculo) | `ck_resultado_calculo_status_revisao` | Sim |
| MCD-F8602 | status_conflito | `ck_conflito_dado_status` | Sim |
| MCD-F8654 | sistema_origem (ConflitoDadoItem) | `ck_conflito_dado_item_sistema_origem` | Sim |
| MCD-F8704 | status_revisao (RevisaoTecnica) | `ck_revisao_tecnica_status_revisao` | Sim |
| MCD-F9001 | sistema_origem (transversal, 4 hosts) | `ck_receita_sistema_origem` + 3 análogas | Sim |
| MCD-F9004 | status_processamento_dado (transversal, 4 hosts) | `ck_receita_status_processamento_dado` + 3 análogas | Sim |
| MCD-F9010 | status_qualidade_dado (transversal, 4 hosts) | `ck_receita_status_qualidade_dado` + 3 análogas | Sim |
| MCD-F10008 | conta_acesso_id (transversal, ContaAcessoTenant/ContaAcessoUnidadeEconomica) | `adr_c014_caue_requires_grant` (via `trg_caue_requires_grant_fixed`) | Sim |
| MCD-F10010 | tenant_id (ContaAcessoTenant) | `adr_c014_cat_blocks_if_dependents` | Sim |
| MCD-F10012 | unidade_economica_id (ContaAcessoUnidadeEconomica) | `adr_c014_caue_requires_grant` (via `trg_caue_requires_grant_fixed`) | Sim |

**Resultado: 22/22 presentes.** Nenhum item `MAPPED_WITH_SQL_CONSTRAINT` ficou sem constraint
física correspondente nesta migration. Os únicos gaps MCD pertinentes permanecem `MCD-F9005` e
`MCD-F9006` (`DEFERRED_BY_GAP`, bloqueados por `EVT-001`/`INT-001`), confirmando
127 + 22 + 2 = 151/151.

## 8. Incorporação de `ADR-C005` e `ADR-C014`

- **`ADR-C005`:** `fn_check_vinculo_extremidades()` e `trg_vinculo_extremidades_check` desta
  migration são idênticos, byte-a-byte, aos da migration pré-SEC (mesmos nomes de tabela/coluna,
  mesma lógica, mesma mensagem de erro, mesmo `DEFERRABLE INITIALLY DEFERRED`) — confirmado por
  comparação direta do bloco de texto. Nenhuma reabertura desta validação foi necessária.
- **`ADR-C014`:** as 3 constraint triggers (`trg_caue_requires_grant_fixed`,
  `trg_cat_blocks_if_dependents`, `trg_ue_tenant_change_guard`) são idênticas, byte-a-byte, às da
  variante CANDIDATA validada em `packages/core/prisma/poc/adr-c014/01_schema_fixed.sql`
  (mesmos nomes de função/trigger, mesma lógica, mesmo `FOR KEY SHARE` na trigger 1, mesmo
  `DEFERRABLE INITIALLY DEFERRED` nas 3), **sem** a instrumentação `_delayed`/`pg_sleep` usada
  exclusivamente para provar as corridas na PoC. A dependência estrutural entre
  `UNIQUE(id, tenant_id)` e a proteção incidental da Corrida 3 está documentada em comentário SQL
  imediatamente anterior ao bloco `ADR-C014`, conforme recomendado no
  `ADR-C014_POC_REPORT.md`.

## 9. Comparação `schema.prisma` pós-SEC × migration inaugural pós-SEC

| Aspecto | `schema.prisma` pós-SEC | Migration inaugural pós-SEC |
|---|---|---|
| 25 tabelas, 189 colunas escalares, 0 enum | Fonte (Prisma DSL) | Seção 1 — saída literal de `prisma migrate diff`, sem edição |
| `UnidadeEconomica.tenant_id NOT NULL` + FK + `@@unique([id, tenant_id])` | Declarado via `@relation`/`@@unique` | Gerado nativamente na Seção 1 — nenhum SQL manual necessário |
| `unidade_economica_id`/`tenant_id` simples nos 9 hospedeiros | Declarado via `@relation` simples | Gerado nativamente na Seção 1 |
| `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` + `@@unique` (`ADR-C012`/`ADR-C013`) | Declarado via `@@unique` | Gerado nativamente na Seção 1 |
| CHECKs de vocabulário fechado DST (`status_registro`, `regime_tributario` etc.) | **Não representável** — Prisma não tem `CHECK` declarativo | SQL manual (Seção 2A), 25 constraints |
| XOR de ownership/endpoint (`ADR-C001`/`ADR-C002`) | **Não representável** — exigiria union type que o Prisma não oferece | SQL manual (Seção 2A) |
| Cardinalidade exata de `VinculoExtremidade` (`ADR-C005`) | **Não representável** — invariante de contagem cross-row | SQL manual (Seção 2A), constraint trigger |
| Invariante cross-table `ADR-C014` | **Não representável** — o `schema.prisma` documenta a dependência apenas em comentário (`ADR-C014 = SQL MANUAL PENDENTE DE PoC`, já superado nesta migration) | SQL manual (Seção 2B), 3 constraint triggers com lock explícito, agora **validado e implementado** |
| RLS (isolamento por tenant nas consultas) | Não representável em Prisma nem nesta migration (nenhuma `CREATE POLICY`) | Fora de escopo físico desta etapa — `ADR-001` V1.1 §9.1 permanece a referência para uma etapa futura |
| Autenticação | Ausente em ambos, por design (`SEC-001` não cobre este escopo) | Ausente |

**Conclusão da comparação:** todo objeto nativamente representável em Prisma foi gerado
integralmente pela Seção 1, sem nenhuma edição manual. Todo objeto que o Prisma não consegue
expressar declarativamente (CHECKs de vocabulário, XORs, cardinalidade exata, invariante
cross-table) está na Seção 2, cada um rastreável a uma decisão específica do `ADR-001` V1.1 e,
no caso de `ADR-C014`, a uma PoC empírica que substituiu a marcação anterior "SQL MANUAL PENDENTE
DE PoC" por uma implementação validada.

## 10. Achados

| # | Achado | Classificação |
|---|---|---|
| 1 | As 33 constraints manuais (25 CHECK + 4 FUNCTION + 4 CONSTRAINT TRIGGER) correspondem 1:1 às regras já autorizadas pelo `ADR-001` V1.1/`DST-001`/`ADR-C014` validado — nenhuma constraint nova foi inventada. | HISTÓRICO (confirmação) |
| 2 | `ADR-C005` foi copiado literalmente da migration pré-SEC (mesmos nomes, mesma lógica) — nenhuma adaptação de comportamento. | HISTÓRICO (confirmação) |
| 3 | As 3 constraint triggers de `ADR-C014` foram copiadas literalmente da variante candidata validada pela PoC (`01_schema_fixed.sql`), sem a instrumentação de teste `_delayed`/`pg_sleep` — confirmado por grep. | HISTÓRICO (confirmação) |
| 4 | Os 22 itens `MAPPED_WITH_SQL_CONSTRAINT` da reconciliação pós-SEC têm constraint física 1:1 nesta migration (ver §7) — nenhum ficou órfão. | HISTÓRICO (confirmação) |
| 5 | `ADR-GAP-007`, `ADR-GAP-008`, F9005/F9006 permanecem sem nenhuma coluna/FK na migration, consistente com a instrução de não resolvê-los nesta etapa. | HISTÓRICO (confirmação, não pendência nova) |
| 6 | A consistência `ResultadoCalculo.unidade_economica_id` × `CenarioTributario.unidade_economica_id` não tem constraint física nem candidata formal — mesma classe de decisão que `ADR-C014`, porém sem PoC proposta ainda. | NAO_BLOQUEANTE — já registrado como pendência aberta na reconciliação do schema pós-SEC (§16), não introduzida por esta migration |
| 7 | Nenhuma migration foi testada contra um PostgreSQL real nesta etapa (a aplicação está fora de escopo desta revisão estática) — a verificação empírica do `ADR-C014` já foi feita separadamente na PoC descartável (`poc/adr-c014/`), mas contra um schema MÍNIMO de 5 tabelas, não contra as 25 tabelas completas desta migration. | EDITORIAL (observação, não bloqueante — a aplicação/teste de integração completo contra PostgreSQL real fica para a próxima etapa, autorizada separadamente) |

**Nenhuma inconsistência CRÍTICA ou RELEVANTE encontrada. `CRITICAL = 0`, `RELEVANTE = 0`.**

**Nenhuma divergência que exigisse alteração de documento normativo foi encontrada** — todo objeto
desta migration tem origem rastreável em `MCD-001` V1.4, `CDC-001` V1.4, `DST-001` V1.3, `SEC-001`
V1.0, `ADR-001` V1.1 ou na PoC `ADR-C014` validada. Nenhum documento canônico foi alterado para
acomodar esta migration.

## 11. Proibições respeitadas

- `prisma migrate dev`, `prisma migrate deploy`, `prisma db push`: **não executados**.
- Nenhuma migration foi marcada como aplicada (`_prisma_migrations` não foi tocado — não existe
  conexão com nenhum banco nesta etapa).
- Nenhum banco Neon/persistente foi criado.
- Nenhum histórico de banco foi alterado.
- Nenhum teste de integração descartável foi executado nesta etapa (autorização restrita à geração
  e revisão estática).
- A migration pré-SEC (`20260901120000_init_baseline_fisica`) não foi alterada, não foi aplicada,
  e não foi tratada como "V1" de uma cadeia corretiva.
- A PoC `ADR-C014` (`packages/core/prisma/poc/adr-c014/`) foi preservada como histórico — não
  alterada, não movida, não duplicada; apenas referenciada.
- Nenhum documento normativo (`COT-001`, `MCD-001`, `DST-001`, `CDC-001`, `SEC-001`,
  `SEC-CHANGE-REQUEST-001`, `ADR-001`) foi alterado.
- Nenhuma policy RLS (`CREATE POLICY`/`ENABLE ROW LEVEL SECURITY`), autenticação
  (`CredencialAcesso`/`Sessao`/`PapelAcesso`/`Permissao`), campo, tabela, enum, constraint ou
  índice não autorizado foi criado.
- `ADR-GAP-007`, `ADR-GAP-008`, F9005/F9006, RLS, autenticação, EVT-001, INT-001: nenhum
  implementado.

## 12. Conclusão do gate

```
MIGRATION INAUGURAL PÓS-SEC — GERADA E ESTATICAMENTE RECONCILIADA, AGUARDANDO TESTE INTEGRAL DESCARTÁVEL
```

Não foi aplicada nenhuma migration a nenhum banco. Não foi criado nenhum banco Neon/persistente.
Não se avançou para o teste de integração descartável — esta conclusão autoriza exclusivamente a
próxima etapa técnica, que permanece uma ação separada e explícita, sujeita a nova autorização.
