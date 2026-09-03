# CDC-001 — Contrato Canônico de Dados da CONTIFISC

**Versão:** 1.4  
**Status:** APROVADO — correção normativa coordenada com MCD-001 V1.4, restrita aos 2 achados
`RELEVANTE` de `SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`  
**Supersede:** CDC-001 V1.3  
**Dependências:** CAF-001, COT-001 V1.2, MCD-001 V1.4, DST-001 V1.3, `SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`, `SEC-CHANGE-REQUEST-001_V1.1.md`  
**Incorpora:** MCD-CHANGE-REQUEST-002, `SEC-CHANGE-REQUEST-001` V1.1, correção de
`SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`  
**Consumidores:** APIs, eventos, integrações, types, repositórios, ATI, GTI, MIT e Skills

> O CDC define fronteiras técnicas de entrada, saída, validação, mutabilidade, compatibilidade, proveniência e reprodutibilidade. Não cria objeto, campo ou regra tributária fora do COT/MCD/RGT.

## 1. Alterações da V1.4

Correção normativa coordenada com `MCD-001` V1.4, restrita aos 2 achados `RELEVANTE` da
reconciliação cruzada:

- **1 novo contrato:** `CDC-SEC-005` (`ContaAcesso`) — identidade mínima, sem nenhum atributo de
  mecanismo de autenticação.
- `CDC-SEC-003` (`ContaAcesso × Tenant`) ganha `id`, `conta_acesso_id`, `tenant_id` — estrutura
  antes incompleta (`GAP-CDC-1.3-003`), agora completa.
- `CDC-SEC-004` (`ContaAcesso × UnidadeEconomica`) ganha `id`, `conta_acesso_id`,
  `unidade_economica_id` — mesma correção.
- `CDC-CAL-001` (`ResultadoCalculo`) tem a mutabilidade de `unidade_economica_id` corrigida de
  `versioned` para `immutable`, alinhando-se à política diferenciada por hospedeiro definida em
  `MCD-001` V1.4 §8.1. Os demais 5 hospedeiros de `unidade_economica_id`
  (`CDC-REC-001`/`PRE-001`/`PREV-001`/`IRP-001`/`FIS-001`) **não mudam** — já eram `versioned`,
  agora confirmado coerente com o MCD.
- **3 novas constraints relacionais:** `CDC-REL-SEC-005`, `CDC-REL-SEC-006`, `CDC-REL-SEC-007`
  (unicidade lógica das duas associações de acesso e dependência estrutural entre elas).
- `GAP-CDC-1.3-003` marcado como **parcialmente resolvido** (estrutura de identidade/FK); o
  residual de vigência/status é desmembrado em `GAP-CDC-1.4-001`. `GAP-CDC-1.3-004` marcado como
  parcialmente resolvido (`ContaAcesso.id` agora existe); o restante permanece aberto. Novo
  `GAP-CDC-1.4-002` registra `ContaAcesso.tipo` (HUMANA/SERVICO) como explicitamente diferido.
- Todos os demais 24 contratos, os 18 erros e as 6 constraints antigas da V1.3 permanecem
  **idênticos**, sem nenhuma alteração.
- Nenhum schema Prisma, migration, RLS ou FK composta física é implementado por esta versão.

## 2. Princípios obrigatórios

Inalterados desde a V1.3.

## 3. Envelope canônico V1.4

Inalterado desde a V1.3 (ver seção correspondente da versão anterior — `unidade_economica_id`,
`tenant_id` e `sujeito_id` como contexto de transporte).

## 4. Tipos e validações gerais

Inalterado desde a V1.3.

## 5. Erros contratuais

Os erros `CDC-ERR-001` a `CDC-ERR-018` são idênticos à V1.3 — nenhum erro novo foi necessário para
esta correção. As violações de unicidade lógica das duas associações de acesso
(`CDC-REL-SEC-005/006`) são cobertas pelo código já existente `CDC-ERR-014`
(`RELATION_CARDINALITY`); a violação de "restrição sem concessão prévia" (`CDC-REL-SEC-007`) é
coberta pelo já existente `CDC-ERR-018` (`SCOPE_VIOLATION`).

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
| CDC-ERR-017 | TENANT_MISMATCH | `tenant_id` do registro não corresponde ao `tenant_id` da `UnidadeEconomica`/objeto relacionado. |
| CDC-ERR-018 | SCOPE_VIOLATION | Acesso solicitado fora do escopo de Tenant/UnidadeEconomica concedido à ContaAcesso. |

## 6. Contratos canônicos V1.4 (26 contratos)

