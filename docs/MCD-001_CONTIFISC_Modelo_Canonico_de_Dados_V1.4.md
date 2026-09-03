# MCD-001 — Modelo Canônico de Dados da CONTIFISC

**Versão:** 1.4  
**Status:** APROVADO — correção normativa coordenada com CDC-001 V1.4, restrita aos 2 achados
`RELEVANTE` de `SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`  
**Supersede:** MCD-001 V1.3  
**Incorpora:** MCD-CHANGE-REQUEST-001, MCD-CHANGE-REQUEST-002 V1.0, `SEC-CHANGE-REQUEST-001` V1.1
(todos APROVADOS), e a correção de `SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`  
**Dependências:** CAF-001, COT-001 V1.2, CDC-001 V1.4, DST-001 V1.3, `SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`  
**Escopo:** CONTIFISC Intelligence Platform — profissionais da saúde

> **Princípio central:** o MCD define a representação canônica dos dados. O schema físico, ORM, banco, ERP e interfaces são implementações/integrações subordinadas ao modelo; nunca são sua fonte de verdade.

## 1. Objetivo

Corrigir, de forma coordenada com `CDC-001` V1.4, exclusivamente os **2 achados `RELEVANTE`**
identificados em `SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`:

1. **Ausência de representação MCD mínima de `ContaAcesso`, `ContaAcessoTenant` e
   `ContaAcessoUnidadeEconomica`** — impedia schema físico válido para essas estruturas.
2. **Divergência de mutabilidade em `MCD-F10004`** entre este documento (`Imutável`) e
   `CDC-001` V1.3 (`versioned`).

Nenhuma outra alteração é feita. A V1.4 preserva integralmente os **145 campos canônicos** da
V1.3 e adiciona **6 novos campos** (`MCD-F10007..F10012`), além de corrigir a política de
mutabilidade de `MCD-F10004` (não seu significado, cardinalidade ou obrigatoriedade, que
permanecem inalterados).

## 2. Governança e versionamento

- Esta V1.4 substitui integralmente o MCD-001 V1.3 para código novo.
- Os IDs de campos removidos ficam aposentados e não podem ser reutilizados com outro significado.
- Nenhum campo, objeto ou ID da V1.3 é removido ou renomeado por esta versão. A correção de
  política de `MCD-F10004` é a única alteração de um valor já existente — documentada
  explicitamente em §8.1, não uma remoção/renomeação.
- A publicação como V1.4 é uma exceção pré-implementação aprovada: ainda não existe
  migration/schema de produção.
- A Fase 1 já implementada para UnidadeEconomica, PessoaFisica e PessoaJuridica permanece válida.

## 3. Decisões arquiteturais da baseline V1.4

Todas as decisões da V1.3 (§3 da versão anterior) permanecem vigentes e não são repetidas aqui.
Decisões adicionadas por esta V1.4 (ambas restritas ao escopo da correção, sem introduzir
arquitetura nova):

- **`ContaAcesso` ganha uma representação MCD mínima (`id`)** — apenas o necessário para
  identidade persistente e participação como FK nas duas associações de acesso. **Nenhum atributo
  de mecanismo de autenticação é antecipado** (sem senha, hash, OAuth, refresh token, MFA físico,
  sessão ou campo de implementação de provedor) — todos permanecem diferidos até Change Request
  específico de autenticação/RBAC, exatamente como já vigorava.
- **`ContaAcessoTenant` e `ContaAcessoUnidadeEconomica` ganham identidade própria (`id`) e as FKs
  estruturais necessárias** (`conta_acesso_id` transversal aos dois; `tenant_id` próprio de
  `ContaAcessoTenant`; `unidade_economica_id` próprio de `ContaAcessoUnidadeEconomica`) — sem as
  quais as duas associações não eram fisicamente persistíveis.
- **`CredencialAcesso` permanece sem nenhum campo MCD** — a nova representação mínima de
  `ContaAcesso` não cria nenhuma necessidade estrutural para `CredencialAcesso` nesta etapa;
  continua explicitamente diferido até Change Request de autenticação/RBAC.
- **`MCD-F10004` (`unidade_economica_id` transversal) passa a ter política de mutabilidade
  explicitamente diferenciada por hospedeiro** (§8.1) — `Versionado` em 5 hospedeiros,
  `Imutável` em `ResultadoCalculo` — corrigindo a divergência com `CDC-001` V1.3 através de
  análise semântica, não de escolha arbitrária para fazer os documentos coincidirem.
