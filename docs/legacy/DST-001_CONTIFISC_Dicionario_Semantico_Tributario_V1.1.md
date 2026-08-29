# DST-001 --- Dicionário Semântico Tributário da CONTIFISC

**Versão:** 1.1\
**Status:** APROVADO --- sincronizado com MCD-001 V1.1 e CDC-001 V1.1\
**Supersede:** DST-001 V1.0\
**Dependências:** CAF-001, COT-001, MCD-001 V1.1, CDC-001 V1.1\
**Escopo:** vocabulário canônico, semântica, enums e lacunas controladas

> O DST define o significado oficial dos termos e códigos. Ele não cria
> schema físico, não implementa regra tributária e não transforma
> infraestrutura de banco/hosting em fonte de negócio.

## 1. Alterações da V1.1

-   Sincronização nominal com MCD/CDC V1.1; nomes prefixados V1.0 deixam
    de orientar código novo.
-   Ampliação do dicionário para os 18 objetos COT e conceitos
    transversais de competência, proveniência, qualidade, fato e
    resultado.
-   Formalização dos enums necessários à Fase 1: `status_registro` e
    `regime_tributario`.
-   Separação entre `status_registro` (ciclo de vida) e
    `status_qualidade_dado` (qualidade/reconciliação).
-   `sistema_origem` deixa de conter infraestrutura de persistência:
    `NEON_DB` foi removido. Neon/PostgreSQL são infraestrutura, não
    origem de negócio.
-   Lacunas de enums ainda não aprovados são explicitamente registradas;
    Claude não deve inventar códigos.
-   Equiparação Hospitalar mantém códigos EH-001..EH-004 como semântica
    de classificação, sem antecipar regras legais do RGT.

## 2. Regras semânticas

-   Um termo canônico possui um significado principal e não deve ser
    reutilizado com significado diferente.
-   Enum é código estável de domínio; label de UI pode mudar sem alterar
    o código.
-   `OUTRO` significa categoria válida fora do catálogo; `NAO_INFORMADO`
    significa ausência de classificação/informação.
-   `PENDENTE` é estado de processo/decisão e não sinônimo de dado
    ausente.
-   Infraestrutura técnica (PostgreSQL, Neon, Vercel, Prisma) não é
    `sistema_origem` de fato tributário.
-   Conceitos temporais não são intercambiáveis: `competencia`,
    `data_fato`, `data_emissao`, `importado_em`, `registrado_em`,
    `vigencia_inicio/fim`.
-   Termo/enumerador ausente gera GAP/Change Request, não inferência em
    código.

