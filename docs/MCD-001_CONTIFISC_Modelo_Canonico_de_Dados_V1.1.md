# MCD-001 --- Modelo Canônico de Dados da CONTIFISC

**Versão:** 1.1\
**Status:** APROVADO --- baseline canônica para Fase 1\
**Supersede:** MCD-001 V1.0\
**Incorpora:** MCD-CHANGE-REQUEST-001\
**Dependências:** CAF-001, CDC-001, DST-001, COT-001\
**Escopo:** CONTIFISC Intelligence Platform --- profissionais da saúde

> **Princípio central:** o MCD define a representação canônica dos dados
> e permanece independente de ERP, ORM, banco hospedado ou interface. O
> schema físico é uma implementação do MCD/COT/CDC/DST, não sua fonte de
> verdade.

## 1. Objetivo

Consolidar a gramática oficial dos dados após a formalização dos
contratos e objetos canônicos, corrigindo a nomenclatura da V1.0,
formalizando relacionamentos e proveniência e estabelecendo a baseline
que pode orientar tipos TypeScript e, onde completamente definido, o
futuro schema físico.

## 2. Decisões arquiteturais da baseline V1.1

-   Um conceito possui nome canônico e ID MCD permanente; mudanças são
    governadas, não 'congeladas para sempre'.
-   Unidade Econômica é contexto agregador; Pessoa Física e Pessoa
    Jurídica preservam identidade própria.
-   `Vinculo` é objeto de primeira classe com origem, destino, papel e
    vigência.
-   Fatos canônicos são separados de documentos, classificações,
    cálculos e cenários.
-   Proveniência e reconciliação são requisitos estruturais.
-   PessoaFisica não é ContaAcesso; autenticação permanece no domínio
    SEC e fora do schema tributário.
-   Competência é conceito mensal `YYYY-MM` no contrato; não é uma data
    fictícia do primeiro dia do mês.
-   PostgreSQL/Prisma podem ser usados na implementação, mas
    Neon/Supabase/RDS/Questor não entram no modelo canônico.

## 3. Convenção de nomenclatura V1.1

-   `snake_case`, ASCII, nomes descritivos em português.
-   PK de cada objeto: `id`.
-   FK/referência: `<objeto>_id`, por exemplo `pessoa_fisica_id`,
    `receita_id`.
-   Datas de negócio: `data_*`; timestamps de sistema: `*_em`; vigência:
    `vigencia_inicio`/`vigencia_fim`.
-   Competência: `competencia`, sem prefixo de data.
-   Dinheiro: `valor_*`; percentuais: `percentual_*`; status:
    `status_*`; tipos: `tipo_*`.
-   Identificadores de negócio permanecem semanticamente explícitos:
    `cpf`, `cnpj`, `cnae_principal`, `municipio_ibge`.
-   Não codificar tipo físico no nome do campo.

## 4. Tipos canônicos

  -------------------------------------------------------------------------
  Tipo              Contrato canônico   Persistência      Regra
                                        recomendada       
  ----------------- ------------------- ----------------- -----------------
  UUID              UUID                UUID nativo       ID interno; não
                                                          usar CPF/CNPJ
                                                          como PK.

  Dinheiro          Decimal             NUMERIC(18,2)     Float proibido.

  Percentual        Decimal             NUMERIC(7,4)      32,0000
                                                          representa 32%
                                                          até mudança
                                                          formal.

  Date              YYYY-MM-DD          DATE              Sem horário.

  Competência       YYYY-MM             Implementação     Não converter
                                        física a decidir  semanticamente
                                                          para dia 01.

  Timestamp TZ      ISO-8601            TIMESTAMPTZ       Persistência UTC.
                    offset-aware                          

  CPF/CNPJ          Somente dígitos     VARCHAR           Máscara somente
                                                          na UI.

  Enum              Código estável DST  VARCHAR/enum      Descrição
                                        técnico           separada.

  Boolean           true/false          BOOLEAN           null somente se
                                                          semanticamente
                                                          necessário.

  SemVer            MAJOR.MINOR.PATCH   VARCHAR           Validar formato.
  -------------------------------------------------------------------------

## 5. Nulidade e estados especiais

-   `null` significa ausência/desconhecimento conforme contrato; nunca é
    convertido automaticamente em zero.
-   `NAO_INFORMADO`, `PENDENTE`, `NAO_APLICAVEL`, `OUTRO` e `ESTIMADO`
    obedecem ao DST e não são sinônimos.
-   Zero é valor conhecido igual a zero.
-   Campos obrigatórios por operação continuam definidos pelo CDC.
-   Resultado com inputs incompletos deve registrar qualidade/revisão,
    não inventar valor.

