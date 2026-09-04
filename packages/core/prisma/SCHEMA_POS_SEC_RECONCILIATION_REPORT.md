# Relatório de Reconciliação — schema.prisma pós-SEC

**Status:** ACOMPANHA a atualização de `packages/core/prisma/schema.prisma` (baseline canônica +
física pós-SEC). Nenhuma migration foi gerada, nenhum banco foi aplicado, nenhuma policy RLS foi
criada, nenhuma autenticação foi implementada, nenhum documento normativo foi alterado.

**Fontes obrigatórias:** `COT-001` V1.2, `MCD-001` V1.4, `DST-001` V1.3, `CDC-001` V1.4,
`SEC-001` V1.0, `ADR-001` V1.1, `SEC-CR-001_RECONCILIACAO_FINAL_V1.0.md`.

---

## 1–2. Fontes e preservação da baseline anterior

Partiu-se do `schema.prisma` canônico pré-SEC já validado (v3, com a Errata controlada nº2 do
`ADR-001` incorporada, 20 models, validado empiricamente contra PostgreSQL 15 descartável —
`INTEGRATION_TEST_REPORT.md`). Nenhum model, campo, tipo ou decisão física pré-SEC foi removido,
renomeado ou reescrito — apenas adições. O arquivo não foi reconstruído do zero.

## 3. Auditoria de models

| Verificação | Resultado |
|---|---|
| Total de models | **25** (confirmado por `grep -c "^model "`) |
| 20 models pré-SEC preservados | ✓ — todos os 20 nomes de model idênticos, na mesma ordem relativa |
| 5 novos models autorizados | ✓ — `Tenant`, `EventoAuditoriaSeguranca`, `ContaAcesso`, `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica` |
| `CredencialAcesso` | **Ausente** — confirmado por grep negativo |
| `Sessao` | **Ausente** |
| `PapelAcesso` | **Ausente** |
| `Permissao` | **Ausente** |
| Enums Prisma nativos | **0** — confirmado por `grep -c "^enum "` |

## 4. `Tenant`

```prisma
model Tenant {
  id String @id @db.Uuid
  // + 5 back-relations (unidades_economicas, arquivos_origem, conflitos_dado,
  //   revisoes_tecnicas, concessoes)
}
```

Somente `id` (`MCD-F10001`). Nenhum atributo comercial/organizacional. Continua exclusivamente a
fronteira técnica de isolamento — nenhuma coluna que sugira identidade de cliente, plano comercial
ou nome de organização.

## 5. `ContaAcesso`

```prisma
model ContaAcesso {
  id String @id @db.Uuid
  // + 2 back-relations (concessoes_tenant, restricoes_unidade_ec)
}
```

Somente `id` (`MCD-F10007`). Confirmado por grep: **nenhum** dos seguintes termos aparece no
model — `email`, `senha`, `password`, `hash`, `provider`, `oauth`, `mfa`, `token`, `refresh`,
`sessao`/`session`, ou qualquer campo de Auth.js. `tipo` (HUMANA/SERVICO) não incorporado —
`GAP-CDC-1.4-002`.

## 6. `UnidadeEconomica`

```prisma
model UnidadeEconomica {
  id              String   @id @db.Uuid
  nome            String   @db.VarChar(160)
  status_registro String   @db.Text
  criado_em       DateTime @db.Timestamptz
  atualizado_em   DateTime @db.Timestamptz
  tenant_id       String   @db.Uuid   // MCD-F10002, ADR-D021

  tenant Tenant @relation(fields: [tenant_id], references: [id], onDelete: Restrict)
  // + 7 back-relations (vinculo_extremidades, cenarios_tributarios, receitas,
  //   contribuicoes_previdenciarias, vinculos_previdenciarios, eventos_irpf,
  //   documentos_fiscais, resultados_calculo, contas_acesso_unidade_economica)

  @@unique([id, tenant_id], map: "uq_unidade_economica_id_tenant")
}
```