## 3. Vocabulário canônico (24 termos)

  ------------------------------------------------------------------------------------------------------------
  ID             Termo            Definição                        Não significa            Rastreabilidade
  -------------- ---------------- -------------------------------- ------------------------ ------------------
  DST-T001       Unidade          Contexto interno que agrega PF,  Não é contribuinte,      COT-OBJ-001 /
                 Econômica        PJ, vínculos, fatos e cenários   estabelecimento, tenant  MCD-F0001..F0005 /
                                  para análise integrada.          ou grupo societário por  CDC-UE-001
                                                                   si só.                   

  DST-T002       Pessoa Física    Pessoa natural titular de fatos, Não equivale a           COT-OBJ-002 /
                                  vínculos e eventos               usuário/conta de acesso. MCD-F1001..F1008 /
                                  tributários/previdenciários.                              CDC-PER-001

  DST-T003       Pessoa Jurídica  Entidade jurídica identificada   CNPJ é identificador     COT-OBJ-003 /
                                  canonicamente e portadora de     fiscal, não PK.          MCD-F2001..F2007 /
                                  atributos cadastrais/tributários                          CDC-EMP-001
                                  temporais.                                                

  DST-T004       Vínculo          Relação canônica de primeira     Não substituir por FK    COT-OBJ-004 /
                                  classe entre objetos, com tipo,  ad-hoc.                  MCD-F2501..F2510 /
                                  papel, atributos e vigência.                              CDC-REL-001

  DST-T005       Receita          Fato econômico de                Não é sinônimo de        COT-OBJ-005 /
                                  ingresso/rendimento normalizado  documento fiscal nem     MCD-F3001..F3009 /
                                  para PF ou PJ.                   recebimento bancário.    CDC-REC-001

  DST-T006       Documento Fiscal Representação canônica de        É evidência/documento;   COT-OBJ-006 /
                                  documento fiscal e seus dados    não substitui Receita.   MCD-F4001..F4008 /
                                  normalizados.                                             CDC-FIS-001

  DST-T007       Arquivo de       Referência imutável à evidência  Não é payload canônico.  COT-OBJ-007 /
                 Origem           RAW usada em                                              MCD-F8401..F8405 /
                                  ingestão/reprocessamento.                                 CDC-ARQ-001

  DST-T008       Classificação de Resultado derivado, versionado e Não é atributo fixo da   COT-OBJ-008 /
                 Equiparação      revisável sobre                  empresa; não é decidido  MCD-F5001..F5008 /
                 Hospitalar       elegibilidade/segregação de      apenas por CNAE/NFS-e.   CDC-EH-001
                                  receita.                                                  

  DST-T009       Contribuição     Fato de contribuição             Não é o vínculo em si.   COT-OBJ-009 /
                 Previdenciária   previdenciária associado a PF e,                          MCD-F6001..F6007 /
                                  quando aplicável, vínculo                                 CDC-PRE-001
                                  previdenciário.                                           

  DST-T010       Vínculo          Fonte/relação previdenciária     Uma PF pode ter vários   COT-OBJ-010 /
                 Previdenciário   temporal de uma PF.              simultaneamente.         MCD-F6101..F6105 /
                                                                                            CDC-PREV-001

  DST-T011       Evento IRPF      Fato ou registro relevante ao    Resultado projetado deve COT-OBJ-011 /
                                  IRPF/Carnê-Leão de uma PF.       permanecer distinguível  MCD-F7001..F7010 /
                                                                   do fato.                 CDC-IRP-001

  DST-T012       Fonte Pagadora   Origem pagadora normalizada de   Não substitui PF/PJ      COT-OBJ-012 /
                                  receita/rendimento.              quando estas forem       MCD-F7201..F7204 /
                                                                   conhecidas.              CDC-FPG-001

  DST-T013       Cenário          Ambiente de simulação de         Nunca altera fatos       COT-OBJ-013 /
                 Tributário       hipóteses tributárias, isolado   canônicos.               MCD-F8001..F8005 /
                                  dos fatos oficiais.                                       CDC-PLN-001

  DST-T014       Resultado de     Saída reproduzível de motor      Não sobrescreve fato.    COT-OBJ-014 /
                 Cálculo          determinístico, vinculada a                               MCD-F8201..F8209 /
                                  snapshot, engine e rule set.                              CDC-CAL-001

  DST-T015       Conflito de      Registro de divergência entre    Não significa            COT-OBJ-015 /
                 Dados            fontes ou fatos candidatos que   automaticamente erro de  MCD-F8601..F8604 /
                                  exige reconciliação.             uma das fontes.          CDC-CFD-001

  DST-T016       Revisão Técnica  Decisão humana auditável sobre   Identidade/autorização   COT-OBJ-016 /
                                  objeto, conflito, classificação  do revisor pertence a    MCD-F8701..F8706 /
                                  ou resultado.                    SEC/OBS.                 CDC-REV-001

  DST-T017       Conta de Acesso  Identidade de acesso ao sistema, Detalhamento bloqueado   COT-OBJ-017
                                  separada da identidade           até SEC-001.             
                                  tributária.                                               

  DST-T018       Credencial de    Mecanismo/segredo/autenticador   Nunca deve ser modelado  COT-OBJ-018
                 Acesso           associado a ContaAcesso.         dentro de PessoaFisica.  

  DST-T019       Competência      Período mensal de referência de  Formato contratual       MCD-F3004 / CDC
                                  um fato, obrigação, cálculo ou   YYYY-MM; não é data      transversal
                                  apuração.                        fictícia no dia 1.       

  DST-T020       Proveniência     Conjunto de metadados que        Não se confunde com      MCD-F9001..F9009 /
                                  explica de onde um dado veio,    autoridade absoluta da   CDC-SYS-001
                                  como foi ingerido e qual         fonte.                   
                                  evidência o sustenta.                                     

  DST-T021       Sistema de       Sistema, documento, processo ou  Infraestrutura de        MCD-F9001
                 Origem           canal externo/interno que        persistência             
                                  produziu o registro antes da     (Neon/PostgreSQL) não é  
                                  normalização.                    sistema de origem de     
                                                                   negócio.                 

  DST-T022       Qualidade do     Condição de uso/validação de um  É distinta do ciclo de   MCD-F9004
                 Dado             dado canônico ao longo de        vida do registro.        
                                  reconciliação e revisão.                                  

  DST-T023       Fato Canônico    Registro normalizado que         Correção preserva        CDC-001 V1.1
                                  representa ocorrência            histórico; derivado não  
                                  econômica/tributária observada.  substitui fato.          

  DST-T024       Resultado        Informação                       Deve ser reproduzível e  CDC-001 V1.1
                 Derivado         calculada/classificada a partir  versionada.              
                                  de fatos, regras e versões                                
                                  identificáveis.                                           
  ------------------------------------------------------------------------------------------------------------

