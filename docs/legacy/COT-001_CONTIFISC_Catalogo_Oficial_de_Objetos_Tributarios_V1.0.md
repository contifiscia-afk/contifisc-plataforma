# COT-001 --- Catálogo Oficial de Objetos Tributários da CONTIFISC

**Versão:** 1.0\
**Status:** Documento Fundador --- V1\
**Dependências:** CAF-001, MCD-001, CDC-001, DST-001\
**Consumidores:** schema físico, Prisma, APIs, RGT-001, EVT-001,
INT-001, ATI-001, GTI-001, MIT-001 e Skills

> **Objetivo:** definir os objetos canônicos da plataforma, suas
> responsabilidades, relacionamentos, cardinalidades, ownership
> semântico e ciclo de vida. O COT é o limite entre o modelo conceitual
> e a futura implementação física. Ele não define tabelas finais nem
> regras tributárias.

## 1. Decisões estruturais

-   Unidade Econômica é um contexto agregador interno, não um
    contribuinte.
-   Pessoa Física e Pessoa Jurídica são entidades tributárias
    independentes e podem participar de múltiplos contextos.
-   Relacionamentos são objetos de primeira classe com tipo, papel,
    vigência e atributos; não devem ser reduzidos a foreign keys ad-hoc.
-   Receita, Contribuição Previdenciária e Evento IRPF são fatos
    canônicos; classificações e cálculos são resultados derivados.
-   Documento bruto/evidência é separado do fato normalizado.
-   Cenários de planejamento são isolados dos fatos oficiais.
-   Conta de acesso e credenciais pertencem ao domínio de segurança,
    separados de Pessoa Física.
-   Objetos do COT não equivalem automaticamente a tabelas. A
    implementação física poderá agrupar/separar estruturas desde que
    preserve contratos e semântica.
-   Os nomes canônicos de objetos são em português no domínio. Nomes
    físicos de tabela serão definidos na convenção de persistência; não
    devem dirigir o domínio.

## 2. Taxonomia de objetos

  ---------------------------------------------------------------------------------------------
  Tipo                    Definição                       Exemplos
  ----------------------- ------------------------------- -------------------------------------
  Entity                  Objeto com identidade própria e PessoaFisica, PessoaJuridica,
                          ciclo de vida.                  FontePagadora

  Relationship Entity     Relacionamento com              Vinculo, VinculoPrevidenciario
                          identidade/atributos/vigência   
                          próprios.                       

  Fact                    Fato econômico/tributário       Receita, ContribuicaoPrevidenciaria,
                          ocorrido e rastreável.          EventoIRPF

  Document/Evidence       Evidência bruta ou documento    DocumentoFiscal, ArquivoOrigem
                          normalizado.                    

  Derived Result          Resultado de                    ClassificacaoEquiparacaoHospitalar,
                          regra/cálculo/classificação     ResultadoCalculo
                          versionado.                     

  Scenario                Simulação isolada dos fatos     CenarioTributario
                          oficiais.                       

  Control                 Objeto de                       ConflitoDado, RevisaoTecnica
                          qualidade/revisão/auditoria.    

  Security Entity         Identidade e autenticação fora  ContaAcesso, CredencialAcesso
                          do domínio tributário.          
  ---------------------------------------------------------------------------------------------