**24 contratos abaixo são idênticos à V1.3** (reproduzidos integralmente); **3 são atualizados**
(`CDC-SEC-003`, `CDC-SEC-004`, `CDC-CAL-001`, marcados *corrigido nesta versão*); **1 é novo**
(`CDC-SEC-005`, marcado *novo nesta versão*).

### CDC-UE-001 — Unidade Econômica

Idêntico à V1.3 — nenhuma alteração.

**Domínio:** `DOM-CORE`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-001`  
**Objetivo:** Contexto econômico/tributário agregador; não substitui CPF ou CNPJ.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F0001 | output | required | system/import | immutable |
| nome | MCD-F0002 | input/output | required | manual/system | versioned |
| status_registro | MCD-F0003 | input/output | required | manual/system | versioned |
| criado_em | MCD-F0004 | output | required | system/import | immutable |
| atualizado_em | MCD-F0005 | output | required | system/import | versioned |
| tenant_id | MCD-F10002 | input/output | required | manual/system | immutable |

**Regras contratuais:**
- UE é contexto interno, não contribuinte.
- PF/PJ associam-se à UE apenas via Vinculo.
- Inativação é preferida à exclusão destrutiva quando houver dependências.
- `tenant_id` é a âncora raiz de todo o modelo de isolamento — definido na criação da UE e nunca
  alterado (`immutable`).

### CDC-PER-001 — Pessoa Física

Idêntico à V1.3 — nenhuma alteração.

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
- Identidade global compartilhável entre tenants — nenhum `tenant_id`/`unidade_economica_id` é
  adicionado a este contrato.

### CDC-EMP-001 — Pessoa Jurídica

Idêntico à V1.3 — nenhuma alteração.

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
- Identidade global compartilhável entre tenants — nenhum `tenant_id`/`unidade_economica_id`
  adicionado.

### CDC-REL-001 — Vínculo

Idêntico à V1.3 — nenhuma alteração.

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
- Tenant não é contratualizado diretamente em `Vinculo`.

### CDC-REL-002 — Vínculo - Extremidade

Idêntico à V1.3 — nenhuma alteração.

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

Idêntico à V1.3 — nenhuma alteração (mutabilidade de `unidade_economica_id` já era `versioned`,
confirmada coerente com `MCD-001` V1.4 §8.1).

**Domínio:** `DOM-REC`  
**Versão:** `1.3.0`  
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
| unidade_economica_id | MCD-F10004 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- pessoa_fisica_id XOR pessoa_juridica_id.
- tipo_titular não é fonte de verdade.
- Receita é fato; resultado derivado não sobrescreve valor_receita_bruta.
- `unidade_economica_id` é o contexto de apuração (`DST-T034`), distinto e adicional à
  titularidade tributária XOR acima. **Mutabilidade `versioned`: correção controlada, preferencialmente via
  `ConflitoDado`/`RevisaoTecnica` — ver `MCD-001` V1.4 §8.1.**

### CDC-FIS-001 — Documento Fiscal

Idêntico à V1.3 — nenhuma alteração (mutabilidade já era `versioned`, confirmada coerente).

**Domínio:** `DOM-FIS`  
**Versão:** `1.3.0`  
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
| unidade_economica_id | MCD-F10004 | input/output | required | system/import | versioned |

**Regras contratuais:**
- DocumentoFiscal não possui arquivo único direto.
- Arquivos RAW associam-se por CDC-FIS-003.
- Receitas associam-se por CDC-FIS-002.
- `unidade_economica_id` é atribuído de forma própria a este contrato — o documento fiscal
  frequentemente chega antes de qualquer `Receita` ser lançada. **Mutabilidade `versioned`:
  quando a reconciliação posterior com uma `Receita` associada revelar UE diferente da inicialmente
  atribuída, a correção ocorre por `UPDATE` controlado — ver `MCD-001` V1.4 §8.1.**

### CDC-FIS-002 — Receita x Documento Fiscal

Idêntico à V1.3 — nenhuma alteração.

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
- Tenant/UE derivam de Receita/DocumentoFiscal.

### CDC-FIS-003 — Documento Fiscal x Arquivo de Origem

Idêntico à V1.3 — nenhuma alteração.

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

Idêntico à V1.3 — nenhuma alteração.

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
- Tenant/UE derivam de Receita.

### CDC-PRE-001 — Contribuição Previdenciária

Idêntico à V1.3 — nenhuma alteração (mutabilidade já era `versioned`, confirmada coerente).

**Domínio:** `DOM-PRE`  
**Versão:** `1.3.0`  
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
| unidade_economica_id | MCD-F10004 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- `unidade_economica_id` é o contexto de apuração (`DST-T034`), distinto do titular
  (`pessoa_fisica_id`). Mutabilidade `versioned` — ver `MCD-001` V1.4 §8.1.

### CDC-PREV-001 — Vínculo Previdenciário

Idêntico à V1.3 — nenhuma alteração (mutabilidade já era `versioned`, confirmada coerente).

**Domínio:** `DOM-PRE`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-010`  
**Objetivo:** Origem/fonte previdenciária de uma Pessoa Física ao longo da vigência.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F6101 | output | required | system/import | immutable |
| pessoa_fisica_id | MCD-F6102 | input/output | required | manual/system | temporal |
| tipo_vinculo_previdenciario | MCD-F6103 | input/output | required | manual/system | temporal |
| vigencia_inicio | MCD-F6104 | input/output | optional | manual/system | temporal |
| vigencia_fim | MCD-F6105 | input/output | optional | manual/system | temporal |
| unidade_economica_id | MCD-F10004 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- `unidade_economica_id` é o contexto de apuração, distinto do titular. Mutabilidade `versioned`
  — ver `MCD-001` V1.4 §8.1.

