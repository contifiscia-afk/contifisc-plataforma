# Rastreabilidade `SEC-CHANGE-REQUEST-001` V1.1 → DST-001 V1.3

**Status:** RELATÓRIO CURTO — acompanha a atualização do DST. Não altera
COT/MCD/CDC/ADR/Prisma/migrations/banco.

| Conceito exigido | Incorporado em | ID(s) atribuído(s) |
|---|---|---|
| `Tenant` (semântica) | DST-001 V1.3 §3, §11 | `DST-T031` |
| `EventoAuditoriaSeguranca` (semântica) | DST-001 V1.3 §3, §11 | `DST-T032` |
| `tenant_id` como contexto/fronteira de segurança | DST-001 V1.3 §2, §11 | `DST-T033` |
| Distinção `tenant_id` × `unidade_economica_id` | DST-001 V1.3 §2, §11 (bullets dedicados) | `DST-T033` × `DST-T034` |
| Identidade tributária × identidade de acesso | DST-001 V1.3 §2, §11 (reafirmação) | `DST-T002`/`T003` × `DST-T021` (termos já vigentes, sem alteração) |
| `ContaAcesso ↔ Tenant` | DST-001 V1.3 §3, §11 | `DST-T036` |
| `ContaAcesso ↔ UnidadeEconomica` (restrição) | DST-001 V1.3 §3, §11 | `DST-T037` |
| Semântica aberta de `papel` | DST-001 V1.3 §3, §11 | `DST-T035`; vocabulário registrado como `DST-GAP-015` (não fechado, nenhum enum criado) |
| `unidade_economica_id` transversal (`MCD-F10004`) | DST-001 V1.3 §11 | `DST-T034` |
| Verificação semântica de `MCD-F10004` | DST-001 V1.3 §11.1 | Resultado: **uniforme**, sem inconsistência — nota não-bloqueante sobre timing de atribuição registrada |
| `Sessao` — não canônico | DST-001 V1.3 §1, §11, §15 | Confirmado `SEGURANCA_OPERACIONAL`, nenhum termo/ID criado |
| `PapelAcesso`/`Permissao` — não canônicos | DST-001 V1.3 §1, §11, §15 | Confirmado `DIFERIDO`, nenhum termo/ID criado |

## Verificação final

| Verificação | Resultado |
|---|---|
| Todos os novos conceitos canônicos COT/MCD possuem definição semântica ou gap explícito | ✓ — `Tenant`, `EventoAuditoriaSeguranca`, `tenant_id` (raiz e transversal), `unidade_economica_id` transversal, `papel`, `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica` — todos com termo DST próprio; `papel` adicionalmente com gap explícito |
| Nenhum gap antigo foi fechado sem base normativa | ✓ — `DST-GAP-001..014` reproduzidos sem alteração (confirmado por diff automatizado); apenas `DST-GAP-015` foi adicionado |
| Nenhum enum foi inventado | ✓ — `DST-E001..012` reproduzidos sem alteração nem adição (confirmado por diff automatizado); `papel` é Enum/Ref aberto, não enum fechado |
| Nenhum conceito operacional foi promovido indevidamente a canônico | ✓ — `Sessao` permanece `SEGURANCA_OPERACIONAL`; `PapelAcesso`/`Permissao` permanecem `DIFERIDO`; nenhum dos três recebeu termo `DST-T` |
| `tenant_id` não foi confundido com UE | ✓ — `DST-T033` (segurança) e `DST-T034` (econômico/tributário) são termos distintos, com bullets explícitos de não-equivalência em §2 e §11 |
| `papel` permanece vocabulário aberto | ✓ — `DST-GAP-015`, nenhum código fechado listado |
| `MCD-F10004` possui semântica uniforme ou divergência reportada | ✓ — verificado uniforme nos 6 hospedeiros (§11.1); nota de timing registrada como não-bloqueante, não como inconsistência |

**Preservação da V1.2:** confirmado por diff automatizado — os 30 termos (`DST-T001..030`), os 12
enums (`DST-E001..012`, incluindo todos os valores de código) e os 14 gaps (`DST-GAP-001..014`)
da V1.2 permanecem idênticos na V1.3, sem nenhuma remoção ou alteração. A V1.3 é estritamente
aditiva: +7 termos (`DST-T031..037`), +1 gap (`DST-GAP-015`), +0 enums.

Nenhuma inconsistência encontrada.

**DST PÓS-SEC SINCRONIZADO — PRONTO PARA REVISÃO**
