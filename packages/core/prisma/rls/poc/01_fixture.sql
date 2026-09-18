-- Fixture sintetica RLS PoC — todos os dados sao obviamente ficticios.
-- Executado como postgres (owner/BYPASSRLS) — RLS nao se aplica a esta sessao.

INSERT INTO tenant (id) VALUES
  ('aaaaaaaa-0000-0000-0000-00000000000a'),
  ('bbbbbbbb-0000-0000-0000-00000000000b');

INSERT INTO conta_acesso (id) VALUES
  ('cccccccc-0000-0000-0000-0000000000aa'), -- Conta A
  ('cccccccc-0000-0000-0000-0000000000bb'), -- Conta B
  ('cccccccc-0000-0000-0000-0000000000cc'); -- Conta C (sem nenhuma concessao)

INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel) VALUES
  ('dddddddd-0000-0000-0000-0000000000a1', 'cccccccc-0000-0000-0000-0000000000aa',
   'aaaaaaaa-0000-0000-0000-00000000000a', 'ADMIN_TENANT'),
  ('dddddddd-0000-0000-0000-0000000000b1', 'cccccccc-0000-0000-0000-0000000000bb',
   'bbbbbbbb-0000-0000-0000-00000000000b', 'ADMIN_TENANT');

INSERT INTO unidade_economica (id, nome, status_registro, criado_em, atualizado_em, tenant_id) VALUES
  ('eeeeeeee-0000-0000-0000-00000000000a', 'UE-A (sintetica, ficticia)', 'ATIVO', now(), now(),
   'aaaaaaaa-0000-0000-0000-00000000000a'),
  ('eeeeeeee-0000-0000-0000-00000000000b', 'UE-B (sintetica, ficticia)', 'ATIVO', now(), now(),
   'bbbbbbbb-0000-0000-0000-00000000000b');

-- pessoa_fisica / pessoa_juridica / fonte_pagadora — globais, sinteticas
INSERT INTO pessoa_fisica (id, cpf, nome, data_nascimento, registrado_em) VALUES
  ('f0000000-0000-0000-0000-00000000000a', '00000000000', 'Pessoa Fisica Sintetica A', '1990-01-01', now());
INSERT INTO pessoa_juridica (id, cnpj, razao_social, regime_tributario, cnae_principal, data_abertura, municipio_ibge, registrado_em) VALUES
  ('f1000000-0000-0000-0000-00000000000a', '00000000000000', 'PJ Sintetica A LTDA', 'SIMPLES_NACIONAL', '0000000', '2020-01-01', '3304557', now());
INSERT INTO fonte_pagadora (id, tipo_fonte_pagadora, identificador_fiscal, nome, registrado_em) VALUES
  ('f2000000-0000-0000-0000-00000000000a', 'PESSOA_JURIDICA', '00000000000000', 'Fonte Pagadora Sintetica', now());

