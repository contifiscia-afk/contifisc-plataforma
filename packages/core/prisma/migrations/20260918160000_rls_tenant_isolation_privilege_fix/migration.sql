-- ============================================================================
-- CONTIFISC — RLS pos-SEC — migration definitiva (20260918150000)
-- ============================================================================
-- STATUS: DEFINITIVA, ADR-002 V1.0 APROVADO. Promovida do DRAFT original
-- (20260917130000_rls_tenant_isolation_DRAFT) sem alteracao de conteudo
-- (checksum preservado na promocao). Corrigida nesta revisao (achado de
-- executabilidade sob migration owner nao-superuser -- ver
-- RLS_NEON_DEPLOYMENT_REPORT.md secao "Fase H") -- novo checksum registrado
-- nesse mesmo relatorio. Validada em PostgreSQL 15 e 18 descartaveis,
-- incluindo com um role de migration nao-superuser mimetizando o
-- neondb_owner do Neon.
--
-- Fontes: ADR-001 V1.1 par.9 (matriz + ADR-D028 contexto de sessao),
-- ADR-002 V1.0 (mediacao SECURITY DEFINER, aprovado), SEC-001 par.11/par.14,
-- RLS_MATRIX.md (25/25), RLS_DESIGN_REVIEW.md, RLS_POC_REPORT.md,
-- RLS_POC_CORRECTION_REPORT.md, RLS_PRE_NEON_REVIEW_REPORT.md,
-- RLS_NEON_DEPLOYMENT_REPORT.md.
--
-- Migration inaugural pos-SEC (20260908120000_init_baseline_fisica_pos_sec)
-- NAO e alterada por este arquivo.
-- ============================================================================

-- ============================================================================
-- 0. Papeis conceituais (PROPOSTA, NAO CRIADOS por este script)
-- ============================================================================
-- contifisc_migration   — role de administracao/migration. Dono dos objetos.
--                         NUNCA usado pela aplicacao em runtime.
-- contifisc_app         — role de runtime da aplicacao. NAO superuser, NAO
--                         BYPASSRLS, NAO dono das tabelas. Sujeito a RLS e a
--                         FORCE ROW LEVEL SECURITY (secao 1).
-- contifisc_admin_op    — role futuro para operacao administrativa
--                         explicitamente auditada (SEC-001 par.12). NAO
--                         implementado nesta revisao — nenhum bypass de
--                         RLS deve existir sem gerar EventoAuditoriaSeguranca
--                         quando esse objeto estiver detalhado (bloqueado por
--                         GAP-CDC-1.3-002).
-- contifisc_provisioning — role de bootstrap (criar o primeiro Tenant e a
--                         primeira ContaAcessoTenant, caso sem concessao
--                         previa possivel). BYPASSRLS. Nunca usado pela
--                         aplicacao normal. Ver SECURITY_CONTEXT_CONTRACT.md
--                         secao 5.
-- contifisc_rls_mediator — role NOVO desta correcao (RLS_POC_CORRECTION_
--                         REPORT.md). NAO e role de login, NAO e runtime,
--                         NAO e migration/provisioning. Unica funcao: ser
--                         dono das funcoes SECURITY DEFINER de mediacao de
--                         autorizacao cross-table (secao 1.6 abaixo).
--                         BYPASSRLS (necessario para as funcoes que possui
--                         conseguirem ler tabelas com FORCE ROW LEVEL
--                         SECURITY sem reaplicar a RLS dessas tabelas —
--                         ver comentario de cada funcao). NUNCA recebe
--                         LOGIN. NUNCA e concedido a nenhuma ContaAcesso
--                         real nem usado fora das 2 funcoes desta secao.
--
-- Este script NAO executa CREATE ROLE para os 5 papeis acima (exceto
-- contifisc_rls_mediator, que E criado por este script — secao 1.6 — por
-- ser estritamente interno ao mecanismo de RLS, nao um role de acesso).
-- A criacao dos demais roles reais fica para quando o provisionamento de
-- banco for autorizado separadamente.

-- ============================================================================
-- 1. ENABLE ROW LEVEL SECURITY + FORCE (todas as 25 tabelas)
-- ============================================================================
-- FORCE ROW LEVEL SECURITY garante que RLS se aplica mesmo ao dono da tabela
-- (exceto role com BYPASSRLS/superuser) — defesa em profundidade caso
-- contifisc_app algum dia acumule ownership por engano. Nao aplicavel/nao
-- prejudicial mesmo que os roles definitivos ainda nao existam.

