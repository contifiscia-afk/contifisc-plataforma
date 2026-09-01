# Relatório de revisão — primeira migration canônica CONTIFISC

**Status:** ARTEFATO DE REVISÃO. NÃO APLICADA A NENHUM BANCO.
**Migration:** `prisma/migrations/20260901120000_init_baseline_fisica/migration.sql`
**Gerada a partir de:** `prisma/schema.prisma` v3 (Errata controlada nº2 do ADR-001 incorporada).
**Comando usado:** `prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script`
— não exigiu conexão com banco real nem shadow database. `prisma migrate dev`,
`prisma migrate deploy` e `prisma db push` **não foram executados**.

## 1. Como a migration foi gerada

`prisma migrate diff` com `--from-empty` computa o SQL inteiramente a partir do motor de
schema do Prisma, comparando um estado vazio ao `schema.prisma` atual — não requer banco de
dados, shadow database, nem `DATABASE_URL` válido apontando para um servidor real. A saída
(`--script`) é SQL puro, sem histórico de migration "aplicada". Isso permite produzir o SQL
para revisão sem qualquer risco de tocar um banco, conforme exigido.

Se uma versão futura do Prisma exigisse banco/shadow DB para este comando específico, a
instrução era parar e reportar em vez de contornar com banco externo — não foi necessário: o
comando funcionou integralmente offline nesta versão (6.19.3).

## 2. Estrutura do arquivo de migration

- **Seção 1** — SQL gerado automaticamente pelo Prisma: `CREATE SCHEMA`, 20 `CREATE TABLE`, 20
  `PRIMARY KEY`, 8 `CREATE INDEX` (3 `UNIQUE` + 5 simples), 20 `ALTER TABLE ... FOREIGN KEY`.
  Nenhuma edição manual nesta seção — é a saída literal do `prisma migrate diff`.
- **Seção 2** — SQL manual complementar: 25 `CHECK`, 1 `FUNCTION`, 1 `CONSTRAINT TRIGGER`.
  Cada item corresponde a uma linha específica de `ADR_TO_SQL_MATRIX.md`, sem nenhuma
  constraint inventada além do que o ADR-001 e suas erratas já autorizam.

## 3. SQL manual obrigatório — checklist de cobertura

| Item exigido | Presente | Constraint |
|---|---|---|
| CHECK XOR de ownership de Receita | Sim | `ck_receita_ownership_xor` |
| CHECK XOR de endpoint de VinculoExtremidade | Sim | `ck_vinculo_extremidade_endpoint_xor` |
| UNIQUE (vinculo_id, lado_extremidade) | Sim (gerada pelo Prisma) | `uq_vinculo_lado` |
| CHECK dos valores ORIGEM/DESTINO | Sim | `ck_vinculo_extremidade_lado` |
| ADR-C005/COT-REL-NORM-001 — CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED, conforme PoC | Sim — texto idêntico à PoC validada | `fn_check_vinculo_extremidades()` + `trg_vinculo_extremidades_check` |
| CHECK de competência YYYY-MM | Sim | `ck_receita_competencia_formato` |
| CHECKs dos vocabulários fechados DST materializados como TEXT | Sim — 8 vocabulários pré-existentes + os 3 novos da errata (DST-E009/E010/E011) | ver `ADR_TO_SQL_MATRIX.md` |
| sistema_origem conforme DST-E010 | Sim — 5 objetos (4 novos da errata + ConflitoDadoItem pré-existente) | `ck_receita_sistema_origem` e 4 análogas |
| status_processamento_dado conforme DST-E009 | Sim — 4 objetos | `ck_receita_status_processamento_dado` e 3 análogas |
| status_qualidade_dado conforme DST-E011 | Sim — 4 objetos | `ck_receita_status_qualidade_dado` e 3 análogas |
| Demais CHECKs previstos no ADR | Sim — DST-E001, E003, E004, E005, E006 (×2), E007, E008 | ver `ADR_TO_SQL_MATRIX.md` |
| Nenhum PostgreSQL ENUM criado | Confirmado — 0 ocorrências de `CREATE TYPE` | — |

## 4. Gaps preservados (não implementados nesta migration)

