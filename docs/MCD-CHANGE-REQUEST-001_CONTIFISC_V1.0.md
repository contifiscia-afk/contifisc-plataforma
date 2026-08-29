# MCD-CHANGE-REQUEST-001 --- Alinhamento Estrutural MCD ↔ CDC ↔ DST ↔ COT

**Versão:** 1.0\
**Status:** PROPOSTO PARA APROVAÇÃO\
**Alvo:** MCD-001 V1.0\
**Origem da mudança:** CDC-001, DST-001 e COT-001\
**Impacto esperado após aprovação:** MCD-001 V1.1

> **Objetivo:** corrigir lacunas estruturais reveladas após a
> formalização dos contratos, semântica e objetos canônicos. Este Change
> Request não cria regra tributária e não autoriza ainda a implementação
> completa de autenticação ou motores tributários.

## 1. Motivo da mudança

-   O MCD-001 inicial definiu campos antes de o COT formalizar objetos,
    cardinalidades e ownership.
-   O COT-001 tornou necessários identificadores explícitos para
    vínculos, titularidade e relacionamentos.
-   O CDC-001 introduziu metadados transversais de proveniência,
    qualidade, correlação e reprodutibilidade ainda não integralmente
    registrados no MCD.
-   O COT separou autenticação de PessoaFisica, exigindo objetos SEC
    próprios.
-   A mudança evita que Claude Code invente foreign keys, campos de
    login ou metadados ao criar o schema físico.

## 2. Decisão sobre nomenclatura

Este Change Request também estabelece a direção para a próxima revisão
do MCD: nomes canônicos devem ser **descritivos em português e
`snake_case`**, sem codificar o tipo do dado no nome. Exemplos:
`valor_receita_bruta`, `data_emissao`, `status_qualidade_dado`,
`pessoa_fisica_id`.

Os nomes prefixados do MCD-001 V1.0 (`vl_`, `dt_`, `st_`, `nm_`, `nr_`,
`cd_`, `tp_`, `fl_`) ficam **depreciados para novos desenvolvimentos** e
deverão ser migrados de forma controlada no MCD-001 V1.1. IDs técnicos
como `MCD-F3001` permanecem estáveis.

Regra de IDs: chave primária física/canônica usa `id`; referências usam
`<objeto>_id`. O COT define o objeto; o MCD define seus campos.

