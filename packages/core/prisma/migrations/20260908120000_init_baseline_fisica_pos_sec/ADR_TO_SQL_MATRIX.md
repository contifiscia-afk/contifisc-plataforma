# Matriz DECISÃO/CONSTRAINT → DDL — migration inaugural pós-SEC (artefato de revisão, não aplicada)

Migration: `20260908120000_init_baseline_fisica_pos_sec/migration.sql`. Gerada a partir de
`prisma/schema.prisma` pós-SEC (25 models, 0 enums, commit `f66d95c`) via
`prisma migrate diff --from-empty --to-schema-datamodel ... --script`, sem conexão com banco.
SQL manual complementar restrito às constraints já autorizadas pelo `ADR-001` V1.1 e suas erratas,
mais o mecanismo `ADR-C014` empiricamente validado pela PoC descartável (ver
`packages/core/prisma/poc/adr-c014/ADR-C014_POC_REPORT.md`).

Esta migration representa DIRETAMENTE o baseline físico pós-SEC — não é uma segunda etapa sobre a
migration pré-SEC (`20260901120000_init_baseline_fisica`), que permanece artefato histórico de
validação, nunca aplicado e nunca usado como "V1" desta linhagem.

**Status:** `GERADA_PELO_PRISMA` (emitida automaticamente a partir de `schema.prisma`) ·
`ADICIONADA_MANUALMENTE` (SQL escrito à mão nesta migration, autorizado pelo ADR/PoC) ·
`DEFERRED_BY_GAP` (gap arquitetural/`ADR-GAP-*`/`DST-GAP-*` explicitamente aberto — nenhum SQL
criado) · `NOT_APPLICABLE` (regra do ADR que não se traduz em SQL de migration — validação de
aplicação, RLS futura, ou nenhum caso concreto ainda aprovado).

---

## PARTE A — Baseline de domínio pré-SEC (reproduzida sem nenhuma alteração)

Todos os itens desta parte são idênticos, byte-a-byte, aos já reconciliados em
`20260901120000_init_baseline_fisica/ADR_TO_SQL_MATRIX.md`. Reproduzidos aqui para que esta
migration tenha uma matriz de rastreabilidade autocontida.

### A.1 Regras estruturais (PK/FK/UNIQUE) — domínio pré-SEC

| ADR | Objeto | Regra | Representação Prisma | DDL na migration | Origem normativa | Método | Status |
|---|---|---|---|---|---|---|---|
| ADR-D004/D005 | todos os 20 models de domínio pré-SEC | PK `id: uuid`, FK `uuid` | `@id @db.Uuid` | `PRIMARY KEY (...)` × 20 | ADR-001 V1.0 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-D013 | todos os relacionamentos | `relationMode = "foreignKeys"` — FK real no PostgreSQL, nunca emulada no client | `datasource { relationMode = "foreignKeys" }` | 20 × `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY` (pré-SEC) | ADR-001 V1.0 §6 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C003 | VinculoExtremidade | `UNIQUE(vinculo_id, lado_extremidade)` | `@@unique([vinculo_id, lado_extremidade])` | `CREATE UNIQUE INDEX "uq_vinculo_lado"` | ADR-001 V1.0 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C006 | ReceitaDocumentoFiscal | `UNIQUE(receita_id, documento_fiscal_id)` | `@@unique([receita_id, documento_fiscal_id])` | `CREATE UNIQUE INDEX "uq_receita_documento_fiscal"` | ADR-001 V1.0 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C007 | DocumentoFiscalArquivoOrigem | Unicidade mínima `(documento_fiscal_id, arquivo_origem_id)` | `@@unique([documento_fiscal_id, arquivo_origem_id])` | `CREATE UNIQUE INDEX "uq_documento_fiscal_arquivo_origem"` | ADR-001 V1.0 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C008 | ClassificacaoEquiparacaoHospitalar | PK própria + FK `receita_id` | `id @id`, `receita Receita @relation(...)` | `classificacao_equiparacao_hospitalar_pkey` + FK | ADR-001 V1.0 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C008 | ClassificacaoEquiparacaoHospitalar | Histórico não-destrutivo (não sobrescrever classificação anterior) | — | — | ADR-001 V1.0 | Validação de aplicação | NOT_APPLICABLE |
| ADR §8 | ResultadoCalculo → CenarioTributario | `onDelete: Restrict` (não Cascade) | `onDelete: Restrict` | `... FOREIGN KEY ("cenario_tributario_id") ... ON DELETE RESTRICT` | ADR-001 V1.0 §8 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR §8 | ReceitaDocumentoFiscal / DocumentoFiscalArquivoOrigem | Cascade só na linha de associação, nunca no objeto de destino | `onDelete: Cascade` só nos models de associação | `ON DELETE CASCADE` nas 4 FKs (lado documento); `ON DELETE RESTRICT` no lado `arquivo_origem` | ADR-001 V1.0 §8 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR §8 | Fatos/evidências pré-SEC | Nenhum cascade destrutivo de fato/evidência | `onDelete: Restrict` em todas as FKs de fato/evidência | 16 das 20 FKs pré-SEC usam `RESTRICT`; 4 usam `CASCADE` só em linhas associativas | ADR-001 V1.0 §8 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C010 | ConflitoDadoItem | `tipo_objeto`/`objeto_id` sem FK (exceção polimórfica de reconciliação) | Campos sem `@relation` | — | ADR-001 V1.0 | Validação de aplicação/auditoria | NOT_APPLICABLE |
| ADR §6 | RevisaoTecnica | `objeto_revisado_id`/`tipo_objeto_revisado` sem FK (exceção polimórfica) | Campos sem `@relation` | — | ADR-001 V1.0 | Validação de aplicação/auditoria | NOT_APPLICABLE |

