# RLS_PRE_NEON_REVIEW_REPORT — Revisão final pré-Neon

**Status:** REVISÃO CONCLUÍDA. Migration RLS continua `DRAFT`, não renomeada, não aplicada. Neon
DEV **sem nenhuma alteração persistente** — confirmado antes e depois (§6). Nenhuma autenticação
implementada. Nenhum commit/push.

## 1. Revisão integral do diff

Todos os artefatos RLS revisados nesta passagem:

| Arquivo | Consistência com o SQL corrigido que passou nos testes |
|---|---|
| Migration RLS DRAFT (`.../20260917130000_rls_tenant_isolation_DRAFT/migration.sql`) | ✓ — checksum `a82e3c08...255f9` (§8), idêntico ao validado na 2ª execução do `RLS_POC_CORRECTION_REPORT.md`; nenhuma edição desde então |
| `RLS-001_CONTIFISC_Row_Level_Security_V1.0.md` | ✓ — atualizado com seções "Atualização pós-PoC" referenciando C1/C2/C3 e gate corrigido |
| `SECURITY_CONTEXT_CONTRACT.md` | ✓ — descreve as 2 variáveis de sessão e a policy definitiva de `tenant`; consistente com a versão via função de mediação (o texto já previa "função" como mecanismo, a PoC apenas confirmou a necessidade de `SECURITY DEFINER`+`BYPASSRLS` especificamente) |
| `RLS_MATRIX.md` | ✓ — linhas 5/6 (`vinculo`/`vinculo_extremidade`) e 21 (`tenant`) atualizadas para refletir as funções de mediação e a separação de policies por comando |
| `RLS_DESIGN_REVIEW.md` | ✓ — seção 5.1 adicionada, referenciando a correção sem apagar os achados originais |
| `RLS_TEST_PLAN.md` | ✓ — T26-T28/T32-T47 continuam válidos como especificação; execução real documentada nos relatórios de PoC, não neste arquivo |
| `RLS_POC_REPORT.md` | ✓ — **preservado integralmente**, incluindo a evidência original de C1/C2 (erros de recursão e acoplamento) — nada apagado ou reescrito |
| `RLS_POC_CORRECTION_REPORT.md` | ✓ — documenta causa raiz, correção e revalidação de C1/C2/C3 |
| Scripts PoC (`01_fixture.sql`...`06_t22_neon_pooled_test.mjs`) | ✓ — todos presentes, `06_*` novo nesta revisão (§4) |

**Conclusão da revisão de diff:** a documentação final representa exatamente o SQL que passou nos
testes — nenhuma divergência entre o que está descrito e o que está no arquivo `migration.sql`
encontrada.

## 2. `SECURITY DEFINER`/`contifisc_rls_mediator` — formalização

Registrado formalmente em **`docs/ADR-002_CONTIFISC_RLS_Contexto_Transacional_Mediacao_SECURITY_DEFINER_DRAFT_V1.0.md`**
(novo, `DRAFT`, não aprovado — decisão explícita de não alterar `ADR-001` V1.1 silenciosamente).
Resumo das 3 decisões físicas novas (`ADR-D031`/`D032`/`D033`, detalhamento completo no ADR):

- `contifisc_rls_mediator`: `NOSUPERUSER`/`NOLOGIN`/`BYPASSRLS`, owner exclusivo das 2 funções,
  nunca runtime/migration/provisioning, sem credencial, privilégio mínimo (`SELECT` apenas nas 3
  tabelas necessárias).
- 2 funções `SECURITY DEFINER`, retorno `boolean`, sem SQL dinâmico, `search_path` fixo, objetos
  schema-qualificados, `PUBLIC` sem `EXECUTE`, `NULL`/inválido/inexistente → `false` por construção.
- Escopo estritamente mínimo: apenas as 2 consultas que precisam mediar acesso a outra tabela com
  RLS própria — as 22 demais tabelas da matriz não usam nem precisam deste mecanismo.

## 3. C3 — formalização

Registrado em `ADR-D033` (ADR-002) e em `RLS_MATRIX.md` linhas 5/6: `vinculo`/`vinculo_extremidade`
passam de 1 policy `FOR ALL` para 4 policies por comando cada. `INSERT` tem regra estrutural
distinta (permissiva para `vinculo`, checagem direta não-circular para `vinculo_extremidade`) —
justificado em detalhe no ADR-002 §1, tabela `ADR-D033`, incluindo por que isso não reduz
isolamento cross-tenant (3 camadas independentes de proteção continuam ativas: FK, `ADR-C005`,
policy de `SELECT`).

## 4. T22 — Neon pooled (executado, não destrutivo)

Executado via Prisma `$transaction()`, sem tocar nenhuma tabela de negócio, sem alterar schema,
sem imprimir connection string/senha/token em nenhum momento. Script:
`packages/core/prisma/rls/poc/06_t22_neon_pooled_test.mjs`.

