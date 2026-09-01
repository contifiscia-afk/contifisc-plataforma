# COT-001 — Catálogo Oficial de Objetos Tributários da CONTIFISC

**Versão:** 1.2  
**Status:** APROVADO — incorpora `SEC-CHANGE-REQUEST-001` V1.1 (APROVADO); alinhado com MCD-001 V1.3, CDC-001 V1.2 e DST-001 V1.2 (CDC/DST ainda pendentes de sincronização com esta versão — ver §18)  
**Supersede:** COT-001 V1.1  
**Dependências:** CAF-001, MCD-001 V1.3, CDC-001 V1.2, DST-001 V1.2, `SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`, `SEC-CHANGE-REQUEST-001_V1.1.md`  
**Consumidores:** ADR físico, Prisma, APIs, RGT-001, EVT-001, INT-001, ATI-001, GTI-001, MIT-001 e Skills

> O COT define o que existe no domínio e quais estruturas relacionais são necessárias para preservar sua integridade. Ele não define tabelas finais, regras tributárias nem autorização automática para migrations.

### Incorporação do `SEC-CHANGE-REQUEST-001` V1.1

Esta V1.2 incorpora exclusivamente as mudanças canônicas e estruturais aprovadas em
`SEC-CHANGE-REQUEST-001_V1.1.md` (aprovado): dois novos objetos canônicos (`Tenant`,
`EventoAuditoriaSeguranca`), duas novas estruturas de suporte de associação
(`ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`) e doze novas relações. **Nenhuma alteração
física, de RLS, de autenticação ou de vocabulário DST foi introduzida por esta versão** — apenas
o que existe e como se relaciona, conforme o escopo do COT. Os 18 objetos e as 4 estruturas de
suporte já vigentes na V1.1 são preservados integralmente, sem renomeação ou remoção.

## 1. Objetivo da V1.2

- Incorporar `Tenant` como fronteira canônica de isolamento/segurança, distinta de
  `UnidadeEconomica` (contexto econômico/tributário) — `SEC-001` V1.0 §1-2.
- Incorporar `EventoAuditoriaSeguranca` como trilho de auditoria de segurança, distinto de
  `ConflitoDado`/`RevisaoTecnica` (auditoria de domínio tributário) e de log técnico —
  `SEC-001` V1.0 §16, `SEC-CHANGE-REQUEST-001` V1.1 item 2.
- Formalizar as relações `UnidadeEconomica → Tenant`, seis fatos `→ UnidadeEconomica`, três
  objetos `→ Tenant` (metadado transversal) e as duas associações de acesso
  `ContaAcesso ↔ Tenant`/`ContaAcesso ↔ UnidadeEconomica`.
- Preservar integralmente a taxonomia, os 18 objetos, as 4 estruturas de suporte e as 20
  relações já vigentes na V1.1.

## 2. Taxonomia V1.2

| Classe | Definição | Exemplos |
|---|---|---|
| Domain Object | Objeto com identidade/semântica de negócio própria. | PessoaFisica, Receita, Vinculo, DocumentoFiscal |
| Relational Support | Estrutura persistível para integridade/cardinalidade; não é novo conceito tributário autônomo. | VinculoExtremidade |
| Association Support | Estrutura persistível de associação N:N. | ReceitaDocumentoFiscal, DocumentoFiscalArquivoOrigem, ContaAcessoTenant, ContaAcessoUnidadeEconomica |
| Audit Support | Estrutura de suporte à reconciliação/auditoria tributária. | ConflitoDadoItem |
| Security Entity | Identidade/autenticação/isolamento fora do domínio tributário. | ContaAcesso, CredencialAcesso, Tenant |
| **Security Audit** *(nova nesta versão)* | Registro imutável de evento de segurança; não é objeto tributário nem log técnico genérico; distinto de `ConflitoDado`/`RevisaoTecnica` (auditoria de domínio) e de `EVT-001` (eventos de domínio genéricos, documento ainda não escrito). | EventoAuditoriaSeguranca |

**Regra (inalterada):** `COT-SUP-*` pode resultar em tabela/model físico, mas não recebe automaticamente status de `COT-OBJ-*`. Criar uma estrutura de suporte não cria novo agregado ou sujeito tributário.

## 3. Catálogo oficial de objetos V1.2 — 20 objetos

