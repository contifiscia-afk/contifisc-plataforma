# CDC-001 — Contrato Canônico de Dados da CONTIFISC

**Versão:** 1.2  
**Status:** APROVADO — sincronizado com MCD-001 V1.2  
**Supersede:** CDC-001 V1.1  
**Dependências:** CAF-001, COT-001, MCD-001 V1.2, DST-001 V1.1 (sincronização V1.2 pendente)  
**Incorpora:** MCD-CHANGE-REQUEST-002  
**Consumidores:** APIs, eventos, integrações, types, repositórios, ATI, GTI, MIT e Skills

> O CDC define fronteiras técnicas de entrada, saída, validação, mutabilidade, compatibilidade, proveniência e reprodutibilidade. Não cria objeto, campo ou regra tributária fora do COT/MCD/RGT.

## 1. Alterações da V1.2

- Sincronização integral com MCD-001 V1.2.
- Receita passa a usar pessoa_fisica_id XOR pessoa_juridica_id.
- Vinculo passa a usar CDC-REL-002 para duas extremidades com FKs reais.
- Novos contratos para ReceitaDocumentoFiscal e DocumentoFiscalArquivoOrigem.
- ClassificacaoEquiparacaoHospitalar passa a possuir id próprio.
- ConflitoDado ganha itens participantes estruturados.
- status_processamento_dado e status_qualidade_dado passam a ser eixos distintos.
- MCD-F9009 arquivo_origem_id é preservado; sua omissão inicial na publicação do MCD V1.2 foi corrigida por errata.
- Nenhum schema Prisma ou migration é autorizado.

## 2. Princípios obrigatórios

- Contract-first.
- Vendor-neutral.
- Fato não é sobrescrito por resultado derivado.
- Proveniência e histórico por padrão.
- No silent conflict resolution.
- Ownership financeiro central usa FKs reais.
- Campo/relação ausente gera Change Request.
- Competência é YYYY-MM, nunca data fictícia.

## 3. Envelope canônico V1.2

```yaml
canonical_envelope:
  contract_id: CDC-REC-001
  contract_version: 1.2.0
  record_id: <uuid>
  unidade_economica_id: <uuid|null>
  sujeito_id: <uuid|null>
  data_fato: <date|timestamp|null>
  competencia: <YYYY-MM|null>
  source:
    sistema_origem: <canonical_source_code|null>
    identificador_origem: <string|null>
    importado_em: <timestamp|null>
    arquivo_origem_id: <uuid|null>
  processing:
    status_processamento_dado: <canonical_processing_status|null>
  quality:
    status_qualidade_dado: <canonical_quality_status|null>
  correlation_id: <uuid|null>
  registrado_em: <timestamp>
  versao_schema: <semver>
  payload: {}
```

`unidade_economica_id` e `sujeito_id` são contexto de transporte, não autorização para FKs homônimas em todos os objetos. `arquivo_origem_id` no envelope é evidência RAW transversal; DocumentoFiscal usa também a associação CDC-FIS-003.

## 4. Tipos e validações gerais

- UUID interno; IDs externos ficam na proveniência.
- Money/Decimal exato; float proibido.
- Competencia YYYY-MM.
- Date YYYY-MM-DD; Timestamp ISO-8601 offset-aware.
- CPF/CNPJ só dígitos.
- Enum fechado somente quando publicado no DST; Enum/Ref sem catálogo permanece aberto/branded.
- null, zero, vazio e não aplicável são estados distintos.

## 5. Erros contratuais

