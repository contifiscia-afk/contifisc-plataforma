# MCD-001 — Modelo Canônico de Dados da CONTIFISC

**Versão:** 1.3  
**Status:** APROVADO — incorpora `SEC-CHANGE-REQUEST-001` V1.1 (APROVADO); schema físico ainda condicionado a CDC/DST V1.3 (a publicar) + ADR  
**Supersede:** MCD-001 V1.2  
**Incorpora:** MCD-CHANGE-REQUEST-001, MCD-CHANGE-REQUEST-002 V1.0 e `SEC-CHANGE-REQUEST-001` V1.1 (todos APROVADOS)  
**Dependências:** CAF-001, COT-001 V1.2, CDC-001 V1.2, DST-001 V1.2, `SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`  
**Sincronizações requeridas:** CDC-001 V1.3, DST-001 V1.3 (ainda a publicar — ver §25)  
**Escopo:** CONTIFISC Intelligence Platform — profissionais da saúde

> **Princípio central:** o MCD define a representação canônica dos dados. O schema físico, ORM, banco, ERP e interfaces são implementações/integrações subordinadas ao modelo; nunca são sua fonte de verdade.

## 1. Objetivo

Incorporar formalmente o `SEC-CHANGE-REQUEST-001` V1.1, adicionando os campos canônicos
necessários para resolver o modelo de ownership/tenant aprovado em `SEC-001` V1.0, sem alterar
nenhum campo, objeto ou regra já vigente na V1.2. A V1.3 preserva integralmente os 139 campos
canônicos da V1.2 e adiciona 6 novos campos ao domínio `DOM-SEC` (antes reservado e sem detalhamento).

## 2. Governança e versionamento

- Esta V1.3 substitui integralmente o MCD-001 V1.2 para código novo.
- Os IDs de campos removidos ficam aposentados e não podem ser reutilizados com outro significado.
- Nenhum campo, objeto ou ID da V1.2 é removido, renomeado ou reaproveitado por esta versão — a mudança é estritamente aditiva.
- A publicação como V1.3, assim como a V1.2, é uma exceção pré-implementação aprovada: ainda não existe migration/schema de produção.
- A Fase 1 já implementada para UnidadeEconomica, PessoaFisica e PessoaJuridica permanece válida e não requer renomeação.

## 3. Decisões arquiteturais da baseline V1.3

Todas as decisões da V1.2 (§3 da versão anterior) permanecem vigentes e não são repetidas aqui.
Decisões adicionadas por esta V1.3:

- **`Tenant`** é a fronteira técnica de isolamento, segurança e propriedade lógica dos dados —
  **não representa** `PessoaFisica`, `PessoaJuridica`, `UnidadeEconomica`, um usuário individual,
  nem necessariamente um cliente comercial (`SEC-001` §1).
- **`UnidadeEconomica` continua sendo o contexto econômico/tributário** — ganha uma relação
  obrigatória com `Tenant` (`tenant_id`), sem nenhuma mudança de sua semântica tributária já
  vigente.
- **`identidade tributária ≠ identidade de acesso ≠ tenant ≠ unidade econômica`** — princípio
  normativo explícito que rege toda a incorporação desta versão (`SEC-001` §1).
- **`PessoaFisica`, `PessoaJuridica` e `FontePagadora` são identidades globais compartilháveis
  entre tenants** — nenhuma delas recebe `tenant_id` ou `unidade_economica_id` direto; o acesso
  aos fatos relacionados é determinado pelo contexto tenant-scoped **desses fatos**, nunca pela
  simples existência de vínculo com a identidade global (`SEC-001` §3).
- **`Cliente`/`Organização` como entidade canônica separada de `Tenant` é
  `REDUNDANTE_NESTA_FASE`** — não incorporado.
- **`Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`,
  `DocumentoFiscal` e `ResultadoCalculo` ganham contexto de apuração explícito em
  `UnidadeEconomica`**, distinto do titular tributário PF/PJ já existente (`SEC-001` §4).
- **`ArquivoOrigem`, `ConflitoDado` e `RevisaoTecnica` ganham `tenant_id` transversal** — nenhum
  dos três ganha `unidade_economica_id` direto (`SEC-001` §5, §6, §8).
- **`ConflitoDadoItem` permanece sem `tenant_id` próprio** — deriva sempre do `ConflitoDado` pai
  via a FK já vigente (`SEC-001` §7).
- **`ResultadoCalculo.unidade_economica_id` não é mutuamente exclusivo com
  `ResultadoCalculo.cenario_tributario_id`** — os dois devem ser consistentes entre si quando
  ambos presentes, nunca XOR (`SEC-001` §9, correção de uma proposta anterior descartada).
- **Nenhum enum nativo foi criado; nenhum vocabulário DST foi fechado por esta versão.**

## 4. Convenção de nomenclatura V1.3

Inalterada em relação à V1.2 (ver seção correspondente da versão anterior, preservada
integralmente):

- `snake_case`, ASCII, nomes descritivos em português.
- PK de objeto: `id`.
- FK/referência concreta: `<objeto>_id`.
- Datas de negócio: `data_*`; timestamps técnicos: `*_em`; vigência: `vigencia_inicio`/`vigencia_fim`.
- Competência: `competencia`.
- Dinheiro: `valor_*`; percentuais: `percentual_*`; status: `status_*`; tipos: `tipo_*`.
- Booleanos devem preferir semântica explícita (`eh_*`, `possui_*`, `permite_*`) em vez de substantivo ambíguo.
- Não codificar tipo físico no nome do campo.

## 5. Tipos canônicos

Inalterados em relação à V1.2 — ver tabela da versão anterior. Nenhum tipo novo foi necessário
para os 6 campos desta V1.3 (todos `UUID`/FK ou `Texto` aberto).

## 6. Nulidade e estados especiais

Inalterado em relação à V1.2.

## 7. Domínios canônicos

| Código | Domínio | Responsabilidade |
|---|---|---|
| DOM-CORE | Núcleo | Unidade Econômica e contexto agregador. |
| DOM-PER | Pessoa Física | Identidade tributária e qualificações da pessoa. |
| DOM-EMP | Pessoa Jurídica | Identidade PJ e atributos tributários temporais. |
| DOM-REL | Relacionamentos | Vínculos e estruturas relacionais de suporte. |
| DOM-REC | Receitas | Receitas e fontes pagadoras. |
| DOM-FIS | Fiscal | Documentos fiscais e associações documentais. |
| DOM-EH | Equiparação Hospitalar | Resultados derivados de classificação/segregação. |
| DOM-PRE | Previdenciário | Contribuições e vínculos previdenciários. |
| DOM-IRP | IRPF/Carnê-Leão | Fatos e resultados relevantes à PF. |
| DOM-PLN | Planejamento | Cenários tributários. |
| DOM-SYS | Sistema/Qualidade | Proveniência, arquivos, cálculo, conflito, revisão e estados do dado. |
| DOM-SEC | Segurança | **Tenant, isolamento, contexto de apuração transversal e auditoria de segurança** (`SEC-CHANGE-REQUEST-001` V1.1). Detalhamento completo de `ContaAcesso`/`CredencialAcesso`/`Tenant`/`EventoAuditoriaSeguranca` além dos campos mínimos abaixo permanece bloqueado até Change Request específico de autenticação/RBAC. |