### CDC-IRP-001 — Evento IRPF / Carnê-Leão

Idêntico à V1.3 — nenhuma alteração (mutabilidade já era `versioned`, confirmada coerente).

**Domínio:** `DOM-IRP`  
**Versão:** `1.3.0`  
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
| unidade_economica_id | MCD-F10004 | input/output | required | system/import | versioned |

**Regras contratuais:**
- `unidade_economica_id` é o contexto de apuração, distinto do titular e da fonte pagadora.
  Mutabilidade `versioned` — ver `MCD-001` V1.4 §8.1.

### CDC-FPG-001 — Fonte Pagadora

Idêntico à V1.3 — nenhuma alteração.

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

**Regras contratuais:**
- Identidade global compartilhável entre tenants — nenhum `tenant_id`/`unidade_economica_id`
  adicionado.

### CDC-PLN-001 — Cenário Tributário

Idêntico à V1.3 — nenhuma alteração.

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

**Regras contratuais:**
- `unidade_economica_id` (`MCD-F8005`) é campo próprio deste objeto desde a V1.0/V1.1 — não é uma
  instância de `MCD-F10004`.

### CDC-CAL-001 — Resultado de Cálculo *(corrigido nesta versão)*

**Domínio:** `DOM-SYS`  
**Versão:** `1.4.0`  
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
| unidade_economica_id | MCD-F10004 | input/output | required | system/import | **immutable** *(corrigido — era `versioned` na V1.3)* |

**Regras contratuais:**
- Preservar snapshot/hash, engine e versão.
- rule_set_id/rule_set_version são opacos até RGT-001.
- `unidade_economica_id` é sempre presente, inclusive quando `cenario_tributario_id` também está
  preenchido — os dois campos NÃO são mutuamente exclusivos (nenhum XOR). Quando ambos presentes,
  devem ser consistentes entre si.
- **Mutabilidade corrigida para `immutable` nesta versão** (`MCD-001` V1.4 §8.1): `ResultadoCalculo`
  é um snapshot reproduzível — todos os seus demais campos já são `immutable` porque qualquer
  mudança de entrada exige um **novo** `ResultadoCalculo` (novo `id`, novo
  `input_snapshot_hash`), nunca uma edição do registro existente. `unidade_economica_id` segue a
  mesma regra: se o contexto administrativo de um resultado precisar mudar, calcula-se um novo
  resultado — o registro anterior nunca é corrigido in-place. Isso resolve a divergência
  encontrada na reconciliação cruzada entre este contrato (`versioned` na V1.3) e a política
  declarada no MCD (`Imutável` na V1.3) — a correção aqui vai no sentido de alinhar este contrato
  ao MCD, e não o inverso, porque a filosofia de imutabilidade de `ResultadoCalculo` é mais
  específica e mais antiga que a generalização aplicada aos outros 5 hospedeiros.
- **Nota sobre `GAP-SEC-CR1-003`:** esta análise de mutabilidade reforça (sem provar) que
  `ResultadoCalculo` é identificado por um conjunto fechado de inputs, incluindo
  `unidade_economica_id` — consistente com, mas não conclusivo sobre, a obrigatoriedade atual do
  campo. O gap permanece aberto e a obrigatoriedade **não foi alterada** por esta versão.

