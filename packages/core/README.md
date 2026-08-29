# @contifisc/core

Reservado para o schema físico (Prisma) do Modelo Canônico de Dados.

**Sem Prisma, sem migration, sem tabela nesta fase.** MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2
e COT-001 V1.1 já são a baseline aprovada, mas o schema físico continua bloqueado até um **ADR
físico** ser aprovado (constraints, índices, delete policy, mapping Prisma/PostgreSQL e
estratégia para a referência genérica de auditoria de `ConflitoDadoItem`).

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

## Também pendente

- `MCD-CHANGE-REQUEST-002` (`docs/MCD-CHANGE-REQUEST-002_CONTIFISC_V1.0.md`) está **APROVADO**
  e incorporado ao MCD-001 V1.2 / CDC-001 V1.2.
- Autenticação (`ContaAcesso`/`CredencialAcesso`, COT-OBJ-017/018) aguarda `SEC-001`.
- Lógica tributária de qualquer domínio aguarda `RGT-001`.
- `rule_set_id`/`rule_set_version`/`regra_versao_id` permanecem identificadores opacos até `RGT-001`.
