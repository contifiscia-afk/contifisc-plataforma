# Proposta de Errata/Revisão do ADR-001 — Estratégia Física dos Campos Transversais (MCD-F9001..F9010)

**Status:** PROPOSTO PARA APROVAÇÃO — documento autônomo, ainda não incorporado ao ADR-001.
**Alvo:** `docs/ADR-001_CONTIFISC_Schema_Fisico_PostgreSQL_Prisma_V1.0.md` (aprovado — baseline
física para PoC).
**Dependências:** MCD-001 V1.2 §8/§10, CDC-001 V1.2 §3/§8/§9/CDC-SYS-001, DST-001 V1.2 §5/§6/§10,
COT-001 V1.1, PoC `ADR-C005 VALIDADO`, análise arquitetural prévia dos campos transversais
(sessão corrente, não persistida como documento separado).
**Escopo:** decisão física de persistência para os 10 campos transversais do MCD-001 V1.2
(`MCD-F9001..F9010`). Não altera `schema.prisma`, não cria migration, não altera
COT/MCD/CDC/DST, não implementa nenhum campo. É uma proposta para revisão humana.

> Este documento não substitui o ADR-001. Se aprovado, seu conteúdo deve ser incorporado como
> nova seção/errata do ADR-001 (decisões `ADR-D015..D0XX` e gap `ADR-GAP-007`), analogamente ao
> que o MCD-CHANGE-REQUEST-002 foi para o MCD-001 V1.2.

## 1. Decisão de arquitetura

Os 10 campos transversais **não** recebem uma entidade relacional genérica de proveniência
nesta fase, e **não** recebem referência polimórfica reversa (`objeto_id` + `tipo_objeto`
apontando de uma tabela central para qualquer fato). Cada campo aplicável é materializado como
**coluna física direta** no(s) objeto(s) canônico(s) onde é semanticamente pertinente — decisão
por campo, não uma regra única para os 10.

Na camada TypeScript (`@contifisc/types`), os campos do Grupo A (origem) podem ser expostos como
uma composição lógica compartilhada (ex.: um tipo `ProvenienciaFato` reaproveitado pelos
DTOs/repositórios de `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF`, `DocumentoFiscal`) —
isso é uma conveniência de código, não uma tabela ou relação física. Essa composição não é
implementada neste passo.

`sistema_origem`, onde aplicado, usa exclusivamente os códigos vigentes do **DST-E010**
(`ERP_CONTABIL`, `DOCUMENTO_FISCAL`, `CNIS`, `FOLHA_PAGAMENTO`, `BANCO`,
`INFORME_RENDIMENTOS`, `CARNE_LEAO`, `ENTRADA_MANUAL`, `API_GOVERNAMENTAL`, `OUTRO_SISTEMA`).
Infraestrutura (PostgreSQL, Prisma, Neon, Vercel etc.) nunca é um valor válido — consistente com
DST-001 V1.2 §2/§10 e com a decisão já vigente (ADR-D010) de não usar `ENUM` nativo do Postgres
para vocabulário DST: a coluna é `TEXT`, fechada por `CHECK` na migration futura.

`identificador_origem` é a chave do registro no **sistema-fonte externo** — nunca o `id` UUID
interno da CONTIFISC (que já existe como PK de cada objeto). Os dois nunca devem ser confundidos
ou usados de forma intercambiável.

## 2. Matriz: campo MCD → objetos aplicáveis → estratégia física → tipo físico → constraint → dependência → justificativa