## 8. Catálogo canônico V1.3 (145 campos)

A coluna `Obrig. base` representa o requisito estrutural mínimo. O CDC continua soberano para obrigatoriedade por operação. `XOR` significa que o grupo indicado deve satisfazer exclusividade lógica conforme a seção de constraints.

**Os 139 campos das seções DOM-CORE a DOM-SYS abaixo são idênticos à V1.2, sem nenhuma alteração
de ID, nome, tipo ou política.** Reproduzidos integralmente para preservar a integridade do
catálogo em um único documento.

### DOM-CORE — Núcleo

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F0001 | id | Identificador da Unidade Econômica | UUID |  - | Sistema | Sim | Imutável |
| MCD-F0002 | nome | Nome da Unidade Econômica | Texto(160) |  - | Cadastro | Sim | Versionado |
| MCD-F0003 | status_registro | Situação do registro | Enum |  - | Sistema/Cadastro | Sim | Versionado |
| MCD-F0004 | criado_em | Data/hora de criação | Timestamp TZ |  - | Sistema | Sim | Imutável |
| MCD-F0005 | atualizado_em | Data/hora da última atualização | Timestamp TZ |  - | Sistema | Sim | Versionado |

### DOM-PER — Pessoa Física

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F1001 | id | Identificador da Pessoa Física | UUID |  - | Sistema | Sim | Imutável |
| MCD-F1002 | cpf | CPF | Texto(11) | dígitos | Cadastro/Importação | Cond. | Versionado |
| MCD-F1003 | nome | Nome completo | Texto(200) |  - | Cadastro/Importação | Sim | Versionado |
| MCD-F1004 | data_nascimento | Data de nascimento | Date |  - | Cadastro/Importação | Não | Versionado |
| MCD-F1005 | conselho_profissional | Conselho profissional | Enum/Ref | - | Cadastro | Não | Versionado |
| MCD-F1006 | registro_profissional | Número/registro no conselho | Texto(30) |  - | Cadastro | Não | Versionado |
| MCD-F1007 | uf_registro_profissional | UF do conselho | Texto(2) | UF | Cadastro | Não | Versionado |
| MCD-F1008 | especialidade_saude | Especialidade/área profissional | Enum/Ref |  - | Cadastro | Não | Versionado |

### DOM-EMP — Pessoa Jurídica

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F2001 | id | Identificador da Pessoa Jurídica | UUID |  - | Sistema | Sim | Imutável |
| MCD-F2002 | cnpj | CNPJ | Texto(14) | dígitos | ERP/Cadastro | Cond. | Versionado |
| MCD-F2003 | razao_social | Razão social | Texto(200) |  - | ERP/Cadastro | Não | Versionado |
| MCD-F2004 | regime_tributario | Regime tributário | Enum |  - | ERP/Cadastro | Cond. | Temporal |
| MCD-F2005 | cnae_principal | CNAE principal | Texto(7) | dígitos | ERP/Cadastro | Não | Temporal |
| MCD-F2006 | data_abertura | Data de abertura | Date |  - | ERP/Cadastro | Não | Versionado |
| MCD-F2007 | municipio_ibge | Código do município IBGE | Texto(7) | IBGE | ERP/Cadastro | Não | Temporal |

### DOM-REL — Relacionamentos

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F2501 | id | Identificador do Vínculo | UUID |  - | Sistema | Sim | Imutável |
| MCD-F2502 | tipo_vinculo | Tipo estrutural do vínculo | Enum |  - | Cadastro/Sistema | Sim | Temporal |
| MCD-F2503 | percentual_participacao_societaria | Participação societária | Decimal(7,4) | \% | ERP/Cadastro | Não | Temporal |
| MCD-F2504 | vigencia_inicio | Início da vigência do vínculo | Date |  - | ERP/Cadastro | Não | Temporal |
| MCD-F2505 | vigencia_fim | Fim da vigência do vínculo | Date |  - | ERP/Cadastro | Não | Temporal |
| MCD-F2510 | papel_vinculo | Papel exercido no relacionamento | Enum |  - | Cadastro/Sistema | Cond. | Temporal |
| MCD-F2520 | id | Identificador da extremidade do vínculo | UUID | - | Sistema | Sim | Imutável |
| MCD-F2521 | vinculo_id | Vínculo pai | UUID/FK | - | Sistema | Sim | Imutável |
| MCD-F2522 | lado_extremidade | Lado da extremidade: origem/destino | Enum | - | Sistema/Cadastro | Sim | Versionado |
| MCD-F2523 | unidade_economica_id | Endpoint Unidade Econômica | UUID/FK | - | Sistema/Cadastro | XOR | Temporal |
| MCD-F2524 | pessoa_fisica_id | Endpoint Pessoa Física | UUID/FK | - | Sistema/Cadastro | XOR | Temporal |
| MCD-F2525 | pessoa_juridica_id | Endpoint Pessoa Jurídica | UUID/FK | - | Sistema/Cadastro | XOR | Temporal |

### DOM-REC — Receitas

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F3001 | id | Identificador da Receita | UUID |  - | Sistema | Sim | Imutável |
| MCD-F3002 | valor_receita_bruta | Valor bruto da receita | Decimal(18,2) | BRL | ERP/XML/Manual | Cond. | Fato imutável |
| MCD-F3003 | data_emissao | Data de emissão | Date |  - | XML/Documento | Não | Fato imutável |
| MCD-F3004 | competencia | Competência | Competência | YYYY-MM | ERP/XML/Manual | Cond. | Fato imutável |
| MCD-F3005 | fonte_receita | Fonte da receita | Enum/Ref |  - | Classificação | Cond. | Versionado |
| MCD-F3007 | fonte_pagadora_id | Fonte pagadora | UUID/Ref |  - | Importação/Cadastro | Não | Versionado |
| MCD-F3008 | valor_retencoes | Retenções vinculadas | Decimal(18,2) | BRL | XML/Informe | Não | Fato imutável |
| MCD-F3010 | pessoa_fisica_id | Titular Pessoa Física da receita | UUID/FK | - | Sistema/Classificação | XOR | Versionado |
| MCD-F3011 | pessoa_juridica_id | Titular Pessoa Jurídica da receita | UUID/FK | - | Sistema/Classificação | XOR | Versionado |
| MCD-F7201 | id | Identificador da Fonte Pagadora | UUID |  - | Sistema | Sim | Imutável |
| MCD-F7202 | tipo_fonte_pagadora | Tipo da fonte pagadora | Enum |  - | Cadastro/Classificação | Sim | Versionado |
| MCD-F7203 | identificador_fiscal | CPF/CNPJ/identificador da fonte quando disponível | Texto(20) |  - | Cadastro/Importação | Não | Versionado |
| MCD-F7204 | nome | Nome/razão da fonte pagadora | Texto(200) |  - | Cadastro/Importação | Não | Versionado |