| ID | Objeto técnico | Nome | Domínio | Tipo | Responsabilidade | Owner | Contrato |
|---|---|---|---|---|---|---|---|
| COT-OBJ-001 | UnidadeEconomica | Unidade Econômica | CORE | Aggregate Context | Contexto agregador econômico/tributário; não é sujeito fiscal. Pertence a exatamente um `Tenant` (`COT-REL-121`). | CONTIFISC | CDC-UE-001 |
| COT-OBJ-002 | PessoaFisica | Pessoa Física | PER | Entity | Pessoa natural em papéis tributários, societários, previdenciários ou profissionais. | Identidade tributária PF | CDC-PER-001 |
| COT-OBJ-003 | PessoaJuridica | Pessoa Jurídica | EMP | Entity | Empresa/CNPJ e atributos cadastrais/tributários temporalmente válidos. | Identidade tributária PJ | CDC-EMP-001 |
| COT-OBJ-004 | Vinculo | Vínculo | REL | Relationship Entity | Relação de primeira classe com tipo, papel, vigência e exatamente duas extremidades. | Relacionamentos | CDC-REL-001 |
| COT-OBJ-005 | Receita | Receita | REC | Fact | Fato econômico de receita pertencente exatamente a PF ou PJ. Contexto de apuração adicional em `UnidadeEconomica` (`COT-REL-122`), distinto do titular tributário. | Titular da receita | CDC-REC-001 |
| COT-OBJ-006 | DocumentoFiscal | Documento Fiscal | FIS | Document | Documento fiscal normalizado; separado do fato Receita e do RAW. Contexto de apuração próprio em `UnidadeEconomica` (`COT-REL-126`). | Fiscal | CDC-FIS-001 |
| COT-OBJ-007 | ArquivoOrigem | Arquivo de Origem | SYS | Evidence | Preserva/referencia evidência RAW usada em ingestão, reprocessamento e auditoria. Pertence a exatamente um `Tenant` (`COT-REL-128`); pode cobrir múltiplas UEs do mesmo tenant. | Ingestão/Documentos | CDC-ARQ-001 |
| COT-OBJ-008 | ClassificacaoEquiparacaoHospitalar | Classificação EqHop | EH | Derived Result | Resultado versionado de classificação de Receita para EqHop. | Motor EqHop | CDC-EH-001 |
| COT-OBJ-009 | ContribuicaoPrevidenciaria | Contribuição Previdenciária | PRE | Fact | Fato contributivo por PF, vínculo/fonte e competência. Contexto de apuração adicional em `UnidadeEconomica` (`COT-REL-123`). | Previdenciário | CDC-PRE-001 |
| COT-OBJ-010 | VinculoPrevidenciario | Vínculo Previdenciário | PRE | Relationship Entity | Fonte/vínculo previdenciário associado a PF e vigência. Contexto de apuração adicional em `UnidadeEconomica` (`COT-REL-124`). | Previdenciário | CDC-PREV-001 |
| COT-OBJ-011 | EventoIRPF | Evento IRPF/Carnê-Leão | IRP | Fact | Fato relevante ao IRPF/Carnê-Leão, independente de existir PJ. Contexto de apuração adicional em `UnidadeEconomica` (`COT-REL-125`). | IRPF | CDC-IRP-001 |
| COT-OBJ-012 | FontePagadora | Fonte Pagadora | REC | Entity | Fonte que origina pagamento/rendimento para PF/PJ; identidade global compartilhável entre tenants (`SEC-001` §3). | Receitas | CDC-FPG-001 |
| COT-OBJ-013 | CenarioTributario | Cenário Tributário | PLN | Scenario | Simulação isolada dos fatos oficiais. | Planejamento | CDC-PLN-001 |
| COT-OBJ-014 | ResultadoCalculo | Resultado de Cálculo | SYS | Derived Result | Resultado reproduzível com snapshot, engine e regras versionadas. Contexto de apuração próprio em `UnidadeEconomica` (`COT-REL-127`), consistente com `CenarioTributario` quando aplicável — sem exclusividade mútua. | Motor responsável | CDC-CAL-001 |
| COT-OBJ-015 | ConflitoDado | Conflito de Dados | SYS | Control | Divergência auditável entre fontes/fatos candidatos sem apagar evidências. Pertence a exatamente um `Tenant` (`COT-REL-129`); nunca agrega itens de tenants diferentes. | Qualidade/Reconciliation | CDC-CFD-001 |
| COT-OBJ-016 | RevisaoTecnica | Revisão Técnica | SYS | Control | Decisão humana auditável sobre classificação, conflito ou resultado. Pertence a exatamente um `Tenant` (`COT-REL-130`). | CONTIFISC | CDC-REV-001 |
| COT-OBJ-017 | ContaAcesso | Conta de Acesso | SEC | Security Entity | Identidade de autenticação separada da Pessoa Física tributária. Autorizada por `Tenant` (`COT-REL-131`) e, opcionalmente, por `UnidadeEconomica` (`COT-REL-132`). | Segurança | SEC futuro |
| COT-OBJ-018 | CredencialAcesso | Credencial de Acesso | SEC | Security Entity | Material/autenticador associado à ContaAcesso. | Segurança | SEC futuro |
| **COT-OBJ-019** *(novo)* | Tenant | Tenant | SEC | Security Entity | Fronteira técnica de isolamento, segurança e propriedade lógica dos dados. **Não representa** `PessoaFisica`, `PessoaJuridica`, `UnidadeEconomica`, um usuário individual, nem necessariamente um cliente comercial (`SEC-001` §1). Agrega 1..N `UnidadeEconomica`. | Segurança | SEC futuro — detalhamento completo de campos aguarda Change Request de autenticação/RBAC específico |
| **COT-OBJ-020** *(novo)* | EventoAuditoriaSeguranca | Evento de Auditoria de Segurança | SEC | Security Audit | Registro imutável de evento de segurança (login, falha de autenticação, mudança de permissão, elevação de privilégio, acesso sensível, override, operação administrativa). Distinto de `ConflitoDado`/`RevisaoTecnica` (auditoria tributária), de log técnico e de um futuro evento de domínio `EVT-001` (`SEC-001` §16). | Segurança | SEC futuro — detalhamento completo de campos aguarda Change Request de autenticação/RBAC específico |

