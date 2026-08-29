# ADR-001 — Schema Físico PostgreSQL/Prisma da CONTIFISC

**Versão:** 1.0  
**Status:** PROPOSTO — requer aprovação antes de schema/migration  
**Tipo:** Architecture Decision Record  
**Baseline obrigatória:** COT-001 V1.1 (publicação corrigida), MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2  
**Escopo:** decisões físicas de persistência relacional; não altera o domínio canônico

> Este ADR traduz a baseline canônica para PostgreSQL/Prisma. Quando houver conflito, COT/MCD/CDC/DST prevalecem. O schema físico não pode criar significado tributário novo.

## 1. Contexto e decisão

A CONTIFISC utilizará PostgreSQL como banco relacional canônico e Prisma como tooling de acesso/migrations. Prisma não é a autoridade do modelo: constraints que ele não expressa nativamente serão materializadas por SQL PostgreSQL versionado dentro da migration. O GTI permanece um grafo lógico/read model derivado do modelo relacional.

## 2. Decisões físicas fundamentais

| ID | Tema | Decisão | Justificativa |
|---|---|---|---|
| ADR-D001 | Banco relacional | PostgreSQL | A baseline canônica é relacional; GTI é read model lógico, não exige graph DB. |
| ADR-D002 | ORM/tooling | Prisma como camada de acesso/migration, subordinado ao PostgreSQL | Constraints não suportadas pelo Prisma serão SQL explícito e versionado. |
| ADR-D003 | Nomes físicos | snake_case em português canônico | Evita tradução semântica e mantém rastreabilidade MCD→DB. |
| ADR-D004 | PK | id UUID | UUID para identidade canônica e integração distribuída. |
| ADR-D005 | FK | <objeto>_id UUID | Mesmo nome canônico do MCD sempre que aplicável. |
| ADR-D006 | Valores monetários | NUMERIC(18,2) | Float/double proibidos para dinheiro. |
| ADR-D007 | Percentuais | NUMERIC com escala definida por campo | Escala deve vir do MCD/ADR específico; não usar float. |
| ADR-D008 | Competência | CHAR(7)/VARCHAR(7) + CHECK YYYY-MM | Competência não é DATE; primeiro dia fictício é proibido. |
| ADR-D009 | Timestamps | TIMESTAMPTZ | Persistência temporal inequívoca; aplicação converte para apresentação. |
| ADR-D010 | Enums | Texto/código canônico + CHECK/lookup conforme estabilidade | Evita acoplamento prematuro a PostgreSQL ENUM; Enum/Ref aberto não recebe CHECK fechado. |
| ADR-D011 | Soft lifecycle | status_registro/processamento/qualidade; sem hard delete por padrão | Fatos/evidências/auditoria preservam histórico. |
| ADR-D012 | Proveniência | Metadados canônicos preservados; RAW imutável | Reprocessamento não destrói evidência. |

## 3. Mapeamento inicial de objetos/estruturas para relações físicas