## 6. Domínios canônicos

  ---------------------------------------------------------------------------
  Código                  Domínio                 Responsabilidade
  ----------------------- ----------------------- ---------------------------
  DOM-CORE                Núcleo                  Unidade Econômica e
                                                  contexto agregador.

  DOM-PER                 Pessoa Física           Identidade tributária e
                                                  qualificações da pessoa.

  DOM-EMP                 Pessoa Jurídica         Identidade PJ e atributos
                                                  tributários temporais.

  DOM-REL                 Relacionamentos         Vínculos entre objetos
                                                  canônicos.

  DOM-REC                 Receitas                Receitas e fontes
                                                  pagadoras.

  DOM-FIS                 Fiscal                  Documentos fiscais
                                                  normalizados.

  DOM-EH                  Equiparação Hospitalar  Resultados derivados de
                                                  classificação/segregação.

  DOM-PRE                 Previdenciário          Contribuições e vínculos
                                                  previdenciários.

  DOM-IRP                 IRPF/Carnê-Leão         Fatos e resultados
                                                  relevantes à PF.

  DOM-PLN                 Planejamento            Cenários tributários.

  DOM-SYS                 Sistema/Qualidade       Proveniência, arquivos,
                                                  cálculo, conflito, revisão.

  DOM-SEC                 Segurança               Conta/credenciais;
                                                  detalhamento bloqueado até
                                                  SEC-001.
  ---------------------------------------------------------------------------

## 7. Catálogo canônico V1.1 (119 campos)

