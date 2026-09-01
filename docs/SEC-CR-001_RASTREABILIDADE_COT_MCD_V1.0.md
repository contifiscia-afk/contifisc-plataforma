# Rastreabilidade `SEC-CHANGE-REQUEST-001` V1.1 → COT-001 V1.2 / MCD-001 V1.3

**Status:** RELATÓRIO CURTO — acompanha a incorporação documental do CR aprovado. Não altera
DST/CDC/ADR/Prisma/migrations/banco.

| Item do CR V1.1 | Incorporado em | ID(s) atribuído(s) |
|---|---|---|
| 1. `Tenant` (novo objeto) | COT-001 V1.2 §3 | `COT-OBJ-019` |
| 2. `EventoAuditoriaSeguranca` (novo objeto) | COT-001 V1.2 §3, nova classe taxonômica "Security Audit" §2 | `COT-OBJ-020` |
| `Sessao` (não incorporado como objeto) | COT-001 V1.2 §13, §15 — registrado como `SEGURANCA_OPERACIONAL` | — |
| `PapelAcesso`/`Permissao` (não incorporados como objetos) | COT-001 V1.2 §13, §15 — registrados como `DIFERIDO` | — |
| 3-4. `UnidadeEconomica → Tenant` | COT-001 V1.2 §5; MCD-001 V1.3 §8/§11 | `COT-REL-121`; `MCD-F10002` |
| `Receita/ContribuicaoPrevidenciaria/VinculoPrevidenciario/EventoIRPF/DocumentoFiscal/ResultadoCalculo → UnidadeEconomica` | COT-001 V1.2 §5; MCD-001 V1.3 §8/§11 | `COT-REL-122..127`; `MCD-F10004` (transversal, 1 ID para os 6) |
| `ArquivoOrigem/ConflitoDado/RevisaoTecnica → Tenant` | COT-001 V1.2 §5; MCD-001 V1.3 §8/§11 | `COT-REL-128..130`; `MCD-F10003` (transversal, 1 ID para os 3) |
| `ContaAcesso ↔ Tenant` | COT-001 V1.2 §4/§5 | `COT-SUP-005`; `COT-REL-131` |
| `ContaAcesso ↔ UnidadeEconomica` | COT-001 V1.2 §4/§5 | `COT-SUP-006`; `COT-REL-132` |
| 5. Campo `papel` (substitui `PapelAcesso`/`Permissao`) | COT-001 V1.2 §4.1; MCD-001 V1.3 §8/§10.1 | `MCD-F10005` |
| Registro do gap DST de `papel` | COT-001 V1.2 §15 (`GAP` textual); MCD-001 V1.3 §23 | `GAP-SEC-CR1-001` — **DST não alterado nesta etapa**, apenas o gap registrado nos dois documentos que o antecedem |
| 6. Semântica de restrição por UE (restringe, nunca amplia/substitui) | COT-001 V1.2 §4.1, §8; MCD-001 V1.3 §12 | Invariante textual, sem ID próprio |
| 7. IDs de `tenant_id` — raiz × transversal | MCD-001 V1.3 §8 (nota explicativa dedicada) | `MCD-F10002` (raiz) ≠ `MCD-F10003` (transversal) |
| 8. `ConflitoDadoItem` sem `tenant_id` | COT-001 V1.2 §5 (nota sob a tabela de relações); MCD-001 V1.3 §11 | Sem novo ID — deriva de `COT-REL-116`/`MCD-F8651` já vigentes |
| 9. `ResultadoCalculo` sem XOR | COT-001 V1.2 §3 (linha do objeto); MCD-001 V1.3 §3, §12 | `MCD-F10004` aplicado a `ResultadoCalculo`, sem constraint XOR |
| 10. Estrutura para futura FK composta / chave candidata | COT-001 V1.2 §8; MCD-001 V1.3 §12 | Registrado como pendência do ADR — nenhuma constraint criada |
| 11. Ordem documental `COT/MCD → DST → CDC → reconciliação → ADR` | COT-001 V1.2 §18; MCD-001 V1.3 §19, §25 | — |
| 12. Contagens (2 objetos, 12 relações, 12 campos aprovados) | COT-001 V1.2 §17; MCD-001 V1.3 §24 | Ver reconciliação de contagens abaixo |

