# DST-001 — Dicionário Semântico Tributário da CONTIFISC

**Versão:** 1.2  
**Status:** APROVADO — sincronizado com MCD-001 V1.2 e CDC-001 V1.2  
**Supersede:** DST-001 V1.1  
**Dependências:** CAF-001, COT-001, MCD-001 V1.2, CDC-001 V1.2  
**Escopo:** vocabulário canônico, códigos estáveis, semântica de estados e gaps semânticos da plataforma

> O DST governa significado. Código, banco, API, IA e integrações não podem atribuir significado diferente a um termo ou inventar códigos para lacunas ainda abertas.

## 1. Objetivo da V1.2

- Sincronizar o dicionário com as estruturas aprovadas no MCD/CDC V1.2.
- Corrigir a antiga mistura entre lifecycle e qualidade do dado.
- Formalizar `lado_extremidade` para VinculoExtremidade.
- Registrar semanticamente as estruturas relacionais de suporte sem transformá-las em novos objetos tributários autônomos.
- Preservar gaps como gaps: ausência de catálogo não autoriza enum inventado em TypeScript, Prisma, banco ou UI.

## 2. Regras semânticas gerais

- Código canônico é estável; label de exibição pode ser traduzido/ajustado sem alterar o código.
- Sinônimos de UI não criam novos conceitos canônicos.
- Infraestrutura como Neon, PostgreSQL, Vercel ou Prisma nunca é `sistema_origem` tributário.
- `competencia` é `YYYY-MM`; conversão para primeiro dia do mês é semanticamente proibida.
- `status_registro`, `status_processamento_dado` e `status_qualidade_dado` são dimensões diferentes.
- Enum/Ref aberto deve ser representado como tipo aberto/branded ou referência validável, nunca como closed union inventada.
- Referência polimórfica genérica é exceção de auditoria/reconciliação, não padrão de ownership financeiro.
- `tipo_titular` permanece termo/enumerador útil para apresentação/intercâmbio derivado, mas não é fonte de verdade de Receita na V1.2; a titularidade persistível é determinada pelas FKs PF/PJ com XOR.

## 3. Termos canônicos V1.2

| ID | Termo | Definição normativa |
|---|---|---|
| DST-T001 | Unidade Econômica | Contexto econômico-tributário agregador interno; não é contribuinte nem substitui CPF/CNPJ. |
| DST-T002 | Pessoa Física | Pessoa natural que pode exercer papéis tributários, societários, previdenciários ou profissionais. |
| DST-T003 | Pessoa Jurídica | Pessoa jurídica identificável no domínio tributário, independente da Unidade Econômica. |
| DST-T004 | Vínculo | Relacionamento de primeira classe entre objetos canônicos, com tipo, papel e vigência. |
| DST-T005 | Extremidade de Vínculo | Estrutura relacional de suporte que materializa ORIGEM ou DESTINO de um Vínculo com uma FK real para UE, PF ou PJ. |
| DST-T006 | Receita | Fato canônico de ingresso/receita atribuído exatamente a uma PF ou PJ. |
| DST-T007 | Documento Fiscal | Documento fiscal normalizado usado como evidência; não substitui o fato Receita. |
| DST-T008 | Arquivo de Origem | Evidência RAW preservada e rastreável, como XML, PDF, arquivo importado ou captura autorizada. |
| DST-T009 | Associação Receita-Documento Fiscal | Estrutura relacional de suporte da relação N:N entre Receita e Documento Fiscal. |
| DST-T010 | Associação Documento-Arquivo | Estrutura relacional de suporte da relação N:N entre Documento Fiscal e Arquivo de Origem. |
| DST-T011 | Classificação de Equiparação Hospitalar | Resultado derivado e versionado sobre Receita, sujeito a regra vigente e revisão técnica. |
| DST-T012 | Contribuição Previdenciária | Fato previdenciário atribuído a Pessoa Física, potencialmente associado a vínculo previdenciário. |
| DST-T013 | Vínculo Previdenciário | Relação previdenciária de uma Pessoa Física com fonte/regime durante determinada vigência. |
| DST-T014 | Evento IRPF | Fato/evento tributário de Pessoa Física relevante ao IRPF ou Carnê-Leão. |
| DST-T015 | Fonte Pagadora | Fonte externa que paga Receita ou rendimento da Pessoa Física. |
| DST-T016 | Cenário Tributário | Ambiente de simulação/planejamento isolado dos fatos oficiais. |
| DST-T017 | Resultado de Cálculo | Resultado derivado reproduzível, ligado a inputs, engine e versões de regras. |
| DST-T018 | Conflito de Dados | Objeto auditável que registra divergência entre dados, fontes ou interpretações de registro. |
| DST-T019 | Item de Conflito | Participante/fonte estruturado de um Conflito de Dados; referência genérica permitida apenas como exceção de auditoria. |
| DST-T020 | Revisão Técnica | Registro de decisão humana sobre objeto, classificação ou resultado revisável. |
| DST-T021 | Conta de Acesso | Identidade de autenticação/autorização; não é sinônimo de Pessoa Física. |
| DST-T022 | Credencial de Acesso | Mecanismo/segredo de autenticação associado a Conta de Acesso; domínio SEC. |
| DST-T023 | Competência | Período mensal canônico no formato opaco YYYY-MM; não representa uma data no primeiro dia do mês. |
| DST-T024 | Proveniência | Conjunto de informações que permite rastrear origem, transformação e evidência de um dado. |
| DST-T025 | Sistema de Origem | Fonte de negócio/processo de onde o dado foi obtido; infraestrutura de hosting não é sistema de origem. |
| DST-T026 | Status de Processamento do Dado | Estado operacional/lifecycle do dado no pipeline canônico. |
| DST-T027 | Status de Qualidade do Dado | Avaliação independente da condição de uso/confiabilidade estrutural do dado. |
| DST-T028 | Fato Canônico | Registro normalizado que representa ocorrência de negócio/tributária e não deve ser sobrescrito por resultado derivado. |
| DST-T029 | Resultado Derivado | Saída calculada/classificada a partir de fatos, regras e versões identificáveis. |
| DST-T030 | Enum/Ref Aberto | Campo semanticamente controlado, mas cujo catálogo fechado ainda não foi aprovado; código não pode inventar union fechada. |