A coluna `Obrig. base` indica requisito estrutural mínimo; o CDC
continua soberano para obrigatoriedade por operação.

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  ID          Domínio    Campo                                         Significado              Tipo             Unidade   Origem típica            Obrig.   Política
                                                                                                                                                    base     
  ----------- ---------- --------------------------------------------- ------------------------ ---------------- --------- ------------------------ -------- ------------
  MCD-F0001   DOM-CORE   id                                            Identificador da Unidade UUID             \-        Sistema                  Sim      Imutável
                                                                       Econômica                                                                             

  MCD-F0002   DOM-CORE   nome                                          Nome da Unidade          Texto(160)       \-        Cadastro                 Sim      Versionado
                                                                       Econômica                                                                             

  MCD-F0003   DOM-CORE   status_registro                               Situação do registro     Enum             \-        Sistema/Cadastro         Sim      Versionado

  MCD-F0004   DOM-CORE   criado_em                                     Data/hora de criação     Timestamp TZ     \-        Sistema                  Sim      Imutável

  MCD-F0005   DOM-CORE   atualizado_em                                 Data/hora da última      Timestamp TZ     \-        Sistema                  Sim      Versionado
                                                                       atualização                                                                           

  MCD-F1001   DOM-PER    id                                            Identificador da Pessoa  UUID             \-        Sistema                  Sim      Imutável
                                                                       Física                                                                                

  MCD-F1002   DOM-PER    cpf                                           CPF                      Texto(11)        dígitos   Cadastro/Importação      Cond.    Versionado

  MCD-F1003   DOM-PER    nome                                          Nome completo            Texto(200)       \-        Cadastro/Importação      Sim      Versionado

  MCD-F1004   DOM-PER    data_nascimento                               Data de nascimento       Date             \-        Cadastro/Importação      Não      Versionado

  MCD-F1005   DOM-PER    conselho_profissional                         Enum/Ref                 Conselho         \-        Cadastro                 Não      Versionado
                                                                                                profissional                                                 

  MCD-F1006   DOM-PER    registro_profissional                         Número/registro no       Texto(30)        \-        Cadastro                 Não      Versionado
                                                                       conselho                                                                              

  MCD-F1007   DOM-PER    uf_registro_profissional                      UF do conselho           Texto(2)         UF        Cadastro                 Não      Versionado

  MCD-F1008   DOM-PER    especialidade_saude                           Especialidade/área       Enum/Ref         \-        Cadastro                 Não      Versionado
                                                                       profissional                                                                          

  MCD-F2001   DOM-EMP    id                                            Identificador da Pessoa  UUID             \-        Sistema                  Sim      Imutável
                                                                       Jurídica                                                                              

  MCD-F2002   DOM-EMP    cnpj                                          CNPJ                     Texto(14)        dígitos   ERP/Cadastro             Cond.    Versionado

  MCD-F2003   DOM-EMP    razao_social                                  Razão social             Texto(200)       \-        ERP/Cadastro             Não      Versionado

  MCD-F2004   DOM-EMP    regime_tributario                             Regime tributário        Enum             \-        ERP/Cadastro             Cond.    Temporal

  MCD-F2005   DOM-EMP    cnae_principal                                CNAE principal           Texto(7)         dígitos   ERP/Cadastro             Não      Temporal

  MCD-F2006   DOM-EMP    data_abertura                                 Data de abertura         Date             \-        ERP/Cadastro             Não      Versionado

  MCD-F2007   DOM-EMP    municipio_ibge                                Código do município IBGE Texto(7)         IBGE      ERP/Cadastro             Não      Temporal

  MCD-F2501   DOM-REL    id                                            Identificador do Vínculo UUID             \-        Sistema                  Sim      Imutável

  MCD-F2502   DOM-REL    tipo_vinculo                                  Tipo estrutural do       Enum             \-        Cadastro/Sistema         Sim      Temporal
                                                                       vínculo                                                                               

  MCD-F2503   DOM-REL    percentual_participacao_societaria            Participação societária  Decimal(7,4)     \%        ERP/Cadastro             Não      Temporal

  MCD-F2504   DOM-REL    vigencia_inicio                               Início da vigência do    Date             \-        ERP/Cadastro             Não      Temporal
                                                                       vínculo                                                                               

  MCD-F2505   DOM-REL    vigencia_fim                                  Fim da vigência do       Date             \-        ERP/Cadastro             Não      Temporal
                                                                       vínculo                                                                               

  MCD-F2506   DOM-REL    objeto_origem_id                              Objeto canônico de       UUID             \-        Sistema/Cadastro         Sim      Temporal
                                                                       origem do vínculo                                                                     

  MCD-F2507   DOM-REL    tipo_objeto_origem                            Tipo canônico do objeto  Enum             \-        Sistema/Cadastro         Sim      Temporal
                                                                       de origem                                                                             

  MCD-F2508   DOM-REL    objeto_destino_id                             Objeto canônico de       UUID             \-        Sistema/Cadastro         Sim      Temporal
                                                                       destino do vínculo                                                                    

  MCD-F2509   DOM-REL    tipo_objeto_destino                           Tipo canônico do objeto  Enum             \-        Sistema/Cadastro         Sim      Temporal
                                                                       de destino                                                                            

  MCD-F2510   DOM-REL    papel_vinculo                                 Papel exercido no        Enum             \-        Cadastro/Sistema         Cond.    Temporal
                                                                       relacionamento                                                                        

  MCD-F3001   DOM-REC    id                                            Identificador da Receita UUID             \-        Sistema                  Sim      Imutável

  MCD-F3002   DOM-REC    valor_receita_bruta                           Valor bruto da receita   Decimal(18,2)    BRL       ERP/XML/Manual           Cond.    Fato
                                                                                                                                                             imutável

  MCD-F3003   DOM-REC    data_emissao                                  Data de emissão          Date             \-        XML/Documento            Não      Fato
                                                                                                                                                             imutável

  MCD-F3004   DOM-REC    competencia                                   Competência              Competência      YYYY-MM   ERP/XML/Manual           Cond.    Fato
                                                                                                                                                             imutável

  MCD-F3005   DOM-REC    fonte_receita                                 Fonte da receita         Enum/Ref         \-        Classificação            Cond.    Versionado

  MCD-F3006   DOM-REC    tipo_titular                                  Tipo do titular: PF/PJ   Enum             \-        Sistema/Classificação    Sim      Versionado

  MCD-F3007   DOM-REC    fonte_pagadora_id                             Fonte pagadora           UUID/Ref         \-        Importação/Cadastro      Não      Versionado

  MCD-F3008   DOM-REC    valor_retencoes                               Retenções vinculadas     Decimal(18,2)    BRL       XML/Informe              Não      Fato
                                                                                                                                                             imutável

  MCD-F3009   DOM-REC    titular_id                                    Titular econômico da     UUID             \-        Sistema/Classificação    Sim      Versionado
                                                                       receita                                                                               

  MCD-F4001   DOM-FIS    id                                            Identificador do         UUID             \-        Sistema                  Sim      Imutável
                                                                       Documento Fiscal                                                                      

  MCD-F4002   DOM-FIS    tipo_documento_fiscal                         Tipo do documento fiscal Enum             \-        Importação               Sim      Fato
                                                                                                                                                             imutável

  MCD-F4003   DOM-FIS    numero_documento_fiscal                       Número do documento      Texto(60)        \-        XML/Documento            Não      Fato
                                                                                                                                                             imutável

  MCD-F4004   DOM-FIS    chave_documento_fiscal                        Chave/ID externo         Texto(80)        \-        XML/API                  Não      Fato
                                                                                                                                                             imutável

  MCD-F4005   DOM-FIS    codigo_servico_fiscal                         Código do serviço        Texto(30)        \-        XML/API                  Não      Fato
                                                                                                                                                             imutável

  MCD-F4006   DOM-FIS    descricao_servico_fiscal                      Descrição do serviço     Texto longo      \-        XML/API                  Não      Fato
                                                                                                                                                             imutável

  MCD-F4007   DOM-FIS    valor_documento_fiscal                        Valor total do documento Decimal(18,2)    BRL       XML/API                  Não      Fato
                                                                                                                                                             imutável

  MCD-F4008   DOM-FIS    arquivo_origem_id                             Arquivo bruto de origem  UUID/Ref         \-        Sistema                  Não      Imutável

  MCD-F5001   DOM-EH     status_elegibilidade_equiparacao_hospitalar   Status de elegibilidade  Enum             \-        Motor/Revisão            Cond.    Resultado
                                                                       EqHop                                                                                 versionado

  MCD-F5002   DOM-EH     percentual_receita_elegivel                   Percentual elegível      Decimal(7,4)     \%        Motor/Revisão            Não      Resultado
                                                                                                                                                             versionado

  MCD-F5003   DOM-EH     valor_receita_elegivel                        Valor elegível segregado Decimal(18,2)    BRL       Cálculo                  Não      Resultado
                                                                                                                                                             versionado

  MCD-F5004   DOM-EH     valor_receita_nao_elegivel                    Valor não elegível       Decimal(18,2)    BRL       Cálculo                  Não      Resultado
                                                                       segregado                                                                             versionado

  MCD-F5005   DOM-EH     percentual_confianca_classificacao            Confiança do             Decimal(7,4)     \%        IA/Classificador         Não      Resultado
                                                                       classificador                                                                         versionado

  MCD-F5006   DOM-EH     validacao_tecnica                             Indica validação         Boolean          \-        CONTIFISC                Não      Resultado
                                                                       humana/técnica                                                                        versionado

  MCD-F5007   DOM-EH     receita_id                                    Receita submetida à      UUID             \-        Sistema/Motor            Sim      Resultado
                                                                       classificação                                                                         versionado

  MCD-F5008   DOM-EH     regra_versao_id                               Versão/conjunto de regra Texto/UUID       \-        Motor                    Cond.    Resultado
                                                                       aplicado                                                                              versionado

  MCD-F6001   DOM-PRE    id                                            Identificador da         UUID             \-        Sistema                  Sim      Imutável
                                                                       Contribuição                                                                          
                                                                       Previdenciária                                                                        

  MCD-F6002   DOM-PRE    valor_inss_recolhido                          INSS recolhido           Decimal(18,2)    BRL       CNIS/Folha/Informe       Cond.    Fato
                                                                                                                                                             imutável

  MCD-F6003   DOM-PRE    valor_salario_contribuicao                    Salário/base de          Decimal(18,2)    BRL       CNIS/Folha               Não      Fato
                                                                       contribuição                                                                          imutável

  MCD-F6004   DOM-PRE    valor_teto_previdenciario                     Teto da competência      Decimal(18,2)    BRL       Tabela legal             Cond.    Referência
                                                                                                                                                             versionada

  MCD-F6005   DOM-PRE    valor_excedente_inss                          Excedente potencial      Decimal(18,2)    BRL       Cálculo                  Não      Resultado
                                                                       calculado                                                                             versionado

  MCD-F6006   DOM-PRE    vinculo_previdenciario_id                     Fonte/vínculo            UUID/Ref         \-        CNIS/Cadastro            Não      Temporal
                                                                       previdenciário                                                                        

  MCD-F6007   DOM-PRE    pessoa_fisica_id                              Titular da contribuição  UUID             \-        Sistema                  Sim      Versionado

  MCD-F6101   DOM-PRE    id                                            Identificador do Vínculo UUID             \-        Sistema                  Sim      Imutável
                                                                       Previdenciário                                                                        

  MCD-F6102   DOM-PRE    pessoa_fisica_id                              Pessoa titular do        UUID             \-        Sistema/Cadastro         Sim      Temporal
                                                                       vínculo                                                                               

  MCD-F6103   DOM-PRE    tipo_vinculo_previdenciario                   Tipo/fonte               Enum             \-        CNIS/Cadastro            Sim      Temporal
                                                                       previdenciária                                                                        

  MCD-F6104   DOM-PRE    vigencia_inicio                               Início da vigência       Date             \-        CNIS/Cadastro            Não      Temporal

  MCD-F6105   DOM-PRE    vigencia_fim                                  Fim da vigência          Date             \-        CNIS/Cadastro            Não      Temporal

  MCD-F7001   DOM-IRP    id                                            Identificador do Evento  UUID             \-        Sistema                  Sim      Imutável
                                                                       IRPF                                                                                  

  MCD-F7002   DOM-IRP    tipo_rendimento_irpf                          Natureza do rendimento   Enum             \-        Classificação/Informe    Cond.    Versionado

  MCD-F7003   DOM-IRP    valor_rendimento_tributavel                   Rendimento tributável    Decimal(18,2)    BRL       Informe/Carnê/ERP        Não      Fato
                                                                                                                                                             imutável

  MCD-F7004   DOM-IRP    valor_rendimento_isento                       Rendimento isento        Decimal(18,2)    BRL       Informe/ERP              Não      Fato
                                                                                                                                                             imutável

  MCD-F7005   DOM-IRP    valor_deducao_irpf                            Dedução considerada      Decimal(18,2)    BRL       Documento/Carnê          Não      Versionado

  MCD-F7006   DOM-IRP    valor_livro_caixa                             Despesa de livro-caixa   Decimal(18,2)    BRL       Carnê/Manual             Não      Versionado

  MCD-F7007   DOM-IRP    valor_irpf_retido                             IRPF retido              Decimal(18,2)    BRL       Informe                  Não      Fato
                                                                                                                                                             imutável

  MCD-F7008   DOM-IRP    valor_irpf_projetado                          IRPF projetado           Decimal(18,2)    BRL       Cálculo                  Não      Resultado
                                                                                                                                                             versionado

  MCD-F7009   DOM-IRP    pessoa_fisica_id                              Titular do evento IRPF   UUID             \-        Sistema                  Sim      Versionado

  MCD-F7010   DOM-IRP    fonte_pagadora_id                             Fonte pagadora do        UUID/Ref         \-        Importação/Cadastro      Não      Versionado
                                                                       rendimento                                                                            

  MCD-F7201   DOM-REC    id                                            Identificador da Fonte   UUID             \-        Sistema                  Sim      Imutável
                                                                       Pagadora                                                                              

  MCD-F7202   DOM-REC    tipo_fonte_pagadora                           Tipo da fonte pagadora   Enum             \-        Cadastro/Classificação   Sim      Versionado

  MCD-F7203   DOM-REC    identificador_fiscal                          CPF/CNPJ/identificador   Texto(20)        \-        Cadastro/Importação      Não      Versionado
                                                                       da fonte quando                                                                       
                                                                       disponível                                                                            

  MCD-F7204   DOM-REC    nome                                          Nome/razão da fonte      Texto(200)       \-        Cadastro/Importação      Não      Versionado
                                                                       pagadora                                                                              

  MCD-F8001   DOM-PLN    id                                            Identificador do Cenário UUID             \-        Sistema                  Sim      Imutável
                                                                       Tributário                                                                            

  MCD-F8002   DOM-PLN    nome                                          Nome do cenário          Texto(120)       \-        Usuário/Sistema          Sim      Versionado

  MCD-F8003   DOM-PLN    valor_carga_tributaria_projetada              Carga tributária         Decimal(18,2)    BRL       Cálculo                  Não      Resultado
                                                                       projetada                                                                             versionado

  MCD-F8004   DOM-PLN    valor_economia_tributaria_projetada           Economia tributária      Decimal(18,2)    BRL       Cálculo                  Não      Resultado
                                                                       projetada                                                                             versionado

  MCD-F8005   DOM-PLN    unidade_economica_id                          Contexto econômico       UUID             \-        Sistema                  Sim      Versionado
                                                                       avaliado                                                                              

  MCD-F8201   DOM-SYS    id                                            Identificador do         UUID             \-        Sistema                  Sim      Imutável
                                                                       Resultado de Cálculo                                                                  

  MCD-F8202   DOM-SYS    cenario_tributario_id                         Cenário relacionado      UUID/Ref         \-        Sistema                  Não      Versionado
                                                                       quando aplicável                                                                      

  MCD-F8203   DOM-SYS    input_snapshot_hash                           Hash do snapshot de      Texto(128)       \-        Motor                    Sim      Imutável
                                                                       entradas                                                                              

  MCD-F8204   DOM-SYS    engine_id                                     Identificador do motor   Texto(80)        \-        Motor                    Sim      Imutável

  MCD-F8205   DOM-SYS    engine_version                                Versão do motor          Texto(20)        SemVer    Motor                    Sim      Imutável

  MCD-F8206   DOM-SYS    rule_set_id                                   Conjunto de regras       Texto(80)        \-        Motor                    Sim      Imutável
                                                                       utilizado                                                                             

  MCD-F8207   DOM-SYS    rule_set_version                              Versão do conjunto de    Texto(20)        SemVer    Motor                    Sim      Imutável
                                                                       regras                                                                                

  MCD-F8208   DOM-SYS    calculado_em                                  Momento do cálculo       Timestamp TZ     \-        Motor                    Sim      Imutável

  MCD-F8209   DOM-SYS    status_revisao                                Status de revisão do     Enum             \-        Motor/Revisor            Não      Versionado
                                                                       resultado                                                                             

  MCD-F8401   DOM-SYS    id                                            Identificador do Arquivo UUID             \-        Sistema                  Sim      Imutável
                                                                       de Origem                                                                             

  MCD-F8402   DOM-SYS    nome_arquivo                                  Nome original/lógico do  Texto(255)       \-        Ingestão                 Não      Imutável
                                                                       arquivo                                                                               

  MCD-F8403   DOM-SYS    hash_conteudo                                 Hash do conteúdo bruto   Texto(128)       \-        Ingestão                 Sim      Imutável

  MCD-F8404   DOM-SYS    tipo_mime                                     MIME type                Texto(120)       \-        Ingestão                 Não      Imutável

  MCD-F8405   DOM-SYS    armazenamento_referencia                      Referência segura ao     Texto(500)       \-        Ingestão                 Sim      Versionado
                                                                       objeto armazenado                                                                     

  MCD-F8601   DOM-SYS    id                                            Identificador do         UUID             \-        Sistema                  Sim      Imutável
                                                                       Conflito de Dados                                                                     

  MCD-F8602   DOM-SYS    status_conflito                               Status do conflito       Enum             \-        Reconciliação            Sim      Versionado

  MCD-F8603   DOM-SYS    tipo_conflito                                 Natureza do conflito     Enum             \-        Reconciliação            Sim      Versionado

  MCD-F8604   DOM-SYS    descricao                                     Descrição técnica do     Texto longo      \-        Reconciliação            Não      Versionado
                                                                       conflito                                                                              

  MCD-F8701   DOM-SYS    id                                            Identificador da Revisão UUID             \-        Sistema                  Sim      Imutável
                                                                       Técnica                                                                               

  MCD-F8702   DOM-SYS    objeto_revisado_id                            Objeto/resultado         UUID             \-        Sistema                  Sim      Imutável
                                                                       revisado                                                                              

  MCD-F8703   DOM-SYS    tipo_objeto_revisado                          Tipo do objeto revisado  Enum             \-        Sistema                  Sim      Imutável

  MCD-F8704   DOM-SYS    status_revisao                                Decisão/status da        Enum             \-        Revisor                  Sim      Versionado
                                                                       revisão                                                                               

  MCD-F8705   DOM-SYS    justificativa                                 Justificativa da revisão Texto longo      \-        Revisor                  Cond.    Imutável

  MCD-F8706   DOM-SYS    revisado_em                                   Momento da revisão       Timestamp TZ     \-        Sistema                  Sim      Imutável

  MCD-F9001   DOM-SYS    sistema_origem                                Sistema/processo de      Enum/Texto       \-        Gateway/Sistema          Sim\*    Imutável
                                                                       origem                                                                                

  MCD-F9002   DOM-SYS    identificador_origem                          Identificador do         Texto(120)       \-        Gateway                  Não      Imutável
                                                                       registro na origem                                                                    

  MCD-F9003   DOM-SYS    importado_em                                  Data/hora de importação  Timestamp TZ     \-        Gateway                  Não      Imutável

  MCD-F9004   DOM-SYS    status_qualidade_dado                         Qualidade do dado        Enum             \-        Validador/Revisor        Não      Versionado

  MCD-F9005   DOM-SYS    versao_schema                                 Versão do                Texto(20)        SemVer    Sistema/Gateway          Sim\*    Imutável
                                                                       schema/contrato                                                                       

  MCD-F9006   DOM-SYS    correlation_id                                Correlação entre         UUID             \-        Sistema/Gateway          Não      Imutável
                                                                       operações/importações                                                                 

  MCD-F9007   DOM-SYS    registrado_em                                 Momento do registro      Timestamp TZ     \-        Sistema                  Sim\*    Imutável
                                                                       canônico                                                                              

  MCD-F9008   DOM-SYS    data_fato                                     Data de ocorrência do    Date/Timestamp   \-        Origem/Normalização      Não      Fato
                                                                       fato                                                                                  imutável

  MCD-F9009   DOM-SYS    arquivo_origem_id                             Evidência RAW associada  UUID/Ref         \-        Sistema/Gateway          Não      Imutável
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------

