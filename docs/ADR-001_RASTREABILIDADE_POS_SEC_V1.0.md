# ADR-001 — Rastreabilidade da Revisão Pós-SEC

**Versão:** 1.0
**Status:** RELATÓRIO CURTO — acompanha `ADR-001_CONTIFISC_Schema_Fisico_PostgreSQL_Prisma_V1.1.md`.
Não altera `schema.prisma`, migrations, banco, autenticação, RLS físico ou aplicação.

## Mapeamento SEC → CR → COT/MCD/DST/CDC → ADR-001 V1.1

| Decisão canônica | Origem | Representação física (ADR-001 V1.1) |
|---|---|---|
| `Tenant` = fronteira de isolamento, distinta de UE | `SEC-001` §1, `COT-OBJ-019`, `MCD-F10001`, `CDC-SEC-001` | `ADR-D020` — tabela `tenant`, apenas `id` |
| `UnidadeEconomica.tenant_id` (âncora raiz) | `MCD-F10002`, `COT-REL-121`, `CDC-UE-001` | `ADR-D021` — coluna `NOT NULL` + FK + `UNIQUE(id, tenant_id)` (`ADR-C011`) |
| `unidade_economica_id` transversal (6 fatos) | `MCD-F10004`, `COT-REL-122..127`, `CDC-REC/PRE/PREV/IRP/FIS/CAL-001` | `ADR-D022` — FK simples (não composta, justificada em §4) |
| `tenant_id` materializado (3 objetos) | `MCD-F10003`, `COT-REL-128..130`, `CDC-ARQ/CFD/REV-001` | `ADR-D023` — FK simples + proveniência de sessão (§8) |
| `ConflitoDadoItem` sem `tenant_id` | `SEC-001` §7, `MCD-F8651` | `ADR-D024` — reafirmação, nenhuma coluna |
| `ContaAcesso` identidade mínima | `MCD-F10007`, `CDC-SEC-005` | `ADR-D025` — tabela `conta_acesso`, apenas `id` |
| `ContaAcessoTenant` completo | `MCD-F10005/F10008/F10009/F10010`, `CDC-SEC-003` | `ADR-D026` — tabela completa + `ADR-C012` |
| `ContaAcessoUnidadeEconomica` completo + dependência estrutural | `MCD-F10005/F10008/F10011/F10012`, `CDC-SEC-004`, `CDC-REL-SEC-005/006/007` | `ADR-D027` — tabela completa + `ADR-C013`/`ADR-C014` |
| Contexto de sessão RLS (`SET LOCAL`, fail-closed) | `SEC-001` §14 | `ADR-D028`, §9.2/§9.3 |
| `EventoAuditoriaSeguranca` mínimo | `MCD-F10006`, `CDC-SEC-002` | `ADR-D029` — tabela `evento_auditoria_seguranca`, apenas `id` |
| Política de mutabilidade dividida de `MCD-F10004` | `MCD-001` V1.4 §8.1 | `ADR-D030` + §13 completo |
| Matriz de 20 tabelas do domínio tributário | `SEC-001` §11 | Preservada e estendida para 25 em §9.1 |
| Autorização por UE restringe, nunca amplia | `SEC-001` §12, `CDC-REL-SEC-001` | §9.1 item 24 + `ADR-C014` |
| Objetos globais não vazam fatos cross-tenant | `SEC-001` §3 | §10 |

## Verificação de preservação (diff automatizado contra V1.0)

| Família de ID | V1.0 | V1.1 | Resultado |
|---|---|---|---|
| `ADR-D001..019` | 19 | 19 (idênticos) + 11 novos (`D020..D030`) | Aditivo, confirmado |
| `ADR-C001..010` | 10 | 10 (idênticos) + 5 novos (`C011..C015`) | Aditivo, confirmado |
| `ADR-GAP-001..008` | 8 | 8 (idênticos) + 1 novo (`GAP-009`) | Aditivo, confirmado |
| `IDX-001..005` | 5 | 5 (idênticos) + 3 novos (`006..008`) | Aditivo, confirmado |
| `MIG-001..009` | 9 | 9 (idênticos, reproduzidos em §15.1) | Idêntico, confirmado |

**Nenhum ID removido ou renumerado. Nenhuma decisão física da V1.0 foi reaberta sem conflito
concreto com a baseline pós-SEC** — a única exceção documentada é a nota de mutabilidade de
`MCD-F10004` (§13), que não reabre nenhuma decisão física já validada por PoC (`ADR-C001..C010`
permanecem intocadas).

## Achado que exige nova PoC antes de migration

`ADR-C014` (dependência estrutural `ContaAcessoUnidadeEconomica` → `ContaAcessoTenant`) é a única
constraint desta revisão sem precedente direto — requer PoC própria em PostgreSQL descartável,
seguindo a metodologia já validada para `ADR-C005`, antes de qualquer migration que inclua
`conta_acesso_unidade_economica`.

## Conclusão

`ADR-001` V1.1 é estritamente aditivo sobre a V1.0 na dimensão de IDs; a única política física
corrigida (mutabilidade de `MCD-F10004` em `resultado_calculo`) decorre diretamente da correção já
aprovada em `MCD-001`/`CDC-001` V1.4, não de uma reabertura independente. Nenhum `schema.prisma`,
migration, RLS, autenticação ou banco foi alterado por este relatório ou pela revisão do ADR.