## 4. Enums aprovados (10 grupos)

### DST-E001 --- `regime_tributario`

**Definição:** Regime tributário da Pessoa Jurídica\
**Rastreabilidade:** MCD-F2004 / CDC-EMP-001

  -----------------------------------------------------------------------
  Código                              Significado
  ----------------------------------- -----------------------------------
  `SIMPLES_NACIONAL`                  Optante pelo Simples Nacional.

  `LUCRO_PRESUMIDO`                   Tributação pelo Lucro Presumido.

  `LUCRO_REAL`                        Tributação pelo Lucro Real.

  `OUTRO`                             Regime válido não contemplado pelo
                                      catálogo atual; exige detalhe
                                      complementar quando aplicável.

  `NAO_INFORMADO`                     Regime ainda não
                                      informado/validado.
  -----------------------------------------------------------------------

### DST-E002 --- `tipo_titular`

**Definição:** Natureza canônica do titular de uma Receita\
**Rastreabilidade:** MCD-F3006 / CDC-REC-001

  Código              Significado
  ------------------- ---------------------------
  `PESSOA_FISICA`     Titular é PessoaFisica.
  `PESSOA_JURIDICA`   Titular é PessoaJuridica.

### DST-E003 --- `status_elegibilidade_equiparacao_hospitalar`

**Definição:** Status da classificação de equiparação hospitalar\
**Rastreabilidade:** MCD-F5001 / CDC-EH-001

  -----------------------------------------------------------------------
  Código                              Significado
  ----------------------------------- -----------------------------------
  `EH_001_ELEGIVEL`                   Receita classificada como elegível
                                      conforme regra aprovada.

  `EH_002_NAO_ELEGIVEL`               Receita classificada como não
                                      elegível.

  `EH_003_PENDENTE`                   Informação/evidência insuficiente
                                      para decisão.

  `EH_004_REVISAO_TECNICA`            Classificação exige revisão
                                      técnica/humana.
  -----------------------------------------------------------------------

### DST-E004 --- `tipo_rendimento_irpf`

**Definição:** Natureza geral do rendimento para IRPF\
**Rastreabilidade:** MCD-F7002 / CDC-IRP-001

  -----------------------------------------------------------------------
  Código                              Significado
  ----------------------------------- -----------------------------------
  `TRIBUTAVEL`                        Rendimento sujeito à tributação
                                      conforme regra aplicável.

  `ISENTO_NAO_TRIBUTAVEL`             Rendimento tratado como isento/não
                                      tributável conforme regra
                                      aplicável.

  `TRIBUTACAO_EXCLUSIVA`              Rendimento sujeito a tributação
                                      exclusiva/definitiva quando
                                      aplicável.

  `OUTRO`                             Natureza ainda não contemplada.

  `NAO_INFORMADO`                     Natureza ainda não classificada.
  -----------------------------------------------------------------------

### DST-E005 --- `tipo_fonte_pagadora`

**Definição:** Natureza da fonte pagadora\
**Rastreabilidade:** MCD-F7202 / CDC-FPG-001

  Código              Significado
  ------------------- -------------------------------------
  `PESSOA_FISICA`     Fonte pagadora pessoa natural.
  `PESSOA_JURIDICA`   Fonte pagadora pessoa jurídica.
  `EXTERIOR`          Fonte pagadora situada no exterior.
  `OUTRA`             Outra natureza.
  `NAO_INFORMADA`     Natureza ainda não informada.

### DST-E006 --- `status_revisao`

**Definição:** Estado de uma revisão/resultado revisável\
**Rastreabilidade:** MCD-F8209 / MCD-F8704

  Código                Significado
  --------------------- ----------------------------------------
  `PENDENTE`            Aguardando revisão.
  `APROVADO`            Revisão concluída com aprovação.
  `REJEITADO`           Revisão concluída com rejeição.
  `AJUSTE_SOLICITADO`   Revisão exige ajuste/novas evidências.

