# RLS_POC_CORRECTION_REPORT — Correção controlada dos 2 CRITICALS (+ 1 descoberto nesta rodada)

**Status:** PoC de correção EXECUTADA E CONCLUÍDA (4 containers descartáveis no total ao longo do
processo — 2 destruídos por correções intermediárias, 2 pela metodologia normal de 1ª/2ª
execução). **Nenhum `schema.prisma` canônico, migration inaugural, documento normativo,
autenticação ou Neon DEV foi alterado.** C1 e C2 (do `RLS_POC_REPORT.md` original) **corrigidos e
revalidados empiricamente**. Um terceiro problema estrutural (**C3**) foi descoberto durante esta
própria correção, dentro do escopo já autorizado (seção 5: "testar... insert cross-tenant" para
`Vinculo`/`VinculoExtremidade`) — também corrigido e revalidado. **Evidência original de C1/C2
preservada integralmente em `RLS_POC_REPORT.md`, não apagada.**

## 1. Causa raiz — confirmação precisa (item 1 do prompt)

### A. Cadeia de avaliação que produzia recursão em `vinculo`/`vinculo_extremidade` (C1)

A policy original de `vinculo_extremidade` continha, dentro de sua própria `USING`/`WITH CHECK`,
um `EXISTS` que consultava a **mesma tabela** `vinculo_extremidade` (para resolver o "caso da
extremidade irmã"). Quando o PostgreSQL avalia essa subconsulta, ele reaplica a RLS de
`vinculo_extremidade` a ela — que por sua vez contém o mesmo `EXISTS`, reaplicado de novo,
indefinidamente. O PostgreSQL detecta esse ciclo e aborta com
`infinite recursion detected in policy for relation "vinculo_extremidade"`.

### B. Cadeia de avaliação da policy `tenant` que fazia `conta_acesso_tenant` reaplicar sua própria RLS (C2)

A policy definitiva de `tenant` consultava `conta_acesso_tenant` via `EXISTS` comum. Como
`conta_acesso_tenant` também tem RLS própria (categoria `TENANT_ID_MATERIALIZADO`, predicado
`tenant_id = app.current_tenant_id`), essa subconsulta era filtrada por essa policy — exigindo
`app.current_tenant_id` já setado e igual ao tenant sendo verificado. Isso não é recursão (tabelas
diferentes), mas reintroduz, por composição indireta, exatamente a dependência de
`app.current_tenant_id` que a resolução de D2 pretendia eliminar.

### C. Por que ocorre apenas para runtime role sem `BYPASSRLS`

`FORCE ROW LEVEL SECURITY` (ativa nas 25 tabelas) faz a RLS se aplicar a **qualquer** role sem
`BYPASSRLS`/superuser executando a consulta — inclusive dentro de uma subconsulta aninhada dentro
de outra policy. Um role com `BYPASSRLS` (ou superuser) nunca dispara esse comportamento, porque
RLS é inteiramente ignorada para ele, em qualquer profundidade de aninhamento.

### D. Por que testes como `postgres`/superuser não seriam suficientes

`postgres` é superuser e tem `rolbypassrls=true` por padrão — toda consulta feita por ele, direta
ou aninhada, ignora RLS completamente. Rodar os testes como `postgres` nunca reproduziria C1 nem
C2 (nem o C3 descoberto nesta correção), porque a condição que os provoca (RLS sendo reaplicada a
uma subconsulta) simplesmente não existe para esse role. **Confirmado empiricamente nesta correção
(teste SD12, §4)**: uma função `SECURITY DEFINER` idêntica, mas com owner **sem** `BYPASSRLS`,
retornou resultado incorreto (`false` para uma concessão real) sob as mesmas condições — prova
direta de que nem `SECURITY DEFINER` sozinho, nem testar como superuser, seriam suficientes; é
`BYPASSRLS` especificamente no owner que resolve.

### E. Quais objetos precisam de mediação privilegiada (e apenas esses)

Somente 2 consultas, ambas de **resolução de autorização cross-table**, nunca de conteúdo de fato
tributário:

1. "esta `conta_acesso_id` tem concessão (`ContaAcessoTenant`) para este `tenant_id`?" — usada pela
   policy de `tenant`.
2. "este `vinculo_id` tem alguma extremidade que é uma `UnidadeEconomica` deste `tenant_id`?" —
   usada pelas policies de `vinculo`/`vinculo_extremidade` (leitura/atualização/exclusão).

Nenhuma outra das 25 tabelas precisa de mediação — as demais 22 resolvem tenant consultando
**apenas** `unidade_economica` sob a **mesma** variável que já protege a tabela derivada (nunca
uma tabela protegida por uma dimensão de contexto diferente), o que é redundante mas nunca
conflitante — confirmado empiricamente no `RLS_POC_REPORT.md` original (T01-T09/T13/T25 corretos
sem nenhuma mediação).

## 2. Achado adicional descoberto nesta correção — C3 (não previsto no prompt original, dentro do escopo já autorizado)

Ao testar o caminho de `INSERT` de um `Vinculo` **novo** (exigido pela seção 5: "insert
cross-tenant" e pela seção 10: reexecutar tudo relacionado a `Vinculo`/`VinculoExtremidade"), a
policy corrigida de C1 (agora via função) ainda falhava — com um erro **diferente**: `new row
violates row-level security policy for table "vinculo"`.

**Causa raiz:** `Vinculo` não tem nenhuma coluna própria que identifique tenant — seu tenant é
**100% derivado** de suas `VinculoExtremidade` (que ainda não existem no momento em que o próprio
`Vinculo` é inserido, por definição — a FK exige o pai antes das filhas). Uma policy `FOR ALL`
usando a função de mediação exige que já exista uma extremidade — impossível de satisfazer para
qualquer `INSERT` de um `Vinculo` novo, sempre. Testado e confirmado que nem inserir as duas
extremidades num único `INSERT` multi-linha resolve (linhas da mesma instrução não se enxergam
mutuamente através da subconsulta da função).

**Correção:** separar as policies de `vinculo`/`vinculo_extremidade` por comando (`SELECT`,
`INSERT`, `UPDATE`, `DELETE`) em vez de uma única `FOR ALL`:
- `vinculo`: `INSERT` fica **permissivo** (`WITH CHECK (true)`) — decisão estrutural, não de
  design, já que não há dado algum na própria linha para validar; a garantia real continua em 3
  camadas independentes (FK obriga extremidades a referenciar um `Vinculo` já existente; `ADR-C005`
  exige exatamente 2 extremidades até o `COMMIT`, ou a transação inteira falha; `SELECT`/`UPDATE`/
  `DELETE` continuam exigindo extremidade no tenant ativo — um `Vinculo` sem extremidades válidas
  do tenant certo fica permanentemente invisível).
- `vinculo_extremidade`: `INSERT` usa uma checagem **direta e não-circular** contra
  `unidade_economica` (sem depender de nenhuma outra linha de `vinculo_extremidade`): se a
  extremidade é UE, ela precisa pertencer ao tenant ativo; se é PF/PJ (sem UE), é permitida (não
  carrega tenant próprio, e a garantia de isolamento continua vindo do `SELECT`, que exige alguma
  extremidade UE do tenant certo).

## 3. Solução implementada no DRAFT

Arquivo: `packages/core/prisma/migrations/20260917130000_rls_tenant_isolation_DRAFT/migration.sql`.

- Novo role interno `contifisc_rls_mediator` (`NOSUPERUSER NOLOGIN BYPASSRLS`) — nunca usado como
  runtime, migration ou provisioning; única função é ser dono das 2 funções de mediação.
- 2 funções `SECURITY DEFINER`: `contifisc_conta_tem_acesso_tenant(uuid,uuid) RETURNS boolean` e
  `contifisc_vinculo_tem_extremidade_no_tenant(uuid,uuid) RETURNS boolean` — ambas retornam
  **apenas boolean**, nunca linhas.
- `GRANT SELECT` mínimo ao `contifisc_rls_mediator` **somente** nas 3 tabelas que essas 2 funções
  precisam ler (`conta_acesso_tenant`, `vinculo_extremidade`, `unidade_economica`) — achado
  intermediário desta correção (a primeira tentativa de execução falhou com
  `permission denied for table conta_acesso_tenant`: `SECURITY DEFINER` muda o role efetivo para
  fins de RLS e de checagem de `GRANT`, mas não cria privilégio que não foi concedido).
- Policy de `tenant`: reescrita para usar `contifisc_conta_tem_acesso_tenant(...)`.
- Policies de `vinculo`/`vinculo_extremidade`: separadas em 4 policies cada (`SELECT`/`INSERT`/
  `UPDATE`/`DELETE`) — `SELECT`/`UPDATE`/`DELETE` usam `contifisc_vinculo_tem_extremidade_no_tenant(...)`;
  `INSERT` usa a regra minimalista descrita em §2.

## 4. Hardening `SECURITY DEFINER` — evidência empírica (SD01-SD15)

| Teste | Resultado | Evidência |
|---|---|---|
| SD01 (`PUBLIC` sem `EXECUTE`) | **PASS** | `pg_proc.proacl` — nenhuma entrada para `PUBLIC` nas 2 funções |
| SD02 (runtime só com `EXECUTE` explícito) | **PASS** | `contifisc_app_test=X` presente no ACL, `REVOKE ALL FROM PUBLIC` executado antes |
| SD03 (`NULL` falha fechado) | **PASS** | `contifisc_conta_tem_acesso_tenant(NULL, NULL)` → `false` |
| SD04 (UUID inexistente falha fechado) | **PASS** | conta e tenant inexistentes → `false` em ambos os casos |
| SD05 (conta A + tenant B → falso) | **PASS** | `false` |
| SD06 (conta A + tenant A → verdadeiro) | **PASS** | `true` |
| SD07 (`search_path` malicioso da sessão não muda resultado) | **PASS** | com `search_path=evil,public` setado pela sessão, resultado idêntico ao correto — função usa `SET search_path = pg_catalog, public` fixo, imune ao `search_path` do chamador |
| SD08 (objeto homônimo em schema controlável não altera resolução) | **PASS** | tabela `evil.conta_acesso_tenant` criada com uma linha **forjada** liberando Conta A → Tenant B, colocada **na frente** do `search_path` — função continuou retornando `false` (ignorou completamente `evil.*`, resolveu contra `public.conta_acesso_tenant` via qualificação explícita de schema) |
| SD09 (sem SQL dinâmico/injection) | **PASS** (por construção) | Funções `LANGUAGE sql`, sem `EXECUTE`, sem concatenação — parâmetros sempre ligados diretamente |
| SD10 (não recupera linhas arbitrárias) | **PASS** | `pg_typeof(...)` confirma tipo de retorno `boolean` |
| SD11 (owner explicitamente conhecido) | **PASS** | `pg_proc`/`pg_roles`: owner = `contifisc_rls_mediator` nas 2 funções |
| SD12 (comportamento com `FORCE RLS` demonstrado empiricamente) | **PASS** | função idêntica criada com owner **sem** `BYPASSRLS` retornou `false` para uma concessão real (deveria ser `true`) — prova direta de que `BYPASSRLS` no owner é indispensável, `SECURITY DEFINER` sozinho não basta sob `FORCE ROW LEVEL SECURITY` |
| SD13 (runtime sem `BYPASSRLS`) | **PASS** | `pg_roles.rolbypassrls = false` para `contifisc_app_test` |
| SD14 (runtime não é dono das tabelas protegidas) | **PASS** | dono de `tenant`/`conta_acesso_tenant`/`vinculo_extremidade` = `postgres`, não `contifisc_app_test` |
| SD15 (`app.current_tenant_id` forjado não concede acesso via a função corrigida) | **PASS** | com `app.current_conta_acesso_id` válido e `app.current_tenant_id` ausente ou inválido, `tenant` continua retornando exatamente o tenant correto — confirma que a policy de `tenant` não depende mais dessa variável |

## 5. Resultado C1/C2/C3

| Achado | Status | Evidência |
|---|---|---|
| **C1** (recursão infinita `vinculo_extremidade`) | **CORRIGIDO E REVALIDADO** | Leitura completa de `vinculo`/`vinculo_extremidade` sem erro, retornando exatamente os 2 vínculos esperados (nunca o residual sem UE) — reproduzido em 2 execuções independentes |
| **C2** (policy `tenant` acoplada a `app.current_tenant_id`) | **CORRIGIDO E REVALIDADO** | Com **apenas** `app.current_conta_acesso_id` setado (sem `app.current_tenant_id`), `tenant` retorna corretamente o Tenant A — reproduzido em 2 execuções independentes |
| **C3** (INSERT de `Vinculo` novo estruturalmente impossível) | **CORRIGIDO E REVALIDADO** | Criação ponta a ponta de um `Vinculo` novo + 2 `VinculoExtremidade`, como `contifisc_app_test`, em uma única transação — sucesso, linha visível após `COMMIT`; extremidade UE de outro tenant continua rejeitada; `ADR-C005` (cardinalidade exata) continua ativo e rejeitando vínculo incompleto |

## 6. Regressão completa (item 10/11 do prompt)

Reexecutados integralmente `02_tests_sequential.sql` + `03_tests_persistence.sql` (T01-T47, exceto
T22/pooled Neon, deliberadamente não tocado) na 1ª e na 2ª execução — **todos os resultados
idênticos ao `RLS_POC_REPORT.md` original**, exceto exatamente as 3 correções (C1/C2/C3). Nenhuma
regressão nova encontrada em: `Tenant`, `ContaAcesso`, `ContaAcessoTenant`,
`ContaAcessoUnidadeEconomica`, `UnidadeEconomica`, `ADR-C005`, `ADR-C014`, fail-closed (ausência/
inválido/inexistente/sem concessão em todas as variantes), `SET LOCAL` pós-`COMMIT`/`ROLLBACK`,
reutilização de conexão, concorrência real (2 conexões simultâneas, sobreposição confirmada por
`pg_sleep`), `SELECT` sem `WHERE`, `INSERT`/`UPDATE`/`DELETE` cross-tenant.

## 7. Prisma (item 13)

Reexecutado `04_prisma_test.mjs` (3 sub-testes: `SET LOCAL`+query na mesma `$transaction`;
nova `$transaction` sem novo `SET LOCAL`; `$transaction` com Tenant B) contra o container
corrigido — **resultado idêntico ao original**, confirmando que a introdução das funções
`SECURITY DEFINER` não altera a garantia já validada de mesma conexão durante `$transaction()`.

## 8. Segunda execução (item 14)

Container `contifisc-rls-fix4`, criado do zero após destruir o anterior. Checksums de
`migration.sql` (baseline e RLS DRAFT corrigido) **idênticos** entre a 1ª e a 2ª execução.
Introspecção reproduzida (25 tabelas, **30 policies** — 24 originais menos as 2 antigas `FOR ALL`
de `vinculo`/`vinculo_extremidade` mais as 8 novas policies separadas por comando = 30). C1, C2 e
C3 reproduzidos com resultado idêntico.

## 9. D8 / Provisioning (item 7)

Não alterado nesta correção — `contifisc_provisioning` continua **proposto, não criado**, nem no
DRAFT nem no Neon. `contifisc_rls_mediator` (novo nesta correção) é **explicitamente distinto**:
não é role de runtime, não é role de migration/admin, não é role de provisioning — sua única
responsabilidade é ser dono das 2 funções de mediação, nunca usado para nenhuma outra finalidade,
nunca recebe `LOGIN`.

## 10. Neon — confirmação de zero alteração

Nenhum `CREATE FUNCTION`, `CREATE POLICY`, `ALTER TABLE ... ROW LEVEL SECURITY`, `CREATE ROLE`,
`GRANT` ou `REVOKE` foi executado contra o Neon DEV nesta correção — toda a atividade ocorreu
exclusivamente nos 4 containers PostgreSQL 15 descartáveis (`contifisc-rls-fix1..4`), todos
destruídos ao final junto com seus volumes.

## 11. Classificação final

| Severidade | Quantidade | Itens |
|---|---|---|
| `CRITICAL` | 0 | C1, C2, C3 — todos corrigidos e revalidados com evidência empírica (nenhum rebaixado por solução apenas teórica) |
| `RELEVANTE` | 0 | — |
| `MENOR` | 1 | T22 (Neon pooled) continua não executado — decisão deliberada, não falha |

## 12. Artefatos desta correção

- `RLS_POC_CORRECTION_REPORT.md` (este arquivo)
- Migration DRAFT corrigida (mesmo arquivo de antes, editado — evidência da versão com bug
  preservada em `RLS_POC_REPORT.md`, que **não foi apagado**)
- `packages/core/prisma/rls/poc/05_sd_abuse_tests.sql` (novo)
- Reuso de `01_fixture.sql`, `02_tests_sequential.sql`, `03_tests_persistence.sql`,
  `04_prisma_test.mjs` já existentes

## 13. Gate

```
RLS PÓS-SEC — CORREÇÕES DO PoC VALIDADAS E APTAS PARA REVISÃO PRÉ-NEON
```

Todos os critérios do gate (item 18 do prompt) atendidos: C1/C2 resolvidos empiricamente (+ C3,
descoberto e resolvido dentro do mesmo escopo autorizado); `CRITICAL=0`/`RELEVANTE=0`; fail-closed
preservado; `SECURITY DEFINER` hardened (15/15 testes SD); `PUBLIC` sem `EXECUTE`; runtime sem
`BYPASSRLS`; runtime não é dono; `search_path` protegido (empiricamente, inclusive contra objeto
homônimo); policy de `tenant` independente do tenant ativo; `Vinculo` sem recursão e com fluxo de
criação funcional; `ADR-C005`/`ADR-C014` preservados; Prisma preservado; concorrência/reuso
preservados; segunda execução reproduzida; Neon intocado.