- **`ADR-GAP-007`** — MCD-F9009 (`arquivo_origem_id`) não foi criado como FK em `receita`,
  `contribuicao_previdenciaria`, `evento_irpf`.
- **`ADR-GAP-008`** — MCD-F9007 (`registrado_em`) não foi criado em `resultado_calculo` nem
  `revisao_tecnica`.
- **F9005/F9006** (`versao_schema`/`correlation_id`) — nenhuma coluna, tipo, tabela ou JSON
  genérico criado. `EVT-001`/`INT-001` não iniciados.
- **SEC-001, tenant isolation, autenticação, RLS** — nenhuma tabela, coluna, policy ou role
  criada. `ContaAcesso`/`CredencialAcesso` continuam ausentes do schema e da migration.
- Todos os 14 campos `DST-GAP-*`/`GAP-CDC`/`ADR-GAP-005` (Enum/Ref abertos) permanecem `TEXT`
  livre, sem `CHECK` — nenhuma lista fechada foi inventada.

## 5. Integridade referencial — revisão de FKs e políticas `onDelete`

Contagem por política (20 FKs totais, confirmado por script estático):

| Política | Quantidade | Objetos |
|---|---|---|
| `RESTRICT` | 16 | Todas as FKs de fato tributário (`receita.*`, `contribuicao_previdenciaria.*`, `evento_irpf.*`), de evidência (`documento_fiscal_arquivo_origem.arquivo_origem_id`), de vínculo/endpoint (`vinculo_extremidade.*`), de suporte (`classificacao_equiparacao_hospitalar.receita_id`, `cenario_tributario.unidade_economica_id`, `resultado_calculo.cenario_tributario_id`, `vinculo_previdenciario.pessoa_fisica_id`) |
| `CASCADE` | 4 | `receita_documento_fiscal.receita_id`, `receita_documento_fiscal.documento_fiscal_id`, `documento_fiscal_arquivo_origem.documento_fiscal_id`, `conflito_dado_item.conflito_dado_id` — todas em linhas associativas/filhas, nunca no objeto de fato/evidência de destino |

Confirmações explícitas exigidas:

- **Fatos tributários não usam cascade destrutivo:** confirmado. Nenhuma FK de `Receita`,
  `ContribuicaoPrevidenciaria`, `EventoIRPF`, `VinculoPrevidenciario`, `FontePagadora` como
  tabela referenciada (lado "pai") usa `CASCADE` — todas as FKs que apontam para essas tabelas
  usam `RESTRICT`.
- **Documentos/evidências não usam cascade destrutivo:** confirmado. `arquivo_origem` (evidência
  RAW) é referenciada com `RESTRICT` em `documento_fiscal_arquivo_origem`. `documento_fiscal`
  como tabela referenciada por `receita_documento_fiscal` usa `CASCADE`, mas essa cascade remove
  apenas a **linha de associação** (`receita_documento_fiscal`), nunca o `documento_fiscal` em
  si — consistente com ADR §8 ("Cascade somente da associação, não do objeto de destino").
- **`ResultadoCalculo → CenarioTributario` permanece `Restrict`:** confirmado —
  `resultado_calculo_cenario_tributario_id_fkey ... ON DELETE RESTRICT`.
- **Relações N:N têm UNIQUE apropriado:** confirmado — `uq_receita_documento_fiscal` e
  `uq_documento_fiscal_arquivo_origem` presentes.
- **Nenhuma relação física polimórfica foi criada:** confirmado — `ConflitoDadoItem.objeto_id` e
  `RevisaoTecnica.objeto_revisado_id` não têm `FOREIGN KEY` na migration (nenhum `ALTER TABLE
  "conflito_dado_item" ... FOREIGN KEY ("objeto_id")` nem equivalente para `revisao_tecnica`) —
  exatamente como o ADR exige (validação de aplicação, não FK genérica impossível).

## 6. Verificações estáticas (análise do SQL, sem aplicar em banco)

Script Node percorrendo `migration.sql` via regex estrutural (parsing dos blocos `CREATE TABLE`
e extração de nomes de tabela/coluna reais, sem executar SQL):

