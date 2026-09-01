# Matriz ADR → SQL — primeira migration canônica (artefato de revisão, não aplicada)

Migration: `20260901120000_init_baseline_fisica/migration.sql`. Gerada a partir de
`prisma/schema.prisma` (v3, Errata controlada nº2 do ADR-001 incorporada) via
`prisma migrate diff --from-empty --to-schema-datamodel ... --script`, sem conexão com banco.
SQL manual complementar restrito às constraints já autorizadas pelo ADR-001 e suas erratas.

**Status:** `GERADA_PELO_PRISMA` (emitida automaticamente a partir de `schema.prisma`) ·
`ADICIONADA_MANUALMENTE` (SQL escrito à mão nesta migration, autorizado pelo ADR) ·
`DEFERRED_BY_GAP` (gap arquitetural/`ADR-GAP-*` explicitamente aberto — nenhum SQL criado) ·
`NOT_APPLICABLE` (regra do ADR que não se traduz em SQL de migration — validação de
aplicação, ou nenhum caso concreto ainda aprovado).

## Regras estruturais (PK/FK/UNIQUE)

| ADR | Objeto | Regra | Representação Prisma | SQL da migration | Status |
|---|---|---|---|---|---|
| ADR-D004/D005 | todos os 20 models | PK `id: uuid`, FK `uuid` | `@id @db.Uuid` | `PRIMARY KEY (...)` × 20 | GERADA_PELO_PRISMA |
| ADR-D013 | todos os relacionamentos | `relationMode = "foreignKeys"` — FK real no PostgreSQL, nunca emulada no client | `datasource { relationMode = "foreignKeys" }` | 20 × `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY` | GERADA_PELO_PRISMA |
| ADR-C003 | VinculoExtremidade | `UNIQUE(vinculo_id, lado_extremidade)` | `@@unique([vinculo_id, lado_extremidade])` | `CREATE UNIQUE INDEX "uq_vinculo_lado"` | GERADA_PELO_PRISMA |
| ADR-C006 | ReceitaDocumentoFiscal | `UNIQUE(receita_id, documento_fiscal_id)` | `@@unique([receita_id, documento_fiscal_id])` | `CREATE UNIQUE INDEX "uq_receita_documento_fiscal"` | GERADA_PELO_PRISMA |
| ADR-C007 | DocumentoFiscalArquivoOrigem | Unicidade mínima `(documento_fiscal_id, arquivo_origem_id)` | `@@unique([documento_fiscal_id, arquivo_origem_id])` | `CREATE UNIQUE INDEX "uq_documento_fiscal_arquivo_origem"` | GERADA_PELO_PRISMA |
| ADR-C008 | ClassificacaoEquiparacaoHospitalar | PK própria + FK `receita_id` | `id @id`, `receita Receita @relation(...)` | `classificacao_equiparacao_hospitalar_pkey` + FK | GERADA_PELO_PRISMA |
| ADR-C008 | ClassificacaoEquiparacaoHospitalar | Histórico não-destrutivo (não sobrescrever classificação anterior) | — | — | NOT_APPLICABLE — garantia de aplicação/repositório, não constraint SQL |
| ADR §8 | ResultadoCalculo → CenarioTributario | `onDelete: Restrict` (não Cascade) | `onDelete: Restrict` | `... FOREIGN KEY ("cenario_tributario_id") ... ON DELETE RESTRICT` | GERADA_PELO_PRISMA |
| ADR §8 | ReceitaDocumentoFiscal / DocumentoFiscalArquivoOrigem | Cascade só na linha de associação, nunca no objeto de destino | `onDelete: Cascade` só nos models de associação | `ON DELETE CASCADE` nas 4 FKs de `receita_documento_fiscal`/`documento_fiscal_arquivo_origem` (lado documento); `ON DELETE RESTRICT` no lado `arquivo_origem` (evidência RAW) | GERADA_PELO_PRISMA |
| ADR §8 | Fatos/evidências (Receita, DocumentoFiscal, ArquivoOrigem, ContribuicaoPrevidenciaria, EventoIRPF etc.) | Nenhum cascade destrutivo de fato/evidência | `onDelete: Restrict` em todas as FKs de fato/evidência | 16 das 20 FKs geradas usam `RESTRICT`; as 4 restantes usam `CASCADE` exclusivamente em linhas associativas/filhas (`receita_documento_fiscal` × 2, `documento_fiscal_arquivo_origem` lado documento × 1, `conflito_dado_item` → `conflito_dado` × 1) — nenhum cascade sobre fato/evidência (Receita, DocumentoFiscal, ArquivoOrigem) em si, confirmado por contagem (ver §5 do relatório de revisão) | GERADA_PELO_PRISMA |
| ADR-C010 | ConflitoDadoItem | `tipo_objeto`/`objeto_id` sem FK (exceção polimórfica de reconciliação) | Campos sem `@relation` | — (validação de domínio/auditoria, não SQL) | NOT_APPLICABLE |
| ADR §6 | RevisaoTecnica | `objeto_revisado_id`/`tipo_objeto_revisado` sem FK (exceção polimórfica de revisão/auditoria) | Campos sem `@relation` | — | NOT_APPLICABLE |
| ADR §6 | (todos) | Partial index | — | Nenhum partial index foi aprovado/nomeado até o momento | NOT_APPLICABLE |