ALTER TABLE unidade_economica ENABLE ROW LEVEL SECURITY;
ALTER TABLE unidade_economica FORCE ROW LEVEL SECURITY;
ALTER TABLE pessoa_fisica ENABLE ROW LEVEL SECURITY;
ALTER TABLE pessoa_fisica FORCE ROW LEVEL SECURITY;
ALTER TABLE pessoa_juridica ENABLE ROW LEVEL SECURITY;
ALTER TABLE pessoa_juridica FORCE ROW LEVEL SECURITY;
ALTER TABLE fonte_pagadora ENABLE ROW LEVEL SECURITY;
ALTER TABLE fonte_pagadora FORCE ROW LEVEL SECURITY;
ALTER TABLE vinculo ENABLE ROW LEVEL SECURITY;
ALTER TABLE vinculo FORCE ROW LEVEL SECURITY;
ALTER TABLE vinculo_extremidade ENABLE ROW LEVEL SECURITY;
ALTER TABLE vinculo_extremidade FORCE ROW LEVEL SECURITY;
ALTER TABLE receita ENABLE ROW LEVEL SECURITY;
ALTER TABLE receita FORCE ROW LEVEL SECURITY;
ALTER TABLE contribuicao_previdenciaria ENABLE ROW LEVEL SECURITY;
ALTER TABLE contribuicao_previdenciaria FORCE ROW LEVEL SECURITY;
ALTER TABLE vinculo_previdenciario ENABLE ROW LEVEL SECURITY;
ALTER TABLE vinculo_previdenciario FORCE ROW LEVEL SECURITY;
ALTER TABLE evento_irpf ENABLE ROW LEVEL SECURITY;
ALTER TABLE evento_irpf FORCE ROW LEVEL SECURITY;
ALTER TABLE documento_fiscal ENABLE ROW LEVEL SECURITY;
ALTER TABLE documento_fiscal FORCE ROW LEVEL SECURITY;
ALTER TABLE arquivo_origem ENABLE ROW LEVEL SECURITY;
ALTER TABLE arquivo_origem FORCE ROW LEVEL SECURITY;
ALTER TABLE receita_documento_fiscal ENABLE ROW LEVEL SECURITY;
ALTER TABLE receita_documento_fiscal FORCE ROW LEVEL SECURITY;
ALTER TABLE documento_fiscal_arquivo_origem ENABLE ROW LEVEL SECURITY;
ALTER TABLE documento_fiscal_arquivo_origem FORCE ROW LEVEL SECURITY;
ALTER TABLE classificacao_equiparacao_hospitalar ENABLE ROW LEVEL SECURITY;
ALTER TABLE classificacao_equiparacao_hospitalar FORCE ROW LEVEL SECURITY;
ALTER TABLE cenario_tributario ENABLE ROW LEVEL SECURITY;
ALTER TABLE cenario_tributario FORCE ROW LEVEL SECURITY;
ALTER TABLE resultado_calculo ENABLE ROW LEVEL SECURITY;
ALTER TABLE resultado_calculo FORCE ROW LEVEL SECURITY;
ALTER TABLE conflito_dado ENABLE ROW LEVEL SECURITY;
ALTER TABLE conflito_dado FORCE ROW LEVEL SECURITY;
ALTER TABLE conflito_dado_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE conflito_dado_item FORCE ROW LEVEL SECURITY;
ALTER TABLE revisao_tecnica ENABLE ROW LEVEL SECURITY;
ALTER TABLE revisao_tecnica FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant FORCE ROW LEVEL SECURITY;
ALTER TABLE conta_acesso ENABLE ROW LEVEL SECURITY;
ALTER TABLE conta_acesso FORCE ROW LEVEL SECURITY;
ALTER TABLE conta_acesso_tenant ENABLE ROW LEVEL SECURITY;
ALTER TABLE conta_acesso_tenant FORCE ROW LEVEL SECURITY;
ALTER TABLE conta_acesso_unidade_economica ENABLE ROW LEVEL SECURITY;
ALTER TABLE conta_acesso_unidade_economica FORCE ROW LEVEL SECURITY;
ALTER TABLE evento_auditoria_seguranca ENABLE ROW LEVEL SECURITY;
ALTER TABLE evento_auditoria_seguranca FORCE ROW LEVEL SECURITY;
-- evento_auditoria_seguranca: NENHUMA policy e criada (secao 8) — RLS
-- habilitada com zero policies = fail-closed total, exatamente
-- ADR-001 V1.1 par.9.1 item 25.

-- ============================================================================
-- 1.5. Funcoes auxiliares de leitura segura de contexto (SECURITY_CONTEXT_
--      CONTRACT.md secao 3 — resolve o achado D2). NUNCA lancam excecao:
--      ausencia ou formato invalido do GUC sempre retorna NULL, nunca erro,
--      preservando fail-closed silencioso em toda a matriz.
-- ============================================================================
CREATE OR REPLACE FUNCTION contifisc_current_tenant_id() RETURNS uuid
LANGUAGE plpgsql STABLE AS $$
DECLARE
  raw text := current_setting('app.current_tenant_id', true);
