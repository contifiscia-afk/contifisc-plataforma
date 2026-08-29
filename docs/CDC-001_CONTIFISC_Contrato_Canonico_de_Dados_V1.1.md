# CDC-001 --- Contrato Canônico de Dados da CONTIFISC

**Versão:** 1.1\
**Status:** APROVADO --- sincronizado com MCD-001 V1.1\
**Supersede:** CDC-001 V1.0\
**Dependências:** CAF-001, MCD-001 V1.1, DST-001 V1.0 (semântica;
sincronização nominal V1.1 pendente), COT-001 V1.0\
**Consumidores:** APIs, eventos, integrações, types, repositórios, ATI,
GTI, MIT e Skills

> **Função do CDC:** definir as fronteiras técnicas de entrada, saída,
> validação, mutabilidade, compatibilidade, proveniência e
> reprodutibilidade. O CDC não cria fatos, objetos ou regras tributárias
> fora do MCD/COT/RGT.

## 1. Alterações da V1.1

-   Sincronização integral da nomenclatura com MCD-001 V1.1: `id`,
    `nome`, `cpf`, `cnpj`, `valor_*`, `data_*`, `competencia`,
    `status_*`, etc.
-   Competência contratual fixada como string opaca validada `YYYY-MM`;
    conversão para primeiro dia do mês é proibida no domínio.
-   `Vinculo` passa a ter origem, destino, tipos, papel e vigência
    formalizados.
-   Titularidade explícita de Receita, IRPF e Previdenciário.
-   Novos contratos para FontePagadora, VinculoPrevidenciario,
    ResultadoCalculo, ArquivoOrigem, ConflitoDado e RevisaoTecnica.
-   Envelope de proveniência alinhado aos MCD-F9001..F9009.
-   ContaAcesso/CredencialAcesso continuam fora do CDC tributário até
    SEC-001.
-   Foram identificadas três lacunas residuais que exigem
    MCD-CHANGE-REQUEST-002 antes da persistência completa: identidade
    própria de ClassificacaoEquiparacaoHospitalar; associação N:N
    Receita↔DocumentoFiscal; referências dos registros envolvidos em
    ConflitoDado.

## 2. Princípios obrigatórios

-   Contract-first: API/evento/DTO deriva do contrato aprovado.
-   Vendor-neutral: nenhum payload canônico expõe Questor, Neon ou
    schema proprietário.
-   Backward compatibility: mudança incompatível exige major version.
-   Fact vs derived: resultado não sobrescreve fato.
-   Provenance by default: origem/evidência são preservadas.
-   Temporal awareness: competência, fato, emissão, importação, registro
    e vigência são distintos.
-   Human review: decisões revisáveis preservam histórico.
-   No silent conflict resolution: conflito é objeto auditável.
-   No schema invention: campo/relação ausente gera Change Request.

## 3. Classificação de campos e mutabilidade

  -----------------------------------------------------------------------
  Classificação                       Regra
  ----------------------------------- -----------------------------------
  required                            Obrigatório naquela operação.

  conditional                         Obrigatório quando a condição do
                                      contrato for atendida.

  optional                            Ausência não vira zero/string
                                      vazia.

  input                               Aceito na entrada.

  output                              Produzido pelo sistema; não implica
                                      mutabilidade.

  input/output                        Aceito e devolvido conforme
                                      política.
  -----------------------------------------------------------------------

  Política           Uso
  ------------------ -------------------------------------------------------
  immutable          Criado uma vez.
  immutable_fact     Fato de origem; correção gera nova versão/ajuste.
  mutable            Atualizável com auditoria.
  temporal           Mudança preserva vigência/histórico.
  reviewable         Pode ser revisado/classificado preservando histórico.
  versioned_result   Resultado ligado a inputs/regras/engine.
  restricted         Alteração/exposição exige controle reforçado.

## 4. Envelope canônico V1.1

``` yaml
canonical_envelope:
  contract_id: CDC-REC-001
  contract_version: 1.1.0
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
  quality:
    status_qualidade_dado: <canonical_quality_status|null>
  correlation_id: <uuid|null>
  registrado_em: <timestamp>
  versao_schema: <semver>
  payload: {}
```

`unidade_economica_id` e `sujeito_id` no envelope são **contexto de
transporte**, não autorização para adicionar FKs homônimas a todos os
objetos persistidos. Persistência segue MCD/COT.

## 5. Tipos e validações gerais

-   UUID: identificador interno; IDs externos permanecem na
    proveniência.
-   Dinheiro: decimal exato; `float` proibido.
-   Percentual: Decimal(7,4); convenção MCD V1.1 (32,0000 = 32%).
-   Competência: regex/validação equivalente a `YYYY-MM`, mês 01..12;
    `2026-08-01` é inválido como competência contratual.
