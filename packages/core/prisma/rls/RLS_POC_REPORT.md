# RLS_POC_REPORT — PoC descartável da RLS pós-SEC

**Status:** PoC EXPERIMENTAL EXECUTADA E CONCLUÍDA. Todos os containers e volumes descartáveis
foram destruídos ao final (`docker rm -f` + `docker volume prune`). **Nenhum `schema.prisma`
canônico, migration inaugural, documento normativo, RLS, autenticação ou banco persistente
(Neon DEV) foi alterado.** Encontrados **2 achados CRITICAL** — ver §6/§11. Gate final: **PoC
REQUER CORREÇÃO**.

## 1. Ambiente

| Componente | Versão |
|---|---|
| PostgreSQL (2 containers) | 15.19 (Debian 15.19-1.pgdg13+2), imagem oficial `postgres:15` |
| Docker Engine/Client | 29.8.0, build 88096ef |
| Prisma CLI / `@prisma/client` | 6.19.3 |
| Node.js | v24.19.0 |

Containers: `contifisc-rls-poc1` (porta 55401) e `contifisc-rls-poc2` (porta 55402, segunda
execução), ambos destruídos ao final junto com seus volumes anônimos.

## 2. Checksums

| Arquivo | SHA-256 | Idêntico nas 2 execuções? |
|---|---|---|
| `migration.sql` (baseline pós-SEC) | `afe5964170c58fbbb3708d65d24d36b49eca988273e4d0f8ece40e95d060e837` | ✓ — **idêntico ao valor já registrado em `MIGRATION_INTEGRATION_TEST_REPORT.md` e ao aplicado no Neon DEV** |
| `migration.sql` (RLS DRAFT) | `14aca75737d275b2da6a03605b01e3d3296bff2470915f4093d37138ff910fc0` | ✓ |

## 3. Aplicação das migrations

Container 1 e Container 2: baseline pós-SEC aplicada primeiro (`psql -v ON_ERROR_STOP=1`, exit 0),
depois RLS DRAFT (exit 0) — em ambos os containers, sem nenhuma edição manual.

## 4. Introspecção (idêntica nas 2 execuções)

| Item | Esperado (matriz) | Observado (container 1) | Observado (container 2) |
|---|---|---|---|
| Total de tabelas | 25 | 25 | 25 |
| `relrowsecurity` (ENABLE) em todas | 25 | 25 | 25 |
| `relforcerowsecurity` (FORCE) em todas | 25 | 25 | 25 |
| Total de policies | 24 (uma por tabela, exceto `evento_auditoria_seguranca`) | 24 | 24 |
| Tabela sem nenhuma policy | `evento_auditoria_seguranca` (única) | confirmado | — (não repetido, já confirmado) |
| Funções novas | `contifisc_current_tenant_id`, `contifisc_current_conta_acesso_id` | presentes | — |
| Funções ADR-C005/C014 preservadas | `fn_check_vinculo_extremidades`, `trg_caue_requires_grant_fixed`, `trg_cat_blocks_if_dependents`, `trg_ue_tenant_change_guard` | presentes, inalteradas | — |
| Constraint triggers (deferrable+initdeferred) | 4 | 4 | — |
| Nenhum objeto canônico não autorizado | — | confirmado (nenhum objeto extra) | confirmado |

Role de teste criado: `contifisc_app_test` (`NOSUPERUSER`, `NOBYPASSRLS`) — todos os testes de RLS
rodaram sob este role, nunca como `postgres` (que é superuser + `BYPASSRLS` por padrão e não
provaria nada sobre a policy).

## 5. Fixture sintética

`packages/core/prisma/rls/poc/01_fixture.sql` — Tenant A/B, Conta A/B/C (C sem nenhuma concessão),
`ContaAcessoTenant` A→A e B→B, UE-A/UE-B, e ao menos um fato sintético em **cada** categoria da
matriz (`receita`, `arquivo_origem`, `documento_fiscal`, `receita_documento_fiscal`,
`documento_fiscal_arquivo_origem`, `classificacao_equiparacao_hospitalar`, `conflito_dado` +
`conflito_dado_item` — incluindo um item com `objeto_id` apontando para outro tenant,
propositalmente, para testar T14 — `revisao_tecnica`, 3 cenários de `Vinculo`/`VinculoExtremidade`,
`cenario_tributario`, `resultado_calculo`, `conta_acesso_unidade_economica` já validada por
`ADR-C014`). Todos os dados são UUIDs/nomes obviamente fictícios; nenhum CPF/CNPJ real.