## 8. Metadados transversais

Os campos `MCD-F9001..F9009` compõem a semântica transversal de
proveniência/registro. **Não há obrigação de replicá-los fisicamente em
todas as tabelas.** A persistência poderá usar composição, tabelas de
lineage/proveniência ou envelope técnico, desde que CDC e auditoria
sejam preservados.

-   `sistema_origem` + `identificador_origem` sustentam idempotência e
    rastreabilidade.
-   `arquivo_origem_id` liga o fato à evidência RAW quando aplicável.
-   `correlation_id` correlaciona ingestão, transformação, evento e
    cálculo.
-   `registrado_em`, `importado_em`, `data_fato` e `competencia`
    representam tempos diferentes.
-   `status_qualidade_dado` não altera o conteúdo do fato; registra sua
    condição de uso.

## 9. Relacionamentos estruturais

O COT é a fonte conceitual das cardinalidades. O MCD V1.1 fornece os
campos necessários para implementá-las sem inventar FKs.

  ---------------------------------------------------------------------------------------------
  Relação                             Implementação canônica mínima
  ----------------------------------- ---------------------------------------------------------
  UE/PF/PJ                            Via `Vinculo`: `objeto_origem_id`, `tipo_objeto_origem`,
                                      `objeto_destino_id`, `tipo_objeto_destino`,
                                      `tipo_vinculo`, `papel_vinculo`, vigência.

  Titular -\> Receita                 `Receita.titular_id` + `Receita.tipo_titular`.

  FontePagadora -\> Receita           `Receita.fonte_pagadora_id`.

  Receita -\> EqHop                   `ClassificacaoEquiparacaoHospitalar.receita_id`.

  PF -\> Contribuição                 `ContribuicaoPrevidenciaria.pessoa_fisica_id`.

  Vínculo Previdenciário -\>          `ContribuicaoPrevidenciaria.vinculo_previdenciario_id`.
  Contribuição                        

  PF -\> EventoIRPF                   `EventoIRPF.pessoa_fisica_id`.

  FontePagadora -\> EventoIRPF        `EventoIRPF.fonte_pagadora_id`.

  UE -\> Cenário                      `CenarioTributario.unidade_economica_id`.

  Cenário -\> Resultado               `ResultadoCalculo.cenario_tributario_id` quando
                                      aplicável.
  ---------------------------------------------------------------------------------------------

