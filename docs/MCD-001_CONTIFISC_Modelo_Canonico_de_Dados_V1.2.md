# MCD-001 — Modelo Canônico de Dados da CONTIFISC

**Versão:** 1.2  
**Status:** APROVADO — baseline canônica pós-CR-002; schema físico ainda condicionado a CDC/DST V1.2 + ADR  
**Supersede:** MCD-001 V1.1  
**Incorpora:** MCD-CHANGE-REQUEST-001 e MCD-CHANGE-REQUEST-002 V1.0 (APROVADO)  
**Dependências:** CAF-001, COT-001, CDC-001 V1.1, DST-001 V1.1  
**Sincronizações requeridas:** CDC-001 V1.2, DST-001 V1.2  
**Escopo:** CONTIFISC Intelligence Platform — profissionais da saúde

> **Princípio central:** o MCD define a representação canônica dos dados. O schema físico, ORM, banco, ERP e interfaces são implementações/integrações subordinadas ao modelo; nunca são sua fonte de verdade.

## 1. Objetivo

Incorporar formalmente o MCD-CHANGE-REQUEST-002, eliminando fragilidades relacionais da V1.1 antes da primeira materialização física. A V1.2 preserva a nomenclatura canônica já implementada na Fase 1 e torna explícitas as estruturas necessárias para integridade referencial, associações documentais, identidade de resultados EqHop, reconciliação e separação entre processamento e qualidade do dado.

## 2. Governança e versionamento

- Esta V1.2 substitui integralmente o MCD-001 V1.1 para código novo.
- Os IDs de campos removidos ficam aposentados e não podem ser reutilizados com outro significado.
- A publicação como V1.2, apesar de conter alterações incompatíveis, é uma exceção pré-implementação aprovada: ainda não existe migration/schema de produção.
- Após a primeira migration oficial, alteração equivalente incompatível exigirá major version.
- A Fase 1 já implementada para UnidadeEconomica, PessoaFisica e PessoaJuridica permanece válida e não requer renomeação.

### 2.1 Errata de publicação V1.2

A primeira renderização da V1.2 omitiu inadvertidamente `MCD-F9009 arquivo_origem_id`, campo transversal vigente na V1.1 e **não removido pelo MCD-CHANGE-REQUEST-002**. A presente publicação restaura o campo sem alteração conceitual, sem novo Change Request e sem mudança de versão. O catálogo correto da V1.2 contém **139 campos canônicos**.

## 3. Decisões arquiteturais da baseline V1.2

- Unidade Econômica continua sendo contexto agregador e não sujeito tributário.
- Pessoa Física e Pessoa Jurídica continuam objetos independentes.
- Vinculo permanece objeto de primeira classe; sua materialização usa duas VinculoExtremidade com FKs reais.
- Receita não usa titularidade polimórfica: exatamente uma FK entre PF e PJ deve estar preenchida.
- Receita↔DocumentoFiscal e DocumentoFiscal↔ArquivoOrigem são relações N:N materializadas por estruturas associativas.
- ClassificacaoEquiparacaoHospitalar possui identidade própria e histórico versionável.
- Referência polimórfica genérica é admitida somente no domínio de auditoria/reconciliação quando deliberadamente governada.
- status_processamento_dado e status_qualidade_dado são eixos distintos.
- PessoaFisica não é ContaAcesso; autenticação permanece bloqueada até SEC-001.
- Competência continua sendo string opaca YYYY-MM; data fictícia no primeiro dia do mês é proibida.
- PostgreSQL/Prisma podem ser usados na implementação, mas não definem semântica canônica.

## 4. Convenção de nomenclatura V1.2

- `snake_case`, ASCII, nomes descritivos em português.
- PK de objeto: `id`.
- FK/referência concreta: `<objeto>_id`.
- Datas de negócio: `data_*`; timestamps técnicos: `*_em`; vigência: `vigencia_inicio`/`vigencia_fim`.
- Competência: `competencia`.
- Dinheiro: `valor_*`; percentuais: `percentual_*`; status: `status_*`; tipos: `tipo_*`.
- Booleanos devem preferir semântica explícita (`eh_*`, `possui_*`, `permite_*`) em vez de substantivo ambíguo.
- Não codificar tipo físico no nome do campo.

## 5. Tipos canônicos