### A.2 CHECKs de XOR e formato (ADR-C0XX) — domínio pré-SEC

| ADR | Objeto | Regra | DDL na migration | Origem normativa | Método | Status |
|---|---|---|---|---|---|---|
| ADR-C001 | Receita | Ownership XOR: `pessoa_fisica_id` XOR `pessoa_juridica_id` | `ck_receita_ownership_xor` | ADR-001 V1.0 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| ADR-C002 | VinculoExtremidade | Endpoint XOR: exatamente uma FK entre UE/PF/PJ | `ck_vinculo_extremidade_endpoint_xor` | ADR-001 V1.0 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| ADR-C004 / DST-E012 | VinculoExtremidade | `lado_extremidade IN ('ORIGEM','DESTINO')` | `ck_vinculo_extremidade_lado` | ADR-001 V1.0 / DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| ADR-C005 / COT-REL-NORM-001 | Vinculo / VinculoExtremidade | Exatamente duas extremidades (1 ORIGEM + 1 DESTINO) por Vinculo | `fn_check_vinculo_extremidades()` + `CREATE CONSTRAINT TRIGGER trg_vinculo_extremidades_check ... DEFERRABLE INITIALLY DEFERRED` — reproduzido byte-a-byte da PoC (`poc/adr-001-vinculo-extremidade/sql/001_schema.sql`) e da migration pré-SEC | ADR-001 V1.0 / COT-001 | SQL manual (constraint trigger), já validado por PoC dedicada | ADICIONADA_MANUALMENTE |
| ADR-C009 | Receita | `competencia` formato `YYYY-MM`, mês 01-12 | `ck_receita_competencia_formato` | ADR-001 V1.0 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |

### A.3 CHECKs de vocabulário fechado DST (ADR-D010 — TEXT + CHECK, nunca ENUM nativo)

| DST | Campo | Objeto(s) | DDL na migration | Origem normativa | Método | Status |
|---|---|---|---|---|---|---|
| DST-E008 | status_registro | UnidadeEconomica | `ck_unidade_economica_status_registro` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E001 | regime_tributario | PessoaJuridica | `ck_pessoa_juridica_regime_tributario` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E003 | status_elegibilidade_equiparacao_hospitalar | ClassificacaoEquiparacaoHospitalar | `ck_classificacao_eqhop_status_elegibilidade` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E004 | tipo_rendimento_irpf | EventoIRPF | `ck_evento_irpf_tipo_rendimento` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E005 | tipo_fonte_pagadora | FontePagadora | `ck_fonte_pagadora_tipo` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E006 | status_revisao | ResultadoCalculo | `ck_resultado_calculo_status_revisao` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E006 | status_revisao | RevisaoTecnica | `ck_revisao_tecnica_status_revisao` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E007 | status_conflito | ConflitoDado | `ck_conflito_dado_status` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E010 | sistema_origem (MCD-F9001) | Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal | `ck_receita_sistema_origem` + 3 análogas | MCD-001 / DST-001 / ADR-D015 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E010 | sistema_origem (uso pré-existente) | ConflitoDadoItem | `ck_conflito_dado_item_sistema_origem` | DST-001 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E009 | status_processamento_dado (MCD-F9004) | Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal | `ck_receita_status_processamento_dado` + 3 análogas | MCD-001 / DST-001 / ADR-D016 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |
| DST-E011 | status_qualidade_dado (MCD-F9010) | Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal | `ck_receita_status_qualidade_dado` + 3 análogas | MCD-001 / DST-001 / ADR-D016 | SQL manual (CHECK) | ADICIONADA_MANUALMENTE |

