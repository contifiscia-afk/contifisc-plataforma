# ADR-001 — Schema Físico PostgreSQL/Prisma da CONTIFISC

**Versão:** 1.0  
**Status:** APROVADO — baseline física autorizada para PoC; schema e migrations ainda não autorizados (publicação corrigida por errata; errata controlada nº2 incorporada em 2026-08-31 — ver notas abaixo)  
**Tipo:** Architecture Decision Record  
**Baseline obrigatória:** COT-001 V1.1 (publicação corrigida), MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2  
**Escopo:** decisões físicas de persistência relacional; não altera o domínio canônico

> Este ADR traduz a baseline canônica para PostgreSQL/Prisma. Quando houver conflito, COT/MCD/CDC/DST prevalecem. O schema físico não pode criar significado tributário novo.

### Errata de publicação V1.0

Antes da aprovação, esta publicação foi corrigida em quatro pontos, sem mudança conceitual e
sem criar schema, migration ou PoC: (1) fixado `relationMode = "foreignKeys"` do Prisma como
decisão obrigatória (ADR-D013), proibindo `relationMode = "prisma"` no schema canônico; (2)
`ADR-D007` deixava de materializar a escala de percentuais já fixada em `NUMERIC(7,4)` pelo
MCD-001 V1.2 §5 — corrigido para citar essa escala diretamente, sem reabrir a decisão; (3) a
escolha física preferencial de `competencia` foi corrigida de `CHAR(7)` para `VARCHAR(7)`,
mantendo o CHECK de formato/mês obrigatório; (4) declarada `PostgreSQL >= 15` como baseline
técnica (ADR-D014), sem vincular o domínio canônico a essa versão especificamente.

### Errata controlada nº2 (pós-aprovação) — Estratégia física dos campos transversais MCD-F9001..F9010

**Data:** 2026-08-31.
**Motivo:** este ADR (§10) e o MCD-001 V1.2 (§10) haviam deixado em aberto a estratégia física
para os 10 campos transversais de proveniência/estado. Esta errata incorpora a decisão tomada
após análise arquitetural dedicada (comparando coluna repetida, composição de aplicação,
entidade relacional própria e combinação por categoria), aprovada para incorporação, e uma
verificação semântica obrigatória sobre quais campos domésticos já existentes poderiam
substituir `registrado_em` (MCD-F9007).

As decisões desta errata estão detalhadas como `ADR-D015..D019` (§2) e um novo gap `ADR-GAP-007`
e `ADR-GAP-008` (§14). Resumo:

- **F9001/F9002/F9003** (`sistema_origem`/`identificador_origem`/`importado_em`): coluna física
  em `receita`, `contribuicao_previdenciaria`, `evento_irpf`, `documento_fiscal`. Sem entidade
  relacional genérica de proveniência e sem referência polimórfica reversa.
- **F9004/F9010** (`status_processamento_dado`/`status_qualidade_dado`): coluna física nos
  mesmos quatro objetos, sempre os dois juntos, **eixos estritamente independentes** — nenhuma
  constraint, trigger ou lógica de aplicação pode sincronizá-los, derivar um do outro, ou tratar
  `VALIDADO` como equivalente a `VALIDO`, nem `RECONCILIADO` como eliminação automática de
  `DIVERGENTE`.
- **F9005/F9006** (`versao_schema`/`correlation_id`): permanecem **`DECISÃO_BLOQUEADA` —
  BLOQUEADO POR EVT-001/INT-001**. A materialização dos demais oito campos não autoriza,
  antecipa ou implica nenhuma decisão sobre estes dois.
- **F9007** (`registrado_em`): coluna em 16 objetos (ver ADR-D017). Confirmado **equivalente e
  não duplicado** em `unidade_economica` (`criado_em`) e `classificacao_equiparacao_hospitalar`
  (`registrado_em`, mesmo campo, MCD-F5010). **Não confirmado** em `resultado_calculo`
  (`calculado_em`) e `revisao_tecnica` (`revisado_em`) — ver achado RELEVANTE abaixo e `ADR-GAP-008`.
- **F9008** (`data_fato`): coluna nos três fatos puros (`receita`, `contribuicao_previdenciaria`,
  `evento_irpf`).
- **F9009** (`arquivo_origem_id`): via relacionamento já existente em `documento_fiscal`
  (`documento_fiscal_arquivo_origem`); gap registrado (`ADR-GAP-007`) para `receita`,
  `contribuicao_previdenciaria`, `evento_irpf`, sem FK criada por inferência.

