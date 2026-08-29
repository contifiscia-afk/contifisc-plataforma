-- PoC ADR-001 §5.1 / §15 passo 2 — validação de ADR-C005 / COT-REL-NORM-001
-- Modelo MÍNIMO necessário para provar a constraint. Não replica o MCD inteiro.
-- Descartável: roda só dentro do container efêmero adr001-poc-pg15.

DROP TABLE IF EXISTS vinculo_extremidade CASCADE;
DROP TABLE IF EXISTS vinculo CASCADE;
DROP TABLE IF EXISTS pessoa_juridica CASCADE;
DROP TABLE IF EXISTS pessoa_fisica CASCADE;
DROP TABLE IF EXISTS unidade_economica CASCADE;

-- Três "endpoints" possíveis de uma extremidade (XOR), reduzidos ao mínimo (só id).
CREATE TABLE unidade_economica (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid()
);

CREATE TABLE pessoa_fisica (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid()
);

CREATE TABLE pessoa_juridica (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid()
);

-- COT-OBJ-004 / CDC-REL-001 (reduzido ao mínimo para a PoC)
CREATE TABLE vinculo (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_vinculo text NOT NULL DEFAULT 'POC_GENERICO'
);

-- COT-SUP-001 / CDC-REL-002
CREATE TABLE vinculo_extremidade (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vinculo_id uuid NOT NULL REFERENCES vinculo (id),
  lado_extremidade text NOT NULL CHECK (lado_extremidade IN ('ORIGEM', 'DESTINO')), -- ADR-C004 / DST-E012
  unidade_economica_id uuid REFERENCES unidade_economica (id),
  pessoa_fisica_id uuid REFERENCES pessoa_fisica (id),
  pessoa_juridica_id uuid REFERENCES pessoa_juridica (id),

  -- ADR-C003: máximo uma ORIGEM e uma DESTINO por vínculo
  CONSTRAINT uq_vinculo_lado UNIQUE (vinculo_id, lado_extremidade),

  -- ADR-C002: XOR do endpoint (exatamente uma FK entre UE/PF/PJ)
  CONSTRAINT ck_endpoint_xor CHECK (
    (
      (unidade_economica_id IS NOT NULL)::int
      + (pessoa_fisica_id IS NOT NULL)::int
      + (pessoa_juridica_id IS NOT NULL)::int
    ) = 1
  )
);

-- ADR-C005 / COT-REL-NORM-001: todo Vinculo deve ter EXATAMENTE duas extremidades,
-- uma ORIGEM e uma DESTINO. Não garantível por FK/CHECK de linha isolada — exige
-- verificação agregada, avaliada ao final da transação (DEFERRABLE INITIALLY DEFERRED).
CREATE OR REPLACE FUNCTION fn_check_vinculo_extremidades() RETURNS trigger AS $$
DECLARE
  v_vinculo_id uuid;
  v_count_origem int;
  v_count_destino int;
  v_total int;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_vinculo_id := OLD.vinculo_id;
  ELSE
    v_vinculo_id := NEW.vinculo_id;
  END IF;

  SELECT
    count(*) FILTER (WHERE lado_extremidade = 'ORIGEM'),
    count(*) FILTER (WHERE lado_extremidade = 'DESTINO'),
    count(*)
  INTO v_count_origem, v_count_destino, v_total
  FROM vinculo_extremidade
  WHERE vinculo_id = v_vinculo_id;

  IF v_total <> 2 OR v_count_origem <> 1 OR v_count_destino <> 1 THEN
    RAISE EXCEPTION
      'ADR-C005/COT-REL-NORM-001: Vinculo % deve ter exatamente duas extremidades (1 ORIGEM + 1 DESTINO); encontrado total=%, origem=%, destino=%',
      v_vinculo_id, v_total, v_count_origem, v_count_destino;
  END IF;

  RETURN NULL; -- AFTER trigger: valor de retorno ignorado
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_vinculo_extremidades_check
  AFTER INSERT OR UPDATE OR DELETE ON vinculo_extremidade
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION fn_check_vinculo_extremidades();
