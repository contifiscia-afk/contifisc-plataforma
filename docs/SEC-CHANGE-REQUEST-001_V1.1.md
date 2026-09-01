# SEC-CHANGE-REQUEST-001 — Escopo de Alteração Canônica Derivado do SEC-001 V1.0

**Versão:** 1.1
**Status:** PROPOSTO PARA APROVAÇÃO — especificação de escopo; **nenhuma alteração foi
executada**.
**Substitui:** `docs/SEC-CHANGE-REQUEST-001_V1.0.md`, cujo status passa a
**`SUPERADO POR REVISÃO — SUBSTITUIR POR V1.1`** (preservado no repositório como histórico, não
alterado por este documento).
**Origem normativa:** `docs/SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`
(**APROVADO**) e `docs/SEC-CHANGE-REQUEST-001_REVISAO_V1.0.md` (revisão de minimalidade, aceita).
**Escopo:** especificar exatamente quais objetos, campos, relações e IDs precisariam ser
adicionados a `COT-001`, `MCD-001`, `CDC-001`, `DST-001` e `ADR-001`. **Este documento não altera
nenhum dos documentos citados, não altera `schema.prisma`, não cria migration, não cria banco,
não implementa autenticação ou RLS.**

Nenhum ID novo proposto abaixo é atribuído definitivamente — todos são **candidatos**, a
confirmar somente na aprovação formal deste CR.

**Mudanças desta versão em relação à V1.0** (incorporando integralmente
`SEC-CHANGE-REQUEST-001_REVISAO_V1.0.md`): objetos candidatos reduzidos de 5 para 2; relações
reduzidas de 13 para 12; campo `papel` adicionado a duas associações (total de campos: 10 → 12);
IDs MCD de `tenant_id` desdobrados em dois candidatos distintos (antes um único `MCD-F9011`);
semântica de restrição por UE formalizada explicitamente; ordem documental corrigida. Nenhuma
contagem da V1.0 é mantida por compatibilidade textual — todas as tabelas abaixo refletem apenas
os valores corrigidos.

---

## Convenção deste documento

Cada alteração é apresentada no formato obrigatório:

```
origem normativa → objeto afetado → alteração → justificativa → documento a alterar →
impacto físico → dependências
```

Cada alteração é também marcada com uma categoria:

- **CANÔNICO** — entra em `COT`/`MCD`/`CDC`/`DST`.
- **ARQUITETURAL/FÍSICO** — pertence ao `ADR` (novo `ADR-002`, ver Ordem documental).
- **SEGURANÇA OPERACIONAL** — necessário para o funcionamento do sistema, mas não catalogado em
  COT/MCD como objeto canônico — permanece responsabilidade da implementação/fornecedor.
- **DIFERIDO** — não descartado, mas não incluído nesta versão do CR; revisitável quando um
  requisito concreto existir, ou dependente de `EVT-001`, `INT-001`, `OBS-001` ou `DST-GAP-003`.

---

## 1. Novos objetos canônicos (2, reduzido de 5)

| Candidato | Domínio | Categoria | Justificativa |
|---|---|---|---|
| `Tenant` (`COT-OBJ-019` candidato) | `DOM-SEC` | **CANÔNICO** | Fronteira de isolamento/propriedade lógica — identidade e semântica estáveis da CONTIFISC, independentes de qualquer framework/provedor de autenticação. Âncora de toda a matriz de tenant das 20 tabelas. |
| `EventoAuditoriaSeguranca` (`COT-OBJ-020` candidato) | `DOM-SEC` | **CANÔNICO** | Trilho de auditoria de segurança (login, falha de autenticação, mudança de permissão, elevação de privilégio, acesso sensível, override, operação administrativa) — necessidade de compliance/LGPD própria da CONTIFISC, que deve sobreviver a qualquer troca de provedor de autenticação. Escopo estreito — nunca um repositório de logs técnicos genéricos. |

## 2. Objetos removidos como canônicos nesta versão (3)