| Código | Categoria | Uso |
|---|---|---|
| CDC-ERR-001 | VALIDATION_REQUIRED | Campo obrigatório ausente. |
| CDC-ERR-002 | VALIDATION_FORMAT | Formato inválido. |
| CDC-ERR-003 | VALIDATION_RANGE | Valor fora da faixa. |
| CDC-ERR-004 | ENUM_UNKNOWN | Enum fechado não reconhecido. |
| CDC-ERR-005 | CONTRACT_VERSION | Versão incompatível. |
| CDC-ERR-006 | DUPLICATE_SOURCE_RECORD | Possível duplicidade. |
| CDC-ERR-007 | SOURCE_CONFLICT | Fontes divergentes. |
| CDC-ERR-008 | IMMUTABLE_FIELD | Tentativa de sobrescrita. |
| CDC-ERR-009 | MCD_FIELD_UNKNOWN | Campo não registrado. |
| CDC-ERR-010 | REVIEW_REQUIRED | Revisão técnica necessária. |
| CDC-ERR-011 | RELATION_NOT_MODELED | Relação não formalizada. |
| CDC-ERR-012 | IDENTITY_NOT_MODELED | Identidade não formalizada. |
| CDC-ERR-013 | RELATION_XOR | Exclusividade relacional violada. |
| CDC-ERR-014 | RELATION_CARDINALITY | Cardinalidade violada. |
| CDC-ERR-015 | QUALITY_STATE_INVALID | Estado de qualidade inválido. |
| CDC-ERR-016 | PROCESSING_STATE_INVALID | Estado de processamento inválido. |

## 6. Contratos canônicos V1.2 (21 contratos)

### CDC-UE-001 — Unidade Econômica

**Domínio:** `DOM-CORE`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-001`  
**Objetivo:** Contexto econômico/tributário agregador; não substitui CPF ou CNPJ.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F0001 | output | required | system/import | immutable |
| nome | MCD-F0002 | input/output | required | manual/system | versioned |
| status_registro | MCD-F0003 | input/output | required | manual/system | versioned |
| criado_em | MCD-F0004 | output | required | system/import | immutable |
| atualizado_em | MCD-F0005 | output | required | system/import | versioned |

**Regras contratuais:**
- UE é contexto interno, não contribuinte.
- PF/PJ associam-se à UE apenas via Vinculo.
- Inativação é preferida à exclusão destrutiva quando houver dependências.

### CDC-PER-001 — Pessoa Física

**Domínio:** `DOM-PER`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-002`  
**Objetivo:** Pessoa natural em papéis tributários, societários ou profissionais.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F1001 | output | required | system/import | immutable |
| cpf | MCD-F1002 | input/output | conditional | manual/system | versioned |
| nome | MCD-F1003 | input/output | required | manual/system | versioned |
| data_nascimento | MCD-F1004 | input/output | optional | manual/system | versioned |
| conselho_profissional | MCD-F1005 | input/output | optional | manual/system | versioned |
| registro_profissional | MCD-F1006 | input/output | optional | manual/system | versioned |
| uf_registro_profissional | MCD-F1007 | input/output | optional | manual/system | versioned |
| especialidade_saude | MCD-F1008 | input/output | optional | manual/system | versioned |

**Regras contratuais:**
- cpf é condicional; ausência não autoriza identificação por nome.
- conselho_profissional e especialidade_saude permanecem Enum/Ref abertos até catálogo DST.
- Autenticação não pertence a PessoaFisica.

### CDC-EMP-001 — Pessoa Jurídica

**Domínio:** `DOM-EMP`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-003`  
**Objetivo:** Pessoa jurídica e atributos cadastrais/tributários canônicos.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F2001 | output | required | system/import | immutable |
| cnpj | MCD-F2002 | input/output | conditional | manual/system | versioned |
| razao_social | MCD-F2003 | input/output | optional | manual/system | versioned |
| regime_tributario | MCD-F2004 | input/output | conditional | manual/system | temporal |
| cnae_principal | MCD-F2005 | input/output | optional | manual/system | temporal |
| data_abertura | MCD-F2006 | input/output | optional | manual/system | versioned |
| municipio_ibge | MCD-F2007 | input/output | optional | manual/system | temporal |

**Regras contratuais:**
- regime_tributario usa somente códigos DST aprovados.
- CNPJ não é PK.
- Associação à UE ocorre por Vinculo.

### CDC-REL-001 — Vínculo

**Domínio:** `DOM-REL`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-004`  
**Objetivo:** Relacionamento de primeira classe; endpoints são materializados separadamente.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F2501 | output | required | system/import | immutable |
| tipo_vinculo | MCD-F2502 | input/output | required | manual/system | temporal |
| percentual_participacao_societaria | MCD-F2503 | input/output | optional | manual/system | temporal |
| vigencia_inicio | MCD-F2504 | input/output | optional | manual/system | temporal |
| vigencia_fim | MCD-F2505 | input/output | optional | manual/system | temporal |
| papel_vinculo | MCD-F2510 | input/output | conditional | manual/system | temporal |

