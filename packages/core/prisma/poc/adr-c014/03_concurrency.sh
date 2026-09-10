#!/bin/bash
# ============================================================================
# PoC ADR-C014 -- teste de concorrencia (EXPERIMENTAL, descartavel)
# Uso: ./03_concurrency.sh <container_name>
#
# Duas sessoes psql concorrentes controladas via FIFO, para forcar a
# interleaving especifica que expoe (ou nao) a janela de corrida entre:
#   Sessao 1 (S1): remover ContaAcessoTenant(C1,T1)
#   Sessao 2 (S2): inserir ContaAcessoUnidadeEconomica(C1,U1) -- U1 em T1
#
# Sequencia forcada:
#   1. S1: BEGIN; DELETE ContaAcessoTenant(C1,T1);              (nao comita)
#   2. S2: BEGIN; INSERT CAUE(C1,U1); COMMIT;                   (comita ANTES de S1)
#   3. S1: COMMIT;
#
# Se o mecanismo permitir os DOIS sucederem, o estado final e inconsistente:
# CAUE(C1,U1) existe mas ContaAcessoTenant(C1,T1) foi removido -- uma
# restricao de UE sobrevivendo sem a concessao de Tenant que a autoriza.
# ============================================================================
set -u
CONTAINER="${1:?uso: 03_concurrency.sh <container_name>}"
DB="poc_adr_c014"
WORKDIR=$(mktemp -d)
S1_IN="$WORKDIR/s1_in"; S1_OUT="$WORKDIR/s1_out.log"
S2_IN="$WORKDIR/s2_in"; S2_OUT="$WORKDIR/s2_out.log"
mkfifo "$S1_IN" "$S2_IN"

# Seed limpo especifico deste teste (id proprios, para nao colidir com 02_scenarios.sh)
docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 >/tmp/conc_seed.log 2>&1 <<'SEED'
BEGIN;
INSERT INTO tenant (id) VALUES ('33333333-3333-3333-3333-333333333333') ON CONFLICT DO NOTHING;
INSERT INTO unidade_economica (id, tenant_id) VALUES ('a4444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso (id) VALUES ('c4444444-4444-4444-4444-444444444444') ON CONFLICT DO NOTHING;
INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel)
  VALUES ('d4444444-4444-4444-4444-444444444444', 'c4444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 'ADMIN')
  ON CONFLICT DO NOTHING;
COMMIT;
SEED
echo "--- seed da concorrencia ---"; cat /tmp/conc_seed.log; echo ""

# Sessoes psql persistentes alimentadas via FIFO
docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$S1_IN" > "$S1_OUT" 2>&1 &
PID1=$!
docker exec -i "$CONTAINER" psql -U postgres -d "$DB" < "$S2_IN" > "$S2_OUT" 2>&1 &
PID2=$!

exec 3>"$S1_IN"
exec 4>"$S2_IN"

echo "-- passo 1: S1 abre transacao e deleta ContaAcessoTenant(C4,T3), sem commit --"
echo "BEGIN;" >&3
echo "DELETE FROM conta_acesso_tenant WHERE conta_acesso_id='c4444444-4444-4444-4444-444444444444' AND tenant_id='33333333-3333-3333-3333-333333333333';" >&3
sleep 1

echo "-- passo 2: S2 abre, insere CAUE(C4,U4) e tenta commitar ANTES de S1 --"
echo "BEGIN;" >&4
echo "INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel) VALUES ('e4444444-4444-4444-4444-444444444444', 'c4444444-4444-4444-4444-444444444444', 'a4444444-4444-4444-4444-444444444444', 'LEITURA');" >&4
echo "COMMIT;" >&4
sleep 2

echo "-- passo 3: S1 tenta commitar a delecao --"
echo "COMMIT;" >&3
sleep 2

exec 3>&-
exec 4>&-
wait "$PID1" 2>/dev/null
wait "$PID2" 2>/dev/null

echo ""
echo "=== SAIDA S1 (DELETE ContaAcessoTenant) ==="
cat "$S1_OUT"
echo ""
echo "=== SAIDA S2 (INSERT ContaAcessoUnidadeEconomica) ==="
cat "$S2_OUT"

echo ""
echo "=== ESTADO FINAL NO BANCO ==="
docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -c "
SELECT
  EXISTS(SELECT 1 FROM conta_acesso_tenant WHERE conta_acesso_id='c4444444-4444-4444-4444-444444444444' AND tenant_id='33333333-3333-3333-3333-333333333333') AS cat_existe,
  EXISTS(SELECT 1 FROM conta_acesso_unidade_economica WHERE id='e4444444-4444-4444-4444-444444444444') AS caue_existe;
"

echo ""
echo "=== DIAGNOSTICO ==="
echo "Se cat_existe=f E caue_existe=t simultaneamente: INCONSISTENCIA CONFIRMADA (restricao sem concessao)."
echo "Se exatamente uma das duas operacoes falhou: mecanismo se comportou corretamente (sem janela de corrida observada nesta execucao)."

rm -rf "$WORKDIR"