**Salvaguarda 1 (Errata controlada nº2), reconfirmada nesta migration:** os CHECKs de
`status_processamento_dado` (DST-E009) e `status_qualidade_dado` (DST-E011) permanecem constraints
de coluna única, independentes entre si — nenhuma constraint/trigger da migration referencia as
duas colunas na mesma cláusula.

### A.4 Enum/Ref abertos (DST-GAP-*) — nenhum CHECK, nenhuma lista inventada (inalterado)

| DST-GAP | Campo | Objeto | Status |
|---|---|---|---|
| DST-GAP-001 | conselho_profissional | PessoaFisica | DEFERRED_BY_GAP |
| DST-GAP-002 | especialidade_saude | PessoaFisica | DEFERRED_BY_GAP |
| DST-GAP-003 | tipo_vinculo | Vinculo | DEFERRED_BY_GAP |
| DST-GAP-005 | papel_vinculo | Vinculo | DEFERRED_BY_GAP |
| DST-GAP-006 | fonte_receita | Receita | DEFERRED_BY_GAP |
| DST-GAP-007 | tipo_documento_fiscal | DocumentoFiscal | DEFERRED_BY_GAP |
| DST-GAP-008 | tipo_vinculo_previdenciario | VinculoPrevidenciario | DEFERRED_BY_GAP |
| DST-GAP-009 | tipo_conflito | ConflitoDado | DEFERRED_BY_GAP |
| DST-GAP-010 | tipo_objeto_revisado | RevisaoTecnica | DEFERRED_BY_GAP |
| DST-GAP-011 | papel_arquivo | DocumentoFiscalArquivoOrigem | DEFERRED_BY_GAP |
| DST-GAP-012 | tipo_objeto | ConflitoDadoItem | DEFERRED_BY_GAP |
| DST-GAP-013 | papel_no_conflito | ConflitoDadoItem | DEFERRED_BY_GAP |
| DST-GAP-015 | papel (transversal, novo em DOM-SEC) | ContaAcessoTenant, ContaAcessoUnidadeEconomica | DEFERRED_BY_GAP |
| GAP-CDC-1.2-004/GAP-MCD-CR2-005 | identificador_fiscal | FontePagadora | DEFERRED_BY_GAP |
| ADR-GAP-005 | rule_set_id / rule_set_version / regra_versao_id | ResultadoCalculo / ClassificacaoEquiparacaoHospitalar | DEFERRED_BY_GAP |

---

## PARTE B — Adições físicas pós-SEC (SEC-001 / SEC-CR-001 / ADR-001 V1.1)

### B.1 Regras estruturais (PK/FK/UNIQUE) — segurança/multi-tenant