### CDC-ARQ-001 — Arquivo de Origem

Idêntico à V1.3 — nenhuma alteração.

**Domínio:** `DOM-SYS`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-007`  
**Objetivo:** Evidência RAW/imutável e referência segura ao conteúdo armazenado.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8401 | output | required | system/import | immutable |
| nome_arquivo | MCD-F8402 | input/output | optional | system/import | immutable |
| hash_conteudo | MCD-F8403 | input/output | required | system/import | immutable |
| tipo_mime | MCD-F8404 | input/output | optional | system/import | immutable |
| armazenamento_referencia | MCD-F8405 | input/output | required | system/import | versioned |
| tenant_id | MCD-F10003 | input/output | required | system/import | immutable |

**Regras contratuais:**
- `tenant_id` é obrigatório desde a ingestão — nunca inferido do conteúdo do arquivo.
- Não inclui `unidade_economica_id` — resolução por UE ocorre em `DocumentoFiscal`.
- Deduplicação física de bytes é permitida sem produzir compartilhamento de autorização.

### CDC-CFD-001 — Conflito de Dados

Idêntico à V1.3 — nenhuma alteração.

**Domínio:** `DOM-SYS`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-015`  
**Objetivo:** Objeto auditável que representa divergência entre dados/fontes.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F8601 | output | required | system/import | immutable |
| status_conflito | MCD-F8602 | input/output | required | reconciliation | versioned |
| tipo_conflito | MCD-F8603 | input/output | required | reconciliation | versioned |
| descricao | MCD-F8604 | input/output | optional | reconciliation | versioned |
| tenant_id | MCD-F10003 | input/output | required | reconciliation | immutable |

**Regras contratuais:**
- Conflito não é resolvido silenciosamente.
- Participantes são registrados por CDC-CFD-002.
- `tenant_id` é carimbado pelo serviço de reconciliação — nunca derivado da referência
  polimórfica.

### CDC-CFD-002 — Item de Conflito

Idêntico à V1.3 — nenhuma alteração.

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
- `ConflitoDadoItem` NÃO recebe `tenant_id` próprio — deriva sempre de `conflito_dado_id` →
  `ConflitoDado.tenant_id`.

### CDC-REV-001 — Revisão Técnica

Idêntico à V1.3 — nenhuma alteração.

**Domínio:** `DOM-SYS`  
**Versão:** `1.3.0`  
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
| tenant_id | MCD-F10003 | input/output | required | system/import | immutable |

**Regras contratuais:**
- Identidade do revisor aguarda `OBS-001`.
- `tenant_id` é carimbado pelo processo/contexto autenticado de quem realiza a revisão — nunca
  inferido do objeto revisado.

### CDC-SYS-001 — Metadados Transversais

Idêntico à V1.3 — nenhuma alteração.

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
- status_processamento_dado representa workflow/lifecycle; status_qualidade_dado representa
  qualidade/condição de uso. Eixos independentes.

### CDC-SEC-001 — Tenant

Idêntico à V1.3 — nenhuma alteração.

**Domínio:** `DOM-SEC`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-019`  
**Objetivo:** Fronteira técnica de isolamento, segurança e propriedade lógica dos dados.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F10001 | output | required | system | immutable |

**Regras contratuais:**
- `Tenant` não é um objeto de domínio tributário.
- `tenant_id ≠ unidade_economica_id`.
- Detalhamento completo permanece bloqueado (`GAP-CDC-1.3-001`).

### CDC-SEC-002 — Evento de Auditoria de Segurança

Idêntico à V1.3 — nenhuma alteração.

**Domínio:** `DOM-SEC`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-020`  
**Objetivo:** Registro imutável de evento de segurança.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F10006 | output | required | system | immutable |

**Regras contratuais:**
- Escopo estreito, restrito a eventos de segurança.
- Não antecipa `EVT-001`.
- Diferenciação de ator/tenant/UE/operação/objeto/instante/resultado permanece `GAP-CDC-1.3-002`.

### CDC-SEC-003 — Conta de Acesso × Tenant *(corrigido nesta versão)*

**Domínio:** `DOM-SEC`  
**Versão:** `1.4.0`  
**COT:** `COT-SUP-005` (`ContaAcessoTenant`)  
**Objetivo:** Concessão explícita de acesso de uma `ContaAcesso` a um `Tenant` inteiro; nenhuma
concessão é implícita (`DST-T036`).

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| **id** *(novo)* | MCD-F10009 | output | required | system | immutable |
| **conta_acesso_id** *(novo)* | MCD-F10008 | input/output | required | manual/system | immutable |
| **tenant_id** *(novo)* | MCD-F10010 | input/output | required | manual/system | immutable |
| papel | MCD-F10005 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- `papel` é Enum/Ref aberto — **nenhum enum é criado por este contrato**. Vocabulário fechado
  ainda não aprovado; ver `DST-GAP-015`.