| Relação física proposta | COT | CDC | Observação |
|---|---|---|---|
| unidade_economica | COT-OBJ-001 | CDC-UE-001 | Objeto de contexto; não contribuinte. |
| pessoa_fisica | COT-OBJ-002 | CDC-PER-001 | Identidade tributária PF. |
| pessoa_juridica | COT-OBJ-003 | CDC-EMP-001 | Identidade tributária PJ. |
| vinculo | COT-OBJ-004 | CDC-REL-001 | Relação de negócio. |
| vinculo_extremidade | COT-SUP-001 | CDC-REL-002 | Suporte relacional; exatamente ORIGEM+DESTINO. |
| receita | COT-OBJ-005 | CDC-REC-001 | Fato com ownership PF XOR PJ. |
| documento_fiscal | COT-OBJ-006 | CDC-FIS-001 | Documento normalizado. |
| receita_documento_fiscal | COT-SUP-002 | CDC-FIS-002 | Associação N:N. |
| arquivo_origem | COT-OBJ-007 | CDC-ARQ-001 | Evidência RAW. |
| documento_fiscal_arquivo_origem | COT-SUP-003 | CDC-FIS-003 | Associação N:N. |
| classificacao_equiparacao_hospitalar | COT-OBJ-008 | CDC-EH-001 | Resultado derivado versionado. |
| contribuicao_previdenciaria | COT-OBJ-009 | CDC-PRE-001 | Fato previdenciário. |
| vinculo_previdenciario | COT-OBJ-010 | CDC-PREV-001 | Relação previdenciária. |
| evento_irpf | COT-OBJ-011 | CDC-IRP-001 | Fato IRPF/Carnê-Leão. |
| fonte_pagadora | COT-OBJ-012 | CDC-FPG-001 | Fonte pagadora. |
| cenario_tributario | COT-OBJ-013 | CDC-PLN-001 | Cenário isolado. |
| resultado_calculo | COT-OBJ-014 | CDC-CAL-001 | Resultado derivado. |
| conflito_dado | COT-OBJ-015 | CDC-CFD-001 | Controle/reconciliação. |
| conflito_dado_item | COT-SUP-004 | CDC-CFD-002 | Suporte de auditoria. |
| revisao_tecnica | COT-OBJ-016 | CDC-REV-001 | Decisão humana auditável. |

**Fora do primeiro schema autorizado por este ADR:** `conta_acesso` e `credencial_acesso`. Embora catalogados no COT, sua modelagem física aguarda SEC-001. Este ADR também não autoriza implementação de regra tributária.

## 4. Convenções de nomes e tipos

- Tabelas: singular, `snake_case`, em português canônico. Ex.: `pessoa_fisica`, não `people` ou `taxpayer_person`.
- Colunas: nomes MCD em `snake_case`; PK `id`; FK `<objeto>_id`.
- UUID: PostgreSQL `uuid`; geração preferencial na aplicação/Prisma ou `gen_random_uuid()` quando a estratégia de migration for fechada; não misturar estratégias sem motivo.
- Dinheiro: `numeric(18,2)`; TypeScript deve tratar Decimal explicitamente, nunca converter silenciosamente para `number` em cálculo tributário.
- Competência: string canônica `YYYY-MM`; no banco usar `char(7)` ou `varchar(7)` com CHECK de formato/mês. A escolha final preferida é `char(7)` pela largura invariável.
- Datas civis: `date`. Instantes de auditoria/processamento: `timestamptz`.
- Booleanos seguem nomes canônicos `eh_*`, `possui_*`, `permite_*`.
- Enums fechados do DST podem receber CHECK; Enum/Ref aberto permanece texto/ref sem lista inventada.
- JSONB só é permitido para payload técnico/RAW/metadata quando o MCD/CDC não exige estrutura relacional específica; não usar JSONB para escapar da modelagem canônica.

## 5. Constraints obrigatórias

| ID | Relação | Constraint | Objetivo | Implementação |
|---|---|---|---|---|
| ADR-C001 | receita | CHECK ((pessoa_fisica_id IS NOT NULL)::int + (pessoa_juridica_id IS NOT NULL)::int = 1) | Ownership PF/PJ XOR. | SQL migration obrigatória. |
| ADR-C002 | vinculo_extremidade | CHECK de exatamente uma FK entre unidade_economica_id, pessoa_fisica_id, pessoa_juridica_id | Endpoint XOR. | SQL migration obrigatória. |
| ADR-C003 | vinculo_extremidade | UNIQUE (vinculo_id, lado_extremidade) | Máximo uma ORIGEM e uma DESTINO. | Prisma @@unique + DB. |
| ADR-C004 | vinculo_extremidade | CHECK lado_extremidade IN ('ORIGEM','DESTINO') | Enum fechado DST-E012. | DB CHECK. |
| ADR-C005 | vinculo | Invariant: exatamente duas extremidades, ORIGEM e DESTINO | Não é garantível apenas por FK/CHECK de linha. | Constraint trigger DEFERRABLE inicialmente preferida; validar em PoC antes da migration. |
| ADR-C006 | receita_documento_fiscal | UNIQUE (receita_id, documento_fiscal_id) | Evita associação duplicada. | Prisma @@unique + DB. |
| ADR-C007 | documento_fiscal_arquivo_origem | Unicidade mínima (documento_fiscal_id, arquivo_origem_id); revisar quando papel_arquivo fechar | Evita duplicidade sem inventar semântica do papel. | Não usar papel_arquivo em unique enquanto DST-GAP-011 aberto. |
| ADR-C008 | classificacao_equiparacao_hospitalar | PK própria + FK receita_id + timestamps/version refs | Preserva histórico de classificação. | Sem overwrite do resultado anterior. |
| ADR-C009 | competencia | CHECK formato e mês 01..12 | Proíbe DATE fictícia e strings inválidas. | Aplicar a todo campo competência. |
| ADR-C010 | conflito_dado_item | Validação de tipo_objeto/objeto_id por serviço de domínio + auditoria | Exceção polimórfica controlada. | Sem FK genérica impossível; não propagar padrão. |

