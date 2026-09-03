# CDC-001 — Contrato Canônico de Dados da CONTIFISC

**Versão:** 1.3  
**Status:** APROVADO — sincronizado com COT-001 V1.2, MCD-001 V1.3 e DST-001 V1.3  
**Supersede:** CDC-001 V1.2  
**Dependências:** CAF-001, COT-001 V1.2, MCD-001 V1.3, DST-001 V1.3, `SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`, `SEC-CHANGE-REQUEST-001_V1.1.md`  
**Incorpora:** MCD-CHANGE-REQUEST-002, `SEC-CHANGE-REQUEST-001` V1.1  
**Consumidores:** APIs, eventos, integrações, types, repositórios, ATI, GTI, MIT e Skills

> O CDC define fronteiras técnicas de entrada, saída, validação, mutabilidade, compatibilidade, proveniência e reprodutibilidade. Não cria objeto, campo ou regra tributária fora do COT/MCD/RGT.

## 1. Alterações da V1.3

- Sincronização integral com COT-001 V1.2, MCD-001 V1.3 e DST-001 V1.3 (`SEC-CHANGE-REQUEST-001` V1.1, aprovado).
- 4 novos contratos: `CDC-SEC-001` (Tenant), `CDC-SEC-002` (EventoAuditoriaSeguranca), `CDC-SEC-003` (ContaAcesso × Tenant), `CDC-SEC-004` (ContaAcesso × UnidadeEconomica).
- `CDC-UE-001` ganha `tenant_id` (âncora raiz do isolamento).
- `CDC-REC-001`, `CDC-PRE-001`, `CDC-PREV-001`, `CDC-IRP-001`, `CDC-FIS-001`, `CDC-CAL-001` ganham `unidade_economica_id` (contexto de apuração transversal).
- `CDC-ARQ-001`, `CDC-CFD-001`, `CDC-REV-001` ganham `tenant_id` (metadado transversal de segurança).
- `CDC-CFD-002` reafirmado explicitamente sem `tenant_id` próprio — deriva do `ConflitoDado` pai.
- `CDC-CAL-001` reafirmado explicitamente sem XOR entre `unidade_economica_id` e `cenario_tributario_id`.
- Todos os 21 contratos da V1.2 não listados acima permanecem **idênticos**, sem nenhuma alteração.
- Nenhum schema Prisma, migration, RLS ou FK composta física é implementado por esta versão.

## 2. Princípios obrigatórios

Inalterados desde a V1.2.

- Contract-first.
- Vendor-neutral.
- Fato não é sobrescrito por resultado derivado.
- Proveniência e histórico por padrão.
- No silent conflict resolution.
- Ownership financeiro central usa FKs reais.
- Campo/relação ausente gera Change Request.
- Competência é YYYY-MM, nunca data fictícia.
- **Referência polimórfica de auditoria nunca é fonte de `tenant_id`** (novo nesta versão — `SEC-001` V1.0 §6, §8).

## 3. Envelope canônico V1.3