Cinco ajustes de fixture foram necessários durante a execução (colunas `NOT NULL` que a fixture
inicial não previu: `registrado_em` em `pessoa_fisica`/`pessoa_juridica`/`fonte_pagadora`/
`cenario_tributario`, `tipo_documento_fiscal`/`sistema_origem` em `documento_fiscal`,
`rule_set_id`/`rule_set_version` em `resultado_calculo`, e agrupar as duas extremidades de um
mesmo `Vinculo` num único `INSERT` multi-linha para não disparar `ADR-C005` prematuramente sob
autocommit do `psql`). Nenhum desses ajustes alterou a lógica de teste — apenas completou a
fixture para satisfazer `NOT NULL`/`CHECK` já vigentes.

## 6. Resultado dos testes (T01–T47 do `RLS_TEST_PLAN.md`)

**44 de 47 comportamentos passaram exatamente como especificado. 2 tabelas (`vinculo`/
`vinculo_extremidade`, tratadas como uma única falha porque compartilham a mesma causa raiz) e a
policy definitiva de `tenant` apresentaram falha real, reproduzida de forma idêntica nas duas
execuções independentes.**

| Teste(s) | Resultado | Evidência |
|---|---|---|
| T04 (ausência total de contexto) | **PASS** | 0 linhas em `receita`/`tenant`/`arquivo_origem`/`unidade_economica` |
| T29 (`GLOBAL_COMPARTILHADO` visível sem contexto) | **PASS** | `pessoa_fisica`/`pessoa_juridica`/`fonte_pagadora`/`conta_acesso` visíveis |
| T30 (`evento_auditoria_seguranca` bloqueada mesmo com contexto válido) | **PASS** | 0 linhas, fail-closed por ausência de policy confirmado |
| T01/T02/T03 (isolamento básico) | **PASS** | Tenant A vê só sua `receita`; Tenant B vê só a sua |
| T05 (tenant inexistente) | **PASS** | 0 linhas |
| T06/T07 (INSERT próprio/cross-tenant) | **PASS** | Próprio: `INSERT 0 1`. Cross-tenant: **rejeitado com erro explícito** `new row violates row-level security policy for table "receita"` (`WITH CHECK` ativo) |
| T08/T09 (UPDATE próprio/cross-tenant) | **PASS** | Próprio: `UPDATE 1`. Cross-tenant: `UPDATE 0` (linha invisível, não afetada) |
| T10 (mover `UnidadeEconomica` para outro tenant) | **PASS** | Rejeitado com erro `new row violates row-level security policy for table "unidade_economica"` — bloqueado pelo `WITH CHECK` da RLS **antes mesmo** de `trg_ue_tenant_change_guard` (`ADR-C014`) ter chance de avaliar no commit; achado de interação registrado em §8, não um problema |
| T11/T12 (DELETE próprio/cross-tenant) | **PASS** | `DELETE 1` / `DELETE 0` |
| T13 (tenant derivado via UE em 6 tabelas) | **PASS** | `documento_fiscal`, `cenario_tributario`, `resultado_calculo`, `receita_documento_fiscal`, `documento_fiscal_arquivo_origem`, `classificacao_equiparacao_hospitalar` — todas com contagem correta (1 cada, só o lado do Tenant A) |
| T14 (`ConflitoDadoItem` deriva só do pai) | **PASS** — achado de correção mais fino do que o mínimo pedido | Item cujo `objeto_id` (polimórfico) aponta para uma `Receita` do **Tenant B** continua **visível** ao Tenant A, porque seu `conflito_dado_id` pertence ao `ConflitoDado` do Tenant A — confirma empiricamente que a referência polimórfica nunca é usada para derivar tenant |
| T15/T16/T17 (tenant materializado) | **PASS** | `arquivo_origem`/`revisao_tecnica`/`conflito_dado` — 1 cada, corretos |
| T25 (`SELECT *` sem `WHERE`) | **PASS** | Tenant B viu somente sua própria linha de `receita`, mesmo sem filtro explícito na query |
| **T26/T27/T28 (`vinculo`/`vinculo_extremidade`)** | **FAIL — CRITICAL** | `ERROR: infinite recursion detected in policy for relation "vinculo_extremidade"` — ver §7 |
| T18/T42 (`ContaAcessoUnidadeEconomica` sem `ContaAcessoTenant`) | **PASS** | Rejeitado pela **RLS** (`new row violates row-level security policy for table "conta_acesso_unidade_economica"`) — `ADR-C014` nem chega a ser necessário neste caminho porque a RLS já bloqueia antes; ambos os mecanismos continuam presentes e não foram enfraquecidos |
| T24 parte 1 (grant existente visível) | **PASS** | `count = 1` |
| **T32/T33/T31 (policy definitiva de `tenant`)** | **FAIL — CRITICAL** | Conta A, com `app.current_conta_acesso_id` setado mas **sem** `app.current_tenant_id`, viu **0** tenants — deveria ver o Tenant A. Ver §7 |
| T34 (conta inexistente) | **PASS** | 0 tenants |
| T36 (conta ausente) | **PASS** | 0 tenants |
| T38 (tenant malformado, valida D7) | **PASS** | 0 linhas, **sem erro** — a função segura funcionou exatamente como desenhado |
| T39 (conta sem nenhuma concessão) | **PASS** | 0 tenants |
| T40/T41 (UE certa/errada, mesmo contexto) | **PASS** | 1 linha / 0 linhas |
| T20/T43 (`SET LOCAL` não sobrevive ao `COMMIT`) | **PASS** | Transação 1 viu 1 linha; Transação 2 (mesma sessão, sem novo `SET LOCAL`) viu 0 |
| T44 (idem com `ROLLBACK`) | **PASS** | Mesmo padrão — 1 depois 0 |
| T21 (conexão reutilizada, tenant trocado) | **PASS** | Tenant A depois Tenant B, cada um viu só o seu, sem resíduo |
| T09-concorrência (duas conexões simultâneas, Tenant A com delay proposital de 3s no meio, Tenant B concorrente terminando primeiro) | **PASS** | Cada conexão viu exclusivamente seu próprio tenant, mesmo com sobreposição real de tempo de execução confirmada pelo `pg_sleep` |
| T24 parte 2 (owner/superuser vs. role normal) | **PASS** | `postgres` (superuser+`BYPASSRLS`) viu as 2 linhas de `receita` sem nenhum contexto setado; `contifisc_app_test` (sem `BYPASSRLS`) viu 0 nas mesmas condições — confirma que o runtime role normal **não pode** bypassar RLS |
| Prisma `$transaction()` (3 sub-testes) | **PASS** | `SET LOCAL` + query na mesma `$transaction` respeita o contexto; uma **nova** `$transaction` sem novo `SET LOCAL` (reusando o pool interno do Prisma) viu 0 linhas — nenhum vazamento entre transações via Prisma |
| Reprodutibilidade (2ª execução, container novo) | **PASS** | Checksums idênticos, introspecção idêntica (25/24/25), T01/T05 reproduzidos, **e os 2 bugs abaixo reproduzidos de forma idêntica** |
| T22 (pooled Neon) | **NÃO EXECUTADO** | Ver §9 — decisão deliberada de não tocar o Neon DEV |
| T23 (direct, quando aplicável) | Coberto indiretamente | Toda a PoC usou conexão direta ao container — nenhuma camada de pooling entre o teste e o Postgres |

