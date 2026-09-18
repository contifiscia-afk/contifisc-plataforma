\echo '--- current_user/session_user ---'
SELECT current_user, session_user;

\echo '--- A: criar mediator + criar funcao simples + GRANT ... TO CURRENT_USER + ALTER FUNCTION OWNER TO ---'
CREATE TABLE t_dummy (id int);
CREATE OR REPLACE FUNCTION fn_dummy() RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = pg_catalog, public AS $$ SELECT true; $$;

CREATE ROLE contifisc_rls_mediator_test NOSUPERUSER NOLOGIN BYPASSRLS;
GRANT contifisc_rls_mediator_test TO CURRENT_USER;
\echo '--- GRANT TO CURRENT_USER executado sem erro? (ver acima) ---'

ALTER FUNCTION fn_dummy() OWNER TO contifisc_rls_mediator_test;
\echo '--- A RESULTADO: ALTER FUNCTION OWNER TO apos GRANT ---'
SELECT p.proname, r.rolname AS owner FROM pg_proc p JOIN pg_roles r ON r.oid=p.proowner WHERE p.proname='fn_dummy';

\echo '--- confirmar SET ROLE funciona ANTES do revoke ---'
SET ROLE contifisc_rls_mediator_test;
SELECT current_user;
RESET ROLE;

\echo '--- B: revogar membership apos o ALTER FUNCTION ---'
REVOKE contifisc_rls_mediator_test FROM CURRENT_USER;
\echo '--- B RESULTADO: REVOKE executado sem erro? (ver acima) ---'

\echo '--- C: funcao ainda pertence ao mediator apos o REVOKE? ---'
SELECT p.proname, r.rolname AS owner FROM pg_proc p JOIN pg_roles r ON r.oid=p.proowner WHERE p.proname='fn_dummy';

\echo '--- D: migration owner ainda consegue SET ROLE mediator depois do REVOKE? (deve falhar) ---'
SET ROLE contifisc_rls_mediator_test;