## Reconciliação de contagens (CR aprovado × MCD/COT incorporados)

O CR aprovou **12 campos físicos** (ocorrências objeto+campo) e **12 relações**. Na incorporação
ao MCD, campos com significado idêntico em múltiplos objetos (mesmo padrão já usado para
`MCD-F9001..F9010`) foram consolidados em **IDs MCD transversais únicos** — isso não representa
nenhuma redução de escopo, apenas a forma correta de atribuir ID canônico:

| Ocorrências físicas aprovadas pelo CR | IDs MCD atribuídos | Objetos hospedeiros |
|---|---|---|
| 1× `UnidadeEconomica.tenant_id` | `MCD-F10002` | 1 |
| 6× `unidade_economica_id` (Receita, ContribuicaoPrevidenciaria, VinculoPrevidenciario, EventoIRPF, DocumentoFiscal, ResultadoCalculo) | `MCD-F10004` | 6 |
| 3× `tenant_id` transversal (ArquivoOrigem, ConflitoDado, RevisaoTecnica) | `MCD-F10003` | 3 |
| 2× `papel` (ContaAcessoTenant, ContaAcessoUnidadeEconomica) | `MCD-F10005` | 2 |
| **12 ocorrências físicas** | **4 IDs MCD transversais** | **12 objetos/associações** |

Adicionalmente, os dois novos objetos canônicos (item 1-2 do CR, não contados nos "12 campos")
receberam seus campos de identidade mínimos: `MCD-F10001` (`Tenant.id`) e `MCD-F10006`
(`EventoAuditoriaSeguranca.id`). **Total: 6 novos IDs MCD (`F10001..F10006`), aplicados a 14
ocorrências físicas (12 aprovadas pelo CR + 2 campos de identidade dos novos objetos).** Catálogo
MCD sobe de 139 para **145 campos canônicos**. Catálogo COT sobe de 18 para **20 objetos** e de 4
para **6 estruturas de suporte**; relações sobem de 20 (`COT-REL-101..120`) para **32**
(`COT-REL-101..132`, 12 novas).

## Verificação final

| Verificação | Resultado |
|---|---|
| Todas as mudanças CANÔNICAS do CR foram incorporadas | ✓ — os 2 objetos, 12 relações, 12 campos (consolidados em 6 IDs transversais) e a semântica de restrição por UE estão presentes em COT-001 V1.2 e MCD-001 V1.3 |
| Nenhuma decisão física foi antecipada | ✓ — FK composta, chave candidata, RLS e triggers permanecem registrados como pendência do ADR, não implementados |
| Nenhum gap DST foi artificialmente resolvido | ✓ — `papel` permanece Enum/Ref aberto (`GAP-SEC-CR1-001`); `DST-GAP-003`, `DST-GAP-014` inalterados; nenhum enum criado |
| Nenhuma relação antiga foi quebrada sem justificativa | ✓ — as 18 objetos, 4 estruturas e 20 relações da V1.1/V1.2 anteriores foram preservados integralmente, verificado por contagem (`COT-OBJ-001..018`, `COT-SUP-001..004`, `COT-REL-101..120`, `MCD-F0001..F9010` todos presentes sem alteração) |
| Nenhuma alteração fora do CR foi introduzida | ✓ — nenhum campo além dos explicitamente listados no CR foi adicionado a `Tenant`/`EventoAuditoriaSeguranca` (apenas o `id` mínimo, necessário para as FKs aprovadas existirem); `ContaAcesso`/`CredencialAcesso` não tiveram nenhum campo novo adicionado |

Nenhuma inconsistência encontrada.

**COT/MCD PÓS-SEC SINCRONIZADOS — PRONTOS PARA REVISÃO**