### 5.1 Decisão específica sobre VinculoExtremidade

O banco deve impedir estados finais com zero, uma, três ou mais extremidades. `UNIQUE(vinculo_id, lado_extremidade)` + CHECK do lado impede duplicidade, mas não garante a existência das duas linhas. A solução preferida para a primeira implementação é uma **constraint trigger DEFERRABLE INITIALLY DEFERRED** que valide, ao final da transação, exatamente duas extremidades por `vinculo_id`, uma ORIGEM e uma DESTINO. Antes da migration, Claude deverá criar uma PoC/teste PostgreSQL dessa estratégia. Se a PoC mostrar incompatibilidade operacional relevante com Prisma, o ADR deve ser revisado antes de substituir a constraint por validação apenas de aplicação.

## 6. Prisma versus PostgreSQL

| Recurso | Prisma | PostgreSQL | Política |
|---|---|---|---|
| PK/FK | Modelável | Nativo | Declarar em ambos. |
| UNIQUE composto | @@unique | UNIQUE | Declarar no Prisma e validar migration. |
| CHECK XOR | Não plenamente representável no schema | CHECK | SQL manual na migration. |
| CHECK competência | Não plenamente representável | CHECK | SQL manual. |
| Constraint trigger diferida | Não | Trigger/function | SQL manual + testes de integração. |
| Partial index | Limitado/não universal no schema | Nativo | SQL manual quando aprovado. |
| Decimal | Decimal | NUMERIC | Usar Decimal ponta a ponta. |
| Enum aberto | Não usar enum fechado | TEXT/REF | Sem inventar valores. |

**Regra operacional:** `prisma migrate` não pode apagar SQL manual de constraints. Toda regeneração de migration deve ser revisada por diff.

## 7. Índices

| ID | Alvo | Estratégia | Motivo |
|---|---|---|---|
| IDX-001 | Todas FKs | B-tree | Criar índice em FKs usadas em join/filtro; PostgreSQL não indexa FK automaticamente. |
| IDX-002 | Fatos por competência | (owner/fonte, competencia) conforme objeto | Consultas fiscais/temporais. |
| IDX-003 | Proveniência | (sistema_origem, identificador_origem) quando aplicável | Idempotência/reconciliação; unique apenas se contrato da fonte garantir unicidade. |
| IDX-004 | Documento fiscal | Chaves fiscais/identificadores normalizados conforme MCD | Busca e deduplicação; constraint concreta depende dos campos MCD. |
| IDX-005 | Status | Índice isolado somente se seletividade justificar | Evitar indexação automática de enums de baixa cardinalidade. |

Índices concretos por tabela devem ser propostos junto ao primeiro `schema.prisma`, baseados nas FKs e queries conhecidas. Não criar dezenas de índices especulativos. `EXPLAIN (ANALYZE, BUFFERS)` será usado quando houver carga/queries representativas.

## 8. Política de deleção e histórico