## 3. Catálogo oficial de objetos V1

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------
  ID            Objeto técnico                       Nome              Domínio   Tipo           Responsabilidade           Owner semântico            Contrato
  ------------- ------------------------------------ ----------------- --------- -------------- -------------------------- -------------------------- -------------
  COT-OBJ-001   UnidadeEconomica                     Unidade Econômica CORE      Aggregate      Organiza o ecossistema     CONTIFISC                  CDC-UE-001
                                                                                 Context        econômico/tributário sem                              
                                                                                                ser sujeito fiscal.                                   

  COT-OBJ-002   PessoaFisica                         Pessoa Física     PER       Entity         Representa pessoa natural  Identidade tributária      CDC-PER-001
                                                                                                em papéis tributários,                                
                                                                                                societários ou                                        
                                                                                                profissionais.                                        

  COT-OBJ-003   PessoaJuridica                       Pessoa Jurídica   EMP       Entity         Representa empresa/CNPJ e  Identidade tributária PJ   CDC-EMP-001
                                                                                                atributos                                             
                                                                                                cadastrais/tributários                                
                                                                                                temporalmente válidos.                                

  COT-OBJ-004   Vinculo                              Vínculo           REL       Relationship   Representa relação com     Relacionamentos            CDC-REL-001
                                                                                 Entity         tipo, papel, vigência e                               
                                                                                                atributos próprios.                                   

  COT-OBJ-005   Receita                              Receita           REC       Fact           Fato econômico de receita  Titular da receita         CDC-REC-001
                                                                                                pertencente a PF ou PJ,                               
                                                                                                com competência e origem.                             

  COT-OBJ-006   DocumentoFiscal                      Documento Fiscal  FIS       Document       Representa NFS-e, NF-e ou  Fiscal                     CDC-FIS-001
                                                                                                outro documento fiscal                                
                                                                                                normalizado.                                          

  COT-OBJ-007   ArquivoOrigem                        Arquivo de Origem SYS       Evidence       Preserva/referencia        Ingestão/Documentos        CDC-SYS-001
                                                                                                documento bruto usado na                              
                                                                                                ingestão e auditoria.                                 

  COT-OBJ-008   ClassificacaoEquiparacaoHospitalar   Classificação     EH        Derived Result Resultado versionado de    Motor EqHop                CDC-EH-001
                                                     EqHop                                      classificação/segregação                              
                                                                                                de receita para EqHop.                                

  COT-OBJ-009   ContribuicaoPrevidenciaria           Contribuição      PRE       Fact           Fato contributivo por      Previdenciário             CDC-PRE-001
                                                     Previdenciária                             pessoa, vínculo/fonte e                               
                                                                                                competência.                                          

  COT-OBJ-010   VinculoPrevidenciario                Vínculo           PRE       Relationship   Fonte previdenciária       Previdenciário             CDC-PRE-001
                                                     Previdenciário              Entity         associada a uma pessoa e                              
                                                                                                vigência.                                             

  COT-OBJ-011   EventoIRPF                           Evento            IRP       Fact           Fato relevante ao IRPF,    IRPF                       CDC-IRP-001
                                                     IRPF/Carnê-Leão                            independente de existir                               
                                                                                                CNPJ.                                                 

  COT-OBJ-012   FontePagadora                        Fonte Pagadora    REC       Entity         Pessoa/organização que     Receitas                   CDC-REC-001
                                                                                                origina pagamento ou                                  
                                                                                                rendimento para PF/PJ.                                

  COT-OBJ-013   CenarioTributario                    Cenário           PLN       Scenario       Simulação isolada dos      Planejamento               CDC-PLN-001
                                                     Tributário                                 fatos oficiais, com                                   
                                                                                                premissas e resultados                                
                                                                                                próprios.                                             

  COT-OBJ-014   ResultadoCalculo                     Resultado de      SYS       Derived Result Snapshot reproduzível de   Motor responsável          CDC
                                                     Cálculo                                    cálculo com regras, engine                            transversal
                                                                                                e inputs versionados.                                 

  COT-OBJ-015   ConflitoDado                         Conflito de Dados SYS       Control        Registra divergência entre Qualidade/Reconciliation   CDC-SYS-001
                                                                                                fontes/fatos candidatos                               
                                                                                                sem apagar evidências.                                

  COT-OBJ-016   RevisaoTecnica                       Revisão Técnica   SYS       Control        Decisão humana auditável   CONTIFISC                  CDC
                                                                                                sobre classificação,                                  transversal
                                                                                                conflito ou resultado.                                

  COT-OBJ-017   ContaAcesso                          Conta de Acesso   SEC       Security       Identidade de autenticação Segurança                  SEC futuro
                                                                                 Entity         separada da Pessoa Física                             
                                                                                                tributária.                                           

  COT-OBJ-018   CredencialAcesso                     Credencial de     SEC       Security       Material/autenticador      Segurança                  SEC futuro
                                                     Acesso                      Entity         associado à Conta de                                  
                                                                                                Acesso; nunca pertence à                              
                                                                                                PessoaFisica.                                         
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------

