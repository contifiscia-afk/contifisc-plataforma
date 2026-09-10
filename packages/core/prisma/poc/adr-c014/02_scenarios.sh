#!/bin/bash
# ============================================================================
# PoC ADR-C014 -- cenarios funcionais A-H (EXPERIMENTAL, descartavel)
# Uso: ./02_scenarios.sh <container_name>
# Roda contra o schema ja aplicado (00_schema_naive.sql ou 01_schema_fixed.sql)
# em <container_name>. Nao aplica nada a banco persistente.
# ============================================================================
set -u
CONTAINER="${1:?uso: 02_scenarios.sh <container_name>}"
DB="poc_adr_c014"
PSQL="docker exec -i $CONTAINER psql -U postgres -d $DB -v ON_ERROR_STOP=1"
PSQL_NOSTOP="docker exec -i $CONTAINER psql -U postgres -d $DB"

run() {
  local label="$1"; shift
  echo "=== $label ==="
  echo "$1" | $PSQL_NOSTOP 2>&1
  echo ""
}

# ---------------------------------------------------------------------------
# Seed: T1, T2, U1(T1), U2(T2), U3(T1), C1 (com CAT em T1), C2 (sem CAT)
# ---------------------------------------------------------------------------
run "SEED" "
BEGIN;
INSERT INTO tenant (id) VALUES
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222');
INSERT INTO unidade_economica (id, tenant_id) VALUES
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111'),
  ('a2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222'),
  ('a3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111');
INSERT INTO conta_acesso (id) VALUES
  ('c1111111-1111-1111-1111-111111111111'),
  ('c2222222-2222-2222-2222-222222222222');
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel) VALUES
  ('d1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'ADMIN');
COMMIT;
SELECT 'seed ok' AS resultado;
"

# ---------------------------------------------------------------------------
# CASO A -- valido: C1 autorizado em T1, U1 pertence a T1 -> deve suceder
# ---------------------------------------------------------------------------
run "CASO A (valido: C1 x U1, C1 autorizado em T1, U1 em T1)" "
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('e0000001-0000-0000-0000-000000000001', 'c1111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', 'LEITURA');
COMMIT;
SELECT 'CASO A: ' || CASE WHEN EXISTS (SELECT 1 FROM conta_acesso_unidade_economica WHERE id='e0000001-0000-0000-0000-000000000001') THEN 'ACEITO (esperado)' ELSE 'REJEITADO (inesperado)' END AS resultado;
"

# ---------------------------------------------------------------------------
# CASO B -- invalido: C2 nao possui NENHUM ContaAcessoTenant
# ---------------------------------------------------------------------------
run "CASO B (invalido: C2 x U1, C2 sem nenhuma concessao de tenant)" "
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('e0000002-0000-0000-0000-000000000002', 'c2222222-2222-2222-2222-222222222222', 'a1111111-1111-1111-1111-111111111111', 'LEITURA');
COMMIT;
"

# ---------------------------------------------------------------------------
# CASO C -- invalido: C1 autorizado em T1, mas U2 pertence a T2 (tenant errado)
# ---------------------------------------------------------------------------
run "CASO C (invalido: C1 x U2, C1 autorizado em T1, U2 pertence a T2)" "
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('e0000003-0000-0000-0000-000000000003', 'c1111111-1111-1111-1111-111111111111', 'a2222222-2222-2222-2222-222222222222', 'LEITURA');
COMMIT;
"

# ---------------------------------------------------------------------------
# CASO D -- remover ContaAcessoTenant enquanto existe ContaAcessoUnidadeEconomica dependente
# (depende do CASO A ter deixado e0000001 comitado)
# ---------------------------------------------------------------------------
run "CASO D (remover ContaAcessoTenant C1xT1 enquanto CASO A ainda depende dele)" "
BEGIN;
DELETE FROM conta_acesso_tenant WHERE conta_acesso_id = 'c1111111-1111-1111-1111-111111111111' AND tenant_id = '11111111-1111-1111-1111-111111111111';
COMMIT;
"

# ---------------------------------------------------------------------------
# CASO E -- transacao deferida VALIDA: insere CAUE antes, CAT depois, na mesma transacao
# ---------------------------------------------------------------------------
run "CASO E (deferido valido: C2 x U2 sem CAT -> insere CAT(C2,T2) na MESMA transacao)" "
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('e0000005-0000-0000-0000-000000000005', 'c2222222-2222-2222-2222-222222222222', 'a2222222-2222-2222-2222-222222222222', 'LEITURA');
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
VALUES ('d0000005-0000-0000-0000-000000000005', 'c2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'OPERADOR');
COMMIT;
SELECT 'CASO E: ' || CASE WHEN EXISTS (SELECT 1 FROM conta_acesso_unidade_economica WHERE id='e0000005-0000-0000-0000-000000000005') THEN 'ACEITO (esperado)' ELSE 'REJEITADO (inesperado)' END AS resultado;
-- limpeza (fora da transacao de teste, nao afeta o resultado acima)
BEGIN;
DELETE FROM conta_acesso_unidade_economica WHERE id = 'e0000005-0000-0000-0000-000000000005';
DELETE FROM conta_acesso_tenant WHERE id = 'd0000005-0000-0000-0000-000000000005';
COMMIT;
"

# ---------------------------------------------------------------------------
# CASO F -- transacao deferida INVALIDA: insere CAUE sem nunca criar o CAT
# ---------------------------------------------------------------------------
run "CASO F (deferido invalido: C2 x U3, sem CAT(C2,T1) em nenhum momento da transacao)" "
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('e0000006-0000-0000-0000-000000000006', 'c2222222-2222-2222-2222-222222222222', 'a3333333-3333-3333-3333-333333333333', 'LEITURA');
COMMIT;
"

# ---------------------------------------------------------------------------
# CASO G -- mudanca de unidade_economica_id (defesa em profundidade; POLITICA
# CANONICA declara este campo Imutavel -- N/A em uso normal, testado apenas
# para confirmar que o trigger tambem cobre este caminho caso alguem o force)
# ---------------------------------------------------------------------------
run "CASO G (defesa em profundidade: mover CAUE de U1(T1) para U2(T2) sem CAT(C1,T2))" "
BEGIN;
UPDATE conta_acesso_unidade_economica
SET unidade_economica_id = 'a2222222-2222-2222-2222-222222222222'
WHERE id = 'e0000001-0000-0000-0000-000000000001';
COMMIT;
"

# ---------------------------------------------------------------------------
# Re-cria CAT(C1,T1) que o CASO D tentou (e nao deveria ter conseguido) remover,
# e confere que o CASO A/G deixaram o estado esperado antes do CASO H.
# ---------------------------------------------------------------------------
run "VERIFICACAO INTERMEDIARIA (estado apos A-G)" "
SELECT 'CAT(C1,T1) ainda existe: ' || EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='c1111111-1111-1111-1111-111111111111' AND tenant_id='11111111-1111-1111-1111-111111111111') AS cat_c1_t1;
SELECT 'CAUE e0000001 ainda aponta para U1: ' || EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='e0000001-0000-0000-0000-000000000001' AND unidade_economica_id='a1111111-1111-1111-1111-111111111111') AS caue_ainda_u1;
"