| Classe | Política padrão | Regra |
|---|---|---|
| Fatos tributários | RESTRICT/NO ACTION + estados de ciclo de vida | Receita, EventoIRPF, Contribuição, resultados históricos não devem desaparecer por cascade. |
| Evidência RAW | RESTRICT/NO ACTION | ArquivoOrigem preservado; retenção LGPD futura deve ser política explícita. |
| Associações N:N | Cascade somente da associação, não do objeto de destino | Remover vínculo associativo não apaga Documento/Arquivo/Receita. |
| Estruturas de Vinculo | RESTRICT durante operação normal | Exclusão física somente em rotinas administrativas controladas antes de haver fatos dependentes. |
| Cenários | Possível cascade interno do cenário após política explícita | Nunca atingir fatos oficiais. |
| Segurança | Fora deste ADR | ContaAcesso/CredencialAcesso aguardam SEC-001. |

Hard delete não é mecanismo de correção de dado tributário. Correção deve usar versão, supersessão, cancelamento, override auditável ou registro corretivo conforme o contrato aplicável.

## 9. Temporalidade

- `competencia` representa período tributário mensal e não substitui `data_emissao`, vigência ou timestamps.
- Objetos com vigência devem preservar início/fim conforme MCD; sobreposição de vigências só será proibida quando a regra de negócio estiver formalizada.
- `criado_em`, `atualizado_em`, `importado_em`, `registrado_em` e demais timestamps mantêm os nomes autorizados pelo MCD; não padronizar renomeando campos já aprovados.
- Resultados derivados registram versões de input/regra/engine conforme MCD/CDC; recalcular não apaga resultado histórico.
- RAW/evidência deve ser imutável; parser novo gera nova transformação/canonicalização, não mutação do arquivo original.

## 10. Proveniência, idempotência e reconciliação

- `sistema_origem` usa códigos DST; Neon/PostgreSQL/Prisma/Vercel não são origem.
- `identificador_origem` deve ser preservado quando disponível.
- `arquivo_origem_id` transversal permanece evidência/proveniência e não substitui as associações específicas de DocumentoFiscal.
- Unique de `(sistema_origem, identificador_origem)` não é global por padrão: só pode ser criado por objeto/fonte quando a semântica da origem garantir unicidade.
- Imports repetidos devem ser idempotentes no adapter/gateway e auditáveis no canonical store.

## 11. Multi-tenant e segurança

A CONTIFISC é multi-tenant, mas a estratégia física de tenant isolation **não será inventada neste ADR sem SEC-001**. O ADR proíbe usar `unidade_economica_id` como substituto automático de `tenant_id`: UE é contexto econômico, não boundary de segurança. Antes de produção com múltiplos clientes, SEC-001 deverá decidir tenant identity, RLS/isolamento, autorização, criptografia, retenção e identidade de usuário. Portanto, a primeira migration de domínio poderá ser criada para desenvolvimento somente após aprovação deste ADR, mas **go-live multi-tenant fica bloqueado por SEC-001**.

## 12. Migrations e ambientes

- **MIG-001:** Toda migration deve ser versionada e revisável; nenhuma alteração manual em produção.
- **MIG-002:** Prisma gera o esqueleto; SQL manual complementa CHECK, triggers, partial indexes ou recursos não expressáveis.
- **MIG-003:** SQL manual faz parte da migration e do code review; não pode existir como comando operacional solto.
- **MIG-004:** Migration destrutiva exige plano de backfill, compatibilidade e rollback/roll-forward.
- **MIG-005:** Schema físico deve ser validado contra COT/MCD/CDC/DST antes de merge.
- **MIG-006:** Ambientes dev/test/staging/prod usam a mesma cadeia de migrations.
- **MIG-007:** Primeira migration só pode ser criada após aprovação explícita deste ADR.

## 13. Testes obrigatórios do schema

| Teste | Obrigatório |
|---|---|
| Receita aceita PF sem PJ e PJ sem PF | Sim |
| Receita rejeita PF+PJ simultaneamente | Sim |
| Receita rejeita ambos nulos | Sim |
| Extremidade aceita exatamente uma FK endpoint | Sim |
| Extremidade rejeita zero ou múltiplas FKs endpoint | Sim |
| Vinculo rejeita commit sem ORIGEM+DESTINO | Sim |
| Vinculo rejeita terceira extremidade/duplicidade de lado | Sim |
| Associações N:N rejeitam par duplicado | Sim |
| Competência rejeita 2026-00, 2026-13, data completa e formato inválido | Sim |
| Decimal preserva centavos sem conversão float | Sim |
| Delete policy não remove fato/evidência por cascade indevido | Sim |
| Reprocessamento preserva RAW e histórico derivado | Sim |