## CHECKs de XOR e formato (ADR-C0XX)

| ADR | Objeto | Regra | Representação Prisma | SQL da migration | Status |
|---|---|---|---|---|---|
| ADR-C001 | Receita | Ownership XOR: `pessoa_fisica_id` XOR `pessoa_juridica_id` | 2 campos `String?` nullable, sem constraint declarável em Prisma | `ck_receita_ownership_xor` | ADICIONADA_MANUALMENTE |
| ADR-C002 | VinculoExtremidade | Endpoint XOR: exatamente uma FK entre UE/PF/PJ | 3 campos `String?` nullable | `ck_vinculo_extremidade_endpoint_xor` | ADICIONADA_MANUALMENTE |
| ADR-C004 / DST-E012 | VinculoExtremidade | `lado_extremidade IN ('ORIGEM','DESTINO')` | `String @db.Text` | `ck_vinculo_extremidade_lado` | ADICIONADA_MANUALMENTE |
| ADR-C005 / COT-REL-NORM-001 | Vinculo / VinculoExtremidade | Exatamente duas extremidades (1 ORIGEM + 1 DESTINO) por Vinculo | Relação 1:N estrutural (`extremidades VinculoExtremidade[]`) | `fn_check_vinculo_extremidades()` + `CREATE CONSTRAINT TRIGGER trg_vinculo_extremidades_check ... DEFERRABLE INITIALLY DEFERRED` — **exatamente** a lógica validada pela PoC (`poc/adr-001-vinculo-extremidade/sql/001_schema.sql`), mesmos nomes de tabela/coluna | ADICIONADA_MANUALMENTE |
| ADR-C009 | Receita | `competencia` formato `YYYY-MM`, mês 01-12 | `String? @db.VarChar(7)` | `ck_receita_competencia_formato` (regex `^[0-9]{4}-(0[1-9]|1[0-2])$`) | ADICIONADA_MANUALMENTE |

## CHECKs de vocabulário fechado DST (ADR-D010 — TEXT + CHECK, nunca ENUM nativo)

