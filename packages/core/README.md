# @contifisc/core

Reservado para o schema físico (Prisma) do Modelo Canônico de Dados.

**Sem Prisma, sem migration, sem tabela nesta fase.** MCD-001 V1.2, CDC-001 V1.2 e DST-001 V1.2
já são a baseline aprovada, mas o schema físico continua bloqueado até:

1. Uma nota/versão de alinhamento do **COT-001** registrar formalmente as estruturas
   relacionais de suporte da V1.2 (`VinculoExtremidade`, `ReceitaDocumentoFiscal`,
   `DocumentoFiscalArquivoOrigem`, `ConflitoDadoItem`) — COT-001 continua V1.0.
2. Um ADR físico ser aprovado (constraints, índices, delete policy, mapping Prisma/PostgreSQL e
   estratégia para a referência genérica de auditoria de `ConflitoDadoItem`).

MCD-001 V1.1, CDC-001 V1.1 e DST-001 V1.1 são `SUPERSEDED` — preservados em `docs/legacy/`
apenas para histórico, e não orientam código novo.

## Gaps bloqueantes registrados (não resolvidos por inferência)

### DST-001 V1.2 §11 — gaps semânticos vigentes (fonte de verdade dos gaps de enum/vocabulário)

| Gap | Campo/tema | Situação |
|---|---|---|
| `DST-GAP-001` | `conselho_profissional` | Enum/Ref aberto; catálogo profissional não aprovado. |
| `DST-GAP-002` | `especialidade_saude` | Enum/Ref aberto; catálogo de especialidades não aprovado. |
| `DST-GAP-003` | `tipo_vinculo` | Catálogo fechado pendente. |
| ~~`DST-GAP-004`~~ | ~~`tipo_objeto_origem`/`tipo_objeto_destino`~~ | **RESOLVIDO na V1.2**: campos polimórficos removidos; usar `VinculoExtremidade` + FKs reais + `lado_extremidade` (DST-E012). |
| `DST-GAP-005` | `papel_vinculo` | Catálogo fechado pendente. |
| `DST-GAP-006` | `fonte_receita` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-007` | `tipo_documento_fiscal` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-008` | `tipo_vinculo_previdenciario` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-009` | `tipo_conflito` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-010` | `tipo_objeto_revisado` | Enum/Ref aberto; depende de revisão/OBS. |
| `DST-GAP-011` | `papel_arquivo` (associação DocumentoFiscal↔ArquivoOrigem) | Novo na V1.2; Enum/Ref aberto. |
| `DST-GAP-012` | `tipo_objeto` de `ConflitoDadoItem` | Novo na V1.2; Enum/Ref aberto, restrito ao domínio de auditoria. |
| `DST-GAP-013` | `papel_no_conflito` | Novo na V1.2; Enum/Ref aberto. |
| `DST-GAP-014` | Identidade/autorização do revisor de `RevisaoTecnica` | Depende de SEC-001/OBS-001; nunca modelar como `PessoaFisica` por inferência. |

Nenhum desses gaps autoriza a criação de enum fechado, union fechada, ou schema físico local.
São Enum/Ref abertos — código deve usar tipo opaco/branded ou referência validável, nunca
inventar catálogo. Se uma implementação futura precisar de um deles, o passo correto é
aguardar o Change Request/revisão DST correspondente.

### CDC-001 V1.2 §11 e MCD-001 V1.2 §23 — mapeamento para os gaps DST acima

Os gaps `GAP-CDC-001`, `GAP-CDC-002` e `GAP-CDC-003` da CDC-001 V1.1 foram **resolvidos** pelo
MCD/CDC V1.2 (identidade própria de EqHop, associação N:N Receita↔DocumentoFiscal via
`ReceitaDocumentoFiscal`, e `ConflitoDadoItem` para os participantes de um conflito).

| Gap (CDC V1.2 / MCD V1.2) | Gap DST V1.2 correspondente | Tema |
|---|---|---|
| `GAP-CDC-1.2-001` / `GAP-MCD-CR2-002` | `DST-GAP-011` | `papel_arquivo` |
| `GAP-CDC-1.2-002` / `GAP-MCD-CR2-003` | `DST-GAP-012` + `DST-GAP-013` | `tipo_objeto` e `papel_no_conflito` de `ConflitoDadoItem` (CDC/MCD tratam como um gap único; DST separa em dois termos) |
| `GAP-CDC-1.2-003` / `GAP-MCD-CR2-004` | `DST-GAP-014` | Identidade/autorização do revisor de `RevisaoTecnica` |
| `GAP-CDC-1.2-004` / `GAP-MCD-CR2-005` | *(sem gap DST correspondente — ver inconsistência observada abaixo)* | `FontePagadora.identificador_fiscal` |
| `GAP-MCD-CR2-001` | *(gap de COT, não de DST)* | `VinculoExtremidade` ainda não registrada formalmente no COT-001 |

**Inconsistência observada (registrada, não resolvida):** `GAP-CDC-1.2-004`/`GAP-MCD-CR2-005`
(tipagem de `FontePagadora.identificador_fiscal` como CPF/CNPJ/Exterior) não tem um `DST-GAP`
correspondente no DST-001 V1.2 — não é um gap de enum/vocabulário, então pode estar
corretamente fora do escopo do DST, mas nenhum documento V1.2 encerrou esse gap explicitamente.
Continua tratado como aberto até um dos documentos endereçá-lo.

## Também pendente

- `MCD-CHANGE-REQUEST-002` (`docs/MCD-CHANGE-REQUEST-002_CONTIFISC_V1.0.md`) está **APROVADO**
  e incorporado ao MCD-001 V1.2 / CDC-001 V1.2.
- Nota/versão de alinhamento do **COT-001** com as estruturas relacionais de suporte da V1.2
  (ver `GAP-MCD-CR2-001`) — ainda não solicitada/autorizada.
- Autenticação (`ContaAcesso`/`CredencialAcesso`, COT-OBJ-017/018) aguarda `SEC-001`.
- Lógica tributária de qualquer domínio aguarda `RGT-001`.
