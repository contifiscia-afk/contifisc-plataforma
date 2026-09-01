# @contifisc/core

Reservado para o schema físico (Prisma) do Modelo Canônico de Dados.

**Prisma schema canônico existente; migration ainda controlada por gate de revisão.**
`prisma/schema.prisma` (v3, com a Errata controlada nº2 do ADR-001 incorporada) é a baseline
física vigente para a próxima etapa. MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2, COT-001 V1.1 e
`docs/ADR-001_CONTIFISC_Schema_Fisico_PostgreSQL_Prisma_V1.0.md` (com todas as erratas vigentes)
continuam a baseline aprovada. A primeira migration canônica foi gerada como artefato de revisão
(`prisma/migrations/`) — **nenhuma migration foi ou será aplicada a nenhum banco sem autorização
explícita** posterior. Ver revisão técnica na seção abaixo.

MCD-001 V1.1, CDC-001 V1.1, DST-001 V1.1 e COT-001 V1.0 são `SUPERSEDED` — preservados em
`docs/legacy/` apenas para histórico, e não orientam código novo.

## Gaps bloqueantes registrados (não resolvidos por inferência)

### DST-001 V1.2 §11 — gaps semânticos vigentes (fonte de verdade dos gaps de enum/vocabulário)

| Gap | Campo/tema | Situação |
|---|---|---|
| `DST-GAP-001` | `conselho_profissional` | Enum/Ref aberto; catálogo profissional não aprovado. |
| `DST-GAP-002` | `especialidade_saude` | Enum/Ref aberto; catálogo de especialidades não aprovado. |
| `DST-GAP-003` | `tipo_vinculo` | Catálogo fechado pendente. |
| ~~`DST-GAP-004`~~ | ~~`tipo_objeto_origem`/`tipo_objeto_destino`~~ | **RESOLVIDO na V1.2**: campos polimórficos removidos; usar `VinculoExtremidade` (`COT-SUP-001`) + FKs reais + `lado_extremidade` (DST-E012). |
| `DST-GAP-005` | `papel_vinculo` | Catálogo fechado pendente. |
| `DST-GAP-006` | `fonte_receita` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-007` | `tipo_documento_fiscal` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-008` | `tipo_vinculo_previdenciario` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-009` | `tipo_conflito` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-010` | `tipo_objeto_revisado` | Enum/Ref aberto; depende de revisão/OBS. |
| `DST-GAP-011` | `papel_arquivo` (associação DocumentoFiscal↔ArquivoOrigem, `COT-SUP-003`) | Enum/Ref aberto. |
| `DST-GAP-012` | `tipo_objeto` de `ConflitoDadoItem` (`COT-SUP-004`) | Enum/Ref aberto, restrito ao domínio de auditoria. |
| `DST-GAP-013` | `papel_no_conflito` (`COT-SUP-004`) | Enum/Ref aberto. |
| `DST-GAP-014` | Identidade/autorização do revisor de `RevisaoTecnica` | Depende de SEC-001/OBS-001; nunca modelar como `PessoaFisica` por inferência. |

Nenhum desses gaps autoriza a criação de enum fechado, union fechada, ou schema físico local.
São Enum/Ref abertos — código deve usar tipo opaco/branded ou referência validável, nunca
inventar catálogo. Se uma implementação futura precisar de um deles, o passo correto é
aguardar o Change Request/revisão DST correspondente.

### CDC-001 V1.2 §11, MCD-001 V1.2 §23 e COT-001 V1.1 §15 — mapeamento cruzado

Os gaps `GAP-CDC-001`, `GAP-CDC-002` e `GAP-CDC-003` da CDC-001 V1.1 foram **resolvidos** pelo
MCD/CDC V1.2 (identidade própria de EqHop, associação N:N Receita↔DocumentoFiscal via
`ReceitaDocumentoFiscal`, e `ConflitoDadoItem` para os participantes de um conflito).

| Gap (CDC V1.2 / MCD V1.2) | Gap DST V1.2 correspondente | Tema |
|---|---|---|
| `GAP-CDC-1.2-001` / `GAP-MCD-CR2-002` | `DST-GAP-011` | `papel_arquivo` |
| `GAP-CDC-1.2-002` / `GAP-MCD-CR2-003` | `DST-GAP-012` + `DST-GAP-013` | `tipo_objeto` e `papel_no_conflito` de `ConflitoDadoItem` (CDC/MCD/COT tratam como um gap único; DST separa em dois termos — diferença de granularidade, não contradição) |
| `GAP-CDC-1.2-003` / `GAP-MCD-CR2-004` | `DST-GAP-014` | Identidade/autorização do revisor de `RevisaoTecnica` |
| `GAP-CDC-1.2-004` / `GAP-MCD-CR2-005` | *(sem gap DST — ver nota abaixo)* | `FontePagadora.identificador_fiscal` |
| ~~`GAP-MCD-CR2-001`~~ | — | **RESOLVIDO por COT-001 V1.1**: `VinculoExtremidade` agora está formalmente registrada como `COT-SUP-001`. |