-   Date: `YYYY-MM-DD`; Timestamp: ISO-8601 offset-aware e persistência
    UTC.
-   CPF/CNPJ: somente dígitos; máscara pertence à UI.
-   Enum: apenas código publicado no DST; até DST V1.1, preservar a
    semântica da V1.0 sem reintroduzir nomes legados de campo.
-   `null`, zero, vazio e não aplicável são estados distintos.
-   Logs devem minimizar CPF/CNPJ/nome e nunca expor credenciais.

## 6. Erros contratuais

  -------------------------------------------------------------------------
  Código                  Categoria                 Uso
  ----------------------- ------------------------- -----------------------
  CDC-ERR-001             VALIDATION_REQUIRED       Campo obrigatório
                                                    ausente.

  CDC-ERR-002             VALIDATION_FORMAT         Formato inválido.

  CDC-ERR-003             VALIDATION_RANGE          Valor fora da faixa.

  CDC-ERR-004             ENUM_UNKNOWN              Enum não reconhecido.

  CDC-ERR-005             CONTRACT_VERSION          Versão incompatível.

  CDC-ERR-006             DUPLICATE_SOURCE_RECORD   Possível duplicidade.

  CDC-ERR-007             SOURCE_CONFLICT           Fontes divergentes.

  CDC-ERR-008             IMMUTABLE_FIELD           Tentativa de
                                                    sobrescrita.

  CDC-ERR-009             MCD_FIELD_UNKNOWN         Campo não registrado.

  CDC-ERR-010             REVIEW_REQUIRED           Revisão técnica
                                                    necessária.

  CDC-ERR-011             RELATION_NOT_MODELED      Relação requerida ainda
                                                    não formalizada no MCD.

  CDC-ERR-012             IDENTITY_NOT_MODELED      Objeto canônico sem
                                                    identidade persistível
                                                    formalizada.
  -------------------------------------------------------------------------

## 7. Contratos canônicos V1.1 (17 contratos)

### CDC-UE-001 --- Unidade Econômica

**Domínio:** `DOM-CORE`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-001`\
**Identidade:** `id`\
**Objetivo:** Representar o contexto econômico/tributário agregador sem
substituir CPF ou CNPJ.

  ---------------------------------------------------------------------------------------------
  Campo             MCD         Direção        Obrigatoriedade   Produtor típico Mutabilidade
  ----------------- ----------- -------------- ----------------- --------------- --------------
  id                MCD-F0001   output         required          system          immutable

  nome              MCD-F0002   input/output   required          manual          mutable

  status_registro   MCD-F0003   input/output   required          system/manual   mutable

  criado_em         MCD-F0004   output         required          system          immutable

  atualizado_em     MCD-F0005   output         required          system          mutable
  ---------------------------------------------------------------------------------------------

Regras: - UE é contexto organizador interno, não sujeito tributário. -
PF/PJ vinculam-se à UE por `Vinculo`; não embutir UE obrigatória
diretamente nessas entidades. - Quando houver fatos relacionados,
inativação substitui exclusão destrutiva.

### CDC-PER-001 --- Pessoa Física

**Domínio:** `DOM-PER`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-002`\
**Identidade:** `id`\
**Objetivo:** Representar pessoa natural em papéis tributários,
societários ou profissionais.

  ------------------------------------------------------------------------------------------------------
  Campo                      MCD         Direção        Obrigatoriedade   Produtor típico Mutabilidade
  -------------------------- ----------- -------------- ----------------- --------------- --------------
  id                         MCD-F1001   output         required          system          immutable

  cpf                        MCD-F1002   input/output   conditional       manual/import   restricted

  nome                       MCD-F1003   input/output   required          manual/import   mutable

  data_nascimento            MCD-F1004   input/output   optional          manual/import   mutable

  conselho_profissional      MCD-F1005   input/output   optional          manual          mutable

  registro_profissional      MCD-F1006   input/output   optional          manual          mutable

  uf_registro_profissional   MCD-F1007   input/output   optional          manual          mutable

  especialidade_saude        MCD-F1008   input/output   optional          manual          mutable
  ------------------------------------------------------------------------------------------------------

Regras: - CPF, quando informado, usa 11 dígitos e validação oficial de
formato/dígitos. - Qualificação profissional é condicional; nem toda PF
é profissional da saúde. - PessoaFisica não é identidade de
autenticação.

### CDC-EMP-001 --- Pessoa Jurídica

