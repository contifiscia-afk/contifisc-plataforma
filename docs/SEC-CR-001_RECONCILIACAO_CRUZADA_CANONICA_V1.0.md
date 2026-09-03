# SEC-CR-001 — Reconciliação Cruzada Canônica Pós-SEC

**Versão:** 1.0
**Status:** RELATÓRIO DE AUDITORIA — não altera nenhum documento normativo, ADR, Prisma,
migration ou banco.
**Fontes auditadas (lidas integralmente nesta rodada, sem confiar em relatórios anteriores):**
`SEC-001` V1.0, `SEC-CHANGE-REQUEST-001` V1.1, `COT-001` V1.2, `MCD-001` V1.3, `DST-001` V1.3,
`CDC-001` V1.3.
**Método:** verificação programática (`grep`/contagem de IDs únicos) sobre o texto real dos seis
documentos, sem reaproveitar contagens declaradas em versões anteriores dos próprios documentos
ou em relatórios de rastreabilidade anteriores (`SEC-CR-001_RASTREABILIDADE_COT_MCD_V1.0.md`,
`SEC-CR-001_RASTREABILIDADE_DST_V1.0.md`, `SEC-CR-001_RASTREABILIDADE_CDC_V1.0.md`).

---

## Resumo executivo

A reconciliação encontrou a arquitetura conceitual **integralmente coerente** entre os seis
documentos — nenhum princípio de `SEC-001` foi perdido, nenhum enum foi inventado, nenhuma FK
composta ou RLS foi antecipada, nenhum objeto diferido foi promovido a canônico. Todas as
contagens declaradas pelos documentos foram recalculadas de forma independente e **fecham
exatamente** (nenhum erro aritmético, ao contrário de rodadas anteriores deste projeto).

Entretanto, foram encontradas **2 questões RELEVANTES** que impedem o gate "apto para ADR" sem
correção prévia:

1. **`ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` são estruturas incompletas de forma que
   impede schema físico válido** — possuem apenas o campo `papel`; não têm `id` próprio nem FKs
   estruturais, e o próprio objeto referenciado (`ContaAcesso`) não tem nenhum campo MCD, nem
   mesmo `id`. `GAP-CDC-1.3-003` já registra parte disso, mas não registra a ausência mais
   fundamental de `ContaAcesso.id`.
2. **Divergência de mutabilidade em `MCD-F10004`** — o MCD declara `Imutável`; o CDC contratou
   `versioned` nos 6 hospedeiros. Contradição real entre dois documentos aprovados, sem cláusula
   de soberania do CDC sobre esse eixo.

Conclusão: **`BASELINE CANÔNICA PÓS-SEC REQUER CORREÇÃO ANTES DO ADR`** (ver §15).

---

## 1. Rastreabilidade integral SEC-001 → SEC-CHANGE-REQUEST-001 → COT → MCD → DST → CDC