**Nota sobre `GAP-CDC-1.2-004`/`GAP-MCD-CR2-005`:** COT-001 V1.1 §15 esclarece explicitamente
que este gap é "de modelagem/validação MCD/CDC" e "não é promovido artificialmente a gap
semântico DST" — ou seja, a ausência de `DST-GAP` correspondente é intencional (não é um gap de
enum/vocabulário), não uma omissão. Continua aberto, apenas fora do escopo do DST por desenho.

## Revisão técnica do ADR-001 (status APROVADO para PoC) — incompatibilidades Prisma/PostgreSQL

Revisão contra o repositório atual (nenhum código de persistência existe ainda — apenas
`packages/types` com `Uuid`/`Money`/`Competencia` como Value Objects) e contra a baseline
canônica. Nenhuma correção foi aplicada ao ADR pela primeira revisão; os dois achados
**RELEVANTE** dessa primeira rodada foram corrigidos por errata do próprio ADR-001 (ver
`docs/ADR-001_..._V1.0.md`, nota de errata próxima ao cabeçalho) e a segunda rodada de auditoria
abaixo os reavalia já corrigidos.

### Confirmado como tecnicamente correto (sem incompatibilidade)
- `CHECK` (XOR de Receita/VinculoExtremidade, formato de `competencia`) **não é representável**
  no `schema.prisma` — Prisma não tem sintaxe declarativa para `CHECK`; precisa mesmo ser SQL
  manual na migration, como o ADR §6 já assume corretamente.
- **Constraint trigger `DEFERRABLE INITIALLY DEFERRED`** (ADR-C005/§5.1) é sintaxe PostgreSQL
  válida e Prisma não tem equivalente declarativo — precisa ser SQL manual, como já previsto.
  Confirmado que uma transação Prisma (`$transaction`, array ou interativa) mapeia para uma
  única transação Postgres, então inserir `Vinculo` + as duas `VinculoExtremidade` na mesma
  transação e deixar o trigger validar no commit é uma estratégia tecnicamente viável.
- **Índice parcial** (`WHERE` em índice) também não é representável no `schema.prisma` — precisa
  de SQL manual, como o ADR já assume.
- Evitar `enum` nativo do Postgres para vocabulário aberto/em evolução (ADR-D010) é a decisão
  correta: alterar um `enum` nativo via Prisma exige `ALTER TYPE ... ADD VALUE`, historicamente
  problemático dentro da mesma transação que já usa o novo valor — relevante para os enums
  governados pelo DST que ainda vão crescer (`DST-GAP-*`).
- `Money`/`Competencia` já implementados em `packages/types` são consistentes com `NUMERIC(18,2)`
  (escala de 2 casas) e com `competencia` como string opaca `YYYY-MM` (não `Date`).

### Segunda rodada de auditoria (pós-errata) — checklist específico