## 4. Estruturas canônicas de suporte relacional — 6 estruturas

| ID | Estrutura | Domínio | Classe | Responsabilidade | Contrato |
|---|---|---|---|---|---|
| COT-SUP-001 | VinculoExtremidade | REL | Relational Support | Materializa ORIGEM/DESTINO de Vinculo com FK real para UE, PF ou PJ. | CDC-REL-002 |
| COT-SUP-002 | ReceitaDocumentoFiscal | FIS | Association Support | Materializa N:N Receita↔DocumentoFiscal. | CDC-FIS-002 |
| COT-SUP-003 | DocumentoFiscalArquivoOrigem | FIS | Association Support | Materializa N:N DocumentoFiscal↔ArquivoOrigem e papel do arquivo. | CDC-FIS-003 |
| COT-SUP-004 | ConflitoDadoItem | SYS | Audit Support | Materializa participantes/fontes de ConflitoDado; referência genérica restrita à auditoria. | CDC-CFD-002 |
| **COT-SUP-005** *(novo)* | ContaAcessoTenant | SEC | Association Support | Materializa N:N `ContaAcesso ↔ Tenant`, com campo `papel` (Enum/Ref aberto, novo gap DST) e vigência da concessão. | CDC-SEC-001 *(a criar)* |
| **COT-SUP-006** *(novo)* | ContaAcessoUnidadeEconomica | SEC | Association Support | Materializa N:N opcional `ContaAcesso ↔ UnidadeEconomica`, com campo `papel`. Restringe o escopo padrão concedido pelo `Tenant` a UEs específicas — nunca amplia, substitui, ou cria acesso implícito a outras UEs do mesmo tenant. | CDC-SEC-002 *(a criar)* |

### 4.1 Regras das estruturas de suporte
- `VinculoExtremidade`: exatamente duas linhas por Vinculo, uma `ORIGEM` e uma `DESTINO`; em cada linha, exatamente uma FK entre UE/PF/PJ.
- `ReceitaDocumentoFiscal`: associação N:N; par receita_id + documento_fiscal_id deve ser único; sem semântica de rateio enquanto não houver novo MCD/CDC.
- `DocumentoFiscalArquivoOrigem`: associação N:N; `papel_arquivo` permanece Enum/Ref aberto no DST.
- `ConflitoDadoItem`: referência polimórfica é exceção deliberada de auditoria; não pode ser copiada para ownership financeiro.
- **`ContaAcessoTenant`** *(nova)*: concessão explícita de acesso a um `Tenant` inteiro; `papel` permanece Enum/Ref aberto no DST (novo gap, não fechado por esta versão); nenhuma concessão é implícita — negar por padrão.
- **`ContaAcessoUnidadeEconomica`** *(nova)*: quando existir ao menos uma linha para um par (`ContaAcesso`, `Tenant`), a autorização deve considerar **exclusivamente** as UEs explicitamente listadas para aquele par — a existência de uma restrição desliga o padrão "todas as UEs do tenant" (`SEC-CHANGE-REQUEST-001` V1.1 item 6). Nunca amplia, nunca substitui a concessão de `Tenant` subjacente.