- **Vigência/status das duas associações de acesso permanecem fora de escopo** — mencionados na
  descrição textual de `COT-SUP-005` (`COT-001` V1.2 §4), mas nunca aprovados por nenhum Change
  Request; não incorporados por esta versão (ver `GAP-CDC-1.4-001` em `CDC-001` V1.4).
- **Timestamps das duas associações não recebem campo MCD dedicado** — cobertos pelo mecanismo já
  estabelecido em §9 (metadados transversais na materialização física), sem necessidade de novo
  Change Request.

## 4. Convenção de nomenclatura V1.4

Inalterada em relação à V1.3.

## 5. Tipos canônicos

Inalterados em relação à V1.3 — nenhum tipo novo foi necessário (todos os 6 novos campos são
`UUID`/FK).

## 6. Nulidade e estados especiais

Inalterado em relação à V1.3.

## 7. Domínios canônicos

Inalterado em relação à V1.3 — ver tabela da versão anterior (`DOM-CORE` a `DOM-SEC`).

## 8. Catálogo canônico V1.4 (151 campos)

A coluna `Obrig. base` representa o requisito estrutural mínimo. O CDC continua soberano para
obrigatoriedade por operação. `XOR` significa que o grupo indicado deve satisfazer exclusividade
lógica conforme a seção de constraints.

**Os 145 campos das seções DOM-CORE a DOM-SEC abaixo são idênticos à V1.3, com uma única exceção
pontual: a política (última coluna) de `MCD-F10004` mudou de um valor único `Imutável` para uma
referência à nota §8.1, que substitui esse valor por uma política diferenciada por hospedeiro
(ver §8.1). Nenhum outro campo, nome, tipo, obrigatoriedade ou hospedeiro foi alterado.**
Reproduzidos integralmente para preservar a integridade do catálogo em um único documento.

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

### DOM-SEC — Segurança *(12 campos: 6 da V1.3, inalterados exceto política de F10004; 6 novos nesta V1.4)*

Campos introduzidos por `SEC-CHANGE-REQUEST-001` V1.1 (`MCD-F10001..F10006`) e pela correção
`SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md` (`MCD-F10007..F10012`, nesta V1.4). Alguns são
**transversais** — a coluna "Objeto(s)" indica onde cada um se materializa. **Nenhum destes campos
reutiliza um ID `MCD-F9001..F9010`.**

| ID | Campo | Significado | Tipo | Objeto(s) | Origem típica | Obrig. base | Política |
|---|---|---|---|---|---|---|---|
| MCD-F10001 | id | Identificador do Tenant | UUID | Tenant | Sistema | Sim | Imutável |
| MCD-F10002 | tenant_id | Tenant ao qual a Unidade Econômica pertence (âncora raiz do isolamento) | UUID/FK | UnidadeEconomica | Sistema/Cadastro | Sim | Imutável |
| MCD-F10003 | tenant_id | Tenant responsável pelo registro — metadado transversal de segurança, carimbado pelo processo/sessão que cria o registro; nunca derivado do objeto polimórfico referenciado | UUID/FK | ArquivoOrigem, ConflitoDado, RevisaoTecnica | Gateway/Reconciliação/Revisor | Sim | Imutável |
| MCD-F10004 | unidade_economica_id | Contexto econômico/tributário de apuração do fato — distinto do titular tributário PF/PJ já existente | UUID/FK | Receita, ContribuicaoPrevidenciaria, VinculoPrevidenciario, EventoIRPF, DocumentoFiscal, ResultadoCalculo | Sistema/Lançamento | Sim | **Ver §8.1** *(corrigido nesta versão — era `Imutável` uniforme na V1.3)* |
| MCD-F10005 | papel | Papel/perfil da concessão de acesso | Enum/Ref | ContaAcessoTenant, ContaAcessoUnidadeEconomica | Concessão de acesso | Sim | Versionado |
| MCD-F10006 | id | Identificador do Evento de Auditoria de Segurança | UUID | EventoAuditoriaSeguranca | Sistema | Sim | Imutável |
| **MCD-F10007** *(novo)* | id | Identificador da Conta de Acesso | UUID | ContaAcesso | Sistema | Sim | Imutável |
| **MCD-F10008** *(novo)* | conta_acesso_id | Conta de Acesso à qual a concessão de Tenant ou a restrição de Unidade Econômica se refere — mesmo papel semântico em ambos os hospedeiros | UUID/FK | ContaAcessoTenant, ContaAcessoUnidadeEconomica | Concessão de acesso | Sim | Imutável |
| **MCD-F10009** *(novo)* | id | Identificador da concessão Conta de Acesso × Tenant | UUID | ContaAcessoTenant | Sistema | Sim | Imutável |
| **MCD-F10010** *(novo)* | tenant_id | Tenant ao qual o acesso é concedido — papel de concessão explícita, distinto do tenant raiz (`MCD-F10002`) e do tenant transversal operacional (`MCD-F10003`) | UUID/FK | ContaAcessoTenant | Concessão de acesso | Sim | Imutável |
| **MCD-F10011** *(novo)* | id | Identificador da restrição Conta de Acesso × Unidade Econômica | UUID | ContaAcessoUnidadeEconomica | Sistema | Sim | Imutável |
| **MCD-F10012** *(novo)* | unidade_economica_id | Unidade Econômica à qual o acesso é restringido — papel de restrição explícita, distinto do contexto de apuração transversal (`MCD-F10004`) | UUID/FK | ContaAcessoUnidadeEconomica | Concessão de acesso | Sim | Imutável |