```yaml
canonical_envelope:
  contract_id: CDC-REC-001
  contract_version: 1.3.0
  record_id: <uuid>
  unidade_economica_id: <uuid|null>
  tenant_id: <uuid|null>
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

`unidade_economica_id` e `sujeito_id` são contexto de transporte, não autorização para FKs
homônimas em todos os objetos. `arquivo_origem_id` no envelope é evidência RAW transversal;
DocumentoFiscal usa também a associação CDC-FIS-003. **`tenant_id` (novo nesta versão)** é
contexto de transporte da fronteira de segurança — não deve ser confundido com
`unidade_economica_id`: quando ambos aparecem no envelope de uma operação sobre um objeto que
possui os dois campos como FK real (§6), o valor transportado deve corresponder exatamente ao
valor persistido, nunca inferido um a partir do outro.

## 4. Tipos e validações gerais

Inalterado desde a V1.2.

- UUID interno; IDs externos ficam na proveniência.
- Money/Decimal exato; float proibido.
- Competencia YYYY-MM.
- Date YYYY-MM-DD; Timestamp ISO-8601 offset-aware.
- CPF/CNPJ só dígitos.
- Enum fechado somente quando publicado no DST; Enum/Ref sem catálogo permanece aberto/branded.
- null, zero, vazio e não aplicável são estados distintos.

## 5. Erros contratuais

Os erros `CDC-ERR-001` a `CDC-ERR-016` são idênticos à V1.2. Dois novos erros são adicionados
para as regras relacionais de segurança/tenant (§7):

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
| **CDC-ERR-017** *(novo)* | TENANT_MISMATCH | `tenant_id` do registro não corresponde ao `tenant_id` da `UnidadeEconomica`/objeto relacionado. |
| **CDC-ERR-018** *(novo)* | SCOPE_VIOLATION | Acesso solicitado fora do escopo de Tenant/UnidadeEconomica concedido à ContaAcesso. |

## 6. Contratos canônicos V1.3 (25 contratos)

**21 contratos abaixo são idênticos à V1.2** (reproduzidos integralmente para preservar a
integridade do documento em um único arquivo); **6 são atualizados** com novos campos (marcados
*atualizado nesta versão*); **4 são novos** (marcados *novo nesta versão*).

### CDC-UE-001 — Unidade Econômica *(atualizado nesta versão)*

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
| **tenant_id** *(novo)* | MCD-F10002 | input/output | required | manual/system | **immutable** |

**Regras contratuais:**
- UE é contexto interno, não contribuinte.
- PF/PJ associam-se à UE apenas via Vinculo.
- Inativação é preferida à exclusão destrutiva quando houver dependências.
- **`tenant_id` é a âncora raiz de todo o modelo de isolamento — definido na criação da UE e
  nunca alterado (`immutable`, mais restritivo que `unidade_economica_id` transversal nos fatos,
  que permanece `versioned`), distinto de `unidade_economica_id`/`DST-T034` conceitualmente
  (aqui, `UnidadeEconomica` é o próprio objeto ancorado, não um contexto de apuração de terceiro
  objeto) (`SEC-001` V1.0 §1, §11; `DST-T033`).**

### CDC-PER-001 — Pessoa Física

Idêntico à V1.2 — nenhuma alteração.

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
- **Identidade global compartilhável entre tenants — nenhum `tenant_id`/`unidade_economica_id`
  é adicionado a este contrato (`SEC-001` V1.0 §3, confirmado nesta versão, ver §12).**

### CDC-EMP-001 — Pessoa Jurídica

Idêntico à V1.2 — nenhuma alteração.

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
- **Identidade global compartilhável entre tenants — nenhum `tenant_id`/`unidade_economica_id`
  adicionado (`SEC-001` V1.0 §3).**

### CDC-REL-001 — Vínculo

Idêntico à V1.2 — nenhuma alteração.

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
- **Tenant não é contratualizado diretamente em `Vinculo` — deriva por relação quando ao menos
  uma extremidade for `UnidadeEconomica` (exceção residual documentada em `SEC-001`/`COT-001`
  §5/§7, condicionada ao fechamento futuro de `DST-GAP-003`).**

### CDC-REL-002 — Vínculo - Extremidade

Idêntico à V1.2 — nenhuma alteração.

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

### CDC-REC-001 — Receita Canônica *(atualizado nesta versão)*

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
| **unidade_economica_id** *(novo)* | MCD-F10004 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- pessoa_fisica_id XOR pessoa_juridica_id.
- tipo_titular não é fonte de verdade na V1.2/V1.3.
- Receita é fato; resultado derivado não sobrescreve valor_receita_bruta.
- **`unidade_economica_id` é o contexto de apuração (`DST-T034`), distinto e adicional à
  titularidade tributária XOR acima — nunca um substituto dela. Disponível no momento da criação
  do fato canônico (`SEC-001` V1.0 §4, §6; `DST-001` §11.1).**

### CDC-FIS-001 — Documento Fiscal *(atualizado nesta versão)*

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
| **unidade_economica_id** *(novo)* | MCD-F10004 | input/output | required | system/import | versioned |

**Regras contratuais:**
- DocumentoFiscal não possui arquivo único direto.
- Arquivos RAW associam-se por CDC-FIS-003.
- Receitas associam-se por CDC-FIS-002.
- **`unidade_economica_id` é atribuído de forma própria a este contrato — não apenas derivado de
  uma `Receita` associada — porque o documento fiscal frequentemente chega ao pipeline antes de
  qualquer `Receita` ser lançada (evidência RAW pode preceder a resolução completa de identidade/
  contexto). Esta é uma diferença de momento de disponibilidade (workflow), não de significado —
  o campo representa exatamente o mesmo conceito canônico em todos os seis hospedeiros de
  `MCD-F10004` (`DST-001` V1.3 §11.1, verificação de uniformidade sem divergência encontrada).
  Quando uma `Receita` associada via `ReceitaDocumentoFiscal` também existir, os dois valores de
  `unidade_economica_id` devem ser consistentes (mesma UE) — validação de aplicação/ADR, não
  implementada por este CDC.**

### CDC-FIS-002 — Receita x Documento Fiscal

Idêntico à V1.2 — nenhuma alteração.

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
- **Tenant/UE derivam de `Receita`/`DocumentoFiscal` (ambos agora com `unidade_economica_id`
  próprio) — nenhum campo novo necessário nesta associação.**

### CDC-FIS-003 — Documento Fiscal x Arquivo de Origem

Idêntico à V1.2 — nenhuma alteração.

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
- **`DocumentoFiscal.unidade_economica_id` e `ArquivoOrigem.tenant_id` (§ novo) não são
  contratualizados como consistentes entre si por esta associação — são eixos diferentes
  (contexto de apuração × fronteira de segurança); a consistência exigida é de tenant apenas
  (o `Tenant` do `ArquivoOrigem` deve corresponder ao `Tenant` da `UnidadeEconomica` referenciada
  pelo `DocumentoFiscal`, via `CDC-REL-SEC-004`), não de `unidade_economica_id`.**

### CDC-EH-001 — Classificação de Equiparação Hospitalar

Idêntico à V1.2 — nenhuma alteração.

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
- **Tenant/UE derivam de `Receita` (`receita_id`, obrigatório) — nenhum campo novo necessário
  neste contrato.**

### CDC-PRE-001 — Contribuição Previdenciária *(atualizado nesta versão)*

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
| **unidade_economica_id** *(novo)* | MCD-F10004 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- **`unidade_economica_id` é o contexto de apuração (`DST-T034`), distinto do titular
  (`pessoa_fisica_id`) — mesma semântica de `CDC-REC-001` (`DST-001` V1.3 §11.1).**

### CDC-PREV-001 — Vínculo Previdenciário *(atualizado nesta versão)*

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
| **unidade_economica_id** *(novo)* | MCD-F10004 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- **`unidade_economica_id` é o contexto de apuração, distinto do titular (`pessoa_fisica_id`) —
  mesma semântica de `CDC-REC-001` (`DST-001` V1.3 §11.1).**

### CDC-IRP-001 — Evento IRPF / Carnê-Leão *(atualizado nesta versão)*

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
| **unidade_economica_id** *(novo)* | MCD-F10004 | input/output | required | system/import | versioned |

**Regras contratuais:**
- **`unidade_economica_id` é o contexto de apuração, distinto do titular (`pessoa_fisica_id`) e
  da fonte pagadora (`fonte_pagadora_id`, identidade global) — mesma semântica de `CDC-REC-001`
  (`DST-001` V1.3 §11.1).**

### CDC-FPG-001 — Fonte Pagadora

Idêntico à V1.2 — nenhuma alteração.

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
- **Identidade global compartilhável entre tenants — nenhum `tenant_id`/`unidade_economica_id`
  adicionado (`SEC-001` V1.0 §3, §10, confirmado nesta versão).**

### CDC-PLN-001 — Cenário Tributário

Idêntico à V1.2 — nenhuma alteração.

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
- **`unidade_economica_id` (`MCD-F8005`) já existia desde a V1.0/V1.1 como campo próprio deste
  objeto — não é uma instância de `MCD-F10004` (o campo transversal desta versão). Os dois IDs
  MCD são distintos porque `CenarioTributario.unidade_economica_id` já era `NOT NULL`/obrigatório
  desde antes do `SEC-CHANGE-REQUEST-001`, servindo de base para a decisão de não aplicar XOR em
  `ResultadoCalculo` (ver `CDC-CAL-001`).**

### CDC-CAL-001 — Resultado de Cálculo *(atualizado nesta versão)*

**Domínio:** `DOM-SYS`  
**Versão:** `1.3.0`  
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
| **unidade_economica_id** *(novo)* | MCD-F10004 | input/output | required | system/import | versioned |

**Regras contratuais:**
- Preservar snapshot/hash, engine e versão.
- rule_set_id/rule_set_version são opacos até RGT-001.
- **`unidade_economica_id` é sempre presente, inclusive quando `cenario_tributario_id` também
  está preenchido — os dois campos NÃO são mutuamente exclusivos (nenhum XOR). Quando ambos
  presentes, devem ser consistentes entre si: `unidade_economica_id` deve corresponder a
  `CenarioTributario.unidade_economica_id` (`CDC-PLN-001`, `MCD-F8005`, já obrigatório desde a
  baseline validada). Esta preservação de coexistência é explícita — uma proposta anterior de
  XOR foi avaliada e descartada durante o processo SEC (`SEC-001_AUDITORIA_CONSISTENCIA_V1.md`
  §3) por não haver ownership concorrente entre os dois campos.**

### CDC-ARQ-001 — Arquivo de Origem *(atualizado nesta versão)*

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
| **tenant_id** *(novo)* | MCD-F10003 | input/output | required | system/import | immutable |

**Regras contratuais:**
- **`tenant_id` é obrigatório desde a ingestão — obtido do contexto autenticado/autorizado da
  operação de upload/importação/coleta, nunca inferido do conteúdo do arquivo. Este contrato
  **não** inclui `unidade_economica_id`: um único arquivo pode conter informações de múltiplas
  Unidades Econômicas do mesmo tenant (ex.: extrato consolidado de um grupo econômico) — uma FK
  direta e única para UE seria estruturalmente incorreta. A resolução por UE ocorre
  posteriormente, na normalização/canonicalização, materializada em
  `DocumentoFiscal.unidade_economica_id` (`CDC-FIS-001`), nunca nesta camada RAW (`SEC-001`
  V1.0 §5).**
- **Deduplicação física de bytes no armazenamento é permitida (`armazenamento_referencia` pode
  apontar a um objeto compartilhado na camada de storage), desde que não produza compartilhamento
  de autorização — dois registros lógicos de tenants diferentes nunca se fundem, mesmo com
  `hash_conteudo` idêntico. Acesso nunca é concedido por igualdade de hash; `object key`/URL de
  armazenamento não constituem autorização (`SEC-001` V1.0 §5).**

### CDC-CFD-001 — Conflito de Dados *(atualizado nesta versão)*

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
| **tenant_id** *(novo)* | MCD-F10003 | input/output | required | reconciliation | immutable |

**Regras contratuais:**
- Conflito não é resolvido silenciosamente.
- Participantes são registrados por CDC-CFD-002.
- **`tenant_id` é carimbado pelo serviço de reconciliação no momento da criação — nunca escolhido
  arbitrariamente, nunca derivado da referência polimórfica de `ConflitoDadoItem`
  (`objeto_id`/`tipo_objeto`). Um `ConflitoDado` pode envolver itens de mais de uma
  `UnidadeEconomica` do mesmo tenant, mas nunca de tenants diferentes — `CDC-REL-SEC-002`
  (`SEC-001` V1.0 §6).**

### CDC-CFD-002 — Item de Conflito *(regra reafirmada; nenhum campo novo)*

**Domínio:** `DOM-SYS`  
**Versão:** `1.2.0` *(inalterada — nenhum campo foi adicionado ou removido)*  
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
- **Reafirmado explicitamente (`SEC-CHANGE-REQUEST-001` V1.1 item 8): `ConflitoDadoItem` NÃO
  recebe `tenant_id` próprio. O tenant é sempre lido através de `conflito_dado_id` → `ConflitoDado.
  tenant_id` (`CDC-CFD-001`, FK real já vigente e obrigatória) — nunca materializado
  redundantemente. A referência polimórfica `objeto_id`/`tipo_objeto` não determina, nem nunca
  determinou, ownership ou tenant deste item (`SEC-001` V1.0 §7).**

### CDC-REV-001 — Revisão Técnica *(atualizado nesta versão)*

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
| **tenant_id** *(novo)* | MCD-F10003 | input/output | required | system/import | immutable |

**Regras contratuais:**
- Identidade do revisor aguarda `OBS-001` (`SEC-001` já aprovado, mas não substitui `OBS-001`).
- Referência genérica revisada é exceção de auditoria.
- **`tenant_id` é carimbado pelo processo/contexto autenticado de quem realiza a revisão — nunca
  inferido do objeto revisado (`objeto_revisado_id`/`tipo_objeto_revisado`). A identidade
  específica do revisor permanece um atributo separado e ainda bloqueado, distinto do `tenant_id`
  da operação (`SEC-001` V1.0 §8).**

### CDC-SYS-001 — Metadados Transversais

Idêntico à V1.2 — nenhuma alteração. **Nota:** os novos campos transversais de segurança/contexto
(`tenant_id` raiz e transversal, `unidade_economica_id` transversal, `papel`) formam uma família
**separada** de metadados transversais (`DOM-SEC`), não uma extensão deste contrato — ver
`DST-001` V1.3 §10.1 e §11.

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

### CDC-SEC-001 — Tenant *(novo nesta versão)*

**Domínio:** `DOM-SEC`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-019`  
**Objetivo:** Fronteira técnica de isolamento, segurança e propriedade lógica dos dados; não
representa PessoaFisica, PessoaJuridica, UnidadeEconomica, um usuário individual, nem
necessariamente um cliente comercial (`SEC-001` V1.0 §1; `DST-T031`).

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F10001 | output | required | system | immutable |