## 5. Relacionamentos e cardinalidades V1.2

| ID | Origem | Destino | Cardinalidade | Regra |
|---|---|---|---|---|
| COT-REL-101 | Vinculo | VinculoExtremidade | 1:N | Ver restrição normativa COT-REL-NORM-001 abaixo: exatamente duas extremidades por Vinculo. |
| COT-REL-102 | VinculoExtremidade | UnidadeEconomica/PessoaFisica/PessoaJuridica | N:1 XOR | Cada extremidade referencia exatamente um tipo de endpoint por FK real. |
| COT-REL-103 | PessoaFisica | PessoaJuridica | N:N via Vinculo | Sociedade/pró-labore e outros papéis usam Vinculo; sem FK ad-hoc. |
| COT-REL-104 | PessoaFisica | Receita | 1:N condicional | PF pode ser titular; Receita exige XOR PF/PJ. |
| COT-REL-105 | PessoaJuridica | Receita | 1:N condicional | PJ pode ser titular; Receita exige XOR PF/PJ. |
| COT-REL-106 | Receita | DocumentoFiscal | N:N via COT-SUP-002 | Associação explícita e única por par. |
| COT-REL-107 | DocumentoFiscal | ArquivoOrigem | N:N via COT-SUP-003 | Documento pode possuir múltiplas evidências RAW; papel do arquivo é semântica pendente DST. |
| COT-REL-108 | Receita | ClassificacaoEquiparacaoHospitalar | 1:N | Histórico versionado de classificações. |
| COT-REL-109 | PessoaFisica | ContribuicaoPrevidenciaria | 1:N | Contribuições pertencem à PF por competência. |
| COT-REL-110 | VinculoPrevidenciario | ContribuicaoPrevidenciaria | 1:N | Vínculo/fonte agrupa contribuições. |
| COT-REL-111 | PessoaFisica | EventoIRPF | 1:N | Eventos IRPF pertencem à PF. |
| COT-REL-112 | FontePagadora | Receita | 1:N | Fonte pode originar múltiplas receitas. |
| COT-REL-113 | FontePagadora | EventoIRPF | 1:N | Fonte pode originar múltiplos eventos. |
| COT-REL-114 | UnidadeEconomica | CenarioTributario | 1:N | Cenários avaliam UE sem alterar fatos. |
| COT-REL-115 | CenarioTributario | ResultadoCalculo | 1:N | Cenário possui resultados reproduzíveis. |
| COT-REL-116 | ConflitoDado | ConflitoDadoItem | 1:N | Conflito registra participantes/fontes estruturados. |
| COT-REL-117 | ConflitoDado | RevisaoTecnica | 1:N | Conflito pode receber revisões auditáveis. |
| COT-REL-118 | ClassificacaoEquiparacaoHospitalar | RevisaoTecnica | 1:N | Classificação pode exigir revisão humana. |
| COT-REL-119 | ContaAcesso | PessoaFisica | 0..N:0..1 | Associação opcional; PF não é identidade de login. |
| COT-REL-120 | ContaAcesso | CredencialAcesso | 1:N | Conta pode ter múltiplos autenticadores; SEC separado. |
| **COT-REL-121** *(novo)* | UnidadeEconomica | Tenant | N:1 | Âncora raiz do isolamento; toda UE pertence a exatamente um Tenant (`SEC-001` §1, §11). |
| **COT-REL-122** *(novo)* | Receita | UnidadeEconomica | N:1 | Contexto de apuração, distinto do titular tributário PF/PJ (`COT-REL-104`/`105`) — `SEC-001` §4. |
| **COT-REL-123** *(novo)* | ContribuicaoPrevidenciaria | UnidadeEconomica | N:1 | Idem. |
| **COT-REL-124** *(novo)* | VinculoPrevidenciario | UnidadeEconomica | N:1 | Idem. |
| **COT-REL-125** *(novo)* | EventoIRPF | UnidadeEconomica | N:1 | Idem. |
| **COT-REL-126** *(novo)* | DocumentoFiscal | UnidadeEconomica | N:1 | Idem, própria — não apenas derivada de `Receita` associada. |
| **COT-REL-127** *(novo)* | ResultadoCalculo | UnidadeEconomica | N:1 | Sempre presente, inclusive quando `COT-REL-115` (Cenário → Resultado) também se aplica — consistentes entre si, nunca mutuamente exclusivas (`SEC-001` §4, `SEC-CHANGE-REQUEST-001` item 9). |
| **COT-REL-128** *(novo)* | ArquivoOrigem | Tenant | N:1 | Camada RAW não tem UE unívoca (um arquivo pode cobrir múltiplas UEs do mesmo tenant) — tenant é a única fronteira estável (`SEC-001` §5). |
| **COT-REL-129** *(novo)* | ConflitoDado | Tenant | N:1 | Conflito pode envolver mais de uma UE do mesmo tenant — nunca de tenants diferentes (`SEC-001` §6). |
| **COT-REL-130** *(novo)* | RevisaoTecnica | Tenant | N:1 | Mesma razão de `ConflitoDado` — nunca inferido do objeto revisado (`SEC-001` §8). |
| **COT-REL-131** *(novo)* | ContaAcesso | Tenant | N:N via COT-SUP-005 | Concessão explícita de acesso; carrega `papel`. |
| **COT-REL-132** *(novo)* | ContaAcesso | UnidadeEconomica | N:N opcional via COT-SUP-006 | Restrição fina; carrega `papel`; nunca derivável de `COT-REL-131`. |