**Por que `MCD-F10008` é um único ID transversal para 2 hospedeiros:** `conta_acesso_id`
responde exatamente à mesma pergunta em `ContaAcessoTenant` e `ContaAcessoUnidadeEconomica` —
"a qual Conta de Acesso esta concessão/restrição se refere" — sem nenhuma variação de papel entre
os dois hospedeiros. Mesmo precedente já usado para `MCD-F10004` (uma pergunta idêntica em 6
hospedeiros) e para `registrado_em`/`MCD-F9007` (uma pergunta idêntica em 16 objetos).

**Por que `MCD-F10009`/`MCD-F10011` (identidade própria de cada associação) e
`MCD-F10010`/`MCD-F10012` (FKs de concessão/restrição) são IDs distintos, não reaproveitados de
`MCD-F10002`/`MCD-F10003`/`MCD-F10004`:** cada `id` de estrutura de suporte já é, por precedente
uniforme no catálogo, específico do seu hospedeiro (`MCD-F4301` ≠ `MCD-F4401`, ambos "id de uma
associação", nunca compartilhados). O mesmo vale para `tenant_id`/`unidade_economica_id` nestas
duas associações: eles respondem "a qual Tenant/UE o acesso é concedido/restringido" — uma
pergunta de **concessão explícita**, estruturalmente diferente de "a qual fronteira de segurança
este registro pertence" (`MCD-F10002`/`F10003`) ou "sob qual UE este fato é administrado"
(`MCD-F10004`). Um `ContaAcesso` pode operacionalmente pertencer a um tenant interno da CONTIFISC
e, ainda assim, ter uma linha de `ContaAcessoTenant` concedendo acesso a um tenant de cliente
completamente diferente — os dois `tenant_id` (o de pertencimento operacional, se algum dia
existir, e o de concessão) nunca podem ser confundidos.

**Não incorporados por esta versão (permanecem diferidos, ver `CDC-001` V1.4 §11 —
`GAP-CDC-1.4-001`/`002`):**
- `ContaAcesso.tipo` (`HUMANA`/`SERVICO`, mencionado conceitualmente em `SEC-001` V1.0 §13) — não
  aprovado por nenhum Change Request; aguardando CR de autenticação/RBAC.
- Vigência/status de `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` — mencionados na descrição
  textual de `COT-SUP-005` (`COT-001` V1.2 §4), mas nunca formalmente aprovados.
- `CredencialAcesso` — nenhum campo MCD; permanece integralmente diferido.
- Detalhamento completo de `Tenant`/`EventoAuditoriaSeguranca` além dos campos mínimos já
  existentes desde a V1.3.

### 8.1 Política de mutabilidade de `MCD-F10004` — correção V1.4

A V1.3 declarava a política de `MCD-F10004` uniformemente como `Imutável` para os 6 hospedeiros.
A reconciliação cruzada (`SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md` §4/§15) encontrou que
`CDC-001` V1.3 contratava o mesmo campo como `versioned` em todos os 6 — uma contradição real
entre os dois documentos, sem cláusula que autorizasse o CDC a divergir da política de mutabilidade
declarada pelo MCD (a soberania do CDC declarada em §8 é apenas sobre **obrigatoriedade por
operação**, não sobre mutabilidade).

Esta correção resolve a contradição através de análise semântica hospedeiro a hospedeiro — não por
escolha arbitrária de um valor único para fazer os dois documentos coincidirem:

| Hospedeiro | Política | Justificativa |
|---|---|---|
| `Receita` | `Versionado` | `unidade_economica_id` representa contexto administrativo passível de correção controlada quando um lançamento é inicialmente atribuído à UE errada — mesma família de tratamento já aplicada às FKs de titularidade tributária (`pessoa_fisica_id`/`pessoa_juridica_id`, ambas `Versionado` em `MCD-F3010`/`F3011`). A correção, quando necessária, deve preferencialmente ocorrer através do mecanismo de reconciliação já existente (`ConflitoDado`/`RevisaoTecnica`) — mas fisicamente a coluna aceita `UPDATE`, não é imutável. |
| `ContribuicaoPrevidenciaria` | `Versionado` | Mesma justificativa — mesmo padrão de `pessoa_fisica_id` (`MCD-F6007`, `Versionado`). |
| `VinculoPrevidenciario` | `Versionado` | Mesma justificativa — mesmo padrão de campos relacionais deste objeto (`Temporal`/correção controlada, nunca imutável). |
| `EventoIRPF` | `Versionado` | Mesma justificativa — mesmo padrão de `pessoa_fisica_id` (`MCD-F7009`, `Versionado`). |
| `DocumentoFiscal` | `Versionado` | Consistente com a nota de timing já registrada em `DST-001` V1.3 §11.1 e `CDC-001` (`CDC-FIS-001`): o campo é atribuído de forma própria e pode precisar de correção quando a reconciliação posterior com uma `Receita` associada revelar uma UE diferente da inicialmente atribuída. |
| **`ResultadoCalculo`** | **`Imutável`** | `ResultadoCalculo` é, por desenho, um snapshot reproduzível — todos os seus demais campos (`input_snapshot_hash`, `engine_id`, `engine_version`, `rule_set_id`, `rule_set_version`, `calculado_em`) já são `Imutável`, precisamente porque qualquer mudança de entrada exige um **novo** `ResultadoCalculo` (novo `id`, novo hash), nunca uma edição do registro existente. Tratar `unidade_economica_id` de forma diferente quebraria essa garantia de reprodutibilidade. A "correção" aqui ocorre por **substituição de registro** (calcular um novo resultado), não por edição in-place. |

**Este é um caso registrado explicitamente em que os 6 hospedeiros de um campo transversal NÃO
compartilham a mesma política física de mutabilidade** — o significado semântico do campo
permanece uniforme (confirmado em `DST-001` V1.3 §11.1: mesma pergunta respondida nos 6
hospedeiros), mas a política de mutabilidade dessa resposta depende da filosofia de mutabilidade
já vigente em cada objeto hospedeiro, não do significado do campo em si. Isso **não é mascarado**
como uma política única — é documentado explicitamente como a exceção do campo transversal, no
mesmo espírito da nota que já diferencia `MCD-F10002`/`MCD-F10003` apesar do nome físico comum.
`CDC-001` V1.4 aplica esta mesma divisão de política de forma coerente (ver `CDC-001` V1.4,
`CDC-CAL-001`).

## 9. Estruturas relacionais de suporte

As estruturas abaixo materializam relações do COT sem criar novos conceitos tributários autônomos:

| Estrutura | Função | Constraints mínimas |
|---|---|---|
| VinculoExtremidade | Materializa ORIGEM/DESTINO de Vinculo com FK real para UE/PF/PJ. | Exatamente 2 por Vinculo; unique(vinculo_id,lado_extremidade); exatamente uma FK de endpoint preenchida. |
| ReceitaDocumentoFiscal | Materializa N:N Receita↔DocumentoFiscal. | Unique(receita_id,documento_fiscal_id); sem valor/percentual de rateio nesta versão. |
| DocumentoFiscalArquivoOrigem | Materializa N:N DocumentoFiscal↔ArquivoOrigem. | Unique(documento_fiscal_id,arquivo_origem_id,papel_arquivo quando aplicável); papel_arquivo depende de DST. |
| ConflitoDadoItem | Registra objetos/fontes participantes de um conflito. | Pertence a ConflitoDado; referência genérica é exceção controlada de auditoria. Não recebe `tenant_id` próprio — deriva sempre do `ConflitoDado` pai. |
| **ContaAcessoTenant** *(estrutura completa nesta V1.4)* | Materializa N:N `ContaAcesso ↔ Tenant`, com identidade própria e FKs reais. | `id` (`MCD-F10009`) próprio; `conta_acesso_id` (`MCD-F10008`, transversal) e `tenant_id` (`MCD-F10010`, próprio) obrigatórios; `papel` (`MCD-F10005`) Enum/Ref aberto; unicidade lógica de `(conta_acesso_id, tenant_id)` — ver `CDC-001` V1.4 `CDC-REL-SEC-005`, forma física a cargo do ADR. |
| **ContaAcessoUnidadeEconomica** *(estrutura completa nesta V1.4)* | Materializa N:N opcional `ContaAcesso ↔ UnidadeEconomica`, com identidade própria e FKs reais. | `id` (`MCD-F10011`) próprio; `conta_acesso_id` (`MCD-F10008`, transversal) e `unidade_economica_id` (`MCD-F10012`, próprio) obrigatórios; `papel` (`MCD-F10005`); unicidade lógica de `(conta_acesso_id, unidade_economica_id)` — ver `CDC-001` V1.4 `CDC-REL-SEC-006`; pressupõe uma linha de `ContaAcessoTenant` para o mesmo par (`ContaAcesso`, Tenant-da-UE) — ver `CDC-REL-SEC-007`. Quando existir ao menos uma linha para um par (ContaAcesso, Tenant), a autorização considera exclusivamente as UEs listadas — nunca ampliação implícita. |

Timestamps técnicos das estruturas associativas (incluindo as duas acima) podem ser atendidos
pelos metadados transversais (`registrado_em` etc.) na materialização física; não se criam campos
locais adicionais sem novo Change Request.

## 10. Metadados transversais

Inalterado em relação à V1.3.

### 10.1 Metadados transversais de segurança/contexto

Os campos `MCD-F10002..F10005` (§8) formam uma segunda família de metadados transversais,
**estruturalmente análoga** a `MCD-F9001..F9010`, mas **semanticamente distinta e independente**
— nenhum dos dois grupos deve ser interpretado como extensão do outro (inalterado da V1.3).

**Nota adicionada nesta V1.4:** `MCD-F10008` (`conta_acesso_id`), `MCD-F10009`/`MCD-F10010`
(identidade e tenant de concessão de `ContaAcessoTenant`) e `MCD-F10011`/`MCD-F10012` (identidade
e UE de restrição de `ContaAcessoUnidadeEconomica`) formam uma **terceira sub-família**, específica
das duas associações de acesso — respondem "quem recebeu o quê" (concessão/restrição), uma
pergunta estruturalmente diferente de "a qual fronteira este registro pertence" (`F10002`/`F10003`)
ou "sob qual UE este fato é administrado" (`F10004`). `MCD-F10007` (`ContaAcesso.id`) não é
transversal — é a identidade própria do objeto `ContaAcesso`, mesmo padrão de qualquer outro `id`
de objeto do catálogo.

## 11. Relacionamentos estruturais V1.4

Idêntico à V1.3, com uma linha detalhada nesta versão:

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
| UnidadeEconomica → Tenant | UnidadeEconomica.tenant_id (`MCD-F10002`), sempre presente. |
| Receita/ContribuicaoPrevidenciaria/VinculoPrevidenciario/EventoIRPF/DocumentoFiscal/ResultadoCalculo → UnidadeEconomica | `<objeto>.unidade_economica_id` (`MCD-F10004`), sempre presente — política de mutabilidade diferenciada por hospedeiro (§8.1). |
| ArquivoOrigem/ConflitoDado/RevisaoTecnica → Tenant | `<objeto>.tenant_id` (`MCD-F10003`), sempre presente. |
| ConflitoDadoItem → tenant | Derivado exclusivamente via ConflitoDadoItem.conflito_dado_id → ConflitoDado.tenant_id; nenhuma coluna própria. |
| **`ContaAcesso ↔ Tenant`** *(completa nesta versão)* | Via `ContaAcessoTenant`: `id` (`MCD-F10009`), `conta_acesso_id` (`MCD-F10008`) → `ContaAcesso.id` (`MCD-F10007`), `tenant_id` (`MCD-F10010`) → `Tenant.id` (`MCD-F10001`), `papel` (`MCD-F10005`). |
| **`ContaAcesso ↔ UnidadeEconomica`** *(completa nesta versão)* | Via `ContaAcessoUnidadeEconomica`: `id` (`MCD-F10011`), `conta_acesso_id` (`MCD-F10008`) → `ContaAcesso.id`, `unidade_economica_id` (`MCD-F10012`) → `UnidadeEconomica.id`, `papel` (`MCD-F10005`) — restringe, nunca amplia ou substitui a concessão de Tenant. |

## 12. Constraints canônicas obrigatórias para o ADR físico

Idêntico à V1.3, mais os invariantes das duas associações de acesso, agora estruturalmente
completas:

- Receita: exatamente uma entre pessoa_fisica_id e pessoa_juridica_id deve estar preenchida.
- VinculoExtremidade: exatamente uma entre unidade_economica_id, pessoa_fisica_id e pessoa_juridica_id deve estar preenchida.
- Vinculo: exatamente uma extremidade ORIGEM e uma DESTINO.
- ReceitaDocumentoFiscal: o par receita_id + documento_fiscal_id é único.
- DocumentoFiscalArquivoOrigem: evitar duplicação da mesma associação/evidência.
- ClassificacaoEquiparacaoHospitalar.id é PK própria; versões anteriores não são sobrescritas de forma destrutiva.
- IDs aposentados de versões anteriores não podem ser reaproveitados.
- `ResultadoCalculo.unidade_economica_id` e `ResultadoCalculo.cenario_tributario_id` não são mutuamente exclusivos — quando ambos presentes, devem ser consistentes entre si. Nenhum XOR entre os dois.
- Estrutura necessária para uma futura FK composta `(unidade_economica_id, tenant_id) → unidade_economica(id, tenant_id)` — forma física definitiva a cargo do ADR.
- Autorização por `UnidadeEconomica` restringe, nunca amplia, substitui ou cria acesso implícito a outras UEs do mesmo tenant.
- **`ContaAcessoTenant`** *(novo)*: unicidade lógica de `(conta_acesso_id, tenant_id)` — no máximo uma concessão por par; forma física (constraint `UNIQUE`) a cargo do ADR.
- **`ContaAcessoUnidadeEconomica`** *(novo)*: unicidade lógica de `(conta_acesso_id, unidade_economica_id)` — no máximo uma restrição por par; forma física a cargo do ADR. Adicionalmente, toda linha desta associação pressupõe uma linha de `ContaAcessoTenant` para o mesmo par (`ContaAcesso`, Tenant-da-UE) — uma restrição sem concessão de Tenant correspondente é inválida; enforcement físico (trigger/validação de aplicação) a cargo do ADR.

## 13. Fatos, documentos e resultados

Inalterado em relação à V1.3.

## 14. Equiparação Hospitalar

Inalterado em relação à V1.3.

## 15. Conflito, revisão e polimorfismo controlado

Inalterado em relação à V1.3.

## 16. IRPF/Carnê-Leão e Previdenciário

Inalterado em relação à V1.3.

## 17. Autenticação e domínio SEC

- ContaAcesso e CredencialAcesso permanecem objetos conceituais do COT.
- `Tenant` e `EventoAuditoriaSeguranca` permanecem incorporados como objetos canônicos com os
  campos mínimos já existentes desde a V1.3 (`MCD-F10001`, `MCD-F10006`).
- **`ContaAcesso` ganha identidade mínima (`MCD-F10007`, apenas `id`) nesta V1.4** — exclusivamente
  para viabilizar as duas associações de acesso já aprovadas. Nenhum atributo de mecanismo de
  autenticação (senha, hash, OAuth, refresh token, MFA, sessão, tipo de conta) é incorporado.
- Esta V1.4 não define e-mail de login, senha, hash, MFA, sessão ou campos de credencial completos
  — exatamente como a V1.3.
- `Sessao` permanece `SEGURANCA_OPERACIONAL`. `PapelAcesso`/`Permissao` permanecem `DIFERIDO`.
- PessoaFisica pode existir sem ContaAcesso; conta técnica pode existir sem representar contribuinte.
- O schema de autenticação completo continua bloqueado até Change Request específico.

## 18. Migração conceitual V1.3 → V1.4

| ID/campo | Ação | Resultado V1.4 |
|---|---|---|
| MCD-F10004 | POLÍTICA CORRIGIDA | Passa de `Imutável` uniforme para política diferenciada por hospedeiro (§8.1) — `Versionado` em 5 hospedeiros, `Imutável` em `ResultadoCalculo`. Significado, tipo, cardinalidade e obrigatoriedade **inalterados**. |
| MCD-F10007 | ADICIONADO | `ContaAcesso.id`. |
| MCD-F10008 | ADICIONADO | `conta_acesso_id` transversal em `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`. |
| MCD-F10009 | ADICIONADO | `ContaAcessoTenant.id`. |
| MCD-F10010 | ADICIONADO | `ContaAcessoTenant.tenant_id`. |
| MCD-F10011 | ADICIONADO | `ContaAcessoUnidadeEconomica.id`. |
| MCD-F10012 | ADICIONADO | `ContaAcessoUnidadeEconomica.unidade_economica_id`. |

**Nenhum campo da V1.3 foi removido ou renomeado.** Os 145 campos canônicos da V1.3 permanecem
com nome, tipo, cardinalidade e obrigatoriedade idênticos; apenas a política de `MCD-F10004` foi
corrigida (não removida — o campo continua existindo com o mesmo significado). A V1.4 soma
exatamente 6 novos IDs, totalizando **151 campos canônicos**.

## 19. Sincronizações obrigatórias em CDC

Concluídas nesta rodada: `CDC-001` V1.4 incorpora coordenadamente as mesmas correções (ver
`SEC-CR-001_CORRECAO_MCD_CDC_V1.0.md`). Antes de qualquer schema físico, ainda são necessários:

1. **Reconciliação final** — nova verificação cruzada COT × MCD × CDC × DST confirmando que os 2
   achados `RELEVANTE` foram corrigidos e nenhuma nova inconsistência bloqueante surgiu.
2. **ADR físico** (novo `ADR-002`) — decisões físicas, incluindo a FK composta
   `(unidade_economica_id, tenant_id)`, a chave candidata `UNIQUE(id, tenant_id)` em
   `UnidadeEconomica`, as unicidades lógicas das duas associações de acesso, e a estratégia de RLS
   conceitual.

## 20. Regras para TypeScript, APIs e Prisma

Inalteradas em relação à V1.3. Nenhuma migration pode ser criada até a reconciliação final e o ADR
físico serem aprovados.

## 21. Política para Claude Code

```yaml
mcd_policy:
  version: 1.4
  source_of_truth: docs/MCD-001_CONTIFISC_Modelo_Canonico_de_Dados_V1.4.md
  supersedes: MCD-001-v1.3
  incorporates:
    - MCD-CHANGE-REQUEST-001
    - MCD-CHANGE-REQUEST-002
    - SEC-CHANGE-REQUEST-001-v1.1
    - SEC-CR-001-reconciliacao-cruzada-correcao
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
    conta_acesso_tenant_unique: [conta_acesso_id, tenant_id]
    conta_acesso_ue_unique: [conta_acesso_id, unidade_economica_id]
    conta_acesso_ue_requires_conta_acesso_tenant: true
  data_state:
    processing_field: status_processamento_dado
    quality_field: status_qualidade_dado
    collapse_axes: prohibited
  tenant_model:
    tenant_id_root: unidade_economica.tenant_id
    tenant_id_transversal: [arquivo_origem, conflito_dado, revisao_tecnica]
    unidade_economica_id_transversal: [receita, contribuicao_previdenciaria, vinculo_previdenciario, evento_irpf, documento_fiscal, resultado_calculo]
    unidade_economica_id_mutability:
      default: versioned
      resultado_calculo_override: immutable
    conflito_dado_item_tenant: derived_from_parent
    tenant_id_root_and_transversal_share_id: false
    tenant_equals_unidade_economica: false
    tenant_equals_pessoa_fisica_ou_juridica: false
    cliente_organizacao_object: not_created
    papel_acesso_permissao_objects: deferred
    sessao_object: security_operational_not_canonical
    conta_acesso_minimal_id_only: true
    conta_acesso_auth_fields: deferred
    credencial_acesso_fields: deferred
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

## 22. O que está liberado após V1.4

- Manter e evoluir a infraestrutura genérica concluída na Fase 1.
- Usar UnidadeEconomica, PessoaFisica e PessoaJuridica já implementadas, sem alteração de nomes.
- Preparar a reconciliação final (COT × MCD × CDC × DST) confirmando a correção dos 2 achados
  `RELEVANTE`.
- Preparar ADR de schema físico de segurança/tenant somente depois da reconciliação final.
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
| GAP-SEC-CR1-001 | Vocabulário de `papel` (`MCD-F10005`) | Enum/Ref aberto; catálogo de papéis não aprovado; não fechar por inferência. |
| GAP-SEC-CR1-002 | `Vinculo` sem nenhuma extremidade `UnidadeEconomica` | Condicionado ao fechamento futuro de `DST-GAP-003`. |
| GAP-SEC-CR1-003 | `ResultadoCalculo` sem `UnidadeEconomica` nem `CenarioTributario` simultaneamente | **Reavaliado nesta versão à luz de §8.1** (ver `CDC-001` V1.4 §11.1 para a nota completa): a análise de mutabilidade de `ResultadoCalculo` reforça que o objeto é estruturalmente identificado por um conjunto fechado de inputs (incluindo UE) — o que é consistente com, mas não prova, que a obrigatoriedade atual esteja correta. Gap permanece aberto, não fechado por inferência; obrigatoriedade **não foi alterada**. |
| **GAP-SEC-CR1-004** *(atualizado nesta versão)* | Detalhamento completo de `Tenant`, `EventoAuditoriaSeguranca`, `ContaAcesso`, `CredencialAcesso` | **Parcialmente resolvido**: `ContaAcesso.id` (`MCD-F10007`) incorporado nesta V1.4. Permanecem diferidos: `Tenant.nome`/`status`, `EventoAuditoriaSeguranca` (ator/operação/objeto/instante/resultado), `ContaAcesso.tipo` (HUMANA/SERVICO), e todo o modelo de `CredencialAcesso` — aguardam Change Request específico de autenticação/RBAC. |

## 24. Critérios de aceite da V1.4

- [x] Todos os critérios da V1.3 permanecem satisfeitos.
- [x] `ContaAcesso` incorporado com campo mínimo (`MCD-F10007`, apenas `id`) — nenhum atributo de
  mecanismo de autenticação antecipado.
- [x] `ContaAcessoTenant` estruturalmente completo: `id`, `conta_acesso_id`, `tenant_id`, `papel`.
- [x] `ContaAcessoUnidadeEconomica` estruturalmente completo: `id`, `conta_acesso_id`,
  `unidade_economica_id`, `papel`.
- [x] `CredencialAcesso` permanece sem nenhum campo — verificado que a mudança em `ContaAcesso`
  não cria necessidade estrutural para `CredencialAcesso` nesta etapa.
- [x] `MCD-F10004` com política de mutabilidade semanticamente justificada e coerente com
  `CDC-001` V1.4 — divergência hospedeiro a hospedeiro reportada explicitamente, não mascarada.
- [x] `ResultadoCalculo` permanece sem XOR entre `unidade_economica_id` e `cenario_tributario_id`
  — obrigatoriedade não alterada; `GAP-SEC-CR1-003` permanece aberto e registrado.
- [x] Nenhum enum criado para `papel` — `DST-GAP-015` inalterado.
- [x] Nenhum ID MCD reutilizado; nenhum campo aposentado retornou.
- [x] 151 campos totais (145 + 6), sem duplicação de ID.
- [x] Nenhuma FK composta, RLS ou constraint física implementada — apenas estrutura relacional e
  invariantes lógicos registrados para o ADR.
- [x] COT-001, DST-001, SEC-001, SEC-CHANGE-REQUEST-001 não foram alterados.

**Ainda não constitui autorização para migration:**
- [ ] Reconciliação final (COT × MCD × CDC × DST) confirmando a correção.
- [ ] ADR físico (novo `ADR-002`) aprovado.

## 25. Próximos documentos

1. **Reconciliação final** — nova verificação cruzada confirmando que os 2 achados `RELEVANTE`
   foram corrigidos e nenhuma nova inconsistência bloqueante surgiu.
2. **ADR-002** — schema físico de segurança/tenant.
3. Change Request específico de autenticação/RBAC (detalhamento completo de `Tenant`,
   `EventoAuditoriaSeguranca`, `ContaAcesso.tipo`, `CredencialAcesso`, vigência das associações de
   acesso, se um requisito concreto surgir).
4. RGT-001, EVT-001, INT-001 conforme a sequência de governança já estabelecida.

---

**Decisão de governança:** MCD-001 V1.4 é a baseline canônica vigente. MCD-001 V1.3, V1.2, V1.1 e
V1.0 permanecem apenas como histórico `SUPERSEDED`. O schema físico continua bloqueado até a
reconciliação final e o novo ADR de segurança/tenant serem aprovados.