## 4. Enums canônicos aprovados

### DST-E001 — `regime_tributario`

| Código | Significado |
|---|---|
| SIMPLES_NACIONAL | Simples Nacional |
| LUCRO_PRESUMIDO | Lucro Presumido |
| LUCRO_REAL | Lucro Real |
| OUTRO | Outro regime |
| NAO_INFORMADO | Não informado |

### DST-E002 — `tipo_titular`

| Código | Significado |
|---|---|
| PESSOA_FISICA | Pessoa Física |
| PESSOA_JURIDICA | Pessoa Jurídica |

### DST-E003 — `status_elegibilidade_equiparacao_hospitalar`

| Código | Significado |
|---|---|
| EH_001_ELEGIVEL | Elegível |
| EH_002_NAO_ELEGIVEL | Não elegível |
| EH_003_PENDENTE | Pendente |
| EH_004_REVISAO_TECNICA | Revisão técnica |

### DST-E004 — `tipo_rendimento_irpf`

| Código | Significado |
|---|---|
| TRIBUTAVEL | Tributável |
| ISENTO_NAO_TRIBUTAVEL | Isento/não tributável |
| TRIBUTACAO_EXCLUSIVA | Tributação exclusiva |
| OUTRO | Outro |
| NAO_INFORMADO | Não informado |

### DST-E005 — `tipo_fonte_pagadora`

| Código | Significado |
|---|---|
| PESSOA_FISICA | Pessoa Física |
| PESSOA_JURIDICA | Pessoa Jurídica |
| EXTERIOR | Exterior |
| OUTRA | Outra |
| NAO_INFORMADA | Não informada |

### DST-E006 — `status_revisao`

| Código | Significado |
|---|---|
| PENDENTE | Pendente |
| APROVADO | Aprovado |
| REJEITADO | Rejeitado |
| AJUSTE_SOLICITADO | Ajuste solicitado |

### DST-E007 — `status_conflito`

| Código | Significado |
|---|---|
| ABERTO | Aberto |
| EM_ANALISE | Em análise |
| RESOLVIDO | Resolvido |
| DESCARTADO | Descartado |

### DST-E008 — `status_registro`

| Código | Significado |
|---|---|
| ATIVO | Ativo |
| INATIVO | Inativo |
| ARQUIVADO | Arquivado |

### DST-E009 — `status_processamento_dado`

| Código | Significado |
|---|---|
| IMPORTADO | Recebido/importado para o pipeline |
| VALIDADO | Validado estrutural/contratualmente |
| RECONCILIADO | Reconciliado com fontes/registros aplicáveis |
| OVERRIDDEN | Valor/estado substituído por override auditável |
| SUPERSEDED | Substituído por versão posterior |
| CANCELADO | Cancelado sem exclusão histórica |

### DST-E011 — `status_qualidade_dado`

| Código | Significado |
|---|---|
| NAO_AVALIADO | Qualidade ainda não avaliada |
| VALIDO | Dado apto segundo critérios de qualidade aplicáveis |
| INCOMPLETO | Faltam elementos relevantes para uso pleno |
| DIVERGENTE | Há divergência relevante com outra fonte/registro |
| SUSPEITO | Há indício de anomalia ou inconsistência que exige verificação |

