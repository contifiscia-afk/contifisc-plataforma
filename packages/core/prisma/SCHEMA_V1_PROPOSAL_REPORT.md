# Relatório da primeira proposta de `schema.prisma` canônico (v2, corrigida)

**Status:** DRAFT para revisão humana. Não autoriza migration (ver `schema.prisma`, cabeçalho).
**Baseline:** COT-001 V1.1 (corrigido por errata), MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2,
ADR-001 V1.0 (aprovado — baseline física para PoC), PoC `ADR-C005 VALIDADO`.

**v2 corrige os 3 achados RELEVANTE da v1** (ver §3): (1) removidos os 9 `enum` nativos do
Prisma — vocabulário fechado do DST agora é `String`/`@db.Text` com CHECK PostgreSQL futuro
documentado, conforme ADR-D010; (2) `ResultadoCalculo.cenario_tributario` volta a
`onDelete: Restrict`; (3) a exceção polimórfica de `RevisaoTecnica.objeto_revisado_id` foi
formalizada (não generalizada) como categoria distinta ("revisão/auditoria") da de
`ConflitoDadoItem` ("reconciliação").

## 1. Matriz de Rastreabilidade MCD → Prisma

Status: `MAPPED` (representável integralmente em Prisma) · `MAPPED_WITH_SQL_CONSTRAINT`
(mapeado, mas depende de CHECK/trigger SQL futuro para integridade completa) ·
`DEFERRED_BY_GAP` (tipo provisório por gap DST/MCD aberto, sem lista/FK inventada) ·
`NOT_AUTHORIZED` (campo do MCD não incluído nesta proposta).

### UnidadeEconomica (`unidade_economica`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F0001 | UnidadeEconomica | id | UnidadeEconomica | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F0002 | UnidadeEconomica | nome | UnidadeEconomica | nome | String | varchar(160) | Não | — | — | MAPPED |
| MCD-F0003 | UnidadeEconomica | status_registro | UnidadeEconomica | status_registro | String | text | Não | — | DST-E008 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F0004 | UnidadeEconomica | criado_em | UnidadeEconomica | criado_em | DateTime | timestamptz | Não | — | — | MAPPED |
| MCD-F0005 | UnidadeEconomica | atualizado_em | UnidadeEconomica | atualizado_em | DateTime | timestamptz | Não | — | — | MAPPED |

### PessoaFisica (`pessoa_fisica`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F1001 | PessoaFisica | id | PessoaFisica | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F1002 | PessoaFisica | cpf | PessoaFisica | cpf | String? | varchar(11) | Sim | — | — | MAPPED |
| MCD-F1003 | PessoaFisica | nome | PessoaFisica | nome | String | varchar(200) | Não | — | — | MAPPED |
| MCD-F1004 | PessoaFisica | data_nascimento | PessoaFisica | data_nascimento | DateTime? | date | Sim | — | — | MAPPED |
| MCD-F1005 | PessoaFisica | conselho_profissional | PessoaFisica | conselho_profissional | String? | text | Sim | — | DST-GAP-001 | DEFERRED_BY_GAP |
| MCD-F1006 | PessoaFisica | registro_profissional | PessoaFisica | registro_profissional | String? | varchar(30) | Sim | — | — | MAPPED |
| MCD-F1007 | PessoaFisica | uf_registro_profissional | PessoaFisica | uf_registro_profissional | String? | varchar(2) | Sim | — | — | MAPPED |
| MCD-F1008 | PessoaFisica | especialidade_saude | PessoaFisica | especialidade_saude | String? | text | Sim | — | DST-GAP-002 | DEFERRED_BY_GAP |

### PessoaJuridica (`pessoa_juridica`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F2001 | PessoaJuridica | id | PessoaJuridica | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F2002 | PessoaJuridica | cnpj | PessoaJuridica | cnpj | String? | varchar(14) | Sim | — | — | MAPPED |
| MCD-F2003 | PessoaJuridica | razao_social | PessoaJuridica | razao_social | String? | varchar(200) | Sim | — | — | MAPPED |
| MCD-F2004 | PessoaJuridica | regime_tributario | PessoaJuridica | regime_tributario | String? | text | Sim | — | DST-E001 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F2005 | PessoaJuridica | cnae_principal | PessoaJuridica | cnae_principal | String? | varchar(7) | Sim | — | — | MAPPED |
| MCD-F2006 | PessoaJuridica | data_abertura | PessoaJuridica | data_abertura | DateTime? | date | Sim | — | — | MAPPED |
| MCD-F2007 | PessoaJuridica | municipio_ibge | PessoaJuridica | municipio_ibge | String? | varchar(7) | Sim | — | — | MAPPED |

### Vinculo (`vinculo`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F2501 | Vinculo | id | Vinculo | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F2502 | Vinculo | tipo_vinculo | Vinculo | tipo_vinculo | String | text | Não | — | DST-GAP-003 | DEFERRED_BY_GAP |
| MCD-F2503 | Vinculo | percentual_participacao_societaria | Vinculo | percentual_participacao_societaria | Decimal? | numeric(7,4) | Sim | — | — | MAPPED |
| MCD-F2504 | Vinculo | vigencia_inicio | Vinculo | vigencia_inicio | DateTime? | date | Sim | — | — | MAPPED |
| MCD-F2505 | Vinculo | vigencia_fim | Vinculo | vigencia_fim | DateTime? | date | Sim | — | — | MAPPED |
| MCD-F2510 | Vinculo | papel_vinculo | Vinculo | papel_vinculo | String? | text | Sim | — | DST-GAP-005 | DEFERRED_BY_GAP |

### VinculoExtremidade (`vinculo_extremidade`) — COT-SUP-001

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F2520 | VinculoExtremidade | id | VinculoExtremidade | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F2521 | VinculoExtremidade | vinculo_id | VinculoExtremidade | vinculo_id | String | uuid | Não | FK → Vinculo | Restrict | MAPPED |
| MCD-F2522 | VinculoExtremidade | lado_extremidade | VinculoExtremidade | lado_extremidade | String | text | Não | — | ADR-C004 / DST-E012 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F2523 | VinculoExtremidade | unidade_economica_id | VinculoExtremidade | unidade_economica_id | String? | uuid | Sim | FK → UnidadeEconomica | ADR-C002 (XOR) | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F2524 | VinculoExtremidade | pessoa_fisica_id | VinculoExtremidade | pessoa_fisica_id | String? | uuid | Sim | FK → PessoaFisica | ADR-C002 (XOR) | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F2525 | VinculoExtremidade | pessoa_juridica_id | VinculoExtremidade | pessoa_juridica_id | String? | uuid | Sim | FK → PessoaJuridica | ADR-C002 (XOR) | MAPPED_WITH_SQL_CONSTRAINT |
| — | VinculoExtremidade | (invariante da entidade) | VinculoExtremidade | — | — | — | — | — | ADR-C003 UNIQUE(vinculo_id,lado) — declarado em Prisma; ADR-C005/COT-REL-NORM-001 (2 extremidades exatas) — trigger SQL futuro, validada por PoC | MAPPED_WITH_SQL_CONSTRAINT |