| Campo MCD | Objetos aplicáveis (models Prisma) | Estratégia física | Tipo físico proposto | Constraint | Dependência | Justificativa |
|---|---|---|---|---|---|---|
| **MCD-F9001** `sistema_origem` | `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF`, `DocumentoFiscal` | `APLICAR_COMO_COLUNA` | `String` / `TEXT` | CHECK PostgreSQL futuro contra códigos DST-E010 vigentes (não ENUM nativo, ADR-D010) | Nenhuma — pronto para errata | Fatos/documento com origem externa real (ERP/XML/CNIS/Informe); identidade/cenário/controle não têm origem externa a rastrear |
| **MCD-F9002** `identificador_origem` | `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF`, `DocumentoFiscal` (sempre em par com F9001) | `APLICAR_COMO_COLUNA` | `String` / `VARCHAR(120)` | Nenhuma constraint de unicidade universal — unicidade `(sistema_origem, identificador_origem)` só quando a fonte garantir (CDC-001 V1.2 §9); decisão por fonte fica para o ADR físico/migration, não fixada aqui | Nenhuma — pronto para errata | Chave de idempotência (par com F9001); identifica o registro na fonte, nunca o `id` interno |
| **MCD-F9003** `importado_em` | `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF`, `DocumentoFiscal` | `APLICAR_COMO_COLUNA` | `DateTime` / `TIMESTAMPTZ` | Nenhuma | Nenhuma — pronto para errata | Momento de ingestão no pipeline — distinto de `registrado_em` (F9007) e de `data_fato` (F9008) |
| **MCD-F9004** `status_processamento_dado` | `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF`, `DocumentoFiscal` (os mesmos 4 — não generalizado) | `APLICAR_COMO_COLUNA` | `String` / `TEXT` | CHECK PostgreSQL futuro contra códigos DST-E009 (`IMPORTADO`, `VALIDADO`, `RECONCILIADO`, `OVERRIDDEN`, `SUPERSEDED`, `CANCELADO`) — não ENUM nativo | Nenhuma — pronto para errata | Workflow/lifecycle de reconciliação; não se aplica a `UnidadeEconomica` (tem `status_registro` próprio), `ConflitoDado` (tem `status_conflito`) nem `ResultadoCalculo`/`RevisaoTecnica` (têm `status_revisao`) — evita colisão semântica com eixos de estado já existentes |
| **MCD-F9005** `versao_schema` | Nenhum (bloqueado) | `DECISÃO_BLOQUEADA` | — | — | **BLOQUEADO POR EVT-001/INT-001** | Propriedade do envelope de ingestão/evento (CDC-001 V1.2 §3/§11), não do fato persistido; não deve ser antecipada como coluna de domínio |
| **MCD-F9006** `correlation_id` | Nenhum (bloqueado) | `DECISÃO_BLOQUEADA` | — | — | **BLOQUEADO POR EVT-001/INT-001** | Mesma natureza de F9005 — correlaciona lote/evento de ingestão, não é atributo do fato em si |
| **MCD-F9007** `registrado_em` | `PessoaFisica`, `PessoaJuridica`, `Vinculo`, `VinculoExtremidade`, `Receita`, `DocumentoFiscal`, `ReceitaDocumentoFiscal`, `ArquivoOrigem`, `DocumentoFiscalArquivoOrigem`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `FontePagadora`, `CenarioTributario`, `ConflitoDado`, `ConflitoDadoItem` (16 models) | `APLICAR_COMO_COLUNA` nos 16 listados; `NÃO_SE_APLICA_A_TODOS_OS_OBJETOS` em `UnidadeEconomica`, `ClassificacaoEquiparacaoHospitalar`, `ResultadoCalculo`, `RevisaoTecnica` | `DateTime` / `TIMESTAMPTZ` | Nenhuma | Nenhuma — pronto para errata | Os 4 objetos excluídos já têm campo doméstico equivalente (`criado_em`/`registrado_em`/`calculado_em`/`revisado_em`, MCD-F0004/F5010/F8208/F8706) — duplicar `registrado_em` neles violaria MCD-001 V1.2 §2 ("um conceito não pode ter dois campos canônicos"). **Não é** o timestamp de importação (F9003) nem de ocorrência do fato (F9008) |
| **MCD-F9008** `data_fato` | `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF` | `APLICAR_COMO_COLUNA` | `DateTime` / `DATE` (MCD classifica como "Date/Timestamp"; proposta usa `DATE` por analogia às demais datas civis do schema — sinalizado para confirmação se o caso de uso exigir hora) | Nenhuma | Nenhuma — pronto para errata, exceto a escolha `DATE` vs `TIMESTAMPTZ` fica sinalizada, não fechada por inferência | Data de ocorrência econômica do fato quando distinta de `data_emissao`/`competencia`; só os 3 fatos puros têm essa divergência potencial |
| **MCD-F9009** `arquivo_origem_id` | `DocumentoFiscal`: já resolvido por `DocumentoFiscalArquivoOrigem` (nenhuma coluna nova). `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF`: **sem relacionamento autorizado com `ArquivoOrigem` hoje** | `APLICAR_VIA_RELACIONAMENTO_EXISTENTE` (DocumentoFiscal); demais → **gap de modelagem registrado, não implementado** | — | — | **Gap de modelagem — proposto `ADR-GAP-007`** (nenhuma FK criada por inferência) | CDC-001 V1.2 §3 já distingue o `arquivo_origem_id` transversal da associação específica CDC-FIS-003 ("ambos têm papéis distintos"); como `Receita`/`ContribuicaoPrevidenciaria`/`EventoIRPF` não têm hoje nenhuma relação autorizada com `ArquivoOrigem`, criar uma FK agora seria inventar relacionamento não aprovado |
| **MCD-F9010** `status_qualidade_dado` | `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF`, `DocumentoFiscal` (mesmos 4 de F9004, sempre em par) | `APLICAR_COMO_COLUNA` | `String` / `TEXT` | CHECK PostgreSQL futuro contra códigos DST-E011 (`NAO_AVALIADO`, `VALIDO`, `INCOMPLETO`, `DIVERGENTE`, `SUSPEITO`) — não ENUM nativo; **CHECK sempre separado do CHECK de F9004** | Nenhuma — pronto para errata | Eixo de qualidade **independente** do eixo de processamento (CR-002/DST-001 V1.2 §5): `VALIDADO` em processamento não implica `VALIDO` em qualidade; `RECONCILIADO` não elimina `DIVERGENTE` |

## 3. Gap de modelagem proposto — `ADR-GAP-007`