# ---------------------------------------------------------------------------
# CASO H1 -- mudar unidade_economica.tenant_id quando existe CAUE dependente,
# SEM criar a concessao correspondente no novo tenant -> deve falhar
# ---------------------------------------------------------------------------
run "CASO H1 (mover U1 de T1 para T2 sem CAT(C1,T2) -- deve falhar, orfanaria e0000001)" "
BEGIN;
UPDATE unidade_economica SET tenant_id = '22222222-2222-2222-2222-222222222222' WHERE id = 'a1111111-1111-1111-1111-111111111111';
COMMIT;
"

# ---------------------------------------------------------------------------
# CASO H2 -- mesma mudanca de tenant, mas criando a concessao correspondente
# na MESMA transacao -> estado final coerente, deve suceder
# ---------------------------------------------------------------------------
run "CASO H2 (mover U1 de T1 para T2 E inserir CAT(C1,T2) na mesma transacao -- deve suceder)" "
BEGIN;
UPDATE unidade_economica SET tenant_id = '22222222-2222-2222-2222-222222222222' WHERE id = 'a1111111-1111-1111-1111-111111111111';
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
VALUES ('d0000008-0000-0000-0000-000000000008', 'c1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'ADMIN');
COMMIT;
SELECT 'CASO H2: ' || CASE WHEN (SELECT tenant_id FROM unidade_economica WHERE id='a1111111-1111-1111-1111-111111111111') = '22222222-2222-2222-2222-222222222222' THEN 'ACEITO (esperado)' ELSE 'REJEITADO (inesperado)' END AS resultado;
-- reverte para nao contaminar testes seguintes (concorrencia usa um container proprio de qualquer forma)
BEGIN;
DELETE FROM conta_acesso_tenant WHERE id = 'd0000008-0000-0000-0000-000000000008';
UPDATE unidade_economica SET tenant_id = '11111111-1111-1111-1111-111111111111' WHERE id = 'a1111111-1111-1111-1111-111111111111';
COMMIT;
"

echo "=== FIM DOS CENARIOS A-H ==="