### DST-E012 — `lado_extremidade`

| Código | Significado |
|---|---|
| ORIGEM | Extremidade de origem do vínculo |
| DESTINO | Extremidade de destino do vínculo |

## 5. Separação normativa: registro, processamento e qualidade

| Dimensão | Campo | Pergunta que responde | Exemplo |
|---|---|---|---|
| Ciclo do registro | status_registro | O objeto cadastral está ativo/inativo/arquivado? | Uma UE pode estar INATIVA. |
| Processamento | status_processamento_dado | Em que etapa/estado operacional o dado está? | Uma Receita pode estar RECONCILIADA. |
| Qualidade | status_qualidade_dado | Qual é a condição de uso/consistência do dado? | A mesma Receita pode estar DIVERGENTE. |

Regras:
- `VALIDADO` em processamento não significa automaticamente `VALIDO` em qualidade.
- `RECONCILIADO` não obriga qualidade `VALIDO`; reconciliação pode confirmar uma divergência.
- `DIVERGENTE` é qualidade/condição do dado. A existência de divergência material pode também originar um `ConflitoDado`, mas um conceito não substitui o outro.
- `SUSPEITO` indica indício que exige verificação; não equivale a fraude, erro confirmado ou conflito resolvido.
- `NAO_AVALIADO` é ausência de avaliação de qualidade, não ausência do dado.

## 6. Semântica de VinculoExtremidade

- `ORIGEM` e `DESTINO` são posições canônicas da relação conforme o COT vigente.
- Cada Vinculo deve possuir exatamente uma extremidade ORIGEM e uma DESTINO.
- Cada extremidade aponta exatamente para um entre UnidadeEconomica, PessoaFisica ou PessoaJuridica.
- `ORIGEM`/`DESTINO` não significam automaticamente pagador/recebedor, controlador/controlado ou sócio/empresa; o significado de negócio vem de `tipo_vinculo` e `papel_vinculo` quando seus catálogos forem aprovados.
- Não usar A/B ou source/target como códigos canônicos sem Change Request.

## 7. Semântica de evidência documental

- `ArquivoOrigem` é RAW/evidência preservada; `DocumentoFiscal` é representação fiscal normalizada.
- `DocumentoFiscalArquivoOrigem` permite mais de uma evidência para o mesmo documento e reuso controlado quando aplicável.
- `papel_arquivo` continua aberto: XML, PDF, captura, lote ou versão são exemplos conceituais, não códigos autorizados.
- `arquivo_origem_id` transversal não substitui a associação documental específica; ambos têm papéis distintos.

## 8. Equiparação Hospitalar

- Códigos canônicos de elegibilidade permanecem `EH_001_ELEGIVEL`, `EH_002_NAO_ELEGIVEL`, `EH_003_PENDENTE`, `EH_004_REVISAO_TECNICA`.
- Labels de negócio podem ser exibidos como `EH-001 Elegível`, etc.; o código técnico permanece com underscore.
- A classificação é resultado derivado sobre Receita e não atributo permanente da empresa.
- `eh_validada_tecnicamente` é indicador derivado; a decisão humana auditável pertence a RevisaoTecnica.
- O DST não define critérios jurídicos de elegibilidade; isso pertence ao RGT.

## 9. Semântica de conflito e revisão

- `ConflitoDado` representa divergência que precisa de tratamento auditável.
- `ConflitoDadoItem` registra participantes/fontes; `tipo_objeto` e `papel_no_conflito` permanecem abertos.
- Exemplos como candidato, referência, vencedor ou descartado não são códigos canônicos até catálogo aprovado.
- `RevisaoTecnica` registra decisão humana, mas a identidade/autorização do revisor aguarda SEC-001/OBS-001.
- Não usar PessoaFisica como identidade de usuário por inferência.

## 10. Sistema de origem e proveniência

### DST-E010 — `sistema_origem`

| Código | Significado |
|---|---|
| ERP_CONTABIL | ERP contábil/fiscal externo. |
| DOCUMENTO_FISCAL | Documento fiscal ou serviço oficial de documentos fiscais. |
| CNIS | Cadastro Nacional de Informações Sociais. |
| FOLHA_PAGAMENTO | Sistema/processo de folha. |
| BANCO | Instituição/arquivo bancário. |
| INFORME_RENDIMENTOS | Informe de rendimentos. |
| CARNE_LEAO | Fonte/processo relacionado ao Carnê-Leão. |
| ENTRADA_MANUAL | Entrada humana autorizada. |
| API_GOVERNAMENTAL | API/serviço governamental. |
| OUTRO_SISTEMA | Outro sistema externo não classificado. |

`NEON_DB`, `POSTGRESQL`, `PRISMA`, `VERCEL` e nomes equivalentes de infraestrutura são proibidos como valores de sistema de origem.