| Tipo | Contrato | Persistência recomendada | Regra |
|---|---|---|---|
| UUID | UUID | UUID nativo | ID interno; CPF/CNPJ não são PK. |
| Dinheiro | Decimal | NUMERIC(18,2) | Float proibido. |
| Percentual | Decimal | NUMERIC(7,4) | 32,0000 representa 32% até decisão formal diversa. |
| Date | YYYY-MM-DD | DATE | Sem horário. |
| Competência | YYYY-MM | A decidir no ADR físico | Não converter semanticamente para dia 01. |
| Timestamp TZ | ISO-8601 offset-aware | TIMESTAMPTZ | Persistência UTC. |
| CPF/CNPJ | Somente dígitos | VARCHAR | Máscara somente na UI. |
| Enum | Código estável DST | VARCHAR/enum técnico | Descrição separada. |
| Boolean | true/false | BOOLEAN | null somente quando semanticamente necessário. |
| SemVer | MAJOR.MINOR.PATCH | VARCHAR | Validar formato. |

## 6. Nulidade e estados especiais

- `null` significa ausência/desconhecimento conforme contrato; nunca é convertido automaticamente em zero.
- Zero é valor conhecido igual a zero.
- Campos obrigatórios por operação continuam definidos pelo CDC.
- Enums especiais obedecem ao DST; código não cria sinônimos.
- Resultado com inputs incompletos deve registrar processamento, qualidade e/ou revisão; nunca inventar valor.

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
| DOM-SEC | Segurança | Conta/credenciais; detalhamento bloqueado até SEC-001. |

## 8. Catálogo canônico V1.2 (139 campos)

A coluna `Obrig. base` representa o requisito estrutural mínimo. O CDC continua soberano para obrigatoriedade por operação. `XOR` significa que o grupo indicado deve satisfazer exclusividade lógica conforme a seção de constraints.

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

## 9. Estruturas relacionais de suporte

As estruturas abaixo materializam relações do COT sem criar novos conceitos tributários autônomos:

| Estrutura | Função | Constraints mínimas |
|---|---|---|
| VinculoExtremidade | Materializa ORIGEM/DESTINO de Vinculo com FK real para UE/PF/PJ. | Exatamente 2 por Vinculo; unique(vinculo_id,lado_extremidade); exatamente uma FK de endpoint preenchida. |
| ReceitaDocumentoFiscal | Materializa N:N Receita↔DocumentoFiscal. | Unique(receita_id,documento_fiscal_id); sem valor/percentual de rateio nesta versão. |
| DocumentoFiscalArquivoOrigem | Materializa N:N DocumentoFiscal↔ArquivoOrigem. | Unique(documento_fiscal_id,arquivo_origem_id,papel_arquivo quando aplicável); papel_arquivo depende de DST. |
| ConflitoDadoItem | Registra objetos/fontes participantes de um conflito. | Pertence a ConflitoDado; referência genérica é exceção controlada de auditoria. |

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

## 11. Relacionamentos estruturais V1.2

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

## 12. Constraints canônicas obrigatórias para o ADR físico

- Receita: exatamente uma entre pessoa_fisica_id e pessoa_juridica_id deve estar preenchida.
- VinculoExtremidade: exatamente uma entre unidade_economica_id, pessoa_fisica_id e pessoa_juridica_id deve estar preenchida.
- Vinculo: exatamente uma extremidade ORIGEM e uma DESTINO.
- ReceitaDocumentoFiscal: o par receita_id + documento_fiscal_id é único.
- DocumentoFiscalArquivoOrigem: evitar duplicação da mesma associação/evidência.
- ClassificacaoEquiparacaoHospitalar.id é PK própria; versões anteriores não são sobrescritas de forma destrutiva.
- IDs aposentados da V1.1 não podem ser reaproveitados.

## 13. Fatos, documentos e resultados

- Receita, ContribuicaoPrevidenciaria e EventoIRPF são fatos canônicos.
- DocumentoFiscal e ArquivoOrigem são evidências/documentos e não substituem fatos normalizados.
- ClassificacaoEquiparacaoHospitalar e ResultadoCalculo são resultados derivados versionados.
- CenarioTributario é sandbox de planejamento e nunca altera fatos oficiais.
- ConflitoDado, ConflitoDadoItem e RevisaoTecnica preservam reconciliação e decisões human-in-the-loop.

## 14. Equiparação Hospitalar

- A classificação possui `id` próprio.
- A classificação é ligada à `receita_id`, não gravada como atributo estático da empresa.
- `regra_versao_id` permanece identificador opaco até RGT-001; nenhum FK físico para regras deve ser inventado antes disso.
- `eh_validada_tecnicamente` é indicador derivado; a evidência formal da decisão humana continua em RevisaoTecnica.
- Percentuais/valores elegíveis não substituem `valor_receita_bruta`.
- A base legal e a lógica executável pertencem ao RGT, não ao MCD.