| § SEC-001 | Decisão | COT | MCD | DST | CDC | Classificação |
|---|---|---|---|---|---|---|
| §1 Definições (Tenant, princípio dos 4 eixos) | `Tenant` fronteira de isolamento; `identidade tributária ≠ acesso ≠ tenant ≠ UE` | `COT-OBJ-019`, §13 | §3, §7 (DOM-SEC) | `DST-T031`, §2, §11 | `CDC-SEC-001`, §12 | **FECHADO** |
| §2 Cliente/Organização | `REDUNDANTE_NESTA_FASE` — nenhum objeto criado | ausência confirmada | §3 explícito | — (nada a nomear) | — (nada a nomear) | **FECHADO** |
| §3 Identidades globais (PF/PJ/FontePagadora) | Sem `tenant_id`/`unidade_economica_id` | §7, §13 | §3 | §11 | `CDC-PER-001`/`EMP-001`/`FPG-001` | **FECHADO** |
| §4 Contexto de apuração (6 fatos → UE) | `unidade_economica_id` obrigatório em 6 objetos | `COT-REL-122..127` | `MCD-F10004` | `DST-T034`, §11.1 | 6 contratos atualizados | **FECHADO** (ver divergência de mutabilidade, §4/§15) |
| §5 `ArquivoOrigem` | `tenant_id` obrigatório, sem UE | `COT-REL-128` | `MCD-F10003` | §11 | `CDC-ARQ-001` | **FECHADO** |
| §6 `ConflitoDado` | `tenant_id` materializado, nunca via referência polimórfica | `COT-REL-129`, §12 | `MCD-F10003`, §15 | §9, §11 | `CDC-CFD-001`, `CDC-REL-SEC-002` | **FECHADO** |
| §7 `ConflitoDadoItem` | Sem `tenant_id` próprio | nota §5 | §3, §9 (estruturas) | §9 | `CDC-CFD-002` | **FECHADO** |
| §8 `RevisaoTecnica` | `tenant_id` materializado; identidade do revisor separada | `COT-REL-130`, §12 | `MCD-F10003`, §15 | §9 | `CDC-REV-001` | **FECHADO** para `tenant_id`; identidade do revisor = **GAP_CONTROLADO** (`DST-GAP-014`, pré-existente, depende de `OBS-001`) |
| §9 `tenant_id` × `unidade_economica_id` | Eixos distintos, consistência quando coexistem | §13 | §10.1 | §2, §11 | §3 (envelope), §9 | **FECHADO** |
| §10 FK composta (decisão preferencial) | Estrutura registrada, forma física para o ADR | §8 | §12 | n/a (não é vocabulário) | `CDC-REL-SEC-004` | **DIFERIDO** (correto — pertence ao `ADR-002`) |
| §11 Matriz das 20 tabelas | 1 raiz + 3 materializado + 12 RLS-derivado + 3 sem + 1 derivado-do-pai | refletido via `COT-REL-*` | refletido via §7/§11 | n/a | refletido — nenhuma coluna `tenant_id` foi adicionada às 12 tabelas `RLS-derivado` | **FECHADO** (verificado: nenhuma das 12 tabelas RLS-derivadas recebeu coluna `tenant_id` própria — correto, mecanismo é RLS/join, não materialização) |
| §12 Autorização conceitual | `papel` aberto; `ContaAcesso↔Tenant`/`↔UE`; `PapelAcesso`/`Permissao` diferidos | `COT-SUP-005/006`, §13 | `MCD-F10005` | `DST-T035/036/037`, `DST-GAP-015` | `CDC-SEC-003/004`, `CDC-REL-SEC-001` | **GAP_CONTROLADO** — estrutura mínima existe, mas incompleta (ver §2/§3/§15) |
| §13 Autenticação (MFA, Sessao, contas de serviço, APIs) | `Sessao = SEGURANCA_OPERACIONAL` | §13 | §17 | §11 | §14 (checklist) | **DIFERIDO**, consistentemente propagado — **FECHADO** enquanto classificação |
| §14 RLS | Defesa em profundidade; `SET LOCAL` por transação | §8 (invariante) | §12 (invariante) | n/a | `CDC-REL-SEC-001` (invariante contratual) | **DIFERIDO** (correto — SQL de RLS é `ADR-002`) |
| §15 Jobs e integrações (contexto de tenant explícito) | Nenhum job deve herdar tenant implícito | não mencionado | não mencionado | não mencionado | não mencionado | **DIFERIDO** — correto não modelar como campo, mas **nenhum gap explícito rastreia este requisito** em COT/MCD/DST/CDC; risco de ser esquecido antes do `ADR-002`/implementação do Gateway (ver §15 do relatório, achado NAO_BLOQUEANTE) |
| §16 Auditoria (ator/tenant/UE/operação/objeto) | `EventoAuditoriaSeguranca` deve diferenciar esses atributos | `COT-OBJ-020` | `MCD-F10006` (só `id`) | `DST-T032` | `CDC-SEC-002` (só `id`) | **GAP_CONTROLADO** — `GAP-CDC-1.3-002`, corretamente registrado, nenhuma estrutura inventada |
| §17 LGPD | Minimização, retenção, anonimização | não mencionado (operacional) | não mencionado | não mencionado | não mencionado | **DIFERIDO** — correto, não é decisão de campo canônico |
| §18 Ambientes e secrets | Segregação de ambientes/segredos | não mencionado | não mencionado | não mencionado | não mencionado | **DIFERIDO** — correto, fora do escopo documental |
| §19 Migration baseline | Baseline histórica preservada; nova baseline só após sincronização | consistente | consistente | n/a | consistente | **FECHADO** |
| §20 Dependências futuras | `SEC-CR-001`, `DST-GAP-003`, `ADR-002`, `EVT-001`, `INT-001`, `OBS-001` | referenciadas | referenciadas | `DST-GAP-003` preservado | referenciadas | **FECHADO/GAP_CONTROLADO** — nenhuma dependência foi silenciosamente descartada |

**Nenhuma decisão de `SEC-001` desapareceu silenciosamente entre as camadas.** Os únicos itens que
não fecham em `FECHADO` puro são exatamente os que o próprio `SEC-001`/CR classificou como
`DIFERIDO`/`SEGURANCA_OPERACIONAL` (corretamente não canonizados) ou como dependência de outro
documento futuro (`OBS-001`, `ADR-002`) — nenhum caso de perda silenciosa foi encontrado.

---

## 2. COT × MCD

Todos os **20 objetos** (`COT-OBJ-001..020`) e as **6 estruturas de suporte** (`COT-SUP-001..006`)
foram verificados individualmente contra o catálogo de 145 campos do MCD:

| Situação | Objetos |
|---|---|
| Representação MCD completa e adequada | 16 objetos de domínio (`COT-OBJ-001..016`) + 4 estruturas de suporte pré-existentes (`COT-SUP-001..004`) |
| Representação MCD **mínima deliberada** (`id` apenas), com gap explícito | `Tenant` (`COT-OBJ-019` → `MCD-F10001`), `EventoAuditoriaSeguranca` (`COT-OBJ-020` → `MCD-F10006`) |
| **Representação MCD ausente por completo — zero campos, nem `id`** | `ContaAcesso` (`COT-OBJ-017`), `CredencialAcesso` (`COT-OBJ-018`) |
| Representação MCD **incompleta a ponto de impedir persistência** (só `papel`, sem identidade/FK) | `ContaAcessoTenant` (`COT-SUP-005`), `ContaAcessoUnidadeEconomica` (`COT-SUP-006`) |

**Achado principal:** `ContaAcesso`/`CredencialAcesso` nunca tiveram nenhum campo MCD atribuído
desde que foram catalogados no COT (V1.1) — nem mesmo um `id`. Isso é uma condição pré-existente,
já registrada de forma geral em `COT-001` §15 e `GAP-SEC-CR1-004`/`GAP-CDC-1.3-004`. Ela se torna
**diretamente relevante agora** porque as duas novas associações de acesso
(`ContaAcessoTenant`/`ContaAcessoUnidadeEconomica`) precisam de uma FK `conta_acesso_id` — e essa
FK não pode ter um ID MCD próprio de forma consistente enquanto `ContaAcesso.id` também não tiver
um. Nenhum dos gaps já registrados (`GAP-CDC-1.3-003`, `GAP-SEC-CR1-004`) menciona esta
dependência explicitamente — eles tratam como se fossem dois problemas separados, quando na
verdade um é pré-requisito do outro.