**Achado RELEVANTE desta errata (não resolvido por inferência):** a verificação semântica de
F9007 mostrou que o próprio catálogo MCD-001 V1.2 define os três campos com textos distintos:
`MCD-F8208 calculado_em` = "momento do cálculo", `MCD-F8706 revisado_em` = "momento da revisão",
`MCD-F9007 registrado_em` = "momento do registro canônico". Nada no texto do MCD-001 V1.2 afirma
que "momento do cálculo"/"momento da revisão" e "momento do registro canônico" são a mesma
ocorrência temporal — um cálculo/revisão pode, em tese, ocorrer em um instante e ser gravado no
armazenamento canônico em outro. Similaridade de nome, tipo (`TIMESTAMPTZ`) ou função aparente não
foi considerada suficiente para presumir equivalência apenas com base nesse texto. Este ADR **não
decide** se esses dois campos substituem `registrado_em` nesses dois objetos ou se cada um precisa
de uma coluna `registrado_em` adicional — fica registrado como `ADR-GAP-008`, aberto para decisão
explícita futura. (Nota de correção: uma redação preliminar desta errata citou incorretamente um
"envelope de evento `occurred_at`/`recorded_at`" da CDC-001 V1.2 §11 como fundamento adicional;
essa distinção existiu apenas na CDC-001 V1.0/V1.1, ambas `SUPERSEDED`, e foi removida da CDC-001
V1.2 — a citação foi corrigida nesta mesma errata para não se apoiar em conteúdo de documento
superado.)

**Distinção RAW / Canonical / Derived preservada:** `arquivo_origem` continua a única fonte de
evidência RAW imutável; `documento_fiscal` é a representação canônica normalizada;
`classificacao_equiparacao_hospitalar`/`resultado_calculo` continuam resultados derivados. Os
campos de proveniência desta errata (F9001/F9002/F9003/F9009) descrevem a **origem primária** do
fato canônico — de onde ele veio antes de virar dado canônico — e não substituem, resumem ou
duplicam as **evidências adicionais** já modeladas especificamente (`ArquivoOrigem`,
`DocumentoFiscalArquivoOrigem`) nem o histórico de reconciliação (`ConflitoDado`/`ConflitoDadoItem`).

