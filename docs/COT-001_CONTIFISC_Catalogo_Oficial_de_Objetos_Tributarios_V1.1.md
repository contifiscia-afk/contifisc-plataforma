# COT-001 — Catálogo Oficial de Objetos Tributários da CONTIFISC

**Versão:** 1.1  
**Status:** APROVADO — alinhado com MCD-001 V1.2, CDC-001 V1.2 e DST-001 V1.2  
**Supersede:** COT-001 V1.0  
**Dependências:** CAF-001, MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2  
**Consumidores:** ADR físico, Prisma, APIs, RGT-001, EVT-001, INT-001, ATI-001, GTI-001, MIT-001 e Skills

> O COT define o que existe no domínio e quais estruturas relacionais são necessárias para preservar sua integridade. Ele não define tabelas finais, regras tributárias nem autorização automática para migrations.

## 1. Objetivo da V1.1

- Alinhar o catálogo à baseline MCD/CDC/DST V1.2.
- Preservar os 18 objetos oficiais existentes.
- Formalizar quatro estruturas canônicas de suporte relacional sem promovê-las a objetos tributários de negócio.
- Substituir a representação antiga de endpoints polimórficos de Vinculo por VinculoExtremidade com FKs reais.
- Formalizar as associações N:N Receita↔DocumentoFiscal e DocumentoFiscal↔ArquivoOrigem.
- Formalizar participantes estruturados de ConflitoDado.
- Atualizar contratos dos objetos cujo CDC específico foi criado na V1.2.

## 2. Taxonomia V1.1

| Classe | Definição | Exemplos |
|---|---|---|
| Domain Object | Objeto com identidade/semântica de negócio própria. | PessoaFisica, Receita, Vinculo, DocumentoFiscal |
| Relational Support | Estrutura persistível para integridade/cardinalidade; não é novo conceito tributário autônomo. | VinculoExtremidade |
| Association Support | Estrutura persistível de associação N:N. | ReceitaDocumentoFiscal, DocumentoFiscalArquivoOrigem |
| Audit Support | Estrutura de suporte à reconciliação/auditoria. | ConflitoDadoItem |
| Security Entity | Identidade/autenticação fora do domínio tributário. | ContaAcesso, CredencialAcesso |

**Regra:** `COT-SUP-*` pode resultar em tabela/model físico, mas não recebe automaticamente status de `COT-OBJ-*`. Criar uma estrutura de suporte não cria novo agregado ou sujeito tributário.

## 3. Catálogo oficial de objetos V1.1 — 18 objetos