**Regras contratuais:**
- Vinculo não contém endpoints polimórficos.
- Endpoints são exatamente duas extremidades em CDC-REL-002.
- tipo_vinculo e papel_vinculo permanecem sujeitos a catálogos DST.

### CDC-REL-002 — Vínculo - Extremidade

**Domínio:** `DOM-REL`  
**Versão:** `1.2.0`  
**COT:** `estrutura relacional de suporte`  
**Objetivo:** Materializa ORIGEM/DESTINO de Vínculo com FK real para UE, PF ou PJ.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F2520 | output | required | system/import | immutable |
| vinculo_id | MCD-F2521 | input/output | required | system/import | immutable |
| lado_extremidade | MCD-F2522 | input/output | required | manual/system | versioned |
| unidade_economica_id | MCD-F2523 | input/output | conditional | manual/system | temporal |
| pessoa_fisica_id | MCD-F2524 | input/output | conditional | manual/system | temporal |
| pessoa_juridica_id | MCD-F2525 | input/output | conditional | manual/system | temporal |

**Regras contratuais:**
- Exatamente uma extremidade ORIGEM e uma DESTINO por vínculo.
- Em cada extremidade, exatamente uma FK entre UE/PF/PJ.
- lado_extremidade deverá ser fechado no DST V1.2.

### CDC-REC-001 — Receita Canônica

**Domínio:** `DOM-REC`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-005`  
**Objetivo:** Fato canônico de receita com titularidade relacional explícita.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F3001 | output | required | system/import | immutable |
| valor_receita_bruta | MCD-F3002 | input/output | conditional | manual/system | immutable |
| data_emissao | MCD-F3003 | input/output | optional | system/import | immutable |
| competencia | MCD-F3004 | input/output | conditional | manual/system | immutable |
| fonte_receita | MCD-F3005 | input/output | conditional | system/import | versioned |
| fonte_pagadora_id | MCD-F3007 | input/output | optional | manual/system | versioned |
| valor_retencoes | MCD-F3008 | input/output | optional | system/import | immutable |
| pessoa_fisica_id | MCD-F3010 | input/output | conditional | system/import | versioned |
| pessoa_juridica_id | MCD-F3011 | input/output | conditional | system/import | versioned |

**Regras contratuais:**
- pessoa_fisica_id XOR pessoa_juridica_id.
- tipo_titular não é fonte de verdade na V1.2.
- Receita é fato; resultado derivado não sobrescreve valor_receita_bruta.

### CDC-FIS-001 — Documento Fiscal

**Domínio:** `DOM-FIS`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-006`  
**Objetivo:** Documento/evidência fiscal normalizada; não é o próprio fato Receita.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F4001 | output | required | system/import | immutable |
| tipo_documento_fiscal | MCD-F4002 | input/output | required | system/import | immutable |
| numero_documento_fiscal | MCD-F4003 | input/output | optional | system/import | immutable |
| chave_documento_fiscal | MCD-F4004 | input/output | optional | system/import | immutable |
| codigo_servico_fiscal | MCD-F4005 | input/output | optional | system/import | immutable |
| descricao_servico_fiscal | MCD-F4006 | input/output | optional | system/import | immutable |
| valor_documento_fiscal | MCD-F4007 | input/output | optional | system/import | immutable |

**Regras contratuais:**
- DocumentoFiscal não possui arquivo único direto.
- Arquivos RAW associam-se por CDC-FIS-003.
- Receitas associam-se por CDC-FIS-002.

### CDC-FIS-002 — Receita x Documento Fiscal

**Domínio:** `DOM-FIS`  
**Versão:** `1.2.0`  
**COT:** `estrutura relacional de suporte`  
**Objetivo:** Materializa a relação N:N Receita↔DocumentoFiscal.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F4301 | output | required | system/import | immutable |
| receita_id | MCD-F4302 | input/output | required | system/import | immutable |
| documento_fiscal_id | MCD-F4303 | input/output | required | system/import | immutable |