| Objeto | Classificação | Justificativa |
|---|---|---|
| `Sessao` | **`SEGURANCA_OPERACIONAL`** | O estado mutável de uma sessão (revogação, MFA por sessão, dispositivo, refresh token, expiração) é inerentemente definido pelo provedor de autenticação escolhido — nenhuma forma estável e independente de fornecedor existe hoje para catalogar. A única necessidade que sobrevive a qualquer provedor (auditoria de que um login/logout/revogação ocorreu) já é coberta por `EventoAuditoriaSeguranca`, sem exigir um objeto `Sessao` separado. Não confundidos: `EventoAuditoriaSeguranca` é um registro imutável de fato passado; uma `Sessao` seria um registro mutável de estado presente. |
| `PapelAcesso` | **`DIFERIDO`** | Nenhum requisito concreto hoje exige um objeto canônico de papel — um campo `papel` aberto nas associações de acesso (item 5) já resolve integralmente os cenários conhecidos (funcionário CONTIFISC multi-tenant, administrador, cliente externo, restrição por UE, segregação de funções por comparação de valores). Mesmo padrão já usado no projeto para vocabulário aberto (`tipo_vinculo`, `papel_vinculo` são campos, não objetos). Pode voltar a ser canônico se um requisito concreto de RBAC estruturado surgir. |
| `Permissao` | **`DIFERIDO`** | Mesma razão de `PapelAcesso` — nenhum requisito hoje confirma a necessidade de decompor papéis em permissões atômicas. |

## 3-4. Relações (12, reduzido de 13) e cardinalidades

| # | Relação (candidata `COT-REL-*`, a partir de 121) | Cardinalidade | Categoria |
|---|---|---|---|
| 1 | `UnidadeEconomica → Tenant` | N:1 | CANÔNICO |
| 2 | `Receita → UnidadeEconomica` | N:1 | CANÔNICO |
| 3 | `ContribuicaoPrevidenciaria → UnidadeEconomica` | N:1 | CANÔNICO |
| 4 | `VinculoPrevidenciario → UnidadeEconomica` | N:1 | CANÔNICO |
| 5 | `EventoIRPF → UnidadeEconomica` | N:1 | CANÔNICO |
| 6 | `DocumentoFiscal → UnidadeEconomica` | N:1 | CANÔNICO |
| 7 | `ResultadoCalculo → UnidadeEconomica` | N:1 | CANÔNICO |
| 8 | `ArquivoOrigem → Tenant` | N:1 | CANÔNICO |
| 9 | `ConflitoDado → Tenant` | N:1 | CANÔNICO |
| 10 | `RevisaoTecnica → Tenant` | N:1 | CANÔNICO |
| 11 | `ContaAcesso ↔ Tenant` (via `COT-SUP-005` candidato) | N:N (carrega o campo `papel`, item 5) | SEGURANÇA OPERACIONAL (relação em si é CANÔNICO — ver nota) |
| 12 | `ContaAcesso ↔ UnidadeEconomica` (via `COT-SUP-006` candidato) | N:N opcional (carrega o campo `papel`, item 5) | SEGURANÇA OPERACIONAL (relação em si é CANÔNICO — ver nota) |

**Nota sobre a categoria das relações 11-12:** a **existência** da relação e sua **catalogação**
(objeto de associação, cardinalidade, campos) é **CANÔNICO** (entra em COT/MCD/CDC); a
**operação** de autorização que a consome (avaliar `papel`, decidir acesso) é **SEGURANÇA
OPERACIONAL** — a mesma relação serve às duas camadas, cada uma em seu documento próprio (COT/MCD
para a estrutura; futuro material de implementação de autorização para a operação).

**Removida em relação à V1.0:** `PapelAcesso ↔ Permissao` (`COT-SUP-007` candidato) — sem objeto,
pois ambos os lados foram reclassificados `DIFERIDO` (item 2).

**Nenhuma relação redundante ou derivável foi encontrada entre as 12 mantidas.**

## 5. Campo aberto `papel` — substituindo `PapelAcesso`/`Permissao`

Adicionado às duas associações de acesso:

| Objeto | Campo | Tipo | Vocabulário |
|---|---|---|---|
| `ContaAcesso ↔ Tenant` (`COT-SUP-005`) | `papel` | `TEXT` | **Aberto** — nenhum enum criado. Registrado como novo `DST-GAP` candidato (número a atribuir pelo `DST-001`), mesmo padrão de `DST-GAP-003` (`tipo_vinculo`). |
| `ContaAcesso ↔ UnidadeEconomica` (`COT-SUP-006`) | `papel` | `TEXT` | Idem. |

**Nenhum enum é criado. Nenhum vocabulário de papel é fechado por este CR.**

## 6. Autorização por `UnidadeEconomica` — semântica formalizada

**Autorização por `UnidadeEconomica` restringe o escopo concedido pelo `Tenant` — nunca:**

- **amplia** — não é possível usar uma concessão de UE para acessar uma UE fora do tenant já
  concedido;
- **substitui** — uma concessão de UE nunca existe sem uma concessão de `Tenant` subjacente,
  que continua sendo pré-requisito;
- **cria acesso implícito a outras UEs** — a presença de qualquer restrição de UE para um par
  (`ContaAcesso`, `Tenant`) desliga o padrão "todas as UEs do tenant" e liga uma lista explícita
  (default-deny reforçado, nunca aditivo).

**Invariante formal (registrada para o `ADR` físico, não implementada aqui):** *quando existir ao
menos uma linha de `ContaAcesso ↔ UnidadeEconomica` para um dado par (`ContaAcesso`, `Tenant`), a
avaliação de autorização deve considerar exclusivamente as UEs explicitamente listadas para
aquele par.* Categoria: SEGURANÇA OPERACIONAL (princípio) + ARQUITETURAL/FÍSICO (mecanismo de
verificação).

## 7. IDs MCD de `tenant_id` — dois candidatos distintos, não um só

**Nenhum ID de `MCD-F9001..F9010` é reutilizado. Nenhum ID é atribuído definitivamente — ambos
seguem candidatos até aprovação formal.**

| Candidato | Campo físico | Objeto(s) | Papel semântico |
|---|---|---|---|
| `MCD-F10001` (candidato, domínio `DOM-SEC`) | `tenant_id` | `UnidadeEconomica` | **Atributo definidor da raiz** — a própria propriedade que estabelece a qual `Tenant` uma `UnidadeEconomica` pertence. Fonte primária de toda a cadeia de derivação de tenant das demais 16 tabelas. |
| `MCD-F10002` (candidato, domínio `DOM-SEC`) | `tenant_id` | `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica` | **Metadado transversal de segurança** — carimbado pelo processo/sessão que cria o registro, aplicável exclusivamente a objetos sem caminho de domínio confiável até `UnidadeEconomica`. Estruturalmente análogo ao padrão de `F9001..F9010` (campo transversal, decidido fisicamente à parte do catálogo principal de cada objeto), mas com ID e domínio próprios — nunca reaproveitando os números `F9001..F9010`. |

**Por que os dois não compartilham o mesmo ID semântico apesar do mesmo nome físico:**

Um ID de campo `MCD` representa um **conceito canônico único e estável**, não um nome de coluna.
Duas colunas podem ter o mesmo nome físico (`tenant_id`) — conveniente e consistente do ponto de
vista de leitura do `schema.prisma` — sem representar o **mesmo conceito de domínio**. Aqui, os
dois papéis são estruturalmente diferentes:

1. **Determinação:** `MCD-F10001` é **definido no momento da criação da UE** e nunca muda
   (a UE não "descobre" seu tenant depois — ela nasce pertencendo a um). `MCD-F10002` é
   **carimbado pelo processo operacional** (ingestão, reconciliação, revisão) que cria o registro
   — sua fonte é o contexto de execução, não uma decisão de domínio inerente ao objeto.
2. **Papel estrutural:** `MCD-F10001` é a **âncora** da qual os outros 16 objetos derivam tenant
   por relação; `MCD-F10002` é uma **folha** — nada deriva tenant a partir dele.