### DOM-FIS — Fiscal

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F4001 | id | Identificador do Documento Fiscal | UUID |  - | Sistema | Sim | Imutável |
| MCD-F4002 | tipo_documento_fiscal | Tipo do documento fiscal | Enum |  - | Importação | Sim | Fato imutável |
| MCD-F4003 | numero_documento_fiscal | Número do documento | Texto(60) |  - | XML/Documento | Não | Fato imutável |
| MCD-F4004 | chave_documento_fiscal | Chave/ID externo | Texto(80) |  - | XML/API | Não | Fato imutável |
| MCD-F4005 | codigo_servico_fiscal | Código do serviço | Texto(30) |  - | XML/API | Não | Fato imutável |
| MCD-F4006 | descricao_servico_fiscal | Descrição do serviço | Texto longo |  - | XML/API | Não | Fato imutável |
| MCD-F4007 | valor_documento_fiscal | Valor total do documento | Decimal(18,2) | BRL | XML/API | Não | Fato imutável |
| MCD-F4301 | id | Identificador da associação Receita-Documento Fiscal | UUID | - | Sistema | Sim | Imutável |
| MCD-F4302 | receita_id | Receita associada | UUID/FK | - | Sistema | Sim | Imutável |
| MCD-F4303 | documento_fiscal_id | Documento fiscal associado | UUID/FK | - | Sistema | Sim | Imutável |
| MCD-F4401 | id | Identificador da associação Documento-Arquivo | UUID | - | Sistema | Sim | Imutável |
| MCD-F4402 | documento_fiscal_id | Documento fiscal associado | UUID/FK | - | Sistema | Sim | Imutável |
| MCD-F4403 | arquivo_origem_id | Arquivo RAW/evidência associado | UUID/FK | - | Sistema | Sim | Imutável |
| MCD-F4404 | papel_arquivo | Papel da evidência no documento | Enum/Ref | - | Sistema/Classificação | Não | Versionado |

### DOM-EH — Equiparação Hospitalar

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F5001 | status_elegibilidade_equiparacao_hospitalar | Status de elegibilidade EqHop | Enum |  - | Motor/Revisão | Cond. | Resultado versionado |
| MCD-F5002 | percentual_receita_elegivel | Percentual elegível | Decimal(7,4) | \% | Motor/Revisão | Não | Resultado versionado |
| MCD-F5003 | valor_receita_elegivel | Valor elegível segregado | Decimal(18,2) | BRL | Cálculo | Não | Resultado versionado |
| MCD-F5004 | valor_receita_nao_elegivel | Valor não elegível segregado | Decimal(18,2) | BRL | Cálculo | Não | Resultado versionado |
| MCD-F5005 | percentual_confianca_classificacao | Confiança do classificador | Decimal(7,4) | \% | IA/Classificador | Não | Resultado versionado |
| MCD-F5006 | eh_validada_tecnicamente | Indicador derivado de validação técnica | Boolean | - | Revisão/Sistema | Não | Resultado versionado |
| MCD-F5007 | receita_id | Receita submetida à classificação | UUID |  - | Sistema/Motor | Sim | Resultado versionado |
| MCD-F5008 | regra_versao_id | Versão/conjunto de regra aplicado | Texto/UUID |  - | Motor | Cond. | Resultado versionado |
| MCD-F5009 | id | Identificador da classificação EqHop | UUID | - | Sistema | Sim | Imutável |
| MCD-F5010 | registrado_em | Momento do registro da classificação | Timestamp TZ | - | Sistema/Motor | Sim | Imutável |
| MCD-F5011 | atualizado_em | Momento da última atualização técnica | Timestamp TZ | - | Sistema/Motor | Não | Versionado |

### DOM-PRE — Previdenciário

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F6001 | id | Identificador da Contribuição Previdenciária | UUID |  - | Sistema | Sim | Imutável |
| MCD-F6002 | valor_inss_recolhido | INSS recolhido | Decimal(18,2) | BRL | CNIS/Folha/Informe | Cond. | Fato imutável |
| MCD-F6003 | valor_salario_contribuicao | Salário/base de contribuição | Decimal(18,2) | BRL | CNIS/Folha | Não | Fato imutável |
| MCD-F6004 | valor_teto_previdenciario | Teto da competência | Decimal(18,2) | BRL | Tabela legal | Cond. | Referência versionada |
| MCD-F6005 | valor_excedente_inss | Excedente potencial calculado | Decimal(18,2) | BRL | Cálculo | Não | Resultado versionado |
| MCD-F6006 | vinculo_previdenciario_id | Fonte/vínculo previdenciário | UUID/Ref |  - | CNIS/Cadastro | Não | Temporal |
| MCD-F6007 | pessoa_fisica_id | Titular da contribuição | UUID |  - | Sistema | Sim | Versionado |
| MCD-F6101 | id | Identificador do Vínculo Previdenciário | UUID |  - | Sistema | Sim | Imutável |
| MCD-F6102 | pessoa_fisica_id | Pessoa titular do vínculo | UUID |  - | Sistema/Cadastro | Sim | Temporal |
| MCD-F6103 | tipo_vinculo_previdenciario | Tipo/fonte previdenciária | Enum |  - | CNIS/Cadastro | Sim | Temporal |
| MCD-F6104 | vigencia_inicio | Início da vigência | Date |  - | CNIS/Cadastro | Não | Temporal |
| MCD-F6105 | vigencia_fim | Fim da vigência | Date |  - | CNIS/Cadastro | Não | Temporal |

### DOM-IRP — IRPF/Carnê-Leão

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F7001 | id | Identificador do Evento IRPF | UUID |  - | Sistema | Sim | Imutável |
| MCD-F7002 | tipo_rendimento_irpf | Natureza do rendimento | Enum |  - | Classificação/Informe | Cond. | Versionado |
| MCD-F7003 | valor_rendimento_tributavel | Rendimento tributável | Decimal(18,2) | BRL | Informe/Carnê/ERP | Não | Fato imutável |
| MCD-F7004 | valor_rendimento_isento | Rendimento isento | Decimal(18,2) | BRL | Informe/ERP | Não | Fato imutável |
| MCD-F7005 | valor_deducao_irpf | Dedução considerada | Decimal(18,2) | BRL | Documento/Carnê | Não | Versionado |
| MCD-F7006 | valor_livro_caixa | Despesa de livro-caixa | Decimal(18,2) | BRL | Carnê/Manual | Não | Versionado |
| MCD-F7007 | valor_irpf_retido | IRPF retido | Decimal(18,2) | BRL | Informe | Não | Fato imutável |
| MCD-F7008 | valor_irpf_projetado | IRPF projetado | Decimal(18,2) | BRL | Cálculo | Não | Resultado versionado |
| MCD-F7009 | pessoa_fisica_id | Titular do evento IRPF | UUID |  - | Sistema | Sim | Versionado |
| MCD-F7010 | fonte_pagadora_id | Fonte pagadora do rendimento | UUID/Ref |  - | Importação/Cadastro | Não | Versionado |