### Receita (`receita`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F3001 | Receita | id | Receita | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F3002 | Receita | valor_receita_bruta | Receita | valor_receita_bruta | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F3003 | Receita | data_emissao | Receita | data_emissao | DateTime? | date | Sim | — | — | MAPPED |
| MCD-F3004 | Receita | competencia | Receita | competencia | String? | varchar(7) | Sim | — | ADR-C009 (CHECK futuro) | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F3005 | Receita | fonte_receita | Receita | fonte_receita | String? | text | Sim | — | DST-GAP-006 | DEFERRED_BY_GAP |
| MCD-F3007 | Receita | fonte_pagadora_id | Receita | fonte_pagadora_id | String? | uuid | Sim | FK → FontePagadora | Restrict | MAPPED |
| MCD-F3008 | Receita | valor_retencoes | Receita | valor_retencoes | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F3010 | Receita | pessoa_fisica_id | Receita | pessoa_fisica_id | String? | uuid | Sim | FK → PessoaFisica | ADR-C001 (XOR) | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F3011 | Receita | pessoa_juridica_id | Receita | pessoa_juridica_id | String? | uuid | Sim | FK → PessoaJuridica | ADR-C001 (XOR) | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F3006 (V1.1) | Receita | tipo_titular | — | — | — | — | — | — | REMOVIDO pelo CR-002/MCD V1.2 | NOT_AUTHORIZED |
| MCD-F3009 (V1.1) | Receita | titular_id | — | — | — | — | — | — | REMOVIDO pelo CR-002/MCD V1.2 | NOT_AUTHORIZED |

### DocumentoFiscal (`documento_fiscal`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F4001 | DocumentoFiscal | id | DocumentoFiscal | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F4002 | DocumentoFiscal | tipo_documento_fiscal | DocumentoFiscal | tipo_documento_fiscal | String | text | Não | — | DST-GAP-007 | DEFERRED_BY_GAP |
| MCD-F4003 | DocumentoFiscal | numero_documento_fiscal | DocumentoFiscal | numero_documento_fiscal | String? | varchar(60) | Sim | — | — | MAPPED |
| MCD-F4004 | DocumentoFiscal | chave_documento_fiscal | DocumentoFiscal | chave_documento_fiscal | String? | varchar(80) | Sim | — | índice IDX-004 | MAPPED |
| MCD-F4005 | DocumentoFiscal | codigo_servico_fiscal | DocumentoFiscal | codigo_servico_fiscal | String? | varchar(30) | Sim | — | — | MAPPED |
| MCD-F4006 | DocumentoFiscal | descricao_servico_fiscal | DocumentoFiscal | descricao_servico_fiscal | String? | text | Sim | — | — | MAPPED |
| MCD-F4007 | DocumentoFiscal | valor_documento_fiscal | DocumentoFiscal | valor_documento_fiscal | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F4008 (V1.1) | DocumentoFiscal | arquivo_origem_id | — | — | — | — | — | — | REMOVIDO — substituído por DocumentoFiscalArquivoOrigem N:N | NOT_AUTHORIZED |

### ReceitaDocumentoFiscal (`receita_documento_fiscal`) — COT-SUP-002

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F4301 | ReceitaDocumentoFiscal | id | ReceitaDocumentoFiscal | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F4302 | ReceitaDocumentoFiscal | receita_id | ReceitaDocumentoFiscal | receita_id | String | uuid | Não | FK → Receita | Cascade (só associação) | MAPPED |
| MCD-F4303 | ReceitaDocumentoFiscal | documento_fiscal_id | ReceitaDocumentoFiscal | documento_fiscal_id | String | uuid | Não | FK → DocumentoFiscal | Cascade (só associação) | MAPPED |
| — | ReceitaDocumentoFiscal | (invariante) | — | — | — | — | — | — | ADR-C006 UNIQUE(receita_id,documento_fiscal_id) | MAPPED |

### ArquivoOrigem (`arquivo_origem`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8401 | ArquivoOrigem | id | ArquivoOrigem | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8402 | ArquivoOrigem | nome_arquivo | ArquivoOrigem | nome_arquivo | String? | varchar(255) | Sim | — | — | MAPPED |
| MCD-F8403 | ArquivoOrigem | hash_conteudo | ArquivoOrigem | hash_conteudo | String | varchar(128) | Não | — | — | MAPPED |
| MCD-F8404 | ArquivoOrigem | tipo_mime | ArquivoOrigem | tipo_mime | String? | varchar(120) | Sim | — | — | MAPPED |
| MCD-F8405 | ArquivoOrigem | armazenamento_referencia | ArquivoOrigem | armazenamento_referencia | String | varchar(500) | Não | — | — | MAPPED |

### DocumentoFiscalArquivoOrigem (`documento_fiscal_arquivo_origem`) — COT-SUP-003

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F4401 | DocumentoFiscalArquivoOrigem | id | DocumentoFiscalArquivoOrigem | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F4402 | DocumentoFiscalArquivoOrigem | documento_fiscal_id | DocumentoFiscalArquivoOrigem | documento_fiscal_id | String | uuid | Não | FK → DocumentoFiscal | Cascade (só associação) | MAPPED |
| MCD-F4403 | DocumentoFiscalArquivoOrigem | arquivo_origem_id | DocumentoFiscalArquivoOrigem | arquivo_origem_id | String | uuid | Não | FK → ArquivoOrigem | Restrict (evidência RAW) | MAPPED |
| MCD-F4404 | DocumentoFiscalArquivoOrigem | papel_arquivo | DocumentoFiscalArquivoOrigem | papel_arquivo | String? | text | Sim | — | DST-GAP-011 | DEFERRED_BY_GAP |
| — | DocumentoFiscalArquivoOrigem | (invariante) | — | — | — | — | — | — | ADR-C007 unicidade mínima (documento_fiscal_id, arquivo_origem_id) | MAPPED |

### ClassificacaoEquiparacaoHospitalar (`classificacao_equiparacao_hospitalar`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F5001 | ClassificacaoEqHop | status_elegibilidade_equiparacao_hospitalar | ClassificacaoEquiparacaoHospitalar | status_elegibilidade_equiparacao_hospitalar | String? | text | Sim | — | DST-E003 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F5002 | ClassificacaoEqHop | percentual_receita_elegivel | ClassificacaoEquiparacaoHospitalar | percentual_receita_elegivel | Decimal? | numeric(7,4) | Sim | — | — | MAPPED |
| MCD-F5003 | ClassificacaoEqHop | valor_receita_elegivel | ClassificacaoEquiparacaoHospitalar | valor_receita_elegivel | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F5004 | ClassificacaoEqHop | valor_receita_nao_elegivel | ClassificacaoEquiparacaoHospitalar | valor_receita_nao_elegivel | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F5005 | ClassificacaoEqHop | percentual_confianca_classificacao | ClassificacaoEquiparacaoHospitalar | percentual_confianca_classificacao | Decimal? | numeric(7,4) | Sim | — | — | MAPPED |
| MCD-F5006 | ClassificacaoEqHop | eh_validada_tecnicamente | ClassificacaoEquiparacaoHospitalar | eh_validada_tecnicamente | Boolean? | boolean | Sim | — | — | MAPPED |
| MCD-F5007 | ClassificacaoEqHop | receita_id | ClassificacaoEquiparacaoHospitalar | receita_id | String | uuid | Não | FK → Receita | Restrict | MAPPED |
| MCD-F5008 | ClassificacaoEqHop | regra_versao_id | ClassificacaoEquiparacaoHospitalar | regra_versao_id | String? | varchar(120) | Sim | — | Opaco até RGT-001 | DEFERRED_BY_GAP |
| MCD-F5009 | ClassificacaoEqHop | id | ClassificacaoEquiparacaoHospitalar | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F5010 | ClassificacaoEqHop | registrado_em | ClassificacaoEquiparacaoHospitalar | registrado_em | DateTime | timestamptz | Não | — | — | MAPPED |
| MCD-F5011 | ClassificacaoEqHop | atualizado_em | ClassificacaoEquiparacaoHospitalar | atualizado_em | DateTime? | timestamptz | Sim | — | — | MAPPED |