-- receita (TENANT_DERIVADO_POR_RLS, 1 hop) — uma em cada UE
INSERT INTO receita (id, valor_receita_bruta, sistema_origem, registrado_em, pessoa_fisica_id, unidade_economica_id) VALUES
  ('11111111-0000-0000-0000-00000000000a', 1000.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', 'eeeeeeee-0000-0000-0000-00000000000a'),
  ('11111111-0000-0000-0000-00000000000b', 2000.00, 'ENTRADA_MANUAL', now(), 'f0000000-0000-0000-0000-00000000000a', 'eeeeeeee-0000-0000-0000-00000000000b');

-- arquivo_origem (TENANT_ID_MATERIALIZADO)
INSERT INTO arquivo_origem (id, hash_conteudo, armazenamento_referencia, registrado_em, tenant_id) VALUES
  ('22222222-0000-0000-0000-00000000000a', 'hash-sintetico-a', 'ref-sintetica-a', now(), 'aaaaaaaa-0000-0000-0000-00000000000a'),
  ('22222222-0000-0000-0000-00000000000b', 'hash-sintetico-b', 'ref-sintetica-b', now(), 'bbbbbbbb-0000-0000-0000-00000000000b');

-- documento_fiscal (TENANT_DERIVADO_POR_RLS, 1 hop)
INSERT INTO documento_fiscal (id, tipo_documento_fiscal, sistema_origem, registrado_em, unidade_economica_id) VALUES
  ('33333333-0000-0000-0000-00000000000a', 'NFSE_SINTETICA', 'ENTRADA_MANUAL', now(), 'eeeeeeee-0000-0000-0000-00000000000a'),
  ('33333333-0000-0000-0000-00000000000b', 'NFSE_SINTETICA', 'ENTRADA_MANUAL', now(), 'eeeeeeee-0000-0000-0000-00000000000b');

-- receita_documento_fiscal (TENANT_DERIVADO_POR_RLS, 2 hops via receita)
INSERT INTO receita_documento_fiscal (id, receita_id, documento_fiscal_id, registrado_em) VALUES
  ('44444444-0000-0000-0000-00000000000a', '11111111-0000-0000-0000-00000000000a', '33333333-0000-0000-0000-00000000000a', now()),
  ('44444444-0000-0000-0000-00000000000b', '11111111-0000-0000-0000-00000000000b', '33333333-0000-0000-0000-00000000000b', now());

-- documento_fiscal_arquivo_origem (TENANT_DERIVADO_POR_RLS, 2 hops via documento_fiscal)
INSERT INTO documento_fiscal_arquivo_origem (id, documento_fiscal_id, arquivo_origem_id, registrado_em) VALUES
  ('55555555-0000-0000-0000-00000000000a', '33333333-0000-0000-0000-00000000000a', '22222222-0000-0000-0000-00000000000a', now()),
  ('55555555-0000-0000-0000-00000000000b', '33333333-0000-0000-0000-00000000000b', '22222222-0000-0000-0000-00000000000b', now());

-- classificacao_equiparacao_hospitalar (TENANT_DERIVADO_POR_RLS, 2 hops via receita)
INSERT INTO classificacao_equiparacao_hospitalar (id, receita_id, registrado_em) VALUES
  ('66666666-0000-0000-0000-00000000000a', '11111111-0000-0000-0000-00000000000a', now()),
  ('66666666-0000-0000-0000-00000000000b', '11111111-0000-0000-0000-00000000000b', now());

-- conflito_dado (TENANT_ID_MATERIALIZADO) + conflito_dado_item (TENANT_DERIVADO_DO_PAI)
INSERT INTO conflito_dado (id, status_conflito, tipo_conflito, registrado_em, tenant_id) VALUES
  ('77777777-0000-0000-0000-00000000000a', 'ABERTO', 'DIVERGENCIA_SINTETICA', now(), 'aaaaaaaa-0000-0000-0000-00000000000a'),
  ('77777777-0000-0000-0000-00000000000b', 'ABERTO', 'DIVERGENCIA_SINTETICA', now(), 'bbbbbbbb-0000-0000-0000-00000000000b');
INSERT INTO conflito_dado_item (id, conflito_dado_id, tipo_objeto, objeto_id, registrado_em) VALUES
  ('88888888-0000-0000-0000-00000000000a', '77777777-0000-0000-0000-00000000000a', 'RECEITA', '11111111-0000-0000-0000-00000000000a', now()),
  -- item cujo objeto_id (polimorfico) aponta para um objeto de OUTRO tenant, para provar que a
  -- referencia polimorfica nunca e usada para derivar tenant (T14):
  ('88888888-0000-0000-0000-00000000000c', '77777777-0000-0000-0000-00000000000a', 'RECEITA', '11111111-0000-0000-0000-00000000000b', now()),
  ('88888888-0000-0000-0000-00000000000b', '77777777-0000-0000-0000-00000000000b', 'RECEITA', '11111111-0000-0000-0000-00000000000b', now());

-- revisao_tecnica (TENANT_ID_MATERIALIZADO)
INSERT INTO revisao_tecnica (id, objeto_revisado_id, tipo_objeto_revisado, status_revisao, justificativa, revisado_em, tenant_id) VALUES
  ('99999999-0000-0000-0000-00000000000a', '11111111-0000-0000-0000-00000000000a', 'RECEITA', 'APROVADO', 'sintetico', now(), 'aaaaaaaa-0000-0000-0000-00000000000a'),
  ('99999999-0000-0000-0000-00000000000b', '11111111-0000-0000-0000-00000000000b', 'RECEITA', 'APROVADO', 'sintetico', now(), 'bbbbbbbb-0000-0000-0000-00000000000b');

-- vinculo / vinculo_extremidade — 3 cenarios (T26/T27/T28)
-- Cenario 1 (T26): duas extremidades UE, mesmo tenant (A)
INSERT INTO vinculo (id, tipo_vinculo, registrado_em) VALUES ('aa000000-0000-0000-0000-00000000001a', 'SOCIETARIO', now());
INSERT INTO vinculo_extremidade (id, vinculo_id, lado_extremidade, unidade_economica_id, registrado_em) VALUES
  ('ab000000-0000-0000-0000-00000000001a', 'aa000000-0000-0000-0000-00000000001a', 'ORIGEM', 'eeeeeeee-0000-0000-0000-00000000000a', now()),
  ('ab000000-0000-0000-0000-00000000001b', 'aa000000-0000-0000-0000-00000000001a', 'DESTINO', 'eeeeeeee-0000-0000-0000-00000000000a', now());

-- Cenario 2 (T27): uma extremidade UE (tenant A), outra PF (deriva da irma) — combinado numa
-- unica INSERT multi-linha para que ADR-C005 (deferred, mas psql autocommita por statement) veja
-- as duas extremidades no mesmo statement/transacao implicita.
INSERT INTO vinculo (id, tipo_vinculo, registrado_em) VALUES ('aa000000-0000-0000-0000-00000000002a', 'SOCIETARIO', now());
INSERT INTO vinculo_extremidade (id, vinculo_id, lado_extremidade, unidade_economica_id, pessoa_fisica_id, registrado_em) VALUES
  ('ab000000-0000-0000-0000-00000000002a', 'aa000000-0000-0000-0000-00000000002a', 'ORIGEM', 'eeeeeeee-0000-0000-0000-00000000000a', NULL, now()),
  ('ab000000-0000-0000-0000-00000000002b', 'aa000000-0000-0000-0000-00000000002a', 'DESTINO', NULL, 'f0000000-0000-0000-0000-00000000000a', now());

-- Cenario 3 (T28): as duas extremidades PF/PJ, nenhuma UE — exceção residual, deve ficar invisível a todos
INSERT INTO vinculo (id, tipo_vinculo, registrado_em) VALUES ('aa000000-0000-0000-0000-00000000003a', 'SOCIETARIO', now());
INSERT INTO vinculo_extremidade (id, vinculo_id, lado_extremidade, pessoa_fisica_id, pessoa_juridica_id, registrado_em) VALUES
  ('ab000000-0000-0000-0000-00000000003a', 'aa000000-0000-0000-0000-00000000003a', 'ORIGEM', 'f0000000-0000-0000-0000-00000000000a', NULL, now()),
  ('ab000000-0000-0000-0000-00000000003b', 'aa000000-0000-0000-0000-00000000003a', 'DESTINO', NULL, 'f1000000-0000-0000-0000-00000000000a', now());

-- conta_acesso_unidade_economica (TENANT_DERIVADO_POR_RLS + ADR-C014) — Conta A restrita a UE-A
-- (ADR-C014 exige que ja exista conta_acesso_tenant A->TenantA, que ja existe acima)
INSERT INTO conta_acesso_unidade_economica (id, conta_acesso_id, unidade_economica_id, papel) VALUES
  ('bb000000-0000-0000-0000-00000000000a', 'cccccccc-0000-0000-0000-0000000000aa', 'eeeeeeee-0000-0000-0000-00000000000a', 'RESTRITO_UE');

-- cenario_tributario / resultado_calculo (TENANT_DERIVADO_POR_RLS, 1 hop)
INSERT INTO cenario_tributario (id, nome, unidade_economica_id, registrado_em) VALUES
  ('cc000000-0000-0000-0000-00000000000a', 'Cenario A', 'eeeeeeee-0000-0000-0000-00000000000a', now()),
  ('cc000000-0000-0000-0000-00000000000b', 'Cenario B', 'eeeeeeee-0000-0000-0000-00000000000b', now());
INSERT INTO resultado_calculo (id, cenario_tributario_id, input_snapshot_hash, engine_id, engine_version, rule_set_id, rule_set_version, calculado_em, unidade_economica_id) VALUES
  ('dd000000-0000-0000-0000-00000000000a', 'cc000000-0000-0000-0000-00000000000a', 'hash-a', 'engine-poc', '1.0', 'rule-poc', '1.0', now(), 'eeeeeeee-0000-0000-0000-00000000000a'),
  ('dd000000-0000-0000-0000-00000000000b', 'cc000000-0000-0000-0000-00000000000b', 'hash-b', 'engine-poc', '1.0', 'rule-poc', '1.0', now(), 'eeeeeeee-0000-0000-0000-00000000000b');
