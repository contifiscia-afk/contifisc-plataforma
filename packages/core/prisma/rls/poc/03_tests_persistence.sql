\echo '=== T18/T42 (retry, UUID corrigido): ContaAcessoUnidadeEconomica sem ContaAcessoTenant -> ADR-C014 rejeita ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000bb';
SET LOCAL app.current_tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('bb000000-0000-0000-0000-0000000000ff', 'cccccccc-0000-0000-0000-0000000000bb', 'eeeeeeee-0000-0000-0000-00000000000a', 'RESTRITO_UE');
ROLLBACK;

\echo '=== T20/T43: SET LOCAL nao sobrevive ao COMMIT (mesma sessao, nova transacao) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT count(*) AS visto_na_transacao_1 FROM receita;
COMMIT;
-- nova transacao, SEM novo SET LOCAL
BEGIN;
SELECT count(*) AS visto_na_transacao_2_pos_commit_sem_set_local FROM receita;
ROLLBACK;

\echo '=== T44: SET LOCAL nao sobrevive ao ROLLBACK (mesma sessao, nova transacao) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT count(*) AS visto_na_transacao_1 FROM receita;
ROLLBACK;
BEGIN;
SELECT count(*) AS visto_na_transacao_2_pos_rollback_sem_set_local FROM receita;
ROLLBACK;

\echo '=== T21: conexao reutilizada, Tenant A depois Tenant B, sem residuo ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT id AS tenant_a_ve FROM receita;
COMMIT;
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000bb';
SET LOCAL app.current_tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
SELECT id AS tenant_b_ve_sem_residuo_de_a FROM receita;
ROLLBACK;