BEGIN
  IF raw IS NULL OR raw = '' THEN
    RETURN NULL;
  END IF;
  RETURN raw::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION contifisc_current_conta_acesso_id() RETURNS uuid
LANGUAGE plpgsql STABLE AS $$
DECLARE
  raw text := current_setting('app.current_conta_acesso_id', true);
BEGIN
  IF raw IS NULL OR raw = '' THEN
    RETURN NULL;
  END IF;
  RETURN raw::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END;
$$;

-- ============================================================================
-- 1.6. Role interno de mediacao + funcoes SECURITY DEFINER de autorizacao
--      minima (CORRECAO dos achados CRITICAL C1/C2 do RLS_POC_REPORT.md —
--      ver RLS_POC_CORRECTION_REPORT.md secao "Causa raiz").
-- ============================================================================
--
-- CAUSA RAIZ (C1 e C2, ambas com a MESMA raiz): uma policy RLS que consulta,
-- via SQL comum, uma tabela que TAMBEM tem RLS+FORCE ativas, faz o
-- PostgreSQL reaplicar a policy dessa tabela consultada dentro da propria
-- avaliacao da policy externa. Quando a tabela consultada e a MESMA tabela
-- da policy (C1: vinculo_extremidade consultando vinculo_extremidade),
-- isso e recursao infinita, detectada e abortada pelo PostgreSQL. Quando e
-- uma tabela DIFERENTE mas com uma dimensao de contexto distinta (C2:
-- tenant consultando conta_acesso_tenant, que exige app.current_tenant_id
-- — dimensao que a policy de tenant deliberadamente NAO deveria exigir),
-- isso nao recursiona, mas reintroduz uma dependencia de contexto que o
-- desenho (SECURITY_CONTEXT_CONTRACT.md, resolucao de D2) pretendia
-- eliminar. Confirmado empiricamente (nao apenas por leitura de codigo) no
-- RLS_POC_REPORT.md original.
--
-- POR QUE ACONTECE SO PARA ROLE SEM BYPASSRLS: a decisao desta revisao de
-- ativar FORCE ROW LEVEL SECURITY nas 25 tabelas (secao 1) significa que
-- RLS se aplica a QUALQUER role sem BYPASSRLS/superuser executando a
-- consulta interna — inclusive o dono das tabelas, se ele nao tiver
-- BYPASSRLS. Um teste rodado como `postgres` (superuser, BYPASSRLS=true
-- por padrao) NUNCA reproduziria C1/C2, porque RLS e completamente
-- ignorada para esse role em qualquer consulta, direta ou aninhada dentro
-- de uma policy — e exatamente por isso os testes deste PoC sempre rodam
-- sob `contifisc_app_test` (NOSUPERUSER, NOBYPASSRLS), nunca como
-- `postgres`.
--
-- QUAIS OBJETOS PRECISAM DE MEDIACAO PRIVILEGIADA (e SOMENTE esses):
--   - a policy de `tenant` precisa verificar a existencia de uma linha em
--     `conta_acesso_tenant` sem que essa verificacao esteja, ela mesma,
--     sujeita a RLS de `conta_acesso_tenant` (senao reintroduz C2);
--   - as policies de `vinculo` e `vinculo_extremidade` precisam verificar
--     se QUALQUER extremidade de um dado `vinculo_id` e uma UE do tenant
--     ativo, sem que essa verificacao esteja sujeita a RLS de
--     `vinculo_extremidade`/`unidade_economica` (senao reintroduz C1).
-- NENHUM outro objeto da matriz precisa deste mecanismo — as demais 22
-- tabelas resolvem tenant consultando SOMENTE `unidade_economica` sob a
-- MESMA variavel (`app.current_tenant_id`) que ja protege a tabela
-- derivada, o que e redundante mas nunca conflitante (confirmado no PoC
-- original: T01-T09/T13/T25 todos corretos sem nenhuma mediacao).

CREATE ROLE contifisc_rls_mediator NOSUPERUSER NOLOGIN BYPASSRLS;
COMMENT ON ROLE contifisc_rls_mediator IS
  'Role interno, sem LOGIN, usado exclusivamente como owner das funcoes '
  'SECURITY DEFINER de mediacao de autorizacao cross-table desta secao. '
  'BYPASSRLS e necessario para que essas 2 funcoes consigam ler '
  'conta_acesso_tenant/vinculo_extremidade/unidade_economica sem '
  'reaplicar a RLS dessas tabelas (FORCE ROW LEVEL SECURITY exige '
  'BYPASSRLS explicito mesmo para o dono). NUNCA usado como role de '
  'runtime, migration ou provisioning; NUNCA concedido a ContaAcesso '
  'real; NUNCA usado fora destas 2 funcoes.';