**Domínio:** `DOM-EMP`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-003`\
**Identidade:** `id`\
**Objetivo:** Representar pessoa jurídica e atributos
cadastrais/tributários temporalmente válidos.

  -----------------------------------------------------------------------------------------------
  Campo               MCD         Direção        Obrigatoriedade   Produtor típico Mutabilidade
  ------------------- ----------- -------------- ----------------- --------------- --------------
  id                  MCD-F2001   output         required          system          immutable

  cnpj                MCD-F2002   input/output   conditional       manual/import   restricted

  razao_social        MCD-F2003   input/output   optional          manual/import   mutable

  regime_tributario   MCD-F2004   input/output   conditional       manual/import   temporal

  cnae_principal      MCD-F2005   input/output   optional          manual/import   temporal

  data_abertura       MCD-F2006   input/output   optional          manual/import   mutable

  municipio_ibge      MCD-F2007   input/output   optional          manual/import   temporal
  -----------------------------------------------------------------------------------------------

Regras: - Regime tributário/CNAE são temporalmente sensíveis. - CNPJ é
identificador de negócio, não PK interna. - Mudança cadastral relevante
preserva histórico/vigência.

### CDC-REL-001 --- Vínculo

**Domínio:** `DOM-REL`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-004`\
**Identidade:** `id`\
**Objetivo:** Representar relações entre objetos canônicos com tipo,
papel, atributos e vigência.

  ----------------------------------------------------------------------------------------------------------------
  Campo                                MCD         Direção        Obrigatoriedade   Produtor típico Mutabilidade
  ------------------------------------ ----------- -------------- ----------------- --------------- --------------
  id                                   MCD-F2501   output         required          system          immutable

  tipo_vinculo                         MCD-F2502   input/output   required          manual/import   temporal

  percentual_participacao_societaria   MCD-F2503   input/output   optional          manual/import   temporal

  vigencia_inicio                      MCD-F2504   input/output   optional          manual/import   temporal

  vigencia_fim                         MCD-F2505   input/output   optional          manual/import   temporal

  objeto_origem_id                     MCD-F2506   input/output   required          system/manual   temporal

  tipo_objeto_origem                   MCD-F2507   input/output   required          system/manual   temporal

  objeto_destino_id                    MCD-F2508   input/output   required          system/manual   temporal

  tipo_objeto_destino                  MCD-F2509   input/output   required          system/manual   temporal

  papel_vinculo                        MCD-F2510   input/output   conditional       manual/system   temporal
  ----------------------------------------------------------------------------------------------------------------

Regras: - Vínculo é first-class object; não substituir por FKs ad-hoc. -
Participação societária só é aplicável a vínculos compatíveis. -
Origem/destino devem referenciar tipos canônicos permitidos pelo
COT/DST. - `vigencia_fim` não pode anteceder `vigencia_inicio`.

### CDC-REC-001 --- Receita Canônica

**Domínio:** `DOM-REC`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-005`\
**Identidade:** `id`\
**Objetivo:** Normalizar receitas de PF/PJ para uso fiscal, EqHop, IRPF,
planejamento e analytics.

  -----------------------------------------------------------------------------------------------------------
  Campo                 MCD         Direção        Obrigatoriedade   Produtor típico         Mutabilidade
  --------------------- ----------- -------------- ----------------- ----------------------- ----------------
  id                    MCD-F3001   output         required          system                  immutable

  valor_receita_bruta   MCD-F3002   input/output   conditional       import/manual           immutable_fact

  data_emissao          MCD-F3003   input/output   optional          import/manual           immutable_fact

  competencia           MCD-F3004   input/output   conditional       import/manual           immutable_fact

  fonte_receita         MCD-F3005   input/output   conditional       classification/manual   reviewable

  tipo_titular          MCD-F3006   input/output   required          system/classification   reviewable

  fonte_pagadora_id     MCD-F3007   input/output   optional          import/manual           reviewable

  valor_retencoes       MCD-F3008   input/output   optional          import/manual           immutable_fact

  titular_id            MCD-F3009   input/output   required          system/classification   reviewable
  -----------------------------------------------------------------------------------------------------------

Regras: - Competência é `YYYY-MM`; não é emissão nem pagamento. -
`titular_id` deve ser interpretado junto com `tipo_titular`. -
Classificação derivada nunca sobrescreve o fato original. - Associação
N:N Receita↔DocumentoFiscal está prevista no COT, mas ainda carece de
objeto/campos MCD próprios; não inventar join table.

### CDC-FIS-001 --- Documento Fiscal

**Domínio:** `DOM-FIS`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-006`\
**Identidade:** `id`\
**Objetivo:** Representar documento fiscal normalizado sem depender do
layout do emissor ou ERP.

  --------------------------------------------------------------------------------------------------------
  Campo                      MCD         Direção        Obrigatoriedade   Produtor típico Mutabilidade
  -------------------------- ----------- -------------- ----------------- --------------- ----------------
  id                         MCD-F4001   output         required          system          immutable

  tipo_documento_fiscal      MCD-F4002   input/output   required          parser/manual   immutable_fact

  numero_documento_fiscal    MCD-F4003   input/output   optional          parser/manual   immutable_fact

  chave_documento_fiscal     MCD-F4004   input/output   optional          parser/api      immutable_fact

  codigo_servico_fiscal      MCD-F4005   input/output   optional          parser/api      immutable_fact

  descricao_servico_fiscal   MCD-F4006   input/output   optional          parser/api      immutable_fact

  valor_documento_fiscal     MCD-F4007   input/output   optional          parser/api      immutable_fact

  arquivo_origem_id          MCD-F4008   input/output   optional          system          immutable
  --------------------------------------------------------------------------------------------------------

