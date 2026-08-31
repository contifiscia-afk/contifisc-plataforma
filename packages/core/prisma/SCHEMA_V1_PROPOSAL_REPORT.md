# Relatório da primeira proposta de `schema.prisma` canônico

**Status:** DRAFT para revisão humana. Não autoriza migration (ver `schema.prisma`, cabeçalho).
**Baseline:** COT-001 V1.1 (corrigido por errata), MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2,
ADR-001 V1.0 (aprovado — baseline física para PoC), PoC `ADR-C005 VALIDADO`.

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
| MCD-F0003 | UnidadeEconomica | status_registro | UnidadeEconomica | status_registro | StatusRegistro (enum) | enum status_registro | Não | — | DST-E008 | MAPPED |
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
| MCD-F2004 | PessoaJuridica | regime_tributario | PessoaJuridica | regime_tributario | RegimeTributario? (enum) | enum regime_tributario | Sim | — | DST-E001 | MAPPED |
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
| MCD-F2522 | VinculoExtremidade | lado_extremidade | VinculoExtremidade | lado_extremidade | LadoExtremidade (enum) | enum lado_extremidade | Não | — | ADR-C004 / DST-E012 | MAPPED |
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
| MCD-F5001 | ClassificacaoEqHop | status_elegibilidade_equiparacao_hospitalar | ClassificacaoEquiparacaoHospitalar | status_elegibilidade_equiparacao_hospitalar | StatusElegibilidadeEquiparacaoHospitalar? (enum) | enum | Sim | — | DST-E003 | MAPPED |
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
| MCD-F7002 | EventoIRPF | tipo_rendimento_irpf | EventoIRPF | tipo_rendimento_irpf | TipoRendimentoIrpf? (enum) | enum | Sim | — | DST-E004 | MAPPED |
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
| MCD-F7202 | FontePagadora | tipo_fonte_pagadora | FontePagadora | tipo_fonte_pagadora | TipoFontePagadora (enum) | enum | Não | — | DST-E005 | MAPPED |
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
| MCD-F8202 | ResultadoCalculo | cenario_tributario_id | ResultadoCalculo | cenario_tributario_id | String? | uuid | Sim | FK → CenarioTributario | Cascade* | MAPPED |
| MCD-F8203 | ResultadoCalculo | input_snapshot_hash | ResultadoCalculo | input_snapshot_hash | String | varchar(128) | Não | — | — | MAPPED |
| MCD-F8204 | ResultadoCalculo | engine_id | ResultadoCalculo | engine_id | String | varchar(80) | Não | — | — | MAPPED |
| MCD-F8205 | ResultadoCalculo | engine_version | ResultadoCalculo | engine_version | String | varchar(20) | Não | — | — | MAPPED |
| MCD-F8206 | ResultadoCalculo | rule_set_id | ResultadoCalculo | rule_set_id | String | varchar(80) | Não | — | Opaco até RGT-001 | DEFERRED_BY_GAP |
| MCD-F8207 | ResultadoCalculo | rule_set_version | ResultadoCalculo | rule_set_version | String | varchar(20) | Não | — | Opaco até RGT-001 | DEFERRED_BY_GAP |
| MCD-F8208 | ResultadoCalculo | calculado_em | ResultadoCalculo | calculado_em | DateTime | timestamptz | Não | — | — | MAPPED |
| MCD-F8209 | ResultadoCalculo | status_revisao | ResultadoCalculo | status_revisao | StatusRevisao? (enum) | enum | Sim | — | DST-E006 | MAPPED |