## 10. Fatos, documentos e resultados

-   `Receita`, `ContribuicaoPrevidenciaria` e `EventoIRPF` são fatos
    canônicos.
-   `DocumentoFiscal` e `ArquivoOrigem` são documento/evidência, não
    substituem fatos.
-   `ClassificacaoEquiparacaoHospitalar` e `ResultadoCalculo` são
    resultados derivados versionados.
-   `CenarioTributario` é sandbox de planejamento e nunca altera fatos
    oficiais.
-   `ConflitoDado` e `RevisaoTecnica` preservam decisões de
    qualidade/human-in-the-loop.

## 11. Equiparação Hospitalar

-   A classificação é ligada à `receita_id`, não gravada como atributo
    estático da empresa.
-   `regra_versao_id` é obrigatória quando houver decisão
    calculada/aprovada.
-   Percentuais/valores elegíveis não substituem `valor_receita_bruta`.
-   Confiança do classificador e validação técnica são dimensões
    distintas.
-   A base legal e lógica executável pertencem ao RGT, não ao MCD.

## 12. IRPF/Carnê-Leão e Previdenciário

-   PF é a raiz dos fatos de IRPF e contribuição previdenciária; nenhum
    CNPJ é obrigatório.
-   Múltiplos vínculos previdenciários podem coexistir na mesma
    competência.