Regras: - Documento bruto deve ser preservado/referenciado quando
disponível. - Chave externa não tem unicidade universal sem
contexto/tipo. - Parser preserva valor bruto e lineage de transformação.

### CDC-EH-001 --- Classificação de Equiparação Hospitalar

**Domínio:** `DOM-EH`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-008`\
**Identidade:** `PENDENTE-MCD`\
**Objetivo:** Registrar resultado derivado e versionado de
elegibilidade/segregação com rastreabilidade.

  ------------------------------------------------------------------------------------------------------------------------------------
  Campo                                         MCD         Direção        Obrigatoriedade   Produtor típico        Mutabilidade
  --------------------------------------------- ----------- -------------- ----------------- ---------------------- ------------------
  status_elegibilidade_equiparacao_hospitalar   MCD-F5001   output         conditional       rule_engine/reviewer   versioned_result

  percentual_receita_elegivel                   MCD-F5002   output         optional          rule_engine/reviewer   versioned_result

  valor_receita_elegivel                        MCD-F5003   output         optional          calculation            versioned_result

  valor_receita_nao_elegivel                    MCD-F5004   output         optional          calculation            versioned_result

  percentual_confianca_classificacao            MCD-F5005   output         optional          classifier             versioned_result

  validacao_tecnica                             MCD-F5006   input/output   optional          reviewer               versioned_result

  receita_id                                    MCD-F5007   input/output   required          system/engine          versioned_result

  regra_versao_id                               MCD-F5008   output         conditional       engine                 versioned_result
  ------------------------------------------------------------------------------------------------------------------------------------

Regras: - NFS-e/CNAE/código de serviço isoladamente não determinam
elegibilidade. - Resultado referencia Receita e regra versionada. - IA
pode sugerir; decisão segue RGT e revisão aplicável. - COT trata a
classificação como objeto com histórico, mas MCD V1.1 não possui `id`
próprio para esse objeto. Persistência fica bloqueada até
MCD-CHANGE-REQUEST-002.

### CDC-PRE-001 --- Contribuição Previdenciária

**Domínio:** `DOM-PRE`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-009`\
**Identidade:** `id`\
**Objetivo:** Normalizar contribuições por PF, vínculo e competência.

  ------------------------------------------------------------------------------------------------------------------
  Campo                        MCD         Direção        Obrigatoriedade   Produtor típico       Mutabilidade
  ---------------------------- ----------- -------------- ----------------- --------------------- ------------------
  id                           MCD-F6001   output         required          system                immutable

  valor_inss_recolhido         MCD-F6002   input/output   conditional       cnis/payroll/manual   immutable_fact

  valor_salario_contribuicao   MCD-F6003   input/output   optional          cnis/payroll          immutable_fact

  valor_teto_previdenciario    MCD-F6004   output         conditional       legal_table           versioned_result

  valor_excedente_inss         MCD-F6005   output         optional          calculation           versioned_result

  vinculo_previdenciario_id    MCD-F6006   input/output   optional          cnis/manual           temporal

  pessoa_fisica_id             MCD-F6007   input/output   required          system                reviewable
  ------------------------------------------------------------------------------------------------------------------

Regras: - Múltiplas fontes podem coexistir na mesma competência. -
CNIS/folha não se sobrescrevem silenciosamente; divergência gera
conflito. - Teto/excedente devem ser reproduzíveis por competência e
regra.

### CDC-PREV-001 --- Vínculo Previdenciário