-- CORRECAO DE EXECUTABILIDADE (achado desta revisao -- a primeira tentativa
-- de deploy no Neon DEV falhou com "must be able to SET ROLE
-- contifisc_rls_mediator", ver RLS_NEON_DEPLOYMENT_REPORT.md). O role que
-- executa esta migration (CURRENT_USER -- neondb_owner no Neon, `postgres`
-- nos containers descartaveis) precisa conseguir SET ROLE para o mediator
-- para poder transferir a propriedade das 2 funcoes abaixo (ALTER FUNCTION
-- ... OWNER TO). CREATE ROLE nao concede essa capacidade automaticamente,
-- mesmo quando o criador tem CREATEROLE. Concedida apenas durante esta
-- migration, revogada antes do fim desta secao -- nao permanece como
-- privilegio permanente. CURRENT_USER (nao um nome fixo como
-- "neondb_owner") mantem a migration portavel entre ambientes
-- (DEV/staging/producao), qualquer que seja o role real usado.
GRANT contifisc_rls_mediator TO CURRENT_USER;
-- Necessario tambem: ALTER ... OWNER TO exige que o NOVO dono tenha
-- privilegio CREATE no schema de destino (protecao do proprio PostgreSQL
-- contra escalacao de privilegio via troca de dono, presente desde a
-- reforma de privilegios do schema public na v15) -- confirmado
-- empiricamente nesta correcao: sem este GRANT, o ALTER FUNCTION falha com
-- "permission denied for schema public" mesmo com a membership acima.
-- Tambem temporario, revogado no fim desta secao.
GRANT CREATE ON SCHEMA public TO contifisc_rls_mediator;

-- --- Funcao 1: resolve C2 (policy definitiva de `tenant`) -------------------
-- Responsabilidade MINIMA: responder true/false para "esta conta_acesso_id
-- possui concessao (ContaAcessoTenant) para este tenant_id?" — nunca
-- retorna linhas, nunca aceita SQL dinamico, nunca depende de
-- app.current_tenant_id.
CREATE OR REPLACE FUNCTION contifisc_conta_tem_acesso_tenant(
  p_conta_acesso_id uuid,
  p_tenant_id uuid
) RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.conta_acesso_tenant cat
    WHERE cat.conta_acesso_id = p_conta_acesso_id
      AND cat.tenant_id = p_tenant_id
  );
$$;

ALTER FUNCTION contifisc_conta_tem_acesso_tenant(uuid, uuid) OWNER TO contifisc_rls_mediator;
COMMENT ON FUNCTION contifisc_conta_tem_acesso_tenant(uuid, uuid) IS
  'SECURITY DEFINER, owner=contifisc_rls_mediator (BYPASSRLS). Resolve '
  'C2 do RLS_POC_REPORT.md: verifica a concessao ContaAcessoTenant sem '
  'reaplicar a RLS de conta_acesso_tenant. Retorna apenas boolean — '
  'nunca expoe linhas. p_conta_acesso_id/p_tenant_id NULL -> comparacao '
  'nunca casa -> false (fail-closed por construcao, sem tratamento '
  'especial). search_path fixo (pg_catalog, public) e todas as '
  'referencias qualificadas com schema — protege contra sequestro via '
  'search_path de sessao (SD07/SD08). Sem SQL dinamico (SD09).';

REVOKE ALL ON FUNCTION contifisc_conta_tem_acesso_tenant(uuid, uuid) FROM PUBLIC;
-- GRANT EXECUTE ao role de runtime real fica para o provisionamento —
-- neste DRAFT, o GRANT e feito apenas no ambiente de PoC descartavel
-- (nao neste arquivo), sobre o role de teste equivalente.

-- contifisc_rls_mediator NAO e dono das tabelas nem superuser — precisa de
-- SELECT explicito para conseguir ler dentro da funcao SECURITY DEFINER
-- (achado desta PoC de correcao: a primeira tentativa de execucao falhou
-- com "permission denied for table conta_acesso_tenant" ate este GRANT ser
-- adicionado — SECURITY DEFINER muda o role efetivo, mas nao contorna
-- GRANT/REVOKE de tabela, apenas RLS). Privilegio minimo: SOMENTE SELECT,
-- SOMENTE nesta tabela, nada de INSERT/UPDATE/DELETE.
GRANT SELECT ON conta_acesso_tenant TO contifisc_rls_mediator;