-   CNIS, folha, informe, Carnê-Leão e ERP são fontes
    externas/candidatas, não modelos de domínio.
-   Excedente INSS e IRPF projetado são resultados derivados e devem
    manter versão de regra/cálculo.

## 13. Autenticação e domínio SEC

-   `ContaAcesso` e `CredencialAcesso` permanecem objetos conceituais do
    COT.
-   Esta V1.1 **não define campos de credencial**, e-mail de login,
    senha, MFA ou sessão.
-   PessoaFisica pode existir sem ContaAcesso; conta técnica pode
    existir sem representar contribuinte.
-   O schema de autenticação fica bloqueado até SEC-001 ou Change
    Request específico aprovado.

## 14. Migração de nomenclatura V1.0 -\> V1.1

Como ainda não existe schema físico de negócio, os nomes V1.0 são
**SUPERSEDED** e não devem ser introduzidos em código novo. Os IDs MCD
abaixo permanecem quando o significado foi preservado.

  ------------------------------------------------------------------------------------------------------------------
  ID                Nome V1.0                        Nome V1.1                                     Observação
  ----------------- -------------------------------- --------------------------------------------- -----------------
  MCD-F0001         id_unidade_economica             id                                            Renomeação;
                                                                                                   significado
                                                                                                   preservado

  MCD-F0002         nm_unidade_economica             nome                                          Renomeação

  MCD-F0003         st_registro                      status_registro                               Renomeação

  MCD-F0004         dt_criacao                       criado_em                                     Timestamp de
                                                                                                   sistema

  MCD-F0005         dt_atualizacao                   atualizado_em                                 Timestamp de
                                                                                                   sistema

  MCD-F1001         id_pessoa                        id                                            PK local do
                                                                                                   objeto

  MCD-F1002         nr_cpf                           cpf                                           Renomeação

  MCD-F1003         nm_pessoa                        nome                                          Renomeação

  MCD-F2001         id_empresa                       id                                            PK local do
                                                                                                   objeto

  MCD-F2002         nr_cnpj                          cnpj                                          Renomeação

  MCD-F2003         nm_razao_social                  razao_social                                  Renomeação

  MCD-F2004         cd_regime_tributario             regime_tributario                             Renomeação

  MCD-F2501         id_relacionamento                id                                            Objeto renomeado
                                                                                                   semanticamente
                                                                                                   para Vinculo

  MCD-F2502         tp_relacionamento                tipo_vinculo                                  Alinhamento ao
                                                                                                   COT

  MCD-F3001         id_receita                       id                                            PK local

  MCD-F3002         vl_receita_bruta                 valor_receita_bruta                           Renomeação

  MCD-F3003         dt_emissao                       data_emissao                                  Renomeação

  MCD-F3004         dt_competencia                   competencia                                   Competência deixa
                                                                                                   de ser DATE
                                                                                                   fictícia

  MCD-F3006         tp_titular_receita               tipo_titular                                  Renomeação

  MCD-F4001         id_documento_fiscal              id                                            PK local

  MCD-F5001         st_elegibilidade_eh              status_elegibilidade_equiparacao_hospitalar   Explicitação
                                                                                                   semântica

  MCD-F6001         id_contribuicao_previdenciaria   id                                            PK local

  MCD-F7001         id_evento_irpf                   id                                            PK local

  MCD-F8001         id_cenario_tributario            id                                            PK local

  MCD-F9001         cd_sistema_origem                sistema_origem                                Renomeação

  MCD-F9002         id_registro_origem               identificador_origem                          Evita confusão
                                                                                                   com ID canônico

  MCD-F9003         dt_importacao                    importado_em                                  Timestamp de
                                                                                                   sistema

  MCD-F9004         st_qualidade_dado                status_qualidade_dado                         Renomeação

  MCD-F9005         nr_versao_schema                 versao_schema                                 Renomeação
  ------------------------------------------------------------------------------------------------------------------