**Nenhuma relação COT (`COT-REL-101..132`) depende de FK inexistente no MCD** — as 32 relações em
si são conceituais/válidas independentemente da completude física das duas estruturas de suporte
acima. O problema está na **materialização** (`COT-SUP-005/006`), não na relação declarada
(`COT-REL-131/132`).

**Cardinalidades compatíveis:** confirmado — `COT-REL-131` (N:N via `COT-SUP-005`) e `COT-REL-132`
(N:N opcional via `COT-SUP-006`) são descritas identicamente em `COT-001` §5 e `MCD-001` §9/§11,
sem divergência.

### Campos exatamente ausentes no MCD (nenhum ID atribuído nesta análise)

**`ContaAcessoTenant`:**
- `id` (identidade própria da associação)
- `conta_acesso_id` (FK — bloqueada adicionalmente pela ausência de `ContaAcesso.id`)
- `tenant_id` (FK — papel semântico distinto de `MCD-F10002`/`MCD-F10003`, pois aqui representa
  "o tenant concedido", não "o tenant operacional do registro"; exige ID MCD próprio, não reuso)

**`ContaAcessoUnidadeEconomica`:**
- `id`
- `conta_acesso_id` (mesma ausência de pré-requisito)
- `unidade_economica_id` (FK — papel semântico distinto de `MCD-F10004`; exige ID MCD próprio)

**`ContaAcesso` (pré-requisito mais fundamental):**
- `id` — sem este campo, nenhuma das duas associações acima pode referenciar `ContaAcesso` de
  forma canônica.

Detalhamento completo em §3.

---

## 3. Análise formal de `GAP-CDC-1.3-003`

### `ContaAcessoTenant`

| Campo | Classificação | Justificativa |
|---|---|---|
| `id` | `OBRIGATORIO_CANONICO` | Toda estrutura de suporte persistível do catálogo tem identidade própria — precedente uniforme (`VinculoExtremidade`, `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem`, `ConflitoDadoItem`, todas com `id` próprio). Nenhuma exceção existe hoje. |
| `conta_acesso_id` | `OBRIGATORIO_CANONICO` | Sem esta FK a associação não tem significado — mas seu ID MCD só pode ser atribuído depois de `ContaAcesso.id` existir (pré-requisito, ver abaixo). |
| `tenant_id` | `OBRIGATORIO_CANONICO` | Idem — é o segundo lado da associação. Não pode reaproveitar `MCD-F10002`/`MCD-F10003` (papéis semânticos distintos — ver §2). |
| `unidade_economica_id` | `NAO_APLICAVEL` | Esta associação é a concessão de **Tenant inteiro**; UE pertence exclusivamente a `ContaAcessoUnidadeEconomica`. |
| `papel` | `OBRIGATORIO_CANONICO` | Já existe (`MCD-F10005`) — nenhuma ação necessária. |
| Timestamps (`concedido_em` etc.) | `DERIVAVEL` | `MCD-001` §9 já estabelece que timestamps de estruturas associativas podem ser atendidos pelos metadados transversais na materialização física, sem exigir campo local novo — precedente já aplicado a `ReceitaDocumentoFiscal`/`DocumentoFiscalArquivoOrigem`, que também não têm timestamp próprio. Nenhuma decisão nova é necessária. |
| Status/vigência | `DIFERIDO` | `COT-001` V1.2 §4 menciona "vigência da concessão" na descrição de `COT-SUP-005`, mas `SEC-CHANGE-REQUEST-001` V1.1 §5 **só aprovou `papel`** — vigência nunca foi submetida a decisão formal. Isso é uma **imprecisão textual do COT** (ver §13, achado editorial), não uma aprovação implícita. |

### `ContaAcessoUnidadeEconomica`

| Campo | Classificação | Justificativa |
|---|---|---|
| `id` | `OBRIGATORIO_CANONICO` | Mesmo precedente acima. |
| `conta_acesso_id` | `OBRIGATORIO_CANONICO` | Mesma dependência de `ContaAcesso.id`. |
| `tenant_id` | `DERIVAVEL` | Pode ser obtido via `unidade_economica_id` → `UnidadeEconomica.tenant_id` (`MCD-F10002`) — não precisa de coluna própria; útil apenas como otimização de consulta, não como requisito semântico. |
| `unidade_economica_id` | `OBRIGATORIO_CANONICO` | É o objeto da restrição. |
| `papel` | `OBRIGATORIO_CANONICO` | Já existe (`MCD-F10005`). |
| Timestamps | `DERIVAVEL` | Mesmo raciocínio de `ContaAcessoTenant`. |
| Status/vigência | `DIFERIDO` | Diferente de `ContaAcessoTenant`, `COT-001` nem chega a mencionar vigência para esta associação — assimetria textual entre as duas descrições que reforça que o assunto nunca foi decidido de forma consistente. |

### Natureza da correção necessária

| Item | Correção exigida | Por quê |
|---|---|---|
| `ContaAcesso.id`, `CredencialAcesso.id` | **Errata/nova versão do MCD** (não novo Change Request) | Atribuir `id` a um objeto já catalogado no COT desde a V1.1 é bookkeeping mecânico, não uma nova decisão arquitetural — mesmo padrão já usado para toda estrutura de suporte do catálogo. |
| `id`, `conta_acesso_id`, `tenant_id` de `ContaAcessoTenant` | **Errata/nova versão do MCD** | Idem — completude estrutural de uma associação já aprovada (`SEC-CHANGE-REQUEST-001` já aprovou a existência da relação `COT-REL-131`); não introduz arquitetura nova. |
| `id`, `conta_acesso_id`, `unidade_economica_id` de `ContaAcessoUnidadeEconomica` | **Errata/nova versão do MCD** | Idem, para `COT-REL-132`. |
| Timestamps das duas associações | **Sincronização documental já autorizada** | `MCD-001` §9 já permite atendê-los via metadados transversais na materialização física — nenhuma nova aprovação necessária, apenas tornar explícito que essa regra também vale aqui. |
| Vigência/status de `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` | **Novo Change Request** (ou emenda a `SEC-CHANGE-REQUEST-001`) | É uma decisão de produto/segurança real (concessões de acesso devem poder expirar?) nunca submetida à aprovação — não pode ser resolvida por inferência nem por errata mecânica. |
| Texto de `COT-001` §4 (menção a "vigência da concessão") | **Correção editorial em nova versão do COT**, ou aprovação retroativa via o Change Request acima | Hoje o texto do COT implica algo que nenhum documento aprovou formalmente. |

