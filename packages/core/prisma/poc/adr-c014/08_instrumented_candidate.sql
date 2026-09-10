-- ============================================================================
-- PoC ADR-C014 -- instrumentacao EXPERIMENTAL da VARIANTE CANDIDATA
-- (01_schema_fixed.sql, trg_caue_requires_grant_fixed com FOR KEY SHARE).
--
-- Mesma tecnica de 06_instrumented_naive.sql: insere um PERFORM pg_sleep(3)
-- DEPOIS de adquirir o lock FOR KEY SHARE (e confirmar que a linha existe),
-- ANTES do RETURN -- para provar que, mesmo com uma janela artificialmente
-- alargada, o lock impede a operacao concorrente conflitante de prosseguir
-- (ela deve ficar BLOQUEADA esperando, nao executar livremente em paralelo).
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_caue_requires_grant_fixed_delayed() RETURNS TRIGGER AS $$
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

  -- INSTRUMENTACAO: mesma tecnica de 06_instrumented_naive.sql -- atraso
  -- deliberado APOS adquirir o lock, para provar que a operacao concorrente
  -- conflitante fica bloqueada esperando, nao prossegue livremente.
  PERFORM pg_sleep(3);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