## 15. Conflito, revisão e polimorfismo controlado

- Ownership financeiro central não utiliza referência polimórfica sem FK.
- ConflitoDadoItem.objeto_id + tipo_objeto é exceção deliberada por pertencer à auditoria/reconciliação.
- O ADR físico deve documentar como essa referência genérica será validada pela aplicação e auditada.
- RevisaoTecnica continua sem identidade de revisor nesta versão; isso permanece bloqueado por SEC-001/OBS-001.
- Objeto revisado continua genericamente referenciado até decisão específica de SEC/OBS; essa exceção não autoriza repetir o padrão em fatos financeiros.

## 16. IRPF/Carnê-Leão e Previdenciário

- PF é a raiz dos fatos de IRPF e contribuição previdenciária; CNPJ não é obrigatório.
- Múltiplos vínculos previdenciários podem coexistir na mesma competência.
- CNIS, folha, informe, Carnê-Leão e ERP são fontes externas/candidatas, não modelos de domínio.
- Excedente INSS e IRPF projetado são resultados derivados e devem preservar versão de regra/cálculo.

## 17. Autenticação e domínio SEC

- ContaAcesso e CredencialAcesso permanecem objetos conceituais do COT.
- Esta V1.2 não define e-mail de login, senha, hash, MFA, sessão ou campos de credencial.
- PessoaFisica pode existir sem ContaAcesso; conta técnica pode existir sem representar contribuinte.
- O schema de autenticação continua bloqueado até SEC-001 ou Change Request específico.

## 18. Migração conceitual V1.1 → V1.2

| ID/campo | Ação | Resultado V1.2 |
|---|---|---|
| MCD-F2506..F2509 | REMOVIDOS | Endpoints polimórficos de Vinculo substituídos por VinculoExtremidade. |
| MCD-F2520..F2525 | ADICIONADOS | Extremidades relacionais com FKs reais e XOR. |
| MCD-F3006 | REMOVIDO | tipo_titular deixa de ser fonte de verdade. |
| MCD-F3009 | REMOVIDO | titular_id polimórfico substituído por FKs explícitas. |
| MCD-F3010..F3011 | ADICIONADOS | Titularidade PF/PJ com XOR. |
| MCD-F4008 | REMOVIDO | Arquivo único substituído por associação N:N. |
| MCD-F4301..F4303 | ADICIONADOS | ReceitaDocumentoFiscal. |
| MCD-F4401..F4404 | ADICIONADOS | DocumentoFiscalArquivoOrigem. |
| MCD-F5006 | RENOMEADO | validacao_tecnica -> eh_validada_tecnicamente; indicador derivado. |
| MCD-F5009..F5011 | ADICIONADOS | Identidade e timestamps da classificação EqHop. |
| MCD-F8650..F8657 | ADICIONADOS | Itens participantes de ConflitoDado. |
| MCD-F9004 | RENOMEADO SEMANTICAMENTE | status_qualidade_dado -> status_processamento_dado. |
| MCD-F9010 | ADICIONADO | Novo status_qualidade_dado, separado do lifecycle. |
| MCD-F1005 | CORRIGIDO | Correção editorial de significado/tipo/unidade. |

### Resolução de incorporação do status do dado

O CR-002 continha duas formulações textuais possíveis para a numeração dos estados. Para preservar a identidade do conceito já existente, a V1.2 estabelece definitivamente: **MCD-F9004 = `status_processamento_dado`** (os valores anteriormente usados eram de workflow/lifecycle) e **MCD-F9010 = novo `status_qualidade_dado`**. Essa resolução elimina a contradição sem reutilizar IDs.

## 19. Sincronizações obrigatórias em CDC e DST

Antes de qualquer schema físico, devem ser publicados:

- CDC-001 V1.2 com titularidade de Receita por FKs XOR, VinculoExtremidade, associações documentais, identidade EqHop, itens de conflito e separação processamento/qualidade.
- DST-001 V1.2 renomeando DST-E009 para `status_processamento_dado`, criando o enum independente `status_qualidade_dado` e formalizando `lado_extremidade`.
- O catálogo de `papel_arquivo`, `tipo_objeto`/`papel_no_conflito` e demais gaps continua aberto quando não houver enum aprovado; código não deve inventar union fechada.

## 20. Regras para TypeScript, APIs e Prisma