Testes de constraints PostgreSQL devem ser de integração contra PostgreSQL real; SQLite/mock não é evidência suficiente para CHECK/trigger/deferrable behavior.

## 14. Gaps deliberadamente não resolvidos

| Gap | Tema | Tratamento |
|---|---|---|
| ADR-GAP-001 | FontePagadora.identificador_fiscal | Tipagem/normalização continua MCD/CDC gap; não criar CPF/CNPJ union por inferência. |
| ADR-GAP-002 | papel_arquivo | DST-GAP-011 aberto; coluna pode existir como texto/ref, sem enum/check fechado. |
| ADR-GAP-003 | ConflitoDadoItem tipo_objeto/papel_no_conflito | DST-GAP-012/013 abertos; sem enum/check fechado. |
| ADR-GAP-004 | Identidade do revisor | Bloqueada por SEC-001/OBS-001; não criar usuario_id/revisor_id por inferência. |
| ADR-GAP-005 | rule_set_id/regra_versao_id | Opacos até RGT-001; persistir como referência opaca apenas onde MCD já autoriza. |
| ADR-GAP-006 | Retenção/anonimização LGPD | SEC-001 deve fechar política antes de automações de purge. |

## 15. Ordem de implementação após aprovação

- 1. Claude sincroniza este ADR em `/docs` e faz auditoria cruzada com COT/MCD/CDC/DST.
- 2. Claude cria PoC isolada da constraint diferida de `VinculoExtremidade`, sem migration de produção.
- 3. Após validação da PoC, gerar proposta de `schema.prisma` e primeira migration em branch/commit separado.
- 4. Revisar diff MCD→Prisma campo a campo e COT/CDC→constraints.
- 5. Rodar testes PostgreSQL reais.
- 6. Somente após revisão humana, autorizar merge/aplicação em ambiente de desenvolvimento.
- 7. Produção/multi-tenant permanece bloqueada por SEC-001 e demais documentos de segurança necessários.

## 16. Critérios de aceite do ADR

- [ ] Não cria objeto ou campo canônico novo.
- [ ] Mapeia os objetos/estruturas V1.2/V1.1 sem vendor leakage.
- [ ] Define tipos físicos para UUID, dinheiro, competência e timestamps.
- [ ] Define XOR de Receita e endpoint.
- [ ] Define estratégia verificável para exatamente duas extremidades.
- [ ] Define N:N e unicidade.
- [ ] Define delete/history conservador.
- [ ] Separa Prisma de autoridade PostgreSQL.
- [ ] Não fecha Enum/Ref aberto.
- [ ] Não usa UE como tenant de segurança.
- [ ] Bloqueia auth/SEC e regras tributárias ainda não aprovadas.
- [ ] Primeira migration continua dependente de aprovação explícita posterior.

## 17. Consequências

**Positivas:** integridade fica no banco onde possível; Prisma permanece produtivo sem virar fonte de verdade; regras canônicas são rastreáveis; histórico fiscal é preservado; vendor lock-in de domínio é reduzido.

**Custos:** migrations terão SQL manual; testes exigem PostgreSQL real; a constraint de VinculoExtremidade aumenta complexidade transacional; segurança multi-tenant ainda exige SEC-001 antes de produção.

## 18. Decisão solicitada

Aprovar, rejeitar ou solicitar alterações neste ADR. **A aprovação do ADR autoriza apenas a próxima etapa técnica (PoC da constraint + proposta de schema/migration); não autoriza aplicação automática de migration nem go-live.**

---
**Governança:** COT define o que existe; MCD define os dados; CDC define contratos; DST define significado; ADR define a implementação física. PostgreSQL/Prisma não podem alterar unilateralmente as camadas anteriores.