| Item | Situação |
|---|---|
| `relationMode` | **Corrigido.** `ADR-D013` fixa `foreignKeys`, proíbe `"prisma"`, exige novo ADR/revisão formal para mudar, e exige verificação explícita na revisão futura do `schema.prisma` (§6 regra operacional + MIG-009). |
| Tipos UUID | Consistente. `ADR-D004`/`D005` (PK/FK `uuid`) batem com MCD-001 V1.2 (`ids: uuid`) e com os campos `*_id` de `VinculoExtremidade` (MCD-F2523..525). |
| `NUMERIC(18,2)` | Consistente. `ADR-D006` inalterado; bate com MCD-001 V1.2 §5 e com `Money` já implementado em `packages/types`. |
| `NUMERIC(7,4)` | **Corrigido.** `ADR-D007` agora materializa `NUMERIC(7,4)` diretamente, citando MCD-001 V1.2 §5; não reabre a escala. |
| `VARCHAR(7)` + CHECK competência | **Corrigido.** `ADR-D008` e §4 agora usam exclusivamente `VARCHAR(7)`; `CHAR(7)` removido de toda decisão vigente (permanece só na nota de errata, como registro do que foi corrigido). CHECK de formato/mês continua obrigatório (`ADR-C009`). |
| `TIMESTAMPTZ` | Consistente. `ADR-D009` inalterado; bate com MCD-001 V1.2 (Timestamp TZ → TIMESTAMPTZ). |
| XOR de Receita | Consistente. `ADR-C001` bate com `CDC-REL-XOR-001` (CDC-001 V1.2 §7) e com a constraint do MCD-001 V1.2 §12. |
| XOR de `VinculoExtremidade` | Consistente. `ADR-C002` bate com `CDC-REL-XOR-002`. |
| Constraint diferida de exatamente duas extremidades | Consistente com `COT-REL-NORM-001` (COT-001 V1.1) e `CDC-REL-CARD-001`. **EDITORIAL corrigido:** `ADR-C005` e §5.1 agora citam `COT-REL-NORM-001` explicitamente pelo ID. |
| N:N (`ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem`) | Consistente. `ADR-C006`/`C007` e a tabela de mapeamento (§3) batem com `COT-SUP-002`/`003` e `CDC-FIS-002`/`003`. |
| Delete policies | Consistente. A política conservadora do ADR §8 (RESTRICT/NO ACTION para fatos/evidência, cascade só na linha associativa) é exatamente o que o MCD-001 V1.2 §12 delegou ao ADR ("política de deleção será definida no ADR"). |
| Enum/Ref abertos | Consistente. `ADR-D010` e `ADR-GAP-002/003` continuam sem fechar `papel_arquivo`/`tipo_objeto`/`papel_no_conflito` (`DST-GAP-011/012/013`); nenhum enum foi inventado pela errata. |
| Gaps deliberadamente não resolvidos | `ADR-GAP-001..006` inalterados. **Errata controlada nº2 (2026-08-31)** acrescentou `ADR-GAP-007` (MCD-F9009 em `receita`/`contribuicao_previdenciaria`/`evento_irpf`, sem FK por inferência) e `ADR-GAP-008` (MCD-F9007 não confirmado equivalente a `resultado_calculo.calculado_em`/`revisao_tecnica.revisado_em`) — ver `docs/ADR-001_..._V1.0.md` §2/§14. |

**Achados remanescentes:**

| Severidade | Achado |
|---|---|
| **OBSERVAÇÃO** (herdada, ainda válida) | Nenhum código do repositório declara dependência de Prisma ainda; a interoperabilidade do client Prisma (CJS) com `"type": "module"` em `packages/core` deve ser validada na PoC, não presumida. |
| **RELEVANTE** (Errata controlada nº2, registrado como `ADR-GAP-008`, não resolvido por inferência) | A verificação semântica de MCD-F9007 (`registrado_em`) não confirmou equivalência entre `resultado_calculo.calculado_em`/`revisao_tecnica.revisado_em` e o campo transversal `registrado_em` — o MCD-001 V1.2 define os três com textos distintos ("momento do cálculo"/"momento da revisão" vs. "momento do registro canônico"), sem afirmar que são a mesma ocorrência temporal. |
| **CRÍTICO corrigido nesta mesma rodada** (achado da própria auditoria de fechamento da Errata nº2) | Uma redação preliminar do achado acima e de `ADR-GAP-008` citava um "envelope de evento `occurred_at`/`recorded_at`" como se fosse da `CDC-001 V1.2 §11` — mas esse envelope só existe na `CDC-001 V1.0`/`V1.1`, ambas `SUPERSEDED` (§11 da V1.2 vigente é "Lacunas residuais após V1.2", sem esse conteúdo). Corrigido no próprio `docs/ADR-001_..._V1.0.md` e aqui antes da conclusão da errata, para não citar documento superado como fundamento de decisão vigente. |

O achado EDITORIAL da rodada anterior (referência a `COT-REL-NORM-001`) foi corrigido no próprio
ADR-001 antes da aprovação. **Nenhuma inconsistência CRÍTICA remanescente** entre COT-001 V1.1 ×
MCD-001 V1.2 × CDC-001 V1.2 × DST-001 V1.2 × ADR-001 (aprovado, com Errata controlada nº2
incorporada); a única pendência RELEVANTE é a acima, explicitamente registrada como `ADR-GAP-008`
e não resolvida por inferência.

## Também pendente

- `MCD-CHANGE-REQUEST-002` (`docs/MCD-CHANGE-REQUEST-002_CONTIFISC_V1.0.md`) está **APROVADO**
  e incorporado ao MCD-001 V1.2 / CDC-001 V1.2.
- Autenticação (`ContaAcesso`/`CredencialAcesso`, COT-OBJ-017/018) aguarda `SEC-001`.
- Lógica tributária de qualquer domínio aguarda `RGT-001`.
- `rule_set_id`/`rule_set_version`/`regra_versao_id` permanecem identificadores opacos até `RGT-001`.
