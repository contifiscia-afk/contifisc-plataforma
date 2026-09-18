-- Executado como contifisc_app_test (NOSUPERUSER, NOBYPASSRLS) — RLS se aplica integralmente.
-- Cada bloco: \echo do teste, BEGIN, SET LOCAL, query, COMMIT/ROLLBACK.

\echo '=== T04: ausencia total de contexto -> 0 linhas em toda tabela tenant-scoped ==='
BEGIN;
SELECT 'receita' t, count(*) FROM receita
UNION ALL SELECT 'tenant', count(*) FROM tenant
UNION ALL SELECT 'arquivo_origem', count(*) FROM arquivo_origem
UNION ALL SELECT 'unidade_economica', count(*) FROM unidade_economica;
ROLLBACK;

\echo '=== T29: GLOBAL_COMPARTILHADO visivel mesmo sem contexto ==='
BEGIN;
SELECT 'pessoa_fisica' t, count(*) FROM pessoa_fisica
UNION ALL SELECT 'pessoa_juridica', count(*) FROM pessoa_juridica
UNION ALL SELECT 'fonte_pagadora', count(*) FROM fonte_pagadora
UNION ALL SELECT 'conta_acesso', count(*) FROM conta_acesso;
ROLLBACK;

\echo '=== T30: evento_auditoria_seguranca bloqueada (zero policies) mesmo com contexto valido ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT count(*) FROM evento_auditoria_seguranca;
ROLLBACK;

\echo '=== T01/T02/T03: Tenant A le so seus fatos, nao le fatos do Tenant B ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT id, valor_receita_bruta FROM receita ORDER BY id;
ROLLBACK;
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000bb';
SET LOCAL app.current_tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
SELECT id, valor_receita_bruta FROM receita ORDER BY id;
ROLLBACK;

\echo '=== T05: tenant_id valido em formato mas inexistente -> 0 linhas ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
SELECT count(*) FROM receita;
ROLLBACK;