### DOM-PLN — Planejamento

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F8001 | id | Identificador do Cenário Tributário | UUID |  - | Sistema | Sim | Imutável |
| MCD-F8002 | nome | Nome do cenário | Texto(120) |  - | Usuário/Sistema | Sim | Versionado |
| MCD-F8003 | valor_carga_tributaria_projetada | Carga tributária projetada | Decimal(18,2) | BRL | Cálculo | Não | Resultado versionado |
| MCD-F8004 | valor_economia_tributaria_projetada | Economia tributária projetada | Decimal(18,2) | BRL | Cálculo | Não | Resultado versionado |
| MCD-F8005 | unidade_economica_id | Contexto econômico avaliado | UUID |  - | Sistema | Sim | Versionado |

### DOM-SYS — Sistema/Qualidade

| ID | Campo | Significado | Tipo | Unidade | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F8201 | id | Identificador do Resultado de Cálculo | UUID |  - | Sistema | Sim | Imutável |
| MCD-F8202 | cenario_tributario_id | Cenário relacionado quando aplicável | UUID/Ref |  - | Sistema | Não | Versionado |
| MCD-F8203 | input_snapshot_hash | Hash do snapshot de entradas | Texto(128) |  - | Motor | Sim | Imutável |
| MCD-F8204 | engine_id | Identificador do motor | Texto(80) |  - | Motor | Sim | Imutável |
| MCD-F8205 | engine_version | Versão do motor | Texto(20) | SemVer | Motor | Sim | Imutável |
| MCD-F8206 | rule_set_id | Conjunto de regras utilizado | Texto(80) |  - | Motor | Sim | Imutável |
| MCD-F8207 | rule_set_version | Versão do conjunto de regras | Texto(20) | SemVer | Motor | Sim | Imutável |
| MCD-F8208 | calculado_em | Momento do cálculo | Timestamp TZ |  - | Motor | Sim | Imutável |
| MCD-F8209 | status_revisao | Status de revisão do resultado | Enum |  - | Motor/Revisor | Não | Versionado |
| MCD-F8401 | id | Identificador do Arquivo de Origem | UUID |  - | Sistema | Sim | Imutável |
| MCD-F8402 | nome_arquivo | Nome original/lógico do arquivo | Texto(255) |  - | Ingestão | Não | Imutável |
| MCD-F8403 | hash_conteudo | Hash do conteúdo bruto | Texto(128) |  - | Ingestão | Sim | Imutável |
| MCD-F8404 | tipo_mime | MIME type | Texto(120) |  - | Ingestão | Não | Imutável |
| MCD-F8405 | armazenamento_referencia | Referência segura ao objeto armazenado | Texto(500) |  - | Ingestão | Sim | Versionado |
| MCD-F8601 | id | Identificador do Conflito de Dados | UUID |  - | Sistema | Sim | Imutável |
| MCD-F8602 | status_conflito | Status do conflito | Enum |  - | Reconciliação | Sim | Versionado |
| MCD-F8603 | tipo_conflito | Natureza do conflito | Enum |  - | Reconciliação | Sim | Versionado |
| MCD-F8604 | descricao | Descrição técnica do conflito | Texto longo |  - | Reconciliação | Não | Versionado |
| MCD-F8650 | id | Identificador do item de conflito | UUID | - | Sistema | Sim | Imutável |
| MCD-F8651 | conflito_dado_id | Conflito de dados pai | UUID/FK | - | Reconciliação | Sim | Imutável |
| MCD-F8652 | tipo_objeto | Tipo do objeto canônico referenciado | Enum/Ref | - | Reconciliação | Sim | Versionado |
| MCD-F8653 | objeto_id | Objeto participante do conflito | UUID | - | Reconciliação | Cond. | Imutável |
| MCD-F8654 | sistema_origem | Sistema/processo de origem participante | Enum/Ref | - | Reconciliação | Não | Imutável |
| MCD-F8655 | identificador_origem | Identificador do registro na origem | Texto(120) | - | Reconciliação | Não | Imutável |
| MCD-F8656 | papel_no_conflito | Papel do item no conflito | Enum/Ref | - | Reconciliação | Não | Versionado |
| MCD-F8657 | valor_hash | Hash opcional do valor/evidência comparada | Texto(128) | - | Reconciliação | Não | Imutável |
| MCD-F8701 | id | Identificador da Revisão Técnica | UUID |  - | Sistema | Sim | Imutável |
| MCD-F8702 | objeto_revisado_id | Objeto/resultado revisado | UUID |  - | Sistema | Sim | Imutável |
| MCD-F8703 | tipo_objeto_revisado | Tipo do objeto revisado | Enum |  - | Sistema | Sim | Imutável |
| MCD-F8704 | status_revisao | Decisão/status da revisão | Enum |  - | Revisor | Sim | Versionado |
| MCD-F8705 | justificativa | Justificativa da revisão | Texto longo |  - | Revisor | Cond. | Imutável |
| MCD-F8706 | revisado_em | Momento da revisão | Timestamp TZ |  - | Sistema | Sim | Imutável |
| MCD-F9001 | sistema_origem | Sistema/processo de origem | Enum/Texto |  - | Gateway/Sistema | Sim\* | Imutável |
| MCD-F9002 | identificador_origem | Identificador do registro na origem | Texto(120) |  - | Gateway | Não | Imutável |
| MCD-F9003 | importado_em | Data/hora de importação | Timestamp TZ |  - | Gateway | Não | Imutável |
| MCD-F9004 | status_processamento_dado | Estado de processamento/lifecycle do dado | Enum | - | Validador/Reconciliador | Não | Versionado |
| MCD-F9005 | versao_schema | Versão do schema/contrato | Texto(20) | SemVer | Sistema/Gateway | Sim\* | Imutável |
| MCD-F9006 | correlation_id | Correlação entre operações/importações | UUID |  - | Sistema/Gateway | Não | Imutável |
| MCD-F9007 | registrado_em | Momento do registro canônico | Timestamp TZ |  - | Sistema | Sim\* | Imutável |
| MCD-F9008 | data_fato | Data de ocorrência do fato | Date/Timestamp |  - | Origem/Normalização | Não | Fato imutável |
| MCD-F9009 | arquivo_origem_id | Evidência RAW associada | UUID/Ref | - | Sistema/Gateway | Não | Imutável |
| MCD-F9010 | status_qualidade_dado | Qualidade intrínseca/condição de uso do dado | Enum | - | Validador/Revisor | Não | Versionado |

