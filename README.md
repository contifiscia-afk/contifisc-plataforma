# CONTIFISC Plataforma

Plataforma de inteligência tributária integrada para profissionais da saúde. Arquitetura
definida em `docs/CAF-001_CONTIFISC_Architecture_Framework_V1.md`.

## Estado atual: Fase 1

Estrutura de monorepo, tipos canônicos e Gateway de Integração genérico. **Nenhuma Skill de
negócio, autenticação ou persistência real ainda.**

```
apps/web            Next.js 14 + TypeScript + Tailwind (página placeholder)
packages/core        Reservado para o schema físico (Prisma) — ver packages/core/README.md
packages/types       Value Objects técnicos + as 3 interfaces canônicas autorizadas
packages/ui          Componentes genéricos (Button, Card)
packages/integrations Gateway de Integração genérico (ERPAdapter/IntegrationGateway)
packages/ai          Reservado para Skills futuras — sem código
docs/                Documentos fundadores vigentes (CAF/MCD/CDC/DST/COT + Change Requests)
docs/legacy/         Versões V1.0 supersedidas, mantidas para histórico
docs/pdf/            PDFs de origem dos documentos fundadores
tests/               Testes de infraestrutura (Vitest)
```

## Fontes de verdade vigentes

- `docs/CAF-001_CONTIFISC_Architecture_Framework_V1.md`
- `docs/MCD-001_CONTIFISC_Modelo_Canonico_de_Dados_V1.4.md` (151 campos canônicos — corrige os 2
  achados `RELEVANTE` de `SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`: representação MCD
  mínima de `ContaAcesso`/`ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` e política de
  mutabilidade de `MCD-F10004`; ver `SEC-CR-001_CORRECAO_MCD_CDC_V1.0.md`)
- `docs/CDC-001_CONTIFISC_Contrato_Canonico_de_Dados_V1.4.md` (26 contratos canônicos — correção
  coordenada com MCD-001 V1.4; reconciliação final aprovada, ver
  `SEC-CR-001_RECONCILIACAO_FINAL_V1.0.md`: `BASELINE CANÔNICA PÓS-SEC RECONCILIADA — APTA PARA ADR`)
- `docs/DST-001_CONTIFISC_Dicionario_Semantico_Tributario_V1.3.md` (37 termos, 12 enums fechados,
  15 gaps abertos — incorpora semântica de `Tenant`/`EventoAuditoriaSeguranca`/`tenant_id`/
  `unidade_economica_id`/`papel`; sincronizado com CDC V1.4)
- `docs/COT-001_CONTIFISC_Catalogo_Oficial_de_Objetos_Tributarios_V1.2.md` (20 objetos `COT-OBJ-*`,
  6 estruturas de suporte relacional `COT-SUP-001..006` — inclui `Tenant`,
  `EventoAuditoriaSeguranca`, `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`, aprovados via
  `SEC-CHANGE-REQUEST-001` V1.1)
- `docs/MCD-CHANGE-REQUEST-001_CONTIFISC_V1.0.md` (incorporado ao MCD-001 V1.1)
- `docs/MCD-CHANGE-REQUEST-002_CONTIFISC_V1.0.md` (status: **APROVADO** — incorporado ao
  MCD-001 V1.2 e ao CDC-001 V1.2)
- `docs/SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md` (status:
  **APROVADO** — baseline normativa de segurança/tenant)
- `docs/SEC-CHANGE-REQUEST-001_V1.1.md` (status: **APROVADO** — incorporado ao COT-001 V1.2, ao
  MCD-001 V1.4, ao DST-001 V1.3, ao CDC-001 V1.4 e ao ADR-001 V1.1)
- `docs/ADR-001_CONTIFISC_Schema_Fisico_PostgreSQL_Prisma_V1.1.md` (status: **APROVADO —
  revisão pós-SEC; define a representação física de Tenant/ContaAcesso/associações de acesso/
  EventoAuditoriaSeguranca e a matriz RLS conceitual (25 tabelas); schema.prisma, migration, RLS
  e autenticação ainda não implementados**; gate `ADR-001 PÓS-SEC CONSOLIDADO — APTO PARA
  ATUALIZAÇÃO DO SCHEMA PRISMA`; ver `ADR-001_RASTREABILIDADE_POS_SEC_V1.0.md` e revisão técnica
  em `packages/core/README.md`.)

As versões V1.0 de MCD/CDC/DST/COT/ADR-001, as versões V1.1 de MCD/CDC/DST/COT, as versões V1.2 de
MCD/DST/CDC e as versões V1.3 de MCD/CDC em `docs/legacy/` são `SUPERSEDED` e não devem orientar
código novo.

## Interfaces canônicas implementadas

Somente 3, sem FK/relacionamento (associação real depende de `Vinculo`, ainda fora de escopo):

- `UnidadeEconomica` — COT-OBJ-001 / MCD-F0001..F0005 / CDC-UE-001 / DST-T001
- `PessoaFisica` — COT-OBJ-002 / MCD-F1001..F1008 / CDC-PER-001 / DST-T002
- `PessoaJuridica` — COT-OBJ-003 / MCD-F2001..F2007 / CDC-EMP-001 / DST-T003

Gaps bloqueantes registrados (não resolvidos por inferência): ver `packages/core/README.md`.

## Setup

```bash
npm install
npm run lint
npm run typecheck
npm run build
npm test
```

Não há banco de dados configurado nesta Fase 1. `DATABASE_URL` em `.env.example` está vazia de
propósito — nenhum passo desta fase depende dela.

## Fora de escopo nesta Fase 1

- Prisma schema, migration ou qualquer persistência real.
- Autenticação (aguarda `SEC-001`; `ContaAcesso`/`CredencialAcesso` são objetos separados de
  `PessoaFisica`, nunca implementados dentro dela).
- Lógica tributária de qualquer domínio (aguarda `RGT-001`).
- Adapter concreto de ERP (Questor ou outro).
- Objetos com FK obrigatória (`Receita`, `Vinculo`, `DocumentoFiscal`, EqHop, etc.).
