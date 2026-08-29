# @contifisc/core

Reservado para o schema físico (Prisma) do Modelo Canônico de Dados.

**Sem Prisma, sem migration, sem tabela nesta fase.** MCD-001 V1.2 e CDC-001 V1.2 já são a
baseline aprovada, mas o schema físico continua bloqueado até:

1. `DST-001 V1.2` ser publicado (próximo bloqueio documental — ainda não existe; DST-001 V1.1
   segue vigente semanticamente até lá).
2. Um ADR físico ser aprovado (constraints, índices, delete policy, mapping Prisma/PostgreSQL e
   estratégia para a referência genérica de auditoria de `ConflitoDadoItem`).

MCD-001 V1.1 e CDC-001 V1.1 são `SUPERSEDED` — preservados em `docs/legacy/` apenas para
histórico, e não orientam código novo.

## Gaps bloqueantes registrados (não resolvidos por inferência)

### CDC-001 V1.2 §11 — gaps estruturais remanescentes

Os gaps `GAP-CDC-001`, `GAP-CDC-002` e `GAP-CDC-003` da CDC-001 V1.1 foram **resolvidos** pelo
MCD/CDC V1.2 (identidade própria de EqHop, associação N:N Receita↔DocumentoFiscal via
`ReceitaDocumentoFiscal`, e `ConflitoDadoItem` para os participantes de um conflito). O antigo
`GAP-CDC-004` foi absorvido pelo `GAP-CDC-1.2-003` abaixo.

| Gap | Tema | Tratamento |
|---|---|---|
| `GAP-CDC-1.2-001` | `papel_arquivo` (associação DocumentoFiscal↔ArquivoOrigem) | Catálogo DST pendente; não criar enum fechado. |
| `GAP-CDC-1.2-002` | `tipo_objeto` / `papel_no_conflito` (ConflitoDadoItem) | Catálogos dependem de OBS/reconciliação. |
| `GAP-CDC-1.2-003` | Identidade/autorização do revisor de `RevisaoTecnica` | Aguardar SEC-001/OBS-001; nunca adicionar usuário a `PessoaFisica`. |
| `GAP-CDC-1.2-004` | `FontePagadora.identificador_fiscal` | Tipagem CPF/CNPJ/Exterior ainda aberta. |
| `GAP-CDC-1.2-005` | Demais gaps DST | Continuam bloqueados até publicação de catálogo. |

### MCD-001 V1.2 §23 — gaps remanescentes do próprio MCD

| Gap | Tema | Tratamento |
|---|---|---|
| `GAP-MCD-CR2-001` | `VinculoExtremidade` ainda não registrada formalmente no COT | COT deve incorporar a estrutura relacional de suporte. |
| `GAP-MCD-CR2-002` | `DocumentoFiscalArquivoOrigem.papel_arquivo` | Mesmo gap de `GAP-CDC-1.2-001`; catálogo DST pendente. |
| `GAP-MCD-CR2-003` | `ConflitoDadoItem.tipo_objeto`/`papel_no_conflito` | Mesmo gap de `GAP-CDC-1.2-002`. |
| `GAP-MCD-CR2-004` | Revisor de `RevisaoTecnica` | Mesmo gap de `GAP-CDC-1.2-003`; aguarda SEC-001/OBS-001. |
| `GAP-MCD-CR2-005` | `FontePagadora.identificador_fiscal` | Mesmo gap de `GAP-CDC-1.2-004`. |

### DST-001 V1.1 §8 — gaps semânticos (catálogos de enum ainda não aprovados)

Ainda vigentes — DST-001 continua na V1.1; a V1.2 (quando publicada) é o próximo documento
esperado para revisar esta lista.

| Gap | Campo/conceito | MCD |
|---|---|---|
| `DST-GAP-001` | `conselho_profissional` | MCD-F1005 |
| `DST-GAP-002` | `especialidade_saude` | MCD-F1008 |
| `DST-GAP-003` | `tipo_vinculo` | MCD-F2502 |
| `DST-GAP-004` | `tipo_objeto_origem` / `tipo_objeto_destino` (V1.1) — substituído por `lado_extremidade`/endpoints XOR na V1.2 | MCD-F2507/F2509 (V1.1) → MCD-F2520..F2525 (V1.2) |
| `DST-GAP-005` | `papel_vinculo` | MCD-F2510 |
| `DST-GAP-006` | `fonte_receita` | MCD-F3005 |
| `DST-GAP-007` | `tipo_documento_fiscal` | MCD-F4002 |
| `DST-GAP-008` | `tipo_vinculo_previdenciario` | MCD-F6103 |
| `DST-GAP-009` | `tipo_conflito` | MCD-F8603 |
| `DST-GAP-010` | `tipo_objeto_revisado` | MCD-F8703 |

Nenhum desses gaps autoriza a criação de enum fechado ou schema físico local. Se uma
implementação futura precisar de um deles, o passo correto é registrar/aguardar o Change
Request ou a revisão DST correspondente — não inferir.

## Também pendente

- `MCD-CHANGE-REQUEST-002` (`docs/MCD-CHANGE-REQUEST-002_CONTIFISC_V1.0.md`) está **APROVADO**
  e incorporado ao MCD-001 V1.2 / CDC-001 V1.2.
- Autenticação (`ContaAcesso`/`CredencialAcesso`, COT-OBJ-017/018) aguarda `SEC-001`.
- Lógica tributária de qualquer domínio aguarda `RGT-001`.