**Domínio:** `DOM-PRE`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-010`\
**Identidade:** `id`\
**Objetivo:** Representar fonte/vínculo previdenciário da PF com
vigência.

  ---------------------------------------------------------------------------------------------------------
  Campo                         MCD         Direção        Obrigatoriedade   Produtor típico Mutabilidade
  ----------------------------- ----------- -------------- ----------------- --------------- --------------
  id                            MCD-F6101   output         required          system          immutable

  pessoa_fisica_id              MCD-F6102   input/output   required          system/manual   temporal

  tipo_vinculo_previdenciario   MCD-F6103   input/output   required          cnis/manual     temporal

  vigencia_inicio               MCD-F6104   input/output   optional          cnis/manual     temporal

  vigencia_fim                  MCD-F6105   input/output   optional          cnis/manual     temporal
  ---------------------------------------------------------------------------------------------------------

Regras: - Uma PF pode possuir múltiplos vínculos simultâneos. - Vigência
deve ser preservada; encerramento não apaga histórico.

### CDC-IRP-001 --- Evento IRPF/Carnê-Leão

**Domínio:** `DOM-IRP`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-011`\
**Identidade:** `id`\
**Objetivo:** Normalizar fatos/resultados relevantes ao IRPF de forma
independente de PJ.

  ---------------------------------------------------------------------------------------------------------------------
  Campo                         MCD         Direção        Obrigatoriedade   Produtor típico         Mutabilidade
  ----------------------------- ----------- -------------- ----------------- ----------------------- ------------------
  id                            MCD-F7001   output         required          system                  immutable

  tipo_rendimento_irpf          MCD-F7002   input/output   conditional       classification/manual   reviewable

  valor_rendimento_tributavel   MCD-F7003   input/output   optional          import/manual           immutable_fact

  valor_rendimento_isento       MCD-F7004   input/output   optional          import/manual           immutable_fact

  valor_deducao_irpf            MCD-F7005   input/output   optional          import/manual           reviewable

  valor_livro_caixa             MCD-F7006   input/output   optional          carne/manual            reviewable

  valor_irpf_retido             MCD-F7007   input/output   optional          informe                 immutable_fact

  valor_irpf_projetado          MCD-F7008   output         optional          calculation             versioned_result

  pessoa_fisica_id              MCD-F7009   input/output   required          system                  reviewable

  fonte_pagadora_id             MCD-F7010   input/output   optional          import/manual           reviewable
  ---------------------------------------------------------------------------------------------------------------------

Regras: - Tributável, isento, dedução e retenção são conceitos
distintos. - Projeções não sobrescrevem fatos. - Classificação mantém
origem/evidência/versão de regra.

### CDC-FPG-001 --- Fonte Pagadora

**Domínio:** `DOM-REC`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-012`\
**Identidade:** `id`\
**Objetivo:** Normalizar a origem pagadora de receitas e rendimentos.

  ----------------------------------------------------------------------------------------------------------
  Campo                  MCD         Direção        Obrigatoriedade   Produtor típico         Mutabilidade
  ---------------------- ----------- -------------- ----------------- ----------------------- --------------
  id                     MCD-F7201   output         required          system                  immutable

  tipo_fonte_pagadora    MCD-F7202   input/output   required          manual/classification   reviewable

  identificador_fiscal   MCD-F7203   input/output   optional          manual/import           restricted

  nome                   MCD-F7204   input/output   optional          manual/import           mutable
  ----------------------------------------------------------------------------------------------------------

Regras: - FontePagadora não substitui PessoaFisica/PessoaJuridica; é um
objeto de origem de pagamento. - Identificador fiscal pode ser ausente
quando a fonte não puder ser plenamente identificada.

### CDC-PLN-001 --- Cenário Tributário

**Domínio:** `DOM-PLN`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-013`\
**Identidade:** `id`\
**Objetivo:** Representar simulações isoladas dos fatos oficiais.

  ---------------------------------------------------------------------------------------------------------------------
  Campo                                 MCD         Direção        Obrigatoriedade   Produtor típico Mutabilidade
  ------------------------------------- ----------- -------------- ----------------- --------------- ------------------
  id                                    MCD-F8001   output         required          system          immutable

  nome                                  MCD-F8002   input/output   required          manual/system   mutable

  valor_carga_tributaria_projetada      MCD-F8003   output         optional          calculation     versioned_result

  valor_economia_tributaria_projetada   MCD-F8004   output         optional          calculation     versioned_result

  unidade_economica_id                  MCD-F8005   input/output   required          system          reviewable
  ---------------------------------------------------------------------------------------------------------------------

Regras: - Cenário é sandbox; não altera fatos. - Resultados preservam
premissas, inputs e versões de regras. - Comparações exigem base
temporal compatível ou alerta.

### CDC-CAL-001 --- Resultado de Cálculo