3. **Precedente do próprio MCD:** a regra já vigente "um conceito não pode ter dois campos
   canônicos" (`MCD-001` V1.2 §2) tem uma contrapartida implícita: **um único campo canônico não
   deve abranger dois conceitos distintos** apenas por coincidência de nome físico — exatamente
   o padrão já seguido por `F9001..F9010`, onde cada ID cobre um único papel semântico preciso,
   nunca múltiplos papéis "porque a coluna se chama igual" em tabelas diferentes.

Se um dia se decidir que os dois DEVEM convergir (ex.: eliminar `MCD-F10001` e tratar até a UE
como "mais um objeto transversal"), isso é uma decisão canônica própria, a ser feita
explicitamente em uma revisão futura do `MCD-001` — não uma inferência automática deste CR.

## 8. `ConflitoDadoItem` — preservado sem `tenant_id`

**Nenhuma alteração de campo.** `ConflitoDadoItem` **não recebe `tenant_id`** — o tenant é sempre
lido através de `conflito_dado_id` (FK real, `NOT NULL`, já vigente), nunca materializado
redundantemente. Classificação de estratégia: `TENANT_DERIVADO_DO_PAI` (inalterada desde
`SEC-001_RESOLUCAO_FINAL_V1.md` §4). Categoria: ARQUITETURAL/FÍSICO (documentação da estratégia
de derivação, sem campo novo).

## 9. `ResultadoCalculo` — preservado sem XOR

**Nenhum XOR entre `unidade_economica_id` e `cenario_tributario_id`.**
`CenarioTributario.unidade_economica_id` já é `NOT NULL` (migration V1 validada) — as duas FKs
não competem por ownership; `ResultadoCalculo.unidade_economica_id` é sempre preenchido (item 12,
lista de campos), e deve ser **consistente** com `CenarioTributario.unidade_economica_id` quando
ambos presentes, via constraint de consistência a decidir no `ADR` — nunca mutuamente exclusivo.
Categoria: CANÔNICO (o campo) + ARQUITETURAL/FÍSICO (a constraint de consistência).

## 10. Integridade `Tenant` × `UnidadeEconomica`

Preservado da V1.0, sem alteração de escopo: `(unidade_economica_id, tenant_id)` deve ser
estruturalmente compatível com `unidade_economica(id, tenant_id)` — exigindo uma chave candidata
correspondente (`UNIQUE(id, tenant_id)`, ou forma equivalente) em `UnidadeEconomica`. **A forma
física definitiva (FK composta, trigger, ou outro mecanismo) permanece responsabilidade do `ADR`
— não decidida nem implementada por este CR canônico**, além de garantir que a relação
`UnidadeEconomica → Tenant` (item 3, relação 1) exista. Categoria: ARQUITETURAL/FÍSICO.

## 11. Mudanças específicas por objeto (rastreabilidade completa)