| DST | Campo | Objeto(s) | SQL da migration | Status |
|---|---|---|---|---|
| DST-E008 | status_registro | UnidadeEconomica | `ck_unidade_economica_status_registro` | ADICIONADA_MANUALMENTE |
| DST-E001 | regime_tributario | PessoaJuridica | `ck_pessoa_juridica_regime_tributario` | ADICIONADA_MANUALMENTE |
| DST-E003 | status_elegibilidade_equiparacao_hospitalar | ClassificacaoEquiparacaoHospitalar | `ck_classificacao_eqhop_status_elegibilidade` | ADICIONADA_MANUALMENTE |
| DST-E004 | tipo_rendimento_irpf | EventoIRPF | `ck_evento_irpf_tipo_rendimento` | ADICIONADA_MANUALMENTE |
| DST-E005 | tipo_fonte_pagadora | FontePagadora | `ck_fonte_pagadora_tipo` | ADICIONADA_MANUALMENTE |
| DST-E006 | status_revisao | ResultadoCalculo | `ck_resultado_calculo_status_revisao` | ADICIONADA_MANUALMENTE |
| DST-E006 | status_revisao | RevisaoTecnica | `ck_revisao_tecnica_status_revisao` | ADICIONADA_MANUALMENTE |
| DST-E007 | status_conflito | ConflitoDado | `ck_conflito_dado_status` | ADICIONADA_MANUALMENTE |
| DST-E010 | sistema_origem (MCD-F9001, Errata nº2/ADR-D015) | Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal | `ck_receita_sistema_origem`, `ck_contribuicao_previdenciaria_sistema_origem`, `ck_evento_irpf_sistema_origem`, `ck_documento_fiscal_sistema_origem` | ADICIONADA_MANUALMENTE |
| DST-E010 | sistema_origem (uso pré-existente, não desta errata) | ConflitoDadoItem | `ck_conflito_dado_item_sistema_origem` | ADICIONADA_MANUALMENTE |
| DST-E009 | status_processamento_dado (MCD-F9004, Errata nº2/ADR-D016) | Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal | `ck_receita_status_processamento_dado`, `ck_contribuicao_previdenciaria_status_processamento_dado`, `ck_evento_irpf_status_processamento_dado`, `ck_documento_fiscal_status_processamento_dado` | ADICIONADA_MANUALMENTE |
| DST-E011 | status_qualidade_dado (MCD-F9010, Errata nº2/ADR-D016) | Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal | `ck_receita_status_qualidade_dado`, `ck_contribuicao_previdenciaria_status_qualidade_dado`, `ck_evento_irpf_status_qualidade_dado`, `ck_documento_fiscal_status_qualidade_dado` | ADICIONADA_MANUALMENTE |

**Salvaguarda 1 (Errata controlada nº2) — verificável diretamente no SQL:** os CHECKs de
`status_processamento_dado` (DST-E009) e `status_qualidade_dado` (DST-E011) acima são
constraints de coluna única e independentes uma da outra. **Nenhuma** constraint, trigger,
`DEFAULT` ou lógica no arquivo `migration.sql` referencia as duas colunas juntas, sincroniza
seus valores, ou deriva uma da outra — confirmado por inspeção: nenhuma ocorrência de
`status_processamento_dado` e `status_qualidade_dado` na mesma cláusula `CHECK`/trigger.

## Enum/Ref abertos (DST-GAP-*) — nenhum CHECK, nenhuma lista inventada

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
| GAP-CDC-1.2-004/GAP-MCD-CR2-005 | identificador_fiscal | FontePagadora | DEFERRED_BY_GAP |
| ADR-GAP-005 | rule_set_id / rule_set_version | ResultadoCalculo | DEFERRED_BY_GAP |

## Campos transversais explicitamente NÃO implementados nesta migration

| Item | Objeto(s) | SQL da migration | Status |
|---|---|---|---|
| ADR-GAP-007 (MCD-F9009) | Receita, ContribuicaoPrevidenciaria, EventoIRPF | Nenhum — nenhuma coluna/FK criada | DEFERRED_BY_GAP |
| ADR-GAP-008 (MCD-F9007) | ResultadoCalculo, RevisaoTecnica | Nenhum — nenhuma coluna `registrado_em` criada | DEFERRED_BY_GAP |
| F9005 (versao_schema) | — | Nenhum — `DECISÃO_BLOQUEADA`, EVT-001/INT-001 | DEFERRED_BY_GAP |
| F9006 (correlation_id) | — | Nenhum — `DECISÃO_BLOQUEADA`, EVT-001/INT-001 | DEFERRED_BY_GAP |
| SEC-001 / autenticação / tenant isolation / RLS | — | Nenhum | NOT_APPLICABLE — fora do escopo desta migration por design |

## Resumo quantitativo

| Status | Quantidade |
|---|---|
| GERADA_PELO_PRISMA | 20 tabelas + 20 FKs + 3 UNIQUE + 5 índices simples + 20 PKs (estrutura completa do `schema.prisma`) |
| ADICIONADA_MANUALMENTE | 25 CHECK + 1 function + 1 constraint trigger = 27 objetos SQL |
| DEFERRED_BY_GAP | 14 campos Enum/Ref abertos (DST-GAP-*) + `ADR-GAP-007` + `ADR-GAP-008` + F9005 + F9006 |
| NOT_APPLICABLE | 5 regras (histórico não-destrutivo de EqHop, 2 exceções polimórficas, partial index não aprovado, SEC-001/tenant/RLS) |