**Regras contratuais:**
- `Tenant` não é um objeto de domínio tributário — nenhuma regra tributária se aplica a ele.
- `tenant_id ≠ unidade_economica_id` (`DST-T033`/`T034`) — nenhum campo deste contrato deve ser
  interpretado como contexto econômico/tributário.
- **Detalhamento completo de campos (ex.: `nome`, `status`) permanece bloqueado até Change
  Request específico de autenticação/RBAC — ver `GAP-CDC-1.3-001`.** Nenhum campo além de `id` é
  inventado por este contrato.

### CDC-SEC-002 — Evento de Auditoria de Segurança *(novo nesta versão)*

**Domínio:** `DOM-SEC`  
**Versão:** `1.3.0`  
**COT:** `COT-OBJ-020`  
**Objetivo:** Registro imutável de evento de segurança; distinto de auditoria tributária
(`ConflitoDado`/`RevisaoTecnica`) e de log técnico genérico (`SEC-001` V1.0 §16; `DST-T032`).

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id | MCD-F10006 | output | required | system | immutable |

**Regras contratuais:**
- Este objeto **não** é um repositório de logs técnicos — escopo estreito e explícito, restrito
  a eventos de segurança (login, falha de autenticação, mudança de permissão, elevação de
  privilégio, acesso sensível, override, operação administrativa).