- **Não criar `PapelAcesso` ou `Permissao` como objetos separados** — `papel` é um atributo
  direto desta associação.
- **Estrutura agora completa** (`GAP-CDC-1.3-003` parcialmente resolvido — ver `CDC-001` V1.4 §11):
  `id`, `conta_acesso_id` e `tenant_id` foram incorporados em `MCD-001` V1.4. `conta_acesso_id`
  aponta para `ContaAcesso.id` (`MCD-F10007`, `CDC-SEC-005`); `tenant_id` aponta para `Tenant.id`
  (`MCD-F10001`, `CDC-SEC-001`) — papel semântico de **concessão**, distinto de `MCD-F10002`
  (âncora raiz) e `MCD-F10003` (metadado operacional transversal).
- `id`, `conta_acesso_id` e `tenant_id` são `immutable`: uma concessão não é "movida" para outro
  `ContaAcesso`/`Tenant` — para mudar o alvo de uma concessão, revoga-se a linha e cria-se uma
  nova (mesma filosofia de `ReceitaDocumentoFiscal`/`DocumentoFiscalArquivoOrigem`, cujas FKs
  também são `immutable`).
- **Unicidade lógica:** no máximo uma linha por par `(conta_acesso_id, tenant_id)` —
  `CDC-REL-SEC-005`. Forma física (`UNIQUE`) a cargo do ADR.
- Vigência/status da concessão **continuam não contratualizados** — mencionados na descrição
  textual de `COT-SUP-005` (`COT-001` V1.2 §4), mas nunca aprovados por nenhum Change Request.
  Registrado como `GAP-CDC-1.4-001` (residual, desmembrado de `GAP-CDC-1.3-003`).
- Timestamps da concessão continuam cobertos pelo mecanismo de metadados transversais
  (`MCD-001` §9), sem campo local dedicado.

### CDC-SEC-004 — Conta de Acesso × Unidade Econômica *(corrigido nesta versão)*

**Domínio:** `DOM-SEC`  
**Versão:** `1.4.0`  
**COT:** `COT-SUP-006` (`ContaAcessoUnidadeEconomica`)  
**Objetivo:** Restrição opcional de acesso de uma `ContaAcesso` a UEs específicas dentro de um
`Tenant` já concedido (`DST-T037`).

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| **id** *(novo)* | MCD-F10011 | output | required | system | immutable |
| **conta_acesso_id** *(novo)* | MCD-F10008 | input/output | required | manual/system | immutable |
| **unidade_economica_id** *(novo)* | MCD-F10012 | input/output | required | manual/system | immutable |
| papel | MCD-F10005 | input/output | required | manual/system | versioned |

**Regras contratuais — formalização obrigatória da semântica de restrição:**
- A autorização por `UnidadeEconomica` **somente restringe** o escopo concedido pela associação
  `ContaAcesso ↔ Tenant` (`CDC-SEC-003`). Ela **nunca**: concede `Tenant`; amplia o escopo já
  concedido; substitui a associação `ContaAcesso ↔ Tenant`; concede acesso implícito a outras UEs
  do mesmo tenant.
- **Invariante formal:** quando existir ao menos uma linha desta associação para um dado par
  (`ContaAcesso`, `Tenant`), a avaliação de autorização deve considerar exclusivamente as UEs
  explicitamente listadas para aquele par (`CDC-REL-SEC-001`).
- **Estrutura agora completa** (`GAP-CDC-1.3-003` parcialmente resolvido): `id`, `conta_acesso_id`
  (`MCD-F10008`, mesmo campo transversal usado por `CDC-SEC-003` — mesma pergunta: "a qual
  `ContaAcesso` esta linha se refere") e `unidade_economica_id` (`MCD-F10012`, papel de
  **restrição**, distinto de `MCD-F10004`, papel de contexto de apuração de um fato) foram
  incorporados em `MCD-001` V1.4.
- Todos os três campos de identidade/FK são `immutable` — mesma filosofia de `CDC-SEC-003`: alterar
  o alvo exige revogar e criar uma nova restrição.
- **Unicidade lógica:** no máximo uma linha por par `(conta_acesso_id, unidade_economica_id)` —
  `CDC-REL-SEC-006`.
