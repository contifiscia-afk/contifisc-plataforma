# Relatório de teste de integração — migration `20260901120000_init_baseline_fisica`

**Status:** TESTE DE INTEGRAÇÃO CONCLUÍDO EM POSTGRESQL DESCARTÁVEL. Nenhum banco persistente,
staging, produção ou Neon foi usado. Ambos os containers criados para este teste foram
destruídos ao final.

## 1. Ambiente

| Item | Valor |
|---|---|
| Docker Desktop | 4.88.1 |
| Docker Engine | 29.7.2 (contexto `desktop-linux`, backend Linux/amd64) |
| Imagem PostgreSQL | `postgres:15` (Docker Hub oficial) |
| Versão PostgreSQL efetiva | **15.19** (Debian 15.19-1.pgdg13+2) |
| Prisma CLI / `@prisma/client` | 6.19.3 |
| Node.js | v24.19.0 |
| Container 1 (aplicação inicial + toda a bateria de testes) | `contifisc-migtest-pg1`, porta host `55433`, banco `contifisc_migtest` — **destruído ao final** |
| Container 2 (teste de repetibilidade) | `contifisc-migtest-pg2`, porta host `55434`, banco `contifisc_migtest2` — **destruído ao final** |

Nenhum dos dois bancos foi reutilizado do ambiente da plataforma; ambos foram criados
exclusivamente para este teste e não persistem após este relatório.

## 2. Aplicação da migration

Migration aplicada **sem nenhuma alteração**: `20260901120000_init_baseline_fisica/migration.sql`
copiado para dentro do container (`docker cp`) e verificado por checksum antes e depois da cópia:

```
260fe5cff184c1a1cd13ef524a3dd7ab  migration.sql  (idêntico dentro do container e no repositório)
```

Comando de aplicação: `psql -U postgres -d contifisc_migtest -v ON_ERROR_STOP=1 -f /tmp/migration.sql`

**Resultado: sucesso, 0 erros.** Única saída não-DDL: `NOTICE: schema "public" already exists,
skipping` (esperado — `CREATE SCHEMA IF NOT EXISTS` contra um banco Postgres que já cria
`public` por padrão; não é erro).

## 3. Auditoria estrutural pós-aplicação (catálogo PostgreSQL)

| Item | Esperado | Encontrado (banco 1) | Encontrado (banco 2, repetibilidade) | Confere |
|---|---|---|---|---|
| Tabelas canônicas | 20 | 20 | 20 | Sim |
| Colunas totais | 168 | 168 | 168 | Sim |
| Foreign keys | 20 | 20 | 20 | Sim |
| UNIQUE explícitos | 3 | 3 | 3 | Sim |
| Índices simples | 5 | 5 | 5 | Sim |
| CHECK constraints | 25 | 25 | 25 | Sim |
| Função (ADR-C005) | 1 | 1 | 1 | Sim |
| CONSTRAINT TRIGGER | 1 | 1 | 1 | Sim |
| PostgreSQL ENUM | 0 | 0 | 0 | Sim |
| Chaves primárias | 20 | 20 | 20 | Sim |