## 3. Campos estruturais propostos

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  ID mudança    Objeto                               Campo proposto              Tipo lógico   Obrigatoriedade   Semântica            Evidência          Ação
  ------------- ------------------------------------ --------------------------- ------------- ----------------- -------------------- ------------------ -----------------------
  MCR-001-F01   Vinculo                              objeto_origem_id            UUID          Obrigatório       Identifica o objeto  COT-REL-001..004   Adicionar
                                                                                                                 de origem do                            
                                                                                                                 vínculo.                                

  MCR-001-F02   Vinculo                              tipo_objeto_origem          ENUM          Obrigatório       Indica o tipo        COT-REL-001..004   Adicionar
                                                                                                                 canônico do objeto                      
                                                                                                                 de origem.                              

  MCR-001-F03   Vinculo                              objeto_destino_id           UUID          Obrigatório       Identifica o objeto  COT-REL-001..004   Adicionar
                                                                                                                 de destino do                           
                                                                                                                 vínculo.                                

  MCR-001-F04   Vinculo                              tipo_objeto_destino         ENUM          Obrigatório       Indica o tipo        COT-REL-001..004   Adicionar
                                                                                                                 canônico do objeto                      
                                                                                                                 de destino.                             

  MCR-001-F05   Vinculo                              papel_vinculo               ENUM          Condicional       Qualifica o papel    COT-OBJ-004        Adicionar
                                                                                                                 exercido no                             
                                                                                                                 relacionamento sem                      
                                                                                                                 confundi-lo com o                       
                                                                                                                 tipo estrutural.                        

  MCR-001-F06   Receita                              titular_id                  UUID          Obrigatório       Referência ao        COT-REL-005/006    Adicionar
                                                                                                                 titular econômico da                    
                                                                                                                 receita.                                

  MCR-001-F07   Receita                              tipo_titular                ENUM          Obrigatório       Define se o titular  DST-E004           Substituir/normalizar
                                                                                                                 canônico é                              
                                                                                                                 PessoaFisica ou                         
                                                                                                                 PessoaJuridica.                         

  MCR-001-F08   Receita                              fonte_pagadora_id           UUID          Opcional          Referência canônica  COT-REL-013        Normalizar
                                                                                                                 à FontePagadora                         
                                                                                                                 quando identificada.                    

  MCR-001-F09   DocumentoFiscal                      arquivo_origem_id           UUID          Opcional          Referência ao        COT-REL-008        Normalizar
                                                                                                                 arquivo/evidência                       
                                                                                                                 RAW preservado.                         

  MCR-001-F10   ContribuicaoPrevidenciaria           pessoa_fisica_id            UUID          Obrigatório       Titular da           COT-REL-010        Adicionar
                                                                                                                 contribuição                            
                                                                                                                 previdenciária.                         

  MCR-001-F11   ContribuicaoPrevidenciaria           vinculo_previdenciario_id   UUID          Opcional          Fonte/vínculo        COT-REL-011        Normalizar
                                                                                                                 previdenciário da                       
                                                                                                                 contribuição.                           

  MCR-001-F12   EventoIRPF                           pessoa_fisica_id            UUID          Obrigatório       Titular do           COT-REL-012        Adicionar
                                                                                                                 fato/evento de IRPF.                    

  MCR-001-F13   EventoIRPF                           fonte_pagadora_id           UUID          Opcional          Fonte pagadora do    COT-REL-014        Adicionar
                                                                                                                 rendimento quando                       
                                                                                                                 aplicável.                              

  MCR-001-F14   ClassificacaoEquiparacaoHospitalar   receita_id                  UUID          Obrigatório       Receita ou unidade   COT-REL-009        Adicionar
                                                                                                                 de receita submetida                    
                                                                                                                 à classificação.                        

  MCR-001-F15   ClassificacaoEquiparacaoHospitalar   regra_versao_id             STRING/UUID   Obrigatório na    Identifica           CDC-EH-001         Adicionar
                                                                                               decisão           conjunto/versão de                      
                                                                                                                 regra que produziu a                    
                                                                                                                 classificação.                          

  MCR-001-F16   CenarioTributario                    unidade_economica_id        UUID          Obrigatório no    Contexto econômico   COT-REL-015        Adicionar
                                                                                               cenário UE        avaliado pelo                           
                                                                                                                 cenário.                                

  MCR-001-F17   ResultadoCalculo                     cenario_tributario_id       UUID          Opcional          Cenário ao qual o    COT-REL-016        Adicionar
                                                                                                                 resultado pertence,                     
                                                                                                                 quando simulação.                       

  MCR-001-F18   ResultadoCalculo                     input_snapshot_hash         STRING        Obrigatório       Hash do conjunto de  CDC cálculo        Adicionar
                                                                                                                 inputs para                             
                                                                                                                 reprodutibilidade.                      

  MCR-001-F19   ResultadoCalculo                     engine_id                   STRING        Obrigatório       Identifica o motor   CDC cálculo        Adicionar
                                                                                                                 responsável.                            

  MCR-001-F20   ResultadoCalculo                     engine_version              SEMVER        Obrigatório       Versão do motor de   CDC cálculo        Adicionar
                                                                                                                 cálculo.                                

  MCR-001-F21   ResultadoCalculo                     rule_set_id                 STRING        Obrigatório       Identifica conjunto  CDC cálculo        Adicionar
                                                                                                                 de regras utilizado.                    

  MCR-001-F22   ResultadoCalculo                     rule_set_version            SEMVER        Obrigatório       Versão do conjunto   CDC cálculo        Adicionar
                                                                                                                 de regras.                              
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

## 4. Metadados transversais a formalizar