**Domínio:** `DOM-SYS`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-014`\
**Identidade:** `id`\
**Objetivo:** Registrar cálculo reproduzível com snapshot de inputs,
motor e regras.

  -----------------------------------------------------------------------------------------------------
  Campo                   MCD         Direção        Obrigatoriedade   Produtor típico   Mutabilidade
  ----------------------- ----------- -------------- ----------------- ----------------- --------------
  id                      MCD-F8201   output         required          system            immutable

  cenario_tributario_id   MCD-F8202   input/output   optional          system            reviewable

  input_snapshot_hash     MCD-F8203   output         required          engine            immutable

  engine_id               MCD-F8204   output         required          engine            immutable

  engine_version          MCD-F8205   output         required          engine            immutable

  rule_set_id             MCD-F8206   output         required          engine            immutable

  rule_set_version        MCD-F8207   output         required          engine            immutable

  calculado_em            MCD-F8208   output         required          engine            immutable

  status_revisao          MCD-F8209   input/output   optional          engine/reviewer   reviewable
  -----------------------------------------------------------------------------------------------------

Regras: - Mesmo conjunto de inputs/regras/engine deve ser auditavelmente
reproduzível. - Resultado não sobrescreve fatos canônicos. - Cenário é
opcional porque cálculos também podem ocorrer fora de simulação.

### CDC-ARQ-001 --- Arquivo de Origem

**Domínio:** `DOM-SYS`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-007`\
**Identidade:** `id`\
**Objetivo:** Preservar referência e integridade da evidência RAW usada
na ingestão/reprocessamento.

  --------------------------------------------------------------------------------------------------
  Campo                      MCD         Direção        Obrigatoriedade   Produtor    Mutabilidade
                                                                          típico      
  -------------------------- ----------- -------------- ----------------- ----------- --------------
  id                         MCD-F8401   output         required          system      immutable

  nome_arquivo               MCD-F8402   input/output   optional          ingestion   immutable

  hash_conteudo              MCD-F8403   output         required          ingestion   immutable

  tipo_mime                  MCD-F8404   input/output   optional          ingestion   immutable

  armazenamento_referencia   MCD-F8405   output         required          ingestion   restricted
  --------------------------------------------------------------------------------------------------

Regras: - Conteúdo bruto não deve ser alterado em normalizações
posteriores. - Referência de armazenamento não deve expor credenciais ou
URL sensível. - Hash suporta integridade, deduplicação e
reprocessamento.

### CDC-CFD-001 --- Conflito de Dados