| Gap | Tema | Tratamento |
|---|---|---|
| ADR-GAP-007 (proposto) | `MCD-F9009 arquivo_origem_id` em `Receita`, `ContribuicaoPrevidenciaria`, `EventoIRPF` | Esses três fatos podem precisar apontar para evidência RAW sem passar por `DocumentoFiscal` (ex.: Informe de Rendimentos escaneado, extrato de CNIS em PDF), mas hoje não existe relacionamento autorizado com `ArquivoOrigem` para eles. Não criar FK por inferência. Aguardar decisão explícita (nova revisão do ADR ou do COT, conforme o caso) antes de modelar. |

Este gap fica registrado ao lado dos já existentes em `packages/core/prisma/SCHEMA_V1_PROPOSAL_REPORT.md` — não é resolvido aqui.

## 4. Bloqueio explícito — F9005/F9006

`MCD-F9005` (`versao_schema`) e `MCD-F9006` (`correlation_id`) permanecem
**`DECISÃO_BLOQUEADA` / `BLOQUEADO POR EVT-001/INT-001`**. A materialização física dos outros
oito campos desta proposta **não autoriza, não antecipa e não inventa** tipo físico, coluna,
tabela ou semântica provisória para F9005/F9006. Nenhum model recebe esses dois campos nesta
proposta, mesmo que already tenha recebido outros campos transversais (ex.: `Receita` recebe
F9001/F9002/F9003/F9004/F9007/F9008/F9010, mas **não** recebe F9005/F9006).

## 5. Resumo de classificações

| Campo | Classificação |
|---|---|
| MCD-F9001 | `APLICAR_COMO_COLUNA` |
| MCD-F9002 | `APLICAR_COMO_COLUNA` |
| MCD-F9003 | `APLICAR_COMO_COLUNA` |
| MCD-F9004 | `APLICAR_COMO_COLUNA` (escopo fechado: 4 objetos) |
| MCD-F9005 | `DECISÃO_BLOQUEADA` |
| MCD-F9006 | `DECISÃO_BLOQUEADA` |
| MCD-F9007 | `APLICAR_COMO_COLUNA` (16 objetos) / `NÃO_SE_APLICA_A_TODOS_OS_OBJETOS` (4 objetos com equivalente próprio) |
| MCD-F9008 | `APLICAR_COMO_COLUNA` (escopo fechado: 3 objetos) |
| MCD-F9009 | `APLICAR_VIA_RELACIONAMENTO_EXISTENTE` (DocumentoFiscal) + gap registrado (demais) |
| MCD-F9010 | `APLICAR_COMO_COLUNA` (escopo fechado: 4 objetos, sempre par com F9004) |

## 6. Impacto em `schema.prisma` (quando esta proposta for aprovada — não implementado agora)

Nenhuma alteração foi feita. Quando aprovada, esta proposta implica adicionar colunas a 16 dos
20 models já existentes — nenhum model novo, nenhuma estrutura `COT-SUP-*` nova, nenhuma
migration. A implementação em si permanece um passo futuro e separado, sujeito a nova
autorização explícita.

## 7. ADR suficiente ou novo ADR necessário?

**A revisão/errata do ADR-001 é suficiente.** Nenhuma das 8 decisões materializáveis
(F9001/F9002/F9003/F9004/F9007/F9008/F9010, mais o encaminhamento de F9009 como gap) exige
criar um objeto ou estrutura de suporte novo no COT-001 — todas se apoiam em models já
registrados (`COT-OBJ-*`/`COT-SUP-*` existentes) e em relacionamentos já autorizados
(`DocumentoFiscalArquivoOrigem` para o caso de F9009 em `DocumentoFiscal`). Isso contrasta com a
alternativa descartada de entidade de proveniência genérica, que exigiria registrar uma nova
`COT-SUP-005` no COT-001 antes de qualquer ADR poder modelá-la — precisamente a alternativa que
esta decisão evitou.

F9005/F9006 não geram incompatibilidade que exija um novo ADR agora — são apenas
**dependências externas não resolvidas** (EVT-001/INT-001), tratadas como bloqueio, não como
falha arquitetural do ADR-001.

## 8. Critérios de aceite desta proposta

- [ ] Objetos aplicáveis por campo revisados e confirmados (especialmente a lista de 16 para F9007).
- [ ] Tipo `DATE` vs `TIMESTAMPTZ` para `data_fato` (F9008) confirmado.
- [ ] `ADR-GAP-007` aceito como gap registrado (não resolvido) para F9009 em Receita/Contribuição/EventoIRPF.
- [ ] Confirmação de que F9005/F9006 permanecem bloqueados sem exceção.
- [ ] Aprovação para incorporar este conteúdo como errata/nova seção do ADR-001.

---
**Governança:** este documento é uma proposta de decisão física, subordinada ao ADR-001 e à
baseline COT/MCD/CDC/DST vigente. Não é fonte de verdade por si só — só passa a valer após
incorporação formal ao ADR-001 e, a partir daí, sujeita ao mesmo processo de PoC/proposta de
`schema.prisma`/migration já em vigor para o restante do modelo.