Estes campos não devem necessariamente existir como colunas repetidas em
todas as tabelas. O schema físico poderá usar composição, tabela de
proveniência ou envelope persistido, desde que o contrato preserve a
semântica.

  --------------------------------------------------------------------------------------------
  ID                Campo canônico          Tipo lógico       Finalidade
  ----------------- ----------------------- ----------------- --------------------------------
  MCR-001-T01       sistema_origem          STRING/ENUM       Sistema/documento/processo de
                                                              origem do fato.

  MCR-001-T02       identificador_origem    STRING            Identificador do registro na
                                                              origem.

  MCR-001-T03       importado_em            TIMESTAMP         Momento da ingestão.

  MCR-001-T04       arquivo_origem_id       UUID              Referência à evidência RAW
                                                              quando aplicável.

  MCR-001-T05       status_qualidade_dado   ENUM              Estado de validação/qualidade.

  MCR-001-T06       versao_schema           SEMVER            Versão do schema/contrato
                                                              recebido.

  MCR-001-T07       correlation_id          UUID              Correlação entre
                                                              operações/importações/eventos.

  MCR-001-T08       registrado_em           TIMESTAMP         Momento em que o fato entrou no
                                                              registro canônico.

  MCR-001-T09       data_fato               DATE/TIMESTAMP    Data de ocorrência quando
                                                              distinta de emissão/competência.
  --------------------------------------------------------------------------------------------

## 5. Objetos adicionados ao escopo do MCD

  -------------------------------------------------------------------------------
  ID mudança        Objeto                  COT               Motivo
  ----------------- ----------------------- ----------------- -------------------
  MCR-001-O01       FontePagadora           COT-OBJ-012       Necessária para
                                                              normalizar
                                                              pagadores em
                                                              Receita e
                                                              EventoIRPF.

  MCR-001-O02       ArquivoOrigem           COT-OBJ-007       Necessário para
                                                              RAW/evidência e
                                                              reprocessamento.

  MCR-001-O03       VinculoPrevidenciario   COT-OBJ-010       Necessário para
                                                              múltiplas fontes
                                                              previdenciárias.

  MCR-001-O04       ResultadoCalculo        COT-OBJ-014       Necessário para
                                                              snapshots
                                                              reproduzíveis.

  MCR-001-O05       ConflitoDado            COT-OBJ-015       Necessário para
                                                              reconciliação sem
                                                              overwrite.

  MCR-001-O06       RevisaoTecnica          COT-OBJ-016       Necessário para
                                                              human-in-the-loop
                                                              auditável.

  MCR-001-O07       ContaAcesso             COT-OBJ-017       Objeto SEC separado
                                                              de PessoaFisica;
                                                              schema detalhado
                                                              fica bloqueado até
                                                              SEC-001.

  MCR-001-O08       CredencialAcesso        COT-OBJ-018       Objeto SEC
                                                              separado;
                                                              credenciais reais
                                                              só após SEC-001.
  -------------------------------------------------------------------------------

## 6. Alterações de nomenclatura recomendadas para MCD-001 V1.1

  --------------------------------------------------------------------------------------------------
  MCD V1.0                     Proposta V1.1                                 Regra
  ---------------------------- --------------------------------------------- -----------------------
  id_unidade_economica         id / unidade_economica_id                     PK usa `id`; FK usa
                                                                             nome do objeto.

  nm_unidade_economica         nome                                          Sem prefixo de tipo.

  nr_cpf                       cpf                                           Identificador de
                                                                             negócio.

  nm_pessoa                    nome                                          Sem prefixo de tipo.

  nr_cnpj                      cnpj                                          Identificador de
                                                                             negócio.

  nm_razao_social              razao_social                                  Sem prefixo de tipo.

  cd_regime_tributario         regime_tributario                             Enum sem prefixo
                                                                             técnico.

  cd_cnae_principal            cnae_principal                                Código semanticamente
                                                                             explícito.

  pc_participacao_societaria   percentual_participacao_societaria            Percentual explícito.

  vl_receita_bruta             valor_receita_bruta                           Valor explícito.

  dt_emissao                   data_emissao                                  Data explícita.

  dt_competencia               competencia                                   Competência é conceito
                                                                             próprio,
                                                                             preferencialmente
                                                                             YYYY-MM.

  cd_fonte_receita             fonte_receita                                 Enum canônico.

  tp_titular_receita           tipo_titular                                  Enum canônico.

  st_elegibilidade_eh          status_elegibilidade_equiparacao_hospitalar   Semântica explícita.

  pc_receita_elegivel_eh       percentual_receita_elegivel                   Percentual explícito.

  vl_inss_recolhido            valor_inss_recolhido                          Valor explícito.

  vl_teto_previdenciario       valor_teto_previdenciario                     Valor explícito.

  tp_rendimento_irpf           tipo_rendimento_irpf                          Enum explícito.

  vl_rendimento_tributavel     valor_rendimento_tributavel                   Valor explícito.

  cd_sistema_origem            sistema_origem                                Origem explícita.

  id_registro_origem           identificador_origem                          Evita confusão com ID
                                                                             canônico.

  dt_importacao                importado_em                                  Timestamp de sistema.

  st_qualidade_dado            status_qualidade_dado                         Status explícito.

  nr_versao_schema             versao_schema                                 Sem prefixo numérico.
  --------------------------------------------------------------------------------------------------