**Domínio:** `DOM-SYS`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-015`\
**Identidade:** `id`\
**Objetivo:** Registrar divergências entre fontes/fatos candidatos sem
apagar evidências.

  ----------------------------------------------------------------------------------------------
  Campo             MCD         Direção        Obrigatoriedade   Produtor típico  Mutabilidade
  ----------------- ----------- -------------- ----------------- ---------------- --------------
  id                MCD-F8601   output         required          system           immutable

  status_conflito   MCD-F8602   input/output   required          reconciliation   reviewable

  tipo_conflito     MCD-F8603   input/output   required          reconciliation   reviewable

  descricao         MCD-F8604   input/output   optional          reconciliation   reviewable
  ----------------------------------------------------------------------------------------------

Regras: - Conflito não resolve silenciosamente a divergência. - As
referências exatas aos registros conflitantes ainda não estão modeladas
no MCD V1.1; persistência completa aguarda MCD-CHANGE-REQUEST-002.

### CDC-REV-001 --- Revisão Técnica

**Domínio:** `DOM-SYS`\
**Versão:** `1.1.0`\
**COT:** `COT-OBJ-016`\
**Identidade:** `id`\
**Objetivo:** Registrar decisão humana auditável sobre objeto,
classificação, conflito ou resultado.

  ------------------------------------------------------------------------------------------------
  Campo                  MCD         Direção        Obrigatoriedade   Produtor    Mutabilidade
                                                                      típico      
  ---------------------- ----------- -------------- ----------------- ----------- ----------------
  id                     MCD-F8701   output         required          system      immutable

  objeto_revisado_id     MCD-F8702   input/output   required          system      immutable

  tipo_objeto_revisado   MCD-F8703   input/output   required          system      immutable

  status_revisao         MCD-F8704   input/output   required          reviewer    reviewable

  justificativa          MCD-F8705   input/output   conditional       reviewer    immutable_fact

  revisado_em            MCD-F8706   output         required          system      immutable
  ------------------------------------------------------------------------------------------------

Regras: - Revisão preserva decisão, momento e justificativa aplicável. -
Identidade do revisor/autorização pertence a SEC/OBS e não será
inventada neste contrato.

### CDC-SYS-001 --- Metadados de Proveniência

**Domínio:** `DOM-SYS`\
**Versão:** `1.1.0`\
**COT:** `transversal`\
**Identidade:** `metadados transversais`\
**Objetivo:** Padronizar origem, qualidade, correlação, temporalidade e
versão para dados canônicos.

  ----------------------------------------------------------------------------------------------------------
  Campo                   MCD         Direção        Obrigatoriedade   Produtor típico      Mutabilidade
  ----------------------- ----------- -------------- ----------------- -------------------- ----------------
  sistema_origem          MCD-F9001   input/output   conditional       gateway/system       immutable_fact

  identificador_origem    MCD-F9002   input/output   optional          gateway              immutable_fact

  importado_em            MCD-F9003   output         optional          gateway              immutable

  status_qualidade_dado   MCD-F9004   input/output   optional          validator/reviewer   reviewable

  versao_schema           MCD-F9005   input/output   conditional       system/gateway       immutable_fact

  correlation_id          MCD-F9006   input/output   optional          system/gateway       immutable

  registrado_em           MCD-F9007   output         conditional       system               immutable

  data_fato               MCD-F9008   input/output   optional          origin/normalizer    immutable_fact

  arquivo_origem_id       MCD-F9009   input/output   optional          system/gateway       immutable
  ----------------------------------------------------------------------------------------------------------

Regras: - Metadados transversais não precisam ser colunas repetidas em
cada tabela. - Proveniência não é removida em transformações. - Tempos
de fato, importação, registro, emissão, competência e vigência são
distintos.

## 8. Reconciliação entre fontes

-   Não existe prioridade global única. Autoridade depende do fato,
    domínio, competência e regra.
-   XML pode ser evidência documental; ERP fonte operacional; CNIS fonte
    previdenciária oficial; banco fonte de movimento financeiro.
-   Divergência gera `ConflitoDado`; original não é apagado.
-   Override/revisão preserva justificativa e trilha; identidade do
    responsável será detalhada em SEC/OBS.
-   Precedência específica pertence ao RGT/contrato de domínio, não ao
    Gateway.

## 9. Idempotência e deduplicação

-   Reprocessamento não pode duplicar fatos.
-   Chave de idempotência pode ser derivada de origem + identificador
    externo + identidade documental/versão, mas a utility não deve
    depender de nomes de campo específicos.
-   Sem ID externo confiável, usar hash/fingerprint com possibilidade de
    revisão.
-   Baixa confiança gera `CDC-ERR-006`; não excluir automaticamente.

## 10. Versionamento

``` text
1.0.0 -> contrato inicial
1.1.0 -> campo opcional compatível / sincronização nominal compatível aprovada
1.1.1 -> correção documental sem mudança semântica
2.0.0 -> quebra de tipo, significado, remoção ou obrigatoriedade incompatível
```

Os contratos deste documento passam a `1.1.0`. Clientes devem declarar a
versão consumida.

## 11. Envelope mínimo de evento

``` yaml
event:
  event_id: <uuid>
  event_type: <namespace.action>
  event_version: <semver>
  occurred_at: <timestamp>
  recorded_at: <timestamp>
  correlation_id: <uuid>
  causation_id: <uuid|null>
  unidade_economica_id: <uuid|null>
  sujeito_id: <uuid|null>
  contract_id: <CDC-...>
  contract_version: <semver>
  payload: {}
```

EVT-001 definirá o catálogo. Eventos não substituem a base canônica;
consumidores são idempotentes.

## 12. Contrato mínimo de cálculo

``` yaml
calculation_result:
  id: <uuid>
  engine_id: <string>
  engine_version: <semver>
  rule_set_id: <string>
  rule_set_version: <semver>
  competencia: <YYYY-MM|period|null>
  input_snapshot_hash: <hash>
  calculado_em: <timestamp>
  status_revisao: <status|null>
  result: {}