| ID | Objeto técnico | Nome | Domínio | Tipo | Responsabilidade | Owner | Contrato |
|---|---|---|---|---|---|---|---|
| COT-OBJ-001 | UnidadeEconomica | Unidade Econômica | CORE | Aggregate Context | Contexto agregador econômico/tributário; não é sujeito fiscal. | CONTIFISC | CDC-UE-001 |
| COT-OBJ-002 | PessoaFisica | Pessoa Física | PER | Entity | Pessoa natural em papéis tributários, societários, previdenciários ou profissionais. | Identidade tributária PF | CDC-PER-001 |
| COT-OBJ-003 | PessoaJuridica | Pessoa Jurídica | EMP | Entity | Empresa/CNPJ e atributos cadastrais/tributários temporalmente válidos. | Identidade tributária PJ | CDC-EMP-001 |
| COT-OBJ-004 | Vinculo | Vínculo | REL | Relationship Entity | Relação de primeira classe com tipo, papel, vigência e exatamente duas extremidades. | Relacionamentos | CDC-REL-001 |
| COT-OBJ-005 | Receita | Receita | REC | Fact | Fato econômico de receita pertencente exatamente a PF ou PJ. | Titular da receita | CDC-REC-001 |
| COT-OBJ-006 | DocumentoFiscal | Documento Fiscal | FIS | Document | Documento fiscal normalizado; separado do fato Receita e do RAW. | Fiscal | CDC-FIS-001 |
| COT-OBJ-007 | ArquivoOrigem | Arquivo de Origem | SYS | Evidence | Preserva/referencia evidência RAW usada em ingestão, reprocessamento e auditoria. | Ingestão/Documentos | CDC-ARQ-001 |
| COT-OBJ-008 | ClassificacaoEquiparacaoHospitalar | Classificação EqHop | EH | Derived Result | Resultado versionado de classificação de Receita para EqHop. | Motor EqHop | CDC-EH-001 |
| COT-OBJ-009 | ContribuicaoPrevidenciaria | Contribuição Previdenciária | PRE | Fact | Fato contributivo por PF, vínculo/fonte e competência. | Previdenciário | CDC-PRE-001 |
| COT-OBJ-010 | VinculoPrevidenciario | Vínculo Previdenciário | PRE | Relationship Entity | Fonte/vínculo previdenciário associado a PF e vigência. | Previdenciário | CDC-PREV-001 |
| COT-OBJ-011 | EventoIRPF | Evento IRPF/Carnê-Leão | IRP | Fact | Fato relevante ao IRPF/Carnê-Leão, independente de existir PJ. | IRPF | CDC-IRP-001 |
| COT-OBJ-012 | FontePagadora | Fonte Pagadora | REC | Entity | Fonte que origina pagamento/rendimento para PF/PJ. | Receitas | CDC-FPG-001 |
| COT-OBJ-013 | CenarioTributario | Cenário Tributário | PLN | Scenario | Simulação isolada dos fatos oficiais. | Planejamento | CDC-PLN-001 |
| COT-OBJ-014 | ResultadoCalculo | Resultado de Cálculo | SYS | Derived Result | Resultado reproduzível com snapshot, engine e regras versionadas. | Motor responsável | CDC-CAL-001 |
| COT-OBJ-015 | ConflitoDado | Conflito de Dados | SYS | Control | Divergência auditável entre fontes/fatos candidatos sem apagar evidências. | Qualidade/Reconciliation | CDC-CFD-001 |
| COT-OBJ-016 | RevisaoTecnica | Revisão Técnica | SYS | Control | Decisão humana auditável sobre classificação, conflito ou resultado. | CONTIFISC | CDC-REV-001 |
| COT-OBJ-017 | ContaAcesso | Conta de Acesso | SEC | Security Entity | Identidade de autenticação separada da Pessoa Física tributária. | Segurança | SEC futuro |
| COT-OBJ-018 | CredencialAcesso | Credencial de Acesso | SEC | Security Entity | Material/autenticador associado à ContaAcesso. | Segurança | SEC futuro |

## 4. Estruturas canônicas de suporte relacional — 4 estruturas

| ID | Estrutura | Domínio | Classe | Responsabilidade | Contrato |
|---|---|---|---|---|---|
| COT-SUP-001 | VinculoExtremidade | REL | Relational Support | Materializa ORIGEM/DESTINO de Vinculo com FK real para UE, PF ou PJ. | CDC-REL-002 |
| COT-SUP-002 | ReceitaDocumentoFiscal | FIS | Association Support | Materializa N:N Receita↔DocumentoFiscal. | CDC-FIS-002 |
| COT-SUP-003 | DocumentoFiscalArquivoOrigem | FIS | Association Support | Materializa N:N DocumentoFiscal↔ArquivoOrigem e papel do arquivo. | CDC-FIS-003 |
| COT-SUP-004 | ConflitoDadoItem | SYS | Audit Support | Materializa participantes/fontes de ConflitoDado; referência genérica restrita à auditoria. | CDC-CFD-002 |

### 4.1 Regras das estruturas de suporte
- `VinculoExtremidade`: exatamente duas linhas por Vinculo, uma `ORIGEM` e uma `DESTINO`; em cada linha, exatamente uma FK entre UE/PF/PJ.
- `ReceitaDocumentoFiscal`: associação N:N; par receita_id + documento_fiscal_id deve ser único; sem semântica de rateio enquanto não houver novo MCD/CDC.
- `DocumentoFiscalArquivoOrigem`: associação N:N; `papel_arquivo` permanece Enum/Ref aberto no DST.
- `ConflitoDadoItem`: referência polimórfica é exceção deliberada de auditoria; não pode ser copiada para ownership financeiro.