## 15. Regras para TypeScript, APIs e Prisma

-   Types canônicos novos usam os nomes V1.1.
-   Interfaces de domínio não embutem relações arbitrariamente; relações
    seguem COT/CDC.
-   Prisma models devem documentar mapeamento
    `COT -> MCD -> CDC -> DST`.
-   Campo físico adicional exige Change Request.
-   Competência em types/API usa `YYYY-MM`; conversão física fica
    isolada no repositório/mapper.
-   Dinheiro/percentual não usam JavaScript `number` quando isso causar
    perda de precisão; adotar representação/validador decimal
    apropriado.
-   Gateway e adapters não importam models Prisma nem expõem schema de
    fornecedor ao domínio.

## 16. Política para Claude Code

``` yaml
mcd_policy:
  version: 1.1
  source_of_truth: docs/02-Data/MCD-001.md
  supersedes: MCD-001-v1.0
  naming:
    style: snake_case
    language: pt-BR-canonical
    type_prefixes: prohibited
    primary_key: id
    foreign_key: <objeto>_id
  competence:
    contract_format: YYYY-MM
    fake_first_day_date: prohibited
  allow_new_field_without_mcd: false
  allow_new_object_without_cot: false
  allow_erp_field_names_in_domain: false
  allow_auth_fields_in_pessoa_fisica: false
  money_type: decimal
  ids: uuid
  preserve_provenance: true
  preserve_history: true
  derived_overwrites_fact: false
  vendor_specific_domain_model: false
```

