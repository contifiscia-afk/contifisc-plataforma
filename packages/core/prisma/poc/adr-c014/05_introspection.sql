-- ============================================================================
-- PoC ADR-C014 -- introspeccao do catalogo PostgreSQL (EXPERIMENTAL)
-- ============================================================================

-- Existencia e propriedades dos CONSTRAINT TRIGGERs
SELECT
  tgname AS trigger_name,
  tgrelid::regclass AS tabela,
  tgdeferrable,
  tginitdeferred,
  tgconstraint <> 0 AS eh_constraint_trigger,
  pg_get_triggerdef(oid) AS definicao
FROM pg_trigger
WHERE tgname LIKE 'adr_c014%'
ORDER BY tgrelid::regclass::text, tgname;

-- Funcoes associadas
SELECT proname, prosrc IS NOT NULL AS tem_corpo
FROM pg_proc
WHERE proname LIKE 'trg_%'
ORDER BY proname;

-- FKs e UNIQUEs esperadas nas 5 tabelas do PoC
SELECT
  conname,
  contype, -- f = foreign key, u = unique, p = primary key
  conrelid::regclass AS tabela,
  pg_get_constraintdef(oid) AS definicao
FROM pg_constraint
WHERE conrelid::regclass::text IN (
  'tenant', 'unidade_economica', 'conta_acesso', 'conta_acesso_tenant', 'conta_acesso_unidade_economica'
)
ORDER BY conrelid::regclass::text, contype, conname;

-- Contagem de tabelas do PoC (deve ser exatamente 5)
SELECT count(*) AS total_tabelas_poc
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('tenant', 'unidade_economica', 'conta_acesso', 'conta_acesso_tenant', 'conta_acesso_unidade_economica');