- Este objeto **não** antecipa `EVT-001` (arquitetura de eventos de domínio genérica, documento
  ainda não escrito) — são conceitos distintos; eventual reconciliação futura entre os dois fica
  para quando `EVT-001` existir, não decidida aqui.
- **Diferenciação contratual obrigatória entre ator, tenant, UE (quando aplicável), operação,
  objeto afetado, instante e resultado é um requisito reafirmado de `SEC-001` V1.0 §16 — mas
  nenhum desses atributos possui campo MCD atribuído nesta versão.** Registrado como
  `GAP-CDC-1.3-002`, dependente de Change Request de autenticação/RBAC (e, para a identidade do
  ator/revisor especificamente, também de `OBS-001`). Nenhuma estrutura é inventada para
  preencher essa lacuna.

### CDC-SEC-003 — Conta de Acesso × Tenant *(novo nesta versão)*

**Domínio:** `DOM-SEC`  
**Versão:** `1.3.0`  
**COT:** `COT-SUP-005` (`ContaAcessoTenant`)  
**Objetivo:** Concessão explícita de acesso de uma `ContaAcesso` a um `Tenant` inteiro; nenhuma
concessão é implícita (`DST-T036`).

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| papel | MCD-F10005 | input/output | required | manual/system | versioned |

**Regras contratuais:**
- `papel` é Enum/Ref aberto — **nenhum enum é criado por este contrato**. Vocabulário fechado
  ainda não aprovado; ver `DST-GAP-015`.
