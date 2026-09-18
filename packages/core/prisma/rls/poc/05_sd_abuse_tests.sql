-- Testes de abuso das funcoes SECURITY DEFINER (SD01-SD15), executados como
-- contifisc_app_test (NOSUPERUSER, NOBYPASSRLS), exceto onde indicado.

\echo '=== SD03/SD04: NULL e UUID inexistente falham fechado (chamada direta da funcao) ==='
SELECT contifisc_conta_tem_acesso_tenant(NULL, NULL) AS deve_ser_false;
SELECT contifisc_conta_tem_acesso_tenant('cccccccc-0000-0000-0000-0000000000aa', NULL) AS deve_ser_false;
SELECT contifisc_conta_tem_acesso_tenant('00000000-9999-9999-9999-999999999999', 'aaaaaaaa-0000-0000-0000-00000000000a') AS deve_ser_false_conta_inexistente;
SELECT contifisc_conta_tem_acesso_tenant('cccccccc-0000-0000-0000-0000000000aa', '00000000-9999-9999-9999-999999999999') AS deve_ser_false_tenant_inexistente;

\echo '=== SD05/SD06: conta A + tenant B -> false; conta A + tenant A -> true ==='
SELECT contifisc_conta_tem_acesso_tenant('cccccccc-0000-0000-0000-0000000000aa', 'bbbbbbbb-0000-0000-0000-00000000000b') AS deve_ser_false;
SELECT contifisc_conta_tem_acesso_tenant('cccccccc-0000-0000-0000-0000000000aa', 'aaaaaaaa-0000-0000-0000-00000000000a') AS deve_ser_true;

\echo '=== SD07/SD08: search_path malicioso + objeto homonimo nao alteram a resolucao ==='
CREATE SCHEMA IF NOT EXISTS evil;
CREATE TABLE evil.conta_acesso_tenant (conta_acesso_id uuid, tenant_id uuid, papel text);
INSERT INTO evil.conta_acesso_tenant VALUES ('cccccccc-0000-0000-0000-0000000000aa', 'bbbbbbbb-0000-0000-0000-00000000000b', 'FORJADO');
SET search_path = evil, public;
\echo '--- com search_path=evil,public setado pela SESSAO, a funcao ainda deve resolver contra public.conta_acesso_tenant (nao evil.*) ---'
SELECT contifisc_conta_tem_acesso_tenant('cccccccc-0000-0000-0000-0000000000aa', 'bbbbbbbb-0000-0000-0000-00000000000b') AS deve_continuar_false_ignora_evil;
SELECT contifisc_conta_tem_acesso_tenant('cccccccc-0000-0000-0000-0000000000aa', 'aaaaaaaa-0000-0000-0000-00000000000a') AS deve_continuar_true_via_public;
RESET search_path;
DROP TABLE evil.conta_acesso_tenant;
DROP SCHEMA evil;

\echo '=== SD10: runtime nao consegue usar a funcao para recuperar linhas arbitrarias (retorno e so boolean) ==='
SELECT pg_typeof(contifisc_conta_tem_acesso_tenant('cccccccc-0000-0000-0000-0000000000aa', 'aaaaaaaa-0000-0000-0000-00000000000a')) AS tipo_retorno;

\echo '=== SD15: forjar app.current_tenant_id sozinho NAO concede visibilidade de tenant (policy nao usa mais essa variavel) ==='
BEGIN;
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT count(*) AS deve_ser_zero_sem_conta_acesso_id FROM tenant;
ROLLBACK;
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
SELECT id FROM tenant ORDER BY id;
\echo '--- correcao de C2: tenant_id forjado/invalido nao afeta o resultado -- deve mostrar so aaaaaaaa...000a de qualquer forma ---'
ROLLBACK;

\echo '=== VINCULO: recursao eliminada — leitura completa sem erro (correcao de C1) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT id FROM vinculo ORDER BY id;
\echo '--- esperado: aa...0001a e aa...0002a; nunca aa...0003a (residual, sem UE) ---'
SELECT id, unidade_economica_id, pessoa_fisica_id, pessoa_juridica_id FROM vinculo_extremidade ORDER BY id;
\echo '--- esperado: as 4 extremidades de 0001a/0002a; nunca as de 0003a ---'
ROLLBACK;