| ADR | Objeto | Regra | Representação Prisma | DDL na migration | Origem normativa | Método | Status |
|---|---|---|---|---|---|---|---|
| ADR-D021/ADR-C011 | UnidadeEconomica | `tenant_id UUID NOT NULL` + FK simples → Tenant, `ON DELETE RESTRICT` | `tenant_id String @db.Uuid`, `tenant Tenant @relation(..., onDelete: Restrict)` | `unidade_economica_tenant_id_fkey` | ADR-001 V1.1 §2.2/§5.2 / MCD-F10002 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-D021/ADR-C011 | UnidadeEconomica | Chave candidata `UNIQUE(id, tenant_id)` | `@@unique([id, tenant_id], map: "uq_unidade_economica_id_tenant")` | `CREATE UNIQUE INDEX "uq_unidade_economica_id_tenant"` | ADR-001 V1.1 §5.2 | Prisma nativo | GERADA_PELO_PRISMA |
| MCD-F10004 | Receita, ContribuicaoPrevidenciaria, VinculoPrevidenciario, EventoIRPF, DocumentoFiscal, ResultadoCalculo (6 hospedeiros) | `unidade_economica_id UUID NOT NULL` + FK simples → UnidadeEconomica (sem FK composta, sem `tenant_id` no hospedeiro), `ON DELETE RESTRICT` | `unidade_economica_id String @db.Uuid`, `@relation(fields: [unidade_economica_id], references: [id])` | `receita_unidade_economica_id_fkey`, `contribuicao_previdenciaria_unidade_economica_id_fkey`, `vinculo_previdenciario_unidade_economica_id_fkey`, `evento_irpf_unidade_economica_id_fkey`, `documento_fiscal_unidade_economica_id_fkey`, `resultado_calculo_unidade_economica_id_fkey` | ADR-001 V1.1 §4 / MCD-001 V1.4 | Prisma nativo | GERADA_PELO_PRISMA |
| MCD-F10003 | ArquivoOrigem, ConflitoDado, RevisaoTecnica (3 hospedeiros) | `tenant_id UUID NOT NULL` + FK simples → Tenant, `ON DELETE RESTRICT` | `tenant_id String @db.Uuid`, `tenant Tenant @relation(...)` | `arquivo_origem_tenant_id_fkey`, `conflito_dado_tenant_id_fkey`, `revisao_tecnica_tenant_id_fkey` | ADR-001 V1.1 §7 / MCD-001 V1.4 | Prisma nativo | GERADA_PELO_PRISMA |
| — | ConflitoDadoItem | Ausência deliberada de `tenant_id` próprio (deriva de `conflito_dado_id → ConflitoDado.tenant_id`) | Sem campo `tenant_id` no model | Nenhuma coluna `tenant_id` em `conflito_dado_item` (confirmado por grep) | ADR-001 V1.1 §7 | Decisão arquitetural (ausência de coluna) | NOT_APPLICABLE |
| MCD-F10001/F10006/F10007 | Tenant, EventoAuditoriaSeguranca, ContaAcesso | Models mínimos, somente `id UUID PRIMARY KEY` | `model Tenant { id String @id @db.Uuid }` (idem para os outros 2) | `tenant_pkey`, `evento_auditoria_seguranca_pkey`, `conta_acesso_pkey` | ADR-001 V1.1 §3/§10/§11 | Prisma nativo | GERADA_PELO_PRISMA |
| MCD-F10008/F10009/F10010 | ContaAcessoTenant | `id`, `conta_acesso_id` + FK → ContaAcesso, `tenant_id` + FK → Tenant, `ON DELETE RESTRICT` | FKs simples via `@relation` | `conta_acesso_tenant_conta_acesso_id_fkey`, `conta_acesso_tenant_tenant_id_fkey` | ADR-001 V1.1 §9 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C012 | ContaAcessoTenant | `UNIQUE(conta_acesso_id, tenant_id)` | `@@unique([conta_acesso_id, tenant_id], map: "uq_conta_acesso_tenant")` | `CREATE UNIQUE INDEX "uq_conta_acesso_tenant"` | ADR-001 V1.1 §9 | Prisma nativo | GERADA_PELO_PRISMA |
| MCD-F10008/F10011/F10012 | ContaAcessoUnidadeEconomica | `id`, `conta_acesso_id` + FK → ContaAcesso, `unidade_economica_id` + FK → UnidadeEconomica, `ON DELETE RESTRICT` | FKs simples via `@relation` | `conta_acesso_unidade_economica_conta_acesso_id_fkey`, `conta_acesso_unidade_economica_unidade_economica_id_fkey` | ADR-001 V1.1 §9 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-C013 | ContaAcessoUnidadeEconomica | `UNIQUE(conta_acesso_id, unidade_economica_id)` | `@@unique([conta_acesso_id, unidade_economica_id], map: "uq_conta_acesso_unidade_economica")` | `CREATE UNIQUE INDEX "uq_conta_acesso_unidade_economica"` | ADR-001 V1.1 §9 | Prisma nativo | GERADA_PELO_PRISMA |
| IDX-006/IDX-007 | 9 hospedeiros (`unidade_economica_id` × 6, `tenant_id` × 3) | Índice simples para leitura filtrada por UE/tenant (preparação de RLS futura) | `@@index([unidade_economica_id])` / `@@index([tenant_id])` | 9 `CREATE INDEX ..._idx` (ver Seção 1 da migration) | ADR-001 V1.1 §7 | Prisma nativo | GERADA_PELO_PRISMA |
| ADR-001 V1.1 §8 | `UnidadeEconomica.tenant` / `ContaAcessoTenant.*` / `ContaAcessoUnidadeEconomica.*` | Todas as 14 novas FKs usam `ON DELETE RESTRICT` — nenhum `CASCADE` novo introduzido | `onDelete: Restrict` em todas | Confirmado por contagem estática (ver `MIGRATION_REVIEW_REPORT.md` §6) | ADR-001 V1.1 §8 | Prisma nativo | GERADA_PELO_PRISMA |
| — | RLS (todas as 25 tabelas) | Nenhuma `CREATE POLICY`/`ENABLE ROW LEVEL SECURITY` | — | Nenhuma | ADR-001 V1.1 §9.1 | Fora de escopo físico nesta etapa | NOT_APPLICABLE |
| — | Autenticação (CredencialAcesso, Sessao, PapelAcesso, Permissao) | Nenhum model/tabela criado | — | Nenhuma | ADR-001 V1.1 | Fora de escopo | NOT_APPLICABLE |
| — | Contexto de sessão (`SET LOCAL app.current_tenant_id`) / preenchimento de `tenant_id` no INSERT | Nenhuma constraint SQL — responsabilidade da camada de aplicação | — | Nenhuma | ADR-001 V1.1 §9.2 | Application runtime | NOT_APPLICABLE |