- **Não criar `PapelAcesso` ou `Permissao` como objetos separados** — `papel` é um atributo
  direto desta associação (`SEC-CHANGE-REQUEST-001` V1.1 item 5, 8).
- **Este contrato é intencionalmente mínimo.** A identidade própria da associação (`id`) e as FKs
  estruturais (`conta_acesso_id`, `tenant_id`) ainda não possuem ID MCD atribuído — apenas
  `papel` (`MCD-F10005`) está formalmente catalogado. Registrado como `GAP-CDC-1.3-003`, não
  implementado por inferência (nenhum ID é inventado para essas colunas).
- Vigência/status da concessão não são contratualizados nesta versão por não terem sido aprovados
  no MCD (ver `GAP-CDC-1.3-003`).

### CDC-SEC-004 — Conta de Acesso × Unidade Econômica *(novo nesta versão)*

**Domínio:** `DOM-SEC`  
**Versão:** `1.3.0`  
**COT:** `COT-SUP-006` (`ContaAcessoUnidadeEconomica`)  
**Objetivo:** Restrição opcional de acesso de uma `ContaAcesso` a UEs específicas dentro de um
`Tenant` já concedido (`DST-T037`).

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| papel | MCD-F10005 | input/output | required | manual/system | versioned |

**Regras contratuais — formalização obrigatória da semântica de restrição:**
- A autorização por `UnidadeEconomica` **somente restringe** o escopo concedido pela associação
  `ContaAcesso ↔ Tenant` (`CDC-SEC-003`). Ela **nunca**:
  - concede `Tenant` (não substitui nem cria `CDC-SEC-003` — esta associação pressupõe uma
    concessão de Tenant já existente);
  - amplia o escopo já concedido pelo Tenant (não é possível usar esta associação para acessar
    uma UE fora do tenant já concedido);
  - substitui a associação `ContaAcesso ↔ Tenant`;
  - concede acesso implícito a outras UEs do mesmo tenant além das explicitamente listadas.