## 17. O que está liberado após V1.1

-   Atualizar `packages/types` para UnidadeEconomica, PessoaFisica e
    PessoaJuridica com nomes V1.1.
-   Implementar `Vinculo` e demais types somente quando todos os
    enums/contratos necessários estiverem disponíveis; lacunas geram
    Change Request.
-   Implementar Gateway genérico e validações técnicas independentes de
    persistência.
-   Preparar proposta de schema Prisma mapeada aos documentos; migration
    continua condicionada à revisão da proposta.
-   Não implementar autenticação real antes do SEC-001.
-   Não implementar lógica tributária antes do RGT aplicável.

## 18. Critérios de aceite

-   [ ] Nomenclatura descritiva V1.1 substitui prefixos técnicos.
-   [ ] Competência é YYYY-MM no domínio/contrato.
-   [ ] Vinculo possui origem/destino/papel/vigência.
-   [ ] Titularidade de Receita, IRPF e Previdenciário está explícita.
-   [ ] EqHop referencia Receita e regra versionada.
-   [ ] Proveniência e cálculo reproduzível estão formalizados.
-   [ ] Autenticação permanece separada.
-   [ ] Modelo continua vendor-neutral.
-   [ ] Nenhum campo novo pode ser inventado pelo código.

## 19. Próximas revisões

1.  Sincronizar CDC-001 e DST-001 com a nomenclatura V1.1, preservando a
    semântica.\
2.  Emitir SEC-001 antes de autenticação.\
3.  Desenvolver RGT-001 para regras tributárias/legais.\
4.  Desenvolver EVT-001 e INT-001 para eventos e integrações.

------------------------------------------------------------------------

**Decisão de governança:** MCD-001 V1.1 é a baseline canônica vigente.
MCD-001 V1.0 permanece apenas como histórico e deve ser marcado
`SUPERSEDED` no repositório.
