#!/bin/bash
# ============================================================================
# PoC ADR-C014 -- execucao dos cenarios de corrida contra a VARIANTE CANDIDATA
# (01_schema_fixed.sql, trg_caue_requires_grant_fixed com FOR KEY SHARE).
# Uso: ./09_run_races_candidate.sh <container_name> <race1|race2|race3>
# ============================================================================
set -u
CONTAINER="${1:?uso}"
RACE="${2:?uso}"
DB="poc_adr_c014"
WORKDIR=$(mktemp -d)

case "$RACE" in
  race1)
    echo "=== RACE 1 (CANDIDATA): trg_caue_requires_grant_fixed com FOR KEY SHARE (delay apos lock) vs DELETE ContaAcessoTenant concorrente ==="
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 > "$WORKDIR/setup.log" 2>&1 <<'SQL'
DROP TRIGGER IF EXISTS adr_c014_caue_requires_grant ON conta_acesso_unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant
  AFTER INSERT OR UPDATE OF conta_acesso_id, unidade_economica_id ON conta_acesso_unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_fixed_delayed();

DROP TRIGGER IF EXISTS adr_c014_cat_blocks_if_dependents ON conta_acesso_tenant;
CREATE CONSTRAINT TRIGGER adr_c014_cat_blocks_if_dependents
  AFTER DELETE OR UPDATE OF conta_acesso_id, tenant_id ON conta_acesso_tenant
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_cat_blocks_if_dependents();

BEGIN;
INSERT INTO tenant (id) VALUES ('99991001-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO unidade_economica (id, tenant_id) VALUES ('99991001-0000-0000-0000-0000000000a1', '99991001-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso (id) VALUES ('99991001-0000-0000-0000-0000000000c1') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
  VALUES ('99991001-0000-0000-0000-0000000000d1', '99991001-0000-0000-0000-0000000000c1', '99991001-0000-0000-0000-000000000001', 'ADMIN')
  ON CONFLICT DO NOTHING;
COMMIT;
SQL
    cat "$WORKDIR/setup.log"

    cat > "$WORKDIR/sx.sql" <<'SQL'
\timing on
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('99991001-0000-0000-0000-0000000000e1', '99991001-0000-0000-0000-0000000000c1', '99991001-0000-0000-0000-0000000000a1', 'LEITURA');
COMMIT;
SELECT clock_timestamp(), 'X (INSERT CAUE, trigger CANDIDATA com lock+delay) finalizada';
SQL

    cat > "$WORKDIR/sy.sql" <<'SQL'
\timing on
SELECT pg_sleep(1);
BEGIN;
DELETE FROM conta_acesso_tenant WHERE conta_acesso_id='99991001-0000-0000-0000-0000000000c1' AND tenant_id='99991001-0000-0000-0000-000000000001';
COMMIT;
SELECT clock_timestamp(), 'Y (DELETE ContaAcessoTenant, trigger normal) finalizada';
SQL

    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sx.sql" > "$WORKDIR/x.out" 2>&1 &
    PIDX=$!
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sy.sql" > "$WORKDIR/y.out" 2>&1 &
    PIDY=$!
    wait "$PIDX" "$PIDY" 2>/dev/null

    echo "--- SAIDA X ---"; cat "$WORKDIR/x.out"
    echo "--- SAIDA Y ---"; cat "$WORKDIR/y.out"
    echo "--- ESTADO FINAL ---"
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -c "
SELECT
  EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='99991001-0000-0000-0000-0000000000c1' AND tenant_id='99991001-0000-0000-0000-000000000001') AS cat_existe,
  EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='99991001-0000-0000-0000-0000000000e1') AS caue_existe;
"
    ;;

  race2)
    echo "=== RACE 2 (CANDIDATA): trg_cat_blocks_if_dependents (delay) vs INSERT CAUE com trigger fixed (lock) concorrente ==="
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 > "$WORKDIR/setup.log" 2>&1 <<'SQL'
DROP TRIGGER IF EXISTS adr_c014_caue_requires_grant ON conta_acesso_unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant
  AFTER INSERT OR UPDATE OF conta_acesso_id, unidade_economica_id ON conta_acesso_unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_fixed();

DROP TRIGGER IF EXISTS adr_c014_cat_blocks_if_dependents ON conta_acesso_tenant;
CREATE CONSTRAINT TRIGGER adr_c014_cat_blocks_if_dependents
  AFTER DELETE OR UPDATE OF conta_acesso_id, tenant_id ON conta_acesso_tenant
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_cat_blocks_if_dependents_delayed();