As 20 tabelas físicas batem nome a nome com os 20 models autorizados do `schema.prisma`
(`unidade_economica`, `pessoa_fisica`, `pessoa_juridica`, `vinculo`, `vinculo_extremidade`,
`receita`, `documento_fiscal`, `receita_documento_fiscal`, `arquivo_origem`,
`documento_fiscal_arquivo_origem`, `classificacao_equiparacao_hospitalar`,
`contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `fonte_pagadora`,
`cenario_tributario`, `resultado_calculo`, `conflito_dado`, `conflito_dado_item`,
`revisao_tecnica`). **Nenhuma tabela extra de domínio.** As 25 constraints CHECK nomeadas no
catálogo (`pg_constraint`, `contype='c'`) correspondem 1:1 às 25 listadas em
`ADR_TO_SQL_MATRIX.md` — confirmado por comparação direta dos nomes; nenhuma divergência contra
`schema.prisma`, `migration.sql` ou `ADR_TO_SQL_MATRIX.md`.

## 4. Testes positivos/negativos dos CHECKs

Cada teste isolado em `BEGIN; ...; ROLLBACK;` (nenhum dado de teste persiste), exceto onde
indicado. Todos os 30 casos abaixo tiveram o comportamento exatamente esperado.

| Constraint | Caso | Esperado | Obtido |
|---|---|---|---|
| `ck_receita_ownership_xor` | só `pessoa_fisica_id` | ACEITA | ACEITA |
| `ck_receita_ownership_xor` | só `pessoa_juridica_id` | ACEITA | ACEITA |
| `ck_receita_ownership_xor` | ambos preenchidos | REJEITA | REJEITA (violates check constraint "ck_receita_ownership_xor") |
| `ck_receita_ownership_xor` | ambos nulos | REJEITA | REJEITA (mesma constraint) |
| `ck_vinculo_extremidade_endpoint_xor` | exatamente 1 endpoint (UE) | ACEITA | ACEITA |
| `ck_vinculo_extremidade_endpoint_xor` | nenhum endpoint | REJEITA | REJEITA |
| `ck_vinculo_extremidade_endpoint_xor` | 2 endpoints (UE+PF) | REJEITA | REJEITA |
| `ck_vinculo_extremidade_lado` | `ORIGEM` | ACEITA | ACEITA |
| `ck_vinculo_extremidade_lado` | `DESTINO` | ACEITA | ACEITA |
| `ck_vinculo_extremidade_lado` | `LATERAL` (fora do vocabulário) | REJEITA | REJEITA |
| `ck_receita_competencia_formato` | `2026-09` | ACEITA | ACEITA |
| `ck_receita_competencia_formato` | `2026-13` | REJEITA | REJEITA |
| `ck_receita_competencia_formato` | `2026-9` | REJEITA | REJEITA |
| `ck_receita_competencia_formato` | `lixo` | REJEITA | REJEITA |
| `ck_receita_sistema_origem` (DST-E010) | `ERP_CONTABIL` | ACEITA | ACEITA |
| `ck_receita_sistema_origem` (DST-E010) | `NEON_DB` (infra proibida) | REJEITA | REJEITA |
| `ck_receita_status_processamento_dado` (DST-E009) | `VALIDADO` | ACEITA | ACEITA |
| `ck_receita_status_processamento_dado` (DST-E009) | `INEXISTENTE` | REJEITA | REJEITA |
| `ck_receita_status_qualidade_dado` (DST-E011) | `DIVERGENTE` | ACEITA | ACEITA |
| `ck_receita_status_qualidade_dado` (DST-E011) | `VALIDADO` (valor do outro eixo) | REJEITA | REJEITA — confirma que os dois vocabulários (E009/E011) não se aceitam mutuamente |
| `ck_unidade_economica_status_registro` (DST-E008) | `ATIVO` | ACEITA | ACEITA |
| `ck_unidade_economica_status_registro` (DST-E008) | `PENDENTE` | REJEITA | REJEITA |
| `ck_pessoa_juridica_regime_tributario` (DST-E001) | `SIMPLES_NACIONAL` | ACEITA | ACEITA |
| `ck_pessoa_juridica_regime_tributario` (DST-E001) | `MEI` | REJEITA | REJEITA |
| `ck_fonte_pagadora_tipo` (DST-E005) | `PESSOA_JURIDICA` | ACEITA | ACEITA |
| `ck_fonte_pagadora_tipo` (DST-E005) | `DESCONHECIDA` | REJEITA | REJEITA |
| `ck_conflito_dado_status` (DST-E007) | `ABERTO` | ACEITA | ACEITA |
| `ck_conflito_dado_status` (DST-E007) | `CONGELADO` | REJEITA | REJEITA |
| `ck_revisao_tecnica_status_revisao` (DST-E006) | `APROVADO` | ACEITA | ACEITA |
| `ck_revisao_tecnica_status_revisao` (DST-E006) | `EM_ABERTO` | REJEITA | REJEITA |
| `ck_evento_irpf_tipo_rendimento` (DST-E004) | `TRIBUTAVEL` | ACEITA | ACEITA |
| `ck_evento_irpf_tipo_rendimento` (DST-E004) | `DESCONHECIDO` | REJEITA | REJEITA |
| `ck_classificacao_eqhop_status_elegibilidade` (DST-E003) | `EH_001_ELEGIVEL` (com `receita_id` válido) | ACEITA | ACEITA |
| `ck_classificacao_eqhop_status_elegibilidade` (DST-E003) | `EH_999_INVALIDO` | REJEITA | REJEITA |

**Nota de metodologia:** a primeira tentativa do caso `EH_001_ELEGIVEL` usou um `receita_id`
aleatório inexistente e falhou pela FK (`classificacao_equiparacao_hospitalar_receita_id_fkey`),
não pelo CHECK — um erro de desenho do meu próprio script de teste, não da migration. Refeito
com uma `Receita` real previamente inserida na mesma transação; o CHECK então foi confirmado
como ACEITA corretamente.

## 5. Bateria ADR-C005 (constraint trigger `DEFERRABLE INITIALLY DEFERRED`)

| # | Cenário | Esperado | Obtido | SQLSTATE / mensagem |
|---|---|---|---|---|
| 1 | Vinculo + 1 ORIGEM + 1 DESTINO | COMMIT aceita | ACEITA | — |
| 2 | Vinculo + somente ORIGEM | COMMIT rejeita | REJEITADO no COMMIT | `P0001` — "ADR-C005/COT-REL-NORM-001: ... total=1, origem=1, destino=0" |
| 3 | Vinculo + somente DESTINO | COMMIT rejeita | REJEITADO no COMMIT | `P0001` — "... total=1, origem=0, destino=1" |
| 4 | Tentativa de 3 extremidades | rejeita | REJEITADO **no INSERT**, não no COMMIT | `23505` — `duplicate key value violates unique constraint "uq_vinculo_lado"` |
| 5 | Duas ORIGEM | rejeita | REJEITADO **no INSERT** | `23505` — mesma UNIQUE |
| 6 | Duas DESTINO | rejeita | REJEITADO **no INSERT** | `23505` — mesma UNIQUE |
| 7 | Estado intermediário incompleto (só ORIGEM) dentro da transação | permitido | PERMITIDO — `SELECT` intra-transação viu a 1 linha, sem erro | — |
| 8 | Completar (DESTINO) antes do COMMIT | aceita | ACEITA | — |
| 9 | Deixar incompleto até o COMMIT | rejeita | REJEITADO no COMMIT | `P0001` — "... total=1, origem=1, destino=0" |
| — | Confirmação de `DEFERRABLE INITIALLY DEFERRED` no catálogo | `tgdeferrable=t`, `tginitdeferred=t` | Confirmado (`pg_trigger`) | — |

**Achado importante (não é falha — é confirmação de desenho em profundidade):** os cenários 4/5/6
("três extremidades", "duas ORIGEM", "duas DESTINO") nunca chegam a acionar o trigger
`ADR-C005`, porque `UNIQUE(vinculo_id, lado_extremidade)` (`ADR-C003`) os rejeita **antes**, no
próprio `INSERT` — e como `lado_extremidade` só tem 2 valores fechados possíveis (`ORIGEM`,
`DESTINO`, `ADR-C004`/DST-E012), é fisicamente impossível ter mais de 2 linhas por `vinculo_id`
sem violar o UNIQUE primeiro. Isso é exatamente a divisão de responsabilidades que o próprio
ADR-001 §5.1 descreve: "`UNIQUE(vinculo_id, lado_extremidade)` + CHECK do lado impede
duplicidade, **mas não garante a existência das duas linhas**" — o trigger `ADR-C005` existe
especificamente para cobrir a lacuna de **sub**-população (0 ou 1 extremidade), não de
sobre-população (que já é impossível pelo UNIQUE+CHECK). Os testes confirmam essa divisão
funcionando exatamente como projetada.

**Achado adicional (observação, não bloqueante):** ao tentar limpar os dois `Vinculo` que
efetivamente commitaram durante os testes (cenários 1 e 8) com
`DELETE FROM vinculo_extremidade ...; DELETE FROM vinculo ...;` em uma única chamada `psql -c`
(que o protocolo simples do PostgreSQL executa como uma transação implícita única), a **própria**
constraint trigger deferida bloqueou a limpeza: ao remover as duas `vinculo_extremidade` de um
`vinculo_id`, a contagem cai para 0 — o que também viola "exatamente duas" no COMMIT implícito.
A transação de limpeza foi revertida por inteiro (nada foi de fato apagado, confirmado por
`SELECT` pós-tentativa). Isso demonstra que o trigger `ADR-C005`, do jeito que está especificado
no ADR (só valida "exatamente 2", sem exceção para remoção completa), também impede remover
todas as extremidades de um `Vinculo` dentro de uma única transação simples — uma consideração
operacional relevante para um futuro fluxo de exclusão/lifecycle de `Vinculo` (fora do escopo
desta migration e desta instrução), não um defeito da regra `ADR-C005` em si, que só especifica
o invariante de criação/estado estável, não um mecanismo de remoção.

## 6. Foreign keys, políticas de deleção e unicidade N:N

| Cenário | Esperado | Obtido |
|---|---|---|
| `ResultadoCalculo → CenarioTributario`: `DELETE` do `CenarioTributario` referenciado | impede (RESTRICT) | `23503` — `... violates foreign key constraint "resultado_calculo_cenario_tributario_id_fkey"` |
| Fato tributário (`Receita`) referenciado por `ClassificacaoEquiparacaoHospitalar`: `DELETE` da `Receita` | impede (RESTRICT), sem cascade destrutivo | `23503` — `... violates foreign key constraint "classificacao_equiparacao_hospitalar_receita_id_fkey"` |
| Evidência RAW (`ArquivoOrigem`) referenciada: `DELETE` do `ArquivoOrigem` | impede (RESTRICT) | `23503` — `... violates foreign key constraint "documento_fiscal_arquivo_origem_arquivo_origem_id_fkey"` |
| `DELETE` de `DocumentoFiscal` associado a um `ArquivoOrigem` | remove só a linha de associação (CASCADE), `ArquivoOrigem` sobrevive | Confirmado — após o `DELETE` (testado em transação com `ROLLBACK` para não persistir), `documento_fiscal_arquivo_origem` ficou com 0 linhas para aquele `arquivo_origem_id`, e `arquivo_origem` continuou com 1 linha (sobreviveu) |
| `ReceitaDocumentoFiscal`: inserir par duplicado `(receita_id, documento_fiscal_id)` | rejeita (UNIQUE) | `23505` — `uq_receita_documento_fiscal` |
| `DocumentoFiscalArquivoOrigem`: inserir par duplicado `(documento_fiscal_id, arquivo_origem_id)` | rejeita (UNIQUE) | `23505` — `uq_documento_fiscal_arquivo_origem` |

Nenhum teste de hard-delete foi conduzido de forma a exigir mudança de política — todos os
`DELETE`s testados confirmam exatamente o comportamento já autorizado (RESTRICT em
fato/evidência, CASCADE apenas em linha associativa).

## 7. Testes via Prisma Client

Gerado a partir do `schema.prisma` inalterado, apontado para o banco descartável via
`datasourceUrl` (sem editar `schema.prisma`, sem `.env`, sem `db push`, sem segunda migration).

| Verificação | Resultado |
|---|---|
| `create UnidadeEconomica` | PASS |
| `create PessoaFisica` | PASS |
| `create Receita` (owner via PF, satisfazendo XOR) | PASS |
| `findUnique` (read) | PASS |
| `create Receita` com PF **e** PJ preenchidos → erro do banco propagado pelo Prisma | PASS (rejeitado, `ck_receita_ownership_xor` visível na mensagem) |
| `create` N:N `DocumentoFiscalArquivoOrigem` | PASS |
| `$transaction([...])` — Vinculo + 1 ORIGEM + 1 DESTINO | PASS (commit aceito) |
| `$transaction([...])` — Vinculo + somente ORIGEM | REJEITADO conforme esperado (erro do trigger propagado através do `$transaction` do Prisma) |

**Compatibilidade ESM/CJS:** `packages/core/package.json` declara `"type": "module"`; o script de
teste usou `import { PrismaClient } from '@prisma/client'` (pacote CJS) via ESM, em Node v24.19.0
— funcionou sem erro de interoperabilidade, confirmando para o schema canônico **completo** (20
models) o que a PoC original já havia confirmado para o schema mínimo reduzido.

Nenhum comando `prisma db push` foi executado. Nenhuma segunda migration foi gerada. O Prisma
não alterou o schema do banco em nenhum momento deste teste (apenas leu/escreveu linhas).

## 8. Análise de drift (somente leitura)

```
prisma migrate diff --from-url <banco> --to-schema-datamodel schema.prisma --script
-- This is an empty migration.

prisma migrate diff --from-schema-datamodel schema.prisma --to-url <banco> --script
-- This is an empty migration.
```

**Resultado: zero diferenças em ambas as direções.** O motor de diff do Prisma não representa
`CHECK`, `FUNCTION` ou `CONSTRAINT TRIGGER` — por isso os 25 CHECKs, a função e o trigger
manuais **não aparecem** no diff em nenhuma direção. Isso não é drift oculto: é a confirmação
empírica de que o Prisma simplesmente não modela esses objetos e, portanto, uma futura
regeneração de migration via Prisma não tentaria removê-los (consistente com a regra
operacional do ADR-001 §6: "`prisma migrate` não pode apagar SQL manual de constraints").
Nenhum SQL manual foi removido para "zerar" o diff — o diff já estava zerado com o SQL manual
presente.

## 9. Gaps preservados (confirmados novamente por consulta ao catálogo)

| Item | Consulta | Resultado |
|---|---|---|
| F9005/F9006 (`versao_schema`/`correlation_id`) | busca por essas colunas em `information_schema.columns` | 0 ocorrências |
| `ADR-GAP-007` (F9009 em Receita/ContribuicaoPrevidenciaria/EventoIRPF) | busca por `arquivo_origem_id` nessas 3 tabelas | 0 ocorrências |
| `ADR-GAP-008` (F9007 em ResultadoCalculo/RevisaoTecnica) | busca por `registrado_em` nessas 2 tabelas | 0 ocorrências |
| `ContaAcesso`/`CredencialAcesso` | busca por tabelas com esses nomes | 0 ocorrências |
| `tenant_id` | busca em `information_schema.columns` | 0 ocorrências |
| RLS | `SELECT count(*) FROM pg_policies` | 0 |
| Autenticação (`password_hash` etc.) | busca em `information_schema.columns` | 0 ocorrências |
| EVT-001/INT-001 | nenhuma tabela/coluna/JSON genérico relacionado a evento/integração foi criado | confirmado por inspeção do `migration.sql` aplicado (idêntico ao commitado) |

## 10. Teste de repetibilidade

Container 1 destruído (`docker rm -f contifisc-migtest-pg1`). Container 2 criado do zero
(`contifisc-migtest-pg2`, banco `contifisc_migtest2`, vazio). `migration.sql` copiado novamente
(checksum idêntico: `260fe5cff184c1a1cd13ef524a3dd7ab`) e aplicado sem nenhuma modificação —
mesma sequência de saída (`CREATE SCHEMA`, 20× `CREATE TABLE`, 8× `CREATE INDEX`, 20+2×
`ALTER TABLE`/`CREATE FUNCTION`/`CREATE TRIGGER`), 0 erros.

Auditoria estrutural do banco 2 idêntica ao banco 1 em todos os 10 itens (ver tabela §3).
Spot-check comportamental: o mesmo cenário "Vinculo + somente ORIGEM → COMMIT rejeita" reproduziu
exatamente a mesma mensagem `P0001` no banco 2. **Reprodutibilidade em banco vazio confirmada.**
(Conforme instruído, não se exigiu idempotência no mesmo banco — apenas reprodutibilidade em
banco vazio, que foi demonstrada.)

Ambos os containers foram destruídos ao final (`docker rm -f`) — `docker ps -a` confirma zero
containers residuais.

## 11. Nenhuma correção automática foi necessária

Nenhum teste revelou falha estrutural ou comportamental na migration. Os dois "achados"
registrados em §5 são confirmações do desenho já especificado no ADR-001 (divisão de
responsabilidade UNIQUE+CHECK vs. trigger) e uma observação operacional sobre limpeza/exclusão
(fora do escopo desta instrução) — não exigiram, e não receberam, nenhuma edição de
`migration.sql` ou `schema.prisma`.

## 12. Classificação de achados

| # | Achado | Classificação |
|---|---|---|
| 1 | Inventário físico (20/168/20/3/5/25/1/1/0/20) idêntico em ambos os bancos e idêntico ao previsto em `schema.prisma`/`ADR_TO_SQL_MATRIX.md`. | HISTÓRICO (confirmação) |
| 2 | Todos os 30 casos de CHECK (positivos e negativos) comportaram-se exatamente como especificado. | HISTÓRICO (confirmação) |
| 3 | A bateria ADR-C005 (9 cenários + confirmação de catálogo) comportou-se exatamente como especificado, incluindo o estado intermediário permitido dentro da transação. | HISTÓRICO (confirmação) |
| 4 | UNIQUE(vinculo_id,lado_extremidade) + CHECK(lado) já tornam fisicamente impossível qualquer cenário de "mais de 2 extremidades" antes mesmo do trigger ser avaliado — divisão de responsabilidade confirmada exatamente como o ADR-001 §5.1 descreve. | EDITORIAL (observação de desenho, não uma falha) |
| 5 | O trigger `ADR-C005`, por não ter exceção para remoção completa, impede esvaziar as extremidades de um `Vinculo` até 0 dentro de uma transação simples — consideração relevante para um futuro mecanismo de exclusão/lifecycle, fora do escopo desta instrução. | EDITORIAL (observação, não bloqueante) |
| 6 | FKs/deleção/unicidade N:N comportaram-se exatamente como especificado (RESTRICT em fato/evidência, CASCADE só em linha associativa). | HISTÓRICO (confirmação) |
| 7 | Testes via Prisma (`create`/`read`/`$transaction`) funcionaram sem necessidade de alterar `schema.prisma`; compatibilidade ESM/CJS confirmada para o schema completo. | HISTÓRICO (confirmação) |
| 8 | Drift zero em ambas as direções; SQL manual corretamente invisível ao diff do Prisma (não removido, não sinalizado como pendência). | HISTÓRICO (confirmação) |
| 9 | Todos os gaps (F9005/F9006, ADR-GAP-007, ADR-GAP-008, SEC-001/tenant/RLS/autenticação, EVT-001/INT-001) confirmados ausentes por consulta direta ao catálogo. | HISTÓRICO (confirmação) |
| 10 | Reprodutibilidade estrutural e comportamental confirmada em banco totalmente novo. | HISTÓRICO (confirmação) |

**Nenhuma inconsistência CRÍTICA ou RELEVANTE encontrada.**

## 13. Comandos executados (resumo)

```
docker run -d --name contifisc-migtest-pg1 -e POSTGRES_PASSWORD=... -e POSTGRES_DB=contifisc_migtest -p 55433:5432 postgres:15
docker exec contifisc-migtest-pg1 pg_isready -U postgres
docker exec contifisc-migtest-pg1 psql -U postgres -d contifisc_migtest -c "SELECT version();"
docker cp .../migration.sql contifisc-migtest-pg1:/tmp/migration.sql
docker exec contifisc-migtest-pg1 md5sum /tmp/migration.sql
docker exec contifisc-migtest-pg1 psql -U postgres -d contifisc_migtest -v ON_ERROR_STOP=1 -f /tmp/migration.sql
docker exec contifisc-migtest-pg1 psql ... (consultas ao catálogo: information_schema.*, pg_indexes, pg_constraint, pg_proc, pg_trigger, pg_type, pg_policies)
docker exec contifisc-migtest-pg1 psql ... (30 casos de CHECK, 9 cenários ADR-C005, 7 cenários FK/delete/unicidade — cada um BEGIN/INSERT/COMMIT|ROLLBACK)
npx prisma generate  (client já gerado nas etapas anteriores, reaproveitado)
node tmp_prisma_integration_test.mjs  (TEST_DATABASE_URL apontando para o banco descartável; arquivo temporário, removido ao final)
npx prisma migrate diff --from-url <banco> --to-schema-datamodel schema.prisma --script
npx prisma migrate diff --from-schema-datamodel schema.prisma --to-url <banco> --script
docker rm -f contifisc-migtest-pg1
docker run -d --name contifisc-migtest-pg2 ... postgres:15
docker cp .../migration.sql contifisc-migtest-pg2:/tmp/migration.sql  (checksum idêntico)
docker exec contifisc-migtest-pg2 psql -U postgres -d contifisc_migtest2 -v ON_ERROR_STOP=1 -f /tmp/migration.sql
docker exec contifisc-migtest-pg2 psql ... (mesma auditoria estrutural + spot-check comportamental)
docker rm -f contifisc-migtest-pg2
docker ps -a  (confirmação: zero containers residuais)
```

Nenhum `prisma migrate dev`, `prisma migrate deploy` ou `prisma db push` foi executado em
nenhum momento.

## 14. Arquivos criados/alterados

- Criado: `packages/core/prisma/migrations/20260901120000_init_baseline_fisica/INTEGRATION_TEST_REPORT.md` (este arquivo).

Nenhum outro arquivo do repositório foi alterado. `migration.sql` e `schema.prisma`
permanecem **byte a byte idênticos** ao estado já commitado — nenhuma correção foi aplicada a
eles nesta etapa (confirmado pelo checksum idêntico do `migration.sql` usado em ambos os
containers).