## 4. Relacionamentos e cardinalidades

  -------------------------------------------------------------------------------------------------------------------------------
  ID             Origem                               Destino                              Cardinalidade   Regra
  -------------- ------------------------------------ ------------------------------------ --------------- ----------------------
  COT-REL-001    UnidadeEconomica                     Vinculo                              1:N             UE possui vínculos;
                                                                                                           vínculo preserva papel
                                                                                                           e vigência.

  COT-REL-002    Vinculo                              PessoaFisica                         N:1             Um vínculo pode
                                                                                                           apontar para PF; PF
                                                                                                           pode participar de
                                                                                                           várias UEs/empresas.

  COT-REL-003    Vinculo                              PessoaJuridica                       N:1             Um vínculo pode
                                                                                                           apontar para PJ; PJ
                                                                                                           pode participar de
                                                                                                           várias relações.

  COT-REL-004    PessoaFisica                         PessoaJuridica                       N:N via Vinculo Sociedade/pró-labore
                                                                                                           não são FK direta;
                                                                                                           usam objeto Vinculo.

  COT-REL-005    PessoaFisica                         Receita                              1:N             PF pode ser titular de
                                                                                                           várias receitas.

  COT-REL-006    PessoaJuridica                       Receita                              1:N             PJ pode ser titular de
                                                                                                           várias receitas.

  COT-REL-007    Receita                              DocumentoFiscal                      N:N             Uma receita pode
                                                                                                           resultar de um ou mais
                                                                                                           documentos e um
                                                                                                           documento pode conter
                                                                                                           múltiplas
                                                                                                           parcelas/receitas;
                                                                                                           associação deve ser
                                                                                                           explícita.

  COT-REL-008    DocumentoFiscal                      ArquivoOrigem                        N:1             Documento normalizado
                                                                                                           pode apontar para
                                                                                                           arquivo bruto
                                                                                                           preservado.

  COT-REL-009    Receita                              ClassificacaoEquiparacaoHospitalar   1:N             Uma receita pode ter
                                                                                                           múltiplas versões de
                                                                                                           classificação; apenas
                                                                                                           uma versão pode ser
                                                                                                           vigente/aprovada por
                                                                                                           contexto.

  COT-REL-010    PessoaFisica                         ContribuicaoPrevidenciaria           1:N             Contribuições
                                                                                                           pertencem à PF por
                                                                                                           competência.

  COT-REL-011    VinculoPrevidenciario                ContribuicaoPrevidenciaria           1:N             Fonte/vínculo agrupa
                                                                                                           contribuições ao longo
                                                                                                           do tempo.

  COT-REL-012    PessoaFisica                         EventoIRPF                           1:N             Eventos IRPF pertencem
                                                                                                           à PF.

  COT-REL-013    FontePagadora                        Receita                              1:N             Fonte pagadora pode
                                                                                                           originar múltiplas
                                                                                                           receitas.

  COT-REL-014    FontePagadora                        EventoIRPF                           1:N             Fonte pagadora pode
                                                                                                           originar múltiplos
                                                                                                           eventos de rendimento.

  COT-REL-015    UnidadeEconomica                     CenarioTributario                    1:N             Cenários podem avaliar
                                                                                                           o ecossistema da UE
                                                                                                           sem alterar fatos.

  COT-REL-016    CenarioTributario                    ResultadoCalculo                     1:N             Cenário possui
                                                                                                           resultados
                                                                                                           reproduzíveis.

  COT-REL-017    ConflitoDado                         RevisaoTecnica                       1:N             Conflito pode receber
                                                                                                           uma ou mais
                                                                                                           revisões/decisões
                                                                                                           auditáveis.

  COT-REL-018    ClassificacaoEquiparacaoHospitalar   RevisaoTecnica                       1:N             Classificação pode
                                                                                                           exigir revisão humana.

  COT-REL-019    ContaAcesso                          PessoaFisica                         0..N:0..1       Conta pode
                                                                                                           opcionalmente
                                                                                                           referenciar PF; PF
                                                                                                           pode existir sem
                                                                                                           conta. Não usar PF
                                                                                                           como identidade de
                                                                                                           login.

  COT-REL-020    ContaAcesso                          CredencialAcesso                     1:N             Conta pode ter senha,
                                                                                                           passkey, MFA ou outros
                                                                                                           autenticadores sem
                                                                                                           contaminar o domínio
                                                                                                           tributário.
  -------------------------------------------------------------------------------------------------------------------------------