| Item | DIRECT | POOLED |
|---|---|---|
| A. `SET LOCAL` visível dentro da transação | ✓ `'valor-sintetico-t22'` | ✓ `'valor-sintetico-t22'` |
| B. Desaparece após `COMMIT` (nova transação, sem novo `SET LOCAL`) | ✓ string vazia `''` | ✓ string vazia `''` |
| C. Desaparece após `ROLLBACK` | ✓ string vazia `''` | ✓ string vazia `''` |
| D. Reutilização de conexão/pool interno do Prisma não carrega contexto anterior | ✓ (sessão 1 = `'sessao-1'`, sessão 2 sem novo `SET LOCAL` = `''`) | ✓ (idêntico) |
| E. Prisma mantém `SET LOCAL` + query na mesma transação | ✓ | ✓ |
| F. Nenhuma persistência de dado/schema | ✓ confirmado (§6) | ✓ confirmado (§6) |
| Versão PostgreSQL | `18.6` | `18.6` |

**Nota semântica sobre o estado pós-transação (item "IMPORTANTE" da tarefa):** o Neon (PostgreSQL
18) retorna **string vazia (`''`)**, não `NULL` literal, para um GUC customizado não setado, lido
com `current_setting(nome, true)`. As 2 funções `contifisc_current_tenant_id()`/
`contifisc_current_conta_acesso_id()` já tratam explicitamente esse caso —
`IF raw IS NULL OR raw = '' THEN RETURN NULL` — então o contrato fail-closed **é preservado**
independentemente de o Postgres devolver `NULL` ou `''`. Este teste T22 é, na prática, a primeira
confirmação empírica de que essa branch específica do tratamento (`raw = ''`) realmente é
exercitada em produção real (Neon), não apenas hipotética — validando uma decisão de robustez que,
sem este teste, permaneceria não comprovada contra o comportamento real do Neon.

**Achado não-bloqueante (MENOR):** o Neon DEV roda **PostgreSQL 18.6** — acima do mínimo exigido
(`ADR-D014`: `>= 15`), portanto conforme. Toda a PoC de RLS (`RLS_POC_REPORT.md`/
`RLS_POC_CORRECTION_REPORT.md`) foi validada em containers descartáveis **PostgreSQL 15.19**
especificamente — a mecânica de `SET LOCAL`/GUC customizado acaba de ser confirmada diretamente
contra o Neon 18.6 por este T22, mas as **policies RLS e as funções `SECURITY DEFINER` em si**
nunca foram executadas contra PostgreSQL 18. Não há motivo técnico conhecido para esperar
divergência (RLS e `SECURITY DEFINER` são recursos estáveis desde PG 9.5/9.x, sem mudança de
semântica relevante até a 18), mas fica registrado como recomendação, não como bloqueio: rodar uma
PoC descartável em `postgres:18` antes (ou logo depois) da aplicação real seria um reforço de
evidência barato, dado que o ambiente real já é a 18.

## 5. Prisma + pooled

Coberto integralmente por T22 (§4) — o mesmo script já usa `$transaction()` contra o endpoint
pooled real. Nenhuma configuração permanente de `schema.prisma` foi alterada; a URL pooled foi
construída em memória (inserindo `-pooler` no host a partir da `DATABASE_URL` já salva em `.env`)
e usada apenas via variável de ambiente de processo, nunca gravada em arquivo nem impressa.

## 6. Neon — inventário antes/depois

| Verificação | Antes do T22 | Depois do T22 |
|---|---|---|
| Migrations aplicadas | 1 (`20260908120000_init_baseline_fisica_pos_sec`) | 1 (inalterado) |
| `prisma migrate status` | — | `20260917130000_rls_tenant_isolation_DRAFT` listada como **não aplicada** (confirmação adicional, não destrutiva) |
| Tabelas em `public` | 26 | 26 |
| Policies (`pg_policies`) | 0 | 0 |
| Funções `contifisc_*` | 0 | 0 |
| Roles `contifisc_*` | 0 | 0 |
| Dado de negócio | 0 registros (banco vazio desde o provisionamento) | 0 registros |

**Achado de processo (MENOR, não bloqueante):** `prisma migrate status` mostrou que, por a pasta
`20260917130000_rls_tenant_isolation_DRAFT` estar fisicamente dentro de
`packages/core/prisma/migrations/`, o Prisma a reconhece como uma migration pendente comum — ou
seja, um `prisma migrate deploy` executado sem essa ressalva em mente aplicaria a RLS DRAFT
automaticamente, sem distinguir "rascunho" de "definitiva". Isso não é um problema do desenho da
RLS em si, mas um risco operacional/de processo: recomenda-se manter a disciplina manual já em
vigor (nunca rodar `migrate deploy` sem checar `migrate status` e revisar o diff antes) até a
migration ser deliberadamente renomeada e promovida — o que esta revisão **não** faz.

