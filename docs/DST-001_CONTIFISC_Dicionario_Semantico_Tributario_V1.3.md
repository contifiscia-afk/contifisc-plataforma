# DST-001 — Dicionário Semântico Tributário da CONTIFISC

**Versão:** 1.3  
**Status:** APROVADO — sincronizado com COT-001 V1.2 e MCD-001 V1.3 (CDC-001 ainda pendente de sincronização — ver §16)  
**Supersede:** DST-001 V1.2  
**Dependências:** CAF-001, COT-001 V1.2, MCD-001 V1.3, CDC-001 V1.2, `SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`, `SEC-CHANGE-REQUEST-001_V1.1.md`  
**Escopo:** vocabulário canônico, códigos estáveis, semântica de estados e gaps semânticos da plataforma

> O DST governa significado. Código, banco, API, IA e integrações não podem atribuir significado diferente a um termo ou inventar códigos para lacunas ainda abertas.

## 1. Objetivo da V1.3

- Incorporar a semântica necessária para os objetos, campos e relações de segurança aprovados em
  `SEC-CHANGE-REQUEST-001` V1.1, já refletidos em `COT-001` V1.2 e `MCD-001` V1.3.
- Preservar integralmente todos os termos (`DST-T001..030`), enums (`DST-E001..012`) e gaps
  (`DST-GAP-001..014`) já vigentes na V1.2 — nenhum é alterado, renomeado ou fechado por
  inferência nesta versão.
- Formalizar a distinção semântica entre `tenant_id` (fronteira de segurança) e
  `unidade_economica_id` (contexto econômico/tributário), e entre identidade tributária e
  identidade de acesso.
- Registrar `papel` como novo gap semântico aberto (`DST-GAP-015`) — nenhum enum é criado.
- **Não transformar `Sessao`, `PapelAcesso` ou `Permissao` em termos/objetos canônicos** — `Sessao`
  permanece `SEGURANCA_OPERACIONAL`; `PapelAcesso`/`Permissao` permanecem `DIFERIDO`.

## 2. Regras semânticas gerais

- Código canônico é estável; label de exibição pode ser traduzido/ajustado sem alterar o código.
- Sinônimos de UI não criam novos conceitos canônicos.
- Infraestrutura como Neon, PostgreSQL, Vercel ou Prisma nunca é `sistema_origem` tributário.
- `competencia` é `YYYY-MM`; conversão para primeiro dia do mês é semanticamente proibida.
- `status_registro`, `status_processamento_dado` e `status_qualidade_dado` são dimensões diferentes.
- Enum/Ref aberto deve ser representado como tipo aberto/branded ou referência validável, nunca como closed union inventada.
- Referência polimórfica genérica é exceção de auditoria/reconciliação, não padrão de ownership financeiro — **e nunca é mecanismo de derivação de `tenant_id`** (novo nesta versão; ver §11).
- `tipo_titular` permanece termo/enumerador útil para apresentação/intercâmbio derivado, mas não é fonte de verdade de Receita na V1.2/V1.3; a titularidade persistível é determinada pelas FKs PF/PJ com XOR.
- **Identidade tributária (`PessoaFisica`/`PessoaJuridica`) e identidade de acesso (`ContaAcesso`) são eixos distintos e nunca conflados** — `PessoaFisica` não é `ContaAcesso` (princípio já vigente desde a V1.1, reafirmado por `SEC-001` V1.0 §1).
- **`tenant_id` (contexto/fronteira de segurança) e `unidade_economica_id` (contexto econômico/tributário) são conceitos distintos** — nenhum deve ser inferido a partir do outro, nem tratado como sinônimo por coincidência de nome físico ou padrão de uso (novo nesta versão; ver §11).

## 3. Termos canônicos V1.3

