-- ============================================================================
-- PoC ADR-C014 -- schema minimo, VERSAO INGENUA (sem lock explicito)
-- EXPERIMENTAL. Nao faz parte da baseline canonica nem de migration real.
--
-- Reproduz apenas os tipos/PKs/FKs/unicidades relevantes de:
--   MCD-001 V1.4 (F10001, F10002, F10005, F10007..F10012)
--   CDC-001 V1.4 (CDC-SEC-001..005)
--   ADR-001 V1.1 (ADR-D020,D021,D025,D026,D027; ADR-C011,C012,C013,C014)
-- Nao inclui as 25 tabelas da baseline completa -- somente as 5 necessarias
-- para o invariante cross-table.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS public;

-- COT-OBJ-019 / MCD-F10001 / CDC-SEC-001
CREATE TABLE tenant (
  id UUID PRIMARY KEY
);

-- COT-OBJ-001 / MCD-F10002 / CDC-UE-001 (reduzido ao minimo necessario)
CREATE TABLE unidade_economica (
  id        UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE RESTRICT,
  -- ADR-C011 -- chave candidata para uma futura FK composta (nao usada por
  -- nenhuma tabela nesta baseline; preparada apenas em unidade_economica).
  CONSTRAINT uq_unidade_economica_id_tenant UNIQUE (id, tenant_id)
);

-- COT-OBJ-017 / MCD-F10007 / CDC-SEC-005 -- identidade minima, sem
-- nenhum campo de autenticacao.
CREATE TABLE conta_acesso (
  id UUID PRIMARY KEY
);

-- COT-SUP-005 / MCD-F10005,F10008,F10009,F10010 / CDC-SEC-003
CREATE TABLE conta_acesso_tenant (
  id              UUID PRIMARY KEY,
  conta_acesso_id UUID NOT NULL REFERENCES conta_acesso(id) ON DELETE RESTRICT,
  tenant_id       UUID NOT NULL REFERENCES tenant(id) ON DELETE RESTRICT,
  papel           TEXT NOT NULL, -- DST-GAP-015, Enum/Ref aberto, sem CHECK fechado
  -- ADR-C012
  CONSTRAINT uq_conta_acesso_tenant UNIQUE (conta_acesso_id, tenant_id)
);

-- COT-SUP-006 / MCD-F10005,F10008,F10011,F10012 / CDC-SEC-004
CREATE TABLE conta_acesso_unidade_economica (
  id                    UUID PRIMARY KEY,
  conta_acesso_id       UUID NOT NULL REFERENCES conta_acesso(id) ON DELETE RESTRICT,
  unidade_economica_id  UUID NOT NULL REFERENCES unidade_economica(id) ON DELETE RESTRICT,
  papel                 TEXT NOT NULL,
  -- ADR-C013
  CONSTRAINT uq_conta_acesso_unidade_economica UNIQUE (conta_acesso_id, unidade_economica_id)
);

-- ============================================================================
-- ADR-C014 -- VERSAO INGENUA (sem lock explicito na leitura de conta_acesso_tenant)
-- Usada apenas para demonstrar a janela de corrida de concorrencia (secao 5
-- do relatorio). NAO E a versao recomendada -- ver 01_schema_fixed.sql.
-- ============================================================================

-- Trigger A: toda linha de conta_acesso_unidade_economica precisa de uma
-- concessao de tenant correspondente (resolvida via unidade_economica.tenant_id).
CREATE OR REPLACE FUNCTION trg_caue_requires_grant_naive() RETURNS TRIGGER AS $$
DECLARE
  v_tenant_id UUID;
  v_ok BOOLEAN;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM unidade_economica WHERE id = NEW.unidade_economica_id;

  SELECT EXISTS (
    SELECT 1 FROM conta_acesso_tenant
    WHERE conta_acesso_id = NEW.conta_acesso_id AND tenant_id = v_tenant_id
  ) INTO v_ok;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'ADR-C014: conta_acesso_unidade_economica (conta_acesso_id=%, unidade_economica_id=%) sem conta_acesso_tenant correspondente (tenant_id resolvido=%)',
      NEW.conta_acesso_id, NEW.unidade_economica_id, v_tenant_id
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER adr_c014_caue_requires_grant
  AFTER INSERT OR UPDATE OF conta_acesso_id, unidade_economica_id ON conta_acesso_unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_naive();

-- Trigger B: nao permitir remover/realterar uma conta_acesso_tenant enquanto
-- existir uma conta_acesso_unidade_economica dependente dela.
CREATE OR REPLACE FUNCTION trg_cat_blocks_if_dependents() RETURNS TRIGGER AS $$
DECLARE
  v_dependents INT;
BEGIN
  SELECT count(*) INTO v_dependents
  FROM conta_acesso_unidade_economica caue
  JOIN unidade_economica ue ON ue.id = caue.unidade_economica_id
  WHERE caue.conta_acesso_id = OLD.conta_acesso_id
    AND ue.tenant_id = OLD.tenant_id;

  IF v_dependents > 0 THEN
    RAISE EXCEPTION 'ADR-C014: nao e possivel remover/alterar conta_acesso_tenant (conta_acesso_id=%, tenant_id=%) -- % restricao(oes) de UE dependente(s) ainda existem',
      OLD.conta_acesso_id, OLD.tenant_id, v_dependents
      USING ERRCODE = 'P0001';
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER adr_c014_cat_blocks_if_dependents
  AFTER DELETE OR UPDATE OF conta_acesso_id, tenant_id ON conta_acesso_tenant
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_cat_blocks_if_dependents();

-- Trigger C: alterar unidade_economica.tenant_id nao pode deixar
-- conta_acesso_unidade_economica orfa (sem concessao no novo tenant).
CREATE OR REPLACE FUNCTION trg_ue_tenant_change_guard() RETURNS TRIGGER AS $$
DECLARE
  v_orphans INT;
BEGIN
  IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
    SELECT count(*) INTO v_orphans
    FROM conta_acesso_unidade_economica caue
    WHERE caue.unidade_economica_id = NEW.id
      AND NOT EXISTS (
        SELECT 1 FROM conta_acesso_tenant cat
        WHERE cat.conta_acesso_id = caue.conta_acesso_id AND cat.tenant_id = NEW.tenant_id
      );

    IF v_orphans > 0 THEN
      RAISE EXCEPTION 'ADR-C014: alterar unidade_economica.tenant_id (id=%) para % invalidaria % restricao(oes) de acesso existentes sem concessao correspondente no novo tenant',
        NEW.id, NEW.tenant_id, v_orphans
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER adr_c014_ue_tenant_change_guard
  AFTER UPDATE OF tenant_id ON unidade_economica
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION trg_ue_tenant_change_guard();