## 7. Checksum da migration RLS corrigida

```
SHA-256: a82e3c088e9f8ea37eba4087f2303e83e2dcab48e2ba4d9a443f5ba183d255f9
```

Idêntico ao valor já registrado como validado (2ª execução) em `RLS_POC_CORRECTION_REPORT.md` §8 —
confirma que o arquivo em disco não foi alterado entre a validação e esta revisão.

## 8. Reconciliação final

| Item | Status |
|---|---|
| 25/25 tabelas classificadas | ✓ |
| Policies reconciliadas (30 no total — 22 tabelas com 1 policy `FOR ALL`, `vinculo`/`vinculo_extremidade` com 4 cada, `evento_auditoria_seguranca` com 0) | ✓ |
| C1 | ✓ resolvido e revalidado |
| C2 | ✓ resolvido e revalidado |
| C3 | ✓ resolvido e revalidado |
| SD01-SD15 | ✓ aprovados |
| T01-T47 | ✓ aprovados (revalidados na correção) |
| T22 pooled | ✓ **encerrado nesta revisão** — DIRECT e POOLED, ambos OK |
| Fail-closed | ✓ preservado (inclusive a branch `raw=''`, agora confirmada contra o Neon real) |
| Mediator hardened | ✓ (ADR-002 §1, 15/15 testes SD) |
| `ADR-C005` | ✓ preservado |
| `ADR-C014` | ✓ preservado |
| `F9005`/`F9006` | ✓ intocados |
| Migration inaugural | ✓ intocada (`git diff --stat` vazio) |
| Neon sem RLS | ✓ confirmado antes/depois |
| Autenticação | ✓ não implementada |
| Governança/ADR | ✓ `ADR-002` DRAFT criado, `ADR-001` preservado sem alteração |

## 9. Gaps

Nenhum gap novo de `COT`/`MCD`/`CDC`/`DST` criado ou fechado. `DST-GAP-003`/`GAP-SEC-CR1-002`
(exceção residual de `Vinculo` sem extremidade UE) e `GAP-CDC-1.3-002`
(`EventoAuditoriaSeguranca` bloqueada) permanecem exatamente como já documentado — reafirmados,
não alterados.

## 10. Classificação final

| Severidade | Quantidade | Itens |
|---|---|---|
| `CRITICAL` | 0 | — |
| `RELEVANTE` | 0 | — |
| `MENOR` | 2 | (1) PoC de RLS/`SECURITY DEFINER` nunca executada especificamente contra PostgreSQL 18 (só T22/GUC mecânica, via este relatório); (2) migration DRAFT reconhecida como pendente comum por `prisma migrate status` — risco de processo, mitigado por disciplina manual, não por barreira técnica |

## 11. Git

```
git status --short
?? docs/11-Security/
?? docs/ADR-002_CONTIFISC_RLS_Contexto_Transacional_Mediacao_SECURITY_DEFINER_DRAFT_V1.0.md
?? packages/core/prisma/migrations/20260917130000_rls_tenant_isolation_DRAFT/
?? packages/core/prisma/rls/

git diff --stat -- packages/core/prisma/migrations/20260908120000_init_baseline_fisica_pos_sec/
(vazio — migration inaugural intocada)
```

Nenhum `.env`, connection string, senha, token, log ou dump encontrado em nenhum arquivo novo ou
staged. Nenhum commit. Nenhum push.

## 12. Recomendação de deploy

**Ainda não recomendado aplicar ao Neon nesta sessão** — não por nenhum achado bloqueante (não há
nenhum), mas porque a aplicação real em ambiente persistente é, por desenho de todo este processo,
uma autorização **separada e explícita**, nunca automática mesmo com gate limpo. Quando essa
autorização for dada: (1) aprovar formalmente `ADR-002`; (2) considerar a PoC adicional em
PostgreSQL 18 (achado MENOR 1, opcional); (3) mover a pasta `..._DRAFT` para um nome de migration
definitivo; (4) `prisma migrate deploy` contra o Neon DEV — nunca `prisma db push`.

## 13. Gate

```
RLS PÓS-SEC — REVISÃO PRÉ-NEON CONCLUÍDA E APTA PARA AUTORIZAÇÃO DE DEPLOY
```

`CRITICAL = 0`, `RELEVANTE = 0`. Todos os critérios do gate atendidos: T22 pooled comprovado
(DIRECT e POOLED); nenhuma alteração persistente no Neon (confirmado antes/depois); mediator
formalmente reconciliado (`ADR-002`); `SECURITY DEFINER` hardened (15/15 SD); C1/C2/C3 encerrados
com evidência empírica; migration DRAFT reconciliada com a documentação (checksum idêntico);
governança resolvida via `ADR-002` DRAFT aditivo, sem alterar `ADR-001` silenciosamente.
