# PoC — ADR-C014 (EXPERIMENTAL / DESCARTÁVEL)

**Este diretório é um experimento isolado. Nada aqui é parte da baseline canônica, do
`schema.prisma` aprovado, ou de qualquer migration real.**

- Não é aplicado a nenhum banco persistente.
- Não é referenciado por `packages/core/prisma/schema.prisma`.
- Não é incorporado a `packages/core/prisma/migrations/`.
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
  mecanismo `ADR-C014`, usada para demonstrar a janela de corrida de concorrência.
- `01_schema_fixed.sql` — mesmo schema, com a correção de lock (`FOR KEY SHARE`) aplicada à
  função de verificação — versão final recomendada.
- `02_scenarios.sql` — os 8 cenários funcionais (A–H) em SQL puro, roda contra qualquer uma das
  duas versões do schema.
- `03_concurrency_naive.sh` / `03_concurrency_fixed.sh` — scripts de teste de concorrência (duas
  sessões `psql` concorrentes), rodados contra a versão ingênua e contra a versão corrigida.
- `04_prisma_test.mjs` — testes via Prisma Client (`$transaction`) contra a versão corrigida.
- `ADR-C014_POC_REPORT.md` — relatório completo (hipótese, SQL, cenários, resultados,
  concorrência, repetibilidade, limitações, recomendação, gate).

## Como este PoC foi executado

Container PostgreSQL 15 descartável via Docker, mesma metodologia já usada para `ADR-C005`
(`packages/core/prisma/migrations/20260901120000_init_baseline_fisica/INTEGRATION_TEST_REPORT.md`).
Ver o relatório para o log completo de comandos, versões e resultados.