**Nenhum ID MCD é atribuído por este relatório** — apenas a classificação e a via de correção.

---

## 4. MCD × CDC — reconciliação programática dos 145 IDs

Verificação automatizada (script de contagem por `grep`, não por transcrição manual): todos os
**145 IDs `MCD-F*`** do catálogo aparecem em `CDC-001` V1.3; nenhum ID referenciado pelo CDC está
ausente do catálogo MCD (checagem bidirecional, resultado vazio nas duas direções).

| Verificação | Resultado |
|---|---|
| MCD sem CDC correspondente | **Nenhum** — 0 de 145 |
| CDC referenciando MCD inexistente | **Nenhum** — confirmado por diff automatizado |
| Campo em objeto errado | Nenhum encontrado — os hospedeiros de cada ID transversal (`MCD-F10003`→3 objetos, `MCD-F10004`→6 objetos, `MCD-F10005`→2 objetos) foram mapeados um a um contra os cabeçalhos de contrato no CDC e batem exatamente com a lista aprovada em `SEC-CHANGE-REQUEST-001` V1.1 |
| Cardinalidade divergente | Nenhuma — contagem de hospedeiros por campo transversal confere: `MCD-F10003`=3, `MCD-F10004`=6, `MCD-F10005`=2 (exatamente como aprovado) |
| Obrigatoriedade divergente | Nenhuma — `MCD-F10001..F10006` são todos "Sim" no MCD e "required" no CDC, sem exceção |
| **Semântica/mutabilidade divergente** | **1 caso encontrado — ver achado abaixo** |

### Achado: divergência de mutabilidade em `MCD-F10004`

`MCD-001` V1.3 §8 declara a política de `MCD-F10004` como **`Imutável`**. `CDC-001` V1.3 contrata
o mesmo campo como **`versioned`** nos 6 hospedeiros (`CDC-REC-001`, `CDC-PRE-001`,
`CDC-PREV-001`, `CDC-IRP-001`, `CDC-FIS-001`, `CDC-CAL-001`) — confirmado por grep direto nas
linhas de tabela dos dois documentos, reproduzido literalmente:

```
MCD-001 V1.3:  | MCD-F10004 | unidade_economica_id | ... | Sim | Imutável |
CDC-001 V1.3:  | unidade_economica_id | MCD-F10004 | input/output | required | ... | versioned |
                                                                                       ^^^^^^^^^
```

Isso é uma contradição real entre dois documentos aprovados — não uma reformulação autorizada.
`MCD-001` §8 concede ao CDC soberania explícita apenas sobre **obrigatoriedade por operação**
("O CDC continua soberano para obrigatoriedade por operação"), **não** sobre a coluna "Política"
(mutabilidade). Não há, portanto, cláusula que legitime a divergência.

**Contexto provável:** ao redigir `CDC-001` V1.3, `unidade_economica_id` foi tratado por analogia
às FKs de titularidade já existentes em `CDC-REC-001` (`pessoa_fisica_id`/`pessoa_juridica_id`,
que são `versioned` para permitir correção via reconciliação) — uma escolha funcionalmente
defensável (permitir corrigir a UE de um fato lançado incorretamente), mas que **não foi
confrontada com o valor já declarado no MCD** antes da publicação do CDC V1.3.

**Não é uma questão puramente editorial**: a política de mutabilidade determina se a coluna física
correspondente aceitará `UPDATE` no schema que o `ADR-002` vai desenhar. `ADR-002` não deve tomar
essa decisão sem que a contradição seja resolvida primeiro em um dos dois documentos-fonte.

---

## 5. COT × CDC

Os **20 objetos** e as **6 estruturas de suporte** (26 entidades) foram conferidos: cada uma
possui exatamente o contrato CDC esperado, ou justificativa explícita de ausência.

| Situação | Quantidade | Detalhe |
|---|---|---|
| Objeto com contrato CDC completo | 18 | `CDC-UE-001`, `CDC-PER-001`, `CDC-EMP-001`, `CDC-REL-001`, `CDC-REC-001`, `CDC-FIS-001`, `CDC-ARQ-001`, `CDC-EH-001`, `CDC-PRE-001`, `CDC-PREV-001`, `CDC-IRP-001`, `CDC-FPG-001`, `CDC-PLN-001`, `CDC-CAL-001`, `CDC-CFD-001`, `CDC-REV-001`, `CDC-SEC-001`, `CDC-SEC-002` |
| Objeto sem contrato, com justificativa explícita ("SEC futuro") | 2 | `ContaAcesso`, `CredencialAcesso` — consistente desde `COT-001` V1.1, sem mudança |
| Estrutura de suporte com contrato completo | 4 | `CDC-REL-002`, `CDC-FIS-002`, `CDC-FIS-003`, `CDC-CFD-002` |
| Estrutura de suporte com contrato **mínimo/incompleto** | 2 | `CDC-SEC-003`, `CDC-SEC-004` — gap já registrado (`GAP-CDC-1.3-003`), ver §3 |

**As 12 novas relações (`COT-REL-121..132`) confirmadas** — todas com contrato correspondente
(direto para as 10 primeiras; mínimo para as 2 últimas via `CDC-SEC-003`/`004`).