-- --- Funcao 2: resolve C1 (policies de `vinculo`/`vinculo_extremidade`) -----
-- Responsabilidade MINIMA: responder true/false para "este vinculo_id tem
-- ALGUMA extremidade que e uma UnidadeEconomica pertencente a este
-- tenant_id?" — cobre simultaneamente os dois casos do desenho original
-- (extremidade propria e UE; ou extremidade propria e PF/PJ e a
-- extremidade IRMA e que e UE), sem precisar distinguir os dois casos e
-- sem recursionar, porque a consulta interna roda como
-- contifisc_rls_mediator (BYPASSRLS), nao como o role chamador.
CREATE OR REPLACE FUNCTION contifisc_vinculo_tem_extremidade_no_tenant(
  p_vinculo_id uuid,
  p_tenant_id uuid
) RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.vinculo_extremidade ve
    JOIN public.unidade_economica ue ON ue.id = ve.unidade_economica_id
    WHERE ve.vinculo_id = p_vinculo_id
      AND ue.tenant_id = p_tenant_id
  );
$$;

ALTER FUNCTION contifisc_vinculo_tem_extremidade_no_tenant(uuid, uuid) OWNER TO contifisc_rls_mediator;
COMMENT ON FUNCTION contifisc_vinculo_tem_extremidade_no_tenant(uuid, uuid) IS
  'SECURITY DEFINER, owner=contifisc_rls_mediator (BYPASSRLS). Resolve '
  'C1 do RLS_POC_REPORT.md: verifica se QUALQUER extremidade do vinculo '
  'e uma UE do tenant informado, sem reaplicar a RLS de '
  'vinculo_extremidade/unidade_economica (o que causava recursao '
  'infinita). Retorna apenas boolean. p_vinculo_id/p_tenant_id NULL -> '
  'false por construcao. search_path fixo, referencias qualificadas, '
  'sem SQL dinamico (mesmo hardening da funcao anterior).';

REVOKE ALL ON FUNCTION contifisc_vinculo_tem_extremidade_no_tenant(uuid, uuid) FROM PUBLIC;

-- Mesmo motivo do GRANT acima — privilegio minimo, apenas SELECT, apenas
-- nas 2 tabelas que esta funcao especifica le.
GRANT SELECT ON vinculo_extremidade TO contifisc_rls_mediator;
GRANT SELECT ON unidade_economica TO contifisc_rls_mediator;

-- Revoga os dois privilegios temporarios concedidos acima -- ambas as
-- transferencias de propriedade ja aconteceram (ALTER FUNCTION ... OWNER TO
-- e permanente, nao depende de a membership continuar ativa). A partir
-- daqui, CURRENT_USER (o role de migration) NAO consegue mais executar
-- `SET ROLE contifisc_rls_mediator` (confirmado empiricamente -- ver
-- RLS_NEON_DEPLOYMENT_REPORT.md) nem tem mais CREATE no schema public via
-- este grant especifico. Residual conhecido, nao removivel sem superuser:
-- quando o migration role tem CREATEROLE (caso do neondb_owner no Neon), o
-- proprio PostgreSQL 16+ concede a ele, automaticamente e no momento do
-- CREATE ROLE, uma entrada com admin_option=true/set_option=false em
-- pg_auth_members para o role recem-criado -- isso permite ao migration
-- role gerenciar futuramente a concessao (GRANT/REVOKE esse role a
-- terceiros), mas NAO permite `SET ROLE`/assumir a identidade do mediator
-- (essa capacidade especifica permanece bloqueada apos este REVOKE, que e
-- a garantia de seguranca relevante aqui). Esse residual e uma
-- caracteristica inerente do modelo CREATEROLE do PostgreSQL, nao uma
-- falha desta migration -- documentado, nao escondido.
REVOKE CREATE ON SCHEMA public FROM contifisc_rls_mediator;
REVOKE contifisc_rls_mediator FROM CURRENT_USER;

-- ============================================================================
-- 2. TENANT_ID_RAIZ — unidade_economica
-- ============================================================================
CREATE POLICY tenant_isolation ON unidade_economica
  FOR ALL
  USING (tenant_id = contifisc_current_tenant_id())
  WITH CHECK (tenant_id = contifisc_current_tenant_id());
-- Policy unica (FOR ALL): USING e WITH CHECK sao identicos porque tenant_id
-- e coluna propria — nao ha diferenca de garantia entre separar por
-- comando. UPDATE tentando mover a UE para outro tenant e bloqueado pelo
-- WITH CHECK (T10); reforcado por trg_ue_tenant_change_guard (ja ativo na
-- migration inaugural, ADR-C014 Race 3).

-- ============================================================================
-- 3. GLOBAL_COMPARTILHADO — pessoa_fisica, pessoa_juridica, fonte_pagadora,
--    conta_acesso (decisao desta revisao: policy permissiva explicita, nao
--    ausencia de RLS — ver RLS_DESIGN_REVIEW.md D1, MENOR)
-- ============================================================================
CREATE POLICY global_sem_isolamento_tenant ON pessoa_fisica
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY global_sem_isolamento_tenant ON pessoa_juridica
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY global_sem_isolamento_tenant ON fonte_pagadora
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY global_sem_isolamento_tenant ON conta_acesso
  FOR ALL USING (true) WITH CHECK (true);
