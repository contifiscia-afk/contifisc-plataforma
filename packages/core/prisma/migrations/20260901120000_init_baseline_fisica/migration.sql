-- ============================================================================
-- Primeira migration canônica CONTIFISC — ARTEFATO DE REVISÃO, NÃO APLICADA
-- ============================================================================
-- Gerada a partir de `prisma/schema.prisma` (v3, com a Errata controlada nº2
-- do ADR-001 incorporada) via `prisma migrate diff --from-empty
-- --to-schema-datamodel prisma/schema.prisma --script` (nenhuma conexão com
-- banco de dados real ou shadow database foi necessária para gerar a seção
-- Prisma abaixo).
--
-- Esta migration NÃO foi aplicada a nenhum banco (`prisma migrate dev`,
-- `prisma migrate deploy` e `prisma db push` NÃO foram executados). É um
-- artefato de revisão humana, conforme autorizado.
--
-- Estrutura deste arquivo:
--   SEÇÃO 1 — SQL gerado automaticamente pelo Prisma (CREATE TABLE, índices
--             declarados via @@unique/@@index, FKs declaradas via @relation).
--   SEÇÃO 2 — SQL manual complementar, contendo EXCLUSIVAMENTE as constraints
--             já autorizadas pelo ADR-001 e suas erratas (ADR-C001..C005,
--             ADR-C009, mais os CHECKs de vocabulário fechado DST previstos
--             em ADR-D010). Nenhuma constraint nova foi inventada aqui — cada
--             uma corresponde a uma linha específica da matriz ADR → SQL em
--             `prisma/migrations/20260901120000_init_baseline_fisica/ADR_TO_SQL_MATRIX.md`.
--
-- Gaps deliberadamente NÃO implementados nesta migration (preservados,
-- conforme instruído — não resolvidos por inferência):
--   - ADR-GAP-007 (MCD-F9009 em receita/contribuicao_previdenciaria/evento_irpf)
--   - ADR-GAP-008 (MCD-F9007 em resultado_calculo/revisao_tecnica)
--   - F9005/F9006 (versao_schema/correlation_id) — BLOQUEADO POR EVT-001/INT-001
--   - SEC-001, tenant isolation, autenticação, RLS — fora de escopo
-- ============================================================================