- **Invariante formal:** quando existir ao menos uma linha desta associação para um dado par
  (`ContaAcesso`, `Tenant`), a avaliação de autorização deve considerar exclusivamente as UEs
  explicitamente listadas para aquele par — a existência de uma restrição desliga o padrão "todas
  as UEs do tenant" (`CDC-REL-SEC-001`, §7).
- `papel` segue a mesma regra de `CDC-SEC-003` — aberto, `DST-GAP-015`, nenhum enum criado.
- Mesma limitação de escopo mínimo de `CDC-SEC-003`: `id`/FKs estruturais ainda sem ID MCD —
  `GAP-CDC-1.3-003`.

## 7. Constraints relacionais normativas

As seis primeiras constraints são idênticas à V1.2. Quatro novas constraints são adicionadas
para as regras relacionais de segurança/tenant aprovadas em `SEC-CHANGE-REQUEST-001` V1.1.

| Regra | Escopo | Constraint |
|---|---|---|
| CDC-REL-XOR-001 | Receita | pessoa_fisica_id XOR pessoa_juridica_id. |
| CDC-REL-XOR-002 | VinculoExtremidade | Exatamente uma FK entre UE/PF/PJ. |
| CDC-REL-CARD-001 | Vinculo | Exatamente duas extremidades: ORIGEM e DESTINO. |
| CDC-REL-UNQ-001 | ReceitaDocumentoFiscal | Unique(receita_id, documento_fiscal_id). |
| CDC-REL-UNQ-002 | DocumentoFiscalArquivoOrigem | Evitar associação duplicada; detalhe de unicidade depende do ADR/papel_arquivo. |
| CDC-REL-ID-001 | EqHop | Classificação possui id próprio e histórico não destrutivo. |
| **CDC-REL-SEC-001** *(novo)* | ContaAcessoUnidadeEconomica | Quando existir ao menos uma linha para o par (ContaAcesso, Tenant), a autorização considera exclusivamente as UEs explicitamente listadas — nunca ampliar, substituir a concessão de Tenant, ou conceder acesso implícito a outras UEs do mesmo tenant. |
| **CDC-REL-SEC-002** *(novo)* | ConflitoDado / ConflitoDadoItem | Todo ConflitoDadoItem deve pertencer ao mesmo tenant do ConflitoDado pai; um ConflitoDado nunca agrega itens de tenants diferentes. Validação de aplicação/serviço de reconciliação — a referência polimórfica não permite enforcement por FK. |
| **CDC-REL-SEC-003** *(novo)* | ResultadoCalculo | `unidade_economica_id` deve ser consistente com `CenarioTributario.unidade_economica_id` quando `cenario_tributario_id` estiver presente. Os dois campos não são mutuamente exclusivos — nenhum XOR. |
| **CDC-REL-SEC-004** *(novo)* | UnidadeEconomica × objetos com `unidade_economica_id`/`tenant_id` | Estrutura necessária para uma futura FK composta `(unidade_economica_id, tenant_id) → unidade_economica(id, tenant_id)`. Exige chave candidata `UNIQUE(id, tenant_id)` em `UnidadeEconomica`. **Forma física definitiva (FK composta, trigger, ou outro mecanismo) permanece responsabilidade exclusiva do ADR — não implementada por este CDC.** |