BEGIN;
INSERT INTO tenant (id) VALUES ('99991002-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO unidade_economica (id, tenant_id) VALUES ('99991002-0000-0000-0000-0000000000a1', '99991002-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso (id) VALUES ('99991002-0000-0000-0000-0000000000c1') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
  VALUES ('99991002-0000-0000-0000-0000000000d1', '99991002-0000-0000-0000-0000000000c1', '99991002-0000-0000-0000-000000000001', 'ADMIN')
  ON CONFLICT DO NOTHING;
COMMIT;
SQL
    cat "$WORKDIR/setup.log"

    cat > "$WORKDIR/sx.sql" <<'SQL'
\timing on
BEGIN;
DELETE FROM conta_acesso_tenant WHERE conta_acesso_id='99991002-0000-0000-0000-0000000000c1' AND tenant_id='99991002-0000-0000-0000-000000000001';
COMMIT;
SELECT clock_timestamp(), 'X (DELETE ContaAcessoTenant, trigger com delay) finalizada';
SQL

    cat > "$WORKDIR/sy.sql" <<'SQL'
\timing on
SELECT pg_sleep(1);
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('99991002-0000-0000-0000-0000000000e1', '99991002-0000-0000-0000-0000000000c1', '99991002-0000-0000-0000-0000000000a1', 'LEITURA');
COMMIT;
SELECT clock_timestamp(), 'Y (INSERT CAUE, trigger CANDIDATA com lock) finalizada';
SQL

    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sx.sql" > "$WORKDIR/x.out" 2>&1 &
    PIDX=$!
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sy.sql" > "$WORKDIR/y.out" 2>&1 &
    PIDY=$!
    wait "$PIDX" "$PIDY" 2>/dev/null

    echo "--- SAIDA X ---"; cat "$WORKDIR/x.out"
    echo "--- SAIDA Y ---"; cat "$WORKDIR/y.out"
    echo "--- ESTADO FINAL ---"
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -c "
SELECT
  EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='99991002-0000-0000-0000-0000000000c1' AND tenant_id='99991002-0000-0000-0000-000000000001') AS cat_existe,
  EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='99991002-0000-0000-0000-0000000000e1') AS caue_existe;
"
    ;;

  race3)
    echo "=== RACE 3 (CANDIDATA): trigger fixed (lock) vs UPDATE unidade_economica.tenant_id concorrente ==="
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 > "$WORKDIR/setup.log" 2>&1 <<'SQL'
DROP TRIGGER IF EXISTS adr_c014_caue_requires_grant ON conta_acesso_unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant
  AFTER INSERT OR UPDATE OF conta_acesso_id, unidade_economica_id ON conta_acesso_unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_fixed_delayed();

DROP TRIGGER IF EXISTS adr_c014_ue_tenant_change_guard ON unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_ue_tenant_change_guard
  AFTER UPDATE OF tenant_id ON unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_ue_tenant_change_guard();

BEGIN;
INSERT INTO tenant (id) VALUES ('99991003-0000-0000-0000-000000000001'), ('99991003-0000-0000-0000-000000000002') ON CONFLICT DO NOTHING;
INSERT INTO unidade_economica (id, tenant_id) VALUES ('99991003-0000-0000-0000-0000000000a1', '99991003-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso (id) VALUES ('99991003-0000-0000-0000-0000000000c1') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
  VALUES ('99991003-0000-0000-0000-0000000000d1', '99991003-0000-0000-0000-0000000000c1', '99991003-0000-0000-0000-000000000001', 'ADMIN')
  ON CONFLICT DO NOTHING;
COMMIT;
SQL
    cat "$WORKDIR/setup.log"

    cat > "$WORKDIR/sx.sql" <<'SQL'
\timing on
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('99991003-0000-0000-0000-0000000000e1', '99991003-0000-0000-0000-0000000000c1', '99991003-0000-0000-0000-0000000000a1', 'LEITURA');
COMMIT;
SELECT clock_timestamp(), 'X (INSERT CAUE, trigger CANDIDATA com lock+delay) finalizada';
SQL

    cat > "$WORKDIR/sy.sql" <<'SQL'
\timing on
SELECT pg_sleep(1);
BEGIN;
UPDATE unidade_economica SET tenant_id = '99991003-0000-0000-0000-000000000002' WHERE id = '99991003-0000-0000-0000-0000000000a1';
COMMIT;
SELECT clock_timestamp(), 'Y (UPDATE UE.tenant_id T1->T2, trigger normal) finalizada';
SQL

    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sx.sql" > "$WORKDIR/x.out" 2>&1 &
    PIDX=$!
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sy.sql" > "$WORKDIR/y.out" 2>&1 &
    PIDY=$!
    wait "$PIDX" "$PIDY" 2>/dev/null

    echo "--- SAIDA X ---"; cat "$WORKDIR/x.out"
    echo "--- SAIDA Y ---"; cat "$WORKDIR/y.out"
    echo "--- ESTADO FINAL ---"
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -c "
SELECT
  (SELECT tenant_id FROM unidade_economica WHERE id='99991003-0000-0000-0000-0000000000a1') AS ue_tenant_atual,
  EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='99991003-0000-0000-0000-0000000000e1') AS caue_existe,
  EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='99991003-0000-0000-0000-0000000000c1' AND tenant_id='99991003-0000-0000-0000-000000000002') AS cat_existe_para_tenant_novo;
"
    ;;
  *)
    echo "cenario desconhecido: $RACE"; exit 1 ;;
esac

rm -rf "$WORKDIR"