### DST-E007 --- `status_conflito`

**Definição:** Estado de tratamento de conflito de dados\
**Rastreabilidade:** MCD-F8602 / CDC-CFD-001

  -----------------------------------------------------------------------
  Código                              Significado
  ----------------------------------- -----------------------------------
  `ABERTO`                            Conflito identificado e não
                                      resolvido.

  `EM_ANALISE`                        Conflito em reconciliação.

  `RESOLVIDO`                         Conflito reconciliado com trilha
                                      preservada.

  `DESCARTADO`                        Conflito considerado não
                                      material/duplicado mediante
                                      justificativa.
  -----------------------------------------------------------------------

### DST-E008 --- `status_registro`

**Definição:** Ciclo de vida cadastral de objetos canônicos\
**Rastreabilidade:** MCD-F0003 / CDC-UE-001

  -----------------------------------------------------------------------
  Código                              Significado
  ----------------------------------- -----------------------------------
  `ATIVO`                             Registro vigente para uso.

  `INATIVO`                           Registro não vigente/operacional,
                                      preservado historicamente.

  `ARQUIVADO`                         Registro retirado do fluxo ativo e
                                      mantido para histórico.
  -----------------------------------------------------------------------

### DST-E009 --- `status_qualidade_dado`

**Definição:** Qualidade/reconciliação do dado canônico\
**Rastreabilidade:** MCD-F9004 / CDC-SYS-001

  -----------------------------------------------------------------------
  Código                              Significado
  ----------------------------------- -----------------------------------
  `IMPORTADO`                         Recebido/normalizado, ainda sem
                                      validação suficiente.

  `VALIDADO`                          Validado estrutural/semanticamente
                                      para o estágio aplicável.

  `RECONCILIADO`                      Confrontado com fontes relevantes e
                                      reconciliado.

  `OVERRIDDEN`                        Valor/decisão substituído por
                                      override autorizado, com trilha.

  `SUPERSEDED`                        Substituído por versão/correção
                                      posterior, preservado
                                      historicamente.

  `CANCELADO`                         Invalidado/cancelado sem exclusão
                                      histórica.
  -----------------------------------------------------------------------

### DST-E010 --- `sistema_origem`

**Definição:** Categorias canônicas de origem do dado\
**Rastreabilidade:** MCD-F9001 / CDC-SYS-001

  -----------------------------------------------------------------------
  Código                              Significado
  ----------------------------------- -----------------------------------
  `ERP_CONTABIL`                      ERP/sistema contábil ou fiscal
                                      externo.

  `DOCUMENTO_FISCAL`                  Documento fiscal/XML/API de
                                      emissão/captura.

  `CNIS`                              Registro previdenciário CNIS.

  `FOLHA_PAGAMENTO`                   Sistema/processo de folha.

  `BANCO`                             Extrato/movimento bancário.

  `INFORME_RENDIMENTOS`               Informe de rendimentos/retencões.

  `CARNE_LEAO`                        Origem vinculada ao Carnê-Leão.

  `ENTRADA_MANUAL`                    Dado informado manualmente por
                                      usuário autorizado.

  `API_GOVERNAMENTAL`                 API/serviço oficial governamental.

  `OUTRO_SISTEMA`                     Outra fonte operacional ainda não
                                      catalogada.
  -----------------------------------------------------------------------

## 5. Regras específicas dos enums

-   `status_registro` é cadastral. Não usar para indicar validação,
    reconciliação ou cancelamento de fato.
-   `status_qualidade_dado` acompanha a confiabilidade/lifecycle do dado
    canônico e preserva histórico.
-   `regime_tributario` é temporal: mudança de regime não reescreve
    competências anteriores.
-   `tipo_titular` identifica PF/PJ do fato Receita; não deve ser
    inferido apenas pelo formato de documento sem validação.
-   `status_elegibilidade_equiparacao_hospitalar` expressa resultado de
    classificação; a regra que produz o status pertence ao RGT.
-   `sistema_origem` classifica a origem operacional; fornecedor
    específico pode ser registrado em metadado técnico/identificador do
    adapter sem contaminar o enum canônico.
-   `status_revisao` e `status_conflito` têm ciclos próprios e não devem
    ser fundidos.