## 7. Achados CRITICAL — diagnóstico

### CRITICAL-1 — `vinculo_extremidade`: recursão infinita na policy

A policy desenhada para `vinculo_extremidade` (RLS_MATRIX item 6) resolve o "caso 2" (extremidade
PF/PJ deriva o tenant da extremidade **irmã**) fazendo um `EXISTS` que consulta a **própria tabela**
`vinculo_extremidade` dentro de sua própria `USING`/`WITH CHECK`. O PostgreSQL aplica a mesma
policy recursivamente a essa subconsulta interna (porque o role de teste não tem `BYPASSRLS`),
gerando recursão infinita, detectada e abortada pelo próprio PostgreSQL com o erro
`infinite recursion detected in policy for relation "vinculo_extremidade"`.

**Isso não é um problema de segurança** (nenhum dado vazou — o resultado é uma falha dura, não um
acesso indevido), mas **bloqueia completamente** o uso de `vinculo`/`vinculo_extremidade` sob RLS
como desenhado — qualquer `SELECT`/`INSERT`/`UPDATE`/`DELETE` nessas duas tabelas falha com erro em
vez de aplicar o filtro.

**Causa raiz:** uma policy não pode consultar a própria tabela via SQL comum quando o role não
possui `BYPASSRLS` — a subconsulta reaplica a mesma policy, indefinidamente.