- **Dependência estrutural:** toda linha desta associação pressupõe uma linha de `CDC-SEC-003`
  (`ContaAcessoTenant`) para o mesmo par (`ContaAcesso`, Tenant-da-UE) — `CDC-REL-SEC-007`. Uma
  restrição de UE isolada, sem concessão de Tenant correspondente, é dado inválido e **nunca
  concede acesso por si só**.
- `papel` segue a mesma regra de `CDC-SEC-003` — aberto, `DST-GAP-015`, nenhum enum criado.
- Vigência/status e timestamps seguem o mesmo tratamento de `CDC-SEC-003` (`GAP-CDC-1.4-001`).

### CDC-SEC-005 — Conta de Acesso *(novo nesta versão)*

**Domínio:** `DOM-SEC`  
**Versão:** `1.4.0`  
**COT:** `COT-OBJ-017`  
**Objetivo:** Identidade de autenticação/autorização, separada da identidade tributária
(`PessoaFisica`/`PessoaJuridica`) — `SEC-001` V1.0 §1, `DST-T021`.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F10007 | output | required | system | immutable |

**Regras contratuais:**
- Este contrato é **intencionalmente mínimo** — contém apenas a identidade persistente necessária
  para `ContaAcesso` participar como FK em `CDC-SEC-003`/`CDC-SEC-004` (`conta_acesso_id`,
  `MCD-F10008`).
- **Nenhum atributo de mecanismo de autenticação é antecipado**: sem senha, hash de senha, OAuth,
  refresh token, MFA físico, sessão, ou qualquer campo específico de provedor de autenticação.
  Todos permanecem diferidos até Change Request específico de autenticação/RBAC.
- **`ContaAcesso.tipo` (`HUMANA`/`SERVICO`), mencionado conceitualmente em `SEC-001` V1.0 §13, não
  é incorporado por este contrato** — não foi aprovado por nenhum Change Request formal; registrado
  como `GAP-CDC-1.4-002`, explicitamente diferido, não inventado por inferência.
- `ContaAcesso` não é `PessoaFisica` — associação opcional já vigente (`COT-REL-119`), inalterada.
- `CredencialAcesso` (`COT-OBJ-018`) **não recebe contrato nesta versão** — verificado que a
  incorporação mínima de `ContaAcesso.id` não cria nenhuma necessidade estrutural nova para
  `CredencialAcesso`; permanece integralmente diferido (nenhum campo MCD, nenhum contrato CDC).

## 7. Constraints relacionais normativas

As seis primeiras constraints e as quatro constraints `CDC-REL-SEC-001..004` são idênticas à V1.3.
Três novas constraints são adicionadas por esta correção.

| Regra | Escopo | Constraint |
|---|---|---|
| CDC-REL-XOR-001 | Receita | pessoa_fisica_id XOR pessoa_juridica_id. |
| CDC-REL-XOR-002 | VinculoExtremidade | Exatamente uma FK entre UE/PF/PJ. |
| CDC-REL-CARD-001 | Vinculo | Exatamente duas extremidades: ORIGEM e DESTINO. |
| CDC-REL-UNQ-001 | ReceitaDocumentoFiscal | Unique(receita_id, documento_fiscal_id). |
| CDC-REL-UNQ-002 | DocumentoFiscalArquivoOrigem | Evitar associação duplicada. |
| CDC-REL-ID-001 | EqHop | Classificação possui id próprio e histórico não destrutivo. |
| CDC-REL-SEC-001 | ContaAcessoUnidadeEconomica | Restrição considera exclusivamente as UEs explicitamente listadas — nunca ampliar/substituir a concessão de Tenant. |
| CDC-REL-SEC-002 | ConflitoDado / ConflitoDadoItem | Todo item pertence ao mesmo tenant do conflito pai. |
| CDC-REL-SEC-003 | ResultadoCalculo | `unidade_economica_id` consistente com `CenarioTributario.unidade_economica_id`; nenhum XOR. |
| CDC-REL-SEC-004 | UnidadeEconomica × objetos com `unidade_economica_id`/`tenant_id` | Estrutura para futura FK composta — forma física a cargo do ADR. |
| **CDC-REL-SEC-005** *(novo)* | ContaAcessoTenant | Unicidade lógica de `(conta_acesso_id, tenant_id)` — no máximo uma concessão por par. **Não implementada como SQL nesta versão** — registrada para o ADR. |
| **CDC-REL-SEC-006** *(novo)* | ContaAcessoUnidadeEconomica | Unicidade lógica de `(conta_acesso_id, unidade_economica_id)` — no máximo uma restrição por par. **Não implementada como SQL nesta versão** — registrada para o ADR. |
| **CDC-REL-SEC-007** *(novo)* | ContaAcessoUnidadeEconomica × ContaAcessoTenant | Toda linha de `ContaAcessoUnidadeEconomica` pressupõe uma linha de `ContaAcessoTenant` para o mesmo par (`ContaAcesso`, Tenant-da-UE referenciada). Uma restrição sem concessão de Tenant correspondente é dado inválido e nunca concede acesso por si só. **Não implementada como SQL/trigger nesta versão** — registrada para o ADR. |