- Types canônicos usam exclusivamente nomes V1.2.
- Interfaces de domínio não embutem relações arbitrariamente; relações seguem COT/MCD/CDC.
- Prisma deve documentar rastreabilidade COT → MCD → CDC → DST.
- Campo físico adicional exige Change Request ou ADR quando for puramente técnico e não alterar o contrato canônico.
- Competencia em types/API permanece `YYYY-MM`.
- Money/percentuais não usam JavaScript `number` quando houver perda de precisão.
- Gateway/adapters não importam models Prisma nem expõem schema de fornecedor ao domínio.
- Nenhuma migration pode ser criada até CDC/DST V1.2 e ADR físico serem aprovados.

## 21. Política para Claude Code

```yaml
mcd_policy:
  version: 1.2
  source_of_truth: docs/02-Data/MCD-001.md
  supersedes: MCD-001-v1.1
  incorporates:
    - MCD-CHANGE-REQUEST-001
    - MCD-CHANGE-REQUEST-002
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
  data_state:
    processing_field: status_processamento_dado
    quality_field: status_qualidade_dado
    collapse_axes: prohibited
  allow_new_field_without_mcd: false
  allow_new_object_without_cot: false
  allow_erp_field_names_in_domain: false
  allow_auth_fields_in_pessoa_fisica: false
  create_prisma_schema_now: false
  create_migration_now: false
  money_type: decimal
  ids: uuid
  preserve_provenance: true
  preserve_history: true
  derived_overwrites_fact: false
  vendor_specific_domain_model: false
```

## 22. O que está liberado após V1.2

- Manter e evoluir a infraestrutura genérica concluída na Fase 1.
- Usar UnidadeEconomica, PessoaFisica e PessoaJuridica já implementadas, sem alteração de nomes.
- Preparar CDC-001 V1.2 e DST-001 V1.2.
- Preparar ADR de schema físico somente depois das sincronizações documentais.
- Preparar proposta de Prisma após o ADR, sem executar migration até aprovação.
- Não implementar autenticação real antes do SEC-001.
- Não implementar lógica tributária antes do RGT aplicável.

## 23. Gaps remanescentes

| Gap | Tema | Tratamento |
|---|---|---|
| GAP-MCD-CR2-001 | VinculoExtremidade e COT | COT deve registrar explicitamente a estrutura relacional de suporte. |
| GAP-MCD-CR2-002 | DocumentoFiscalArquivoOrigem.papel_arquivo | Catálogo DST pendente; não criar enum fechado. |
| GAP-MCD-CR2-003 | ConflitoDadoItem.tipo_objeto/papel_no_conflito | Catálogos dependem de OBS/reconciliação. |
| GAP-MCD-CR2-004 | Revisor de RevisaoTecnica | Aguardar SEC-001/OBS-001. |
| GAP-MCD-CR2-005 | FontePagadora.identificador_fiscal | Validação tipada CPF/CNPJ/Exterior fica para revisão posterior; não bloqueia ADR inicial. |

## 24. Critérios de aceite da V1.2

- [x] Nomenclatura snake_case preservada.
- [x] Competência permanece YYYY-MM.
- [x] Receita possui titularidade com FK real e XOR.
- [x] Vinculo possui duas extremidades relacionais com FKs reais.
- [x] Receita↔DocumentoFiscal e DocumentoFiscal↔ArquivoOrigem estão materializados sem semântica inventada.
- [x] EqHop possui identidade própria.
- [x] ConflitoDado possui participantes/fontes estruturados.
- [x] Processamento e qualidade do dado estão separados.
- [x] MCD-F1005 está corrigido.
- [x] Autenticação permanece separada.
- [x] Modelo continua vendor-neutral.
- [x] Nenhum campo novo pode ser inventado pelo código.

**Ainda não constitui autorização para migration:**
- [ ] CDC-001 V1.2 publicado e aprovado.
- [ ] DST-001 V1.2 publicado e aprovado.
- [ ] ADR físico aprovado com constraints, índices, delete policy, mapping Prisma/PostgreSQL e estratégia da referência genérica de auditoria.

## 25. Próximos documentos

1. CDC-001 V1.2 — sincronização contratual com o MCD V1.2.  
2. DST-001 V1.2 — sincronização semântica dos estados/enums.  
3. Nota/versão de alinhamento do COT para estruturas relacionais de suporte.  
4. ADR do schema físico Prisma/PostgreSQL.  
5. SEC-001, RGT-001, EVT-001, INT-001 conforme a sequência de governança.

---

**Decisão de governança:** MCD-001 V1.2 é a baseline canônica vigente. MCD-001 V1.1 e V1.0 permanecem apenas como histórico `SUPERSEDED`. O schema físico continua bloqueado até CDC/DST V1.2 e ADR aprovados.