Nenhum objeto/estrutura ficou sem contrato **e** sem justificativa — a exigência do item 5 é
satisfeita mesmo com as duas associações mínimas, pois a ausência é explicitamente registrada
(`GAP-CDC-1.3-003`), não silenciosa.

---

## 6. DST × MCD × CDC

Nenhum valor fechado surge apenas no CDC. Verificação campo a campo dos 6 novos campos `DOM-SEC`:

| Campo MCD | Tipo | Termo/enum DST | Situação |
|---|---|---|---|
| `MCD-F10001` (`Tenant.id`) | UUID | n/a (identificador, não vocabulário) | OK |
| `MCD-F10002` (`tenant_id` raiz) | UUID/FK | `DST-T033` | OK |
| `MCD-F10003` (`tenant_id` transversal) | UUID/FK | `DST-T033` (mesma família semântica, IDs MCD distintos) | OK |
| `MCD-F10004` (`unidade_economica_id`) | UUID/FK | `DST-T034` | OK |
| `MCD-F10005` (`papel`) | Enum/Ref **aberto** | `DST-T035` + `DST-GAP-015` | OK — nenhum enum fechado criado; confirmado por grep que `CDC-SEC-003`/`004` tratam `papel` como aberto, sem union fechada |
| `MCD-F10006` (`EventoAuditoriaSeguranca.id`) | UUID | n/a | OK |

`CDC-ERR-017`/`018` (novos códigos de erro) e `CDC-REL-SEC-001..004` (novas constraints) são
identificadores internos do CDC, não vocabulário de domínio — mesmo padrão já usado por
`CDC-ERR-001..016`/`CDC-REL-XOR-001..002`, que também não têm termo DST equivalente. Não é uma
omissão.

**Verificação específica de `DST-GAP-015`:** confirmado aberto, sem catálogo fechado, corretamente
referenciado em `MCD-001` (`GAP-SEC-CR1-001`), `COT-001` (§15), e `CDC-001` (`CDC-SEC-003`/`004`,
`GAP-CDC-1.3-003`). Nenhuma tentativa de fechar o vocabulário por inferência foi encontrada.

**Conclusão da seção:** `FECHADO`.

---

## 7. `tenant_id` — raiz × transversal

- `MCD-F10002` (`UnidadeEconomica.tenant_id`, raiz) e `MCD-F10003` (`ArquivoOrigem`/`ConflitoDado`/
  `RevisaoTecnica`, transversal) permanecem **IDs MCD distintos** em todos os seis documentos —
  nenhuma menção encontrada que os trate como o mesmo campo canônico.
- Mesma representação física futura (`UUID`, provavelmente `FK → tenant.id`) é apropriada para
  ambos — mas isso é uma coincidência de tipo físico, não de identidade canônica, exatamente como
  o precedente de `MCD-F9001..F9010` já estabelece.
- **Nenhum outro objeto recebeu `tenant_id` "por conveniência"**: confirmado por grep — apenas
  `UnidadeEconomica` (`F10002`) e os 3 hospedeiros de `F10003` têm a coluna. As 12 tabelas
  `TENANT_DERIVADO_POR_RLS` da matriz do `SEC-001` §11 (`Vinculo`, `VinculoExtremidade`, `Receita`,
  `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`,
  `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem`, `ClassificacaoEquiparacaoHospitalar`,
  `CenarioTributario`, `ResultadoCalculo`) **não** receberam coluna própria — correto, a derivação
  é por RLS/join, decisão física a cargo do `ADR-002`.
- `ConflitoDadoItem` confirmado continuar sem `tenant_id` próprio, derivando exclusivamente via
  `conflito_dado_id` → `ConflitoDado.tenant_id` (`MCD-F8651`, FK já vigente) — nenhuma alteração
  encontrada.

**Conclusão:** `FECHADO`.

---

## 8. Auditoria de `MCD-F10004` nos seis hospedeiros

| Hospedeiro | Semântica (`DST-001` §11.1) | Cardinalidade | Nullability | Disponibilidade no ciclo de vida | Contrato CDC |
|---|---|---|---|---|---|
| `Receita` | "sob qual UE este ingresso é apurado" | N:1 | `NOT NULL` (obrig. base = Sim) | No momento da criação do fato | `CDC-REC-001` |
| `ContribuicaoPrevidenciaria` | mesma pergunta | N:1 | `NOT NULL` | Idem | `CDC-PRE-001` |
| `VinculoPrevidenciario` | mesma pergunta | N:1 | `NOT NULL` | Idem | `CDC-PREV-001` |
| `EventoIRPF` | mesma pergunta | N:1 | `NOT NULL` | Idem | `CDC-IRP-001` |
| `DocumentoFiscal` | mesma pergunta (nota de timing) | N:1 | `NOT NULL` | **Atribuição própria**, não derivada de `Receita` — pode chegar antes de qualquer `Receita` existir | `CDC-FIS-001` |
| `ResultadoCalculo` | mesma pergunta | N:1 | `NOT NULL` | No momento do cálculo; deve ser consistente com `CenarioTributario.unidade_economica_id` quando presente | `CDC-CAL-001` |

**Semântica:** uniforme confirmada nos 6 — mesma pergunta respondida, nenhuma variação de papel
(diferente do precedente `receita_id`, que muda de papel por hospedeiro).

**Diferença de workflow vs. divergência semântica:** a única variação real é o *momento* de
atribuição em `DocumentoFiscal` (chega antes de `Receita` no pipeline RAW→Canonical). Isso é
corretamente tratado em `DST-001` §11.1 e `CDC-001` (`CDC-FIS-001`) como nuance de **timing
operacional**, não como divergência de significado — concordo com essa conclusão após reverificar
os quatro eixos (semântica, cardinalidade, nullability, disponibilidade): apenas a disponibilidade
varia, e varia por razão de pipeline, não de contrato.