**Regras contratuais:**
- Unique(receita_id, documento_fiscal_id).
- Não aceitar rateio/percentual sem novo MCD/CDC.

### CDC-FIS-003 — Documento Fiscal x Arquivo de Origem

**Domínio:** `DOM-FIS`  
**Versão:** `1.2.0`  
**COT:** `estrutura relacional de suporte`  
**Objetivo:** Materializa a relação N:N DocumentoFiscal↔ArquivoOrigem.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F4401 | output | required | system/import | immutable |
| documento_fiscal_id | MCD-F4402 | input/output | required | system/import | immutable |
| arquivo_origem_id | MCD-F4403 | input/output | required | system/import | immutable |
| papel_arquivo | MCD-F4404 | input/output | optional | system/import | versioned |

**Regras contratuais:**
- Permite múltiplos arquivos por documento e documentos por arquivo.
- papel_arquivo permanece Enum/Ref aberto.
- ArquivoOrigem continua RAW/imutável.

### CDC-EH-001 — Classificação de Equiparação Hospitalar

**Domínio:** `DOM-EH`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-008`  
**Objetivo:** Resultado derivado/versionado de classificação EqHop ligado à Receita.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| status_elegibilidade_equiparacao_hospitalar | MCD-F5001 | input/output | conditional | engine/system | versioned |
| percentual_receita_elegivel | MCD-F5002 | input/output | optional | engine/system | versioned |
| valor_receita_elegivel | MCD-F5003 | input/output | optional | system/import | versioned |
| valor_receita_nao_elegivel | MCD-F5004 | input/output | optional | system/import | versioned |
| percentual_confianca_classificacao | MCD-F5005 | output | optional | system/import | versioned |
| eh_validada_tecnicamente | MCD-F5006 | output | optional | review/system | versioned |
| receita_id | MCD-F5007 | input/output | required | engine/system | versioned |
| regra_versao_id | MCD-F5008 | input/output | conditional | engine/system | versioned |
| id | MCD-F5009 | output | required | system/import | immutable |
| registrado_em | MCD-F5010 | output | required | engine/system | immutable |
| atualizado_em | MCD-F5011 | output | optional | engine/system | versioned |

**Regras contratuais:**
- id é identidade própria.
- regra_versao_id é opaco até RGT-001.
- eh_validada_tecnicamente é indicador derivado; revisão formal fica em RevisaoTecnica.
- Histórico não é sobrescrito destrutivamente.

### CDC-PRE-001 — Contribuição Previdenciária

**Domínio:** `DOM-PRE`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-009`  
**Objetivo:** Fato previdenciário de contribuição e excedente potencial.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F6001 | output | required | system/import | immutable |
| valor_inss_recolhido | MCD-F6002 | input/output | conditional | system/import | immutable |
| valor_salario_contribuicao | MCD-F6003 | input/output | optional | system/import | immutable |
| valor_teto_previdenciario | MCD-F6004 | input/output | conditional | system/import | versioned |
| valor_excedente_inss | MCD-F6005 | output | optional | system/import | versioned |
| vinculo_previdenciario_id | MCD-F6006 | input/output | optional | manual/system | temporal |
| pessoa_fisica_id | MCD-F6007 | input/output | required | system/import | versioned |

### CDC-PREV-001 — Vínculo Previdenciário

**Domínio:** `DOM-PRE`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-010`  
**Objetivo:** Origem/fonte previdenciária de uma Pessoa Física ao longo da vigência.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F6101 | output | required | system/import | immutable |
| pessoa_fisica_id | MCD-F6102 | input/output | required | manual/system | temporal |
| tipo_vinculo_previdenciario | MCD-F6103 | input/output | required | manual/system | temporal |
| vigencia_inicio | MCD-F6104 | input/output | optional | manual/system | temporal |
| vigencia_fim | MCD-F6105 | input/output | optional | manual/system | temporal |

### CDC-IRP-001 — Evento IRPF / Carnê-Leão

**Domínio:** `DOM-IRP`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-011`  
**Objetivo:** Fato/evento tributário da Pessoa Física relevante para IRPF/Carnê-Leão.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F7001 | output | required | system/import | immutable |
| tipo_rendimento_irpf | MCD-F7002 | input/output | conditional | system/import | versioned |
| valor_rendimento_tributavel | MCD-F7003 | input/output | optional | system/import | immutable |
| valor_rendimento_isento | MCD-F7004 | input/output | optional | system/import | immutable |
| valor_deducao_irpf | MCD-F7005 | input/output | optional | system/import | versioned |
| valor_livro_caixa | MCD-F7006 | input/output | optional | manual/system | versioned |
| valor_irpf_retido | MCD-F7007 | input/output | optional | system/import | immutable |
| valor_irpf_projetado | MCD-F7008 | output | optional | system/import | versioned |
| pessoa_fisica_id | MCD-F7009 | input/output | required | system/import | versioned |
| fonte_pagadora_id | MCD-F7010 | input/output | optional | manual/system | versioned |

