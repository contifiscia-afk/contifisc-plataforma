# PoC — ADR-C014 (EXPERIMENTAL / DESCARTÁVEL)

**Este diretório é um experimento isolado. Nada aqui é parte da baseline canônica, do
`schema.prisma` aprovado, ou de qualquer migration real.**

- Não é aplicado a nenhum banco persistente.
- Não é referenciado por `packages/core/prisma/schema.prisma`.
- Nenhum arquivo deste diretório é incorporado por referência em
  `packages/core/prisma/migrations/` — a migration inaugural pós-SEC
  (`20260908120000_init_baseline_fisica_pos_sec/migration.sql`) porta manualmente, byte-a-byte e
  **sem nenhuma instrumentação de teste**, apenas a lógica SQL da variante **CANDIDATA**
  (`01_schema_fixed.sql`) — nunca a variante ingênua, nunca os arquivos instrumentados. É essa
  implementação incorporada na migration inaugural, e somente ela, que está autorizada para o
  baseline físico.
- Todo o SQL aqui roda exclusivamente em containers PostgreSQL descartáveis, destruídos ao final
  do teste.

## Objetivo

Validar empiricamente, em PostgreSQL >= 15 real, o invariante `ADR-C014` (`ADR-001` V1.1
§5.2/§5.3): uma linha de `conta_acesso_unidade_economica` só pode existir se houver uma linha de
`conta_acesso_tenant` para o mesmo `conta_acesso_id` e o `tenant_id` da `unidade_economica`
referenciada — "restrição por UE nunca cria autorização de Tenant, apenas restringe uma já
existente".

## Arquivos

- `00_schema_naive.sql` — schema mínimo (5 tabelas) + versão **ingênua** (sem lock explícito) do
  mecanismo `ADR-C014`. **Experimental — demonstra a janela de corrida (race condition); nunca
  deve ser usada como base para SQL de produção.**
- `01_schema_fixed.sql` — mesmo schema, com a correção de lock (`FOR KEY SHARE`) aplicada à
  função `trg_caue_requires_grant_fixed` — variante **candidata**, empiricamente validada por
  este PoC. É esta lógica (sem nenhuma instrumentação de teste) que foi portada para a migration
  inaugural pós-SEC.
- `02_scenarios.sh` — os 8 cenários funcionais (A–H) em SQL puro, executados contra o container
  onde `00_schema_naive.sql` ou `01_schema_fixed.sql` já foi aplicado. Uso:
  `./02_scenarios.sh <container_name>`.
- `03_concurrency.sh` — primeira tentativa de teste de concorrência, com duas sessões `psql`
  coordenadas via FIFO para forçar uma interleaving específica. Abandonada nesta forma (limitação
  do ambiente Windows/Git Bash com `mkfifo`) e substituída pela técnica de instrumentação por
  atraso usada em `06_instrumented_naive.sql`/`07_run_races.sh` e
  `08_instrumented_candidate.sql`/`09_run_races_candidate.sh`. Mantido como registro histórico da
  tentativa, não como método de execução vigente.
- `04_prisma_test.mjs` — testes via Prisma Client (`$transaction()`) contra a variante candidata
  (`01_schema_fixed.sql`), usando o schema Prisma isolado `poc-schema.prisma`.
- `05_introspection.sql` — introspecção do catálogo PostgreSQL (`pg_trigger`), confirmando
  existência, `DEFERRABLE`/`INITIALLY DEFERRED` e definição dos constraint triggers `adr_c014_*`.
- `06_instrumented_naive.sql` — instrumentação de teste, **exclusiva do arnês de PoC, nunca de
  produção**: mesma lógica da variante ingênua, com um `pg_sleep()` inserido entre a checagem de
  "estado seguro" e o `RETURN`, para tornar deterministicamente observável a janela de corrida.
  Aplicar somente depois de `00_schema_naive.sql` já estar carregado.
- `07_run_races.sh` — execução orquestrada dos 3 cenários de corrida (Race 1/2/3) contra a
  variante ingênua instrumentada (`06_instrumented_naive.sql`), via duas sessões `psql` lançadas
  como jobs de background do bash (sem FIFO). Uso:
  `./07_run_races.sh <container_name> <race1|race2|race3>`.
- `08_instrumented_candidate.sql` — instrumentação de teste equivalente a
  `06_instrumented_naive.sql`, **exclusiva do arnês de PoC, nunca de produção**, aplicada à
  função da variante candidata (`trg_caue_requires_grant_fixed`), para provar que o lock
  `FOR KEY SHARE` efetivamente bloqueia a operação concorrente mesmo com uma janela
  artificialmente alargada.
- `09_run_races_candidate.sh` — execução dos mesmos 3 cenários de corrida contra a variante
  candidata instrumentada, confirmando o fechamento das janelas de corrida encontradas na
  variante ingênua. Uso: `./09_run_races_candidate.sh <container_name> <race1|race2|race3>`.
- `ADR-C014_POC_REPORT.md` — relatório completo (hipótese, resultado empírico, falha observada,
  correção candidata, validação da correção, concorrência, Prisma, introspecção,
  repetibilidade, limitações, gate).
- `poc-schema.prisma` — schema Prisma isolado deste PoC (gera um client próprio em
  `./generated-client`, nunca o `schema.prisma` canônico do projeto), usado exclusivamente pelos
  testes `$transaction()` de `04_prisma_test.mjs`.

## Como este PoC foi executado

Container PostgreSQL 15 descartável via Docker, mesma metodologia já usada para `ADR-C005`
(`packages/core/prisma/migrations/20260901120000_init_baseline_fisica/INTEGRATION_TEST_REPORT.md`).
Ver `ADR-C014_POC_REPORT.md` para o log completo de comandos, versões e resultados.
