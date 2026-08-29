# @contifisc/core

Reservado para o schema físico (Prisma) do Modelo Canônico de Dados.

**Sem Prisma, sem migration, sem tabela nesta Fase 1.** MCD-001 V1.1 e CDC-001 V1.1 já são a
baseline aprovada, mas o schema físico continua condicionado a uma proposta/ADR revisada antes
da primeira migration (MCD-001 V1.1 §17; CDC-001 V1.1 §17).

## Gaps bloqueantes registrados (não resolvidos por inferência)

### CDC-001 V1.1 §15 — gaps estruturais

| Gap | Descrição | Bloqueia |
|---|---|---|
| `GAP-CDC-001` | `ClassificacaoEquiparacaoHospitalar` (COT-OBJ-008) é objeto versionado, mas o MCD V1.1 não possui `id` próprio para ele. | Persistência de EqHop. |
| `GAP-CDC-002` | Associação N:N `Receita` ↔ `DocumentoFiscal` (COT-REL-007) exige estrutura explícita, ausente no MCD. | Modelo de Receita/Documento completo. |
| `GAP-CDC-003` | `ConflitoDado` (COT-OBJ-015) não possui referências estruturadas aos registros/fontes em conflito. | Reconciliação persistente completa. |
| `GAP-CDC-004` | `RevisaoTecnica` (COT-OBJ-016) não modela identidade/autorização do revisor. | Resolvido em SEC-001/OBS-001, nunca adicionando usuário à PessoaFisica. |

### DST-001 V1.1 §8 — gaps semânticos (catálogos de enum ainda não aprovados)

| Gap | Campo/conceito | MCD |
|---|---|---|
| `DST-GAP-001` | `conselho_profissional` | MCD-F1005 |
| `DST-GAP-002` | `especialidade_saude` | MCD-F1008 |
| `DST-GAP-003` | `tipo_vinculo` | MCD-F2502 |
| `DST-GAP-004` | `tipo_objeto_origem` / `tipo_objeto_destino` | MCD-F2507 / MCD-F2509 |
| `DST-GAP-005` | `papel_vinculo` | MCD-F2510 |
| `DST-GAP-006` | `fonte_receita` | MCD-F3005 |
| `DST-GAP-007` | `tipo_documento_fiscal` | MCD-F4002 |
| `DST-GAP-008` | `tipo_vinculo_previdenciario` | MCD-F6103 |
| `DST-GAP-009` | `tipo_conflito` | MCD-F8603 |
| `DST-GAP-010` | `tipo_objeto_revisado` | MCD-F8703 |

Nenhum desses gaps autoriza a criação de enum fechado ou schema físico local. Se uma
implementação futura precisar de um deles, o passo correto é registrar/aguardar o Change
Request correspondente — não inferir.

## Também pendente

- `MCD-CHANGE-REQUEST-002` (`docs/MCD-CHANGE-REQUEST-002_CONTIFISC_V1.0.md`) está com status
  `PROPOSTO PARA APROVAÇÃO` e propõe a versão `MCD-001 V1.2`. Não foi implementado nesta Fase 1.
- Autenticação (`ContaAcesso`/`CredencialAcesso`, COT-OBJ-017/018) aguarda `SEC-001`.
- Lógica tributária de qualquer domínio aguarda `RGT-001`.