## 8. Estados de processamento e qualidade

Inalterado desde a V1.3.

## 9. Proveniência, idempotência e reprocessamento

Inalterado desde a V1.3.

## 10. IA e ingestão documental

Inalterado desde a V1.3.

## 11. Lacunas residuais após V1.4

Os gaps `GAP-CDC-1.2-001`, `GAP-CDC-1.2-002`, `GAP-CDC-1.2-004`, `GAP-CDC-1.2-005` e
`GAP-CDC-1.3-001`/`002` são idênticos à V1.3. `GAP-CDC-1.2-003` permanece com a nota de status já
registrada. `GAP-CDC-1.3-003` e `GAP-CDC-1.3-004` são atualizados; dois novos gaps são
adicionados.

| Gap | Tema | Tratamento |
|---|---|---|
| GAP-CDC-1.2-001 | papel_arquivo | Catálogo DST pendente; não criar enum fechado. |
| GAP-CDC-1.2-002 | tipo_objeto / papel_no_conflito | Catálogos dependem de OBS/reconciliação. |
| GAP-CDC-1.2-003 | Revisor de RevisaoTecnica | `SEC-001` aprovado não resolve; depende de `OBS-001`. |
| GAP-CDC-1.2-004 | FontePagadora.identificador_fiscal | Tipagem CPF/CNPJ/Exterior ainda aberta. |
| GAP-CDC-1.2-005 | Demais gaps DST | Continuam bloqueados até publicação de catálogo. |
| GAP-CDC-1.3-001 | Tenant — detalhamento completo | Aguarda Change Request de autenticação/RBAC. |
| GAP-CDC-1.3-002 | EventoAuditoriaSeguranca — detalhamento completo | Aguarda Change Request de autenticação/RBAC; identidade do ator depende de `OBS-001`. |
| **GAP-CDC-1.3-003** *(atualizado)* | ContaAcessoTenant/ContaAcessoUnidadeEconomica — identidade e FKs estruturais | **PARCIALMENTE RESOLVIDO nesta versão**: `id`, `conta_acesso_id`, `tenant_id`/`unidade_economica_id` incorporados (`MCD-001` V1.4, `CDC-SEC-003`/`004`). Residual (vigência/status) desmembrado em `GAP-CDC-1.4-001`. |
| **GAP-CDC-1.3-004** *(atualizado)* | ContaAcesso/CredencialAcesso — detalhamento físico completo | **PARCIALMENTE RESOLVIDO**: `ContaAcesso.id` (`MCD-F10007`, `CDC-SEC-005`) incorporado. `ContaAcesso.tipo` (ver `GAP-CDC-1.4-002`) e todo o modelo de `CredencialAcesso` continuam integralmente diferidos. |
| **GAP-CDC-1.4-001** *(novo)* | Vigência/status de `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` | Mencionado na descrição textual de `COT-SUP-005` (`COT-001` V1.2 §4), nunca aprovado por Change Request. Requer novo Change Request (decisão de produto: concessões devem poder expirar?) ou correção editorial do COT removendo a menção. Não incorporado por inferência. |
| **GAP-CDC-1.4-002** *(novo)* | `ContaAcesso.tipo` (HUMANA/SERVICO) | Mencionado conceitualmente em `SEC-001` V1.0 §13, nunca aprovado por nenhum Change Request formal. Aguarda Change Request específico de autenticação/RBAC. Não incorporado por inferência. |

## 12. O que está liberado após CDC V1.4

- Fase 1 permanece válida sem alterações em UE/PF/PJ.
- Os 2 achados `RELEVANTE` da reconciliação cruzada foram corrigidos nesta versão coordenada
  MCD/CDC.
- Próximo passo: **reconciliação final** confirmando a correção e ausência de nova inconsistência
  bloqueante.
- Depois da reconciliação final, elaborar `ADR-002` (schema físico de segurança/tenant).
- Nenhuma migration antes do ADR aprovado.
- Autenticação completa aguarda Change Request específico; regras tributárias aguardam RGT.