### B.2 `ADR-C014` — invariante cross-table `ContaAcessoUnidadeEconomica` → `ContaAcessoTenant`

Diferente de todas as demais linhas desta parte, `ADR-C014` **não** é representável em Prisma nem
por um `CHECK` de coluna única — é um invariante cross-table que depende de uma constraint trigger
com lock explícito, cujo desenho foi **empiricamente validado** por PoC descartável (PostgreSQL 15
real, 3 containers, reproduzido em ambiente limpo) antes de entrar nesta migration.

| Item | Regra | DDL na migration | Origem normativa | Método | Status |
|---|---|---|---|---|---|
| MCD-F10008/F10010/F10012 | Toda linha de `conta_acesso_unidade_economica` exige uma linha de `conta_acesso_tenant` para o mesmo `conta_acesso_id` e o `tenant_id` resolvido da UE referenciada | `trg_caue_requires_grant_fixed()` + `CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant ... DEFERRABLE INITIALLY DEFERRED` — usa `SELECT ... FOR KEY SHARE` sobre a linha candidata de `conta_acesso_tenant` (correção empiricamente validada, fecha Corrida 1 e Corrida 2 da PoC) | ADR-001 V1.1 §9 (`ADR-C014`) + PoC `packages/core/prisma/poc/adr-c014/ADR-C014_POC_REPORT.md` | SQL manual (constraint trigger), portado da variante candidata validada (`01_schema_fixed.sql`), sem instrumentação `_delayed` | ADICIONADA_MANUALMENTE |
| ADR-C014 (direção inversa) | `conta_acesso_tenant` não pode ser removida/alterada enquanto existirem `conta_acesso_unidade_economica` dependentes no mesmo tenant | `trg_cat_blocks_if_dependents()` + `CREATE CONSTRAINT TRIGGER adr_c014_cat_blocks_if_dependents ... DEFERRABLE INITIALLY DEFERRED` — inalterada em relação à variante ingênua; a PoC provou que o lock da trigger anterior já protege esta direção | idem | SQL manual (constraint trigger), inalterada desde a variante ingênua, validada por PoC | ADICIONADA_MANUALMENTE |
| ADR-C014 (mudança de tenant da UE) | Reatribuir `unidade_economica.tenant_id` não pode invalidar concessões (`conta_acesso_unidade_economica`) existentes sem concessão correspondente no novo tenant | `trg_ue_tenant_change_guard()` + `CREATE CONSTRAINT TRIGGER adr_c014_ue_tenant_change_guard ... DEFERRABLE INITIALLY DEFERRED` — inalterada; protegida incidentalmente pelo lock nativo de FK do PostgreSQL interagindo com `UNIQUE(id, tenant_id)` (`ADR-C011`), confirmado empiricamente na PoC (Corrida 3) | idem | SQL manual (constraint trigger), inalterada, proteção incidental documentada em comentário na migration | ADICIONADA_MANUALMENTE |
| — | Dependência estrutural entre `UNIQUE(id, tenant_id)` (`ADR-C011`) e a proteção incidental da Corrida 3 | Comentário SQL dedicado, imediatamente antes do bloco `ADR-C014` na Seção 2B da migration | ADR-001 V1.1 + PoC (Corrida 3) | Documentação, sem novo objeto SQL | NOT_APPLICABLE (documentação, não constraint) |
| — | Instrumentação de teste (`_delayed`, `pg_sleep`) usada na PoC para provar as corridas | Nenhuma — confirmado por grep negativo na migration | PoC (uso exclusivo de teste) | N/A | NOT_APPLICABLE — nunca migra para produção |