## 5. Relacionamentos e cardinalidades V1.1

| ID | Origem | Destino | Cardinalidade | Regra |
|---|---|---|---|---|
| COT-REL-001 | Vinculo | VinculoExtremidade | 1:2 | Todo Vinculo possui exatamente duas extremidades. |
| COT-REL-002 | VinculoExtremidade | UnidadeEconomica/PessoaFisica/PessoaJuridica | N:1 XOR | Cada extremidade referencia exatamente um tipo de endpoint por FK real. |
| COT-REL-003 | PessoaFisica | PessoaJuridica | N:N via Vinculo | Sociedade/pró-labore e outros papéis usam Vinculo; sem FK ad-hoc. |
| COT-REL-004 | PessoaFisica | Receita | 1:N condicional | PF pode ser titular; Receita exige XOR PF/PJ. |
| COT-REL-005 | PessoaJuridica | Receita | 1:N condicional | PJ pode ser titular; Receita exige XOR PF/PJ. |
| COT-REL-006 | Receita | DocumentoFiscal | N:N via COT-SUP-002 | Associação explícita e única por par. |
| COT-REL-007 | DocumentoFiscal | ArquivoOrigem | N:N via COT-SUP-003 | Documento pode possuir múltiplas evidências RAW; papel do arquivo é semântica pendente DST. |
| COT-REL-008 | Receita | ClassificacaoEquiparacaoHospitalar | 1:N | Histórico versionado de classificações. |
| COT-REL-009 | PessoaFisica | ContribuicaoPrevidenciaria | 1:N | Contribuições pertencem à PF por competência. |
| COT-REL-010 | VinculoPrevidenciario | ContribuicaoPrevidenciaria | 1:N | Vínculo/fonte agrupa contribuições. |
| COT-REL-011 | PessoaFisica | EventoIRPF | 1:N | Eventos IRPF pertencem à PF. |
| COT-REL-012 | FontePagadora | Receita | 1:N | Fonte pode originar múltiplas receitas. |
| COT-REL-013 | FontePagadora | EventoIRPF | 1:N | Fonte pode originar múltiplos eventos. |
| COT-REL-014 | UnidadeEconomica | CenarioTributario | 1:N | Cenários avaliam UE sem alterar fatos. |
| COT-REL-015 | CenarioTributario | ResultadoCalculo | 1:N | Cenário possui resultados reproduzíveis. |
| COT-REL-016 | ConflitoDado | ConflitoDadoItem | 1:N | Conflito registra participantes/fontes estruturados. |
| COT-REL-017 | ConflitoDado | RevisaoTecnica | 1:N | Conflito pode receber revisões auditáveis. |
| COT-REL-018 | ClassificacaoEquiparacaoHospitalar | RevisaoTecnica | 1:N | Classificação pode exigir revisão humana. |
| COT-REL-019 | ContaAcesso | PessoaFisica | 0..N:0..1 | Associação opcional; PF não é identidade de login. |
| COT-REL-020 | ContaAcesso | CredencialAcesso | 1:N | Conta pode ter múltiplos autenticadores; SEC separado. |

**Governança de IDs:** os IDs `COT-REL-001..020` são redefinidos nesta V1.1 como catálogo vigente de relacionamentos. Para auditoria histórica, a semântica V1.0 permanece preservada no documento `legacy`; código novo deve referenciar a V1.1. Nenhum relacionamento físico deve ser inferido apenas pelo número do ID sem versão do COT.

## 6. Diagrama conceitual V1.1

```text
                           UnidadeEconomica
                                  ^
                                  |
                        VinculoExtremidade
                           [ORIGEM/DESTINO]
                                  |
                               Vinculo
                                  |
                        VinculoExtremidade
                           [ORIGEM/DESTINO]
                       /          |          \
              PessoaFisica  PessoaJuridica  UnidadeEconomica
                   |             |
                   |             +------ Receita ------+
                   |                    /       \       |
              EventoIRPF              /         \      |
                   |       ReceitaDocumentoFiscal       |
          ContribuicaoPrev          /             \    |
                   |       DocumentoFiscal         ClassificacaoEqHop
          VinculoPrevidenciario      |
                           DocumentoFiscalArquivoOrigem
                                     |
                                ArquivoOrigem

ConflitoDado ---- ConflitoDadoItem
      |
RevisaoTecnica

UnidadeEconomica ---- CenarioTributario ---- ResultadoCalculo

PessoaFisica - - associação opcional SEC - -> ContaAcesso -> CredencialAcesso
```