## 11. Gaps semânticos V1.2

| Gap | Campo/tema | Situação |
|---|---|---|
| DST-GAP-001 | conselho_profissional | Enum/Ref aberto; catálogo profissional não aprovado. |
| DST-GAP-002 | especialidade_saude | Enum/Ref aberto; catálogo de especialidades não aprovado. |
| DST-GAP-003 | tipo_vinculo | Catálogo fechado pendente. |
| DST-GAP-004 | tipo_objeto_origem/destino | RESOLVIDO: campos polimórficos removidos; usar VinculoExtremidade + FKs reais. |
| DST-GAP-005 | papel_vinculo | Catálogo fechado pendente. |
| DST-GAP-006 | fonte_receita | Enum/Ref aberto; catálogo pendente. |
| DST-GAP-007 | tipo_documento_fiscal | Enum/Ref aberto; catálogo pendente. |
| DST-GAP-008 | tipo_vinculo_previdenciario | Enum/Ref aberto; catálogo pendente. |
| DST-GAP-009 | tipo_conflito | Enum/Ref aberto; catálogo pendente. |
| DST-GAP-010 | tipo_objeto_revisado | Enum/Ref aberto; depende de revisão/OBS. |
| DST-GAP-011 | papel_arquivo | Novo gap V1.2; Enum/Ref aberto. |
| DST-GAP-012 | tipo_objeto de ConflitoDadoItem | Novo gap V1.2; Enum/Ref aberto e restrito ao domínio de auditoria. |
| DST-GAP-013 | papel_no_conflito | Novo gap V1.2; Enum/Ref aberto. |
| DST-GAP-014 | identidade do revisor | Depende de SEC-001/OBS-001; não modelar como PessoaFisica por inferência. |

### Gaps resolvidos nesta versão
- `DST-GAP-004` é resolvido estruturalmente: os campos polimórficos de origem/destino foram removidos e substituídos por VinculoExtremidade.
- A contradição da antiga `DST-E009 status_qualidade_dado` é resolvida: E009 passa a significar `status_processamento_dado`; qualidade recebe E011.
- `lado_extremidade` deixa de ser gap e passa a DST-E012.

## 12. Política para TypeScript, Prisma, API e IA

```yaml
dst_policy:
  version: 1.2
  source_of_truth: docs/01-Semantics/DST-001.md
  supersedes: DST-001-v1.1
  canonical_language: pt-BR
  enum_codes_are_stable: true
  invent_enum_values: false
  invent_synonyms_as_codes: false
  open_enum_ref:
    closed_union: prohibited
    branded_or_reference_type: allowed
  competence:
    format: YYYY-MM
    fake_first_day_date: prohibited
  data_status:
    record: status_registro
    processing: status_processamento_dado
    quality: status_qualidade_dado
    collapse_dimensions: prohibited
  source_system:
    hosting_infrastructure_as_source: prohibited
  relation:
    vinculo_endpoint_side:
      - ORIGEM
      - DESTINO
    polymorphic_financial_ownership: prohibited
  auth_identity_equals_pessoa_fisica: false
```

## 13. Impacto sobre a Fase 1

- Nenhuma alteração é necessária nas interfaces UnidadeEconomica, PessoaFisica e PessoaJuridica já implementadas.
- `regime_tributario` e `status_registro` mantêm os mesmos códigos da V1.1.
- `conselho_profissional` e `especialidade_saude` continuam abertos/branded.
- Não implementar os novos objetos/estruturas até a autorização da fase correspondente.
- Este DST não autoriza Prisma schema ou migration.

## 14. Critérios de aceite

- [x] Semântica sincronizada com MCD-001 V1.2 e CDC-001 V1.2.
- [x] Lifecycle e qualidade separados.
- [x] DST-E009 renomeado semanticamente para status_processamento_dado.
- [x] DST-E011 criado para status_qualidade_dado.
- [x] DST-E012 criado para lado_extremidade.
- [x] Enums existentes preservam códigos estáveis.
- [x] Gaps sem catálogo permanecem abertos.
- [x] Infraestrutura não aparece como sistema de origem.
- [x] Competência continua YYYY-MM.
- [x] Fase 1 permanece compatível.

## 15. Próximo documento

Com MCD-001 V1.2, CDC-001 V1.2 e DST-001 V1.2 sincronizados, o próximo passo é uma **nota/versão de alinhamento do COT-001** para registrar explicitamente as estruturas relacionais de suporte (`VinculoExtremidade`, `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem` e `ConflitoDadoItem`). Depois disso, deve ser elaborado o **ADR do schema físico Prisma/PostgreSQL** antes de qualquer migration.

---
**Governança:** DST-001 V1.2 é o dicionário semântico vigente. DST V1.1/V1.0 permanecem apenas como histórico `SUPERSEDED`.