**Divergência real encontrada nesta auditoria:** mutabilidade (`Imutável` no MCD vs. `versioned`
no CDC) — ver §4. Isso não estava coberto pela verificação de `DST-001` §11.1 (que audita
semântica, não mutabilidade contratual) nem pelo relatório de rastreabilidade anterior do CDC.

---

## 9. `ResultadoCalculo` — reconfirmação

`cenario_tributario_id` (`MCD-F8202`, opcional) e `unidade_economica_id` (`MCD-F10004`,
obrigatório) **coexistem sem XOR** — confirmado em `SEC-001` §4/§9, `SEC-CHANGE-REQUEST-001` item
9, `COT-001` (linha do objeto, §8), `MCD-001` §12, `CDC-001` (`CDC-CAL-001` + `CDC-REL-SEC-003`).
Nenhum dos seis documentos introduz XOR. A consistência exigida entre os dois campos quando ambos
presentes permanece corretamente registrada como constraint a decidir no `ADR-002`
(`CDC-REL-SEC-003`), não implementada agora.

**Nota relacionada (não uma inconsistência, um risco a observar):** `GAP-SEC-CR1-003` registra que
o cenário "resultado técnico/global sem UE" não foi confirmado nem descartado. Hoje,
`unidade_economica_id` é contratado como `required` em `ResultadoCalculo` — se esse cenário se
confirmar real no futuro, a obrigatoriedade precisará ser revisada. Isso não bloqueia o gate atual
(a decisão vigente é consistente e foi tomada deliberadamente), mas o `ADR-002` deveria registrar
explicitamente que aceita a obrigatoriedade atual como hipótese de trabalho, não como fato
definitivamente encerrado.

**Conclusão:** `FECHADO`, com um risco `NAO_BLOQUEANTE` observado (`GAP-SEC-CR1-003`).

---

## 10. Objetos globais (`PessoaFisica`, `PessoaJuridica`, `FontePagadora`)

Confirmado por grep e leitura integral: nenhum dos três recebeu `tenant_id` ou
`unidade_economica_id` em nenhum dos seis documentos.

**Por que isso não produz concessão cross-tenant:** o acesso a essas identidades globais nunca é,
por si só, a fonte de autorização — a autorização é sempre avaliada no nível do **fato**
tenant-scoped que referencia a identidade (ex.: uma `Receita` específica, com seu próprio
`tenant_id` derivado de `unidade_economica_id` → `UnidadeEconomica.tenant_id`). Duas `Receita` de
tenants diferentes podem apontar para a mesma `PessoaFisica` sem que isso vaze dados entre
tenants, porque o RLS (a ser desenhado no `ADR-002`) filtraria por `tenant_id` do fato, não pela
identidade da PF. Esse mecanismo está corretamente descrito em `SEC-001` §3 e reafirmado
identicamente em `COT-001` §7, `MCD-001` §3, `DST-001` §11 e `CDC-001` (`CDC-PER-001`/`EMP-001`/
`FPG-001`).

**Conclusão:** `FECHADO`.

---

## 11. Associações de autorização — semântica confirmada