## 7. Ownership e fonte única

| Conceito | Owner | Regra |
|---|---|---|
| Identidade PF | PessoaFisica | Outros módulos referenciam; não duplicam identidade. |
| Identidade PJ | PessoaJuridica | Regime/cadastro respeitam temporalidade. |
| Relacionamentos | Vinculo | Papel/tipo/vigência pertencem ao vínculo; endpoints ficam em VinculoExtremidade. |
| Receita | Receita | Fiscal/EqHop/IRPF/Planejamento consomem; não copiam o fato. |
| Documento | DocumentoFiscal | RAW permanece em ArquivoOrigem. |
| EqHop | ClassificacaoEquiparacaoHospitalar | Nunca altera Receita original. |
| Conflito | ConflitoDado | Participantes em ConflitoDadoItem. |
| Cenários | CenarioTributario | Isolados dos fatos oficiais. |
| Autenticação | ContaAcesso/CredencialAcesso | Separada de PessoaFisica. |

## 8. Regras de integridade que o ADR físico deverá materializar

- Receita: CHECK/XOR entre pessoa_fisica_id e pessoa_juridica_id.
- VinculoExtremidade: CHECK/XOR do endpoint; unique(vinculo_id, lado_extremidade).
- Vinculo: exatamente duas extremidades e exatamente uma ORIGEM/DESTINO; a estratégia física pode exigir constraint diferida/trigger/transação/aplicação, a ser decidida no ADR.
- ReceitaDocumentoFiscal: unique(receita_id, documento_fiscal_id).
- DocumentoFiscalArquivoOrigem: política de unicidade deve considerar `papel_arquivo` quando o catálogo semântico for fechado.
- EqHop: PK própria e histórico/versionamento preservado.
- Delete cascade não é padrão para fatos/evidências tributárias; política de deleção será definida no ADR com preservação de auditoria.
- ConflitoDadoItem pode usar referência genérica apenas no domínio de auditoria e deve ter validação explícita.

## 9. Ciclo de vida e estados

O COT V1.1 deixa de inventar estados conceituais próprios quando eles pertencem ao DST. `status_registro`, `status_processamento_dado`, `status_qualidade_dado`, `status_conflito`, `status_revisao` e status EqHop devem usar exclusivamente os códigos vigentes no DST-001 V1.2. Estruturas de suporte seguem o ciclo de vida do relacionamento/associação e preservam histórico conforme MCD/CDC.

## 10. Unidade Econômica e vínculos

- UE continua contexto agregador, não sujeito tributário.
- PF/PJ podem participar de múltiplas UEs.
- Participação ocorre via Vinculo + VinculoExtremidade; não adicionar unidade_economica_id obrigatório diretamente em PF/PJ.
- VinculoExtremidade é infraestrutura canônica da relação, não um novo vínculo de negócio.
- GTI poderá projetar grafo lógico a partir das relações canônicas sem exigir graph database.

## 11. Receita, Documento Fiscal e evidência RAW

- Receita é fato econômico; DocumentoFiscal é documento normalizado; ArquivoOrigem é evidência RAW.
- Titularidade de Receita é PF XOR PJ por FK real.
- Receita↔DocumentoFiscal usa COT-SUP-002.
- DocumentoFiscal↔ArquivoOrigem usa COT-SUP-003.
- Cancelamento/substituição documental não apaga fatos/classificações; gera reconciliação/ajuste conforme regras futuras.

## 12. EqHop, conflito e revisão