### CDC-FPG-001 — Fonte Pagadora

**Domínio:** `DOM-REC`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-012`  
**Objetivo:** Fonte externa pagadora de Receita ou rendimento da PF.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F7201 | output | required | system/import | immutable |
| tipo_fonte_pagadora | MCD-F7202 | input/output | required | manual/system | versioned |
| identificador_fiscal | MCD-F7203 | input/output | optional | manual/system | versioned |
| nome | MCD-F7204 | input/output | optional | manual/system | versioned |

### CDC-PLN-001 — Cenário Tributário

**Domínio:** `DOM-PLN`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-013`  
**Objetivo:** Sandbox de planejamento; nunca sobrescreve fatos oficiais.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8001 | output | required | system/import | immutable |
| nome | MCD-F8002 | input/output | required | system/import | versioned |
| valor_carga_tributaria_projetada | MCD-F8003 | input/output | optional | system/import | versioned |
| valor_economia_tributaria_projetada | MCD-F8004 | input/output | optional | system/import | versioned |
| unidade_economica_id | MCD-F8005 | input/output | required | system/import | versioned |

### CDC-CAL-001 — Resultado de Cálculo

**Domínio:** `DOM-SYS`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-014`  
**Objetivo:** Resultado reproduzível ligado a snapshot, motor e versão de regras.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8201 | output | required | system/import | immutable |
| cenario_tributario_id | MCD-F8202 | input/output | optional | system/import | versioned |
| input_snapshot_hash | MCD-F8203 | output | required | engine/system | immutable |
| engine_id | MCD-F8204 | output | required | engine/system | immutable |
| engine_version | MCD-F8205 | output | required | engine/system | immutable |
| rule_set_id | MCD-F8206 | output | required | engine/system | immutable |
| rule_set_version | MCD-F8207 | output | required | engine/system | immutable |
| calculado_em | MCD-F8208 | output | required | engine/system | immutable |
| status_revisao | MCD-F8209 | input/output | optional | engine/system | versioned |

**Regras contratuais:**
- Preservar snapshot/hash, engine e versão.
- rule_set_id/rule_set_version são opacos até RGT-001.

### CDC-ARQ-001 — Arquivo de Origem

**Domínio:** `DOM-SYS`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-007`  
**Objetivo:** Evidência RAW/imutável e referência segura ao conteúdo armazenado.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8401 | output | required | system/import | immutable |
| nome_arquivo | MCD-F8402 | input/output | optional | system/import | immutable |
| hash_conteudo | MCD-F8403 | input/output | required | system/import | immutable |
| tipo_mime | MCD-F8404 | input/output | optional | system/import | immutable |
| armazenamento_referencia | MCD-F8405 | input/output | required | system/import | versioned |

### CDC-CFD-001 — Conflito de Dados