`tenant_id` é `NOT NULL` (obrigatoriedade `Sim`/`required` conforme `MCD-001`/`CDC-001`), FK
simples para `Tenant`, `ON DELETE RESTRICT`. `@@unique([id, tenant_id])` representa diretamente a
chave candidata do `ADR-001` V1.1 §2.2 (`ADR-D021`)/§5.2 (`ADR-C011`) — a sintaxe Prisma permite
representá-la sem SQL manual, exatamente como o `ADR-001` previu ("se a sintaxe Prisma permitir
representá-la diretamente, utilizar `@@unique([id, tenant_id])`").

**Correspondência com o ADR:** `ADR-D021`/`ADR-C011` — chave candidata preparatória para uma
eventual FK composta futura, não usada por nenhuma tabela nesta revisão (`ADR-001` V1.1 §4).

## 7. `MCD-F10004` nos seis hospedeiros

| Hospedeiro | Model Prisma | Coluna | `NOT NULL`? | FK | Mutabilidade documentada |
|---|---|---|---|---|---|
| Receita | `Receita` | `unidade_economica_id` | Sim | Simples → `UnidadeEconomica` | `Versionado` |
| ContribuicaoPrevidenciaria | `ContribuicaoPrevidenciaria` | `unidade_economica_id` | Sim | Simples | `Versionado` |
| VinculoPrevidenciario | `VinculoPrevidenciario` | `unidade_economica_id` | Sim | Simples | `Versionado` |
| EventoIRPF | `EventoIRPF` | `unidade_economica_id` | Sim | Simples | `Versionado` |
| DocumentoFiscal | `DocumentoFiscal` | `unidade_economica_id` | Sim | Simples | `Versionado` |
| ResultadoCalculo | `ResultadoCalculo` | `unidade_economica_id` | Sim | Simples | **`Imutável`** |

Nenhum `tenant_id` foi adicionado a nenhum dos 6 — confirmado por grep negativo em cada model.
Nenhuma FK composta foi criada — confirmado, apenas `@relation(fields: [unidade_economica_id],
references: [id])` simples em todos os 6. `ResultadoCalculo.cenario_tributario_id` permanece
opcional, coexistindo sem XOR com `unidade_economica_id` (`CDC-REL-SEC-003`, comentário no model).

## 8. `tenant_id` materializado

| Model | Coluna | `NOT NULL`? | FK |
|---|---|---|---|
| `ArquivoOrigem` | `tenant_id` | Sim | Simples → `Tenant` |
| `ConflitoDado` | `tenant_id` | Sim | Simples → `Tenant` |
| `RevisaoTecnica` | `tenant_id` | Sim | Simples → `Tenant` |

Nenhum outro model recebeu `tenant_id` — confirmado por grep: `tenant_id` aparece exclusivamente
em `UnidadeEconomica`, `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`, `ContaAcessoTenant`.
`ConflitoDadoItem` confirmado **sem** `tenant_id` próprio (grep negativo) — deriva via
`conflito_dado_id → ConflitoDado.tenant_id`.

## 9. Associações de acesso

`ContaAcessoTenant`: `id`, `conta_acesso_id`, `tenant_id`, `papel` (`String @db.Text`, sem enum) —
`@@unique([conta_acesso_id, tenant_id])`.

`ContaAcessoUnidadeEconomica`: `id`, `conta_acesso_id`, `unidade_economica_id`, `papel` (idem) —
`@@unique([conta_acesso_id, unidade_economica_id])`.

Ambas as unicidades lógicas são representadas nativamente em Prisma (`@@unique`). `papel`
referencia `DST-GAP-015` em comentário nos dois models — nenhum Prisma enum criado.

## 10. `ADR-C014`

```
ADR-C014 = SQL MANUAL PENDENTE DE PoC
```

O `schema.prisma` representa apenas as relações básicas de `ContaAcessoUnidadeEconomica`
(`conta_acesso_id`, `unidade_economica_id`, FKs simples). **Nenhuma tentativa foi feita de
substituir o invariante cross-table por lógica de aplicação ou modelagem alternativa** — o
comentário no model documenta explicitamente que a dependência estrutural (toda linha desta
tabela deve corresponder a uma linha de `ContaAcessoTenant` para o mesmo `conta_acesso_id` e o
`tenant_id` da UE referenciada) exige uma constraint trigger PostgreSQL cross-table, não
implementada nesta etapa, pendente da mesma metodologia de PoC já usada para `ADR-C005`.

## 11. `EventoAuditoriaSeguranca`

```prisma
model EventoAuditoriaSeguranca {
  id String @id @db.Uuid
}
```

Somente `id` (`MCD-F10006`). Confirmado por grep: nenhum campo de log técnico, request HTTP, IP,
user-agent ou tracing existe — nenhum desses termos aparece no model. Não confundido com `EVT-001`
(comentário explícito no schema).

## 12. Objetos globais

`PessoaFisica`, `PessoaJuridica`, `FontePagadora`: confirmado por grep — nenhum dos três ganhou
`tenant_id`. Nenhuma alteração foi feita a esses três models além do que já existia pré-SEC.

## 13. RLS — nenhuma policy; mapeamento dos 25 models às categorias do `ADR-001` V1.1 §9.1

| # | Model Prisma | Categoria RLS (ADR-001 V1.1) | Schema contradiz a matriz? |
|---|---|---|---|
| 1 | `UnidadeEconomica` | `TENANT_ID_RAIZ` | Não — `tenant_id` coluna própria confirmada |
| 2 | `PessoaFisica` | `GLOBAL_COMPARTILHADO` | Não — sem `tenant_id` |
| 3 | `PessoaJuridica` | `GLOBAL_COMPARTILHADO` | Não |
| 4 | `FontePagadora` | `GLOBAL_COMPARTILHADO` | Não |
| 5 | `Vinculo` | `TENANT_DERIVADO_POR_RLS` | Não — sem coluna própria |
| 6 | `VinculoExtremidade` | `TENANT_DERIVADO_POR_RLS` | Não |
| 7 | `Receita` | `TENANT_DERIVADO_POR_RLS` | Não — `unidade_economica_id` simples, sem `tenant_id` |
| 8 | `ContribuicaoPrevidenciaria` | `TENANT_DERIVADO_POR_RLS` | Não |
| 9 | `VinculoPrevidenciario` | `TENANT_DERIVADO_POR_RLS` | Não |
| 10 | `EventoIRPF` | `TENANT_DERIVADO_POR_RLS` | Não |
| 11 | `DocumentoFiscal` | `TENANT_DERIVADO_POR_RLS` | Não |
| 12 | `ArquivoOrigem` | `TENANT_ID_MATERIALIZADO` | Não — `tenant_id` coluna própria confirmada |
| 13 | `ReceitaDocumentoFiscal` | `TENANT_DERIVADO_POR_RLS` | Não |
| 14 | `DocumentoFiscalArquivoOrigem` | `TENANT_DERIVADO_POR_RLS` | Não |
| 15 | `ClassificacaoEquiparacaoHospitalar` | `TENANT_DERIVADO_POR_RLS` | Não |
| 16 | `CenarioTributario` | `TENANT_DERIVADO_POR_RLS` | Não |
| 17 | `ResultadoCalculo` | `TENANT_DERIVADO_POR_RLS` | Não — `unidade_economica_id` simples |
| 18 | `ConflitoDado` | `TENANT_ID_MATERIALIZADO` | Não — `tenant_id` coluna própria confirmada |
| 19 | `ConflitoDadoItem` | `TENANT_DERIVADO_DO_PAI` | Não — sem `tenant_id`, confirmado |
| 20 | `RevisaoTecnica` | `TENANT_ID_MATERIALIZADO` | Não — `tenant_id` coluna própria confirmada |
| 21 | `Tenant` | `RAIZ_PROPRIA_VISIVEL_POR_CONCESSAO` | Não — sem `tenant_id` de saída, como esperado |
| 22 | `ContaAcesso` | `GLOBAL_COMPARTILHADO` | Não — sem `tenant_id` |
| 23 | `ContaAcessoTenant` | `TENANT_ID_MATERIALIZADO` | Não — `tenant_id` coluna própria confirmada |
| 24 | `ContaAcessoUnidadeEconomica` | `TENANT_DERIVADO_POR_RLS` | Não — `unidade_economica_id` simples, sem `tenant_id` |
| 25 | `EventoAuditoriaSeguranca` | `BLOQUEADO — SEM CAMPOS PARA POLICY` | Não — confirmado que só tem `id`, nenhuma policy é definível ainda |

**Nenhuma coluna adicional foi criada exclusivamente para facilitar RLS sem autorização
MCD/ADR** — confirmado: todas as colunas novas correspondem a um ID `MCD-F*` aprovado (ver §17).
Nenhuma `CREATE POLICY`/`ENABLE ROW LEVEL SECURITY` foi escrita.

## 14. Tipos físicos

| Regra | Confirmado no schema |
|---|---|
| UUID em PK/FK | ✓ — todos os novos campos usam `String @db.Uuid` |
| Dinheiro `NUMERIC(18,2)` | ✓ inalterado (nenhum campo monetário novo nesta revisão) |
| Percentual `NUMERIC(7,4)` | ✓ inalterado |
| Competência `String @db.VarChar(7)` | ✓ inalterado (`Receita.competencia`, único campo desse tipo) |
| Timestamps `TIMESTAMPTZ` | ✓ inalterado |
| Vocabulários fechados como texto | ✓ — `papel` é `String @db.Text`, sem union fechada |
| 0 Prisma enums | ✓ confirmado |

Nenhum vocabulário foi convertido em enum por conveniência do Prisma.

## 15. Relações e delete behavior

| Relação nova | `onDelete` | Justificativa | Determinável pelas fontes? |
|---|---|---|---|
| `UnidadeEconomica.tenant` | `Restrict` | `ADR-001` V1.1 §8 — tenant referenciado não pode ser excluído por cascade | Sim |
| 6 hospedeiros `unidade_economica_id` | `Restrict` | Fato/evidência/resultado nunca desaparece por cascade (`ADR-001` §4, inalterado desde V1.0 §8) | Sim |
| 3 hospedeiros `tenant_id` materializado | `Restrict` | Idem | Sim |
| `ContaAcessoTenant.conta_acesso`/`.tenant` | `Restrict` | Revogar concessão é operação explícita (excluir a linha), não efeito colateral de excluir a conta/tenant (`ADR-001` §8) | Sim |
| `ContaAcessoUnidadeEconomica.conta_acesso`/`.unidade_economica` | `Restrict` | Idem | Sim |

**Nenhuma relação com comportamento de delete indeterminável pelas fontes foi encontrada** — todas
as 11 novas relações têm política explícita no `ADR-001` V1.1. Nenhum `Cascade` destrutivo foi
introduzido em fatos, evidências ou segurança. As duas tabelas de associação de acesso
(`ContaAcessoTenant`/`ContaAcessoUnidadeEconomica`) em si — ao contrário de fatos tributários —
podem ser excluídas diretamente por um serviço de revogação (não modelado neste schema como
cascade, apenas como ausência de proibição — a exclusão da PRÓPRIA linha de concessão é uma
operação de aplicação normal, não uma cascade a partir de outra tabela).

## 16. Constraints — PRISMA_NATIVE / SQL_MANUAL / RLS_FUTURO / APPLICATION_RUNTIME

| Constraint | Classificação |
|---|---|
| `UnidadeEconomica.tenant_id NOT NULL` + FK | `PRISMA_NATIVE` |
| `@@unique([id, tenant_id])` (`ADR-C011`) | `PRISMA_NATIVE` |
| `unidade_economica_id`/`tenant_id` NOT NULL + FK (9 hospedeiros) | `PRISMA_NATIVE` |
| `@@unique([conta_acesso_id, tenant_id])` (`ADR-C012`) | `PRISMA_NATIVE` |
| `@@unique([conta_acesso_id, unidade_economica_id])` (`ADR-C013`) | `PRISMA_NATIVE` |
| CHECK de enums fechados (DST-E001/003/004/005/006/007/008/009/010/011/012) | `SQL_MANUAL` (inalterado desde V1.0) |
| `ADR-C001` (XOR Receita PF/PJ) | `SQL_MANUAL` (inalterado) |
| `ADR-C002` (XOR endpoint VinculoExtremidade) | `SQL_MANUAL` (inalterado) |
| `ADR-C005` (trigger cardinalidade Vinculo) | `SQL_MANUAL` — **já validado por PoC** (inalterado, nenhuma reabertura) |
| `ADR-C009` (CHECK formato competência) | `SQL_MANUAL` (inalterado) |
| **`ADR-C014`** (trigger cross-table `ContaAcessoUnidadeEconomica` → `ContaAcessoTenant`) | **`SQL_MANUAL` — PENDENTE DE PoC, não validado, não implementado** |
| Consistência `ResultadoCalculo.unidade_economica_id` × `CenarioTributario.unidade_economica_id` | `SQL_MANUAL` (candidata, não implementada — mesma classe de `ADR-C014`, ainda mais adiada) |
| RLS (todas as 25 tabelas) | `RLS_FUTURO` — nenhuma policy escrita |
| Contexto de sessão (`SET LOCAL app.current_tenant_id`) | `APPLICATION_RUNTIME` |
| Preenchimento de `tenant_id` a partir do contexto de sessão no `INSERT` (nunca payload de API) | `APPLICATION_RUNTIME` |
| Preservação histórica de campos `Versionado` (via `RevisaoTecnica`/`ConflitoDado` antes do `UPDATE`) | `APPLICATION_RUNTIME` (`ADR-GAP-009`) |
| Imutabilidade de campos `Imutável` (nenhum trigger — consistente com o baseline V1.0) | `APPLICATION_RUNTIME` |

Nenhum `SQL_MANUAL` foi implementado nesta etapa — apenas identificado e classificado.

## 17. Reconciliação programática dos 151 IDs MCD

Verificação por domínio, seguindo a estrutura de `MCD-001` V1.4 §8. **Classificações usadas:**
`MAPPED` (coluna física existe, representa integralmente o campo aprovado — inclui vocabulário
aberto sem CHECK, que nunca receberá enum fechado enquanto o gap permanecer aberto);
`MAPPED_WITH_SQL_CONSTRAINT` (coluna existe **e** depende de CHECK/trigger PostgreSQL não
representável em Prisma para estar completa); `DEFERRED_BY_GAP` (nenhuma coluna física existe
porque um gap aberto impede a decisão); `DEFERRED_BY_ARCHITECTURE` (nenhum ID nesta rodada se
enquadra — ver nota ao final); `NOT_AUTHORIZED` (nenhum ID se enquadra — todos os 151 são
canônicos aprovados).

### DOM-CORE (5 IDs) — model `UnidadeEconomica`

| ID | Campo | Ocorrências | Coluna(s) | Status |
|---|---|---|---|---|
| MCD-F0001 | id | 1 | id | MAPPED |
| MCD-F0002 | nome | 1 | nome | MAPPED |
| MCD-F0003 | status_registro | 1 | status_registro | MAPPED_WITH_SQL_CONSTRAINT (DST-E008) |
| MCD-F0004 | criado_em | 1 | criado_em | MAPPED |
| MCD-F0005 | atualizado_em | 1 | atualizado_em | MAPPED |

### DOM-PER (8 IDs) — model `PessoaFisica`

| ID | Campo | Ocorrências | Status |
|---|---|---|---|
| MCD-F1001 | id | 1 | MAPPED |
| MCD-F1002 | cpf | 1 | MAPPED |
| MCD-F1003 | nome | 1 | MAPPED |
| MCD-F1004 | data_nascimento | 1 | MAPPED |
| MCD-F1005 | conselho_profissional | 1 | MAPPED (DST-GAP-001, aberto) |
| MCD-F1006 | registro_profissional | 1 | MAPPED |
| MCD-F1007 | uf_registro_profissional | 1 | MAPPED |
| MCD-F1008 | especialidade_saude | 1 | MAPPED (DST-GAP-002, aberto) |

### DOM-EMP (7 IDs) — model `PessoaJuridica`

| ID | Campo | Ocorrências | Status |
|---|---|---|---|
| MCD-F2001 | id | 1 | MAPPED |
| MCD-F2002 | cnpj | 1 | MAPPED |
| MCD-F2003 | razao_social | 1 | MAPPED |
| MCD-F2004 | regime_tributario | 1 | MAPPED_WITH_SQL_CONSTRAINT (DST-E001) |
| MCD-F2005 | cnae_principal | 1 | MAPPED |
| MCD-F2006 | data_abertura | 1 | MAPPED |
| MCD-F2007 | municipio_ibge | 1 | MAPPED |

### DOM-REL (12 IDs) — models `Vinculo`, `VinculoExtremidade`

| ID | Campo | Model | Status |
|---|---|---|---|
| MCD-F2501 | id | Vinculo | MAPPED |
| MCD-F2502 | tipo_vinculo | Vinculo | MAPPED (DST-GAP-003, aberto) |
| MCD-F2503 | percentual_participacao_societaria | Vinculo | MAPPED |
| MCD-F2504 | vigencia_inicio | Vinculo | MAPPED |
| MCD-F2505 | vigencia_fim | Vinculo | MAPPED |
| MCD-F2510 | papel_vinculo | Vinculo | MAPPED (DST-GAP-005, aberto) |
| MCD-F2520 | id | VinculoExtremidade | MAPPED |
| MCD-F2521 | vinculo_id | VinculoExtremidade | MAPPED |
| MCD-F2522 | lado_extremidade | VinculoExtremidade | MAPPED_WITH_SQL_CONSTRAINT (DST-E012, ADR-C004) |
| MCD-F2523 | unidade_economica_id (endpoint) | VinculoExtremidade | MAPPED_WITH_SQL_CONSTRAINT (ADR-C002 XOR) |
| MCD-F2524 | pessoa_fisica_id (endpoint) | VinculoExtremidade | MAPPED_WITH_SQL_CONSTRAINT (ADR-C002 XOR) |
| MCD-F2525 | pessoa_juridica_id (endpoint) | VinculoExtremidade | MAPPED_WITH_SQL_CONSTRAINT (ADR-C002 XOR) |

*(Nota: `ADR-C005`, a constraint trigger de cardinalidade exata de `VinculoExtremidade` por
`Vinculo`, já validada por PoC, é estrutural — não associada a um único campo/ID, por isso não
aparece como status de um ID individual acima; permanece `SQL_MANUAL` já validado, inalterada.)*

### DOM-REC (13 IDs) — models `Receita`, `FontePagadora`

| ID | Campo | Model | Status |
|---|---|---|---|
| MCD-F3001 | id | Receita | MAPPED |
| MCD-F3002 | valor_receita_bruta | Receita | MAPPED |
| MCD-F3003 | data_emissao | Receita | MAPPED |
| MCD-F3004 | competencia | Receita | MAPPED_WITH_SQL_CONSTRAINT (ADR-C009) |
| MCD-F3005 | fonte_receita | Receita | MAPPED (DST-GAP-006, aberto) |
| MCD-F3007 | fonte_pagadora_id | Receita | MAPPED |
| MCD-F3008 | valor_retencoes | Receita | MAPPED |
| MCD-F3010 | pessoa_fisica_id | Receita | MAPPED_WITH_SQL_CONSTRAINT (ADR-C001 XOR) |
| MCD-F3011 | pessoa_juridica_id | Receita | MAPPED_WITH_SQL_CONSTRAINT (ADR-C001 XOR) |
| MCD-F7201 | id | FontePagadora | MAPPED |
| MCD-F7202 | tipo_fonte_pagadora | FontePagadora | MAPPED_WITH_SQL_CONSTRAINT (DST-E005) |
| MCD-F7203 | identificador_fiscal | FontePagadora | MAPPED (ADR-GAP-001, tipagem aberta) |
| MCD-F7204 | nome | FontePagadora | MAPPED |

### DOM-FIS (14 IDs) — models `DocumentoFiscal`, `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem`

| ID | Campo | Model | Status |
|---|---|---|---|
| MCD-F4001 | id | DocumentoFiscal | MAPPED |
| MCD-F4002 | tipo_documento_fiscal | DocumentoFiscal | MAPPED (DST-GAP-007, aberto) |
| MCD-F4003 | numero_documento_fiscal | DocumentoFiscal | MAPPED |
| MCD-F4004 | chave_documento_fiscal | DocumentoFiscal | MAPPED |
| MCD-F4005 | codigo_servico_fiscal | DocumentoFiscal | MAPPED |
| MCD-F4006 | descricao_servico_fiscal | DocumentoFiscal | MAPPED |
| MCD-F4007 | valor_documento_fiscal | DocumentoFiscal | MAPPED |
| MCD-F4301 | id | ReceitaDocumentoFiscal | MAPPED |
| MCD-F4302 | receita_id | ReceitaDocumentoFiscal | MAPPED |
| MCD-F4303 | documento_fiscal_id | ReceitaDocumentoFiscal | MAPPED |
| MCD-F4401 | id | DocumentoFiscalArquivoOrigem | MAPPED |
| MCD-F4402 | documento_fiscal_id | DocumentoFiscalArquivoOrigem | MAPPED |
| MCD-F4403 | arquivo_origem_id | DocumentoFiscalArquivoOrigem | MAPPED |
| MCD-F4404 | papel_arquivo | DocumentoFiscalArquivoOrigem | MAPPED (DST-GAP-011, aberto) |

### DOM-EH (11 IDs) — model `ClassificacaoEquiparacaoHospitalar`

| ID | Campo | Status |
|---|---|---|
| MCD-F5001 | status_elegibilidade_equiparacao_hospitalar | MAPPED_WITH_SQL_CONSTRAINT (DST-E003) |
| MCD-F5002 | percentual_receita_elegivel | MAPPED |
| MCD-F5003 | valor_receita_elegivel | MAPPED |
| MCD-F5004 | valor_receita_nao_elegivel | MAPPED |
| MCD-F5005 | percentual_confianca_classificacao | MAPPED |
| MCD-F5006 | eh_validada_tecnicamente | MAPPED |
| MCD-F5007 | receita_id | MAPPED |
| MCD-F5008 | regra_versao_id | MAPPED (ADR-GAP-005, opaco até RGT-001) |
| MCD-F5009 | id | MAPPED |
| MCD-F5010 | registrado_em | MAPPED |
| MCD-F5011 | atualizado_em | MAPPED |

### DOM-PRE (12 IDs) — models `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`

| ID | Campo | Model | Status |
|---|---|---|---|
| MCD-F6001 | id | ContribuicaoPrevidenciaria | MAPPED |
| MCD-F6002 | valor_inss_recolhido | ContribuicaoPrevidenciaria | MAPPED |
| MCD-F6003 | valor_salario_contribuicao | ContribuicaoPrevidenciaria | MAPPED |
| MCD-F6004 | valor_teto_previdenciario | ContribuicaoPrevidenciaria | MAPPED |
| MCD-F6005 | valor_excedente_inss | ContribuicaoPrevidenciaria | MAPPED |
| MCD-F6006 | vinculo_previdenciario_id | ContribuicaoPrevidenciaria | MAPPED |
| MCD-F6007 | pessoa_fisica_id | ContribuicaoPrevidenciaria | MAPPED |
| MCD-F6101 | id | VinculoPrevidenciario | MAPPED |
| MCD-F6102 | pessoa_fisica_id | VinculoPrevidenciario | MAPPED |
| MCD-F6103 | tipo_vinculo_previdenciario | VinculoPrevidenciario | MAPPED (DST-GAP-008, aberto) |
| MCD-F6104 | vigencia_inicio | VinculoPrevidenciario | MAPPED |
| MCD-F6105 | vigencia_fim | VinculoPrevidenciario | MAPPED |

### DOM-IRP (10 IDs) — model `EventoIRPF`

| ID | Campo | Status |
|---|---|---|
| MCD-F7001 | id | MAPPED |
| MCD-F7002 | tipo_rendimento_irpf | MAPPED_WITH_SQL_CONSTRAINT (DST-E004) |
| MCD-F7003 | valor_rendimento_tributavel | MAPPED |
| MCD-F7004 | valor_rendimento_isento | MAPPED |
| MCD-F7005 | valor_deducao_irpf | MAPPED |
| MCD-F7006 | valor_livro_caixa | MAPPED |
| MCD-F7007 | valor_irpf_retido | MAPPED |
| MCD-F7008 | valor_irpf_projetado | MAPPED |
| MCD-F7009 | pessoa_fisica_id | MAPPED |
| MCD-F7010 | fonte_pagadora_id | MAPPED |

### DOM-PLN (5 IDs) — model `CenarioTributario`

| ID | Campo | Status |
|---|---|---|
| MCD-F8001 | id | MAPPED |
| MCD-F8002 | nome | MAPPED |
| MCD-F8003 | valor_carga_tributaria_projetada | MAPPED |
| MCD-F8004 | valor_economia_tributaria_projetada | MAPPED |
| MCD-F8005 | unidade_economica_id | MAPPED |

### DOM-SYS (42 IDs) — models `ResultadoCalculo`, `ArquivoOrigem`, `ConflitoDado`, `ConflitoDadoItem`, `RevisaoTecnica`, transversais F9001–F9010

| ID | Campo | Model(s) / Ocorrências | Status |
|---|---|---|---|
| MCD-F8201 | id | ResultadoCalculo | MAPPED |
| MCD-F8202 | cenario_tributario_id | ResultadoCalculo | MAPPED |
| MCD-F8203 | input_snapshot_hash | ResultadoCalculo | MAPPED |
| MCD-F8204 | engine_id | ResultadoCalculo | MAPPED |
| MCD-F8205 | engine_version | ResultadoCalculo | MAPPED |
| MCD-F8206 | rule_set_id | ResultadoCalculo | MAPPED (ADR-GAP-005, opaco) |
| MCD-F8207 | rule_set_version | ResultadoCalculo | MAPPED (ADR-GAP-005, opaco) |
| MCD-F8208 | calculado_em | ResultadoCalculo | MAPPED |
| MCD-F8209 | status_revisao | ResultadoCalculo | MAPPED_WITH_SQL_CONSTRAINT (DST-E006) |
| MCD-F8401 | id | ArquivoOrigem | MAPPED |
| MCD-F8402 | nome_arquivo | ArquivoOrigem | MAPPED |
| MCD-F8403 | hash_conteudo | ArquivoOrigem | MAPPED |
| MCD-F8404 | tipo_mime | ArquivoOrigem | MAPPED |
| MCD-F8405 | armazenamento_referencia | ArquivoOrigem | MAPPED |
| MCD-F8601 | id | ConflitoDado | MAPPED |
| MCD-F8602 | status_conflito | ConflitoDado | MAPPED_WITH_SQL_CONSTRAINT (DST-E007) |
| MCD-F8603 | tipo_conflito | ConflitoDado | MAPPED (DST-GAP-009, aberto) |
| MCD-F8604 | descricao | ConflitoDado | MAPPED |
| MCD-F8650 | id | ConflitoDadoItem | MAPPED |
| MCD-F8651 | conflito_dado_id | ConflitoDadoItem | MAPPED |
| MCD-F8652 | tipo_objeto | ConflitoDadoItem | MAPPED (DST-GAP-012, aberto/restrito) |
| MCD-F8653 | objeto_id | ConflitoDadoItem | MAPPED (exceção polimórfica controlada, sem FK) |
| MCD-F8654 | sistema_origem (próprio de ConflitoDadoItem) | ConflitoDadoItem | MAPPED_WITH_SQL_CONSTRAINT (DST-E010) |
| MCD-F8655 | identificador_origem (próprio) | ConflitoDadoItem | MAPPED |
| MCD-F8656 | papel_no_conflito | ConflitoDadoItem | MAPPED (DST-GAP-013, aberto) |
| MCD-F8657 | valor_hash | ConflitoDadoItem | MAPPED |
| MCD-F8701 | id | RevisaoTecnica | MAPPED |
| MCD-F8702 | objeto_revisado_id | RevisaoTecnica | MAPPED (exceção polimórfica controlada, sem FK) |
| MCD-F8703 | tipo_objeto_revisado | RevisaoTecnica | MAPPED (DST-GAP-010, aberto) |
| MCD-F8704 | status_revisao | RevisaoTecnica | MAPPED_WITH_SQL_CONSTRAINT (DST-E006) |
| MCD-F8705 | justificativa | RevisaoTecnica | MAPPED |
| MCD-F8706 | revisado_em | RevisaoTecnica | MAPPED |
| MCD-F9001 | sistema_origem (transversal) | Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal (4 ocorrências) | MAPPED_WITH_SQL_CONSTRAINT (DST-E010) |
| MCD-F9002 | identificador_origem (transversal) | mesmos 4 hosts | MAPPED |
| MCD-F9003 | importado_em (transversal) | mesmos 4 hosts | MAPPED |
| MCD-F9004 | status_processamento_dado (transversal) | mesmos 4 hosts | MAPPED_WITH_SQL_CONSTRAINT (DST-E009) |
| **MCD-F9005** | versao_schema | 0 ocorrências | **DEFERRED_BY_GAP** (bloqueado por EVT-001/INT-001) |
| **MCD-F9006** | correlation_id | 0 ocorrências | **DEFERRED_BY_GAP** (bloqueado por EVT-001/INT-001) |
| MCD-F9007 | registrado_em (transversal) | 16 hosts (ver ADR-D017) | MAPPED nos 16; ausência em `ResultadoCalculo`/`RevisaoTecnica` é `ADR-GAP-008`, não resolvida por inferência |
| MCD-F9008 | data_fato (transversal) | Receita, ContribuicaoPrevidenciaria, EventoIRPF (3 ocorrências) | MAPPED |
| MCD-F9009 | arquivo_origem_id (transversal) | DocumentoFiscal (via `DocumentoFiscalArquivoOrigem`, 1 ocorrência) | MAPPED via relacionamento; ausência em Receita/ContribuicaoPrevidenciaria/EventoIRPF é `ADR-GAP-007`, não resolvida por inferência |
| MCD-F9010 | status_qualidade_dado (transversal) | mesmos 4 hosts de F9001 | MAPPED_WITH_SQL_CONSTRAINT (DST-E011) |

### DOM-SEC (12 IDs) — models `Tenant`, `EventoAuditoriaSeguranca`, `ContaAcesso`, `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica` (novo nesta revisão)

| ID | Campo | Model(s) / Ocorrências | Status |
|---|---|---|---|
| MCD-F10001 | id | Tenant | MAPPED |
| MCD-F10002 | tenant_id | UnidadeEconomica | MAPPED |
| MCD-F10003 | tenant_id (transversal) | ArquivoOrigem, ConflitoDado, RevisaoTecnica (3 ocorrências) | MAPPED |
| MCD-F10004 | unidade_economica_id (transversal) | 6 hospedeiros (ver §7) | MAPPED (5×) / mutabilidade `Imutável` documentada em `ResultadoCalculo` |
| MCD-F10005 | papel (transversal) | ContaAcessoTenant, ContaAcessoUnidadeEconomica (2 ocorrências) | MAPPED (DST-GAP-015, aberto) |
| MCD-F10006 | id | EventoAuditoriaSeguranca | MAPPED |
| MCD-F10007 | id | ContaAcesso | MAPPED |
| MCD-F10008 | conta_acesso_id (transversal) | ContaAcessoTenant, ContaAcessoUnidadeEconomica (2 ocorrências) | MAPPED_WITH_SQL_CONSTRAINT (participa do invariante `ADR-C014` pendente de PoC) |
| MCD-F10009 | id | ContaAcessoTenant | MAPPED |
| MCD-F10010 | tenant_id | ContaAcessoTenant | MAPPED_WITH_SQL_CONSTRAINT (participa de `ADR-C014`) |
| MCD-F10011 | id | ContaAcessoUnidadeEconomica | MAPPED |
| MCD-F10012 | unidade_economica_id | ContaAcessoUnidadeEconomica | MAPPED_WITH_SQL_CONSTRAINT (participa de `ADR-C014`) |

### Nota sobre `DEFERRED_BY_ARCHITECTURE` e `NOT_AUTHORIZED`

Nenhum dos 151 IDs se enquadra em `DEFERRED_BY_ARCHITECTURE` — a única decisão puramente
arquitetural desta revisão (não usar FK composta nos 6 hospedeiros de `MCD-F10004`) é uma decisão
**relacional**, não a ausência de um campo/ID específico (o campo `unidade_economica_id` em si
está `MAPPED` em todos os 6; apenas a FORMA da FK — simples, não composta — é a decisão
arquitetural, documentada em `ADR-001` V1.1 §4, não em um status de ID individual). Nenhum ID se
enquadra em `NOT_AUTHORIZED` — todos os 151 são campos canônicos aprovados por `MCD-001` V1.4.

### Resumo da reconciliação

| Classificação | Quantidade de IDs |
|---|---|
| `MAPPED` | 127 |
| `MAPPED_WITH_SQL_CONSTRAINT` | 22 |
| `DEFERRED_BY_GAP` | 2 (`MCD-F9005`, `MCD-F9006`) |
| `DEFERRED_BY_ARCHITECTURE` | 0 |
| `NOT_AUTHORIZED` | 0 |
| **Total** | **151** |

**Separação exigida:** número de IDs canônicos reconciliados = **151**. Número real de colunas
escalares físicas no `schema.prisma` = **189** (ver §22) — a diferença (38) é inteiramente
explicada por IDs transversais mapeando para múltiplas colunas físicas (`MCD-F9001..F9004`/`F9010`
× 4 hosts cada = 20 colunas de 5 IDs; `MCD-F9007` × 16 hosts = 16 colunas de 1 ID; `MCD-F9008` × 3
hosts = 3 colunas de 1 ID; `MCD-F10003` × 3 hosts = 3 colunas de 1 ID; `MCD-F10004` × 6 hosts = 6
colunas de 1 ID; `MCD-F10005` × 2 = 2 colunas de 1 ID; `MCD-F10008` × 2 = 2 colunas de 1 ID) — 
verificado que a aritmética fecha: 151 IDs únicos, cada um mapeado para 1 ou mais colunas,
totalizando 189 colunas físicas (`MCD-F9009` conta como mapeado por relacionamento, não coluna
direta, portanto não soma a este total).

---

## 18. Auditoria de models (reconfirmação)

Ver §3. Confirmado novamente após a escrita completa do schema: 25 models, 0 enums, `CredencialAcesso`/`Sessao`/`PapelAcesso`/`Permissao` ausentes.

## 19. IDs aposentados

| Verificação | Resultado |
|---|---|
| `MCD-F2506..F2509` (campos polimórficos de Vinculo, removidos na V1.2) | Ausentes — confirmado por grep |
| `MCD-F3006`/`F3009` (`tipo_titular`/`titular_id` polimórfico, removidos) | Ausentes — a única ocorrência da string é um comentário histórico explicando a remoção, não uma reintrodução |
| `MCD-F4008` (`DocumentoFiscal.arquivo_origem_id` único, removido) | Ausente — confirmado que `DocumentoFiscal` não tem coluna `arquivo_origem_id` direta; a relação com `ArquivoOrigem` continua exclusivamente via `DocumentoFiscalArquivoOrigem` (N:N) |
| Relações polimórficas de ownership financeiro | Nenhuma nova foi introduzida — `ConflitoDadoItem.objeto_id` e `RevisaoTecnica.objeto_revisado_id` permanecem as únicas exceções controladas, ambas pré-existentes, ambas inalteradas |

## 20. Validação técnica

| Comando | Resultado |
|---|---|
| `prisma format` | ✓ `Formatted prisma\schema.prisma in 101ms` |
| `prisma validate` | ✓ `The schema at prisma\schema.prisma is valid` |
| `prisma generate` | ✓ `Generated Prisma Client (v6.19.3)` |
| `npm run lint` | ✓ sem erros (ESLint, `packages apps tests`) |
| `npm run typecheck` | ✓ sem erros (`tsc -b --pretty`) |
| `npm test` | ✓ 24/24 testes passando (7 arquivos, Vitest) — nenhum teste dependia do schema físico; nenhuma regressão em `packages/types`/`packages/integrations` |

`DATABASE_URL` foi fornecida apenas como variável de ambiente inline (`postgresql://user:pass@
localhost:5432/tmp_validate_only`) para os comandos `prisma format`/`validate`/`generate`
funcionarem — **nunca gravada em `.env` ou em qualquer arquivo versionado**. Nenhuma conexão real
foi estabelecida (esses três comandos não conectam a um banco; apenas leem/parseiam o
`schema.prisma`). Nenhum banco persistente foi tocado.

## 21. Diff completo — classificação de cada alteração

Diff calculado contra o `schema.prisma` do commit anterior (`git show HEAD:...`): **334 linhas
adicionadas, 11 linhas "removidas"** — as 11 remoções são exclusivamente realinhamento de
espaçamento produzido por `prisma format` (colunas de tipo Prisma realinhadas porque nomes de
campo mais longos foram adicionados aos mesmos models) — nenhum conteúdo foi de fato removido,
confirmado por inspeção linha a linha das 11 remoções.

| Alteração | Classificação |
|---|---|
| Bloco de comentário "Atualização desta versão — Revisão pós-SEC" no cabeçalho | `SEC_BASELINE` |
| `UnidadeEconomica.tenant_id` + relação + `@@unique([id, tenant_id])` + 7 back-relations novas | `SEC_BASELINE` |
| `unidade_economica_id` em Receita/ContribuicaoPrevidenciaria/VinculoPrevidenciario/EventoIRPF/DocumentoFiscal/ResultadoCalculo | `SEC_BASELINE` |
| `tenant_id` em ArquivoOrigem/ConflitoDado/RevisaoTecnica | `SEC_BASELINE` |
| 5 novos models (`Tenant`, `EventoAuditoriaSeguranca`, `ContaAcesso`, `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`) | `SEC_BASELINE` |
| `@@index` novos (`unidade_economica_id`/`tenant_id` em 9 hospedeiros) | `ADR_V1.1` (§7 do ADR, `IDX-006`/`IDX-007`) |
| Comentários documentando `ADR-C014 = SQL MANUAL PENDENTE DE PoC` | `ADR_V1.1` |
| Comentários documentando mutabilidade `Versionado`/`Imutável` por campo | `ADR_V1.1` (§13 do ADR) |
| Realinhamento de espaçamento (`prisma format`) em 3 models pré-existentes | `SEC_BASELINE` (efeito colateral inevitável de adicionar campos aos mesmos models — nenhum conteúdo alterado) |

**Nenhuma alteração foi classificada `INCONSISTENCIA`** — toda alteração tem causa direta e
rastreável em `MCD-001` V1.4, `CDC-001` V1.4 ou `ADR-001` V1.1.

## 22. Gate

### Totais

| Métrica | Valor |
|---|---|
| Total de models | 25 |
| Total de scalar columns | 189 (168 pré-SEC + 21 novas) |
| Total de relation/navigation fields | 68 (40 pré-SEC + 28 novos) |
| Total de enums Prisma | 0 |
| IDs MCD reconciliados | 151 / 151 |
| Constraints Prisma nativas (novas) | 8 (`UnidadeEconomica.tenant_id` FK, `@@unique([id,tenant_id])`, 9 FKs simples de `unidade_economica_id`/`tenant_id`, `@@unique` × 2 nas associações de acesso — contadas por tipo de constraint, não por ocorrência individual) |
| Constraints ainda destinadas a SQL manual (novas) | 1 (`ADR-C014`, não implementada, pendente de PoC) + 1 candidata não formalizada (consistência `ResultadoCalculo`/`CenarioTributario`) |
| Gaps preservados | Todos os `ADR-GAP-001..008`, `DST-GAP-001..015`, `GAP-CDC-*`, `GAP-SEC-CR1-*` — nenhum fechado por este schema; `ADR-GAP-009` (novo, do `ADR-001` V1.1) confirmado sem mecanismo físico, tratado por processo |
| Testes executados | `prisma format`/`validate`/`generate` ✓; `npm run lint` ✓; `npm run typecheck` ✓; `npm test` (24/24) ✓ |

### Achados por severidade

| Achado | Severidade |
|---|---|
| `ADR-C014` não implementada — `ContaAcessoUnidadeEconomica` fica sem enforcement físico do invariante de dependência até a PoC ser conduzida | `NAO_BLOQUEANTE` — decisão já prevista e documentada no `ADR-001` V1.1 (mesmo padrão de `ADR-C005` na V1.0: schema aprovado com uma constraint pendente de PoC própria, não uma falha desta atualização) |
| Consistência `ResultadoCalculo.unidade_economica_id` × `CenarioTributario.unidade_economica_id` não tem constraint física (nem candidata formal) | `NAO_BLOQUEANTE` — mesma classe de decisão que `ADR-C014`, ainda mais cedo no processo (nem PoC foi proposta); registrado aqui para rastreabilidade, não bloqueia esta etapa |
| 21 novas colunas escalares aumentam a superfície de `@@index` necessária para performance de RLS futura | `EDITORIAL` — já endereçado pelos `@@index` adicionados nesta mesma atualização, conforme `IDX-006`/`IDX-007` do `ADR-001` V1.1 |
| Nenhuma outra divergência entre schema e fontes normativas encontrada | — |

**Contagem do gate:** `CRITICAL = 0`, `RELEVANTE = 0`.

### Conclusão

```
SCHEMA PRISMA PÓS-SEC ATUALIZADO E RECONCILIADO — APTO PARA PoC ADR-C014
```

Não foi gerada migration. Não foi executado banco. Não se avançou para o PoC — esta conclusão
autoriza exclusivamente a próxima etapa técnica (`ADR-001` V1.1 §19), que permanece uma ação
separada e explícita.