- EqHop permanece resultado derivado versionado por Receita.
- `eh_validada_tecnicamente` não substitui RevisaoTecnica.
- ConflitoDado registra a ocorrência; ConflitoDadoItem registra participantes/fontes.
- Identidade do revisor continua bloqueada até SEC-001/OBS-001.
- Critérios jurídicos/tributários de EqHop pertencem ao RGT, não ao COT.

## 13. Segurança

- PessoaFisica não é ContaAcesso.
- ContaAcesso/CredencialAcesso permanecem objetos catalogados, mas implementação continua bloqueada até SEC-001.
- Nenhum campo de autenticação pode ser adicionado a PessoaFisica por inferência.

## 14. Matriz de autorização para Claude Code

```yaml
cot_policy:
  version: 1.1
  source_of_truth: docs/COT-001_CONTIFISC_Catalogo_Oficial_de_Objetos_Tributarios_V1.1.md
  supersedes: COT-001-v1.0
  domain_objects: 18
  relational_support_structures: 4
  one_object_equals_one_table: false
  support_structure_is_domain_object: false
  relationship_object_required: true
  vinculo_endpoints:
    structure: VinculoExtremidade
    count: 2
    sides: [ORIGEM, DESTINO]
    endpoint_fk_xor: true
  receita_owner:
    pessoa_fisica_xor_pessoa_juridica: true
  explicit_many_to_many:
    - ReceitaDocumentoFiscal
    - DocumentoFiscalArquivoOrigem
  generic_polymorphic_reference:
    financial_ownership: prohibited
    audit_support: controlled_exception
  person_is_login_account: false
  security_domain_separate: true
  derived_result_overwrites_fact: false
  scenario_overwrites_fact: false
  vendor_specific_domain_model: false
  new_domain_object_without_cot: false
  create_prisma_schema_now: false
  create_migration_now: false
```

## 15. Gaps e bloqueios remanescentes

- `papel_arquivo`, `tipo_objeto`/`papel_no_conflito`, `tipo_vinculo`, `papel_vinculo` e demais Enum/Ref abertos continuam sob DST.
- `FontePagadora.identificador_fiscal` continua gap de modelagem/validação MCD/CDC; não é promovido artificialmente a gap semântico DST.
- Identidade/autorização do revisor depende de SEC-001/OBS-001.
- Rule IDs de ResultadoCalculo e EqHop permanecem opacos até RGT-001.
- Schema/migration continuam bloqueados até ADR físico aprovado.

## 16. Compatibilidade com a Fase 1

- Interfaces já implementadas de UnidadeEconomica, PessoaFisica e PessoaJuridica permanecem válidas.
- Nenhum rename ou alteração de código da Fase 1 é exigido por este COT.
- As quatro estruturas de suporte não devem ser implementadas antes da autorização da próxima fase/ADR.
- Este documento permite desenhar o ADR físico, mas não autoriza criar Prisma schema ou migration.

## 17. Critérios de aceite

- [x] 18 objetos oficiais preservados.
- [x] 4 estruturas relacionais de suporte formalizadas.
- [x] Vinculo sem endpoints polimórficos livres.
- [x] Receita com ownership PF/PJ XOR.
- [x] N:N Receita-Documento e Documento-Arquivo explícitos.
- [x] ConflitoDadoItem restrito à auditoria.
- [x] Contratos atualizados para CDC V1.2.
- [x] Estados delegados ao DST V1.2.
- [x] Fase 1 permanece compatível.
- [x] Schema/migration continuam bloqueados.

## 18. Próximo documento

Com COT-001 V1.1 alinhado à baseline MCD/CDC/DST V1.2, o próximo passo é o **ADR do schema físico PostgreSQL/Prisma**. O ADR deverá decidir nomes físicos, constraints, índices, delete policies, temporalidade, estratégia para a cardinalidade de VinculoExtremidade, validação da exceção polimórfica de auditoria e como expressar constraints PostgreSQL não suportadas nativamente pelo Prisma. Somente após aprovação do ADR poderá ser autorizada a primeira migration.

---
**Governança:** COT define objetos e estruturas relacionais autorizadas; MCD define campos; CDC define contratos; DST define significado. PostgreSQL/Prisma implementam essa arquitetura e não são sua fonte de verdade.