### DOM-SEC — Segurança *(nova nesta versão, 6 campos)*

Campos introduzidos por `SEC-CHANGE-REQUEST-001` V1.1. Alguns são **transversais** (aplicados
fisicamente a mais de um objeto, mesmo padrão de `MCD-F9001..F9010`) — a coluna "Objeto(s)" indica
onde cada um se materializa. **Nenhum destes campos reutiliza um ID `MCD-F9001..F9010`.**

| ID | Campo | Significado | Tipo | Objeto(s) | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F10001 | id | Identificador do Tenant | UUID | Tenant | Sistema | Sim | Imutável |
| MCD-F10002 | tenant_id | Tenant ao qual a Unidade Econômica pertence (âncora raiz do isolamento) | UUID/FK | UnidadeEconomica | Sistema/Cadastro | Sim | Imutável |
| MCD-F10003 | tenant_id | Tenant responsável pelo registro — metadado transversal de segurança, carimbado pelo processo/sessão que cria o registro; nunca derivado do objeto polimórfico referenciado | UUID/FK | ArquivoOrigem, ConflitoDado, RevisaoTecnica | Gateway/Reconciliação/Revisor | Sim | Imutável |
| MCD-F10004 | unidade_economica_id | Contexto econômico/tributário de apuração do fato — distinto do titular tributário PF/PJ já existente | UUID/FK | Receita, ContribuicaoPrevidenciaria, VinculoPrevidenciario, EventoIRPF, DocumentoFiscal, ResultadoCalculo | Sistema/Lançamento | Sim | Imutável |
| MCD-F10005 | papel | Papel/perfil da concessão de acesso | Enum/Ref | ContaAcessoTenant, ContaAcessoUnidadeEconomica | Concessão de acesso | Sim | Versionado |
| MCD-F10006 | id | Identificador do Evento de Auditoria de Segurança | UUID | EventoAuditoriaSeguranca | Sistema | Sim | Imutável |

**Por que `MCD-F10002` e `MCD-F10003` são IDs distintos apesar do mesmo nome físico
(`tenant_id`):** um ID de campo MCD representa um conceito canônico único e estável, não um nome
de coluna. `MCD-F10002` é **definido no momento da criação da UnidadeEconomica** e nunca muda — é
a âncora da qual os outros 16 objetos (via `MCD-F10004` ou relação já existente) derivam tenant.
`MCD-F10003` é **carimbado pelo processo operacional** que cria o registro (ingestão,
reconciliação, revisão) — sua fonte é o contexto de execução, não uma decisão de domínio inerente
ao objeto, e nada deriva tenant a partir dele. Tratá-los como o mesmo campo canônico só porque
compartilham nome físico violaria o mesmo princípio de precisão já seguido por `MCD-F9001..F9010`
(`SEC-CHANGE-REQUEST-001` V1.1 item 7).

