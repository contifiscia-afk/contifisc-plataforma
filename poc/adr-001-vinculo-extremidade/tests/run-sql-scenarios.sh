#!/usr/bin/env bash
# Testes automatizados (SQL direto) da PoC ADR-001 / ADR-C005 / COT-REL-NORM-001.
# Roda contra o container descartável adr001-poc-pg15. Não toca em nenhum banco de produção.
set -u

export PATH="/c/Program Files/Docker/Docker/resources/bin:$PATH"
DOCKER="/c/Program Files/Docker/Docker/resources/bin/docker.exe"
PSQL=("$DOCKER" exec -i adr001-poc-pg15 psql -U poc_user -d adr001_poc -v ON_ERROR_STOP=1 -qtA)

UE="00000000-0000-4000-8000-000000000001"
PF="00000000-0000-4000-8000-000000000002"
PJ="00000000-0000-4000-8000-000000000003"

PASS=0
FAIL=0

reset_vinculos() {
  "${PSQL[@]}" >/dev/null 2>&1 <<SQL
TRUNCATE vinculo_extremidade, vinculo CASCADE;
SQL
}

# expect_ok "nome" "<<SQL>>"
expect_ok() {
  local name="$1" sql="$2"
  local out
  out=$("${PSQL[@]}" 2>&1 <<SQL
$sql
SQL
)
  local code=$?
  if [ "$code" -eq 0 ]; then
    echo "PASS (aceito conforme esperado): $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL (deveria ter sido aceito, mas foi rejeitado): $name"
    echo "  saída: $out"
    FAIL=$((FAIL + 1))
  fi
}

# expect_fail "nome" "trecho_esperado_no_erro" "<<SQL>>"
expect_fail() {
  local name="$1" expected_substr="$2" sql="$3"
  local out
  out=$("${PSQL[@]}" 2>&1 <<SQL
$sql
SQL
)
  local code=$?
  if [ "$code" -ne 0 ] && echo "$out" | grep -qi "$expected_substr"; then
    echo "PASS (rejeitado conforme esperado, contém '$expected_substr'): $name"
    PASS=$((PASS + 1))
  elif [ "$code" -ne 0 ]; then
    echo "FAIL (rejeitado, mas motivo inesperado): $name"
    echo "  esperado conter: $expected_substr"
    echo "  saída: $out"
    FAIL=$((FAIL + 1))
  else
    echo "FAIL (deveria ter sido rejeitado, mas foi aceito): $name"
    echo "  saída: $out"
    FAIL=$((FAIL + 1))
  fi
}

echo "== Cenário 1: XOR do endpoint — rejeita zero endpoints =="
reset_vinculos
expect_fail "extremidade sem nenhum endpoint" "ck_endpoint_xor" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000001');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade)
  VALUES ('10000000-0000-4000-8000-000000000001', 'ORIGEM');
COMMIT;
"

echo
echo "== Cenário 2: XOR do endpoint — rejeita dois endpoints simultâneos =="
reset_vinculos
expect_fail "extremidade com dois endpoints (PF e PJ)" "ck_endpoint_xor" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000002');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_fisica_id, pessoa_juridica_id)
  VALUES ('10000000-0000-4000-8000-000000000002', 'ORIGEM', '$PF', '$PJ');
COMMIT;
"

echo
echo "== Cenário 3: UNIQUE(vinculo_id, lado_extremidade) — rejeita duas ORIGEM =="
reset_vinculos
expect_fail "duas extremidades ORIGEM para o mesmo vinculo" "uq_vinculo_lado" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000003');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_fisica_id)
  VALUES ('10000000-0000-4000-8000-000000000003', 'ORIGEM', '$PF');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_juridica_id)
  VALUES ('10000000-0000-4000-8000-000000000003', 'ORIGEM', '$PJ');
COMMIT;
"

echo
echo "== Cenário 4: UNIQUE(vinculo_id, lado_extremidade) — rejeita duas DESTINO =="
reset_vinculos
expect_fail "duas extremidades DESTINO para o mesmo vinculo" "uq_vinculo_lado" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000004');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_fisica_id)
  VALUES ('10000000-0000-4000-8000-000000000004', 'DESTINO', '$PF');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, unidade_economica_id)
  VALUES ('10000000-0000-4000-8000-000000000004', 'DESTINO', '$UE');