### ContribuicaoPrevidenciaria (`contribuicao_previdenciaria`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F6001 | ContribuicaoPrevidenciaria | id | ContribuicaoPrevidenciaria | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F6002 | ContribuicaoPrevidenciaria | valor_inss_recolhido | ContribuicaoPrevidenciaria | valor_inss_recolhido | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F6003 | ContribuicaoPrevidenciaria | valor_salario_contribuicao | ContribuicaoPrevidenciaria | valor_salario_contribuicao | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F6004 | ContribuicaoPrevidenciaria | valor_teto_previdenciario | ContribuicaoPrevidenciaria | valor_teto_previdenciario | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F6005 | ContribuicaoPrevidenciaria | valor_excedente_inss | ContribuicaoPrevidenciaria | valor_excedente_inss | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F6006 | ContribuicaoPrevidenciaria | vinculo_previdenciario_id | ContribuicaoPrevidenciaria | vinculo_previdenciario_id | String? | uuid | Sim | FK → VinculoPrevidenciario | Restrict | MAPPED |
| MCD-F6007 | ContribuicaoPrevidenciaria | pessoa_fisica_id | ContribuicaoPrevidenciaria | pessoa_fisica_id | String | uuid | Não | FK → PessoaFisica | Restrict | MAPPED |

### VinculoPrevidenciario (`vinculo_previdenciario`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F6101 | VinculoPrevidenciario | id | VinculoPrevidenciario | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F6102 | VinculoPrevidenciario | pessoa_fisica_id | VinculoPrevidenciario | pessoa_fisica_id | String | uuid | Não | FK → PessoaFisica | Restrict | MAPPED |
| MCD-F6103 | VinculoPrevidenciario | tipo_vinculo_previdenciario | VinculoPrevidenciario | tipo_vinculo_previdenciario | String | text | Não | — | DST-GAP-008 | DEFERRED_BY_GAP |
| MCD-F6104 | VinculoPrevidenciario | vigencia_inicio | VinculoPrevidenciario | vigencia_inicio | DateTime? | date | Sim | — | — | MAPPED |
| MCD-F6105 | VinculoPrevidenciario | vigencia_fim | VinculoPrevidenciario | vigencia_fim | DateTime? | date | Sim | — | — | MAPPED |

### EventoIRPF (`evento_irpf`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F7001 | EventoIRPF | id | EventoIRPF | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F7002 | EventoIRPF | tipo_rendimento_irpf | EventoIRPF | tipo_rendimento_irpf | String? | text | Sim | — | DST-E004 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F7003 | EventoIRPF | valor_rendimento_tributavel | EventoIRPF | valor_rendimento_tributavel | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F7004 | EventoIRPF | valor_rendimento_isento | EventoIRPF | valor_rendimento_isento | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F7005 | EventoIRPF | valor_deducao_irpf | EventoIRPF | valor_deducao_irpf | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F7006 | EventoIRPF | valor_livro_caixa | EventoIRPF | valor_livro_caixa | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F7007 | EventoIRPF | valor_irpf_retido | EventoIRPF | valor_irpf_retido | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F7008 | EventoIRPF | valor_irpf_projetado | EventoIRPF | valor_irpf_projetado | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F7009 | EventoIRPF | pessoa_fisica_id | EventoIRPF | pessoa_fisica_id | String | uuid | Não | FK → PessoaFisica | Restrict | MAPPED |
| MCD-F7010 | EventoIRPF | fonte_pagadora_id | EventoIRPF | fonte_pagadora_id | String? | uuid | Sim | FK → FontePagadora | Restrict | MAPPED |

### FontePagadora (`fonte_pagadora`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F7201 | FontePagadora | id | FontePagadora | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F7202 | FontePagadora | tipo_fonte_pagadora | FontePagadora | tipo_fonte_pagadora | String | text | Não | — | DST-E005 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F7203 | FontePagadora | identificador_fiscal | FontePagadora | identificador_fiscal | String? | varchar(20) | Sim | — | GAP-CDC-1.2-004/GAP-MCD-CR2-005 | DEFERRED_BY_GAP |
| MCD-F7204 | FontePagadora | nome | FontePagadora | nome | String? | varchar(200) | Sim | — | — | MAPPED |

### CenarioTributario (`cenario_tributario`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8001 | CenarioTributario | id | CenarioTributario | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8002 | CenarioTributario | nome | CenarioTributario | nome | String | varchar(120) | Não | — | — | MAPPED |
| MCD-F8003 | CenarioTributario | valor_carga_tributaria_projetada | CenarioTributario | valor_carga_tributaria_projetada | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F8004 | CenarioTributario | valor_economia_tributaria_projetada | CenarioTributario | valor_economia_tributaria_projetada | Decimal? | numeric(18,2) | Sim | — | — | MAPPED |
| MCD-F8005 | CenarioTributario | unidade_economica_id | CenarioTributario | unidade_economica_id | String | uuid | Não | FK → UnidadeEconomica | Restrict | MAPPED |

### ResultadoCalculo (`resultado_calculo`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8201 | ResultadoCalculo | id | ResultadoCalculo | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8202 | ResultadoCalculo | cenario_tributario_id | ResultadoCalculo | cenario_tributario_id | String? | uuid | Sim | FK → CenarioTributario | **Restrict (corrigido de Cascade)** | MAPPED |
| MCD-F8203 | ResultadoCalculo | input_snapshot_hash | ResultadoCalculo | input_snapshot_hash | String | varchar(128) | Não | — | — | MAPPED |
| MCD-F8204 | ResultadoCalculo | engine_id | ResultadoCalculo | engine_id | String | varchar(80) | Não | — | — | MAPPED |
| MCD-F8205 | ResultadoCalculo | engine_version | ResultadoCalculo | engine_version | String | varchar(20) | Não | — | — | MAPPED |
| MCD-F8206 | ResultadoCalculo | rule_set_id | ResultadoCalculo | rule_set_id | String | varchar(80) | Não | — | Opaco até RGT-001 | DEFERRED_BY_GAP |
| MCD-F8207 | ResultadoCalculo | rule_set_version | ResultadoCalculo | rule_set_version | String | varchar(20) | Não | — | Opaco até RGT-001 | DEFERRED_BY_GAP |
| MCD-F8208 | ResultadoCalculo | calculado_em | ResultadoCalculo | calculado_em | DateTime | timestamptz | Não | — | — | MAPPED |
| MCD-F8209 | ResultadoCalculo | status_revisao | ResultadoCalculo | status_revisao | String? | text | Sim | — | DST-E006 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |

### ConflitoDado (`conflito_dado`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8601 | ConflitoDado | id | ConflitoDado | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8602 | ConflitoDado | status_conflito | ConflitoDado | status_conflito | String | text | Não | — | DST-E007 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F8603 | ConflitoDado | tipo_conflito | ConflitoDado | tipo_conflito | String | text | Não | — | DST-GAP-009 | DEFERRED_BY_GAP |
| MCD-F8604 | ConflitoDado | descricao | ConflitoDado | descricao | String? | text | Sim | — | — | MAPPED |

