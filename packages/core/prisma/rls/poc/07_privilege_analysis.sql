-- Analise tecnica isolada (fora do schema RLS real) do ciclo de
-- membership necessario para ALTER FUNCTION ... OWNER TO sob um role
-- nao-superuser, mimetizando neondb_owner. Executado como postgres so
-- para bootstrap (CREATE ROLE/DATABASE); o resto roda como o role de teste.

CREATE ROLE contifisc_test_migration_owner LOGIN NOSUPERUSER NOBYPASSRLS CREATEROLE PASSWORD 'test';
CREATE DATABASE priv_analysis OWNER contifisc_test_migration_owner;
