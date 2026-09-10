#!/bin/bash
# ============================================================================
# PoC ADR-C014 -- execucao orquestrada dos 3 cenarios de corrida (EXPERIMENTAL)
# Uso: ./07_run_races.sh <container_name> <race1|race2|race3> <trigger_variant_sql_or_none>
#
# race1: delay em trg_caue_requires_grant (insercao de restricao) vs DELETE
#        normal de ContaAcessoTenant concorrente.
# race2: delay em trg_cat_blocks_if_dependents (remocao de concessao) vs
#        INSERT normal de ContaAcessoUnidadeEconomica concorrente.
# race3: delay em trg_caue_requires_grant vs UPDATE normal de
#        unidade_economica.tenant_id concorrente.
#
# Nenhum uso de FIFO -- duas sessoes psql lancadas como jobs de background do
# bash, cada uma alimentada por um arquivo .sql temporario via stdin.
# ============================================================================
set -u
CONTAINER="${1:?uso: 07_run_races.sh <container> <race1|race2|race3>}"
RACE="${2:?uso: 07_run_races.sh <container> <race1|race2|race3>}"
DB="poc_adr_c014"
WORKDIR=$(mktemp -d)

run_bg() {
  local label="$1" sqlfile="$2" outfile="$3"
  docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$sqlfile" > "$outfile" 2>&1 &
  echo $!
}

case "$RACE" in
  race1)
    echo "=== RACE 1: delay em trg_caue_requires_grant (INSERT CAUE) vs DELETE ContaAcessoTenant concorrente ==="
    # troca o trigger de conta_acesso_unidade_economica para usar a versao com delay
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 > "$WORKDIR/setup.log" 2>&1 <<'SQL'
DROP TRIGGER IF EXISTS adr_c014_caue_requires_grant ON conta_acesso_unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant
  AFTER INSERT OR UPDATE OF conta_acesso_id, unidade_economica_id ON conta_acesso_unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_naive_delayed();

BEGIN;
INSERT INTO tenant (id) VALUES ('99990001-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO unidade_economica (id, tenant_id) VALUES ('99990001-0000-0000-0000-0000000000a1', '99990001-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso (id) VALUES ('99990001-0000-0000-0000-0000000000c1') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
  VALUES ('99990001-0000-0000-0000-0000000000d1', '99990001-0000-0000-0000-0000000000c1', '99990001-0000-0000-0000-000000000001', 'ADMIN')
  ON CONFLICT DO NOTHING;
COMMIT;
SQL
    cat "$WORKDIR/setup.log"

    cat > "$WORKDIR/sx.sql" <<'SQL'
\timing on
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('99990001-0000-0000-0000-0000000000e1', '99990001-0000-0000-0000-0000000000c1', '99990001-0000-0000-0000-0000000000a1', 'LEITURA');
COMMIT;
SELECT clock_timestamp(), 'X (INSERT CAUE, trigger com delay) finalizada';
SQL

    cat > "$WORKDIR/sy.sql" <<'SQL'
\timing on
SELECT pg_sleep(1);
BEGIN;
DELETE FROM conta_acesso_tenant WHERE conta_acesso_id='99990001-0000-0000-0000-0000000000c1' AND tenant_id='99990001-0000-0000-0000-000000000001';
COMMIT;
SELECT clock_timestamp(), 'Y (DELETE ContaAcessoTenant, trigger normal) finalizada';
SQL

    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sx.sql" > "$WORKDIR/x.out" 2>&1 &
    PIDX=$!
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sy.sql" > "$WORKDIR/y.out" 2>&1 &
    PIDY=$!
    wait "$PIDX" "$PIDY" 2>/dev/null

    echo "--- SAIDA X (INSERT CAUE, checagem com delay de 3s apos confirmar CAT) ---"; cat "$WORKDIR/x.out"
    echo "--- SAIDA Y (DELETE ContaAcessoTenant, 1s de atraso para rodar durante o sleep de X) ---"; cat "$WORKDIR/y.out"

    echo "--- ESTADO FINAL ---"
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -c "
SELECT
  EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='99990001-0000-0000-0000-0000000000c1' AND tenant_id='99990001-0000-0000-0000-000000000001') AS cat_existe,
  EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='99990001-0000-0000-0000-0000000000e1') AS caue_existe;
"
    ;;

  race2)
    echo "=== RACE 2: delay em trg_cat_blocks_if_dependents (DELETE ContaAcessoTenant) vs INSERT ContaAcessoUnidadeEconomica concorrente ==="
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 > "$WORKDIR/setup.log" 2>&1 <<'SQL'
DROP TRIGGER IF EXISTS adr_c014_cat_blocks_if_dependents ON conta_acesso_tenant;
CREATE CONSTRAINT TRIGGER adr_c014_cat_blocks_if_dependents
  AFTER DELETE OR UPDATE OF conta_acesso_id, tenant_id ON conta_acesso_tenant
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_cat_blocks_if_dependents_delayed();

-- garante trigger A de volta ao normal (nao-delayed) para este teste
DROP TRIGGER IF EXISTS adr_c014_caue_requires_grant ON conta_acesso_unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant
  AFTER INSERT OR UPDATE OF conta_acesso_id, unidade_economica_id ON conta_acesso_unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_naive();

