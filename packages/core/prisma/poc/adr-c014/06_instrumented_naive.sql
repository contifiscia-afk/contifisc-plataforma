-- ============================================================================
-- PoC ADR-C014 -- instrumentacao EXPERIMENTAL para tornar deterministica a
-- janela de corrida da variante INGENUA (00_schema_naive.sql).
--
-- NAO E uma variante nova de design -- e a MESMA logica de
-- trg_caue_requires_grant_naive e trg_cat_blocks_if_dependents e
-- trg_ue_tenant_change_guard, apenas com um PERFORM pg_sleep(...) inserido
-- ENTRE o momento em que a checagem confirma "estado seguro" e o RETURN da
-- funcao -- simulando de forma deterministica a janela real (mas
-- naturalmente minuscula) que existe entre "checagem" e "commit efetivo".
-- Tecnica padrao de teste de race condition (fault/delay injection).
--
-- Aplicar SOMENTE depois de 00_schema_naive.sql ja estar carregado.
-- ============================================================================

-- Instrumentacao 1: atraso apos confirmar que a concessao existe (para medir
-- corrida Insercao-de-restricao--vs--Remocao-de-concessao).
CREATE OR REPLACE FUNCTION trg_caue_requires_grant_naive_delayed() RETURNS TRIGGER AS $$
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

  -- INSTRUMENTACAO: atraso deliberado apos a checagem confirmar "seguro",
  -- antes de retornar (antes do commit efetivo desta transacao).
  PERFORM pg_sleep(3);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Instrumentacao 2: atraso apos confirmar "sem dependentes" em
-- trg_cat_blocks_if_dependents (para medir a corrida na direcao oposta:
-- Remocao-de-concessao--vs--Insercao-de-restricao).
CREATE OR REPLACE FUNCTION trg_cat_blocks_if_dependents_delayed() RETURNS TRIGGER AS $$
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

  PERFORM pg_sleep(3);

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Instrumentacao 3: atraso apos confirmar "sem orfaos" em
-- trg_ue_tenant_change_guard (para medir a corrida entre alterar
-- unidade_economica.tenant_id e inserir uma nova restricao para essa UE).
CREATE OR REPLACE FUNCTION trg_ue_tenant_change_guard_delayed() RETURNS TRIGGER AS $$
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

    PERFORM pg_sleep(3);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
