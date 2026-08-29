# @contifisc/core

Reservado para o schema físico (Prisma) do Modelo Canônico de Dados.

**Sem Prisma, sem migration, sem tabela nesta fase.** MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2
e COT-001 V1.1 já são a baseline aprovada. `docs/ADR-001_CONTIFISC_Schema_Fisico_PostgreSQL_Prisma_V1.0.md`
está com status **PROPOSTO** (não aprovado) — define as decisões físicas propostas
(constraints, índices, delete policy, mapping Prisma/PostgreSQL) mas não autoriza `schema.prisma`,
migration ou PoC até aprovação explícita. Ver revisão técnica na seção abaixo.

MCD-001 V1.1, CDC-001 V1.1, DST-001 V1.1 e COT-001 V1.0 são `SUPERSEDED` — preservados em
`docs/legacy/` apenas para histórico, e não orientam código novo.

## Gaps bloqueantes registrados (não resolvidos por inferência)

### DST-001 V1.2 §11 — gaps semânticos vigentes (fonte de verdade dos gaps de enum/vocabulário)

| Gap | Campo/tema | Situação |
|---|---|---|
| `DST-GAP-001` | `conselho_profissional` | Enum/Ref aberto; catálogo profissional não aprovado. |
| `DST-GAP-002` | `especialidade_saude` | Enum/Ref aberto; catálogo de especialidades não aprovado. |
| `DST-GAP-003` | `tipo_vinculo` | Catálogo fechado pendente. |
| ~~`DST-GAP-004`~~ | ~~`tipo_objeto_origem`/`tipo_objeto_destino`~~ | **RESOLVIDO na V1.2**: campos polimórficos removidos; usar `VinculoExtremidade` (`COT-SUP-001`) + FKs reais + `lado_extremidade` (DST-E012). |
| `DST-GAP-005` | `papel_vinculo` | Catálogo fechado pendente. |
| `DST-GAP-006` | `fonte_receita` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-007` | `tipo_documento_fiscal` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-008` | `tipo_vinculo_previdenciario` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-009` | `tipo_conflito` | Enum/Ref aberto; catálogo pendente. |
| `DST-GAP-010` | `tipo_objeto_revisado` | Enum/Ref aberto; depende de revisão/OBS. |
| `DST-GAP-011` | `papel_arquivo` (associação DocumentoFiscal↔ArquivoOrigem, `COT-SUP-003`) | Enum/Ref aberto. |
| `DST-GAP-012` | `tipo_objeto` de `ConflitoDadoItem` (`COT-SUP-004`) | Enum/Ref aberto, restrito ao domínio de auditoria. |
| `DST-GAP-013` | `papel_no_conflito` (`COT-SUP-004`) | Enum/Ref aberto. |
| `DST-GAP-014` | Identidade/autorização do revisor de `RevisaoTecnica` | Depende de SEC-001/OBS-001; nunca modelar como `PessoaFisica` por inferência. |

Nenhum desses gaps autoriza a criação de enum fechado, union fechada, ou schema físico local.
São Enum/Ref abertos — código deve usar tipo opaco/branded ou referência validável, nunca
inventar catálogo. Se uma implementação futura precisar de um deles, o passo correto é
aguardar o Change Request/revisão DST correspondente.

### CDC-001 V1.2 §11, MCD-001 V1.2 §23 e COT-001 V1.1 §15 — mapeamento cruzado

Os gaps `GAP-CDC-001`, `GAP-CDC-002` e `GAP-CDC-003` da CDC-001 V1.1 foram **resolvidos** pelo
MCD/CDC V1.2 (identidade própria de EqHop, associação N:N Receita↔DocumentoFiscal via
`ReceitaDocumentoFiscal`, e `ConflitoDadoItem` para os participantes de um conflito).

| Gap (CDC V1.2 / MCD V1.2) | Gap DST V1.2 correspondente | Tema |
|---|---|---|
| `GAP-CDC-1.2-001` / `GAP-MCD-CR2-002` | `DST-GAP-011` | `papel_arquivo` |
| `GAP-CDC-1.2-002` / `GAP-MCD-CR2-003` | `DST-GAP-012` + `DST-GAP-013` | `tipo_objeto` e `papel_no_conflito` de `ConflitoDadoItem` (CDC/MCD/COT tratam como um gap único; DST separa em dois termos — diferença de granularidade, não contradição) |
| `GAP-CDC-1.2-003` / `GAP-MCD-CR2-004` | `DST-GAP-014` | Identidade/autorização do revisor de `RevisaoTecnica` |
| `GAP-CDC-1.2-004` / `GAP-MCD-CR2-005` | *(sem gap DST — ver nota abaixo)* | `FontePagadora.identificador_fiscal` |
| ~~`GAP-MCD-CR2-001`~~ | — | **RESOLVIDO por COT-001 V1.1**: `VinculoExtremidade` agora está formalmente registrada como `COT-SUP-001`. |

**Nota sobre `GAP-CDC-1.2-004`/`GAP-MCD-CR2-005`:** COT-001 V1.1 §15 esclarece explicitamente
que este gap é "de modelagem/validação MCD/CDC" e "não é promovido artificialmente a gap
semântico DST" — ou seja, a ausência de `DST-GAP` correspondente é intencional (não é um gap de
enum/vocabulário), não uma omissão. Continua aberto, apenas fora do escopo do DST por desenho.

## Revisão técnica do ADR-001 (status PROPOSTO) — incompatibilidades Prisma/PostgreSQL

Revisão contra o repositório atual (nenhum código de persistência existe ainda — apenas
`packages/types` com `Uuid`/`Money`/`Competencia` como Value Objects) e contra a baseline
canônica. Nenhuma correção foi aplicada ao ADR; apenas registrada aqui para decisão humana.

### Confirmado como tecnicamente correto (sem incompatibilidade)
- `CHECK` (XOR de Receita/VinculoExtremidade, formato de `competencia`) **não é representável**
  no `schema.prisma` — Prisma não tem sintaxe declarativa para `CHECK` até a versão usada neste
  projeto; precisa mesmo ser SQL manual na migration, como o ADR §6 já assume corretamente.
- **Constraint trigger `DEFERRABLE INITIALLY DEFERRED`** (ADR-C005/§5.1) é sintaxe PostgreSQL
  válida e Prisma não tem equivalente declarativo — precisa ser SQL manual, como já previsto.
  Confirmado que uma transação Prisma (`$transaction`, array ou interativa) mapeia para uma
  única transação Postgres, então inserir `Vinculo` + as duas `VinculoExtremidade` na mesma
  transação e deixar o trigger validar no commit é uma estratégia tecnicamente viável.
- **Índice parcial** (`WHERE` em índice) também não é representável no `schema.prisma` — precisa
  de SQL manual, como o ADR já assume (a tabela do ADR §6 descreve isso como "limitado/não
  universal"; mais preciso seria "não suportado", mas a conclusão prática — SQL manual — está
  correta).
- Evitar `enum` nativo do Postgres para vocabulário aberto/em evolução (ADR-D010) é a decisão
  correta: alterar um `enum` nativo do Postgres via Prisma exige `ALTER TYPE ... ADD VALUE`, que
  historicamente não podia rodar dentro da mesma transação que já usa o novo valor — problemático
  para os enums governados pelo DST que ainda vão crescer (`DST-GAP-*`). O ADR não cita esse
  motivo explicitamente, mas a decisão em si é sólida.
- `Money`/`Competencia` já implementados em `packages/types` são consistentes com `NUMERIC(18,2)`
  (escala de 2 casas) e com `competencia` como string opaca `YYYY-MM` (não `Date`) — nenhuma
  incompatibilidade entre o repositório atual e o ADR.

### Achados (não corrigidos — apenas reportados)

| Severidade | Achado |
|---|---|
| **RELEVANTE** | ADR não fixa `relationMode` do Prisma. Se um `schema.prisma` futuro for gerado com `relationMode = "prisma"` (FKs emuladas no client, não no banco), toda a premissa do ADR — "constraints ficam no PostgreSQL, Prisma é subordinado" — quebra silenciosamente, porque os `ON DELETE`/`ON UPDATE` e a integridade referencial deixam de ser garantidos pelo banco. O ADR deveria declarar explicitamente `relationMode = "foreignKeys"` (padrão) como decisão obrigatória. |
| **RELEVANTE** | ADR-D007 (percentuais) deixa a escala "a definir por campo/ADR específico", mas o MCD-001 V1.2 §5 já fixa `NUMERIC(7,4)` para todo campo percentual. O ADR deveria referenciar essa escala já definida em vez de deixá-la em aberto — risco de alguém implementar com escala inconsistente. |
| **EDITORIAL** | ADR não declara uma versão mínima do PostgreSQL. `gen_random_uuid()` nativo (sem extensão `pgcrypto`) só existe a partir do PostgreSQL 13. Improvável ser um problema real (Neon/Supabase/RDS já operam em versões recentes), mas o ADR deveria declarar isso como premissa explícita. |
| **EDITORIAL** | `char(7)` (ADR §4, escolha preferida para `competencia`) é desaconselhado pela própria documentação do PostgreSQL a favor de `varchar`/`text`, por causa de padding e semântica de comparação com espaços — não é um problema prático aqui (toda `competencia` válida já tem exatamente 7 caracteres), mas `varchar(7)` seria a escolha mais idiomática sem custo algum. |
| **OBSERVAÇÃO** | Nenhum código do repositório hoje declara dependência de Prisma (não há `prisma` em nenhum `package.json`) — não há conflito de versão a verificar ainda. `tsconfig.base.json` usa `moduleResolution: "Bundler"` com `esModuleInterop: true`, compatível com o client gerado pelo Prisma; só vale reconfirmar isso quando `packages/core` ganhar `"type": "module"` (os demais pacotes já têm) — o client padrão do Prisma é CJS e a interop deve ser testada na PoC, não presumida. |

Nenhuma inconsistência **CRÍTICA** foi encontrada — nada no ADR impede tecnicamente a PoC ou o
desenho do schema. Os dois achados **RELEVANTE** deveriam ser esclarecidos no ADR antes da
aprovação, mas não bloqueiam a leitura/uso do documento como proposta.

## Também pendente

- `MCD-CHANGE-REQUEST-002` (`docs/MCD-CHANGE-REQUEST-002_CONTIFISC_V1.0.md`) está **APROVADO**
  e incorporado ao MCD-001 V1.2 / CDC-001 V1.2.
- Autenticação (`ContaAcesso`/`CredencialAcesso`, COT-OBJ-017/018) aguarda `SEC-001`.
- Lógica tributária de qualquer domínio aguarda `RGT-001`.
- `rule_set_id`/`rule_set_version`/`regra_versao_id` permanecem identificadores opacos até `RGT-001`.