## 7. Semântica temporal obrigatória

-   `competencia`: período de referência (preferencialmente `YYYY-MM` no
    contrato).
-   `data_fato`: ocorrência do fato quando aplicável.
-   `data_emissao`: emissão documental.
-   `data_pagamento`: somente quando o domínio exigir e o campo for
    formalizado.
-   `registrado_em`: momento de registro canônico.
-   `importado_em`: momento de ingestão externa.
-   `vigencia_inicio` / `vigencia_fim`: validade temporal de cadastro,
    vínculo ou regra.
-   Esses conceitos não podem ser usados como sinônimos.

## 8. Impacto em autenticação

-   Não adicionar `email`, `password_hash`, MFA ou sessão a
    PessoaFisica.
-   `ContaAcesso` e `CredencialAcesso` são objetos do domínio SEC.
-   O COT autoriza a existência conceitual desses objetos, mas **não
    autoriza seu schema completo** antes do SEC-001.
-   Implementação de login permanece bloqueada até definição mínima do
    SEC-001 ou Change Request específico de segurança.

## 9. Impacto no schema Prisma

Após aprovação deste Change Request, Claude Code poderá iniciar apenas
os modelos cujo mapeamento `COT -> MCD -> CDC -> DST` esteja completo. O
schema deverá ser apresentado em proposta/ADR antes da migration
inicial.

Ficam bloqueados: - Campos inventados para completar relações. -
Credenciais/autenticação real. - Regras tributárias de EqHop, IRPF,
INSS, IBS/CBS ou planejamento sem RGT. - Mapeamentos específicos Questor
sem INT-001/adaptador aprovado. - Uso de recursos proprietários do Neon
no domínio.

## 10. Compatibilidade e migração

-   Como ainda não existe schema físico nem dados de produção, a
    renomeação pode ocorrer antes da primeira migration, reduzindo custo
    de compatibilidade.
-   O MCD-001 V1.0 deve ser marcado `SUPERSEDED` após publicação do
    MCD-001 V1.1.
-   IDs permanentes de campos devem ser preservados sempre que o
    significado não mudar; mudança apenas de nome não cria novo
    conceito.
-   Campos realmente novos recebem novos IDs MCD.
-   CDC e DST deverão receber revisão de nomenclatura sincronizada, sem
    mudança semântica indevida.

## 11. Critérios de aceite

-   [ ] Vínculos possuem origem, destino, tipo e vigência suficientes
    para implementação.
-   [ ] Receita possui titular canônico explícito.
-   [ ] PF é explicitamente titular de Contribuição Previdenciária e
    EventoIRPF.
-   [ ] EqHop referencia Receita e versão de regra.
-   [ ] Resultados de cálculo são reproduzíveis.
-   [ ] Proveniência transversal está formalizada.
-   [ ] Autenticação permanece separada do domínio tributário.
-   [ ] Nomenclatura descritiva substitui prefixos de tipo antes da
    primeira migration.
-   [ ] Nenhum novo campo físico será inventado fora do MCD aprovado.

## 12. Aprovação proposta

**Recomendação:** APROVAR o MCD-CHANGE-REQUEST-001 e emitir o **MCD-001
V1.1** antes de liberar a primeira migration Prisma de negócio.

Após o MCD-001 V1.1, revisar CDC-001/DST-001 apenas nos nomes afetados e
manter COT-001 como fonte conceitual.

------------------------------------------------------------------------

**Efeito de governança:** este Change Request corrige a ordem natural de
maturação do modelo: os objetos e contratos revelaram requisitos que o
primeiro MCD ainda não podia conhecer. A correção deve ocorrer agora,
antes de existir banco físico, e não depois.