```

Quando persistido como `ResultadoCalculo`, os nomes devem corresponder a
MCD-F8201..F8209.

## 13. IA e extração documental

-   RAW -\> extração -\> candidato -\> validação/reconciliação -\> fato
    canônico.
-   Extração registra parser/modelo, versão, confiança e evidência
    quando aplicável; campos ainda não formalizados ficam em metadados
    técnicos/OBS, não no domínio inventado.
-   Confiança de IA não equivale a validade jurídica.
-   Cálculo tributário é determinístico e usa RGT aprovado; LLM pode
    extrair, explicar ou sugerir.

## 14. Segurança e multi-tenancy

-   Tenant/organização é contexto de autorização; UE não substitui
    tenant.
-   Contratos não expõem dados sensíveis por padrão.
-   Revisões/overrides exigem auditoria.
-   ContaAcesso/CredencialAcesso aguardam SEC-001; CDC V1.1 não define
    payload de autenticação.

## 15. Lacunas residuais --- bloqueios explícitos

  ---------------------------------------------------------------------------------------------------
  Gap               Origem             Impacto                              Ação
  ----------------- ------------------ ------------------------------------ -------------------------
  GAP-CDC-001       COT-OBJ-008 vs     ClassificacaoEquiparacaoHospitalar é MCD-CHANGE-REQUEST-002
                    MCD-F5001..F5008   objeto versionado, mas não possui    antes do model
                                       `id` próprio no MCD.                 Prisma/persistência
                                                                            EqHop.

  GAP-CDC-002       COT-REL-007        Relação N:N Receita↔DocumentoFiscal  MCD-CHANGE-REQUEST-002;
                                       exige associação explícita, ausente  não criar join table
                                       no MCD.                              ad-hoc.

  GAP-CDC-003       COT-OBJ-015        ConflitoDado não possui referências  MCD-CHANGE-REQUEST-002
                                       estruturadas aos registros/fontes em antes de reconciliação
                                       conflito.                            persistente completa.

  GAP-CDC-004       COT-OBJ-016 / SEC  RevisaoTecnica não modela            Resolver em
                    futuro             revisor/autorização.                 SEC-001/OBS-001, sem
                                                                            adicionar usuário à PF.
  ---------------------------------------------------------------------------------------------------

## 16. Política operacional para Claude Code

``` yaml
cdc_policy:
  version: 1.1
  contract_first: true
  sources_of_truth:
    - CAF-001
    - MCD-001-v1.1
    - CDC-001-v1.1
    - DST-001
    - COT-001
  use_legacy_mcd_field_names: false
  allow_unregistered_payload_field: false
  allow_unmodeled_relation_in_persistence: false
  allow_breaking_change_without_major_version: false
  preserve_raw_source: true
  preserve_provenance: true
  preserve_history: true
  calculations_are_reproducible: true
  events_are_idempotent: true
  external_vendor_schema_in_domain: false
  competence_as_first_day_date: false
  auth_contracts_before_sec001: false
```

Se um type/interface precisar de campo que não existe no MCD V1.1,
Claude deve registrar a lacuna. Se uma persistência exigir
relação/identidade ausente, deve aguardar Change Request aprovado.

## 17. O que está liberado na Fase 1

-   Types de `UnidadeEconomica`, `PessoaFisica` e `PessoaJuridica` com
    nomes MCD V1.1.
-   Value Objects técnicos: UUID, Money/Decimal, SemVer, Competencia,
    IdempotencyKey.
-   Gateway genérico `ERPAdapter<TRaw,TNormalized>` e
    `IntegrationGateway` sem adapter concreto.
-   Types adicionais podem ser preparados quando todos os campos/enums
    usados estiverem publicados, sem persistência automática.
-   Proposta de schema físico pode ser desenhada; primeira migration
    permanece sujeita a revisão.
-   EqHop persistente, associação Receita↔Documento e reconciliação
    completa permanecem bloqueadas pelos gaps da seção 15.

## 18. Critérios de aceite CDC-001 V1.1

-   [ ] Todos os nomes de payload correspondem ao MCD V1.1.
-   [ ] Nenhum nome prefixado legado é usado como campo canônico.
-   [ ] Competência é YYYY-MM.
-   [ ] Vínculo possui origem/destino/papel/vigência.
-   [ ] Titularidade PF/PJ está explícita.
-   [ ] Novos objetos COT possuem contratos quando o MCD os suporta.
-   [ ] Lacunas não foram preenchidas por invenção de schema.
-   [ ] Proveniência, conflito e reprodutibilidade estão preservados.
-   [ ] Autenticação continua separada.
-   [ ] Modelo permanece independente de ERP e fornecedor PostgreSQL.

## 19. Próximos documentos

1.  **DST-001 V1.1** --- sincronização dos enums/termos com a
    nomenclatura e objetos atuais.\
2.  **MCD-CHANGE-REQUEST-002** --- fechar os três gaps estruturais de
    persistência identificados nesta revisão.\
3.  **SEC-001** --- autenticação, autorização e identidade de acesso.\
4.  **RGT-001**, **EVT-001** e **INT-001**.

------------------------------------------------------------------------

**Decisão de governança:** CDC-001 V1.1 substitui CDC-001 V1.0 como
contrato vigente. O CDC não corrige lacunas do MCD por conta própria;
ele as torna explícitas e bloqueia implementação física até aprovação
formal.
