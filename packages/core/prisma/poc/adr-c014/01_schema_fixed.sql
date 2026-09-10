-- ============================================================================
-- PoC ADR-C014 -- schema minimo, VERSAO CORRIGIDA (com lock explicito)
-- EXPERIMENTAL. Nao faz parte da baseline canonica nem de migration real.
--
-- Identico a 00_schema_naive.sql, exceto pela funcao trg_caue_requires_grant,
-- que agora usa "FOR KEY SHARE" para tomar um lock de linha sobre a
-- conta_acesso_tenant correspondente -- fechando a janela de corrida
-- demonstrada com a versao ingenua (ver secao 5 do relatorio).
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE tenant (
  id UUID PRIMARY KEY
);

CREATE TABLE unidade_economica (
  id        UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenant(id) ON DELETE RESTRICT,
  CONSTRAINT uq_unidade_economica_id_tenant UNIQUE (id, tenant_id)
);

CREATE TABLE conta_acesso (
  id UUID PRIMARY KEY
);

CREATE TABLE conta_acesso_tenant (
  id              UUID PRIMARY KEY,
  conta_acesso_id UUID NOT NULL REFERENCES conta_acesso(id) ON DELETE RESTRICT,
  tenant_id       UUID NOT NULL REFERENCES tenant(id) ON DELETE RESTRICT,
  papel           TEXT NOT NULL,
  CONSTRAINT uq_conta_acesso_tenant UNIQUE (conta_acesso_id, tenant_id)
);

CREATE TABLE conta_acesso_unidade_economica (
  id                    UUID PRIMARY KEY,
  conta_acesso_id       UUID NOT NULL REFERENCES conta_acesso(id) ON DELETE RESTRICT,
  unidade_economica_id  UUID NOT NULL REFERENCES unidade_economica(id) ON DELETE RESTRICT,
  papel                 TEXT NOT NULL,
  CONSTRAINT uq_conta_acesso_unidade_economica UNIQUE (conta_acesso_id, unidade_economica_id)
);

-- ============================================================================
-- ADR-C014 -- VERSAO CORRIGIDA (recomendada)
-- ============================================================================

-- Trigger A (CORRIGIDA): "FOR KEY SHARE" toma um lock de linha sobre a
-- conta_acesso_tenant candidata -- se ela existir, uma DELETE/UPDATE de chave
-- concorrente sobre essa MESMA linha (trigger B) bloqueia ate esta transacao
-- terminar, fechando a janela de corrida entre "conceder" e "revogar".
-- Mesmo padrao que o proprio PostgreSQL usa internamente para FKs nativas.
CREATE OR REPLACE FUNCTION trg_caue_requires_grant_fixed() RETURNS TRIGGER AS $$
DECLARE
  v_tenant_id UUID;
  v_locked_id UUID;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM unidade_economica WHERE id = NEW.unidade_economica_id;

  SELECT id INTO v_locked_id
  FROM conta_acesso_tenant
  WHERE conta_acesso_id = NEW.conta_acesso_id AND tenant_id = v_tenant_id
  FOR KEY SHARE;

  IF v_locked_id IS NULL THEN
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
  FOR EACH ROW EXECUTE FUNCTION trg_caue_requires_grant_fixed();

-- Trigger B: inalterado -- o lock FOR KEY SHARE da trigger A ja e suficiente
-- para fechar a janela de corrida (ver relatorio, secao 5). Nenhuma mudanca
-- adicional foi necessaria aqui.
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

-- Trigger C: inalterado.
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