**Restrição normativa COT-REL-NORM-001 (Vinculo ↔ VinculoExtremidade):** independentemente da
cardinalidade estrutural `1:N` de `COT-REL-101`, todo `Vinculo` deve possuir **exatamente duas**
`VinculoExtremidade`: uma com `lado_extremidade = ORIGEM` e outra com `lado_extremidade =
DESTINO`. Esta é uma restrição de integridade (cardinalidade exata), não uma cardinalidade
estrutural `1:2` — consistente com `CDC-REL-CARD-001` (CDC-001 V1.2 §7). **Inalterada por esta
versão.**

**Nota sobre `ConflitoDadoItem` (`COT-SUP-004`):** nenhuma relação nova foi criada para tenant —
o tenant de um `ConflitoDadoItem` é sempre lido através de `COT-REL-116` (`ConflitoDado →
ConflitoDadoItem`, já vigente), nunca materializado como campo próprio (`SEC-001` §7,
`SEC-CHANGE-REQUEST-001` item 8).

**Governança de IDs:** os relacionamentos vigentes usam a faixa `COT-REL-101..132`. A faixa
`101..120` já estava vigente na V1.1; a faixa `121..132` é introduzida por esta V1.2,
especificamente para as relações aprovadas em `SEC-CHANGE-REQUEST-001` V1.1. Os IDs
`COT-REL-001..020` (V1.0) permanecem preservados exclusivamente como histórico e não devem ser
reutilizados.

## 6. Diagrama conceitual V1.2

```text
                           UnidadeEconomica ---- Tenant
                                  ^                 ^
                                  |                 |
                        VinculoExtremidade    ArquivoOrigem
                           [ORIGEM/DESTINO]   ConflitoDado
                                  |           RevisaoTecnica
                               Vinculo         (tenant_id transversal)
                                  |
                        VinculoExtremidade
                           [ORIGEM/DESTINO]
                       /          |          \
              PessoaFisica  PessoaJuridica  UnidadeEconomica
                   |             |
                   |             +------ Receita ------+---- UnidadeEconomica
                   |                    /       \       |    (contexto de apuração)
              EventoIRPF----UE        /         \      |
                   |       ReceitaDocumentoFiscal       |
          ContribuicaoPrev----UE     /             \    |
                   |       DocumentoFiscal----UE    ClassificacaoEqHop
          VinculoPrevidenciario----UE  |
                           DocumentoFiscalArquivoOrigem
                                     |
                                ArquivoOrigem---- Tenant

ConflitoDado ---- ConflitoDadoItem                ConflitoDado ---- Tenant
      |
RevisaoTecnica ---- Tenant

UnidadeEconomica ---- CenarioTributario ---- ResultadoCalculo ---- UnidadeEconomica
                                                                   (sempre presente)

PessoaFisica - - associação opcional SEC - -> ContaAcesso -> CredencialAcesso
                                                  |     \
                                                Tenant   UnidadeEconomica (opcional, restringe)
```

## 7. Ownership e fonte única