**Domínio:** `DOM-SYS`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-015`  
**Objetivo:** Objeto auditável que representa divergência entre dados/fontes.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8601 | output | required | system/import | immutable |
| status_conflito | MCD-F8602 | input/output | required | reconciliation | versioned |
| tipo_conflito | MCD-F8603 | input/output | required | reconciliation | versioned |
| descricao | MCD-F8604 | input/output | optional | reconciliation | versioned |

**Regras contratuais:**
- Conflito não é resolvido silenciosamente.
- Participantes são registrados por CDC-CFD-002.

### CDC-CFD-002 — Item de Conflito

**Domínio:** `DOM-SYS`  
**Versão:** `1.2.0`  
**COT:** `estrutura relacional de suporte`  
**Objetivo:** Registra os participantes/fontes de um ConflitoDado.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8650 | output | required | system/import | immutable |
| conflito_dado_id | MCD-F8651 | input/output | required | reconciliation | immutable |
| tipo_objeto | MCD-F8652 | input/output | required | reconciliation | versioned |
| objeto_id | MCD-F8653 | input/output | conditional | reconciliation | immutable |
| sistema_origem | MCD-F8654 | input/output | optional | reconciliation | immutable |
| identificador_origem | MCD-F8655 | input/output | optional | reconciliation | immutable |
| papel_no_conflito | MCD-F8656 | input/output | optional | reconciliation | versioned |
| valor_hash | MCD-F8657 | input/output | optional | reconciliation | immutable |

**Regras contratuais:**
- objeto_id + tipo_objeto é exceção polimórfica controlada de auditoria.
- Não reutilizar esse padrão em ownership financeiro.
- tipo_objeto e papel_no_conflito permanecem abertos até catálogo.

### CDC-REV-001 — Revisão Técnica

**Domínio:** `DOM-SYS`  
**Versão:** `1.2.0`  
**COT:** `COT-OBJ-016`  
**Objetivo:** Decisão humana/revisão auditável de objeto ou resultado.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8701 | output | required | system/import | immutable |
| objeto_revisado_id | MCD-F8702 | input/output | required | system/import | immutable |
| tipo_objeto_revisado | MCD-F8703 | input/output | required | system/import | immutable |
| status_revisao | MCD-F8704 | input/output | required | review/system | versioned |
| justificativa | MCD-F8705 | input/output | conditional | review/system | immutable |
| revisado_em | MCD-F8706 | input/output | required | system/import | immutable |

**Regras contratuais:**
- Identidade do revisor aguarda SEC-001/OBS-001.
- Referência genérica revisada é exceção de auditoria.

### CDC-SYS-001 — Metadados Transversais

**Domínio:** `DOM-SYS`  
**Versão:** `1.2.0`  
**COT:** `transversal`  
**Objetivo:** Proveniência, temporalidade, processamento, qualidade e correlação.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| sistema_origem | MCD-F9001 | input/output | required | integration/system | immutable |
| identificador_origem | MCD-F9002 | input/output | optional | integration/system | immutable |
| importado_em | MCD-F9003 | output | optional | integration/system | immutable |
| status_processamento_dado | MCD-F9004 | input/output | optional | reconciliation | versioned |
| versao_schema | MCD-F9005 | input/output | required | integration/system | immutable |
| correlation_id | MCD-F9006 | input/output | optional | integration/system | immutable |
| registrado_em | MCD-F9007 | output | required | system/import | immutable |
| data_fato | MCD-F9008 | input/output | optional | system/import | immutable |
| arquivo_origem_id | MCD-F9009 | input/output | optional | integration/system | immutable |
| status_qualidade_dado | MCD-F9010 | input/output | optional | review/system | versioned |

**Regras contratuais:**
- status_processamento_dado representa workflow/lifecycle.
- status_qualidade_dado representa qualidade/condição de uso.
- Os eixos são independentes.
- MCD-F9009 arquivo_origem_id permanece vigente.

## 7. Constraints relacionais normativas

| Regra | Escopo | Constraint |
|---|---|---|
| CDC-REL-XOR-001 | Receita | pessoa_fisica_id XOR pessoa_juridica_id. |
| CDC-REL-XOR-002 | VinculoExtremidade | Exatamente uma FK entre UE/PF/PJ. |
| CDC-REL-CARD-001 | Vinculo | Exatamente duas extremidades: ORIGEM e DESTINO. |
| CDC-REL-UNQ-001 | ReceitaDocumentoFiscal | Unique(receita_id, documento_fiscal_id). |
| CDC-REL-UNQ-002 | DocumentoFiscalArquivoOrigem | Evitar associação duplicada; detalhe de unicidade depende do ADR/papel_arquivo. |
| CDC-REL-ID-001 | EqHop | Classificação possui id próprio e histórico não destrutivo. |

## 8. Estados de processamento e qualidade

`status_processamento_dado` descreve workflow/lifecycle. `status_qualidade_dado` descreve qualidade/condição de uso. São independentes e não podem ser colapsados. O DST-001 V1.2 deverá formalizar os códigos correspondentes.

## 9. Proveniência, idempotência e reprocessamento

- Preservar RAW quando disponível.
- sistema_origem é origem de negócio/processo, não hosting.
- Preservar identificador_origem, arquivo_origem_id e correlation_id.
- Reprocessamento não apaga RAW nem histórico.
- Idempotência deve ser determinística conforme adapter/ADR.

## 10. IA e ingestão documental

- Saída de LLM/OCR/parser é candidata, não fato autoritativo.
- Preservar confiança, localização/texto bruto e versão do extrator quando aplicável.
- Candidato passa por validação/reconciliação.
- IA não inventa regra tributária.

## 11. Lacunas residuais após V1.2

| Gap | Tema | Tratamento |
|---|---|---|
| GAP-CDC-1.2-001 | papel_arquivo | Catálogo DST pendente; não criar enum fechado. |
| GAP-CDC-1.2-002 | tipo_objeto / papel_no_conflito | Catálogos dependem de OBS/reconciliação. |
| GAP-CDC-1.2-003 | Revisor de RevisaoTecnica | Aguardar SEC-001/OBS-001. |
| GAP-CDC-1.2-004 | FontePagadora.identificador_fiscal | Tipagem CPF/CNPJ/Exterior ainda aberta. |
| GAP-CDC-1.2-005 | Demais gaps DST | Continuam bloqueados até publicação de catálogo. |

Os antigos GAP-CDC-001, GAP-CDC-002 e GAP-CDC-003 ficam resolvidos por MCD/CDC V1.2. O antigo GAP-CDC-004 permanece materialmente aberto e é absorvido por GAP-CDC-1.2-003.

## 12. O que está liberado após CDC V1.2

- Fase 1 permanece válida sem alterações em UE/PF/PJ.
- Gerar DST-001 V1.2.
- Preparar alinhamento do COT.
- Depois de DST/COT, elaborar ADR físico.
- Nenhuma migration antes do ADR aprovado.
- Autenticação aguarda SEC-001; regras tributárias aguardam RGT.

## 13. Política para Claude Code

```yaml
cdc_policy:
  version: 1.2
  mcd_required: 1.2
  supersedes: CDC-001-v1.1
  canonical_naming: snake_case
  competence: YYYY-MM
  fake_first_day_date: prohibited
  relation_rules:
    receita_owner: xor_pf_pj
    vinculo_endpoints: exactly_two_vinculo_extremidade
    receita_documento_fiscal: explicit_many_to_many
    documento_arquivo_origem: explicit_many_to_many
  data_state:
    processing: status_processamento_dado
    quality: status_qualidade_dado
    collapse_axes: prohibited
  preserve_raw: true
  preserve_provenance: true
  infer_missing_field: false
  invent_closed_enum: false
  expose_vendor_schema: false
  create_prisma_schema_now: false
  create_migration_now: false
  auth_implementation: blocked_until_SEC_001
  tax_rule_implementation: blocked_until_RGT
```

## 14. Critérios de aceite

- [x] Todos os campos existem no MCD V1.2.
- [x] Receita usa PF/PJ com XOR.
- [x] VinculoExtremidade formalizado.
- [x] N:N documentais com contratos próprios.
- [x] EqHop com identidade própria.
- [x] Conflito com itens participantes.
- [x] MCD-F9009 preservado.
- [x] Processamento e qualidade separados.
- [x] Nenhum enum pendente inventado.

**Bloqueios restantes para schema/migration:**

- [ ] DST-001 V1.2 aprovado.
- [ ] Alinhamento COT.
- [ ] ADR físico Prisma/PostgreSQL aprovado.

## 15. Próximo documento

**DST-001 V1.2 — Dicionário Semântico Tributário**, sincronizando estados e enums mínimos necessários às estruturas aprovadas.

---
**Governança:** CDC-001 V1.2 passa a ser o contrato vigente após aprovação. CDC V1.1/V1.0 ficam como histórico SUPERSEDED. Este documento não autoriza migration.