`ContaAcesso × Tenant` = concessão básica de escopo (`CDC-SEC-003`, `DST-T036`). `ContaAcesso ×
UnidadeEconomica` = restrição adicional que **somente restringe** (`CDC-SEC-004`, `DST-T037`,
`CDC-REL-SEC-001`). A formalização textual do invariante ("nunca amplia, nunca substitui, nunca
concede acesso implícito a outras UEs") está presente e idêntica em `SEC-001` §12,
`SEC-CHANGE-REQUEST-001` item 6, `COT-001` §4.1/§8, `MCD-001` §12, `DST-001` §11, `CDC-001`
(`CDC-SEC-004`, `CDC-REL-SEC-001`).

**Ressalva:** essa semântica está corretamente **especificada em prosa/constraint declarada**, mas
ainda não é **enforçável** como constraint real de banco, porque as colunas físicas da associação
(`conta_acesso_id`, `tenant_id`/`unidade_economica_id`) ainda não têm ID MCD (§2/§3). Isso não
invalida a especificação — apenas confirma que sua materialização depende da correção de
`GAP-CDC-1.3-003` antes do `ADR-002`.

**Conclusão:** `FECHADO` semanticamente; `GAP_CONTROLADO` estruturalmente (mesma causa de §2/§3).

---

## 12. Objetos diferidos/operacionais

| Objeto | Classificação exigida | COT | MCD | DST | CDC |
|---|---|---|---|---|---|
| `Sessao` | `SEGURANCA_OPERACIONAL` | ✓ §13 | ✓ §17 | ✓ §11 | ✓ §14 (checklist, linha 900) |
| `PapelAcesso` | `DIFERIDO` | ✓ §13 | ✓ §17 | ✓ §11 | ✓ `CDC-SEC-003` regra + §14 |
| `Permissao` | `DIFERIDO` | ✓ §13 | ✓ §17 | ✓ §11 | ✓ idem |

Nenhum dos três aparece como objeto canônico (`COT-OBJ-*`), campo MCD, termo DST (`DST-T*`) ou
contrato CDC em nenhum dos seis documentos — confirmado por grep negativo (`Sessao`,
`PapelAcesso`, `Permissao` não aparecem como IDs formais em nenhuma tabela de catálogo). As únicas
ocorrências são menções textuais de exclusão/classificação, nunca de inclusão.

**Conclusão:** `FECHADO`.

---

## 13. Gaps consolidados

| ID | Origem | Descrição | Doc. responsável | Bloqueia ADR-002? | Bloqueia Prisma? | Bloqueia migration? | Doc. futuro responsável | Classe |
|---|---|---|---|---|---|---|---|---|
| `DST-GAP-001` | V1.0 | `conselho_profissional` sem catálogo | DST | Não | Não | Não | Change Request de vocabulário | `GAP_CONTROLADO` |
| `DST-GAP-002` | V1.0 | `especialidade_saude` sem catálogo | DST | Não | Não | Não | Idem | `GAP_CONTROLADO` |
| `DST-GAP-003` | V1.0 | `tipo_vinculo` sem catálogo | DST | Não | Não | Não | Idem | `GAP_CONTROLADO` |
| `DST-GAP-005..013` (9 gaps) | V1.0/V1.1 | Vocabulários abertos diversos (`papel_vinculo`, `fonte_receita`, `tipo_documento_fiscal`, `tipo_vinculo_previdenciario`, `tipo_conflito`, `tipo_objeto_revisado`, `papel_arquivo`, `tipo_objeto`, `papel_no_conflito`) | DST | Não | Não | Não | Change Requests de vocabulário | `GAP_CONTROLADO` |
| `DST-GAP-014` / `GAP-MCD-CR2-004` / `GAP-CDC-1.2-003` | V1.0 | Identidade do revisor de `RevisaoTecnica` | DST/MCD/CDC | Não (tenant_id de `RevisaoTecnica` já resolvido; só a identidade do revisor pendente) | Não | Não | `OBS-001` | `GAP_CONTROLADO` |
| `DST-GAP-015` / `GAP-SEC-CR1-001` | `SEC-CHANGE-REQUEST-001` V1.1 | Vocabulário de `papel` | DST/MCD/CDC | Não (tipo físico `TEXT` já decidível sem o catálogo fechado) | Não | Não | Change Request de RBAC | `GAP_CONTROLADO` |
| `GAP-SEC-CR1-002` | idem | `Vinculo` sem extremidade UE — depende de `DST-GAP-003` | MCD | Não | Não | Não | Fechamento de `DST-GAP-003` | `GAP_CONTROLADO` |
| `GAP-SEC-CR1-003` | idem | `ResultadoCalculo` sem UE nem Cenário simultaneamente — não confirmado/descartado | MCD | **Sim, parcialmente** — `ADR-002` deve registrar a obrigatoriedade atual como hipótese revisável | Não | Não | Revisão futura de obrigatoriedade | `GAP_CONTROLADO` (risco `NAO_BLOQUEANTE`, ver §15) |
| `GAP-SEC-CR1-004` / `GAP-CDC-1.3-001/002/004` | idem | Detalhamento completo de `Tenant`, `EventoAuditoriaSeguranca`, `ContaAcesso`, `CredencialAcesso` além dos campos mínimos | MCD/CDC | Não (modelo mínimo com `id` é suficiente para o escopo do `ADR-002`) | Não, para o escopo mínimo já aprovado | Não | Change Request de autenticação/RBAC | `GAP_CONTROLADO` |
| `GAP-CDC-1.2-001`/`002`/`004`/`005` | V1.2 | Vocabulários/tipagens diversas do domínio tributário | CDC | Não | Não | Não | Change Requests de domínio | `GAP_CONTROLADO` |
| **`GAP-CDC-1.3-003` (ampliado nesta auditoria)** | `SEC-CHANGE-REQUEST-001` V1.1 | `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` sem `id`/FKs estruturais; **e `ContaAcesso`/`CredencialAcesso` sem nenhum campo MCD, nem `id`** (achado novo desta auditoria — não estava explícito no gap original) | MCD | **Sim** — impede schema físico válido para `COT-SUP-005/006` | **Sim**, para essas 2 tabelas especificamente | **Sim**, para essas 2 tabelas | Errata/nova versão do MCD (ver §3) | **`INCONSISTENCIA_CANONICA`** |
| **Divergência de mutabilidade `MCD-F10004`** (achado novo) | Autoria de `CDC-001` V1.3 | MCD declara `Imutável`; CDC contrata `versioned` nos 6 hospedeiros | MCD e/ou CDC | **Sim** — `ADR-002` não deve decidir `UPDATE`-ability sem resolver a contradição | Sim, para a definição de coluna | Não diretamente | Errata a um dos dois documentos | **`INCONSISTENCIA_CANONICA`** |
| Menção não aprovada de "vigência da concessão" | `COT-001` V1.2 §4 | Texto do COT implica campo nunca aprovado pelo CR/MCD | COT | Não | Não | Não | Correção editorial ou novo CR | `NAO_BLOQUEANTE` / `EDITORIAL` |
| Ausência de gap explícito para `SEC-001` §15 (contexto de tenant em jobs) | `SEC-001` V1.0 | Requisito operacional sem ticket de rastreamento em COT/MCD/DST/CDC | — | Não | Não | Não | Nota de implementação futura (Gateway/Skills) | `NAO_BLOQUEANTE` |

**Distinção rigorosa aplicada:** todos os itens acima seguem `GAP_CONTROLADO` (registrados,
explicados, com caminho de resolução, não bloqueantes) **exceto os dois marcados
`INCONSISTENCIA_CANONICA`**, que representam contradição real entre documentos já aprovados
(mutabilidade de `MCD-F10004`) ou impossibilidade estrutural de implementação física sem correção
prévia (`ContaAcessoTenant`/`ContaAcessoUnidadeEconomica`/`ContaAcesso`).

---

## 14. Contagens recalculadas independentemente

| Item | Contagem recalculada (`grep`, nesta auditoria) | Contagem declarada nos documentos | Diferença |
|---|---|---|---|
| Objetos COT (`COT-OBJ-*`) | 20 | 20 | Nenhuma |
| Estruturas de suporte COT (`COT-SUP-*`) | 6 | 6 | Nenhuma |
| Relações COT (`COT-REL-101..132`, faixa vigente) | 32 | 32 (20 antigas + 12 novas) | Nenhuma — a string `COT-REL-001` também aparece no texto, mas apenas como referência histórica em prosa (§5 do COT), não como relação ativa; corretamente excluída da contagem |
| Campos MCD (`MCD-F*`) | 145 | 145 (139 + 6) | Nenhuma |
| Termos DST (`DST-T*`) | 37 | 37 (30 + 7) | Nenhuma |
| Enums DST (`DST-E*`) | 12 (`E001..E012`, sem lacuna) | 12 | Nenhuma |
| Gaps DST (`DST-GAP-*`) | 15 | 15 (14 + 1) | Nenhuma |
| Contratos CDC (contando `CDC-REL-001`/`002` como contratos, não como constraints) | 25 | 25 (21 + 4) | Nenhuma |
| Erros CDC (`CDC-ERR-*`) | 18 | 18 (16 + 2) | Nenhuma |
| Constraints relacionais CDC (`CDC-REL-XXX-NNN`) | 10 | 10 (6 + 4) | Nenhuma |
| Gaps CDC (`GAP-CDC-*`) | 9 | 9 (5 + 4) | Nenhuma |

**Nenhuma diferença encontrada em nenhuma contagem.** Diferente de rodadas anteriores deste
projeto (ex.: o erro aritmético 21 vs. 20 na matriz de tenant do `SEC-001` adendo V1, corrigido na
V2), esta rodada de COT/MCD/DST/CDC fecha exatamente em todas as dimensões verificadas.

---

## 15. Gate para ADR

| Achado | Severidade |
|---|---|
| `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica`/`ContaAcesso` sem identidade/FKs estruturais no MCD (`GAP-CDC-1.3-003` ampliado) | **RELEVANTE** |
| Divergência de mutabilidade em `MCD-F10004` (`Imutável` no MCD × `versioned` no CDC) | **RELEVANTE** |
| `GAP-SEC-CR1-003` — obrigatoriedade de `unidade_economica_id` em `ResultadoCalculo` assume um cenário ainda não confirmado | `NAO_BLOQUEANTE` |
| `SEC-001` §15 (contexto de tenant em jobs) sem gap de rastreamento explícito | `NAO_BLOQUEANTE` |
| Menção não aprovada de "vigência da concessão" em `COT-001` §4 | `EDITORIAL` |

Nenhum achado `CRITICAL` foi encontrado — a arquitetura conceitual está correta, nenhuma decisão
de `SEC-001` foi perdida, nenhum enum foi inventado, nenhuma promoção indevida de objeto diferido
ocorreu. Porém **2 achados `RELEVANTE` existem**, e a instrução deste relatório é explícita:
existindo inconsistência estrutural de ausência de identidade/FKs das associações, o gate deve
ser negativo.

### Conclusão do gate

```
BASELINE CANÔNICA PÓS-SEC REQUER CORREÇÃO ANTES DO ADR
```

### Documentos que precisam de nova versão, e por quê

| Documento | Nova versão necessária? | Motivo |
|---|---|---|
| `MCD-001` (→ V1.4 ou errata) | **Sim** | (a) Atribuir `id` a `ContaAcesso`/`CredencialAcesso`; (b) atribuir `id`/`conta_acesso_id`/`tenant_id` a `ContaAcessoTenant` e `id`/`conta_acesso_id`/`unidade_economica_id` a `ContaAcessoUnidadeEconomica`; (c) resolver a divergência de mutabilidade de `MCD-F10004` (confirmar `Imutável` ou revisar para `Versionado`). Nenhum destes é uma nova decisão arquitetural — são completude mecânica de estruturas já aprovadas, mais a correção de uma contradição textual. |
| `CDC-001` (→ V1.4) | **Sim, na sequência do MCD** | Completar `CDC-SEC-003`/`CDC-SEC-004` com as novas linhas de campo assim que o MCD as definir; e alinhar a mutabilidade de `unidade_economica_id` (`MCD-F10004`) ao valor que o MCD confirmar. |
| `COT-001` (→ V1.3, opcional/editorial) | Recomendado, não bloqueante | Remover ou qualificar a menção a "vigência da concessão" em `COT-SUP-005` (§4), que hoje excede o que foi efetivamente aprovado. Alternativa: manter o texto e abrir um Change Request específico para aprovar formalmente o campo de vigência. |
| `DST-001` | **Não** | Nenhum achado desta auditoria implica DST — `DST-GAP-015` já está corretamente registrado e nada nesta reconciliação exige fechamento de vocabulário. |
| `SEC-001` / `SEC-CHANGE-REQUEST-001` | **Não** | As duas questões relevantes decorrem da **incorporação** ao MCD/CDC, não de uma falha na decisão arquitetural original — `SEC-001`/CR permanecem corretos e completos no nível conceitual em que operam. |

### O que NÃO exige correção (explicitamente confirmado nesta auditoria)

- Todas as 20 relações da matriz de tenant do `SEC-001` §11 estão corretamente refletidas (nenhuma
  tabela `RLS-derivado` recebeu coluna espúria de `tenant_id`).
- `ConflitoDadoItem`, `PessoaFisica`/`PessoaJuridica`/`FontePagadora`, `Sessao`/`PapelAcesso`/
  `Permissao` estão exatamente como deveriam, em todos os seis documentos.
- Nenhum enum foi fechado por inferência; nenhuma FK composta ou RLS foi antecipada; nenhum ID foi
  reutilizado; todas as contagens fecham.

**Não avancei para ADR, Prisma ou migration.** Nenhum documento normativo foi alterado por esta
auditoria — apenas este relatório foi produzido.