## 5. Diagrama conceitual

``` text
                           UnidadeEconomica
                                  |
                               Vinculo
                    +-------------+-------------+
                    |                           |
              PessoaFisica                PessoaJuridica
              /    |    \                    /      \
             /     |     \                  /        \
     EventoIRPF  Contribuicao           Receita ---- DocumentoFiscal
                  |                         |              |
          VinculoPrevidenciario            |         ArquivoOrigem
                                            |
                           ClassificacaoEquiparacaoHospitalar
                                            |
                                      RevisaoTecnica

UnidadeEconomica ---- CenarioTributario ---- ResultadoCalculo

PessoaFisica  - - - vínculo opcional - - -> ContaAcesso -> CredencialAcesso
                 (domínio SEC separado)
```

## 6. Ownership semântico e fonte única

  ---------------------------------------------------------------------------------------------------------
  Conceito          Owner                                Domínio           Regra
  ----------------- ------------------------------------ ----------------- --------------------------------
  Identidade PF     PessoaFisica                         DOM-PER           Outros módulos referenciam; não
                                                                           duplicam nome/CPF.

  Identidade PJ     PessoaJuridica                       DOM-EMP           Regime/CNAE exigem histórico
                                                                           temporal.

  Relacionamentos   Vinculo                              DOM-REL           Participação, pró-labore, UE
                                                                           membership e papéis são
                                                                           relações.

  Receita           Receita                              DOM-REC           Fiscal/EqHop/IRPF/Planejamento
                                                                           consomem; não copiam o fato.

  Documento         DocumentoFiscal                      DOM-FIS           Parsers escrevem via contrato;
                                                                           Skills leem.

  EqHop             ClassificacaoEquiparacaoHospitalar   DOM-EH            Nunca altera Receita original.

  Previdenciário    ContribuicaoPrevidenciaria           DOM-PRE           CNIS/folha são fontes, não
                                                                           owners.

  IRPF              EventoIRPF                           DOM-IRP           Pode existir sem PJ.

  Cenários          CenarioTributario                    DOM-PLN           Isolados dos fatos oficiais.

  Autenticação      ContaAcesso/CredencialAcesso         SEC               Separada de PessoaFisica e dos
                                                                           objetos tributários.
  ---------------------------------------------------------------------------------------------------------

## 7. Ciclo de vida

  ---------------------------------------------------------------------------------------
  Objeto                  Estados conceituais                     Regra de preservação
  ----------------------- --------------------------------------- -----------------------
  PessoaFisica /          ATIVO -\> INATIVO/ARQUIVADO             Não apagar quando
  PessoaJuridica                                                  houver fatos ou
                                                                  auditoria vinculados.

  Vinculo                 PLANEJADO/ATIVO -\> ENCERRADO           Vigência explícita;
                                                                  encerramento não remove
                                                                  histórico.

  Receita / Contribuição  CANDIDATO -\> VALIDADO ou REJEITADO -\> Fato original
  / EventoIRPF            SUPERSEDED quando corrigido             preservado; correção é
                                                                  nova versão/ajuste.

  DocumentoFiscal         IMPORTADO -\> VALIDADO -\> CANCELADO    Cancelamento não
                          quando aplicável                        elimina documento.

  Classificacao EqHop     PENDENTE -\>                            Resultado versionado;
                          ELEGIVEL/NAO_ELEGIVEL/REVISAO_TECNICA   regra e evidência
                          -\> SUPERSEDED                          preservadas.

  CenarioTributario       RASCUNHO -\> CALCULADO -\> ARQUIVADO    Nunca promove
                                                                  automaticamente cenário
                                                                  a fato oficial.

  ConflitoDado            ABERTO -\> EM_REVISAO -\> RESOLVIDO     Preserva todas as
                                                                  fontes envolvidas.

  ContaAcesso             CONVIDADA/ATIVA -\> BLOQUEADA/INATIVA   Ciclo de segurança
                                                                  independente do
                                                                  cadastro tributário.
  ---------------------------------------------------------------------------------------