### ConflitoDadoItem (`conflito_dado_item`) — COT-SUP-004 — exceção polimórfica de **RECONCILIAÇÃO**

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8650 | ConflitoDadoItem | id | ConflitoDadoItem | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8651 | ConflitoDadoItem | conflito_dado_id | ConflitoDadoItem | conflito_dado_id | String | uuid | Não | FK → ConflitoDado | Cascade | MAPPED |
| MCD-F8652 | ConflitoDadoItem | tipo_objeto | ConflitoDadoItem | tipo_objeto | String | text | Não | — | DST-GAP-012 | DEFERRED_BY_GAP |
| MCD-F8653 | ConflitoDadoItem | objeto_id | ConflitoDadoItem | objeto_id | String? | uuid | Sim | Exceção polimórfica de reconciliação — SEM FK | Validação de domínio/auditoria, não SQL | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F8654 | ConflitoDadoItem | sistema_origem | ConflitoDadoItem | sistema_origem | String? | text | Sim | — | DST-E010 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F8655 | ConflitoDadoItem | identificador_origem | ConflitoDadoItem | identificador_origem | String? | varchar(120) | Sim | — | — | MAPPED |
| MCD-F8656 | ConflitoDadoItem | papel_no_conflito | ConflitoDadoItem | papel_no_conflito | String? | text | Sim | — | DST-GAP-013 | DEFERRED_BY_GAP |
| MCD-F8657 | ConflitoDadoItem | valor_hash | ConflitoDadoItem | valor_hash | String? | varchar(128) | Sim | — | — | MAPPED |

### RevisaoTecnica (`revisao_tecnica`) — exceção polimórfica de **REVISÃO/AUDITORIA** (categoria distinta de ConflitoDadoItem)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8701 | RevisaoTecnica | id | RevisaoTecnica | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8702 | RevisaoTecnica | objeto_revisado_id | RevisaoTecnica | objeto_revisado_id | String | uuid | Não | Exceção polimórfica de revisão/auditoria — SEM FK | Validação de domínio/auditoria, não SQL | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F8703 | RevisaoTecnica | tipo_objeto_revisado | RevisaoTecnica | tipo_objeto_revisado | String | text | Não | — | DST-GAP-010 | DEFERRED_BY_GAP |
| MCD-F8704 | RevisaoTecnica | status_revisao | RevisaoTecnica | status_revisao | String | text | Não | — | DST-E006 (fechado) — CHECK PostgreSQL futuro | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F8705 | RevisaoTecnica | justificativa | RevisaoTecnica | justificativa | String? | text | Sim | — | — | MAPPED |
| MCD-F8706 | RevisaoTecnica | revisado_em | RevisaoTecnica | revisado_em | DateTime | timestamptz | Não | — | — | MAPPED |

### Campos MCD V1.2 não incluídos nesta proposta (fora dos 20 objetos autorizados ou metadados transversais)

| MCD | Campo | Motivo |
|---|---|---|
| MCD-F9001..F9009 | sistema_origem (genérico), identificador_origem, importado_em, status_processamento_dado, versao_schema, correlation_id, registrado_em (genérico), data_fato, arquivo_origem_id (transversal) | Metadados transversais — MCD-001 V1.2 §10 diz explicitamente que a estratégia física (replicar por tabela, envelope ou tabela de lineage) ainda não foi decidida. Não incluídos para não inventar essa decisão. |
| MCD-F9010 | status_qualidade_dado (genérico) | Mesmo motivo acima. |
| COT-OBJ-017/018 | ContaAcesso, CredencialAcesso | Explicitamente fora do escopo desta etapa (aguardam SEC-001). |

## 2. Matriz de Constraints ADR → Prisma/SQL futuro

| ADR | Objeto | Regra | Representável em Prisma? | Representação Prisma nesta proposta | SQL futuro necessário? | Status |
|---|---|---|---|---|---|---|
| ADR-C001 | Receita | XOR pessoa_fisica_id / pessoa_juridica_id | Não | Campos declarados nullable; comentário normativo no schema | Sim — CHECK ((pessoa_fisica_id IS NOT NULL)::int + (pessoa_juridica_id IS NOT NULL)::int = 1) | MAPPED_WITH_SQL_CONSTRAINT |
| ADR-C002 | VinculoExtremidade | XOR do endpoint (UE/PF/PJ) | Não | 3 FKs opcionais declaradas; comentário normativo | Sim — CHECK equivalente (soma = 1) | MAPPED_WITH_SQL_CONSTRAINT |
| ADR-C003 | VinculoExtremidade | UNIQUE(vinculo_id, lado_extremidade) | Sim | `@@unique([vinculo_id, lado_extremidade])` | Não (Prisma gera o UNIQUE na migration) | MAPPED |
| ADR-C004 | VinculoExtremidade | lado_extremidade IN ('ORIGEM','DESTINO') | **Corrigido:** Não via ENUM nativo (ADR-D010 prevalece) | `String @db.Text` + comentário listando DST-E012 (ORIGEM, DESTINO) | Sim — CHECK PostgreSQL (`lado_extremidade IN ('ORIGEM','DESTINO')`), não PostgreSQL ENUM | MAPPED_WITH_SQL_CONSTRAINT |
| ADR-C005 | Vinculo / VinculoExtremidade | Exatamente duas extremidades (1 ORIGEM + 1 DESTINO) — COT-REL-NORM-001 | Não | Relação 1:N estrutural declarada; comentário normativo remete à PoC | Sim — `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED` (validada pela PoC) | MAPPED_WITH_SQL_CONSTRAINT |
| ADR-C006 | ReceitaDocumentoFiscal | UNIQUE(receita_id, documento_fiscal_id) | Sim | `@@unique([receita_id, documento_fiscal_id])` | Não | MAPPED |
| ADR-C007 | DocumentoFiscalArquivoOrigem | Unicidade mínima (documento_fiscal_id, arquivo_origem_id) | Sim | `@@unique([documento_fiscal_id, arquivo_origem_id])` | Não agora; revisar quando `papel_arquivo` (DST-GAP-011) fechar | MAPPED |
| ADR-C008 | ClassificacaoEquiparacaoHospitalar | PK própria + histórico não destrutivo | Sim (PK); histórico é responsabilidade da camada de aplicação/repositório | `id` própria declarada; `registrado_em`/`atualizado_em` presentes | Não para a PK; a garantia de "não sobrescrever destrutivamente" é de aplicação, não de constraint SQL | MAPPED |
| ADR-C009 | Receita.competencia | CHECK formato YYYY-MM e mês 01-12 | Não | `String? @db.VarChar(7)` + comentário normativo | Sim — CHECK regex/formato | MAPPED_WITH_SQL_CONSTRAINT |
| ADR-C010 | ConflitoDadoItem | Validação de tipo_objeto/objeto_id por serviço de domínio (exceção polimórfica de reconciliação) | Não (por desenho — não deve virar FK) | Campos declarados sem `@relation`; comentário explícito de exceção controlada | Não é CHECK/FK; validação fica na camada de aplicação/auditoria, conforme o próprio ADR-C010 determina | MAPPED_WITH_SQL_CONSTRAINT (validação, não constraint de banco) |

**Nota sobre os 9 vocabulários DST fechados que deixaram de ser ENUM nativo** (status_registro,
regime_tributario, lado_extremidade/ADR-C004, status_elegibilidade_equiparacao_hospitalar,
tipo_rendimento_irpf, tipo_fonte_pagadora, status_revisao ×2, status_conflito, sistema_origem):
todos passam a exigir **CHECK PostgreSQL** (não `CREATE TYPE ... AS ENUM`) na migration futura,
listado campo a campo na Matriz §1 acima. Nenhum documento canônico (COT/MCD/CDC/DST/ADR)
autoriza explicitamente ENUM nativo do PostgreSQL para nenhum campo desta proposta — por isso a
contagem de `enum` Prisma é **zero**, sem exceção criada por inferência.

## 3. Auditoria cruzada final (pós-correção) — `schema.prisma` × COT V1.1 × MCD V1.2 × CDC V1.2 × DST V1.2 × ADR-001 V1.0

