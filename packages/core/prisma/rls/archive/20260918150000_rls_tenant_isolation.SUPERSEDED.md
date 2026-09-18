# TOMBSTONE — migration 20260918150000_rls_tenant_isolation (SUPERSEDED, ROLLED BACK)

Este arquivo NÃO é uma migration (fica fora de `prisma/migrations/`, o Prisma o ignora). Serve
apenas para preservar a rastreabilidade da tentativa histórica registrada no Neon DEV.

| Campo | Valor |
|---|---|
| migration_name (Neon DEV `_prisma_migrations`) | `20260918150000_rls_tenant_isolation` |
| Status | FAILED → RESOLVED AS ROLLED BACK (`prisma migrate resolve --rolled-back`) |
| Checksum da tentativa | `a82e3c088e9f8ea37eba4087f2303e83e2dcab48e2ba4d9a443f5ba183d255f9` |
| Causa da falha | ownership: `ALTER FUNCTION ... OWNER TO contifisc_rls_mediator` sob `neondb_owner` (não-superuser) — sem `SET ROLE` para o novo dono (e sem `CREATE` do novo dono no schema) |
| Efeito físico no Neon | nenhum (transação DDL revertida; banco permaneceu na baseline pós-SEC) |
| Registro no Neon | a linha PERMANECE em `_prisma_migrations` (não apagada, não editada) |
| Reuso do nome | PROIBIDO — nome terminal no histórico do Prisma |
| Substituída por | `20260918160000_rls_tenant_isolation_privilege_fix` (SQL corrigido, validado 2x em PG18.6 com migration owner não-superuser) |

O conteúdo original da tentativa (checksum `a82e3c08...255f9`) não é mais candidato a deploy. O
SQL corrigido vive somente na nova pasta de migration.