| Conceito | Owner | Regra |
|---|---|---|
| Identidade PF | PessoaFisica | Outros módulos referenciam; não duplicam identidade. Identidade global compartilhável entre tenants — não adquire ownership de tenant automaticamente (`SEC-001` §3). |
| Identidade PJ | PessoaJuridica | Regime/cadastro respeitam temporalidade. Mesma regra de compartilhamento global de PF. |
| Relacionamentos | Vinculo | Papel/tipo/vigência pertencem ao vínculo; endpoints ficam em VinculoExtremidade. |
| Receita | Receita | Fiscal/EqHop/IRPF/Planejamento consomem; não copiam o fato. Titular tributário (PF/PJ) e contexto de apuração (UnidadeEconomica) são eixos distintos. |
| Documento | DocumentoFiscal | RAW permanece em ArquivoOrigem. |
| EqHop | ClassificacaoEquiparacaoHospitalar | Nunca altera Receita original. |
| Conflito | ConflitoDado | Participantes em ConflitoDadoItem. Nunca agrega itens de tenants diferentes. |
| Cenários | CenarioTributario | Isolados dos fatos oficiais. |
| Autenticação | ContaAcesso/CredencialAcesso | Separada de PessoaFisica. |
| **Isolamento/segurança** *(novo)* | **Tenant** | Fronteira técnica de isolamento e propriedade lógica; nunca confundido com titular tributário (PF/PJ) nem com contexto econômico (UnidadeEconomica). |
| **Auditoria de segurança** *(novo)* | **EventoAuditoriaSeguranca** | Registro imutável, independente de `ConflitoDado`/`RevisaoTecnica` (auditoria de domínio). |

## 8. Regras de integridade que o ADR físico deverá materializar

- Receita: CHECK/XOR entre pessoa_fisica_id e pessoa_juridica_id.
- VinculoExtremidade: CHECK/XOR do endpoint; unique(vinculo_id, lado_extremidade).
- Vinculo: exatamente duas extremidades e exatamente uma ORIGEM/DESTINO; a estratégia física pode exigir constraint diferida/trigger/transação/aplicação, a ser decidida no ADR.
- ReceitaDocumentoFiscal: unique(receita_id, documento_fiscal_id).
- DocumentoFiscalArquivoOrigem: política de unicidade deve considerar `papel_arquivo` quando o catálogo semântico for fechado.
- EqHop: PK própria e histórico/versionamento preservado.
- Delete cascade não é padrão para fatos/evidências tributárias; política de deleção será definida no ADR com preservação de auditoria.
- ConflitoDadoItem pode usar referência genérica apenas no domínio de auditoria e deve ter validação explícita.
- **Tenant/UnidadeEconomica** *(novo)*: a estrutura necessária para uma futura FK composta `(unidade_economica_id, tenant_id) → unidade_economica(id, tenant_id)` deve estar presente (a relação `COT-REL-121` e as relações `COT-REL-122..127`), mas **a forma física definitiva (FK composta, trigger, ou outro mecanismo) permanece responsabilidade exclusiva do ADR** — não decidida nem antecipada por este COT (`SEC-CHANGE-REQUEST-001` item 10).
- **Autorização por UnidadeEconomica** *(novo)*: quando existir restrição via `COT-SUP-006`, a avaliação de acesso deve considerar exclusivamente as UEs explicitamente listadas — invariante a materializar no ADR/camada de autorização, nunca como concessão implícita.

## 9. Ciclo de vida e estados

O COT V1.2 continua sem inventar estados conceituais próprios quando eles pertencem ao DST. `status_registro`, `status_processamento_dado`, `status_qualidade_dado`, `status_conflito`, `status_revisao` e status EqHop devem usar exclusivamente os códigos vigentes no DST-001 V1.2. O novo campo `papel` (`COT-SUP-005`/`006`) segue a mesma regra — Enum/Ref aberto, novo gap DST, **não fechado por este documento**. Estruturas de suporte seguem o ciclo de vida do relacionamento/associação e preservam histórico conforme MCD/CDC.

## 10. Unidade Econômica e vínculos

- UE continua contexto agregador, não sujeito tributário. **Pertence a exatamente um `Tenant`** (`COT-REL-121`, novo nesta versão).
- PF/PJ podem participar de múltiplas UEs.
- Participação ocorre via Vinculo + VinculoExtremidade; não adicionar unidade_economica_id obrigatório diretamente em PF/PJ — **regra inalterada**, mesmo após a incorporação do SEC-CR-001 (PF/PJ permanecem identidades globais compartilháveis, sem FK direta de UE ou de Tenant).
- VinculoExtremidade é infraestrutura canônica da relação, não um novo vínculo de negócio.
- GTI poderá projetar grafo lógico a partir das relações canônicas sem exigir graph database.