## 8. Unidade Econômica e participação múltipla

-   Uma PessoaFisica pode participar de zero, uma ou várias
    UnidadesEconomicas.
-   Uma PessoaJuridica pode participar de uma ou várias
    UnidadesEconomicas quando houver justificativa de negócio e
    autorização.
-   A associação ocorre via Vinculo; não adicionar
    `unidade_economica_id` obrigatório diretamente em PessoaFisica ou
    PessoaJuridica.
-   Participação societária, pró-labore, dependência IRPF e fonte de
    renda são papéis/vínculos com vigência.
-   O GTI futuro poderá materializar essas relações como grafo lógico
    sem exigir banco de grafos.

## 9. Receita e Documento Fiscal

-   Receita é o fato econômico; DocumentoFiscal é evidência/documento.
    Não são o mesmo objeto.
-   Uma NFS-e pode conter itens ou parcelas que gerem mais de uma
    classificação econômica/tributária; por isso a associação
    Receita↔DocumentoFiscal deve suportar N:N.
-   Classificação EqHop referencia a receita/parcela analisada e
    preserva a versão da regra.
-   Cancelamento/substituição de documento não deve apagar o histórico
    da receita ou das classificações; deve produzir reconciliação/ajuste
    conforme regra futura.

## 10. IRPF, Carnê-Leão e Previdenciário

-   PessoaFisica é a raiz tributária desses domínios, não a Empresa.
-   EventoIRPF pode receber dados de informe, Carnê-Leão, pró-labore,
    distribuição, aluguel, investimentos ou outras fontes futuras.
-   ContribuicaoPrevidenciaria é registrada por competência e pode
    coexistir em múltiplos vínculos.
-   Dados de PJ compartilhados com PF devem ser referenciados/derivados
    por contratos, não duplicados sem lineage.

## 11. Equiparação Hospitalar

-   ClassificacaoEquiparacaoHospitalar é resultado derivado, não
    atributo fixo da empresa ou do código de serviço.
-   Elegibilidade deve ser calculada/classificada sobre fatos de receita
    e evidências, com regra versionada.
-   Uma mesma receita pode possuir histórico de classificações; o
    sistema deve saber qual resultado está vigente/aprovado.
-   Revisão técnica é objeto auditável e pode confirmar, rejeitar ou
    substituir resultado anterior sem apagar a trilha.

## 12. Autenticação e segurança

-   PessoaFisica não é usuário de login.
-   ContaAcesso representa identidade de autenticação; pode
    opcionalmente estar associada a uma PessoaFisica.
-   CredencialAcesso contém referência a autenticadores (hash de senha,
    passkey, MFA etc.) e deve ser tratada no SEC-001.
-   Uma PessoaFisica pode existir sem ContaAcesso. Uma conta
    administrativa/técnica poderá existir sem representar contribuinte.
-   Campos de autenticação não entram no DOM-PER nem podem ser
    inventados dentro de PessoaFisica.

## 13. Regras para implementação física

-   COT define objetos conceituais; não autoriza automaticamente uma
    tabela por objeto.
-   Prisma/schema físico só pode ser criado depois de mapear cada
    tabela/modelo ao COT, MCD e CDC.