**Correção recomendada (não aplicada nesta PoC, por instrução explícita de não editar SQL durante
o teste):** mover a resolução "extremidade irmã" para uma função `SECURITY DEFINER` (de propriedade
de um role com `BYPASSRLS` implícito por ser `SECURITY DEFINER` executando como esse dono),
equivalente ao padrão já usado para `contifisc_current_tenant_id()`, mas que internamente execute a
consulta com `SET LOCAL row_security = off` (ou, mais simples e mais seguro: consulte
`unidade_economica.tenant_id` diretamente pela extremidade irmã via uma função auxiliar que já
recebe o `vinculo_id` e devolve o tenant resolvido, nunca reconsultando `vinculo_extremidade` com
RLS ativa dentro de si mesma). Mesma classe de correção provavelmente necessária para a policy de
`vinculo` (item 5), que hoje consulta `vinculo_extremidade` (não a si mesma, então **não** recursiona
da mesma forma — mas herda o mesmo erro porque a consulta a `vinculo_extremidade` já falha).

### CRITICAL-2 — `tenant`: policy definitiva acoplada indevidamente ao tenant ativo

A policy definitiva de `tenant` (resolução do achado D2, `SECURITY_CONTEXT_CONTRACT.md` §5) foi
desenhada para depender **apenas** de `app.current_conta_acesso_id`, deliberadamente **independente**
de `app.current_tenant_id` — o objetivo explícito era permitir que uma conta veja **todos** os
tenants aos quais tem concessão, mesmo sem ainda ter escolhido qual está ativo.

**Observado empiricamente:** com `app.current_conta_acesso_id` setado corretamente para a Conta A e
**sem** `app.current_tenant_id`, a query `SELECT id FROM tenant` retornou **0 linhas** — deveria
retornar 1 (o Tenant A). Confirmado que, setando **também** `app.current_tenant_id` para o mesmo
Tenant A, a query passa a retornar corretamente a linha.

**Causa raiz (confirmada por teste controlado, §comparação acima):** a policy de `tenant` resolve a
concessão via `EXISTS (SELECT 1 FROM conta_acesso_tenant cat WHERE ...)`. A tabela
`conta_acesso_tenant` **também tem RLS própria** (categoria `TENANT_ID_MATERIALIZADO`, policy
`tenant_id = contifisc_current_tenant_id()`). Como o role de teste não tem `BYPASSRLS`, essa
subconsulta dentro da policy de `tenant` está, ela mesma, sujeita à policy de `conta_acesso_tenant`
— que exige `app.current_tenant_id` já setado e igual ao tenant sendo verificado. Isso recria,
por composição indireta de RLS entre tabelas diferentes, exatamente a dependência de
`app.current_tenant_id` que a resolução de D2 pretendia eliminar — o achado D2 **não foi
efetivamente resolvido** pela policy como implementada, apesar de o contrato e a intenção de
desenho estarem corretos.