## 11. Receita, Documento Fiscal e evidência RAW

- Receita é fato econômico; DocumentoFiscal é documento normalizado; ArquivoOrigem é evidência RAW.
- Titularidade de Receita é PF XOR PJ por FK real.
- Receita↔DocumentoFiscal usa COT-SUP-002.
- DocumentoFiscal↔ArquivoOrigem usa COT-SUP-003.
- Cancelamento/substituição documental não apaga fatos/classificações; gera reconciliação/ajuste conforme regras futuras.
- **Contexto de apuração** *(novo)*: `Receita` e `DocumentoFiscal` também se relacionam a `UnidadeEconomica` (`COT-REL-122`/`126`) — um eixo de segurança/contexto administrativo, distinto e adicional à titularidade tributária PF/PJ e à evidência RAW.

## 12. EqHop, conflito e revisão

- EqHop permanece resultado derivado versionado por Receita.
- `eh_validada_tecnicamente` não substitui RevisaoTecnica.
- ConflitoDado registra a ocorrência; ConflitoDadoItem registra participantes/fontes.
- Identidade do revisor continua bloqueada até SEC-001/OBS-001. **Nota: `SEC-001` já foi aprovado, mas a identidade/autorização específica do revisor depende adicionalmente de `OBS-001`, ainda não escrito — este gap permanece aberto.**
- Critérios jurídicos/tributários de EqHop pertencem ao RGT, não ao COT.
- **`ConflitoDado`/`RevisaoTecnica` pertencem a exatamente um `Tenant`** (`COT-REL-129`/`130`, novo) — a referência polimórfica de auditoria (`objeto_id`/`objeto_revisado_id`) permanece exclusivamente mecanismo de auditoria/revisão, nunca de ownership/isolamento (`SEC-001` §6, §8, §9).

## 13. Segurança

- PessoaFisica não é ContaAcesso.
- ContaAcesso/CredencialAcesso permanecem objetos catalogados, mas implementação física completa continua bloqueada até Change Request específico de autenticação.
- Nenhum campo de autenticação pode ser adicionado a PessoaFisica por inferência.
- **`Tenant` é a fronteira técnica de isolamento, segurança e propriedade lógica dos dados — não representa PessoaFisica, PessoaJuridica, UnidadeEconomica, um usuário individual, nem necessariamente um cliente comercial** (`SEC-001` §1, novo nesta versão).
- **Identidade tributária ≠ identidade de acesso ≠ tenant ≠ unidade econômica** (`SEC-001` §1) — princípio normativo que rege toda a incorporação desta V1.2.
- **`EventoAuditoriaSeguranca` é o único trilho canônico de auditoria de segurança** — nunca confundido com sessão (responsabilidade do futuro provedor de autenticação, `SEGURANCA_OPERACIONAL`) nem com logs técnicos genéricos.
- **`PapelAcesso`/`Permissao` como objetos canônicos separados permanecem `DIFERIDO`** — o campo `papel` (aberto) nas associações de acesso resolve os cenários hoje conhecidos (`SEC-CHANGE-REQUEST-001` V1.1 item 2, itens 4-5).

## 14. Matriz de autorização para Claude Code

```yaml
cot_policy:
  version: 1.2
  source_of_truth: docs/COT-001_CONTIFISC_Catalogo_Oficial_de_Objetos_Tributarios_V1.2.md
  supersedes: COT-001-v1.1
  domain_objects: 20
  relational_support_structures: 6
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
    - ContaAcessoTenant
    - ContaAcessoUnidadeEconomica
  generic_polymorphic_reference:
    financial_ownership: prohibited
    audit_support: controlled_exception
    tenant_isolation: prohibited
  person_is_login_account: false
  security_domain_separate: true
  tenant_is_unidade_economica: false
  tenant_is_pessoa_fisica_ou_juridica: false
  tenant_requires_cliente_organizacao_object: false
  papel_acesso_permissao_objects: deferred
  sessao_object: security_operational_not_canonical
  derived_result_overwrites_fact: false
  scenario_overwrites_fact: false
  vendor_specific_domain_model: false
  new_domain_object_without_cot: false
  create_prisma_schema_now: false
  create_migration_now: false
  implement_rls_now: false
  implement_composite_fk_now: false
```

## 15. Gaps e bloqueios remanescentes