## 6. Competência e temporalidade

  -----------------------------------------------------------------------
  Conceito                Semântica               Exemplo
  ----------------------- ----------------------- -----------------------
  competencia             Período mensal de       2026-08
                          referência.             

  data_fato               Data/momento da         2026-08-14
                          ocorrência econômica.   

  data_emissao            Data de emissão         2026-08-15
                          documental.             

  importado_em            Momento de ingestão no  2026-08-16T12:00:00Z
                          pipeline.               

  registrado_em           Momento de registro     2026-08-16T12:00:03Z
                          canônico.               

  vigencia_inicio/fim     Intervalo em que        2026-01-01 ..
                          atributo/vínculo é      2026-12-31
                          válido.                 
  -----------------------------------------------------------------------

`competencia` nunca deve ser convertida semanticamente para
`2026-08-01`. Uma camada física pode escolher representação técnica, mas
o contrato continua `YYYY-MM`.

## 7. Estados especiais

  -----------------------------------------------------------------------
  Estado                              Semântica
  ----------------------------------- -----------------------------------
  null                                Ausência/desconhecimento permitido
                                      pelo contrato.

  0                                   Valor conhecido igual a zero.

  NAO_INFORMADO                       Informação ainda não
                                      fornecida/classificada.

  OUTRO                               Valor conhecido, válido, mas fora
                                      das categorias atuais.

  PENDENTE                            Decisão/processamento ainda não
                                      concluído.

  NAO_APLICAVEL                       Conceito não se aplica ao caso;
                                      somente usar onde formalmente
                                      previsto.

  ESTIMADO                            Valor derivado/estimado; somente
                                      usar onde o contrato/regra
                                      permitir.
  -----------------------------------------------------------------------

## 8. Lacunas semânticas controladas (10 gaps)

Estas lacunas são deliberadas. Elas **não autorizam** criação de enums
locais em TypeScript/Prisma.

  -------------------------------------------------------------------------------------------------------------------------------------
  Gap           Campo/conceito                MCD               Tipo        Motivo                                 Política temporária
                                                                esperado                                           
  ------------- ----------------------------- ----------------- ----------- -------------------------------------- --------------------
  DST-GAP-001   conselho_profissional         MCD-F1005         Enum/Ref    Catálogo de conselhos ainda não        Manter tipo
                                                                            aprovado.                              opaco/branded
                                                                                                                   aberto; não criar
                                                                                                                   enum fechado.

  DST-GAP-002   especialidade_saude           MCD-F1008         Enum/Ref    Taxonomia de especialidades/profissões Manter tipo
                                                                            ainda não aprovada.                    opaco/branded
                                                                                                                   aberto; não inventar
                                                                                                                   códigos.

  DST-GAP-003   tipo_vinculo                  MCD-F2502         Enum        Catálogo de vínculos ainda precisa     Bloquear enum
                                                                            derivar integralmente das relações     fechado até revisão
                                                                            COT.                                   específica.

  DST-GAP-004   tipo_objeto_origem/destino    MCD-F2507/F2509   Enum        Tipos permitidos precisam ser          Não inventar lista
                                                                            alinhados ao catálogo de objetos COT e de endpoints no
                                                                            estratégia de integridade referencial. código.

  DST-GAP-005   papel_vinculo                 MCD-F2510         Enum        Papéis                                 Tipo aberto/sem
                                                                            societários/profissionais/econômicos   persistência até
                                                                            ainda não catalogados.                 catálogo.

  DST-GAP-006   fonte_receita                 MCD-F3005         Enum/Ref    Taxonomia de fontes/naturezas de       Não criar enum.
                                                                            receita ainda não formalizada.         

  DST-GAP-007   tipo_documento_fiscal         MCD-F4002         Enum        Catálogo documental ainda não          Não criar enum
                                                                            formalizado.                           fechado.

  DST-GAP-008   tipo_vinculo_previdenciario   MCD-F6103         Enum        Catálogo previdenciário depende do     Não inventar
                                                                            desenho do módulo/integração.          códigos.

  DST-GAP-009   tipo_conflito                 MCD-F8603         Enum        Taxonomia de conflitos ainda não       Aguardar revisão de
                                                                            formalizada.                           reconciliação/OBS.

  DST-GAP-010   tipo_objeto_revisado          MCD-F8703         Enum        Tipos revisáveis devem acompanhar      Não criar enum
                                                                            COT/SEC/OBS.                           fechado.
  -------------------------------------------------------------------------------------------------------------------------------------