-- O isolamento entre tenants NAO depende de restringir visibilidade destas
-- 4 tabelas — depende exclusivamente da RLS dos FATOS que as referenciam
-- (ADR-001 V1.1 par.10). Uma identidade global compartilhada nunca e, por
-- si so, concessao de acesso a fatos de outro tenant.

-- ============================================================================
-- 4. TENANT_DERIVADO_POR_RLS — 1 hop direto via unidade_economica_id
-- ============================================================================
CREATE POLICY tenant_isolation ON receita
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = receita.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = receita.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON contribuicao_previdenciaria
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = contribuicao_previdenciaria.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = contribuicao_previdenciaria.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON vinculo_previdenciario
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = vinculo_previdenciario.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = vinculo_previdenciario.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON evento_irpf
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = evento_irpf.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = evento_irpf.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON documento_fiscal
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = documento_fiscal.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = documento_fiscal.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON cenario_tributario
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = cenario_tributario.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = cenario_tributario.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON resultado_calculo
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = resultado_calculo.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = resultado_calculo.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));
-- resultado_calculo.unidade_economica_id e Imutavel (ADR-001 par.13.2, sem
-- trigger de banco) — o WITH CHECK acima e rede de seguranca adicional,
-- nao o unico mecanismo de imutabilidade (que continua sendo disciplina de
-- aplicacao).

CREATE POLICY tenant_isolation ON conta_acesso_unidade_economica
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = conta_acesso_unidade_economica.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM unidade_economica ue
    WHERE ue.id = conta_acesso_unidade_economica.unidade_economica_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));
-- Esta policy NAO substitui ADR-C014 (trg_caue_requires_grant_fixed, ja
-- ativo na migration inaugural). RLS restringe visibilidade/escrita por
-- tenant; ADR-C014 garante o invariante de negocio "toda restricao de UE
-- pressupoe concessao de Tenant". Os dois mecanismos sao independentes e
-- coexistem sem conflito (ver RLS_DESIGN_REVIEW.md D3).

-- ============================================================================
-- 5. TENANT_DERIVADO_POR_RLS — 2 hops
-- ============================================================================
CREATE POLICY tenant_isolation ON receita_documento_fiscal
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM receita r
    JOIN unidade_economica ue ON ue.id = r.unidade_economica_id
    WHERE r.id = receita_documento_fiscal.receita_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM receita r
    JOIN unidade_economica ue ON ue.id = r.unidade_economica_id
    WHERE r.id = receita_documento_fiscal.receita_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON documento_fiscal_arquivo_origem
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM documento_fiscal df
    JOIN unidade_economica ue ON ue.id = df.unidade_economica_id
    WHERE df.id = documento_fiscal_arquivo_origem.documento_fiscal_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM documento_fiscal df
    JOIN unidade_economica ue ON ue.id = df.unidade_economica_id
    WHERE df.id = documento_fiscal_arquivo_origem.documento_fiscal_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation ON classificacao_equiparacao_hospitalar
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM receita r
    JOIN unidade_economica ue ON ue.id = r.unidade_economica_id
    WHERE r.id = classificacao_equiparacao_hospitalar.receita_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM receita r
    JOIN unidade_economica ue ON ue.id = r.unidade_economica_id
    WHERE r.id = classificacao_equiparacao_hospitalar.receita_id
      AND ue.tenant_id = contifisc_current_tenant_id()
  ));