Os termos `DST-T001` a `DST-T030` são idênticos à V1.2, sem nenhuma alteração de ID, nome ou
definição — reproduzidos integralmente abaixo para preservar a integridade do dicionário em um
único documento.

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
| **DST-T031** *(novo)* | Tenant | Fronteira técnica de isolamento, segurança e propriedade lógica dos dados; não representa Pessoa Física, Pessoa Jurídica, Unidade Econômica, um usuário individual, nem necessariamente um cliente comercial. |
| **DST-T032** *(novo)* | Evento de Auditoria de Segurança | Registro imutável de evento de segurança (login, falha de autenticação, mudança de permissão, elevação de privilégio, acesso sensível, override, operação administrativa); distinto da auditoria tributária (Conflito de Dados/Revisão Técnica) e de log técnico genérico. |
| **DST-T033** *(novo)* | Contexto/Fronteira de Segurança | Conceito expresso pelo campo transversal `tenant_id`: identifica a fronteira de isolamento à qual um registro pertence. Nunca equivalente a contexto econômico/tributário; nunca derivado de referência polimórfica de auditoria. |
| **DST-T034** *(novo)* | Contexto de Apuração | Conceito expresso pelo campo transversal `unidade_economica_id`: identifica a Unidade Econômica em cujo contexto administrativo/tributário um fato, documento ou resultado é apurado. Distinto do titular tributário (Pessoa Física/Jurídica) e do Tenant de segurança. |
| **DST-T035** *(novo)* | Papel de Acesso | Atributo aberto que descreve o perfil/função de uma concessão de acesso (Conta de Acesso a um Tenant ou a uma Unidade Econômica). Catálogo fechado ainda não aprovado — ver `DST-GAP-015`. |
| **DST-T036** *(novo)* | Concessão de Acesso a Tenant | Estrutura relacional de suporte que materializa a associação N:N entre Conta de Acesso e Tenant, com Papel de Acesso e vigência. |
| **DST-T037** *(novo)* | Restrição de Acesso por Unidade Econômica | Estrutura relacional de suporte que materializa a associação N:N opcional entre Conta de Acesso e Unidade Econômica; restringe o escopo concedido pela Concessão de Acesso a Tenant — nunca o amplia, nunca o substitui, nunca autoriza acesso implícito a outras UEs do mesmo tenant. |

## 4. Enums canônicos aprovados

**Inalterados desde a V1.2 — nenhum enum novo foi criado nesta versão** (o novo campo `papel`,
§3/§11, é Enum/Ref aberto, não um enum fechado; ver `DST-GAP-015`).

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

Inalterado desde a V1.2.

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

Inalterado desde a V1.2.

- `ORIGEM` e `DESTINO` são posições canônicas da relação conforme o COT vigente.
- Cada Vinculo deve possuir exatamente uma extremidade ORIGEM e uma DESTINO.
- Cada extremidade aponta exatamente para um entre UnidadeEconomica, PessoaFisica ou PessoaJuridica.
- `ORIGEM`/`DESTINO` não significam automaticamente pagador/recebedor, controlador/controlado ou sócio/empresa; o significado de negócio vem de `tipo_vinculo` e `papel_vinculo` quando seus catálogos forem aprovados.
- Não usar A/B ou source/target como códigos canônicos sem Change Request.

## 7. Semântica de evidência documental

Inalterado desde a V1.2.

- `ArquivoOrigem` é RAW/evidência preservada; `DocumentoFiscal` é representação fiscal normalizada.
- `DocumentoFiscalArquivoOrigem` permite mais de uma evidência para o mesmo documento e reuso controlado quando aplicável.
- `papel_arquivo` continua aberto: XML, PDF, captura, lote ou versão são exemplos conceituais, não códigos autorizados.
- `arquivo_origem_id` transversal não substitui a associação documental específica; ambos têm papéis distintos.

## 8. Equiparação Hospitalar

Inalterado desde a V1.2.

- Códigos canônicos de elegibilidade permanecem `EH_001_ELEGIVEL`, `EH_002_NAO_ELEGIVEL`, `EH_003_PENDENTE`, `EH_004_REVISAO_TECNICA`.
- Labels de negócio podem ser exibidos como `EH-001 Elegível`, etc.; o código técnico permanece com underscore.
- A classificação é resultado derivado sobre Receita e não atributo permanente da empresa.
- `eh_validada_tecnicamente` é indicador derivado; a decisão humana auditável pertence a RevisaoTecnica.
- O DST não define critérios jurídicos de elegibilidade; isso pertence ao RGT.

## 9. Semântica de conflito e revisão