## 8. Estados de processamento e qualidade

Inalterado desde a V1.2. `status_processamento_dado` descreve workflow/lifecycle.
`status_qualidade_dado` descreve qualidade/condição de uso. São independentes e não podem ser
colapsados.

## 9. Proveniência, idempotência e reprocessamento

Inalterado desde a V1.2, com uma nota de escopo adicionada:

- Preservar RAW quando disponível.
- sistema_origem é origem de negócio/processo, não hosting.
- Preservar identificador_origem, arquivo_origem_id e correlation_id.
- Reprocessamento não apaga RAW nem histórico.
- Idempotência deve ser determinística conforme adapter/ADR.
- **`tenant_id` e `unidade_economica_id` (`DOM-SEC`, §6) não fazem parte da família de
  proveniência (`MCD-F9001..F9010`, `CDC-SYS-001`) — são eixos de segurança/contexto econômico
  independentes, nunca derivados de `sistema_origem`/`identificador_origem`/`correlation_id`
  nem substitutos deles.**

## 10. IA e ingestão documental

Inalterado desde a V1.2.

- Saída de LLM/OCR/parser é candidata, não fato autoritativo.
- Preservar confiança, localização/texto bruto e versão do extrator quando aplicável.
- Candidato passa por validação/reconciliação.
- IA não inventa regra tributária.

## 11. Lacunas residuais após V1.3

Os gaps `GAP-CDC-1.2-001`, `GAP-CDC-1.2-002`, `GAP-CDC-1.2-004` e `GAP-CDC-1.2-005` são idênticos
à V1.2. `GAP-CDC-1.2-003` recebe uma nota de status (sem ser resolvido).

| Gap | Tema | Tratamento |
|---|---|---|
| GAP-CDC-1.2-001 | papel_arquivo | Catálogo DST pendente; não criar enum fechado. |
| GAP-CDC-1.2-002 | tipo_objeto / papel_no_conflito | Catálogos dependem de OBS/reconciliação. |
| GAP-CDC-1.2-003 | Revisor de RevisaoTecnica | **Nota desta versão:** `SEC-001` foi aprovado, mas não resolve este gap — a identidade específica do revisor continua dependente de `OBS-001`, ainda não escrito. |
| GAP-CDC-1.2-004 | FontePagadora.identificador_fiscal | Tipagem CPF/CNPJ/Exterior ainda aberta. |
| GAP-CDC-1.2-005 | Demais gaps DST | Continuam bloqueados até publicação de catálogo. |
| **GAP-CDC-1.3-001** *(novo)* | Tenant — detalhamento completo | Campos além de `id` (ex.: `nome`, `status`) aguardam Change Request de autenticação/RBAC específico. |
| **GAP-CDC-1.3-002** *(novo)* | EventoAuditoriaSeguranca — detalhamento completo | Campos de ator, tenant/UE explícitos, operação, objeto afetado, instante e resultado (`SEC-001` V1.0 §16) aguardam Change Request de autenticação/RBAC; identidade do ator depende adicionalmente de `OBS-001`. |
| **GAP-CDC-1.3-003** *(novo)* | ContaAcessoTenant/ContaAcessoUnidadeEconomica — identidade e FKs estruturais | `id`, `conta_acesso_id`, `tenant_id`/`unidade_economica_id` destas duas associações ainda não possuem ID MCD; apenas `papel` (`MCD-F10005`) está catalogado. **Achado desta rodada de sincronização — registrado para a reconciliação cruzada, não bloqueante para esta versão do CDC** (mesmo padrão histórico de `ContaAcesso`/`CredencialAcesso`, catalogados sem campos completos por várias versões). |
| **GAP-CDC-1.3-004** *(novo)* | ContaAcesso/CredencialAcesso — detalhamento físico completo | Continua bloqueado (reafirmação do estado já vigente desde a V1.1/V1.2; nenhuma mudança). |