**Proibição explícita reafirmada:** nenhuma entidade relacional genérica de proveniência foi
criada; nenhuma referência polimórfica reversa foi usada para os campos de origem ou evidência
incorporados por esta errata. O padrão de referência polimórfica controlada continua restrito às
exceções já fechadas — reconciliação (`ConflitoDadoItem`) e revisão/auditoria
(`RevisaoTecnica.objeto_revisado_id`) — e nunca é reaproveitado como atalho de proveniência
financeira.

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
| ADR-D007 | Percentuais | NUMERIC(7,4) | Escala já fixada pelo MCD-001 V1.2 §5 (32,0000 = 32%); não é reaberta aqui. TypeScript/Prisma preservam precisão decimal — nunca convertem percentual para `number`/float em cálculo tributário. |
| ADR-D008 | Competência | VARCHAR(7) + CHECK YYYY-MM | Competência não é DATE; primeiro dia fictício é proibido. `VARCHAR(7)` substitui `CHAR(7)` (errata) — mesma largura útil, sem o padding/semântica de comparação problemática do `CHAR`. |
| ADR-D009 | Timestamps | TIMESTAMPTZ | Persistência temporal inequívoca; aplicação converte para apresentação. |
| ADR-D010 | Enums | Texto/código canônico + CHECK/lookup conforme estabilidade | Evita acoplamento prematuro a PostgreSQL ENUM; Enum/Ref aberto não recebe CHECK fechado. |
| ADR-D011 | Soft lifecycle | status_registro/processamento/qualidade; sem hard delete por padrão | Fatos/evidências/auditoria preservam histórico. |
| ADR-D012 | Proveniência | Metadados canônicos preservados; RAW imutável | Reprocessamento não destrói evidência. |
| ADR-D013 | Prisma relationMode | `relationMode = "foreignKeys"` (obrigatório) | A integridade referencial permanece no PostgreSQL, nunca emulada no client. `relationMode = "prisma"` é **proibido** para o schema canônico da CONTIFISC — mudar essa decisão exige novo ADR ou revisão formal deste. A futura revisão do `schema.prisma` deve verificar explicitamente essa configuração antes de qualquer migration. |
| ADR-D014 | Versão mínima do PostgreSQL | PostgreSQL >= 15 | Baseline técnica declarada para viabilizar recursos usados neste ADR (ex.: `gen_random_uuid()` nativo). Não vincula o domínio canônico a uma versão específica. A versão efetivamente usada em desenvolvimento/staging/produção deve ser registrada e validada antes da primeira migration; recursos específicos de versão devem ser verificados contra essa baseline. |
| ADR-D015 | Proveniência de origem (MCD-F9001/F9002/F9003) | Coluna física em `receita`, `contribuicao_previdenciaria`, `evento_irpf`, `documento_fiscal`. `sistema_origem`: TEXT + CHECK futuro contra DST-E010 (nunca ENUM nativo, ADR-D010); nunca infraestrutura (PostgreSQL/Prisma/Neon/Vercel). `identificador_origem`: VARCHAR(120) — identifica o registro no **sistema-fonte externo**, nunca o `id` interno da CONTIFISC. `importado_em`: TIMESTAMPTZ. | Sem entidade relacional genérica de proveniência e sem referência polimórfica reversa nesta fase — cada coluna é local ao fato/documento que a usa. Na camada TypeScript, os três campos podem ser expostos como composição lógica compartilhada (ex.: tipo `ProvenienciaFato`), sem tabela/relação física correspondente. MCD-001 V1.2 §8/§10; CDC-001 V1.2 §3/§9/CDC-SYS-001; DST-001 V1.2 §2/§10/DST-E010. |
| ADR-D016 | Estado duplo do dado (MCD-F9004/F9010) | Coluna física em `receita`, `contribuicao_previdenciaria`, `evento_irpf`, `documento_fiscal` para `status_processamento_dado` (TEXT + CHECK futuro contra DST-E009) e `status_qualidade_dado` (TEXT + CHECK futuro contra DST-E011), sempre os dois juntos nesses quatro objetos. | Eixos **estruturalmente colocados, semanticamente independentes**: proibido qualquer constraint, trigger, default ou lógica de aplicação que exija preenchimento simultâneo, sincronize os dois valores, derive um do outro, trate `VALIDADO` (processamento) como equivalente a `VALIDO` (qualidade), ou trate `RECONCILIADO` como eliminação automática de `DIVERGENTE`. Não se aplica a `unidade_economica` (`status_registro` próprio), `conflito_dado` (`status_conflito`), `resultado_calculo`/`revisao_tecnica` (`status_revisao`) — evita colisão com eixos de estado já existentes. MCD-CHANGE-REQUEST-002 (CR2-007)/MCD-001 V1.2 §10; DST-001 V1.2 §5/DST-E009/DST-E011. |
| ADR-D017 | Registro canônico (MCD-F9007) | Coluna `registrado_em` (TIMESTAMPTZ) em `pessoa_fisica`, `pessoa_juridica`, `vinculo`, `vinculo_extremidade`, `receita`, `documento_fiscal`, `receita_documento_fiscal`, `arquivo_origem`, `documento_fiscal_arquivo_origem`, `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `fonte_pagadora`, `cenario_tributario`, `conflito_dado`, `conflito_dado_item` (16 objetos). | Confirmado equivalente e **não duplicado** em `unidade_economica` (`criado_em`, MCD-F0004) e `classificacao_equiparacao_hospitalar` (`registrado_em`, MCD-F5010 — mesmo campo). **Pendente** (não decidido por inferência) em `resultado_calculo` (`calculado_em`) e `revisao_tecnica` (`revisado_em`) — ver `ADR-GAP-008`. MCD-001 V1.2 §8/§10; CDC-001 V1.2 §9. |
| ADR-D018 | Data do fato (MCD-F9008) | Coluna `data_fato` em `receita`, `contribuicao_previdenciaria`, `evento_irpf`. | Os três fatos puros onde a data de ocorrência econômica pode divergir de `data_emissao`/`competencia`. Tipo físico proposto `DATE` por analogia às demais datas civis do schema; `TIMESTAMPTZ` não descartado se o caso de uso exigir hora — tipo exato fica aberto para a proposta de `schema.prisma`. MCD-001 V1.2 §8/§10. |
| ADR-D019 | Evidência RAW transversal (MCD-F9009) | `APLICAR_VIA_RELACIONAMENTO_EXISTENTE`: em `documento_fiscal`, já coberto por `documento_fiscal_arquivo_origem` (COT-SUP-003) — nenhuma coluna nova. Em `receita`, `contribuicao_previdenciaria`, `evento_irpf`, nenhuma FK criada por inferência — ver `ADR-GAP-007`. | CDC-001 V1.2 §3 (`arquivo_origem_id` transversal ≠ associação específica CDC-FIS-003); MCD-001 V1.2 §9. |

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
- Competência: string canônica `YYYY-MM`; no banco usar `varchar(7)` com CHECK de formato/mês (ADR-D008). Nunca converter para `date` com primeiro dia fictício.
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
| ADR-C005 | vinculo | Invariant: exatamente duas extremidades, ORIGEM e DESTINO (materializa a restrição normativa `COT-REL-NORM-001`, COT-001 V1.1) | Não é garantível apenas por FK/CHECK de linha. | Constraint trigger DEFERRABLE inicialmente preferida; validar em PoC antes da migration. |
| ADR-C006 | receita_documento_fiscal | UNIQUE (receita_id, documento_fiscal_id) | Evita associação duplicada. | Prisma @@unique + DB. |
| ADR-C007 | documento_fiscal_arquivo_origem | Unicidade mínima (documento_fiscal_id, arquivo_origem_id); revisar quando papel_arquivo fechar | Evita duplicidade sem inventar semântica do papel. | Não usar papel_arquivo em unique enquanto DST-GAP-011 aberto. |
| ADR-C008 | classificacao_equiparacao_hospitalar | PK própria + FK receita_id + timestamps/version refs | Preserva histórico de classificação. | Sem overwrite do resultado anterior. |
| ADR-C009 | competencia | CHECK formato e mês 01..12 | Proíbe DATE fictícia e strings inválidas. | Aplicar a todo campo competência. |
| ADR-C010 | conflito_dado_item | Validação de tipo_objeto/objeto_id por serviço de domínio + auditoria | Exceção polimórfica controlada. | Sem FK genérica impossível; não propagar padrão. |

### 5.1 Decisão específica sobre VinculoExtremidade

O banco deve impedir estados finais com zero, uma, três ou mais extremidades — esta é a materialização física da restrição normativa **`COT-REL-NORM-001`** (COT-001 V1.1 §5): todo `Vinculo` deve possuir exatamente duas `VinculoExtremidade`, uma `ORIGEM` e uma `DESTINO`. `UNIQUE(vinculo_id, lado_extremidade)` + CHECK do lado impede duplicidade, mas não garante a existência das duas linhas. A solução preferida para a primeira implementação é uma **constraint trigger DEFERRABLE INITIALLY DEFERRED** que valide, ao final da transação, exatamente duas extremidades por `vinculo_id`, uma ORIGEM e uma DESTINO. Antes da migration, Claude deverá criar uma PoC/teste PostgreSQL dessa estratégia. Se a PoC mostrar incompatibilidade operacional relevante com Prisma, o ADR deve ser revisado antes de substituir a constraint por validação apenas de aplicação.

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
| relationMode | `foreignKeys` (obrigatório, ADR-D013) | FK nativa | `relationMode = "prisma"` proibido; integridade referencial fica no PostgreSQL, nunca emulada no client. |

**Regra operacional:** `prisma migrate` não pode apagar SQL manual de constraints. Toda regeneração de migration deve ser revisada por diff. Toda revisão futura do `schema.prisma` deve verificar explicitamente que `relationMode = "foreignKeys"` permanece configurado.

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
- **MIG-008:** A versão do PostgreSQL efetivamente usada em desenvolvimento/staging/produção deve ser registrada e validada contra a baseline `PostgreSQL >= 15` (ADR-D014) antes da primeira migration; recursos específicos de versão são verificados contra essa baseline, não presumidos.
- **MIG-009:** Antes de qualquer migration, confirmar que `schema.prisma` declara `relationMode = "foreignKeys"` (ADR-D013).

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
| ADR-GAP-007 | MCD-F9009 (`arquivo_origem_id`) em `receita`, `contribuicao_previdenciaria`, `evento_irpf` | Nenhum relacionamento com `arquivo_origem` autorizado por inferência para esses três objetos; só `documento_fiscal` tem cobertura via `documento_fiscal_arquivo_origem` (ADR-D019). Decisão física (nova FK ou ausência deliberada) fica para revisão explícita futura. |
| ADR-GAP-008 | MCD-F9007 (`registrado_em`) em `resultado_calculo`/`revisao_tecnica` | Verificação semântica (Errata controlada nº2) não confirmou equivalência entre `calculado_em`/`revisado_em` e `registrado_em` — o MCD-001 V1.2 define os três com textos distintos ("momento do cálculo"/"momento da revisão" vs. "momento do registro canônico"), sem afirmar que são a mesma ocorrência temporal. Não decidido se os campos existentes substituem `registrado_em` ou se cada objeto precisa de uma coluna `registrado_em` adicional. |

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
- [ ] Fixa `relationMode = "foreignKeys"` e proíbe `relationMode = "prisma"`.
- [ ] Declara baseline `PostgreSQL >= 15` sem vincular o domínio canônico à versão.
- [ ] Define estratégia física dos campos transversais MCD-F9001..F9010 preservando `status_processamento_dado`/`status_qualidade_dado` como eixos independentes e sem entidade polimórfica genérica de proveniência.
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