-   Foreign keys físicas devem refletir relacionamentos aprovados; não
    criar atalhos que eliminem o objeto Vinculo.
-   Fatos devem manter proveniência, competência e histórico conforme
    CDC.
-   Resultados derivados devem registrar regra/engine/input snapshot
    conforme CDC.
-   Objetos SEC devem ficar logicamente separados dos objetos
    tributários, mesmo que compartilhem o mesmo PostgreSQL.
-   PostgreSQL é tecnologia de persistência; Neon/Supabase/RDS não
    alteram o COT.

## 14. Matriz de autorização para o Claude Code

``` yaml
cot_policy:
  source_of_truth: docs/02-Data/COT-001.md
  physical_schema_allowed_after_cot: true
  one_object_equals_one_table: false
  direct_person_company_fk_for_roles: false
  relationship_object_required: true
  person_is_login_account: false
  security_domain_separate: true
  derived_result_overwrites_fact: false
  scenario_overwrites_fact: false
  vendor_specific_domain_model: false
  new_object_without_cot: false
```

Antes de criar um model Prisma, Claude deve registrar no comentário/ADR
de implementação:
`COT object -> MCD fields -> CDC contract -> physical model`. Se
qualquer elo estiver ausente, deve gerar change request em vez de
inventar estrutura.

## 15. Pendências que bloqueiam schema completo

-   Formalizar no MCD os identificadores de origem/destino de Vinculo e
    demais campos estruturais que o COT tornou necessários.
-   Formalizar metadados transversais do envelope CDC ainda não
    presentes no MCD.
-   Definir enums complementares no DST para ciclos de vida e papéis
    específicos.
-   Definir SEC-001 antes de implementar credenciais reais.
-   Definir RGT-001 antes de implementar lógica tributária de EqHop,
    IRPF, INSS ou planejamento.

## 16. O que o Claude já pode implementar após este COT

-   Estrutura de packages/modules baseada nos objetos e contratos
    aprovados.
-   Interfaces/types canônicos correspondentes aos objetos, sem criar
    campos novos.
-   Schema físico inicial SOMENTE para objetos cujos campos e relações
    estejam integralmente definidos; demais modelos devem aguardar
    MCD-CHANGE-REQUEST.
-   Camada abstrata de repositórios e Unit of Work sem dependência de
    Neon.
-   Testes de contrato, validação de UUID/decimal/competência e
    políticas de idempotência.
-   Separação arquitetural entre domínio tributário e domínio de
    segurança.

## 17. Critérios de aceite

-   [ ] UE, PF e PJ estão corretamente separados.
-   [ ] Relacionamentos são first-class objects com vigência.
-   [ ] Fatos, documentos, resultados derivados, cenários e controles
    estão diferenciados.
-   [ ] Receita e Documento Fiscal não foram fundidos.
-   [ ] EqHop foi modelada como resultado versionado, não atributo
    estático.
-   [ ] IRPF/INSS funcionam sem PJ.
-   [ ] Autenticação está separada da Pessoa Física.
-   [ ] Cardinalidades suportam múltiplos CPFs, CNPJs e vínculos.
-   [ ] Modelo permanece independente de ERP e fornecedor PostgreSQL.
-   [ ] Claude possui regra explícita para mapear COT-\>MCD-\>CDC antes
    do schema.

## 18. Próximo documento

**RGT-001 --- Registro de Regras Tributárias e Legais** deve ser
iniciado em paralelo ao **EVT-001 --- Catálogo de Eventos**. Antes
disso, recomenda-se emitir um pequeno `MCD-CHANGE-REQUEST-001` para
incorporar os campos estruturais revelados pelo COT (origem/destino de
vínculos, referências de titularidade e metadados transversais),
evitando que o Claude tenha de adivinhar o schema.

------------------------------------------------------------------------

**Decisão de governança:** COT define o que existe no domínio e como os
objetos se relacionam; MCD define seus dados; CDC define seus contratos;
DST define seu significado. O schema físico é uma implementação desses
artefatos, não sua fonte de verdade.