- `ConflitoDado` representa divergência que precisa de tratamento auditável.
- `ConflitoDadoItem` registra participantes/fontes; `tipo_objeto` e `papel_no_conflito` permanecem abertos.
- Exemplos como candidato, referência, vencedor ou descartado não são códigos canônicos até catálogo aprovado.
- `RevisaoTecnica` registra decisão humana, mas a identidade/autorização do revisor aguarda `OBS-001`.
- Não usar PessoaFisica como identidade de usuário por inferência.
- **`ConflitoDado` e `RevisaoTecnica` agora carregam `tenant_id` (Contexto/Fronteira de Segurança, `DST-T033`) — carimbado pelo processo operacional que cria o registro, nunca derivado de `objeto_id`/`tipo_objeto` ou `objeto_revisado_id`/`tipo_objeto_revisado`. `ConflitoDadoItem` não recebe `tenant_id` próprio — deriva sempre do `ConflitoDado` pai (novo nesta versão; ver §11).**

## 10. Sistema de origem e proveniência

Inalterado desde a V1.2.

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

## 11. Segurança, tenant e contexto de apuração *(nova nesta versão)*

- `Tenant` (`DST-T031`) é a fronteira técnica de isolamento e propriedade lógica dos dados; não é
  `UnidadeEconomica`, não é `PessoaFisica`/`PessoaJuridica`, não é `ContaAcesso`, e não corresponde
  necessariamente a um único cliente comercial (`SEC-001` V1.0 §1).
- `tenant_id` (`MCD-F10002` raiz, `MCD-F10003` transversal; `DST-T033`) responde exclusivamente "a
  qual fronteira de segurança este registro pertence" — nunca "de que contexto econômico/
  tributário trata este registro" (essa pergunta pertence a `unidade_economica_id`, `DST-T034`).
  `MCD-F10002` e `MCD-F10003` são IDs MCD distintos (âncora raiz × metadado transversal
  carimbado operacionalmente) mas compartilham a mesma categoria semântica DST (`DST-T033`) — um
  termo DST pode descrever uma família semântica compartilhada por mais de um campo MCD, sem
  implicar que os campos MCD sejam o mesmo conceito canônico entre si.
- `unidade_economica_id` transversal (`MCD-F10004`, `DST-T034`) responde "sob qual Unidade
  Econômica este fato/documento/resultado é administrado" — um eixo adicional e distinto da
  titularidade tributária (`PessoaFisica`/`PessoaJuridica` via XOR já vigente), nunca um
  substituto dela.
- Identidade tributária (`PessoaFisica`/`PessoaJuridica`, `DST-T002`/`T003`) e identidade de
  acesso (`ContaAcesso`, `DST-T021`) permanecem eixos distintos — reafirmação do princípio já
  vigente (`SEC-001` V1.0 §1).
- `PessoaFisica`, `PessoaJuridica` e `FontePagadora` são identidades globais compartilháveis entre
  tenants — nenhuma delas recebe `tenant_id` ou `unidade_economica_id` próprio; o acesso aos fatos
  relacionados é determinado pelo contexto tenant-scoped **desses fatos**, nunca pela simples
  existência de vínculo com a identidade global (`SEC-001` V1.0 §3).
- `ContaAcesso ↔ Tenant` (`DST-T036`) é uma concessão explícita de acesso a um Tenant inteiro;
  nenhuma concessão é implícita — negar por padrão.
- `ContaAcesso ↔ UnidadeEconomica` (`DST-T037`) é uma restrição opcional que **restringe** o
  escopo já concedido pelo Tenant — nunca o **amplia**, nunca o **substitui**, e nunca autoriza
  acesso implícito a outras UEs do mesmo tenant quando a conta possuir restrição específica.
- `papel` (`MCD-F10005`, `DST-T035`) permanece Enum/Ref aberto — ver `DST-GAP-015`. Nenhum
  catálogo fechado de papéis é criado por esta versão.