-- ============================================================================
-- SEÇÃO 1 — SQL gerado pelo Prisma (`prisma migrate diff`, sem edição manual)
-- ============================================================================

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "unidade_economica" (
    "id" UUID NOT NULL,
    "nome" VARCHAR(160) NOT NULL,
    "status_registro" TEXT NOT NULL,
    "criado_em" TIMESTAMPTZ NOT NULL,
    "atualizado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "unidade_economica_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pessoa_fisica" (
    "id" UUID NOT NULL,
    "cpf" VARCHAR(11),
    "nome" VARCHAR(200) NOT NULL,
    "data_nascimento" DATE,
    "conselho_profissional" TEXT,
    "registro_profissional" VARCHAR(30),
    "uf_registro_profissional" VARCHAR(2),
    "especialidade_saude" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "pessoa_fisica_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pessoa_juridica" (
    "id" UUID NOT NULL,
    "cnpj" VARCHAR(14),
    "razao_social" VARCHAR(200),
    "regime_tributario" TEXT,
    "cnae_principal" VARCHAR(7),
    "data_abertura" DATE,
    "municipio_ibge" VARCHAR(7),
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "pessoa_juridica_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vinculo" (
    "id" UUID NOT NULL,
    "tipo_vinculo" TEXT NOT NULL,
    "percentual_participacao_societaria" DECIMAL(7,4),
    "vigencia_inicio" DATE,
    "vigencia_fim" DATE,
    "papel_vinculo" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "vinculo_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vinculo_extremidade" (
    "id" UUID NOT NULL,
    "vinculo_id" UUID NOT NULL,
    "lado_extremidade" TEXT NOT NULL,
    "unidade_economica_id" UUID,
    "pessoa_fisica_id" UUID,
    "pessoa_juridica_id" UUID,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "vinculo_extremidade_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "receita" (
    "id" UUID NOT NULL,
    "valor_receita_bruta" DECIMAL(18,2),
    "data_emissao" DATE,
    "competencia" VARCHAR(7),
    "fonte_receita" TEXT,
    "fonte_pagadora_id" UUID,
    "valor_retencoes" DECIMAL(18,2),
    "pessoa_fisica_id" UUID,
    "pessoa_juridica_id" UUID,
    "sistema_origem" TEXT NOT NULL,
    "identificador_origem" VARCHAR(120),
    "importado_em" TIMESTAMPTZ,
    "status_processamento_dado" TEXT,
    "status_qualidade_dado" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,
    "data_fato" TIMESTAMPTZ,

    CONSTRAINT "receita_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "documento_fiscal" (
    "id" UUID NOT NULL,
    "tipo_documento_fiscal" TEXT NOT NULL,
    "numero_documento_fiscal" VARCHAR(60),
    "chave_documento_fiscal" VARCHAR(80),
    "codigo_servico_fiscal" VARCHAR(30),
    "descricao_servico_fiscal" TEXT,
    "valor_documento_fiscal" DECIMAL(18,2),
    "sistema_origem" TEXT NOT NULL,
    "identificador_origem" VARCHAR(120),
    "importado_em" TIMESTAMPTZ,
    "status_processamento_dado" TEXT,
    "status_qualidade_dado" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "documento_fiscal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "receita_documento_fiscal" (
    "id" UUID NOT NULL,
    "receita_id" UUID NOT NULL,
    "documento_fiscal_id" UUID NOT NULL,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "receita_documento_fiscal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "arquivo_origem" (
    "id" UUID NOT NULL,
    "nome_arquivo" VARCHAR(255),
    "hash_conteudo" VARCHAR(128) NOT NULL,
    "tipo_mime" VARCHAR(120),
    "armazenamento_referencia" VARCHAR(500) NOT NULL,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "arquivo_origem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "documento_fiscal_arquivo_origem" (
    "id" UUID NOT NULL,
    "documento_fiscal_id" UUID NOT NULL,
    "arquivo_origem_id" UUID NOT NULL,
    "papel_arquivo" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "documento_fiscal_arquivo_origem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "classificacao_equiparacao_hospitalar" (
    "id" UUID NOT NULL,
    "status_elegibilidade_equiparacao_hospitalar" TEXT,
    "percentual_receita_elegivel" DECIMAL(7,4),
    "valor_receita_elegivel" DECIMAL(18,2),
    "valor_receita_nao_elegivel" DECIMAL(18,2),
    "percentual_confianca_classificacao" DECIMAL(7,4),
    "eh_validada_tecnicamente" BOOLEAN,
    "receita_id" UUID NOT NULL,
    "regra_versao_id" VARCHAR(120),
    "registrado_em" TIMESTAMPTZ NOT NULL,
    "atualizado_em" TIMESTAMPTZ,

    CONSTRAINT "classificacao_equiparacao_hospitalar_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "contribuicao_previdenciaria" (
    "id" UUID NOT NULL,
    "valor_inss_recolhido" DECIMAL(18,2),
    "valor_salario_contribuicao" DECIMAL(18,2),
    "valor_teto_previdenciario" DECIMAL(18,2),
    "valor_excedente_inss" DECIMAL(18,2),
    "vinculo_previdenciario_id" UUID,
    "pessoa_fisica_id" UUID NOT NULL,
    "sistema_origem" TEXT NOT NULL,
    "identificador_origem" VARCHAR(120),
    "importado_em" TIMESTAMPTZ,
    "status_processamento_dado" TEXT,
    "status_qualidade_dado" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,
    "data_fato" TIMESTAMPTZ,

    CONSTRAINT "contribuicao_previdenciaria_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vinculo_previdenciario" (
    "id" UUID NOT NULL,
    "pessoa_fisica_id" UUID NOT NULL,
    "tipo_vinculo_previdenciario" TEXT NOT NULL,
    "vigencia_inicio" DATE,
    "vigencia_fim" DATE,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "vinculo_previdenciario_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "evento_irpf" (
    "id" UUID NOT NULL,
    "tipo_rendimento_irpf" TEXT,
    "valor_rendimento_tributavel" DECIMAL(18,2),
    "valor_rendimento_isento" DECIMAL(18,2),
    "valor_deducao_irpf" DECIMAL(18,2),
    "valor_livro_caixa" DECIMAL(18,2),
    "valor_irpf_retido" DECIMAL(18,2),
    "valor_irpf_projetado" DECIMAL(18,2),
    "pessoa_fisica_id" UUID NOT NULL,
    "fonte_pagadora_id" UUID,
    "sistema_origem" TEXT NOT NULL,
    "identificador_origem" VARCHAR(120),
    "importado_em" TIMESTAMPTZ,
    "status_processamento_dado" TEXT,
    "status_qualidade_dado" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,
    "data_fato" TIMESTAMPTZ,

    CONSTRAINT "evento_irpf_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fonte_pagadora" (
    "id" UUID NOT NULL,
    "tipo_fonte_pagadora" TEXT NOT NULL,
    "identificador_fiscal" VARCHAR(20),
    "nome" VARCHAR(200),
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "fonte_pagadora_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cenario_tributario" (
    "id" UUID NOT NULL,
    "nome" VARCHAR(120) NOT NULL,
    "valor_carga_tributaria_projetada" DECIMAL(18,2),
    "valor_economia_tributaria_projetada" DECIMAL(18,2),
    "unidade_economica_id" UUID NOT NULL,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "cenario_tributario_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "resultado_calculo" (
    "id" UUID NOT NULL,
    "cenario_tributario_id" UUID,
    "input_snapshot_hash" VARCHAR(128) NOT NULL,
    "engine_id" VARCHAR(80) NOT NULL,
    "engine_version" VARCHAR(20) NOT NULL,
    "rule_set_id" VARCHAR(80) NOT NULL,
    "rule_set_version" VARCHAR(20) NOT NULL,
    "calculado_em" TIMESTAMPTZ NOT NULL,
    "status_revisao" TEXT,

    CONSTRAINT "resultado_calculo_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "conflito_dado" (
    "id" UUID NOT NULL,
    "status_conflito" TEXT NOT NULL,
    "tipo_conflito" TEXT NOT NULL,
    "descricao" TEXT,
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "conflito_dado_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "conflito_dado_item" (
    "id" UUID NOT NULL,
    "conflito_dado_id" UUID NOT NULL,
    "tipo_objeto" TEXT NOT NULL,
    "objeto_id" UUID,
    "sistema_origem" TEXT,
    "identificador_origem" VARCHAR(120),
    "papel_no_conflito" TEXT,
    "valor_hash" VARCHAR(128),
    "registrado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "conflito_dado_item_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "revisao_tecnica" (
    "id" UUID NOT NULL,
    "objeto_revisado_id" UUID NOT NULL,
    "tipo_objeto_revisado" TEXT NOT NULL,
    "status_revisao" TEXT NOT NULL,
    "justificativa" TEXT,
    "revisado_em" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "revisao_tecnica_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "uq_vinculo_lado" ON "vinculo_extremidade"("vinculo_id", "lado_extremidade");

-- CreateIndex
CREATE INDEX "receita_competencia_idx" ON "receita"("competencia");

-- CreateIndex
CREATE INDEX "documento_fiscal_chave_documento_fiscal_idx" ON "documento_fiscal"("chave_documento_fiscal");

-- CreateIndex
CREATE UNIQUE INDEX "uq_receita_documento_fiscal" ON "receita_documento_fiscal"("receita_id", "documento_fiscal_id");

-- CreateIndex
CREATE UNIQUE INDEX "uq_documento_fiscal_arquivo_origem" ON "documento_fiscal_arquivo_origem"("documento_fiscal_id", "arquivo_origem_id");

-- CreateIndex
CREATE INDEX "conflito_dado_item_objeto_id_idx" ON "conflito_dado_item"("objeto_id");

-- CreateIndex
CREATE INDEX "conflito_dado_item_sistema_origem_identificador_origem_idx" ON "conflito_dado_item"("sistema_origem", "identificador_origem");

-- CreateIndex
CREATE INDEX "revisao_tecnica_objeto_revisado_id_idx" ON "revisao_tecnica"("objeto_revisado_id");

-- AddForeignKey
ALTER TABLE "vinculo_extremidade" ADD CONSTRAINT "vinculo_extremidade_vinculo_id_fkey" FOREIGN KEY ("vinculo_id") REFERENCES "vinculo"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vinculo_extremidade" ADD CONSTRAINT "vinculo_extremidade_unidade_economica_id_fkey" FOREIGN KEY ("unidade_economica_id") REFERENCES "unidade_economica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vinculo_extremidade" ADD CONSTRAINT "vinculo_extremidade_pessoa_fisica_id_fkey" FOREIGN KEY ("pessoa_fisica_id") REFERENCES "pessoa_fisica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vinculo_extremidade" ADD CONSTRAINT "vinculo_extremidade_pessoa_juridica_id_fkey" FOREIGN KEY ("pessoa_juridica_id") REFERENCES "pessoa_juridica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "receita" ADD CONSTRAINT "receita_fonte_pagadora_id_fkey" FOREIGN KEY ("fonte_pagadora_id") REFERENCES "fonte_pagadora"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "receita" ADD CONSTRAINT "receita_pessoa_fisica_id_fkey" FOREIGN KEY ("pessoa_fisica_id") REFERENCES "pessoa_fisica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "receita" ADD CONSTRAINT "receita_pessoa_juridica_id_fkey" FOREIGN KEY ("pessoa_juridica_id") REFERENCES "pessoa_juridica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "receita_documento_fiscal" ADD CONSTRAINT "receita_documento_fiscal_receita_id_fkey" FOREIGN KEY ("receita_id") REFERENCES "receita"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "receita_documento_fiscal" ADD CONSTRAINT "receita_documento_fiscal_documento_fiscal_id_fkey" FOREIGN KEY ("documento_fiscal_id") REFERENCES "documento_fiscal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documento_fiscal_arquivo_origem" ADD CONSTRAINT "documento_fiscal_arquivo_origem_documento_fiscal_id_fkey" FOREIGN KEY ("documento_fiscal_id") REFERENCES "documento_fiscal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documento_fiscal_arquivo_origem" ADD CONSTRAINT "documento_fiscal_arquivo_origem_arquivo_origem_id_fkey" FOREIGN KEY ("arquivo_origem_id") REFERENCES "arquivo_origem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "classificacao_equiparacao_hospitalar" ADD CONSTRAINT "classificacao_equiparacao_hospitalar_receita_id_fkey" FOREIGN KEY ("receita_id") REFERENCES "receita"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "contribuicao_previdenciaria" ADD CONSTRAINT "contribuicao_previdenciaria_vinculo_previdenciario_id_fkey" FOREIGN KEY ("vinculo_previdenciario_id") REFERENCES "vinculo_previdenciario"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "contribuicao_previdenciaria" ADD CONSTRAINT "contribuicao_previdenciaria_pessoa_fisica_id_fkey" FOREIGN KEY ("pessoa_fisica_id") REFERENCES "pessoa_fisica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vinculo_previdenciario" ADD CONSTRAINT "vinculo_previdenciario_pessoa_fisica_id_fkey" FOREIGN KEY ("pessoa_fisica_id") REFERENCES "pessoa_fisica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evento_irpf" ADD CONSTRAINT "evento_irpf_pessoa_fisica_id_fkey" FOREIGN KEY ("pessoa_fisica_id") REFERENCES "pessoa_fisica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "evento_irpf" ADD CONSTRAINT "evento_irpf_fonte_pagadora_id_fkey" FOREIGN KEY ("fonte_pagadora_id") REFERENCES "fonte_pagadora"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cenario_tributario" ADD CONSTRAINT "cenario_tributario_unidade_economica_id_fkey" FOREIGN KEY ("unidade_economica_id") REFERENCES "unidade_economica"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resultado_calculo" ADD CONSTRAINT "resultado_calculo_cenario_tributario_id_fkey" FOREIGN KEY ("cenario_tributario_id") REFERENCES "cenario_tributario"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conflito_dado_item" ADD CONSTRAINT "conflito_dado_item_conflito_dado_id_fkey" FOREIGN KEY ("conflito_dado_id") REFERENCES "conflito_dado"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ============================================================================
-- SEÇÃO 2 — SQL manual complementar (constraints já autorizadas pelo ADR-001)
-- Nenhum PostgreSQL ENUM foi criado nesta seção (ADR-D010).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ADR-C001 — Receita: ownership PF/PJ XOR
-- ----------------------------------------------------------------------------
ALTER TABLE "receita" ADD CONSTRAINT "ck_receita_ownership_xor" CHECK (
  (
    (pessoa_fisica_id IS NOT NULL)::int
    + (pessoa_juridica_id IS NOT NULL)::int
  ) = 1
);

-- ----------------------------------------------------------------------------
-- ADR-C002 — VinculoExtremidade: endpoint XOR (exatamente uma FK entre UE/PF/PJ)
-- ----------------------------------------------------------------------------
ALTER TABLE "vinculo_extremidade" ADD CONSTRAINT "ck_vinculo_extremidade_endpoint_xor" CHECK (
  (
    (unidade_economica_id IS NOT NULL)::int
    + (pessoa_fisica_id IS NOT NULL)::int
    + (pessoa_juridica_id IS NOT NULL)::int
  ) = 1
);

-- ----------------------------------------------------------------------------
-- ADR-C004 / DST-E012 — VinculoExtremidade.lado_extremidade (fechado)
-- ----------------------------------------------------------------------------
ALTER TABLE "vinculo_extremidade" ADD CONSTRAINT "ck_vinculo_extremidade_lado" CHECK (
  lado_extremidade IN ('ORIGEM', 'DESTINO')
);

-- ----------------------------------------------------------------------------
-- ADR-C005 / COT-REL-NORM-001 — Vinculo deve ter EXATAMENTE duas
-- VinculoExtremidade (1 ORIGEM + 1 DESTINO). Constraint trigger DEFERRABLE
-- INITIALLY DEFERRED, EXATAMENTE conforme validado pela PoC
-- (poc/adr-001-vinculo-extremidade/sql/001_schema.sql) — mesma lógica, mesmos
-- nomes de tabela/coluna, sem nenhuma alteração de comportamento.
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- ADR-C009 — Receita.competencia: formato YYYY-MM, mês 01..12
-- ----------------------------------------------------------------------------
ALTER TABLE "receita" ADD CONSTRAINT "ck_receita_competencia_formato" CHECK (
  competencia IS NULL OR competencia ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
);

-- ----------------------------------------------------------------------------
-- ADR-D010 — vocabulários fechados do DST materializados como TEXT + CHECK
-- (nunca ENUM nativo do PostgreSQL/Prisma).
-- ----------------------------------------------------------------------------

-- DST-E008 — UnidadeEconomica.status_registro
ALTER TABLE "unidade_economica" ADD CONSTRAINT "ck_unidade_economica_status_registro" CHECK (
  status_registro IN ('ATIVO', 'INATIVO', 'ARQUIVADO')
);

-- DST-E001 — PessoaJuridica.regime_tributario
ALTER TABLE "pessoa_juridica" ADD CONSTRAINT "ck_pessoa_juridica_regime_tributario" CHECK (
  regime_tributario IS NULL OR regime_tributario IN (
    'SIMPLES_NACIONAL', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'OUTRO', 'NAO_INFORMADO'
  )
);

-- DST-E003 — ClassificacaoEquiparacaoHospitalar.status_elegibilidade_equiparacao_hospitalar
ALTER TABLE "classificacao_equiparacao_hospitalar" ADD CONSTRAINT "ck_classificacao_eqhop_status_elegibilidade" CHECK (
  status_elegibilidade_equiparacao_hospitalar IS NULL OR status_elegibilidade_equiparacao_hospitalar IN (
    'EH_001_ELEGIVEL', 'EH_002_NAO_ELEGIVEL', 'EH_003_PENDENTE', 'EH_004_REVISAO_TECNICA'
  )
);

-- DST-E004 — EventoIRPF.tipo_rendimento_irpf
ALTER TABLE "evento_irpf" ADD CONSTRAINT "ck_evento_irpf_tipo_rendimento" CHECK (
  tipo_rendimento_irpf IS NULL OR tipo_rendimento_irpf IN (
    'TRIBUTAVEL', 'ISENTO_NAO_TRIBUTAVEL', 'TRIBUTACAO_EXCLUSIVA', 'OUTRO', 'NAO_INFORMADO'
  )
);

-- DST-E005 — FontePagadora.tipo_fonte_pagadora
ALTER TABLE "fonte_pagadora" ADD CONSTRAINT "ck_fonte_pagadora_tipo" CHECK (
  tipo_fonte_pagadora IN ('PESSOA_FISICA', 'PESSOA_JURIDICA', 'EXTERIOR', 'OUTRA', 'NAO_INFORMADA')
);

-- DST-E006 — ResultadoCalculo.status_revisao / RevisaoTecnica.status_revisao
ALTER TABLE "resultado_calculo" ADD CONSTRAINT "ck_resultado_calculo_status_revisao" CHECK (
  status_revisao IS NULL OR status_revisao IN ('PENDENTE', 'APROVADO', 'REJEITADO', 'AJUSTE_SOLICITADO')
);

ALTER TABLE "revisao_tecnica" ADD CONSTRAINT "ck_revisao_tecnica_status_revisao" CHECK (
  status_revisao IN ('PENDENTE', 'APROVADO', 'REJEITADO', 'AJUSTE_SOLICITADO')
);

-- DST-E007 — ConflitoDado.status_conflito
ALTER TABLE "conflito_dado" ADD CONSTRAINT "ck_conflito_dado_status" CHECK (
  status_conflito IN ('ABERTO', 'EM_ANALISE', 'RESOLVIDO', 'DESCARTADO')
);

-- DST-E010 — sistema_origem (MCD-F9001, Errata controlada nº2 / ADR-D015),
-- materializado em Receita, ContribuicaoPrevidenciaria, EventoIRPF,
-- DocumentoFiscal; e o uso pré-existente (não desta errata) em
-- ConflitoDadoItem.
ALTER TABLE "receita" ADD CONSTRAINT "ck_receita_sistema_origem" CHECK (
  sistema_origem IN (
    'ERP_CONTABIL', 'DOCUMENTO_FISCAL', 'CNIS', 'FOLHA_PAGAMENTO', 'BANCO',
    'INFORME_RENDIMENTOS', 'CARNE_LEAO', 'ENTRADA_MANUAL', 'API_GOVERNAMENTAL', 'OUTRO_SISTEMA'
  )
);

ALTER TABLE "contribuicao_previdenciaria" ADD CONSTRAINT "ck_contribuicao_previdenciaria_sistema_origem" CHECK (
  sistema_origem IN (
    'ERP_CONTABIL', 'DOCUMENTO_FISCAL', 'CNIS', 'FOLHA_PAGAMENTO', 'BANCO',
    'INFORME_RENDIMENTOS', 'CARNE_LEAO', 'ENTRADA_MANUAL', 'API_GOVERNAMENTAL', 'OUTRO_SISTEMA'
  )
);

ALTER TABLE "evento_irpf" ADD CONSTRAINT "ck_evento_irpf_sistema_origem" CHECK (
  sistema_origem IN (
    'ERP_CONTABIL', 'DOCUMENTO_FISCAL', 'CNIS', 'FOLHA_PAGAMENTO', 'BANCO',
    'INFORME_RENDIMENTOS', 'CARNE_LEAO', 'ENTRADA_MANUAL', 'API_GOVERNAMENTAL', 'OUTRO_SISTEMA'
  )
);

ALTER TABLE "documento_fiscal" ADD CONSTRAINT "ck_documento_fiscal_sistema_origem" CHECK (
  sistema_origem IN (
    'ERP_CONTABIL', 'DOCUMENTO_FISCAL', 'CNIS', 'FOLHA_PAGAMENTO', 'BANCO',
    'INFORME_RENDIMENTOS', 'CARNE_LEAO', 'ENTRADA_MANUAL', 'API_GOVERNAMENTAL', 'OUTRO_SISTEMA'
  )
);

ALTER TABLE "conflito_dado_item" ADD CONSTRAINT "ck_conflito_dado_item_sistema_origem" CHECK (
  sistema_origem IS NULL OR sistema_origem IN (
    'ERP_CONTABIL', 'DOCUMENTO_FISCAL', 'CNIS', 'FOLHA_PAGAMENTO', 'BANCO',
    'INFORME_RENDIMENTOS', 'CARNE_LEAO', 'ENTRADA_MANUAL', 'API_GOVERNAMENTAL', 'OUTRO_SISTEMA'
  )
);

-- DST-E009 — status_processamento_dado (MCD-F9004, ADR-D016), materializado
-- em Receita, ContribuicaoPrevidenciaria, EventoIRPF, DocumentoFiscal.
-- Salvaguarda 1 (Errata controlada nº2): NENHUMA constraint/trigger abaixo
-- sincroniza, deriva ou compara este campo com status_qualidade_dado — os
-- dois eixos permanecem estruturalmente colocados e semanticamente
-- independentes, exatamente como o ADR-001 exige.
ALTER TABLE "receita" ADD CONSTRAINT "ck_receita_status_processamento_dado" CHECK (
  status_processamento_dado IS NULL OR status_processamento_dado IN (
    'IMPORTADO', 'VALIDADO', 'RECONCILIADO', 'OVERRIDDEN', 'SUPERSEDED', 'CANCELADO'
  )
);

ALTER TABLE "contribuicao_previdenciaria" ADD CONSTRAINT "ck_contribuicao_previdenciaria_status_processamento_dado" CHECK (
  status_processamento_dado IS NULL OR status_processamento_dado IN (
    'IMPORTADO', 'VALIDADO', 'RECONCILIADO', 'OVERRIDDEN', 'SUPERSEDED', 'CANCELADO'
  )
);

ALTER TABLE "evento_irpf" ADD CONSTRAINT "ck_evento_irpf_status_processamento_dado" CHECK (
  status_processamento_dado IS NULL OR status_processamento_dado IN (
    'IMPORTADO', 'VALIDADO', 'RECONCILIADO', 'OVERRIDDEN', 'SUPERSEDED', 'CANCELADO'
  )
);

ALTER TABLE "documento_fiscal" ADD CONSTRAINT "ck_documento_fiscal_status_processamento_dado" CHECK (
  status_processamento_dado IS NULL OR status_processamento_dado IN (
    'IMPORTADO', 'VALIDADO', 'RECONCILIADO', 'OVERRIDDEN', 'SUPERSEDED', 'CANCELADO'
  )
);

-- DST-E011 — status_qualidade_dado (MCD-F9010, ADR-D016), materializado nos
-- mesmos quatro objetos. Salvaguarda 1: eixo independente do CHECK acima —
-- ver nota junto ao DST-E009.
ALTER TABLE "receita" ADD CONSTRAINT "ck_receita_status_qualidade_dado" CHECK (
  status_qualidade_dado IS NULL OR status_qualidade_dado IN (
    'NAO_AVALIADO', 'VALIDO', 'INCOMPLETO', 'DIVERGENTE', 'SUSPEITO'
  )
);

ALTER TABLE "contribuicao_previdenciaria" ADD CONSTRAINT "ck_contribuicao_previdenciaria_status_qualidade_dado" CHECK (
  status_qualidade_dado IS NULL OR status_qualidade_dado IN (
    'NAO_AVALIADO', 'VALIDO', 'INCOMPLETO', 'DIVERGENTE', 'SUSPEITO'
  )
);

ALTER TABLE "evento_irpf" ADD CONSTRAINT "ck_evento_irpf_status_qualidade_dado" CHECK (
  status_qualidade_dado IS NULL OR status_qualidade_dado IN (
    'NAO_AVALIADO', 'VALIDO', 'INCOMPLETO', 'DIVERGENTE', 'SUSPEITO'
  )
);

ALTER TABLE "documento_fiscal" ADD CONSTRAINT "ck_documento_fiscal_status_qualidade_dado" CHECK (
  status_qualidade_dado IS NULL OR status_qualidade_dado IN (
    'NAO_AVALIADO', 'VALIDO', 'INCOMPLETO', 'DIVERGENTE', 'SUSPEITO'
  )
);

-- ============================================================================
-- Fim da migration. NÃO aplicada a nenhum banco.
-- ============================================================================