- `papel_arquivo`, `tipo_objeto`/`papel_no_conflito`, `tipo_vinculo`, `papel_vinculo` e demais Enum/Ref abertos continuam sob DST.
- **`papel` (`ContaAcessoTenant`/`ContaAcessoUnidadeEconomica`) é um novo Enum/Ref aberto — gap DST a registrar formalmente na próxima atualização do DST-001 (não fechado por este COT).**
- `FontePagadora.identificador_fiscal` continua gap de modelagem/validação MCD/CDC; não é promovido artificialmente a gap semântico DST.
- Identidade/autorização do revisor depende de `OBS-001` (SEC-001 já aprovado, mas não substitui `OBS-001`).
- Rule IDs de ResultadoCalculo e EqHop permanecem opacos até RGT-001.
- **Detalhamento completo de campos de `Tenant`, `EventoAuditoriaSeguranca`, `ContaAcesso` e `CredencialAcesso` permanece bloqueado até Change Request específico de autenticação/RBAC — apenas o essencial para as relações aprovadas foi incorporado nesta versão.**
- **`PapelAcesso`/`Permissao` como objetos canônicos, e `Sessao` como objeto canônico, permanecem fora de escopo desta versão** (`DIFERIDO`/`SEGURANCA_OPERACIONAL`, `SEC-CHANGE-REQUEST-001` V1.1).
- Schema/migration continuam bloqueados até ADR físico aprovado.

## 16. Compatibilidade com a Fase 1

- Interfaces já implementadas de UnidadeEconomica, PessoaFisica e PessoaJuridica permanecem válidas.
- Nenhum rename ou alteração de código da Fase 1 é exigido por este COT.
- As estruturas de suporte (incluindo as duas novas, `COT-SUP-005`/`006`) não devem ser implementadas antes da autorização da próxima fase/ADR.
- Este documento permite desenhar o ADR físico, mas não autoriza criar Prisma schema ou migration.

## 17. Critérios de aceite

- [x] 18 objetos oficiais da V1.1 preservados, sem renomeação ou remoção.
- [x] `Tenant` incorporado como novo objeto canônico (`COT-OBJ-019`), distinto de PF/PJ/UE/usuário/cliente comercial.
- [x] `EventoAuditoriaSeguranca` incorporado como novo objeto canônico (`COT-OBJ-020`), distinto de auditoria tributária e log técnico.
- [x] `Sessao`, `PapelAcesso`, `Permissao` explicitamente não incorporados como objetos canônicos nesta versão.
- [x] 4 estruturas relacionais de suporte da V1.1 preservadas; 2 novas formalizadas (`ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`).
- [x] 20 relações da V1.1 preservadas; 12 novas relações aprovadas incorporadas (`COT-REL-121..132`).
- [x] `ConflitoDadoItem` preservado sem `tenant_id` próprio — deriva de `ConflitoDado`.
- [x] `ResultadoCalculo` preservado sem XOR entre `unidade_economica_id` e `cenario_tributario_id`.
- [x] Nenhum enum criado; vocabulário de `papel` registrado como gap DST, não fechado.
- [x] Nenhuma FK composta implementada — apenas a estrutura relacional necessária para a futura decisão do ADR.
- [x] Nenhuma modelagem física de RLS antecipada.
- [x] Vinculo sem endpoints polimórficos livres.
- [x] Receita com ownership PF/PJ XOR.
- [x] N:N Receita-Documento e Documento-Arquivo explícitos.
- [x] ConflitoDadoItem restrito à auditoria.
- [x] Estados delegados ao DST V1.2.
- [x] Fase 1 permanece compatível.
- [x] Schema/migration continuam bloqueados.

## 18. Próximo documento

Com `COT-001` V1.2 e `MCD-001` V1.3 estruturalmente sincronizados, a ordem documental oficial
(`SEC-CHANGE-REQUEST-001` V1.1) determina os próximos passos: **`DST-001`** (vocabulário/gaps dos
campos recém-criados, incluindo o novo gap de `papel`) → **`CDC-001`** (contratos) →
**reconciliação** (auditoria cruzada COT × MCD × CDC × DST) → **`ADR`** (decisões físicas,
incluindo a FK composta `(unidade_economica_id, tenant_id)`, a estratégia de RLS conceitual e o
impacto em `schema.prisma`). Somente após aprovação do ADR poderá ser autorizada a nova migration
física (que substituirá a baseline histórica pré-SEC).

---
**Governança:** COT define objetos e estruturas relacionais autorizadas; MCD define campos; CDC define contratos; DST define significado. PostgreSQL/Prisma implementam essa arquitetura e não são sua fonte de verdade.