### B.3 Consistência `ResultadoCalculo.unidade_economica_id` × `CenarioTributario.unidade_economica_id`

| Item | Situação | Status |
|---|---|---|
| Consistência entre as duas colunas quando `ResultadoCalculo.cenario_tributario_id` está preenchido | Nenhuma constraint física, nem candidata formal — mesma classe de decisão que `ADR-C014`, ainda mais adiantada (nem PoC foi proposta) | DEFERRED_BY_GAP (registrado para rastreabilidade, não implementado nesta migration) |

### B.4 Campos transversais explicitamente NÃO implementados nesta migration (herdados + reconfirmados)

| Item | Objeto(s) | DDL na migration | Status |
|---|---|---|---|
| ADR-GAP-007 (MCD-F9009) | Receita, ContribuicaoPrevidenciaria, EventoIRPF | Nenhum — nenhuma coluna/FK criada | DEFERRED_BY_GAP |
| ADR-GAP-008 (MCD-F9007) | ResultadoCalculo, RevisaoTecnica | Nenhum — nenhuma coluna `registrado_em` criada | DEFERRED_BY_GAP |
| F9005 (versao_schema) | — | Nenhum — `DECISÃO_BLOQUEADA`, EVT-001/INT-001 | DEFERRED_BY_GAP |
| F9006 (correlation_id) | — | Nenhum — `DECISÃO_BLOQUEADA`, EVT-001/INT-001 | DEFERRED_BY_GAP |

---

## Resumo quantitativo

| Status | Quantidade |
|---|---|
| GERADA_PELO_PRISMA | 25 tabelas + 34 FKs + 6 UNIQUE INDEX + 14 índices simples + 25 PKs (estrutura completa do `schema.prisma` pós-SEC) |
| ADICIONADA_MANUALMENTE | 25 CHECK + 4 FUNCTION + 4 CONSTRAINT TRIGGER = 33 objetos SQL (27 herdados do domínio pré-SEC + 3 funções/triggers novas do `ADR-C014`, mais a função/trigger `ADR-C005` já contada no domínio) |
| DEFERRED_BY_GAP | 15 campos Enum/Ref abertos (`DST-GAP-*`, incl. o novo `DST-GAP-015`) + `ADR-GAP-005` + `ADR-GAP-007` + `ADR-GAP-008` + F9005 + F9006 + consistência `ResultadoCalculo`×`CenarioTributario` |
| NOT_APPLICABLE | 8 regras (histórico não-destrutivo de EqHop, 2 exceções polimórficas, ausência de `tenant_id` em `ConflitoDadoItem`, RLS, autenticação, contexto de sessão/aplicação, documentação da dependência estrutural Corrida 3, instrumentação de teste `_delayed`) |

**Reconciliação com os 151 IDs MCD:** 127 `MAPPED` (sem constraint SQL própria, apenas coluna) +
22 `MAPPED_WITH_SQL_CONSTRAINT` (todos com CHECK/trigger correspondente nesta migration — 19 na
Parte A, 3 na Parte B/`ADR-C014`) + 2 `DEFERRED_BY_GAP` (F9005/F9006) = 151/151. Ver
`MIGRATION_REVIEW_REPORT.md` §7 para a verificação linha a linha dos 22 itens.