## 9. Política de tipos para gaps

-   Quando o MCD disser `Enum/Ref` mas o catálogo DST estiver ausente,
    usar tipo opaco/branded aberto somente se a Fase atual exigir o
    campo.
-   Não exportar `string` genérica sem marca semântica para campos de
    domínio sensíveis.
-   Parser/factory pode validar apenas requisitos estruturais já
    aprovados (ex.: não vazio/tamanho), sem lista fechada inventada.
-   Persistência com enum fechado fica bloqueada até publicação do
    catálogo correspondente.
-   Comentários de código devem apontar o `DST-GAP-XXX` específico.

## 10. Fonte de dados vs infraestrutura

  --------------------------------------------------------------------------
  Categoria                  É `sistema_origem`?     Exemplo
  -------------------------- ----------------------- -----------------------
  ERP/contábil               Sim                     Questor, Domínio ou
                                                     outro via adapter; o
                                                     enum canônico é
                                                     ERP_CONTABIL.

  Documento/XML fiscal       Sim                     NFS-e/XML/API
                                                     documental.

  CNIS/folha/banco/informe   Sim                     Fonte do
                                                     fato/candidato.

  Entrada manual             Sim                     Ação autorizada de
                                                     cadastro/importação.

  PostgreSQL/Neon            Não                     Persistência da própria
                                                     plataforma.

  Prisma                     Não                     ORM.

  Vercel                     Não                     Hosting/deploy.

  GitHub                     Não                     Repositório/CI.
  --------------------------------------------------------------------------

## 11. Política para Claude Code

``` yaml
dst_policy:
  version: 1.1
  source_of_truth: DST-001-v1.1
  supersedes: DST-001-v1.0
  canonical_language: pt-BR
  legacy_prefixed_field_names: prohibited
  enum_codes_are_stable: true
  invent_enum_values: false
  invent_synonyms_as_codes: false
  unknown_enum_requires_gap: true
  enum_ref_without_catalog:
    allow_open_branded_type: true
    allow_closed_union: false
  competence:
    format: YYYY-MM
    fake_first_day_date: prohibited
  source_system:
    persistence_infrastructure_is_source: false
    vendor_specific_code_in_canonical_enum: false
  status_registro_is_quality_status: false
  status_qualidade_dado_is_record_lifecycle: false
```

## 12. Uso autorizado na Fase 1

-   `UnidadeEconomica.status_registro` pode usar DST-E008.
-   `PessoaJuridica.regime_tributario` pode usar DST-E001.
-   `PessoaFisica.conselho_profissional` deve apontar DST-GAP-001 e
    permanecer tipo opaco aberto.
-   `PessoaFisica.especialidade_saude` deve apontar DST-GAP-002 e
    permanecer tipo opaco aberto.
-   UUID, Money, SemVer, Competencia e IdempotencyKey continuam Value
    Objects/tipos técnicos.
-   Nenhum enum adicional deve ser criado só para facilitar Prisma ou
    UI.

## 13. Critérios de aceite

-   [ ] Vocabulário está alinhado a COT/MCD/CDC V1.1.
-   [ ] `status_registro` e `regime_tributario` estão formalizados para
    os 3 types da Fase 1.
-   [ ] `NEON_DB` não aparece como sistema de origem.
-   [ ] Qualidade e ciclo de vida não são confundidos.
-   [ ] Competência permanece YYYY-MM.
-   [ ] Gaps de conselho/especialidade e demais enums estão
    explicitamente bloqueados.
-   [ ] Claude não precisa inventar código semântico para implementar a
    Fase 1.

## 14. Próximos passos

1.  Emitir **MCD-CHANGE-REQUEST-002** para os gaps estruturais
    identificados pelo CDC-001 V1.1.\
2.  Criar revisão DST específica para os catálogos de `tipo_vinculo`,
    `papel_vinculo`, documentos, fontes de receita e previdenciário
    quando os módulos correspondentes entrarem em implementação.\
3.  Desenvolver SEC-001, RGT-001, EVT-001 e INT-001.

------------------------------------------------------------------------

**Decisão de governança:** DST-001 V1.1 substitui DST-001 V1.0. O
dicionário distingue vocabulário aprovado de taxonomias ainda pendentes
e proíbe que código de implementação preencha essas lacunas por
conveniência.