\* Cascade em `cenario_tributario_id` é uma decisão interpretativa do ADR §8 ("possível cascade
interno do cenário após política explícita") — sinalizada como achado RELEVANTE na auditoria (§3).

### ConflitoDado (`conflito_dado`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8601 | ConflitoDado | id | ConflitoDado | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8602 | ConflitoDado | status_conflito | ConflitoDado | status_conflito | StatusConflito (enum) | enum | Não | — | DST-E007 | MAPPED |
| MCD-F8603 | ConflitoDado | tipo_conflito | ConflitoDado | tipo_conflito | String | text | Não | — | DST-GAP-009 | DEFERRED_BY_GAP |
| MCD-F8604 | ConflitoDado | descricao | ConflitoDado | descricao | String? | text | Sim | — | — | MAPPED |

### ConflitoDadoItem (`conflito_dado_item`) — COT-SUP-004

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8650 | ConflitoDadoItem | id | ConflitoDadoItem | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8651 | ConflitoDadoItem | conflito_dado_id | ConflitoDadoItem | conflito_dado_id | String | uuid | Não | FK → ConflitoDado | Cascade | MAPPED |
| MCD-F8652 | ConflitoDadoItem | tipo_objeto | ConflitoDadoItem | tipo_objeto | String | text | Não | — | DST-GAP-012 | DEFERRED_BY_GAP |
| MCD-F8653 | ConflitoDadoItem | objeto_id | ConflitoDadoItem | objeto_id | String? | uuid | Sim | Exceção polimórfica — SEM FK | ADR §17 exceção controlada | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F8654 | ConflitoDadoItem | sistema_origem | ConflitoDadoItem | sistema_origem | SistemaOrigem? (enum) | enum | Sim | — | DST-E010 | MAPPED |
| MCD-F8655 | ConflitoDadoItem | identificador_origem | ConflitoDadoItem | identificador_origem | String? | varchar(120) | Sim | — | — | MAPPED |
| MCD-F8656 | ConflitoDadoItem | papel_no_conflito | ConflitoDadoItem | papel_no_conflito | String? | text | Sim | — | DST-GAP-013 | DEFERRED_BY_GAP |
| MCD-F8657 | ConflitoDadoItem | valor_hash | ConflitoDadoItem | valor_hash | String? | varchar(128) | Sim | — | — | MAPPED |

### RevisaoTecnica (`revisao_tecnica`)

| MCD | Objeto | Nome canônico | Model | Field | Tipo Prisma | Tipo PG esperado | Nullable | PK/FK | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| MCD-F8701 | RevisaoTecnica | id | RevisaoTecnica | id | String | uuid | Não | PK | — | MAPPED |
| MCD-F8702 | RevisaoTecnica | objeto_revisado_id | RevisaoTecnica | objeto_revisado_id | String | uuid | Não | Exceção polimórfica — SEM FK | Mesmo padrão de ConflitoDadoItem | MAPPED_WITH_SQL_CONSTRAINT |
| MCD-F8703 | RevisaoTecnica | tipo_objeto_revisado | RevisaoTecnica | tipo_objeto_revisado | String | text | Não | — | DST-GAP-010 | DEFERRED_BY_GAP |
| MCD-F8704 | RevisaoTecnica | status_revisao | RevisaoTecnica | status_revisao | StatusRevisao (enum) | enum | Não | — | DST-E006 | MAPPED |
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
| ADR-C004 | VinculoExtremidade | lado_extremidade IN ('ORIGEM','DESTINO') | Sim (via enum nativo, ver achado RELEVANTE §3) | `enum LadoExtremidade { ORIGEM DESTINO }` | Não, se enum nativo for a decisão final; Sim (CHECK) se a decisão for reverter para TEXT+CHECK per ADR-D010 | MAPPED (condicional — ver achado) |
| ADR-C005 | Vinculo / VinculoExtremidade | Exatamente duas extremidades (1 ORIGEM + 1 DESTINO) — COT-REL-NORM-001 | Não | Relação 1:N estrutural declarada; comentário normativo remete à PoC | Sim — `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED` (validada pela PoC) | MAPPED_WITH_SQL_CONSTRAINT |
| ADR-C006 | ReceitaDocumentoFiscal | UNIQUE(receita_id, documento_fiscal_id) | Sim | `@@unique([receita_id, documento_fiscal_id])` | Não | MAPPED |
| ADR-C007 | DocumentoFiscalArquivoOrigem | Unicidade mínima (documento_fiscal_id, arquivo_origem_id) | Sim | `@@unique([documento_fiscal_id, arquivo_origem_id])` | Não agora; revisar quando `papel_arquivo` (DST-GAP-011) fechar | MAPPED |
| ADR-C008 | ClassificacaoEquiparacaoHospitalar | PK própria + histórico não destrutivo | Sim (PK); histórico é responsabilidade da camada de aplicação/repositório | `id` própria declarada; `registrado_em`/`atualizado_em` presentes | Não para a PK; a garantia de "não sobrescrever destrutivamente" é de aplicação, não de constraint SQL | MAPPED |
| ADR-C009 | Receita.competencia | CHECK formato YYYY-MM e mês 01-12 | Não | `String? @db.VarChar(7)` + comentário normativo | Sim — CHECK regex/formato | MAPPED_WITH_SQL_CONSTRAINT |
| ADR-C010 | ConflitoDadoItem | Validação de tipo_objeto/objeto_id por serviço de domínio (exceção polimórfica) | Não (por desenho — não deve virar FK) | Campos declarados sem `@relation`; comentário explícito de exceção controlada | Não é CHECK/FK; validação fica na camada de aplicação/auditoria, conforme o próprio ADR-C010 determina | MAPPED_WITH_SQL_CONSTRAINT (validação, não constraint de banco) |

## 3. Auditoria cruzada final — `schema.prisma` × COT V1.1 × MCD V1.2 × CDC V1.2 × DST V1.2 × ADR-001 V1.0

| # | Achado | Classificação |
|---|---|---|
| 1 | **Enums nativos do Prisma para códigos DST fechados** (`StatusRegistro`, `RegimeTributario`, `LadoExtremidade`, `StatusElegibilidadeEquiparacaoHospitalar`, `TipoRendimentoIrpf`, `TipoFontePagadora`, `StatusRevisao`, `StatusConflito`, `SistemaOrigem`) geram `CREATE TYPE ... AS ENUM` nativo do PostgreSQL na migration futura. Isso diverge de **ADR-D010**, que recomenda TEXT + CHECK/lookup em vez de ENUM nativo, justamente para evitar a limitação histórica do `ALTER TYPE ... ADD VALUE` (não podia rodar dentro da mesma transação que já usa o novo valor) — risco relevante para os enums do DST que ainda vão evoluir. A instrução desta etapa (#19) pediu explicitamente "use enums fechados no DST"; segui essa instrução, mas o conflito com ADR-D010 é real e não foi resolvido por mim. **Decisão pendente de revisão humana:** manter enum nativo (aceitando a limitação de evolução) ou reverter para TEXT + CHECK (alinhado a ADR-D010). | **RELEVANTE** |
| 2 | **`ResultadoCalculo.cenario_tributario_id` com `onDelete: Cascade`** — interpretação da frase do ADR §8 "Cenários: possível cascade interno do cenário após política explícita". A própria frase do ADR sinaliza que isso NÃO é uma decisão fechada ("após política explícita" ainda não ocorreu). Apliquei Cascade como leitura mais provável, mas isso é uma escolha meu, não uma instrução literal e fechada do ADR. | **RELEVANTE** |
| 3 | **`RevisaoTecnica.objeto_revisado_id` tratado com a mesma exceção polimórfica controlada de `ConflitoDadoItem.objeto_id`**, sem FK. O ADR-001 (instrução #17 desta etapa) menciona explicitamente essa exceção só para `ConflitoDadoItem`; estendi o mesmo tratamento a `RevisaoTecnica` porque o COT-001 V1.1 (COT-REL-117/118) e o CDC-REV-001 descrevem `objeto_revisado_id` com a mesma natureza genérica/polimórfica (referencia múltiplos tipos de objeto). Não é uma instrução literal desta etapa, é inferência estrutural a partir do MCD/CDC/COT — sinalizando para confirmação humana. | **RELEVANTE** |
| 4 | Todos os 18 objetos `COT-OBJ-*` autorizados (16 incluídos + `ContaAcesso`/`CredencialAcesso` corretamente excluídos) e as 4 estruturas `COT-SUP-*` têm correspondência 1:1 nome/contrato/campo entre COT-001 V1.1, MCD-001 V1.2 e CDC-001 V1.2. Nenhuma divergência de nomenclatura encontrada. | **HISTÓRICO** (confirmação, não é problema) |
| 5 | `Receita.tipo_titular` (MCD-F3006, V1.1) e `titular_id` (MCD-F3009, V1.1) corretamente **não** incluídos — foram removidos pelo CR-002/MCD-001 V1.2 em favor de `pessoa_fisica_id`/`pessoa_juridica_id` com XOR. `DocumentoFiscal.arquivo_origem_id` (MCD-F4008, V1.1) corretamente **não** incluído — substituído por `DocumentoFiscalArquivoOrigem`. | **HISTÓRICO** (confirmação) |
| 6 | Metadados transversais (MCD-F9001..F9010) intencionalmente não replicados como colunas em nenhuma tabela — consistente com MCD-001 V1.2 §10 ("não há obrigação de replicá-los fisicamente... estratégia física a decidir"). | **EDITORIAL** (decisão documentada, não uma falha) |
| 7 | Nomenclatura de campo Prisma = nome MCD literal (snake_case), sem `@map` na maioria dos campos escalares — não há tradução para inglês em nenhum campo. Consistente com a instrução #6. | **HISTÓRICO** (confirmação) |
| 8 | Nenhum enum foi criado para os 13 gaps `DST-GAP-001/002/003/005/006/007/008/009/010/011/012/013` — todos permanecem `String`/`@db.Text`, sem lista fechada inventada. `DST-GAP-004` corretamente tratado como resolvido (usa o enum fechado `LadoExtremidade`, DST-E012). | **HISTÓRICO** (confirmação) |
| 9 | `GAP-CDC-1.2-004`/`GAP-MCD-CR2-005` (`FontePagadora.identificador_fiscal`) mantido como `String?` simples, sem union CPF/CNPJ/Exterior inventada — consistente com a nota do COT-001 V1.1 §15 de que esse gap é de modelagem/validação, não de vocabulário DST. | **HISTÓRICO** (confirmação) |
| 10 | Nenhuma trigger, function, CHECK SQL, partial index, RLS ou migration foi criada — só comentários normativos apontando o que a migration futura precisará conter (instrução #22 cumprida). | **HISTÓRICO** (confirmação) |

**Nenhuma inconsistência CRÍTICA foi encontrada** — nada neste draft impede a revisão humana ou uma eventual PoC/ajuste adicional. Os 3 achados RELEVANTE (enum nativo vs. ADR-D010; Cascade de ResultadoCalculo; extensão da exceção polimórfica a RevisaoTecnica) são decisões que tomei para poder produzir um arquivo completo e válido, mas que exigem confirmação explícita antes de qualquer migration.