| # | origem normativa | objeto afetado | alteração | justificativa | documento a alterar | impacto físico | dependências | categoria |
|---|---|---|---|---|---|---|---|---|
| 1 | SEC-001 V1.0 §5 | `ArquivoOrigem` | Adicionar `tenant_id` (obrigatório, candidato `MCD-F10002`); **sem** `unidade_economica_id` | Camada RAW; um arquivo pode cobrir múltiplas UEs do mesmo tenant | MCD, COT (relação 8), CDC, ADR | Nova coluna `NOT NULL` + FK | `MCD-F10002` (item 7) | CANÔNICO + SEGURANÇA OPERACIONAL |
| 2 | SEC-001 V1.0 §6 | `ConflitoDado` | Adicionar `tenant_id` (obrigatório, candidato `MCD-F10002`) | Reconciliação já opera sob tenant conhecido; referência polimórfica não pode ser mecanismo de isolamento | MCD, COT (relação 9), CDC, ADR | Nova coluna `NOT NULL` + FK | `MCD-F10002` | CANÔNICO + SEGURANÇA OPERACIONAL |
| 3 | SEC-001 V1.0 §7 | `ConflitoDadoItem` | Nenhum campo novo — item 8 | FK pai já é caminho canônico e unívoco | Documentação de estratégia em CDC/ADR | Nenhum | Item 2 (`ConflitoDado.tenant_id`) | ARQUITETURAL/FÍSICO |
| 4 | SEC-001 V1.0 §8 | `RevisaoTecnica` | Adicionar `tenant_id` (obrigatório, candidato `MCD-F10002`) | Revisão opera sob tenant conhecido; identidade do revisor é auditoria separada | MCD, COT (relação 10), CDC, ADR | Nova coluna `NOT NULL` + FK | `MCD-F10002`; identidade do revisor depende de `OBS-001` (inalterado) | CANÔNICO + SEGURANÇA OPERACIONAL |
| 5 | SEC-001 V1.0 §4 | `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal` | Adicionar `unidade_economica_id` (obrigatório) | Contexto de apuração, distinto do titular tributário PF/PJ | MCD, COT (relações 2-6), CDC, ADR | 5 novas colunas `NOT NULL` + FK | Nenhuma | CANÔNICO |
| 6 | SEC-001 V1.0 §4 | `ResultadoCalculo` | Adicionar `unidade_economica_id` (obrigatório, sem XOR — item 9) | `CenarioTributario` já identifica UE obrigatoriamente; consistência, não exclusividade | MCD, COT (relação 7), CDC, ADR | Nova coluna `NOT NULL` + FK + constraint de consistência | Nenhuma | CANÔNICO + ARQUITETURAL/FÍSICO |
| 7 | SEC-001 V1.0 §1 | `UnidadeEconomica` | Adicionar `tenant_id` (obrigatório, candidato `MCD-F10001`) | Âncora raiz de todo o modelo de isolamento | MCD, COT (relação 1), CDC, ADR | Nova coluna `NOT NULL` + FK | `MCD-F10001` (item 7) | CANÔNICO |
| 8 | SEC-CHANGE-REQUEST-001_REVISAO_V1.0 §4-5 | `ContaAcesso ↔ Tenant`, `ContaAcesso ↔ UnidadeEconomica` | Adicionar campo `papel` (aberto) a ambas as associações | Substitui `PapelAcesso`/`Permissao` sem perder capacidade de diferenciar concessões | COT (relações 11-12), MCD, CDC, DST (novo gap de vocabulário) | 2 novas colunas em 2 tabelas de associação | Novo `DST-GAP` candidato | CANÔNICO |
| 9 | SEC-CHANGE-REQUEST-001_REVISAO_V1.0 §5 | `ContaAcesso ↔ UnidadeEconomica` | Formalizar semântica de restrição (item 6) | Impedir interpretação de concessão de UE como acesso implícito a outras UEs | ADR (invariante de verificação) | Nenhuma coluna nova — regra de avaliação | Item 8 | SEGURANÇA OPERACIONAL + ARQUITETURAL/FÍSICO |

## 12. Contagens finais (substituem integralmente as da V1.0)

| Categoria | Quantidade |
|---|---|
| **Novos objetos canônicos** | **2** (`Tenant`, `EventoAuditoriaSeguranca`) |
| **Objetos em segurança operacional (não canônicos)** | **1** (`Sessao`) |
| **Objetos diferidos** | **2** (`PapelAcesso`, `Permissao`) |
| **Novas relações** | **12** |
| **Novos campos totais** | **12** — 10 confirmados pela revisão (`UnidadeEconomica.tenant_id`; `unidade_economica_id` em `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`, `ResultadoCalculo`; `tenant_id` em `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`) **+ 2 novos** (`papel` em `ContaAcesso ↔ Tenant` e em `ContaAcesso ↔ UnidadeEconomica`) |

**`12 objetos removidos/reclassificados (3) + 2 objetos canônicos + 12 relações + 12 campos`** —
nenhuma contagem da V1.0 (5 objetos, 13 relações, 10 campos) é preservada por compatibilidade
textual.