| # | Achado | Classificação |
|---|---|---|
| 1 | **[CORRIGIDO]** Os 9 `enum` nativos do Prisma foram removidos. Os 9 campos de vocabulário fechado do DST agora são `String`/`@db.Text`, com comentário listando os códigos vigentes e apontando CHECK PostgreSQL futuro (não ENUM), alinhado a ADR-D010. Contagem de enums Prisma: 0. | **RESOLVIDO** (era RELEVANTE na v1) |
| 2 | **[CORRIGIDO]** `ResultadoCalculo.cenario_tributario` voltou a `onDelete: Restrict`. Nenhuma política de hard delete/cascade foi criada para Cenário; a frase do ADR §8 ("possível cascade... após política explícita") permanece sem decisão fechada, então a postura conservadora padrão (Restrict) foi adotada, não Cascade. | **RESOLVIDO** (era RELEVANTE na v1) |
| 3 | **[FORMALIZADO, NÃO GENERALIZADO]** `RevisaoTecnica.objeto_revisado_id` permanece sem FK (exceção polimórfica), mas agora está explicitamente rotulado como exceção de **REVISÃO/AUDITORIA**, categoricamente distinta da exceção de **RECONCILIAÇÃO** de `ConflitoDadoItem`, com comentário afirmando que (a) a integridade é validada pela camada de domínio/aplicação e auditada, não por FK; (b) `tipo_objeto_revisado` permanece aberto (DST-GAP-010) sem valor inventado; (c) o padrão é proibido para ownership de Receita/fatos financeiros/objetos tributários; (d) não deve ser generalizado para nenhum outro model. Nenhum novo model recebeu esse tratamento. | **RESOLVIDO** (era RELEVANTE na v1) |
| 4 | Todos os 18 objetos `COT-OBJ-*` autorizados (16 incluídos + `ContaAcesso`/`CredencialAcesso` corretamente excluídos) e as 4 estruturas `COT-SUP-*` têm correspondência 1:1 nome/contrato/campo entre COT-001 V1.1, MCD-001 V1.2 e CDC-001 V1.2. Nenhuma divergência de nomenclatura encontrada. | **HISTÓRICO** (confirmação) |
| 5 | `Receita.tipo_titular` (MCD-F3006, V1.1) e `titular_id` (MCD-F3009, V1.1) corretamente **não** incluídos — removidos pelo CR-002/MCD-001 V1.2. `DocumentoFiscal.arquivo_origem_id` (MCD-F4008, V1.1) corretamente **não** incluído — substituído por `DocumentoFiscalArquivoOrigem`. | **HISTÓRICO** (confirmação) |
| 6 | Metadados transversais (MCD-F9001..F9010) intencionalmente não replicados como colunas em nenhuma tabela — consistente com MCD-001 V1.2 §10 ("estratégia física a decidir"). | **EDITORIAL** (decisão documentada) |
| 7 | Nomenclatura de campo Prisma = nome MCD literal (snake_case), sem tradução para inglês em nenhum campo. | **HISTÓRICO** (confirmação) |
| 8 | Nenhum enum/união fechada foi criado para os 13 gaps `DST-GAP-001/002/003/005/006/007/008/009/010/011/012/013` — todos permanecem `String`/`@db.Text`. `DST-GAP-004` corretamente tratado como resolvido pela V1.2 (usa `lado_extremidade`, agora `String` documentado com DST-E012, não mais enum nativo — a resolução do gap continua válida; só a representação física do campo mudou de enum nativo para TEXT+CHECK). | **HISTÓRICO** (confirmação) |
| 9 | `GAP-CDC-1.2-004`/`GAP-MCD-CR2-005` (`FontePagadora.identificador_fiscal`) mantido como `String?` simples, sem union CPF/CNPJ/Exterior inventada. | **HISTÓRICO** (confirmação) |
| 10 | Nenhuma trigger, function, CHECK SQL, partial index, RLS ou migration foi criada — só comentários normativos apontando o que a migration futura precisará conter. | **HISTÓRICO** (confirmação) |
| 11 | A distinção explícita entre a exceção polimórfica de `ConflitoDadoItem` (reconciliação) e a de `RevisaoTecnica` (revisão/auditoria) está documentada em ambos os models e na Matriz §1, sem generalizar o padrão para nenhum objeto financeiro/tributário. | **HISTÓRICO** (confirmação da correção #3) |

**Nenhuma inconsistência CRÍTICA ou RELEVANTE remanescente.** Os 3 achados RELEVANTE da v1 foram
corrigidos nesta v2; os achados remanescentes são todos HISTÓRICO/EDITORIAL (confirmações, não
pendências).

## 4. Reconciliação quantitativa integral MCD-001 V1.2 × `schema.prisma` (139/139)

Tabela com **exatamente uma linha por campo canônico dos 139** do catálogo MCD-001 V1.2 §8.
`schema.prisma` não foi alterado para esta reconciliação — é uma auditoria somente leitura.

### DOM-CORE — UnidadeEconomica (5 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F0001 | UnidadeEconomica | id | MAPPED | UnidadeEconomica | id | — |
| MCD-F0002 | UnidadeEconomica | nome | MAPPED | UnidadeEconomica | nome | — |
| MCD-F0003 | UnidadeEconomica | status_registro | MAPPED_WITH_SQL_CONSTRAINT | UnidadeEconomica | status_registro | — |
| MCD-F0004 | UnidadeEconomica | criado_em | MAPPED | UnidadeEconomica | criado_em | — |
| MCD-F0005 | UnidadeEconomica | atualizado_em | MAPPED | UnidadeEconomica | atualizado_em | — |

### DOM-PER — PessoaFisica (8 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F1001 | PessoaFisica | id | MAPPED | PessoaFisica | id | — |
| MCD-F1002 | PessoaFisica | cpf | MAPPED | PessoaFisica | cpf | — |
| MCD-F1003 | PessoaFisica | nome | MAPPED | PessoaFisica | nome | — |
| MCD-F1004 | PessoaFisica | data_nascimento | MAPPED | PessoaFisica | data_nascimento | — |
| MCD-F1005 | PessoaFisica | conselho_profissional | DEFERRED_BY_GAP | PessoaFisica | conselho_profissional | DST-GAP-001: catálogo aberto; campo existe como String/@db.Text, sem lista fechada |
| MCD-F1006 | PessoaFisica | registro_profissional | MAPPED | PessoaFisica | registro_profissional | — |
| MCD-F1007 | PessoaFisica | uf_registro_profissional | MAPPED | PessoaFisica | uf_registro_profissional | — |
| MCD-F1008 | PessoaFisica | especialidade_saude | DEFERRED_BY_GAP | PessoaFisica | especialidade_saude | DST-GAP-002: catálogo aberto; campo existe como String/@db.Text, sem lista fechada |

### DOM-EMP — PessoaJuridica (7 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F2001 | PessoaJuridica | id | MAPPED | PessoaJuridica | id | — |
| MCD-F2002 | PessoaJuridica | cnpj | MAPPED | PessoaJuridica | cnpj | — |
| MCD-F2003 | PessoaJuridica | razao_social | MAPPED | PessoaJuridica | razao_social | — |
| MCD-F2004 | PessoaJuridica | regime_tributario | MAPPED_WITH_SQL_CONSTRAINT | PessoaJuridica | regime_tributario | — |
| MCD-F2005 | PessoaJuridica | cnae_principal | MAPPED | PessoaJuridica | cnae_principal | — |
| MCD-F2006 | PessoaJuridica | data_abertura | MAPPED | PessoaJuridica | data_abertura | — |
| MCD-F2007 | PessoaJuridica | municipio_ibge | MAPPED | PessoaJuridica | municipio_ibge | — |

### DOM-REL — Vinculo + VinculoExtremidade (12 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F2501 | Vinculo | id | MAPPED | Vinculo | id | — |
| MCD-F2502 | Vinculo | tipo_vinculo | DEFERRED_BY_GAP | Vinculo | tipo_vinculo | DST-GAP-003: catálogo aberto |
| MCD-F2503 | Vinculo | percentual_participacao_societaria | MAPPED | Vinculo | percentual_participacao_societaria | — |
| MCD-F2504 | Vinculo | vigencia_inicio | MAPPED | Vinculo | vigencia_inicio | — |
| MCD-F2505 | Vinculo | vigencia_fim | MAPPED | Vinculo | vigencia_fim | — |
| MCD-F2510 | Vinculo | papel_vinculo | DEFERRED_BY_GAP | Vinculo | papel_vinculo | DST-GAP-005: catálogo aberto |
| MCD-F2520 | VinculoExtremidade | id | MAPPED | VinculoExtremidade | id | — |
| MCD-F2521 | VinculoExtremidade | vinculo_id | MAPPED | VinculoExtremidade | vinculo_id | — |
| MCD-F2522 | VinculoExtremidade | lado_extremidade | MAPPED_WITH_SQL_CONSTRAINT | VinculoExtremidade | lado_extremidade | — |
| MCD-F2523 | VinculoExtremidade | unidade_economica_id | MAPPED_WITH_SQL_CONSTRAINT | VinculoExtremidade | unidade_economica_id | ADR-C002 XOR — CHECK futuro |
| MCD-F2524 | VinculoExtremidade | pessoa_fisica_id | MAPPED_WITH_SQL_CONSTRAINT | VinculoExtremidade | pessoa_fisica_id | ADR-C002 XOR — CHECK futuro |
| MCD-F2525 | VinculoExtremidade | pessoa_juridica_id | MAPPED_WITH_SQL_CONSTRAINT | VinculoExtremidade | pessoa_juridica_id | ADR-C002 XOR — CHECK futuro |

### DOM-REC — Receita + FontePagadora (13 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F3001 | Receita | id | MAPPED | Receita | id | — |
| MCD-F3002 | Receita | valor_receita_bruta | MAPPED | Receita | valor_receita_bruta | — |
| MCD-F3003 | Receita | data_emissao | MAPPED | Receita | data_emissao | — |
| MCD-F3004 | Receita | competencia | MAPPED_WITH_SQL_CONSTRAINT | Receita | competencia | — |
| MCD-F3005 | Receita | fonte_receita | DEFERRED_BY_GAP | Receita | fonte_receita | DST-GAP-006: catálogo aberto |
| MCD-F3007 | Receita | fonte_pagadora_id | MAPPED | Receita | fonte_pagadora_id | — |
| MCD-F3008 | Receita | valor_retencoes | MAPPED | Receita | valor_retencoes | — |
| MCD-F3010 | Receita | pessoa_fisica_id | MAPPED_WITH_SQL_CONSTRAINT | Receita | pessoa_fisica_id | ADR-C001 XOR — CHECK futuro |
| MCD-F3011 | Receita | pessoa_juridica_id | MAPPED_WITH_SQL_CONSTRAINT | Receita | pessoa_juridica_id | ADR-C001 XOR — CHECK futuro |
| MCD-F7201 | FontePagadora | id | MAPPED | FontePagadora | id | — |
| MCD-F7202 | FontePagadora | tipo_fonte_pagadora | MAPPED_WITH_SQL_CONSTRAINT | FontePagadora | tipo_fonte_pagadora | — |
| MCD-F7203 | FontePagadora | identificador_fiscal | DEFERRED_BY_GAP | FontePagadora | identificador_fiscal | GAP-CDC-1.2-004/GAP-MCD-CR2-005: tipagem CPF/CNPJ/Exterior ainda aberta |
| MCD-F7204 | FontePagadora | nome | MAPPED | FontePagadora | nome | — |

### DOM-FIS — DocumentoFiscal + ReceitaDocumentoFiscal + DocumentoFiscalArquivoOrigem (14 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F4001 | DocumentoFiscal | id | MAPPED | DocumentoFiscal | id | — |
| MCD-F4002 | DocumentoFiscal | tipo_documento_fiscal | DEFERRED_BY_GAP | DocumentoFiscal | tipo_documento_fiscal | DST-GAP-007: catálogo aberto |
| MCD-F4003 | DocumentoFiscal | numero_documento_fiscal | MAPPED | DocumentoFiscal | numero_documento_fiscal | — |
| MCD-F4004 | DocumentoFiscal | chave_documento_fiscal | MAPPED | DocumentoFiscal | chave_documento_fiscal | — |
| MCD-F4005 | DocumentoFiscal | codigo_servico_fiscal | MAPPED | DocumentoFiscal | codigo_servico_fiscal | — |
| MCD-F4006 | DocumentoFiscal | descricao_servico_fiscal | MAPPED | DocumentoFiscal | descricao_servico_fiscal | — |
| MCD-F4007 | DocumentoFiscal | valor_documento_fiscal | MAPPED | DocumentoFiscal | valor_documento_fiscal | — |
| MCD-F4301 | ReceitaDocumentoFiscal | id | MAPPED | ReceitaDocumentoFiscal | id | — |
| MCD-F4302 | ReceitaDocumentoFiscal | receita_id | MAPPED | ReceitaDocumentoFiscal | receita_id | — |
| MCD-F4303 | ReceitaDocumentoFiscal | documento_fiscal_id | MAPPED | ReceitaDocumentoFiscal | documento_fiscal_id | — |
| MCD-F4401 | DocumentoFiscalArquivoOrigem | id | MAPPED | DocumentoFiscalArquivoOrigem | id | — |
| MCD-F4402 | DocumentoFiscalArquivoOrigem | documento_fiscal_id | MAPPED | DocumentoFiscalArquivoOrigem | documento_fiscal_id | — |
| MCD-F4403 | DocumentoFiscalArquivoOrigem | arquivo_origem_id | MAPPED | DocumentoFiscalArquivoOrigem | arquivo_origem_id | — |
| MCD-F4404 | DocumentoFiscalArquivoOrigem | papel_arquivo | DEFERRED_BY_GAP | DocumentoFiscalArquivoOrigem | papel_arquivo | DST-GAP-011: catálogo aberto |

### DOM-EH — ClassificacaoEquiparacaoHospitalar (11 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F5001 | ClassificacaoEqHop | status_elegibilidade_equiparacao_hospitalar | MAPPED_WITH_SQL_CONSTRAINT | ClassificacaoEquiparacaoHospitalar | status_elegibilidade_equiparacao_hospitalar | — |
| MCD-F5002 | ClassificacaoEqHop | percentual_receita_elegivel | MAPPED | ClassificacaoEquiparacaoHospitalar | percentual_receita_elegivel | — |
| MCD-F5003 | ClassificacaoEqHop | valor_receita_elegivel | MAPPED | ClassificacaoEquiparacaoHospitalar | valor_receita_elegivel | — |
| MCD-F5004 | ClassificacaoEqHop | valor_receita_nao_elegivel | MAPPED | ClassificacaoEquiparacaoHospitalar | valor_receita_nao_elegivel | — |
| MCD-F5005 | ClassificacaoEqHop | percentual_confianca_classificacao | MAPPED | ClassificacaoEquiparacaoHospitalar | percentual_confianca_classificacao | — |
| MCD-F5006 | ClassificacaoEqHop | eh_validada_tecnicamente | MAPPED | ClassificacaoEquiparacaoHospitalar | eh_validada_tecnicamente | — |
| MCD-F5007 | ClassificacaoEqHop | receita_id | MAPPED | ClassificacaoEquiparacaoHospitalar | receita_id | — |
| MCD-F5008 | ClassificacaoEqHop | regra_versao_id | DEFERRED_BY_GAP | ClassificacaoEquiparacaoHospitalar | regra_versao_id | Opaco até RGT-001 (ADR-GAP-005); não é FK |
| MCD-F5009 | ClassificacaoEqHop | id | MAPPED | ClassificacaoEquiparacaoHospitalar | id | — |
| MCD-F5010 | ClassificacaoEqHop | registrado_em | MAPPED | ClassificacaoEquiparacaoHospitalar | registrado_em | — |
| MCD-F5011 | ClassificacaoEqHop | atualizado_em | MAPPED | ClassificacaoEquiparacaoHospitalar | atualizado_em | — |

### DOM-PRE — ContribuicaoPrevidenciaria + VinculoPrevidenciario (12 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F6001 | ContribuicaoPrevidenciaria | id | MAPPED | ContribuicaoPrevidenciaria | id | — |
| MCD-F6002 | ContribuicaoPrevidenciaria | valor_inss_recolhido | MAPPED | ContribuicaoPrevidenciaria | valor_inss_recolhido | — |
| MCD-F6003 | ContribuicaoPrevidenciaria | valor_salario_contribuicao | MAPPED | ContribuicaoPrevidenciaria | valor_salario_contribuicao | — |
| MCD-F6004 | ContribuicaoPrevidenciaria | valor_teto_previdenciario | MAPPED | ContribuicaoPrevidenciaria | valor_teto_previdenciario | — |
| MCD-F6005 | ContribuicaoPrevidenciaria | valor_excedente_inss | MAPPED | ContribuicaoPrevidenciaria | valor_excedente_inss | — |
| MCD-F6006 | ContribuicaoPrevidenciaria | vinculo_previdenciario_id | MAPPED | ContribuicaoPrevidenciaria | vinculo_previdenciario_id | — |
| MCD-F6007 | ContribuicaoPrevidenciaria | pessoa_fisica_id | MAPPED | ContribuicaoPrevidenciaria | pessoa_fisica_id | — |
| MCD-F6101 | VinculoPrevidenciario | id | MAPPED | VinculoPrevidenciario | id | — |
| MCD-F6102 | VinculoPrevidenciario | pessoa_fisica_id | MAPPED | VinculoPrevidenciario | pessoa_fisica_id | — |
| MCD-F6103 | VinculoPrevidenciario | tipo_vinculo_previdenciario | DEFERRED_BY_GAP | VinculoPrevidenciario | tipo_vinculo_previdenciario | DST-GAP-008: catálogo aberto |
| MCD-F6104 | VinculoPrevidenciario | vigencia_inicio | MAPPED | VinculoPrevidenciario | vigencia_inicio | — |
| MCD-F6105 | VinculoPrevidenciario | vigencia_fim | MAPPED | VinculoPrevidenciario | vigencia_fim | — |

### DOM-IRP — EventoIRPF (10 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F7001 | EventoIRPF | id | MAPPED | EventoIRPF | id | — |
| MCD-F7002 | EventoIRPF | tipo_rendimento_irpf | MAPPED_WITH_SQL_CONSTRAINT | EventoIRPF | tipo_rendimento_irpf | — |
| MCD-F7003 | EventoIRPF | valor_rendimento_tributavel | MAPPED | EventoIRPF | valor_rendimento_tributavel | — |
| MCD-F7004 | EventoIRPF | valor_rendimento_isento | MAPPED | EventoIRPF | valor_rendimento_isento | — |
| MCD-F7005 | EventoIRPF | valor_deducao_irpf | MAPPED | EventoIRPF | valor_deducao_irpf | — |
| MCD-F7006 | EventoIRPF | valor_livro_caixa | MAPPED | EventoIRPF | valor_livro_caixa | — |
| MCD-F7007 | EventoIRPF | valor_irpf_retido | MAPPED | EventoIRPF | valor_irpf_retido | — |
| MCD-F7008 | EventoIRPF | valor_irpf_projetado | MAPPED | EventoIRPF | valor_irpf_projetado | — |
| MCD-F7009 | EventoIRPF | pessoa_fisica_id | MAPPED | EventoIRPF | pessoa_fisica_id | — |
| MCD-F7010 | EventoIRPF | fonte_pagadora_id | MAPPED | EventoIRPF | fonte_pagadora_id | — |

### DOM-PLN — CenarioTributario (5 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F8001 | CenarioTributario | id | MAPPED | CenarioTributario | id | — |
| MCD-F8002 | CenarioTributario | nome | MAPPED | CenarioTributario | nome | — |
| MCD-F8003 | CenarioTributario | valor_carga_tributaria_projetada | MAPPED | CenarioTributario | valor_carga_tributaria_projetada | — |
| MCD-F8004 | CenarioTributario | valor_economia_tributaria_projetada | MAPPED | CenarioTributario | valor_economia_tributaria_projetada | — |
| MCD-F8005 | CenarioTributario | unidade_economica_id | MAPPED | CenarioTributario | unidade_economica_id | — |

### DOM-SYS — ResultadoCalculo (9 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F8201 | ResultadoCalculo | id | MAPPED | ResultadoCalculo | id | — |
| MCD-F8202 | ResultadoCalculo | cenario_tributario_id | MAPPED | ResultadoCalculo | cenario_tributario_id | — |
| MCD-F8203 | ResultadoCalculo | input_snapshot_hash | MAPPED | ResultadoCalculo | input_snapshot_hash | — |
| MCD-F8204 | ResultadoCalculo | engine_id | MAPPED | ResultadoCalculo | engine_id | — |
| MCD-F8205 | ResultadoCalculo | engine_version | MAPPED | ResultadoCalculo | engine_version | — |
| MCD-F8206 | ResultadoCalculo | rule_set_id | DEFERRED_BY_GAP | ResultadoCalculo | rule_set_id | Opaco até RGT-001 (ADR-GAP-005); não é FK |
| MCD-F8207 | ResultadoCalculo | rule_set_version | DEFERRED_BY_GAP | ResultadoCalculo | rule_set_version | Opaco até RGT-001 (ADR-GAP-005); não é FK |
| MCD-F8208 | ResultadoCalculo | calculado_em | MAPPED | ResultadoCalculo | calculado_em | — |
| MCD-F8209 | ResultadoCalculo | status_revisao | MAPPED_WITH_SQL_CONSTRAINT | ResultadoCalculo | status_revisao | — |

### DOM-SYS — ArquivoOrigem (5 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F8401 | ArquivoOrigem | id | MAPPED | ArquivoOrigem | id | — |
| MCD-F8402 | ArquivoOrigem | nome_arquivo | MAPPED | ArquivoOrigem | nome_arquivo | — |
| MCD-F8403 | ArquivoOrigem | hash_conteudo | MAPPED | ArquivoOrigem | hash_conteudo | — |
| MCD-F8404 | ArquivoOrigem | tipo_mime | MAPPED | ArquivoOrigem | tipo_mime | — |
| MCD-F8405 | ArquivoOrigem | armazenamento_referencia | MAPPED | ArquivoOrigem | armazenamento_referencia | — |

### DOM-SYS — ConflitoDado (4 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F8601 | ConflitoDado | id | MAPPED | ConflitoDado | id | — |
| MCD-F8602 | ConflitoDado | status_conflito | MAPPED_WITH_SQL_CONSTRAINT | ConflitoDado | status_conflito | — |
| MCD-F8603 | ConflitoDado | tipo_conflito | DEFERRED_BY_GAP | ConflitoDado | tipo_conflito | DST-GAP-009: catálogo aberto |
| MCD-F8604 | ConflitoDado | descricao | MAPPED | ConflitoDado | descricao | — |

### DOM-SYS — ConflitoDadoItem (8 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F8650 | ConflitoDadoItem | id | MAPPED | ConflitoDadoItem | id | — |
| MCD-F8651 | ConflitoDadoItem | conflito_dado_id | MAPPED | ConflitoDadoItem | conflito_dado_id | — |
| MCD-F8652 | ConflitoDadoItem | tipo_objeto | DEFERRED_BY_GAP | ConflitoDadoItem | tipo_objeto | DST-GAP-012: catálogo aberto |
| MCD-F8653 | ConflitoDadoItem | objeto_id | MAPPED_WITH_SQL_CONSTRAINT | ConflitoDadoItem | objeto_id | Exceção polimórfica de reconciliação — sem FK, validação de aplicação |
| MCD-F8654 | ConflitoDadoItem | sistema_origem | MAPPED_WITH_SQL_CONSTRAINT | ConflitoDadoItem | sistema_origem | — |
| MCD-F8655 | ConflitoDadoItem | identificador_origem | MAPPED | ConflitoDadoItem | identificador_origem | — |
| MCD-F8656 | ConflitoDadoItem | papel_no_conflito | DEFERRED_BY_GAP | ConflitoDadoItem | papel_no_conflito | DST-GAP-013: catálogo aberto |
| MCD-F8657 | ConflitoDadoItem | valor_hash | MAPPED | ConflitoDadoItem | valor_hash | — |

### DOM-SYS — RevisaoTecnica (6 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F8701 | RevisaoTecnica | id | MAPPED | RevisaoTecnica | id | — |
| MCD-F8702 | RevisaoTecnica | objeto_revisado_id | MAPPED_WITH_SQL_CONSTRAINT | RevisaoTecnica | objeto_revisado_id | Exceção polimórfica de revisão/auditoria — sem FK, validação de aplicação |
| MCD-F8703 | RevisaoTecnica | tipo_objeto_revisado | DEFERRED_BY_GAP | RevisaoTecnica | tipo_objeto_revisado | DST-GAP-010: catálogo aberto |
| MCD-F8704 | RevisaoTecnica | status_revisao | MAPPED_WITH_SQL_CONSTRAINT | RevisaoTecnica | status_revisao | — |
| MCD-F8705 | RevisaoTecnica | justificativa | MAPPED | RevisaoTecnica | justificativa | — |
| MCD-F8706 | RevisaoTecnica | revisado_em | MAPPED | RevisaoTecnica | revisado_em | — |

### DOM-SYS — Metadados transversais (10 campos)

| ID MCD | Objeto | Nome do campo | Status | Model Prisma | Field Prisma | Justificativa |
|---|---|---|---|---|---|---|
| MCD-F9001 | Metadados Transversais | sistema_origem | OUT_OF_SCOPE | — | — | MCD-001 V1.2 §10: estratégia física (envelope/composição/tabela de lineage) ainda não decidida; não replicado por tabela nesta proposta |
| MCD-F9002 | Metadados Transversais | identificador_origem | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |
| MCD-F9003 | Metadados Transversais | importado_em | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |
| MCD-F9004 | Metadados Transversais | status_processamento_dado | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |
| MCD-F9005 | Metadados Transversais | versao_schema | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |
| MCD-F9006 | Metadados Transversais | correlation_id | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |
| MCD-F9007 | Metadados Transversais | registrado_em | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |
| MCD-F9008 | Metadados Transversais | data_fato | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |
| MCD-F9009 | Metadados Transversais | arquivo_origem_id | OUT_OF_SCOPE | — | — | Idem MCD-F9001 (restaurado por errata de publicação do MCD V1.2 §2.1; continua fora de escopo físico) |
| MCD-F9010 | Metadados Transversais | status_qualidade_dado | OUT_OF_SCOPE | — | — | Idem MCD-F9001 |

### Equação de fechamento

```
95 (MAPPED) + 18 (MAPPED_WITH_SQL_CONSTRAINT) + 16 (DEFERRED_BY_GAP) + 0 (NOT_AUTHORIZED) + 10 (OUT_OF_SCOPE) = 139
```

**139 = MAPPED + MAPPED_WITH_SQL_CONSTRAINT + DEFERRED_BY_GAP + NOT_AUTHORIZED + OUT_OF_SCOPE** ✓

Verificação independente: os 129 campos com coluna física real (95 + 18 + 16) batem exatamente
com a contagem estrutural de campos escalares do `schema.prisma` (129, obtida por script
percorrendo os 20 models e distinguindo campos escalares de campos de relação/navegação
virtuais). 129 + 10 (fora de escopo) = 139.

### Verificações adicionais exigidas

- **Nenhum ID MCD duplicado:** confirmado — cada uma das 139 linhas acima usa um ID MCD único;
  nenhum ID aparece em mais de uma linha.
- **Nenhum ID MCD ausente:** confirmado — a enumeração cobre integralmente F0001-F0005,
  F1001-F1008, F2001-F2007, F2501-F2505+F2510, F2520-F2525, F3001-F3005+F3007+F3008+F3010+F3011,
  F4001-F4007, F4301-F4303, F4401-F4404, F5001-F5011, F6001-F6007, F6101-F6105, F7001-F7010,
  F7201-F7204, F8001-F8005, F8201-F8209, F8401-F8405, F8601-F8604, F8650-F8657, F8701-F8706,
  F9001-F9010 — sem lacunas.
- **Nenhum field Prisma canônico sem correspondência no MCD, exceto campos técnicos autorizados
  pelo ADR:** confirmado. Os 129 campos escalares do `schema.prisma` correspondem 1:1 aos 129
  campos MAPPED/MAPPED_WITH_SQL_CONSTRAINT/DEFERRED_BY_GAP desta tabela. Os 40 campos de
  relação/navegação Prisma (`@relation(...)` e listas de back-relation, ex.: `vinculo
  Vinculo @relation(...)`, `receitas Receita[]`) são propriedades virtuais do ORM sem coluna
  física própria — não são "campos MCD" e portanto não entram nesta reconciliação de dados; a FK
  escalar correspondente a cada uma (`vinculo_id`, etc.) já está contabilizada com seu próprio ID
  MCD na tabela acima. Nenhum campo técnico adicional (ex.: `sistema_origem` genérico,
  `password_hash`, `tenant_id`) foi encontrado no schema — consistente com o que o ADR-001
  autorizou.
- **Campos removidos/superseded não reincorporados:** confirmado. `MCD-F3006` (tipo_titular),
  `MCD-F3009` (titular_id) e `MCD-F4008` (arquivo_origem_id único) são IDs **aposentados da
  MCD-001 V1.1**, formalmente removidos pelo CR-002 e **não fazem parte do catálogo de 139
  campos da V1.2** — por isso não aparecem como linha nesta reconciliação (que cobre
  exclusivamente os 139 campos vigentes da V1.2). Confirmei por inspeção direta que nenhum dos
  três nomes existe em `schema.prisma` (`Receita` não tem `tipo_titular`/`titular_id`;
  `DocumentoFiscal` não tem `arquivo_origem_id`).
- **Os 20 models autorizados continuam sendo os únicos models de domínio implementados:**
  confirmado — `grep -c "^model " schema.prisma` retorna exatamente 20, o mesmo conjunto desde a
  v2 (nenhuma alteração feita ao `schema.prisma` nesta rodada).

### Conclusão

**RECONCILIAÇÃO MCD → PRISMA FECHADA EM 139/139**