\echo '=== T06/T07: INSERT proprio permitido, INSERT cross-tenant rejeitado ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
INSERT INTO receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id)
VALUES ('11111111-0000-0000-0000-0000000000f1', 50.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', 'eeeeeeee-0000-0000-0000-00000000000a');
\echo '--- insert proprio: deve ter inserido 1 linha ---'
ROLLBACK;
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
\echo '--- tentando INSERT em receita apontando para UE-B (Tenant B) com contexto ativo = Tenant A ---'
INSERT INTO receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id)
VALUES ('11111111-0000-0000-0000-0000000000f2', 50.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', 'eeeeeeee-0000-0000-0000-00000000000b');
ROLLBACK;

\echo '=== T08/T09: UPDATE proprio permitido, UPDATE cross-tenant nao afeta linhas ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
UPDATE receita SET valor_receita_bruta = 9999.00 WHERE id = '11111111-0000-0000-0000-00000000000a';
\echo '--- update proprio: linhas afetadas deve ser 1 ---'
UPDATE receita SET valor_receita_bruta = 8888.00 WHERE id = '11111111-0000-0000-0000-00000000000b';
\echo '--- update cross-tenant (linha da UE-B, invisivel): linhas afetadas deve ser 0 ---'
ROLLBACK;

\echo '=== T10: UPDATE tentando mover UnidadeEconomica de A para tenant B rejeitado por WITH CHECK ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
UPDATE unidade_economica SET tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b' WHERE id = 'eeeeeeee-0000-0000-0000-00000000000a';
ROLLBACK;

\echo '=== T11/T12: DELETE proprio permitido, DELETE cross-tenant nao afeta linhas ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
DELETE FROM conflito_dado WHERE id = '77777777-0000-0000-0000-00000000000a';
\echo '--- delete proprio: linhas afetadas deve ser 1 ---'
DELETE FROM conflito_dado WHERE id = '77777777-0000-0000-0000-00000000000b';
\echo '--- delete cross-tenant: linhas afetadas deve ser 0 ---'
ROLLBACK;

\echo '=== T13: tenant derivado por UE respeitado em varias tabelas (contexto = Tenant A) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT 'documento_fiscal' t, count(*) FROM documento_fiscal
UNION ALL SELECT 'cenario_tributario', count(*) FROM cenario_tributario
UNION ALL SELECT 'resultado_calculo', count(*) FROM resultado_calculo
UNION ALL SELECT 'receita_documento_fiscal', count(*) FROM receita_documento_fiscal
UNION ALL SELECT 'documento_fiscal_arquivo_origem', count(*) FROM documento_fiscal_arquivo_origem
UNION ALL SELECT 'classificacao_equiparacao_hospitalar', count(*) FROM classificacao_equiparacao_hospitalar;
ROLLBACK;

\echo '=== T14: conflito_dado_item deriva SOMENTE do pai, ignora objeto_id polimorfico apontando p/ outro tenant ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT id, conflito_dado_id, objeto_id FROM conflito_dado_item ORDER BY id;
\echo '--- esperado: ver os 2 itens do conflito_dado A (88...a e 88...c), mesmo o item c apontando objeto_id de receita do Tenant B ---'
ROLLBACK;

\echo '=== T15/T16/T17: tenant materializado (arquivo_origem, revisao_tecnica, conflito_dado) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT 'arquivo_origem' t, count(*) FROM arquivo_origem
UNION ALL SELECT 'revisao_tecnica', count(*) FROM revisao_tecnica
UNION ALL SELECT 'conflito_dado', count(*) FROM conflito_dado;
ROLLBACK;

\echo '=== T25: SELECT * sem WHERE nao vaza dado (RLS filtra automaticamente) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000bb';
SET LOCAL app.current_tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
SELECT * FROM receita;
\echo '--- esperado: so a linha 11111111-...000b (UE-B), mesmo sem WHERE ---'
ROLLBACK;

\echo '=== T26/T27/T28: Vinculo/VinculoExtremidade — 2 UE, 1 UE+1 PF (deriva da irma), 0 UE (invisivel) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT id FROM vinculo ORDER BY id;
\echo '--- esperado: aa...0001a (2 UE) e aa...0002a (1UE+1PF); NUNCA aa...0003a (0 UE, exceção residual, T28) ---'
SELECT id, unidade_economica_id, pessoa_fisica_id, pessoa_juridica_id FROM vinculo_extremidade ORDER BY id;
\echo '--- esperado: as 4 extremidades dos vinculos 0001a/0002a; nunca as de 0003a ---'
ROLLBACK;

\echo '=== T18/T42: ContaAcessoUnidadeEconomica sem ContaAcessoTenant correspondente -> ADR-C014 rejeita, independente da RLS ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000bb';
SET LOCAL app.current_tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
\echo '--- Conta B tem concessao em Tenant B, mas NAO em Tenant A. Tentando restringir Conta B a UE-A (Tenant A) ---'
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('bb000000-0000-0000-0000-0000000000ff', 'cccccccc-0000-0000-0000-0000000000bb', 'eeeeeeee-0000-0000-0000-00000000000a', 'RESTRITO_UE');
ROLLBACK;

\echo '=== T24 (parte 1): conta_acesso_unidade_economica ja existente (Conta A / UE-A) visivel sob RLS ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT count(*) FROM conta_acesso_unidade_economica;
ROLLBACK;

\echo '=== T32/T33: Tenant policy — Conta A ve Tenant A; Conta A tentando ver Tenant B sem concessao -> 0 ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SELECT id FROM tenant ORDER BY id;
\echo '--- esperado: so aaaaaaaa...000a, mesmo SEM app.current_tenant_id setado (T37-equivalente p/ tenant) ---'
ROLLBACK;

\echo '=== T34: conta bem formada mas inexistente em conta_acesso -> 0 tenants ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = '00000000-9999-9999-9999-999999999999';
SELECT count(*) FROM tenant;
ROLLBACK;

\echo '=== T36: conta ausente (nunca setada) -> 0 tenants ==='
BEGIN;
SELECT count(*) FROM tenant;
ROLLBACK;

\echo '=== T38: tenant com formato invalido -> 0 linhas, SEM ERRO (valida funcao segura, achado D7) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'isso-nao-e-um-uuid';
SELECT count(*) FROM receita;
\echo '--- se chegou aqui sem erro, a funcao segura funcionou (D7 confirmado) ---'
ROLLBACK;

\echo '=== T39: conta_acesso_id valido mas SEM NENHUMA concessao (Conta C) -> 0 tenants ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000cc';
SELECT count(*) FROM tenant;
ROLLBACK;

\echo '=== T40/T41: UE do tenant correto visivel, UE de outro tenant invisivel (mesmo contexto) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
SELECT id FROM receita WHERE unidade_economica_id = 'eeeeeeee-0000-0000-0000-00000000000a';
\echo '--- esperado: 1 linha (UE-A) ---'
SELECT id FROM receita WHERE unidade_economica_id = 'eeeeeeee-0000-0000-0000-00000000000b';
\echo '--- esperado: 0 linhas (UE-B, outro tenant) ---'
ROLLBACK;

\echo '=== T46: tentativa de forjar tenant_id (Conta A, mas tenant=B, sem concessao real em B) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa';
SET LOCAL app.current_tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
SELECT count(*) FROM receita;
\echo '--- esperado: 0 linhas -- policy de receita usa app.current_tenant_id (nao verifica grant aqui), mas a UE-B pertence ao tenant B que foi "forjado" -- a defesa real esta em nunca permitir a aplicacao setar esse tenant sem grant (nota do TEST_PLAN) ---'
ROLLBACK;

\echo '=== T47: tentativa de forjar conta_acesso_id (conta de outra pessoa, bem formada e existente) ==='
BEGIN;
SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000bb';
SELECT id FROM tenant;
\echo '--- retorna os tenants da conta B (a que foi informada) -- nao ha como a policy distinguir "forjado" de "real"; defesa fica na autenticacao, nao na RLS (nota do TEST_PLAN) ---'
ROLLBACK;