- A referência polimórfica de auditoria (`objeto_id`/`tipo_objeto` em `ConflitoDadoItem`;
  `objeto_revisado_id`/`tipo_objeto_revisado` em `RevisaoTecnica`) permanece exclusivamente
  mecanismo de auditoria/reconciliação — **nunca fonte de `tenant_id`**. O `tenant_id` de
  `ConflitoDado`/`RevisaoTecnica` é sempre carimbado pelo processo operacional que cria o
  registro, nunca inferido do objeto referenciado (`SEC-001` V1.0 §6, §8).
- `Sessao` permanece `SEGURANCA_OPERACIONAL` — não é termo canônico desta versão; sua semântica
  concreta depende do provedor de autenticação a ser escolhido.
- `PapelAcesso` e `Permissao` como objetos/termos canônicos separados permanecem `DIFERIDO` — não
  incorporados por esta versão.

### 11.1 Verificação semântica de `MCD-F10004` (`unidade_economica_id` transversal)

Verificação, hospedeiro a hospedeiro, de que os seis objetos que recebem `MCD-F10004`
compartilham exatamente o mesmo conceito canônico ("Unidade Econômica em cujo contexto
econômico/tributário o registro é administrado, distinto do titular tributário"):

| Objeto | Categoria (MCD-001 §13) | A pergunta respondida é a mesma? |
|---|---|---|
| Receita | Fato canônico | Sim — "sob qual UE este ingresso é apurado". |
| ContribuicaoPrevidenciaria | Fato canônico | Sim — mesma pergunta. |
| VinculoPrevidenciario | Relação/fonte previdenciária | Sim — mesma pergunta, aplicada a uma relação em vez de um fato puro; não altera o significado do campo. |
| EventoIRPF | Fato canônico | Sim — mesma pergunta. |
| DocumentoFiscal | Evidência/documento normalizado | Sim — mesma pergunta (nota de timing abaixo). |
| ResultadoCalculo | Resultado derivado | Sim — mesma pergunta; deve ser consistente com `CenarioTributario.unidade_economica_id` quando ambos presentes. |

**Resultado: semântica uniforme confirmada.** O campo responde exatamente à mesma pergunta nos
seis hospedeiros, independentemente da categoria ontológica do objeto (fato, relação, documento
ou resultado derivado) — mesmo padrão já validado para `registrado_em` (`MCD-F9007`), aplicado
uniformemente a 16 objetos de categorias diferentes. **Nenhuma inconsistência semântica
encontrada; não há necessidade de reconciliação no MCD.**

**Nota não bloqueante (diferença de workflow, não de significado):** o *momento* em que
`unidade_economica_id` é atribuído difere entre os hospedeiros por posição no pipeline
RAW→Canonical, não por diferença de significado — `DocumentoFiscal` recebe o campo de forma
própria (não apenas derivada de uma `Receita` associada) porque o documento fiscal frequentemente
chega antes de qualquer `Receita` ser lançada; os demais cinco objetos recebem o campo diretamente
no momento da criação do fato/resultado. Esta é uma diferença de **atribuição operacional**, a
detalhar no `CDC-001` (obrigatoriedade por operação) e no `ADR` físico (trigger/validação) — não
uma divergência semântica a corrigir no MCD.

## 12. Gaps semânticos V1.3

Os gaps `DST-GAP-001` a `DST-GAP-014` são idênticos à V1.2 — nenhum é fechado por inferência
nesta versão.

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
| DST-GAP-011 | papel_arquivo | Enum/Ref aberto. |
| DST-GAP-012 | tipo_objeto de ConflitoDadoItem | Enum/Ref aberto e restrito ao domínio de auditoria. |
| DST-GAP-013 | papel_no_conflito | Enum/Ref aberto. |
| DST-GAP-014 | identidade do revisor | Depende de `OBS-001` (`SEC-001` já aprovado, mas não substitui `OBS-001`); não modelar como PessoaFisica por inferência. |
| **DST-GAP-015** *(novo)* | papel (`MCD-F10005`, `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica`) | Enum/Ref aberto; catálogo de papéis de acesso ainda não aprovado; não fechar por inferência. Nenhum enum foi criado. |

### Gaps resolvidos em versões anteriores (preservado da V1.2, sem alteração)
- `DST-GAP-004` foi resolvido estruturalmente na V1.2: os campos polimórficos de origem/destino foram removidos e substituídos por VinculoExtremidade.
- A contradição da antiga `DST-E009 status_qualidade_dado` foi resolvida na V1.2: E009 passou a significar `status_processamento_dado`; qualidade recebeu E011.
- `lado_extremidade` deixou de ser gap na V1.2 e passou a `DST-E012`.

### Nenhum gap resolvido nesta versão
`DST-GAP-001` a `DST-GAP-014` permanecem exatamente na mesma situação da V1.2 — esta versão
apenas **adiciona** `DST-GAP-015`, sem fechar nenhum gap preexistente por inferência.

## 13. Política para TypeScript, Prisma, API e IA

```yaml
dst_policy:
  version: 1.3
  source_of_truth: docs/DST-001_CONTIFISC_Dicionario_Semantico_Tributario_V1.3.md
  supersedes: DST-001-v1.2
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
    polymorphic_tenant_derivation: prohibited
  auth_identity_equals_pessoa_fisica: false
  tenant_semantics:
    tenant_id_equals_unidade_economica_id: false
    tenant_id_root_and_transversal_share_mcd_id: false
    tenant_equals_pessoa_fisica_ou_juridica: false
    tenant_equals_conta_acesso: false
    unidade_economica_authorization: restricts_only
    unidade_economica_authorization_amplia: false
    unidade_economica_authorization_substitui: false
    papel_is_closed_enum: false
    papel_acesso_permissao_objects: deferred
    sessao_object: security_operational_not_canonical
```

## 14. Impacto sobre a Fase 1

- Nenhuma alteração é necessária nas interfaces UnidadeEconomica, PessoaFisica e PessoaJuridica já implementadas.
- `regime_tributario` e `status_registro` mantêm os mesmos códigos das versões anteriores.
- `conselho_profissional` e `especialidade_saude` continuam abertos/branded.
- Não implementar os novos objetos/estruturas/campos de segurança até a autorização da fase física correspondente (CDC/ADR de segurança).
- Este DST não autoriza Prisma schema ou migration.

## 15. Critérios de aceite

- [x] Semântica sincronizada com COT-001 V1.2 e MCD-001 V1.3.
- [x] Todos os termos, enums e gaps da V1.2 preservados sem alteração.
- [x] `Tenant` e `EventoAuditoriaSeguranca` com definição semântica própria (`DST-T031`/`T032`).
- [x] `tenant_id` e `unidade_economica_id` distinguidos semanticamente (`DST-T033`/`T034`).
- [x] Identidade tributária × identidade de acesso reafirmada.
- [x] `ContaAcesso ↔ Tenant` e `ContaAcesso ↔ UnidadeEconomica` com semântica própria (`DST-T036`/`T037`), incluindo a regra de que UE restringe e nunca amplia/substitui.
- [x] `papel` registrado como `DST-GAP-015`, aberto — nenhum enum criado.
- [x] `Sessao` permanece `SEGURANCA_OPERACIONAL`; `PapelAcesso`/`Permissao` permanecem `DIFERIDO` — nenhum promovido a canônico.
- [x] `MCD-F10004` verificado como semanticamente uniforme nos 6 hospedeiros (§11.1).
- [x] Referência polimórfica de auditoria reafirmada como nunca-fonte-de-tenant.
- [x] Nenhum gap anterior fechado por inferência.
- [x] Fase 1 permanece compatível.

## 16. Próximo documento

Com `COT-001` V1.2, `MCD-001` V1.3 e `DST-001` V1.3 sincronizados, a ordem documental oficial
(`SEC-CHANGE-REQUEST-001` V1.1) determina os próximos passos: **`CDC-001` V1.3** (contratos —
direção, obrigatoriedade, mutabilidade dos novos campos/objetos) → **reconciliação** (auditoria
cruzada COT × MCD × CDC × DST) → **`ADR-002`** (decisões físicas de segurança/tenant, incluindo a
FK composta e a estratégia de RLS conceitual). Somente após aprovação do ADR poderá ser
autorizada a nova migration física.

---
**Governança:** DST-001 V1.3 é o dicionário semântico vigente. DST V1.2/V1.1/V1.0 permanecem apenas como histórico `SUPERSEDED`.