BEGIN;
INSERT INTO tenant (id) VALUES ('99990002-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO unidade_economica (id, tenant_id) VALUES ('99990002-0000-0000-0000-0000000000a1', '99990002-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso (id) VALUES ('99990002-0000-0000-0000-0000000000c1') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
  VALUES ('99990002-0000-0000-0000-0000000000d1', '99990002-0000-0000-0000-0000000000c1', '99990002-0000-0000-0000-000000000001', 'ADMIN')
  ON CONFLICT DO NOTHING;
COMMIT;
SQL
    cat "$WORKDIR/setup.log"

    cat > "$WORKDIR/sx.sql" <<'SQL'
\timing on
BEGIN;
DELETE FROM conta_acesso_tenant WHERE conta_acesso_id='99990002-0000-0000-0000-0000000000c1' AND tenant_id='99990002-0000-0000-0000-000000000001';
COMMIT;
SELECT clock_timestamp(), 'X (DELETE ContaAcessoTenant, trigger com delay) finalizada';
SQL

    cat > "$WORKDIR/sy.sql" <<'SQL'
\timing on
SELECT pg_sleep(1);
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('99990002-0000-0000-0000-0000000000e1', '99990002-0000-0000-0000-0000000000c1', '99990002-0000-0000-0000-0000000000a1', 'LEITURA');
COMMIT;
SELECT clock_timestamp(), 'Y (INSERT CAUE, trigger normal) finalizada';
SQL

    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sx.sql" > "$WORKDIR/x.out" 2>&1 &
    PIDX=$!
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sy.sql" > "$WORKDIR/y.out" 2>&1 &
    PIDY=$!
    wait "$PIDX" "$PIDY" 2>/dev/null

    echo "--- SAIDA X (DELETE ContaAcessoTenant, checagem com delay de 3s apos confirmar 0 dependentes) ---"; cat "$WORKDIR/x.out"
    echo "--- SAIDA Y (INSERT CAUE, 1s de atraso para rodar durante o sleep de X) ---"; cat "$WORKDIR/y.out"

    echo "--- ESTADO FINAL ---"
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -c "
SELECT
  EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='99990002-0000-0000-0000-0000000000c1' AND tenant_id='99990002-0000-0000-0000-000000000001') AS cat_existe,
  EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='99990002-0000-0000-0000-0000000000e1') AS caue_existe;
"
    ;;

  race3)
    echo "=== RACE 3: delay em trg_caue_requires_grant (INSERT CAUE) vs UPDATE unidade_economica.tenant_id concorrente ==="
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 > "$WORKDIR/setup.log" 2>&1 <<'SQL'
DROP TRIGGER IF EXISTS adr_c014_caue_requires_grant ON conta_acesso_unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant
  AFTER INSERT OR UPDATE OF conta_acesso_id, unidade_economica_id ON conta_acesso_unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_naive_delayed();

-- garante trigger C normal (nao-delayed) para este teste
DROP TRIGGER IF EXISTS adr_c014_ue_tenant_change_guard ON unidade_economica;
CREATE CONSTRAINT TRIGGER adr_c014_ue_tenant_change_guard
  AFTER UPDATE OF tenant_id ON unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_ue_tenant_change_guard();

BEGIN;
INSERT INTO tenant (id) VALUES ('99990003-0000-0000-0000-000000000001'), ('99990003-0000-0000-0000-000000000002') ON CONFLICT DO NOTHING;
INSERT INTO unidade_economica (id, tenant_id) VALUES ('99990003-0000-0000-0000-0000000000a1', '99990003-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso (id) VALUES ('99990003-0000-0000-0000-0000000000c1') ON CONFLICT DO NOTHING;
-- C1 so tem concessao em T1 (000...001), nao em T2 (000...002)
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
  VALUES ('99990003-0000-0000-0000-0000000000d1', '99990003-0000-0000-0000-0000000000c1', '99990003-0000-0000-0000-000000000001', 'ADMIN')
  ON CONFLICT DO NOTHING;
COMMIT;
SQL
    cat "$WORKDIR/setup.log"

    cat > "$WORKDIR/sx.sql" <<'SQL'
\timing on
BEGIN;
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel)
VALUES ('99990003-0000-0000-0000-0000000000e1', '99990003-0000-0000-0000-0000000000c1', '99990003-0000-0000-0000-0000000000a1', 'LEITURA');
COMMIT;
SELECT clock_timestamp(), 'X (INSERT CAUE referenciando UE ainda em T1, trigger com delay) finalizada';
SQL

    cat > "$WORKDIR/sy.sql" <<'SQL'
\timing on
SELECT pg_sleep(1);
BEGIN;
UPDATE unidade_economica SET tenant_id = '99990003-0000-0000-0000-000000000002' WHERE id = '99990003-0000-0000-0000-0000000000a1';
COMMIT;
SELECT clock_timestamp(), 'Y (UPDATE UE.tenant_id de T1 para T2, trigger normal) finalizada';
SQL

    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sx.sql" > "$WORKDIR/x.out" 2>&1 &
    PIDX=$!
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$WORKDIR/sy.sql" > "$WORKDIR/y.out" 2>&1 &
    PIDY=$!
    wait "$PIDX" "$PIDY" 2>/dev/null

    echo "--- SAIDA X (INSERT CAUE, checagem com delay de 3s apos resolver tenant_id=T1 e confirmar CAT(C1,T1)) ---"; cat "$WORKDIR/x.out"
    echo "--- SAIDA Y (UPDATE UE.tenant_id T1->T2, 1s de atraso para rodar durante o sleep de X) ---"; cat "$WORKDIR/y.out"

    echo "--- ESTADO FINAL ---"
    docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -c "
SELECT
  (SELECT tenant_id FROM unidade_economica WHERE id='99990003-0000-0000-0000-0000000000a1') AS ue_tenant_atual,
  EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='99990003-0000-0000-0000-0000000000e1') AS caue_existe,
  EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='99990003-0000-0000-0000-0000000000c1' AND tenant_id='99990003-0000-0000-0000-000000000002') AS cat_existe_para_tenant_novo;
"
    ;;
  *)
    echo "cenario desconhecido: $RACE"
    exit 1
    ;;
esac

rm -rf "$WORKDIR"