**Por que `MCD-F10004` é um único ID transversal para 6 objetos (e não 6 IDs distintos, ao
contrário do padrão de `receita_id`, que recebe `MCD-F4302` em um objeto e `MCD-F5007` em
outro):** a diferença está na estabilidade do significado. `receita_id` identifica um papel
diferente conforme o objeto que o hospeda (em `ReceitaDocumentoFiscal`, é "o lado receita da
associação"; em `ClassificacaoEquiparacaoHospitalar`, é "a receita sendo classificada") — papéis
distintos, ainda que apontando para o mesmo tipo de objeto. Já `unidade_economica_id` (esta
versão) responde exatamente à mesma pergunta em todos os seis hospedeiros — "sob qual UE este
fato está sendo administrado" — sem nenhuma variação de papel, exatamente como `registrado_em`
(`MCD-F9007`) significa "momento do registro canônico" identicamente em 16 objetos diferentes.

**Detalhamento de campos além dos listados acima** (ex.: `Tenant.nome`, `Tenant.status`,
`EventoAuditoriaSeguranca.tipo_evento`/`ocorrido_em`/`ator`/`resultado`, campos completos de
`ContaAcesso`/`CredencialAcesso`) **permanece bloqueado até Change Request específico de
autenticação/RBAC** — apenas os campos estritamente necessários para as relações aprovadas em
`SEC-CHANGE-REQUEST-001` V1.1 foram incorporados nesta V1.3, conforme o mesmo padrão já usado
para `ContaAcesso`/`CredencialAcesso` desde a V1.1 do COT (catalogados como objetos, sem campos
completos, até autorização específica).

## 9. Estruturas relacionais de suporte

As estruturas abaixo materializam relações do COT sem criar novos conceitos tributários autônomos:

| Estrutura | Função | Constraints mínimas |
|---|---|---|
| VinculoExtremidade | Materializa ORIGEM/DESTINO de Vinculo com FK real para UE/PF/PJ. | Exatamente 2 por Vinculo; unique(vinculo_id,lado_extremidade); exatamente uma FK de endpoint preenchida. |
| ReceitaDocumentoFiscal | Materializa N:N Receita↔DocumentoFiscal. | Unique(receita_id,documento_fiscal_id); sem valor/percentual de rateio nesta versão. |
| DocumentoFiscalArquivoOrigem | Materializa N:N DocumentoFiscal↔ArquivoOrigem. | Unique(documento_fiscal_id,arquivo_origem_id,papel_arquivo quando aplicável); papel_arquivo depende de DST. |
| ConflitoDadoItem | Registra objetos/fontes participantes de um conflito. | Pertence a ConflitoDado; referência genérica é exceção controlada de auditoria. Não recebe `tenant_id` próprio — deriva sempre do `ConflitoDado` pai. |
| **ContaAcessoTenant** *(nova)* | Materializa N:N `ContaAcesso ↔ Tenant`, com `papel`. | Concessão explícita; `papel` é Enum/Ref aberto (gap DST a registrar). |
| **ContaAcessoUnidadeEconomica** *(nova)* | Materializa N:N opcional `ContaAcesso ↔ UnidadeEconomica`, com `papel`. | Quando existir ao menos uma linha para um par (ContaAcesso, Tenant), a autorização considera exclusivamente as UEs listadas — nunca ampliação implícita. |

Timestamps técnicos das estruturas associativas podem ser atendidos pelos metadados transversais (`registrado_em` etc.) na materialização física; não se criam campos locais adicionais sem novo Change Request.

## 10. Metadados transversais

Os campos MCD-F9001..F9010 (incluindo MCD-F9009 `arquivo_origem_id`) definem proveniência, temporalidade técnica, processamento e qualidade. Eles não precisam ser replicados fisicamente em todas as tabelas; o ADR poderá usar envelope, composição ou tabela de lineage.

- `sistema_origem` + `identificador_origem` sustentam idempotência e rastreabilidade.
- `arquivo_origem_id` liga fatos/objetos à evidência RAW quando aplicável; relações documentais específicas podem usar DocumentoFiscalArquivoOrigem.
- `correlation_id` correlaciona ingestão, transformação, evento e cálculo.
- `registrado_em`, `importado_em`, `data_fato` e `competencia` representam tempos diferentes.
- `status_processamento_dado` representa workflow/lifecycle: importação, validação, reconciliação, override, supersession e cancelamento.
- `status_qualidade_dado` representa qualidade/condição de uso independente do lifecycle.
- Um fato pode estar VALIDADO no processamento e, ainda assim, ter qualidade INCOMPLETA ou DIVERGENTE; os eixos não devem ser colapsados.

### 10.1 Metadados transversais de segurança/contexto *(novo, `SEC-CHANGE-REQUEST-001` V1.1)*

Os campos `MCD-F10002..F10005` (§8) formam uma segunda família de metadados transversais,
**estruturalmente análoga** a `MCD-F9001..F9010`, mas **semanticamente distinta e independente**
— nenhum dos dois grupos deve ser interpretado como extensão do outro:

- `MCD-F10002` (`tenant_id` raiz) e `MCD-F10003` (`tenant_id` transversal) respondem "a qual
  fronteira de isolamento este registro pertence" — nunca "de onde este dado veio"
  (`MCD-F9001`/`F9002`) nem "quando foi registrado" (`MCD-F9007`).
- `MCD-F10004` (`unidade_economica_id` transversal) responde "sob qual contexto
  econômico/tributário este fato é administrado" — um eixo novo, adicional ao titular tributário
  PF/PJ já existente (`MCD-F3010`/`F3011` etc.), nunca um substituto dele.
- `MCD-F10005` (`papel`) é aberto (Enum/Ref) e não fechado por esta versão — mesmo tratamento já
  dado a `tipo_vinculo`/`papel_vinculo`/demais Enum/Ref abertos do catálogo.
- Nenhum destes quatro campos altera o comportamento ou a obrigatoriedade de `MCD-F9001..F9010`
  nos objetos onde ambas as famílias coexistem (ex.: `DocumentoFiscal` passa a ter tanto os
  metadados de proveniência `F9001..F9004`/`F9010` quanto o novo `MCD-F10004`, sem nenhuma
  interação entre eles).

## 11. Relacionamentos estruturais V1.3

| Relação | Implementação canônica mínima |
|---|---|
| UE/PF/PJ | Via Vinculo + duas VinculoExtremidade; sem FK direta UE em PF/PJ. |
| Titular → Receita | Receita.pessoa_fisica_id XOR Receita.pessoa_juridica_id. |
| FontePagadora → Receita | Receita.fonte_pagadora_id. |
| Receita ↔ DocumentoFiscal | ReceitaDocumentoFiscal N:N. |
| DocumentoFiscal ↔ ArquivoOrigem | DocumentoFiscalArquivoOrigem N:N. |
| Receita → EqHop | ClassificacaoEquiparacaoHospitalar.receita_id. |
| PF → Contribuição | ContribuicaoPrevidenciaria.pessoa_fisica_id. |
| VinculoPrevidenciario → Contribuição | ContribuicaoPrevidenciaria.vinculo_previdenciario_id. |
| PF → EventoIRPF | EventoIRPF.pessoa_fisica_id. |
| FontePagadora → EventoIRPF | EventoIRPF.fonte_pagadora_id. |
| UE → Cenário | CenarioTributario.unidade_economica_id. |
| Cenário → Resultado | ResultadoCalculo.cenario_tributario_id quando aplicável. |
| ConflitoDado → participantes | ConflitoDadoItem N:1 com referências controladas aos participantes/fontes. |
| **UnidadeEconomica → Tenant** *(nova)* | UnidadeEconomica.tenant_id (`MCD-F10002`), sempre presente. |
| **Receita/ContribuicaoPrevidenciaria/VinculoPrevidenciario/EventoIRPF/DocumentoFiscal/ResultadoCalculo → UnidadeEconomica** *(nova)* | `<objeto>.unidade_economica_id` (`MCD-F10004`), sempre presente — contexto de apuração, distinto do titular tributário. |
| **ArquivoOrigem/ConflitoDado/RevisaoTecnica → Tenant** *(nova)* | `<objeto>.tenant_id` (`MCD-F10003`), sempre presente — metadado transversal de segurança. |
| **ConflitoDadoItem → tenant** *(nova, sem campo)* | Derivado exclusivamente via ConflitoDadoItem.conflito_dado_id → ConflitoDado.tenant_id; nenhuma coluna própria. |
| **ContaAcesso ↔ Tenant** *(nova)* | Via ContaAcessoTenant, com `papel` (`MCD-F10005`). |
| **ContaAcesso ↔ UnidadeEconomica** *(nova)* | Via ContaAcessoUnidadeEconomica opcional, com `papel` (`MCD-F10005`) — restringe, nunca amplia ou substitui a concessão de Tenant. |

## 12. Constraints canônicas obrigatórias para o ADR físico

- Receita: exatamente uma entre pessoa_fisica_id e pessoa_juridica_id deve estar preenchida.
- VinculoExtremidade: exatamente uma entre unidade_economica_id, pessoa_fisica_id e pessoa_juridica_id deve estar preenchida.
- Vinculo: exatamente uma extremidade ORIGEM e uma DESTINO.
- ReceitaDocumentoFiscal: o par receita_id + documento_fiscal_id é único.
- DocumentoFiscalArquivoOrigem: evitar duplicação da mesma associação/evidência.
- ClassificacaoEquiparacaoHospitalar.id é PK própria; versões anteriores não são sobrescritas de forma destrutiva.
- IDs aposentados de versões anteriores não podem ser reaproveitados.
- **`ResultadoCalculo.unidade_economica_id` e `ResultadoCalculo.cenario_tributario_id` não são mutuamente exclusivos** — quando ambos presentes, devem ser consistentes entre si (o `unidade_economica_id` do resultado deve corresponder ao `unidade_economica_id` do cenário relacionado). Nenhum XOR entre os dois.
- **Estrutura necessária para uma futura FK composta `(unidade_economica_id, tenant_id) →
  unidade_economica(id, tenant_id)`**: as relações `UnidadeEconomica → Tenant` e `<fato> →
  UnidadeEconomica` (§11) devem existir fisicamente para viabilizar essa decisão — **a forma
  física definitiva (FK composta, trigger, chave candidata `UNIQUE(id, tenant_id)` em
  `UnidadeEconomica`, ou outro mecanismo) permanece responsabilidade exclusiva do ADR**, não
  decidida nem implementada por este MCD.
- **Autorização por `UnidadeEconomica` restringe, nunca amplia, substitui ou cria acesso implícito
  a outras UEs do mesmo tenant** — invariante a materializar na camada de autorização/ADR.

## 13. Fatos, documentos e resultados

- Receita, ContribuicaoPrevidenciaria e EventoIRPF são fatos canônicos. **Todos os três, mais
  VinculoPrevidenciario, DocumentoFiscal e ResultadoCalculo, agora também carregam contexto de
  apuração explícito em UnidadeEconomica (`MCD-F10004`), distinto do titular tributário.**
- DocumentoFiscal e ArquivoOrigem são evidências/documentos e não substituem fatos normalizados.
- ClassificacaoEquiparacaoHospitalar e ResultadoCalculo são resultados derivados versionados.
- CenarioTributario é sandbox de planejamento e nunca altera fatos oficiais.
- ConflitoDado, ConflitoDadoItem e RevisaoTecnica preservam reconciliação e decisões human-in-the-loop. **ConflitoDado e RevisaoTecnica agora também carregam `tenant_id` transversal (`MCD-F10003`); ConflitoDadoItem permanece sem campo próprio, derivando do pai.**

## 14. Equiparação Hospitalar

Inalterado em relação à V1.2 — ver seção correspondente da versão anterior.

## 15. Conflito, revisão e polimorfismo controlado

- Ownership financeiro central não utiliza referência polimórfica sem FK.
- ConflitoDadoItem.objeto_id + tipo_objeto é exceção deliberada por pertencer à auditoria/reconciliação.
- O ADR físico deve documentar como essa referência genérica será validada pela aplicação e auditada.
- RevisaoTecnica continua sem identidade de revisor nesta versão; isso permanece bloqueado por `OBS-001` (`SEC-001` já aprovado, mas não substitui `OBS-001`).
- Objeto revisado continua genericamente referenciado até decisão específica de `OBS-001`; essa exceção não autoriza repetir o padrão em fatos financeiros.
- **A referência polimórfica de `ConflitoDadoItem`/`RevisaoTecnica` nunca é usada para derivar `tenant_id` — o novo `MCD-F10003` é carimbado pelo processo operacional, exatamente para evitar esse acoplamento (`SEC-001` §6, §9).**

## 16. IRPF/Carnê-Leão e Previdenciário

Inalterado em relação à V1.2 — ver seção correspondente da versão anterior. `VinculoPrevidenciario` e `ContribuicaoPrevidenciaria` ganham `unidade_economica_id` (`MCD-F10004`), sem alteração de nenhuma regra previdenciária já vigente.

## 17. Autenticação e domínio SEC

- ContaAcesso e CredencialAcesso permanecem objetos conceituais do COT.
- **`Tenant` e `EventoAuditoriaSeguranca` são incorporados como objetos canônicos** (`COT-OBJ-019`/`020`), com apenas os campos mínimos necessários (`MCD-F10001`, `MCD-F10006`) — detalhamento completo aguarda Change Request específico.
- Esta V1.3 não define e-mail de login, senha, hash, MFA, sessão ou campos de credencial completos.
- **`Sessao` permanece `SEGURANCA_OPERACIONAL`** — não é objeto canônico; sua forma concreta depende do provedor de autenticação a ser escolhido.
- **`PapelAcesso` e `Permissao` permanecem `DIFERIDO`** — não são objetos canônicos nesta versão; o campo `papel` (`MCD-F10005`, aberto) nas associações de acesso resolve os cenários hoje conhecidos.
- PessoaFisica pode existir sem ContaAcesso; conta técnica pode existir sem representar contribuinte.
- O schema de autenticação completo continua bloqueado até Change Request específico.

## 18. Migração conceitual V1.2 → V1.3

| ID/campo | Ação | Resultado V1.3 |
|---|---|---|
| MCD-F10001 | ADICIONADO | `Tenant.id`. |
| MCD-F10002 | ADICIONADO | `UnidadeEconomica.tenant_id` (âncora raiz). |
| MCD-F10003 | ADICIONADO | `tenant_id` transversal em `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`. |
| MCD-F10004 | ADICIONADO | `unidade_economica_id` transversal em `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`, `ResultadoCalculo`. |
| MCD-F10005 | ADICIONADO | `papel` (aberto) em `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`. |
| MCD-F10006 | ADICIONADO | `EventoAuditoriaSeguranca.id`. |

**Nenhum campo da V1.2 foi removido, renomeado ou reaproveitado.** Os 139 campos canônicos da
V1.2 permanecem idênticos; a V1.3 soma exatamente 6 novos IDs, totalizando **145 campos
canônicos**.

## 19. Sincronizações obrigatórias em CDC e DST

Antes de qualquer schema físico, devem ser publicados (ordem oficial definida em
`SEC-CHANGE-REQUEST-001` V1.1):

1. **DST-001 V1.3** — registrar o novo gap semântico de `papel` (Enum/Ref aberto, não fechado);
   nenhum outro vocabulário novo é necessário (os demais campos desta V1.3 são FK/UUID, não enum).
2. **CDC-001 V1.3** — contratos (direção, obrigatoriedade, mutabilidade) para os 6 novos campos e
   para `Tenant`/`EventoAuditoriaSeguranca`.
3. **Reconciliação** — auditoria cruzada COT × MCD × CDC × DST antes do ADR.
4. **ADR físico** (novo `ADR-002`) — decisões físicas, incluindo a FK composta
   `(unidade_economica_id, tenant_id)`, a chave candidata `UNIQUE(id, tenant_id)` em
   `UnidadeEconomica`, e a estratégia de RLS conceitual.

O catálogo de `papel_arquivo`, `tipo_objeto`/`papel_no_conflito`, `papel` e demais gaps continua aberto quando não houver enum aprovado; código não deve inventar união fechada.

## 20. Regras para TypeScript, APIs e Prisma

Inalteradas em relação à V1.2 — ver seção correspondente da versão anterior. Nenhuma migration pode ser criada até CDC/DST V1.3 e ADR físico serem aprovados.

## 21. Política para Claude Code

```yaml
mcd_policy:
  version: 1.3
  source_of_truth: docs/MCD-001_CONTIFISC_Modelo_Canonico_de_Dados_V1.3.md
  supersedes: MCD-001-v1.2
  incorporates:
    - MCD-CHANGE-REQUEST-001
    - MCD-CHANGE-REQUEST-002
    - SEC-CHANGE-REQUEST-001-v1.1
  naming:
    style: snake_case
    language: pt-BR-canonical
    type_prefixes: prohibited
    primary_key: id
    foreign_key: <objeto>_id
  competence:
    contract_format: YYYY-MM
    fake_first_day_date: prohibited
  relational_integrity:
    receita_owner: xor_pf_pj
    vinculo_endpoints: vinculo_extremidade_with_real_fks
    receita_documento_fiscal: explicit_many_to_many
    documento_arquivo_origem: explicit_many_to_many
    resultado_calculo_ue_cenario: consistent_not_xor
  data_state:
    processing_field: status_processamento_dado
    quality_field: status_qualidade_dado
    collapse_axes: prohibited
  tenant_model:
    tenant_id_root: unidade_economica.tenant_id
    tenant_id_transversal: [arquivo_origem, conflito_dado, revisao_tecnica]
    unidade_economica_id_transversal: [receita, contribuicao_previdenciaria, vinculo_previdenciario, evento_irpf, documento_fiscal, resultado_calculo]
    conflito_dado_item_tenant: derived_from_parent
    tenant_id_root_and_transversal_share_id: false
    tenant_equals_unidade_economica: false
    tenant_equals_pessoa_fisica_ou_juridica: false
    cliente_organizacao_object: not_created
    papel_acesso_permissao_objects: deferred
    sessao_object: security_operational_not_canonical
  allow_new_field_without_mcd: false
  allow_new_object_without_cot: false
  allow_erp_field_names_in_domain: false
  allow_auth_fields_in_pessoa_fisica: false
  create_prisma_schema_now: false
  create_migration_now: false
  implement_rls_now: false
  implement_composite_fk_now: false
  money_type: decimal
  ids: uuid
  preserve_provenance: true
  preserve_history: true
  derived_overwrites_fact: false
  vendor_specific_domain_model: false
```

## 22. O que está liberado após V1.3

- Manter e evoluir a infraestrutura genérica concluída na Fase 1.
- Usar UnidadeEconomica, PessoaFisica e PessoaJuridica já implementadas, sem alteração de nomes.
- Preparar DST-001 V1.3 (registro do gap de `papel`) e CDC-001 V1.3 (contratos dos novos campos/objetos).
- Preparar ADR de schema físico de segurança/tenant somente depois das sincronizações documentais.
- Preparar proposta de Prisma após o ADR, sem executar migration até aprovação.
- Não implementar autenticação real, RLS ou FK composta antes do ADR físico aprovado.
- Não implementar lógica tributária antes do RGT aplicável.

## 23. Gaps remanescentes

| Gap | Tema | Tratamento |
|---|---|---|
| GAP-MCD-CR2-001 | VinculoExtremidade e COT | Resolvido — já registrado no COT desde a V1.1. |
| GAP-MCD-CR2-002 | DocumentoFiscalArquivoOrigem.papel_arquivo | Catálogo DST pendente; não criar enum fechado. |
| GAP-MCD-CR2-003 | ConflitoDadoItem.tipo_objeto/papel_no_conflito | Catálogos dependem de OBS/reconciliação. |
| GAP-MCD-CR2-004 | Revisor de RevisaoTecnica | Aguardar `OBS-001` (SEC-001 já aprovado, não substitui OBS-001). |
| GAP-MCD-CR2-005 | FontePagadora.identificador_fiscal | Validação tipada CPF/CNPJ/Exterior fica para revisão posterior; não bloqueia ADR inicial. |
| **GAP-SEC-CR1-001** *(novo)* | Vocabulário de `papel` (`MCD-F10005`) | Enum/Ref aberto; catálogo de papéis não aprovado; não fechar por inferência. |
| **GAP-SEC-CR1-002** *(novo)* | `Vinculo` sem nenhuma extremidade `UnidadeEconomica` | Condicionado ao fechamento futuro de `DST-GAP-003` (`tipo_vinculo`); ambas as ramificações identificadas são seguras. |
| **GAP-SEC-CR1-003** *(novo)* | `ResultadoCalculo` sem `UnidadeEconomica` nem `CenarioTributario` simultaneamente | Cenário "resultado técnico/global sem UE" não confirmado nem descartado; se existir, exigirá revisão futura de obrigatoriedade. |
| **GAP-SEC-CR1-004** *(novo)* | Detalhamento completo de `Tenant`, `EventoAuditoriaSeguranca`, `ContaAcesso`, `CredencialAcesso` | Aguarda Change Request específico de autenticação/RBAC. |

## 24. Critérios de aceite da V1.3

- [x] Todos os critérios da V1.2 permanecem satisfeitos (nomenclatura, competência, titularidade, VinculoExtremidade, associações N:N, EqHop, ConflitoDado, separação processamento/qualidade, autenticação separada, modelo vendor-neutral).
- [x] `Tenant` incorporado com campo mínimo (`MCD-F10001`).
- [x] `EventoAuditoriaSeguranca` incorporado com campo mínimo (`MCD-F10006`).
- [x] `UnidadeEconomica.tenant_id` (`MCD-F10002`) distinto do `tenant_id` transversal (`MCD-F10003`) — dois IDs, não um.
- [x] `unidade_economica_id` transversal (`MCD-F10004`) incorporado nos 6 fatos aprovados.
- [x] `ConflitoDadoItem` preservado sem `tenant_id` próprio.
- [x] `ResultadoCalculo` preservado sem XOR entre `unidade_economica_id` e `cenario_tributario_id`.
- [x] Campo `papel` (`MCD-F10005`) incorporado como Enum/Ref aberto — nenhum enum criado, nenhum gap DST fechado por inferência.
- [x] Nenhum campo da V1.2 removido, renomeado ou reaproveitado.
- [x] 145 campos totais (139 + 6), sem duplicação de ID.
- [x] Nenhuma FK composta implementada — apenas a estrutura relacional necessária registrada para o ADR.
- [x] Nenhuma modelagem física de RLS antecipada.

**Ainda não constitui autorização para migration:**
- [ ] CDC-001 V1.3 publicado e aprovado.
- [ ] DST-001 V1.3 publicado e aprovado (registro do gap de `papel`).
- [ ] ADR físico (novo `ADR-002`) aprovado com FK composta/chave candidata, RLS conceitual, e demais decisões físicas.

## 25. Próximos documentos

1. **DST-001 V1.3** — registro do gap semântico de `papel`.
2. **CDC-001 V1.3** — sincronização contratual com o MCD V1.3.
3. **Reconciliação** — auditoria cruzada COT × MCD × CDC × DST.
4. **ADR-002** — schema físico de segurança/tenant (FK composta, RLS conceitual, impacto Prisma).
5. Change Request específico de autenticação/RBAC (detalhamento completo de `Tenant`,
   `EventoAuditoriaSeguranca`, `ContaAcesso`, `CredencialAcesso`, `PapelAcesso`/`Permissao` se um
   requisito concreto surgir).
6. RGT-001, EVT-001, INT-001 conforme a sequência de governança já estabelecida.

---

**Decisão de governança:** MCD-001 V1.3 é a baseline canônica vigente. MCD-001 V1.2, V1.1 e V1.0 permanecem apenas como histórico `SUPERSEDED`. O schema físico continua bloqueado até CDC/DST V1.3 e o novo ADR de segurança/tenant serem aprovados.