## Impacto sobre os 20 objetos atuais (atualizado)

| Tipo de impacto | Objetos | Quantidade |
|---|---|---|
| Recebem `unidade_economica_id` | `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`, `ResultadoCalculo` | 6 |
| Recebem `tenant_id` transversal (`MCD-F10002`) | `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica` | 3 |
| Recebe `tenant_id` raiz (`MCD-F10001`) | `UnidadeEconomica` | 1 |
| Sem alteração de campo | `PessoaFisica`, `PessoaJuridica`, `FontePagadora`, `Vinculo`, `VinculoExtremidade`, `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem`, `ClassificacaoEquiparacaoHospitalar`, `CenarioTributario`, `ConflitoDadoItem` | 10 |
| **Total** | | **20** |

---

## Ordem documental oficial (corrigida)

```
COT/MCD estrutural (novos objetos, campos e relações)
  → DST (vocabulário/gaps dos campos recém-criados, incluindo o novo DST-GAP de `papel`)
  → CDC (contratos — direção, obrigatoriedade, mutabilidade)
  → reconciliação (auditoria cruzada COT × MCD × CDC × DST, mesmo padrão já usado no projeto)
  → ADR (decisões físicas: tipos, FKs, FK composta/chave candidata, invariante de UE, impacto
    Prisma, RLS conceitual)
```

Substitui a ordem `COT → MCD → CDC → DST → ADR` da V1.0 — corrigida porque `DST` só pode
registrar um gap semântico depois que o campo correspondente já existe no `MCD`, e porque toda
rodada anterior deste projeto incluiu uma etapa de reconciliação cruzada antes de qualquer decisão
física.

## Baseline física

Inalterado desde `SEC-001` V1.0 §19: a migration `20260901120000_init_baseline_fisica`
permanece histórica, nunca aplicada a banco persistente. Uma nova baseline definitiva só é
produzida após os documentos canônicos estarem sincronizados (ordem acima) e o `ADR` físico
aprovado; `schema.prisma` só é alterado depois da aprovação documental completa; a validação da
nova baseline deve reutilizar o mesmo padrão de PostgreSQL descartável já usado para a V1.

---

## Verificação interna

| Verificação | Resultado |
|---|---|
| Nenhuma decisão de `SEC-CHANGE-REQUEST-001_REVISAO_V1.0.md` ficou de fora | ✓ — as 3 inconsistências da revisão (IDs distintos, ordem documental, campo `papel`) foram todas incorporadas (itens 5, 7, e Ordem documental) |
| Nenhuma nova decisão foi introduzida sem origem | ✓ — cada item cita a seção do `SEC-001 V1.0` ou do relatório de revisão que a origina |
| Nenhum ID existente foi reutilizado | ✓ — `MCD-F10001`/`MCD-F10002`, `COT-OBJ-019`/`020`, `COT-SUP-005`/`006`, `COT-REL-121..132` são candidatos em faixas livres; nenhum reaproveita `F9001..F9010` nem IDs `COT-*` já atribuídos; os dois novos IDs `MCD-F10xxx` são explicitamente distintos entre si (item 7) |
| Nenhuma implementação física ocorreu | ✓ — nenhum `schema.prisma`, `ADR-001`, migration ou banco foi tocado |
| Nenhuma migration foi alterada | ✓ — `20260901120000_init_baseline_fisica` permanece intocada |
| Nenhum gap `DST` foi artificialmente fechado | ✓ — `DST-GAP-003` (`tipo_vinculo`), `DST-GAP-014` (identidade do revisor) e o novo gap de `papel` (item 5) permanecem explicitamente abertos |
| Todas as contagens fecham | ✓ — 2 objetos canônicos + 1 segurança operacional + 2 diferidos = 5 objetos originalmente avaliados; 12 relações (13 − 1 removida); 12 campos (10 + 2); impacto nos 20 objetos soma exatamente 20 |

Nenhuma inconsistência encontrada.

**SEC-CHANGE-REQUEST-001 V1.1 PRONTO PARA APROVAÇÃO**