COMMIT;
"

echo
echo "== Cenário 5: 'terceira extremidade' — só é possível duplicando um lado (ORIGEM/DESTINO), logo cai no Cenário 3/4 (UNIQUE), não chega ao trigger diferido =="
reset_vinculos
expect_fail "terceira extremidade (ORIGEM, DESTINO, ORIGEM de novo)" "uq_vinculo_lado" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000005');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_fisica_id)
  VALUES ('10000000-0000-4000-8000-000000000005', 'ORIGEM', '$PF');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_juridica_id)
  VALUES ('10000000-0000-4000-8000-000000000005', 'DESTINO', '$PJ');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, unidade_economica_id)
  VALUES ('10000000-0000-4000-8000-000000000005', 'ORIGEM', '$UE');
COMMIT;
"

echo
echo "== Cenário 6: vínculo incompleto (só ORIGEM) — deve falhar no COMMIT pelo trigger diferido =="
reset_vinculos
expect_fail "commit com apenas uma extremidade (ORIGEM)" "ADR-C005/COT-REL-NORM-001" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000006');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_fisica_id)
  VALUES ('10000000-0000-4000-8000-000000000006', 'ORIGEM', '$PF');
COMMIT;
"

echo
echo "== Cenário 7: vínculo incompleto (só DESTINO) — deve falhar no COMMIT pelo trigger diferido =="
reset_vinculos
expect_fail "commit com apenas uma extremidade (DESTINO)" "ADR-C005/COT-REL-NORM-001" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000007');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_juridica_id)
  VALUES ('10000000-0000-4000-8000-000000000007', 'DESTINO', '$PJ');
COMMIT;
"

echo
echo "== Cenário 8: ORIGEM + DESTINO na mesma transação — deve ser aceito no COMMIT =="
reset_vinculos
expect_ok "vinculo completo (1 ORIGEM + 1 DESTINO), tipos de endpoint distintos" "
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000008');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_fisica_id)
  VALUES ('10000000-0000-4000-8000-000000000008', 'ORIGEM', '$PF');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_juridica_id)
  VALUES ('10000000-0000-4000-8000-000000000008', 'DESTINO', '$PJ');
COMMIT;
"

echo
echo "== Cenário 9: estado intermediário incompleto É PERMITIDO dentro da transação (antes do COMMIT) =="
reset_vinculos
out=$("${PSQL[@]}" 2>&1 <<SQL
BEGIN;
INSERT INTO vinculo (id) VALUES ('10000000-0000-4000-8000-000000000009');
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, pessoa_fisica_id)
  VALUES ('10000000-0000-4000-8000-000000000009', 'ORIGEM', '$PF');
-- Estado intermediário: só 1 extremidade existe. Consulta dentro da MESMA transação
-- não deve levantar erro (trigger ainda não foi avaliado — é diferido para o COMMIT).
SELECT count(*) AS total_intermediario FROM vinculo_extremidade WHERE vinculo_id = '10000000-0000-4000-8000-000000000009';
INSERT INTO vinculo_extremidade (vinculo_id, lado_extremidade, unidade_economica_id)
  VALUES ('10000000-0000-4000-8000-000000000009', 'DESTINO', '$UE');
COMMIT;
SQL
)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "^1$"; then
  echo "PASS (estado intermediário com 1 linha foi lido sem erro dentro da transação; commit final aceito): estado intermediário + commit completo"
  PASS=$((PASS + 1))
else
  echo "FAIL (esperava leitura intermediária = 1 e commit aceito)"
  echo "  saída: $out"
  FAIL=$((FAIL + 1))
fi

echo
echo "=========================================="
echo "RESULTADO SQL DIRETO: $PASS passaram, $FAIL falharam (de $((PASS + FAIL)) cenários)"
echo "=========================================="

reset_vinculos
[ "$FAIL" -eq 0 ]