| Métrica | Valor |
|---|---|
| `CREATE TABLE` | 20 |
| `PRIMARY KEY` | 20 |
| `FOREIGN KEY` (`ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY`) | 20 |
| `UNIQUE INDEX` | 3 |
| Índice simples (não único) | 5 |
| `CHECK` (`ALTER TABLE ... ADD CONSTRAINT ... CHECK`) | 25 |
| `FUNCTION` | 1 |
| `CONSTRAINT TRIGGER` | 1 |
| `CREATE TYPE` (ENUM PostgreSQL) | 0 |
| Referências a `ContaAcesso`/`CredencialAcesso` | 0 |
| Referências a `tipo_titular`/`titular_id` (removidos pelo CR-002) | 0 |
| `arquivo_origem_id` como coluna singular em `documento_fiscal` (MCD-F4008) | 0 |
| Total de colunas nas 20 tabelas | 168 (idêntico à contagem de campos escalares do `schema.prisma`) |
| Integridade de FKs (tabela/coluna de origem e destino existem) | Sem erros |
| Parênteses balanceados | Sim (225 = 225) |

Todas as verificações passaram sem inconsistência.

## 7. Diferenças entre o SQL gerado pelo Prisma e o SQL final

O SQL final = SQL gerado pelo Prisma (Seção 1, inalterado) + SQL manual (Seção 2, adicionado).
Nenhuma linha da Seção 1 foi editada manualmente — a regra operacional do ADR-001 (§6:
"`prisma migrate` não pode apagar SQL manual de constraints... toda regeneração deve ser
revisada por diff") foi seguida colocando o SQL manual em seção própria e claramente
delimitada, nunca misturado ao bloco gerado.

## 8. Achados

| # | Achado | Classificação |
|---|---|---|
| 1 | As 27 constraints manuais adicionadas correspondem 1:1 às regras já autorizadas pelo ADR-001/DST-001 — nenhuma constraint nova foi inventada. | HISTÓRICO (confirmação) |
| 2 | O trigger `ADR-C005`/`COT-REL-NORM-001` foi copiado literalmente da PoC validada (mesmos nomes de tabela/coluna, mesma lógica) — nenhuma adaptação de comportamento foi feita. | HISTÓRICO (confirmação) |
| 3 | Nenhum CHECK foi criado para os 14 campos Enum/Ref ainda abertos (`DST-GAP-*`, `GAP-CDC-1.2-004`, `ADR-GAP-005`) — confirmado por inspeção da Seção 2 completa. | HISTÓRICO (confirmação) |
| 4 | `ADR-GAP-007` e `ADR-GAP-008` permanecem sem nenhuma coluna/FK na migration, consistente com a instrução de não resolvê-los nesta etapa. | HISTÓRICO (confirmação, não pendência nova) |
| 5 | A independência estrutural entre `status_processamento_dado` (DST-E009) e `status_qualidade_dado` (DST-E011) — Salvaguarda 1 da Errata controlada nº2 — é verificável diretamente no SQL: nenhuma constraint/trigger no arquivo referencia as duas colunas na mesma cláusula. | HISTÓRICO (confirmação) |
| 6 | Esta migration não foi testada contra um PostgreSQL real (nenhuma aplicação foi autorizada nesta etapa) — a verificação empírica do trigger `ADR-C005` já foi feita anteriormente na PoC dedicada (`poc/adr-001-vinculo-extremidade/`), mas essa PoC validou um schema MÍNIMO reduzido, não o schema completo de 20 tabelas desta migration. | EDITORIAL (observação, não bloqueante — a aplicação completa contra PostgreSQL real fica para a etapa de teste de integração autorizada separadamente) |

**Nenhuma inconsistência CRÍTICA ou RELEVANTE encontrada.**

## 9. Proibições respeitadas

- `prisma migrate dev`, `prisma migrate deploy`, `prisma db push`: **não executados**.
- Nenhuma migration foi marcada como aplicada (`_prisma_migrations` não foi tocado — não existe
  conexão com nenhum banco nesta etapa).
- Nenhum histórico de banco foi alterado.
- `ADR-GAP-007`, `ADR-GAP-008`, F9005/F9006, SEC-001, tenant isolation, autenticação, RLS,
  EVT-001, INT-001: nenhum implementado.