-- ============================================================================
-- 6. TENANT_DERIVADO_POR_RLS — vinculo / vinculo_extremidade (caso especial:
--    exceção residual quando nenhuma extremidade é UE — DST-GAP-003 /
--    GAP-SEC-CR1-002, já reconhecida NAO_BLOQUEANTE por ADR-001 V1.1 par.14)
-- ============================================================================
-- CORRIGIDO (era recursao infinita, C1 do RLS_POC_REPORT.md) — agora usa
-- contifisc_vinculo_tem_extremidade_no_tenant() (secao 1.6), que roda como
-- contifisc_rls_mediator (BYPASSRLS) e portanto nao reaplica a RLS desta
-- mesma tabela. Cobre os dois casos originais (extremidade propria UE;
-- extremidade propria PF/PJ com irma UE) num unico predicado, porque a
-- funcao verifica QUALQUER extremidade do vinculo, nao so a linha atual.
--
-- C3 (achado desta MESMA PoC de correcao, nao fazia parte do escopo C1/C2
-- original, mas descoberto ao testar INSERT de Vinculo novo — ver
-- RLS_POC_CORRECTION_REPORT.md): uma unica policy FOR ALL usando a funcao
-- acima e IMPOSSIVEL de satisfazer no INSERT de um Vinculo NOVO — a funcao
-- exige que ja exista uma extremidade no tenant ativo, mas um Vinculo novo
-- comeca com ZERO extremidades (elas so existem apos o proprio INSERT).
-- Testado empiricamente: nem inserir as 2 extremidades juntas num unico
-- INSERT multi-linha resolve (linhas da mesma instrucao nao se enxergam
-- via sub-SELECT dentro do WITH CHECK). Correcao: separar em policies por
-- comando — INSERT fica com uma regra MINIMA e DIRETA (nunca dependente de
-- outra linha da mesma tabela), SELECT/UPDATE/DELETE continuam usando a
-- funcao (que por essa altura ja encontra as extremidades existentes).
CREATE POLICY tenant_isolation_select ON vinculo_extremidade
  FOR SELECT
  USING (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo_extremidade.vinculo_id, contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation_insert ON vinculo_extremidade
  FOR INSERT
  WITH CHECK (
    -- Extremidade e UE: precisa pertencer ao tenant ativo (verificacao
    -- DIRETA contra unidade_economica, nunca contra a propria
    -- vinculo_extremidade — sem dependencia circular).
    (unidade_economica_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM unidade_economica ue
      WHERE ue.id = vinculo_extremidade.unidade_economica_id
        AND ue.tenant_id = contifisc_current_tenant_id()
    ))
    -- Extremidade e PF/PJ (sem UE): nao carrega tenant proprio — permitido
    -- na escrita (nao ha o que validar aqui sem a extremidade irma, que
    -- pode nao existir ainda na mesma transacao); a garantia de isolamento
    -- continua vindo do SELECT (que exige alguma extremidade UE do tenant
    -- ativo) e de ADR-C005 (cardinalidade exata=2, ja ativo). Nao amplia
    -- superficie de vazamento: uma extremidade PF/PJ sozinha nunca revela
    -- nem concede acesso a nenhum fato tributario.
    OR unidade_economica_id IS NULL
  );

CREATE POLICY tenant_isolation_update ON vinculo_extremidade
  FOR UPDATE
  USING (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo_extremidade.vinculo_id, contifisc_current_tenant_id()
  ))
  WITH CHECK (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo_extremidade.vinculo_id, contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation_delete ON vinculo_extremidade
  FOR DELETE
  USING (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo_extremidade.vinculo_id, contifisc_current_tenant_id()
  ));

-- Mesma correcao C3, mesma logica, para `vinculo`: o proprio Vinculo nao
-- tem NENHUMA coluna que identifique tenant (nem propria, nem FK direta —
-- ADR-001 e explicito que o tenant e 100% derivado das extremidades),
-- entao o INSERT do Vinculo (linha-pai, sem filhas ainda) NUNCA pode ser
-- validado no momento da propria insercao — fica permissivo por
-- necessidade estrutural, nao por escolha de design. A garantia real
-- continua em 3 camadas: (1) FK vinculo_extremidade.vinculo_id -> vinculo.id
-- exige que o pai exista antes das filhas (nao o contrario); (2) ADR-C005
-- exige exatamente 2 extremidades ate o COMMIT, ou a transacao inteira
-- falha (nenhum Vinculo "vazio" sobrevive); (3) SELECT/UPDATE/DELETE em
-- `vinculo` continuam exigindo extremidade no tenant ativo — um Vinculo
-- inserido sem extremidades validas do tenant certo fica permanentemente
-- invisivel (fail-closed), nunca acessivel por ninguem.
CREATE POLICY tenant_isolation_select ON vinculo
  FOR SELECT
  USING (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo.id, contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation_insert ON vinculo
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY tenant_isolation_update ON vinculo
  FOR UPDATE
  USING (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo.id, contifisc_current_tenant_id()
  ))
  WITH CHECK (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo.id, contifisc_current_tenant_id()
  ));

CREATE POLICY tenant_isolation_delete ON vinculo
  FOR DELETE
  USING (contifisc_vinculo_tem_extremidade_no_tenant(
    vinculo.id, contifisc_current_tenant_id()
  ));
-- LIMITACAO CONHECIDA (nao um bug de isolamento — fail-closed-seguro):
-- um Vinculo cujas DUAS extremidades sejam PF/PJ (nenhuma UE) nao tem
-- tenant resolvivel por nenhum caminho acima e fica invisivel sob RLS a
-- QUALQUER tenant, ate DST-GAP-003/GAP-SEC-CR1-002 fecharem. Nunca vaza
-- dado cross-tenant; apenas super-restringe esse caso residual ainda sem
-- vinculo com UE. Ja reconhecido NAO_BLOQUEANTE por ADR-001 V1.1 par.14.