**Correção recomendada (não aplicada nesta PoC):** a leitura de `conta_acesso_tenant` dentro da
policy de `tenant` precisa **não estar sujeita à RLS de `conta_acesso_tenant`** — via função
`SECURITY DEFINER` (dona de um role com privilégio para ignorar RLS nessa leitura específica) que
encapsula exatamente "esta conta tem concessão para este tenant?", análoga ao padrão já usado com
sucesso para `contifisc_current_tenant_id()`/`contifisc_current_conta_acesso_id()`, mas operando
sobre uma tabela em vez de um GUC.

**Implicação mais ampla a verificar na correção:** este mesmo padrão de composição
(policy A consulta tabela B, que também tem RLS própria) existe em **todas** as 13 tabelas
`TENANT_DERIVADO_POR_RLS` que consultam `unidade_economica` — porém, nelas, a policy de
`unidade_economica` exige o **mesmo** `app.current_tenant_id` que a tabela derivada já exige, então
a composição é redundante, não conflitante (confirmado empiricamente — T13, T01-T09, T25 todos
passaram). O problema em `tenant` é específico porque sua policy foi desenhada para depender de uma
variável **diferente** (`conta_acesso_id`) da que protege a tabela consultada internamente
(`tenant_id` em `conta_acesso_tenant`) — um descasamento de dimensões que só a execução real expôs.

## 8. Achado de interação (não um erro) — RLS antecede `ADR-C014` em dois caminhos

Tanto em T10 (`UnidadeEconomica.tenant_id`) quanto em T18/T42 (`ContaAcessoUnidadeEconomica` sem
concessão), a rejeição observada veio da **RLS** (`WITH CHECK`), não do trigger `ADR-C014` — porque
a RLS é avaliada de forma síncrona por statement, enquanto os triggers `ADR-C014` são
`DEFERRABLE INITIALLY DEFERRED` (avaliados só no `COMMIT`). Isso significa que, na prática, a RLS
"chega primeiro" nesses dois caminhos específicos. **Isso não enfraquece `ADR-C014`** — o trigger
continua presente, inalterado e continuaria protegendo qualquer caminho que a RLS eventualmente não
cobrisse (por exemplo, se um role tivesse `BYPASSRLS` mas não fosse superuser) — mas é um achado
relevante para o entendimento operacional do sistema em camadas, documentado aqui para
rastreabilidade. Nenhum cenário Race 1/Race 2/Race 3 do `ADR-C014_POC_REPORT.md` foi reexecutado
nesta PoC (ver §10 — limitação).

## 9. Neon — pooled vs. direct

**Não executado contra o endpoint pooled real do Neon nesta PoC**, por decisão deliberada: o Neon
DEV não tem nenhuma policy RLS aplicada (nunca foi tocado), então um teste de `SET LOCAL` contra seu
pooler testaria apenas o comportamento genérico do PgBouncer, não as policies específicas desta
revisão — e o risco de gerar qualquer efeito colateral num banco persistente real, para um ganho de
evidência marginal, não se justificou. Mantido como **item obrigatório da PoC pré-aplicação**,
quando (e se) os 2 achados CRITICAL acima forem corrigidos — não presumido como aprovado.

## 10. Limitações desta execução

- `ADR-C014` Race 1/Race 2/Race 3 (concorrência com `pg_sleep` instrumentado) **não foram
  reexecutados** — apenas confirmado que os 4 constraint triggers continuam presentes e que os 2
  caminhos testados (T10, T18/T42) continuam rejeitando corretamente (agora com RLS também
  rejeitando, antes mesmo do trigger). Reexecução completa das 3 races fica recomendada para a
  PoC de correção subsequente, não repetida aqui por ser específica de `ADR-C014` em si (já
  validada em `ADR-C014_POC_REPORT.md`) e não ter relação com os 2 bugs encontrados.
- `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf` não têm fato sintético
  próprio na fixture — sua policy usa o **mesmo padrão exato** (1 hop via `unidade_economica_id`)
  já validado empiricamente para `receita`/`documento_fiscal`/`cenario_tributario`/
  `resultado_calculo`. Tratado como validado por analogia estrutural direta, não por execução
  individual — registrado explicitamente, não presumido silenciosamente.