## 13. Política para Claude Code

```yaml
cdc_policy:
  version: 1.4
  mcd_required: 1.4
  cot_required: 1.2
  dst_required: 1.3
  supersedes: CDC-001-v1.3
  canonical_naming: snake_case
  competence: YYYY-MM
  fake_first_day_date: prohibited
  relation_rules:
    receita_owner: xor_pf_pj
    vinculo_endpoints: exactly_two_vinculo_extremidade
    receita_documento_fiscal: explicit_many_to_many
    documento_arquivo_origem: explicit_many_to_many
    resultado_calculo_ue_cenario: consistent_not_xor
    conflito_dado_item_tenant: derived_from_parent_only
    unidade_economica_authorization: restricts_only
    conta_acesso_tenant_unique: [conta_acesso_id, tenant_id]
    conta_acesso_ue_unique: [conta_acesso_id, unidade_economica_id]
    conta_acesso_ue_requires_conta_acesso_tenant: true
  data_state:
    processing: status_processamento_dado
    quality: status_qualidade_dado
    collapse_axes: prohibited
  tenant_rules:
    tenant_id_equals_unidade_economica_id: false
    tenant_id_root_and_transversal_share_mcd_id: false
    polymorphic_reference_determines_tenant: false
    papel_is_closed_enum: false
    papel_acesso_permissao_objects_created: false
    sessao_object_canonical: false
  unidade_economica_id_mutability:
    default: versioned
    resultado_calculo_override: immutable
  conta_acesso:
    minimal_id_only: true
    auth_fields: deferred
    tipo_humana_servico: deferred
  credencial_acesso:
    fields: deferred
  preserve_raw: true
  preserve_provenance: true
  infer_missing_field: false
  invent_closed_enum: false
  expose_vendor_schema: false
  create_prisma_schema_now: false
  create_migration_now: false
  implement_rls_now: false
  implement_composite_fk_now: false
  auth_implementation: blocked_until_change_request
  tax_rule_implementation: blocked_until_RGT
```

## 14. Critérios de aceite

- [x] Todos os critérios da V1.3 permanecem satisfeitos.
- [x] `ContaAcesso` contratualizado (`CDC-SEC-005`) com identidade mínima — nenhum atributo de
  mecanismo de autenticação antecipado.
- [x] `ContaAcesso ↔ Tenant` (`CDC-SEC-003`) e `ContaAcesso ↔ UnidadeEconomica` (`CDC-SEC-004`)
  estruturalmente completos: `id`, `conta_acesso_id`, `tenant_id`/`unidade_economica_id`, `papel`.
- [x] `CredencialAcesso` permanece sem contrato — verificado que não há necessidade estrutural
  nova.
- [x] `MCD-F10004` com mutabilidade coerente entre MCD e CDC em todos os 6 hospedeiros — divergência
  resolvida por análise semântica (`versioned` em 5, `immutable` em `ResultadoCalculo`), não por
  escolha arbitrária.
- [x] `ResultadoCalculo` permanece sem XOR; obrigatoriedade de `unidade_economica_id` não alterada;
  `GAP-SEC-CR1-003` permanece aberto.
- [x] Nenhum enum criado para `papel`; `DST-GAP-015` inalterado.
- [x] Nenhum ID CDC reutilizado; nenhum campo aposentado retornou.
- [x] Invariantes de unicidade lógica e dependência estrutural das duas associações registrados
  (`CDC-REL-SEC-005/006/007`) — não implementados como SQL.
- [x] COT-001, DST-001, SEC-001, SEC-CHANGE-REQUEST-001, ADR, Prisma, migrations e banco não foram
  alterados.

**Bloqueios restantes para schema/migration:**

- [ ] Reconciliação final confirmando a correção dos 2 achados `RELEVANTE`.
- [ ] `ADR-002` físico de segurança/tenant aprovado.

## 15. Próximo documento

**Reconciliação final** — nova verificação cruzada COT-001 V1.2 × MCD-001 V1.4 × CDC-001 V1.4 ×
DST-001 V1.3, confirmando a correção dos 2 achados `RELEVANTE` e a ausência de nova inconsistência
bloqueante. Somente depois, **`ADR-002`** — schema físico de segurança/tenant.

---
**Governança:** CDC-001 V1.4 passa a ser o contrato vigente após aprovação. CDC V1.3/V1.2/V1.1/V1.0
ficam como histórico SUPERSEDED. Este documento não autoriza migration.