-- ============================================================================
-- 7. TENANT_ID_MATERIALIZADO — coluna própria
-- ============================================================================
CREATE POLICY tenant_isolation ON arquivo_origem
  FOR ALL
  USING (tenant_id = contifisc_current_tenant_id())
  WITH CHECK (tenant_id = contifisc_current_tenant_id());

CREATE POLICY tenant_isolation ON conflito_dado
  FOR ALL
  USING (tenant_id = contifisc_current_tenant_id())
  WITH CHECK (tenant_id = contifisc_current_tenant_id());

CREATE POLICY tenant_isolation ON revisao_tecnica
  FOR ALL
  USING (tenant_id = contifisc_current_tenant_id())
  WITH CHECK (tenant_id = contifisc_current_tenant_id());

CREATE POLICY tenant_isolation ON conta_acesso_tenant
  FOR ALL
  USING (tenant_id = contifisc_current_tenant_id())
  WITH CHECK (tenant_id = contifisc_current_tenant_id());
-- Nos 4 casos acima, WITH CHECK no INSERT impede aceitar tenant_id vindo de
-- payload de API divergente do contexto de sessao (ADR-001 par.8) — a
-- camada de aplicacao ainda deve preencher tenant_id a partir do contexto
-- (nunca do payload), mas o banco agora rejeita fisicamente uma tentativa
-- de payload malicioso mesmo que a aplicacao falhe em filtrar.

-- ============================================================================
-- 8. TENANT_DERIVADO_DO_PAI — conflito_dado_item
-- ============================================================================
CREATE POLICY tenant_isolation ON conflito_dado_item
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM conflito_dado cd
    WHERE cd.id = conflito_dado_item.conflito_dado_id
      AND cd.tenant_id = contifisc_current_tenant_id()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM conflito_dado cd
    WHERE cd.id = conflito_dado_item.conflito_dado_id
      AND cd.tenant_id = contifisc_current_tenant_id()
  ));
-- A referencia polimorfica objeto_id/tipo_objeto NUNCA e usada para derivar
-- tenant (ADR-D024) — apenas conflito_dado_id.

-- ============================================================================
-- 9. RAIZ_PROPRIA_VISIVEL_POR_CONCESSAO — tenant (POLICY DEFINITIVA — D2
--    RESOLVIDO NO DESENHO, ver SECURITY_CONTEXT_CONTRACT.md secao 5)
-- ============================================================================
-- CORRIGIDO (dependia indevidamente de app.current_tenant_id via RLS de
-- conta_acesso_tenant, C2 do RLS_POC_REPORT.md) — agora usa
-- contifisc_conta_tem_acesso_tenant() (secao 1.6), que roda como
-- contifisc_rls_mediator (BYPASSRLS) e portanto nao reaplica a RLS de
-- conta_acesso_tenant. A policy volta a depender SOMENTE de
-- app.current_conta_acesso_id, exatamente como o contrato (D2) exige.
CREATE POLICY tenant_isolation ON tenant
  FOR ALL
  USING (contifisc_conta_tem_acesso_tenant(
    contifisc_current_conta_acesso_id(), tenant.id
  ))
  WITH CHECK (contifisc_conta_tem_acesso_tenant(
    contifisc_current_conta_acesso_id(), tenant.id
  ));
-- Implementa a categoria conceitual completa do ADR-001 V1.1 par.9.1 item 21
-- (visibilidade por concessao explicita via conta_acesso_tenant). Usa
-- app.current_conta_acesso_id (AUTHENTICATED ACCOUNT CONTEXT), nao
-- app.current_tenant_id — deliberado: responde "quais tenants esta conta
-- pode enxergar" (plural), nao "qual tenant esta ativo agora". O banco
-- verifica a concessao diretamente via funcao de mediacao — nunca confia em
-- tenant_id fornecido livremente pela aplicacao.
--
-- NOTA OPERACIONAL (nao resolvida por policy, ver contrato secao 5):
-- provisionar um Tenant novo (sem nenhuma ContaAcessoTenant ainda) exige um
-- role administrativo com BYPASSRLS (contifisc_provisioning, proposto,
-- NAO criado por este script) — com FORCE ROW LEVEL SECURITY ativa, nem o
-- dono da tabela passa neste WITH CHECK para o primeiro INSERT de um
-- tenant. Comportamento esperado do fail-closed universal, nao uma falha.

-- ============================================================================
-- 10. BLOQUEADO — evento_auditoria_seguranca: RLS habilitada (secao 1),
--     ZERO policies. Nenhum CREATE POLICY nesta secao — fail-closed total
--     por ausencia de regra, ate GAP-CDC-1.3-002 fechar
--     (ADR-001 V1.1 par.9.1 item 25).
-- ============================================================================

-- ============================================================================
-- FIM DO DRAFT. Nenhuma linha acima foi executada contra Neon DEV ou
-- qualquer banco persistente por esta sessao.
-- ============================================================================