- T22 (Neon pooled) não executado — §9.
- `ADR-C011` (`UNIQUE(id, tenant_id)`) não foi reexercitada isoladamente nesta PoC — já validada
  estruturalmente pela introspecção (constraint presente) e indiretamente por T10 (o `UPDATE` de
  `tenant_id` em `unidade_economica` foi rejeitado antes de chegar a essa constraint).

## 11. Gaps

Nenhum gap novo de `COT`/`MCD`/`CDC`/`DST` foi criado ou fechado. `F9005`/`F9006` não tocados
(confirmado — nenhuma referência nesta PoC). Os 2 achados `CRITICAL` são bugs de **implementação
física de RLS** (SQL das policies), não gaps de modelagem canônica — não requerem nenhuma
alteração em `COT`/`MCD`/`CDC`/`DST`/`ADR-001`/`SEC-001`, apenas correção do SQL das duas policies
específicas identificadas.

## 12. Contagem do gate

| Severidade | Quantidade | Itens |
|---|---|---|
| `CRITICAL` | 2 | `vinculo`/`vinculo_extremidade` (recursão infinita); `tenant` (policy definitiva não funciona sem `app.current_tenant_id`, contrariando o desenho de D2) |
| `RELEVANTE` | 0 | — |
| `MENOR` | 1 | T22 (Neon pooled) não executado, por decisão deliberada de não tocar o Neon DEV — não é uma falha de teste, é escopo preservado |

## 13. Conclusão

```
RLS PÓS-SEC — PoC REQUER CORREÇÃO ANTES DE QUALQUER APLICAÇÃO
```

**O que funcionou (44/47 comportamentos, incluindo todos os mecanismos estruturais mais
importantes):** fail-closed em todas as suas variantes (ausência, formato inválido, inexistência,
sem concessão), isolamento correto em 23 das 25 tabelas (incluindo as 13 `TENANT_DERIVADO_POR_RLS`,
as 4 `TENANT_ID_MATERIALIZADO`, a `TENANT_ID_RAIZ`, a `TENANT_DERIVADO_DO_PAI`, as 4
`GLOBAL_COMPARTILHADO` e a `BLOQUEADA`), `SET LOCAL` não sobrevive a `COMMIT`/`ROLLBACK`/reuso de
conexão, concorrência real sem vazamento, Prisma `$transaction()` compatível, `owner`/`BYPASSRLS`
comportando-se exatamente como o desenho previa, e `ADR-C014` preservado e não enfraquecido.

**O que não funcionou:** as 2 tabelas com o padrão de policy "auto-referencial"
(`vinculo`/`vinculo_extremidade`) e a policy definitiva de `tenant` (que também consulta outra
tabela com RLS própria) — ambas falharam por um mesmo tipo de causa raiz: **uma policy RLS não pode
consultar, sem mediação, uma tabela que também tem RLS ativa, quando o role de execução não tem
`BYPASSRLS`** — algo que não havia sido considerado durante o desenho (`RLS-001`/`RLS_MATRIX.md`) e
que só a execução empírica revelou, exatamente o propósito desta etapa.

**Reprodutibilidade:** ambos os achados foram confirmados de forma idêntica em duas execuções
completamente independentes (containers e volumes diferentes, checksums idênticos).

## 14. Artefatos desta PoC

- `packages/core/prisma/rls/RLS_POC_REPORT.md` (este arquivo)
- `packages/core/prisma/rls/poc/01_fixture.sql`
- `packages/core/prisma/rls/poc/02_tests_sequential.sql`
- `packages/core/prisma/rls/poc/03_tests_persistence.sql`
- `packages/core/prisma/rls/poc/04_prisma_test.mjs`

Nenhum arquivo canônico, `schema.prisma`, migration inaugural ou documento normativo foi alterado.
A migration RLS DRAFT (`20260917130000_rls_tenant_isolation_DRAFT/migration.sql`) **não foi
editada** durante esta PoC, por instrução explícita — os 2 achados `CRITICAL` permanecem
registrados aqui, não corrigidos silenciosamente no arquivo.