## 12. O que está liberado após CDC V1.3

- Fase 1 permanece válida sem alterações em UE/PF/PJ.
- `DST-001` V1.3 já publicado e sincronizado.
- Próximo passo: **reconciliação cruzada** (COT × MCD × CDC × DST), abordando explicitamente
  `GAP-CDC-1.3-003` (identidade/FKs das associações de acesso).
- Depois da reconciliação, elaborar `ADR-002` (schema físico de segurança/tenant).
- Nenhuma migration antes do ADR aprovado.
- Autenticação completa aguarda Change Request específico; regras tributárias aguardam RGT.

## 13. Política para Claude Code

```yaml
cdc_policy:
  version: 1.3
  mcd_required: 1.3
  cot_required: 1.2
  dst_required: 1.3
  supersedes: CDC-001-v1.2
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
  data_state:
    processing: status_processamento_dado
    quality: status_qualidade_dado
    collapse_axes: prohibited
  tenant_rules:
    tenant_id_equals_unidade_economica_id: false
    tenant_id_root_and_transversal_share_mcd_id: false
    polymorphic_reference_determines_tenant: false
    papel_is_closed_enum: false
    papel_acesso_permissao_objects: created: false
    sessao_object_canonical: false
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

- [x] Todos os campos existem no MCD V1.3.
- [x] Receita usa PF/PJ com XOR (inalterado).
- [x] VinculoExtremidade formalizado (inalterado).
- [x] N:N documentais com contratos próprios (inalterado).
- [x] EqHop com identidade própria (inalterado).
- [x] Conflito com itens participantes (inalterado).
- [x] MCD-F9009 preservado (inalterado).
- [x] Processamento e qualidade separados (inalterado).
- [x] Nenhum enum pendente inventado.
- [x] `Tenant` e `EventoAuditoriaSeguranca` contratualizados com IDs CDC novos (`CDC-SEC-001`/`002`).
- [x] `ContaAcesso ↔ Tenant` e `ContaAcesso ↔ UnidadeEconomica` contratualizados (`CDC-SEC-003`/`004`), com `papel` aberto e semântica de restrição formalizada.
- [x] `UnidadeEconomica.tenant_id`, `unidade_economica_id` transversal (6 hospedeiros) e `tenant_id` transversal (3 hospedeiros) contratualizados.
- [x] `ConflitoDadoItem` preservado sem `tenant_id` próprio.
- [x] `ResultadoCalculo` preservado sem XOR.
- [x] `PessoaFisica`/`PessoaJuridica`/`FontePagadora` preservados sem `tenant_id`/`unidade_economica_id`.
- [x] `Sessao`/`PapelAcesso`/`Permissao` não transformados em contratos canônicos.
- [x] Nenhum ID CDC reutilizado.
- [x] Nenhum campo aposentado retornou.

**Bloqueios restantes para schema/migration:**

- [ ] Reconciliação cruzada COT × MCD × CDC × DST (incluindo `GAP-CDC-1.3-003`).
- [ ] `ADR-002` físico de segurança/tenant aprovado.

## 15. Próximo documento

**Reconciliação cruzada COT-001 V1.2 × MCD-001 V1.3 × CDC-001 V1.3 × DST-001 V1.3**, endereçando
explicitamente `GAP-CDC-1.3-003` (identidade/FKs de `ContaAcessoTenant`/
`ContaAcessoUnidadeEconomica` ainda não catalogadas no MCD). Somente depois, **`ADR-002`** —
schema físico de segurança/tenant.

---
**Governança:** CDC-001 V1.3 passa a ser o contrato vigente após aprovação. CDC V1.2/V1.1/V1.0 ficam como histórico SUPERSEDED. Este documento não autoriza migration.
