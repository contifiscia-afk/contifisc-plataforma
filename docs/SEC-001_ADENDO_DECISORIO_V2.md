# SEC-001 — Adendo Decisório V2: Resolução Conceitual do Ownership/Tenant

**Status:** ADENDO — resolve os bloqueios estruturais registrados em
`SEC-001_ADENDO_DECISORIO_V1.md`. Ainda não é normativo. **Não altera** COT/MCD/CDC/DST/ADR,
`schema.prisma` ou migrations. **Não cria** banco, RLS ou autenticação. Análise exclusivamente
conceitual.

---

## 1. Correção da matriz 20/20

**Erro identificado:** o adendo V1 somou `1 + 3 + 8 + 6 + 3 = 21`. A causa foi apresentar
`vinculo` e `vinculo_extremidade` — duas tabelas físicas distintas — como **uma única linha**
("`vinculo` / `vinculo_extremidade`") na matriz, mas rotular essa linha como valendo "8" no
resumo textual, sem refletir que ela continha 2 tabelas, não 1. Não havia dupla classificação de
nenhuma tabela — era um erro de rotulagem no resumo, não um erro na matriz linha a linha (que já
somava certo). Corrigido abaixo com uma linha por tabela física, sem exceções tratadas como
segunda categoria.

| # | Tabela | Classificação primária (única) | Atributo secundário (não conta na soma) |
|---|---|---|---|
| 1 | `unidade_economica` | `TENANT_ROOT` | — |
| 2 | `pessoa_fisica` | `GLOBAL_SHARED` | — |
| 3 | `pessoa_juridica` | `GLOBAL_SHARED` | — |
| 4 | `fonte_pagadora` | `GLOBAL_SHARED` | — |
| 5 | `vinculo` | `TENANT_DERIVED` | Exceção: se nenhuma das duas extremidades for `UnidadeEconomica`, não há tenant derivável (ver §7) |
| 6 | `vinculo_extremidade` | `TENANT_DERIVED` | Mesma exceção da linha 5 |
| 7 | `receita` | `TENANT_MATERIALIZED_FOR_SECURITY` | Sem fonte canônica confiável hoje (ver §3-4) |
| 8 | `contribuicao_previdenciaria` | `TENANT_MATERIALIZED_FOR_SECURITY` | Idem |
| 9 | `vinculo_previdenciario` | `TENANT_MATERIALIZED_FOR_SECURITY` | Idem |
| 10 | `evento_irpf` | `TENANT_MATERIALIZED_FOR_SECURITY` | Idem |
| 11 | `documento_fiscal` | `TENANT_MATERIALIZED_FOR_SECURITY` | Idem — ver também §6 |
| 12 | `arquivo_origem` | `TENANT_MATERIALIZED_FOR_SECURITY` | Idem — ver também §6 |
| 13 | `receita_documento_fiscal` | `TENANT_DERIVED` | Depende de `receita`/`documento_fiscal` (linhas 7/11) |
| 14 | `documento_fiscal_arquivo_origem` | `TENANT_DERIVED` | Depende de `documento_fiscal` (linha 11) |
| 15 | `classificacao_equiparacao_hospitalar` | `TENANT_DERIVED` | Depende de `receita` (linha 7) |
| 16 | `cenario_tributario` | `TENANT_DERIVED` | Nenhuma — FK direta e obrigatória a UE, já resolvido |
| 17 | `resultado_calculo` | `TENANT_DERIVED` | Exceção: indeterminado quando `cenario_tributario_id` é nulo (ver §8) |
| 18 | `conflito_dado` | `DECISION_BLOCKED` | Ver §9 |
| 19 | `conflito_dado_item` | `DECISION_BLOCKED` | Ver §9 |
| 20 | `revisao_tecnica` | `DECISION_BLOCKED` | Ver §9 |

**Soma correta, por contagem direta das 20 linhas acima:** `TENANT_ROOT`=1 (linha 1) ·
`GLOBAL_SHARED`=3 (linhas 2-4) · `TENANT_DERIVED`=7 (linhas 5, 6, 13, 14, 15, 16, 17) ·
`TENANT_MATERIALIZED_FOR_SECURITY`=6 (linhas 7-12) · `DECISION_BLOCKED`=3 (linhas 18-20).

**`1 + 3 + 7 + 6 + 3 = 20`** ✓ — o valor correto de `TENANT_DERIVED` é **7**, não 8 (o "8" do
adendo V1 tinha o mesmo problema de rotulagem do resumo, não da matriz linha a linha). Esta é a
versão de referência: **20 tabelas, 20 linhas, 1 classificação primária cada.**

## 2. Verificação do princípio "identidade do titular ≠ ownership do fato ≠ autorização de acesso"

A hipótese **resolve corretamente** os cenários já analisados (adendo V1, §4): permite que
`pessoa_fisica`/`pessoa_juridica`/`fonte_pagadora` permaneçam identidades globais únicas sem
duplicação, sem forçar um `tenant_id` inválido sobre elas. **Mas ela sozinha não é suficiente**
— o princípio nomeia corretamente os três eixos, mas não diz **de onde vem** o valor do segundo
eixo (ownership do fato/tenant) quando o titular não o determina. É exatamente essa lacuna que os
itens 3-4 abaixo resolvem: o ownership do fato precisa de uma **relação de domínio própria**,
diferente da identidade do titular — não pode ficar sem fonte nenhuma.

## 3-4. O elemento canônico que falta: contexto de apuração (UE) no próprio fato

**Pergunta:** qual elemento canônico determina a qual Tenant pertence uma ocorrência concreta de
`Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`?

**Resposta:** nenhum elemento **hoje existente** resolve isso de forma confiável — esse é
precisamente o achado do adendo V1. A resposta correta não é "adicionar `tenant_id`" (isso seria
"dado sem fonte canônica confiável", exatamente a armadilha a evitar) — é reconhecer que **falta
uma relação de domínio genuína**: nenhuma dessas cinco tabelas registra, hoje, "em nome de qual
`UnidadeEconomica` este fato está sendo apurado/administrado" — elas só registram **quem é o
titular tributário** (PF/PJ), que é uma pergunta diferente. Isso não é um artefato de segurança:
é uma pergunta de negócio legítima e já implícita em qualquer fluxo real de trabalho ("estou
lançando esta receita para o cliente X") que nunca foi explicitada no MCD.

### Comparação de alternativas

| Critério | A. Tenant direto no fato | B. UE direta no fato | C. Contexto intermediário (`Vinculo`) | D. Associação própria fato↔UE | E. Híbrida por tipo de fato |
|---|---|---|---|---|---|
| Cardinalidade | N fatos : 1 tenant | N fatos : 1 UE : 1 tenant | N fatos : 1 `Vinculo` : 1 UE | N:N (over-engineering se a relação real é 1:1) | Mistura arbitrária |
| Semântica tributária | **Nenhuma** — puro artefato de segurança | Forte — "apurado no contexto da UE X" é uma afirmação de domínio genuína | Mais forte ainda — também informa "sob qual relação" (ex.: sócio, funcionário) | Igual a B, mas sem ganho sobre FK direta | Inconsistente sem justificativa |
| Compartilhamento | Resolve, mas artificialmente | Resolve corretamente | Resolve corretamente | Resolve, mas com complexidade extra | — |
| Reconciliação | Neutra | Habilita filtrar por UE diretamente | Habilita filtrar por UE **e** por tipo de relação | Igual a B | — |
| Histórico | Sem rastro do "porquê" | FK é a própria evidência | FK + semântica do vínculo é mais rica | Igual a B | — |
| RLS | Ótima (1 hop, mas sem fonte) | Ótima (1 hop, com fonte) | Boa (2-3 hops) | Ótima, mas redundante | — |
| Performance | Ótima | Ótima | Levemente pior (mais um hop) | Ótima | — |
| Auditabilidade | **Baixa** — nada explica o valor | Alta | Alta (mais rica) | Alta | — |

**Decisão recomendada: Opção B — FK direta e nova, `unidade_economica_id`, adicionada a
`Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`
(e `ResultadoCalculo`, ver §8).** Reaproveita o objeto já existente (`UnidadeEconomica`), não cria
abstração nova, resolve cardinalidade e semântica corretamente, e é a opção mais simples que
resolve o problema — consistente com "não criar abstrações genéricas se relações existentes
puderem resolver o problema". A Opção C (via `Vinculo`) permanece uma melhoria **tributária**
futura legítima (saber não só a UE, mas o tipo de relação), mas não é necessária para resolver
especificamente o problema de tenant — fica registrada como possível refinamento futuro, não
como parte do escopo mínimo deste Change Request.

**Resposta à pergunta do item 4:** um `tenant_id` isolado, sem a FK acima, seria **dado sem fonte
canônica confiável** (a situação atual). Com a FK `unidade_economica_id` adicionada, um eventual
`tenant_id` redundante passaria a ser **desnormalização física legítima para segurança/
performance** — porque agora existe uma fonte de verdade (a nova FK) contra a qual um
trigger pode validar consistência (`tenant_id da linha = unidade_economica.tenant_id da UE
referenciada`), no mesmo padrão de constraint já usado nesta migration. **Sem essa FK, não existe
relacionamento suficiente no MCD atual — será necessário Change Request** (ver §12).

## 5. Cenário estendido de PF compartilhada

Dra. Ana (`pessoa_fisica.id = X`), participando de `UnidadeEconomica Alfa` (Tenant 1) e
`UnidadeEconomica Beta` (Tenant 2), duas relações comerciais não relacionadas:

| Fato | `pessoa_fisica_id` | `unidade_economica_id` (novo, proposto) | Tenant derivado |
|---|---|---|---|
| Receita 1 (honorário recebido via Alfa) | X | UE Alfa | Tenant 1 |
| Receita 2 (consultoria faturada via Beta) | X | UE Beta | Tenant 2 |
| EventoIRPF (só relevante a Alfa) | X | UE Alfa | Tenant 1 — Tenant 2 nunca enxerga esta linha |
| ContribuicaoPrevidenciária (origem Alfa) | X | UE Alfa | Tenant 1 |
| ContribuicaoPrevidenciária (origem Beta) | X | UE Beta | Tenant 2 |

**Onde fica o ownership sem duplicar a PF:** a linha `pessoa_fisica.id = X` permanece **única**,
sem `tenant_id`, sem cópia. O ownership tributário de cada fato continua sendo a mesma PF (X) em
todos os casos — o que muda, fato a fato, é o **novo campo `unidade_economica_id`**, que é
totalmente independente de quem é o titular. Isso demonstra exatamente a separação dos três eixos
do item 2: mesma identidade (X), mesmo mecanismo de ownership tributário (FK para PF), mas
contexto/tenant diferente por fato individual — nunca inferido a partir da PF.

**Documento servindo de evidência para mais de um fato:** tratado separadamente no item 6 — é
justamente o caso que exige uma resposta diferente de "materializar `unidade_economica_id`
direto", porque aqui a ambiguidade é genuína (o mesmo arquivo físico) e não apenas um problema de
FK ausente.

## 6. `DocumentoFiscal` e `ArquivoOrigem`

**Não presumido que pertencem a exatamente 1 tenant** — analisados separadamente, como pedido.

### `DocumentoFiscal`

Um documento fiscal individual (ex.: uma NFe específica) é, na prática tributária real, emitido
para **uma transação comercial específica**, tipicamente de **um cliente**. A associação N:N com
`Receita` (`ReceitaDocumentoFiscal`) existe para permitir 1 documento cobrir N receitas (rateio) —
mas não há caso de negócio conhecido em que essas N receitas pertençam a **tenants diferentes**.

**Recomendação: `TENANT_OWNED`.** `DocumentoFiscal` ganha sua **própria** FK
`unidade_economica_id` (não derivada apenas de `Receita`) — porque, no fluxo de ingestão real, o
documento fiscal frequentemente chega **antes** de qualquer `Receita` ser lançada (ex.: XML de
NFe importado do SEFAZ antes da contabilização) — depender só da derivação via `Receita` deixaria
o documento "sem tenant" durante essa janela. Um trigger deve então **validar** (não derivar) que
toda `Receita` associada via `ReceitaDocumentoFiscal` compartilha o mesmo `unidade_economica_id`
do `DocumentoFiscal` — rejeitando associações cross-tenant na própria constraint, não apenas na
aplicação.

### `ArquivoOrigem`

Cenário do item 5 (documento servindo de evidência para mais de um fato) é mais crítico aqui:
diferente de um `DocumentoFiscal` (documento fiscal legalmente específico), um `ArquivoOrigem`
bruto (ex.: um extrato bancário pessoal da Dra. Ana) **poderia, em tese**, ser usado como
evidência tanto para um lançamento em Alfa quanto em Beta — e a **deduplicação por hash**
(`hash_conteudo`, já existente no schema) tentaria naturalmente unificá-los na mesma linha se
implementada ingenuamente (dedup global por hash), criando exatamente o vazamento que se quer
evitar: uma linha de evidência compartilhada silenciosamente entre dois tenants sem nenhuma
decisão explícita.

**Recomendação: `TENANT_OWNED`, com a regra explícita de que a deduplicação por hash NUNCA deve
ser global** — a chave de deduplicação efetiva deve ser conceitualmente
`(tenant/unidade_economica, hash_conteudo)`, nunca apenas `hash_conteudo`. O tenant de um
`ArquivoOrigem` é **fixado no momento da primeira associação** (via
`DocumentoFiscalArquivoOrigem`) e um trigger deve **proibir** uma segunda associação a um
`DocumentoFiscal` de tenant diferente — se duas ingestões distintas (tenants diferentes)
produzirem um arquivo byte-idêntico, o sistema deve criar **duas linhas `ArquivoOrigem`
separadas** (aceitando duplicação de armazenamento) em vez de unificá-las. Isso é uma inversão
deliberada do instinto natural de "deduplicar tudo que for idêntico" — aqui, a segurança
justifica **não** deduplicar entre tenants, mesmo ao custo de espaço de armazenamento.

Nenhuma das duas tabelas se qualifica como `GLOBAL_SHARED` (não há nenhum caso de domínio real,
diferente de PF/PJ/FontePagadora, em que o **mesmo documento fiscal ou evidência** deva ser
legitimamente visível a dois clientes distintos da CONTIFISC simultaneamente) nem como
`TENANT_SCOPED_ASSOCIATION` genérica (a FK direta com trigger de validação é suficiente e mais
simples).

## 7. `Vinculo`

**Não se fecha `tipo_vinculo` por inferência** (`DST-GAP-003` permanece aberto). A resposta,
portanto, é uma **árvore de decisão**, não uma escolha única fechada agora:

- **Se, no futuro, o catálogo fechado de `tipo_vinculo` confirmar que todo tipo de vínculo
  relevante ao domínio tributário sempre envolve pelo menos uma `UnidadeEconomica`** (plausível,
  dado que `Vinculo` hoje já carrega `percentual_participacao_societaria`, um conceito
  inerentemente societário/empresarial) — então a regra estrutural correta seria **exigir que
  pelo menos uma das duas extremidades de todo `Vinculo` seja `UnidadeEconomica`** — uma nova
  constraint (`CHECK`/trigger), a decidir formalmente junto com o fechamento de `DST-GAP-003`.
- **Se o domínio eventualmente precisar de vínculos legitimamente sem UE** (ex.: relação PF-PF
  para fins de declaração conjunta de IRPF, um caso não documentado hoje, mas não impossível) —
  então `Vinculo`/`VinculoExtremidade` devem ser tratados, para esses casos residuais, como
  referência **global sem tenant próprio** (mesmo padrão de `pessoa_fisica`), com o tenant
  relevante ficando inteiramente a cargo do **fato que referencia aquele vínculo** (uma vez que
  os fatos passem a ter seu próprio `unidade_economica_id`, per §3-4, eles não dependem mais do
  `Vinculo` para determinar tenant de qualquer forma).

**Conclusão:** ambas as ramificações são estruturalmente seguras — nenhuma deixa uma brecha de
vazamento, porque, após a correção do §3-4, os FATOS que importam para RLS não dependem mais de
`Vinculo` para resolver tenant. A decisão entre as duas ramificações é uma decisão de **modelagem
tributária** (que tipos de vínculo existem), não uma decisão de segurança — corretamente adiada
até `DST-GAP-003` fechar. `Vinculo`/`VinculoExtremidade` continuam classificados `TENANT_DERIVED`
como caso dominante, com a exceção documentada como atributo secundário (§1), não um bloqueio.

## 8. `ResultadoCalculo` sem `CenarioTributario`

**Não se torna `cenario_tributario_id` obrigatório só para resolver segurança.** Investigando a
razão de negócio da nulidade: `CenarioTributario` é descrito no COT como "simulação **isolada**
dos fatos oficiais" — ou seja, existe uma distinção real entre (a) um `ResultadoCalculo` que é
uma **simulação** (tem `CenarioTributario`) e (b) um `ResultadoCalculo` que é o **cálculo oficial**
sobre os fatos reais da UE, sem nenhuma simulação envolvida (não precisa de
`CenarioTributario`, e isso é uma distinção tributária legítima, não uma lacuna de dados).

**Recomendação:** adicionar um `unidade_economica_id` **próprio e opcional** a `ResultadoCalculo`
— usado precisamente no caso (b), onde não há `CenarioTributario`. A regra de domínio a ser
formalizada (Change Request) seria: **todo `ResultadoCalculo` deve ter exatamente um entre
`cenario_tributario_id` OU `unidade_economica_id` preenchido** (XOR, mesmo padrão já usado em
`ADR-C001`/`ADR-C002`) — nunca os dois, nunca nenhum. Isso resolve o tenant em ambos os ramos sem
forçar nenhuma obrigatoriedade que não seja já uma exigência natural do domínio (todo cálculo,
simulado ou oficial, precisa dizer para qual UE ele vale).

## 9. Objetos polimórficos (`ConflitoDado`, `ConflitoDadoItem`, `RevisaoTecnica`)

**A referência polimórfica de auditoria (`objeto_id`/`tipo_objeto`,
`objeto_revisado_id`/`tipo_objeto_revisado`) não deve virar mecanismo de isolamento** — usá-la
para derivar tenant exigiria resolver, em tempo de query, um ponteiro sem FK real para um de N
tipos de tabela possíveis, e depois aplicar a ele toda a lógica de derivação já frágil das
tabelas de fato — um acoplamento perigoso entre dois domínios (auditoria e segurança) que o
próprio ADR-001 já proíbe para ownership tributário, pela mesma razão.

### Comparação

| Opção | Avaliação |
|---|---|
| Tenant materializado (coluna direta) | Viável, mas reintroduz "dado sem fonte automática" — precisa ser setado pelo serviço que cria o registro, não por FK. |
| **Contexto de segurança próprio** | **Recomendado.** Tratar o tenant destes 3 objetos como um **metadado transversal de segurança**, estruturalmente análogo ao padrão já estabelecido para `MCD-F9001..F9010` (a Errata controlada nº2 do ADR-001 já institucionalizou exatamente esse padrão: um campo transversal, preenchido pelo serviço de domínio, sem CHECK/FK cruzando para o objeto de negócio principal). Reutiliza um padrão já aprovado neste projeto, em vez de inventar um novo. |
| Derivação por objeto revisado | **Rejeitada** — é exatamente reaproveitar a referência polimórfica de auditoria como mecanismo de isolamento, proibido pela própria premissa do item 9. |
| Associação explícita (tabela própria) | Funcionalmente equivalente à materialização, com uma tabela a mais sem benefício claro (a relação é 1:1 por registro, não N:N). |

**Decisão:** tratar o tenant de `ConflitoDado`, `ConflitoDadoItem` e `RevisaoTecnica` como um novo
campo transversal de segurança (paralelo conceitual a `MCD-F9001..F9010`), setado pelo serviço de
reconciliação/revisão no momento da criação, **nunca** derivado de `objeto_id`/
`objeto_revisado_id`. Validação estrutural completa não é possível (mesma limitação do §3-4 para
os 6 fatos "materializados") — fica também como validação de aplicação, documentada como exceção,
não escondida.

## 10. `FontePagadora`

**Confirmado: `GLOBAL_SHARED`.** A justificativa é ainda mais forte que a de PF/PJ: uma fonte
pagadora (ex.: um banco, uma prefeitura, uma grande empresa) é, por natureza, uma entidade que
paga a **muitos** sujeitos tributários não relacionados entre si — o caso comum, não a exceção.

Diferenciação explícita, como pedido:
- **Identidade da fonte pagadora** (CNPJ/nome/tipo) — `GLOBAL_SHARED`, sem `tenant_id`.
- **Relacionamento daquela fonte com um contribuinte/tenant específico** — não precisa de
  objeto próprio; já é inteiramente capturado pelo FK `fonte_pagadora_id` dentro de `Receita`/
  `EventoIRPF`, cujo tenant (após §3-4) vem do **novo** `unidade_economica_id` dessas tabelas, não
  de `FontePagadora`.
- **Rendimentos/fatos originados dessa fonte** — já são o próprio `Receita`/`EventoIRPF`, cujo
  tenant já está resolvido independentemente.

Nenhuma mudança adicional necessária em `FontePagadora` além de manter sua classificação
`GLOBAL_SHARED` já correta. Nota lateral (não bloqueante): a deduplicação de `FontePagadora`
pelo mundo real (`GAP-CDC-1.2-004`/`GAP-MCD-CR2-005`, tipagem de `identificador_fiscal` ainda
aberta) é um gap tributário pré-existente, não uma pendência de segurança — não resolvido aqui.

## 11. Modelo conceitual resultante (conjunto mínimo)

| Novo elemento | Necessário porque | Cardinalidade | Ownership | Impacto COT | Impacto MCD | Impacto CDC | Impacto DST | Impacto ADR | Impacto Prisma futuro |
|---|---|---|---|---|---|---|---|---|---|
| `Tenant` (já proposto) | Fronteira de isolamento — sem ele nada mais nesta lista faz sentido | 1 `Tenant` : N `UnidadeEconomica` | Raiz própria | Novo `COT-OBJ-*` | Novo domínio `DOM-SEC` detalhado | Novo contrato canônico | Vocabulário de status (aberto) | Novo `ADR-D*`/`ADR-C*` (ADR-002 dedicado) | Novo model |
| `UnidadeEconomica.tenant_id` | Ancorar a raiz ao Tenant | N:1 | — | Novo `COT-REL-*` (`UnidadeEconomica → Tenant`) | Novo campo MCD | Novo campo CDC | — | Nova decisão física | Novo campo + relation |
| `unidade_economica_id` em `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal` | Resolve o problema fundamental do §3-4 — nenhum caminho relacional confiável existe hoje | N:1 (cada fato : 1 UE) | Contexto de apuração — **não** substitui o ownership tributário (PF/PJ) já existente | 5 novos `COT-REL-*` | 5 novos campos MCD | 5 novos contratos CDC | Nenhum (é FK, não enum) | 5 novas decisões físicas (FK + índice) | 5 novos campos + relations |
| `unidade_economica_id` opcional em `ResultadoCalculo`, XOR com `cenario_tributario_id` | Resolve o caso "cálculo oficial sem cenário" (§8) sem forçar obrigatoriedade indevida | N:1 opcional | Idem acima | 1 novo `COT-REL-*` + 1 nova constraint XOR (`COT-REL-NORM-*`) | 1 novo campo MCD + regra de obrigatoriedade condicional | 1 novo contrato CDC | Nenhum | 1 nova decisão física (FK + CHECK XOR, padrão `ADR-C001`/`ADR-C002`) | 1 novo campo + relation |
| Campo transversal de segurança (tenant) em `ConflitoDado`, `ConflitoDadoItem`, `RevisaoTecnica` | Resolve §9 sem reaproveitar a referência polimórfica de auditoria | N:1 (cada registro : 1 UE/Tenant) | Metadado de segurança — explicitamente **não** um relacionamento de domínio | Nenhum objeto novo | 3 novos campos MCD, tratados como metadado transversal (paralelo a `MCD-F9001..F9010`) | Contrato análogo ao já existente para metadados transversais (`CDC-SYS-001`) | Nenhum | 3 novas decisões físicas, mesmo padrão da Errata controlada nº2 | 3 novos campos |

**Nenhuma tabela de associação genérica fato↔UE foi proposta** — todas as cardinalidades
identificadas são N:1 (um fato pertence a exatamente uma UE por vez), o que uma FK direta resolve
sem necessidade de uma estrutura N:N. `Tenant`/`Cliente-Organização` permanece uma única entidade
(confirmado no adendo V1 §1, não revisitado aqui).

---

## 12. PROPOSTA DE ESCOPO DO SEC-CHANGE-REQUEST-001

*(Documentos não alterados — apenas o escopo do que precisaria mudar, para decisão futura.)*

**Objetos novos:**
- `Tenant` (COT-OBJ, domínio `DOM-SEC`).

**Campos novos:**
- `UnidadeEconomica.tenant_id` (FK, obrigatório).
- `Receita.unidade_economica_id`, `ContribuicaoPrevidenciaria.unidade_economica_id`,
  `VinculoPrevidenciario.unidade_economica_id`, `EventoIRPF.unidade_economica_id`,
  `DocumentoFiscal.unidade_economica_id` (FK — obrigatoriedade a decidir explicitamente no CR,
  não assumida aqui).
- `ResultadoCalculo.unidade_economica_id` (FK opcional, XOR com `cenario_tributario_id`).
- `ConflitoDado.<campo transversal de segurança>`, `ConflitoDadoItem.<idem>`,
  `RevisaoTecnica.<idem>` (metadado transversal, não domínio).

**Relações novas:**
- `UnidadeEconomica → Tenant` (N:1).
- `Receita/ContribuicaoPrevidenciaria/VinculoPrevidenciario/EventoIRPF/DocumentoFiscal →
  UnidadeEconomica` (N:1 cada, 5 relações).
- `ResultadoCalculo → UnidadeEconomica` (N:1 opcional, nova constraint XOR com
  `ResultadoCalculo → CenarioTributario`).

**Constraints novas (para a fase de ADR físico, não decididas aqui):**
- XOR `ResultadoCalculo.cenario_tributario_id` / `unidade_economica_id`.
- Trigger de consistência: `Receita`s associadas a um `DocumentoFiscal` via
  `ReceitaDocumentoFiscal` devem compartilhar o mesmo `unidade_economica_id`.
- Trigger proibindo associar um `ArquivoOrigem` a `DocumentoFiscal` de `unidade_economica_id`
  diferente do já fixado na primeira associação.
- Possível `CHECK`/trigger em `Vinculo`/`VinculoExtremidade` exigindo pelo menos uma extremidade
  `UnidadeEconomica` — **condicionado ao fechamento de `DST-GAP-003`**, não incluído
  incondicionalmente neste escopo.

**Decisões de obrigatoriedade explicitamente NÃO resolvidas por este documento** (para decisão
humana no próprio Change Request): se `unidade_economica_id` nos 5 fatos listados deve ser
`NOT NULL` desde já ou nullable com plano de preenchimento gradual; se a regra "todo `Vinculo`
tem pelo menos uma extremidade UE" deve de fato ser adotada quando `DST-GAP-003` fechar.

---

## Conclusão

Todos os 20 tabelas têm agora uma resposta conceitual justificada — nenhuma permanece
"indeterminada" ou "sem proposta". Os itens que restam (obrigatoriedade exata das novas FKs, a
decisão sobre `Vinculo` após `DST-GAP-003`) são decisões de **detalhe de implementação** a tomar
formalmente durante o `SEC-CHANGE-REQUEST-001`/ADR físico subsequente — não são mais bloqueios
conceituais sobre **qual é o modelo correto**, que é o objetivo desta rodada.

**MODELO DE OWNERSHIP TENANT RESOLVIDO — SEC-001 PODE SER APROVADO**

(condicionado à execução formal do `SEC-CHANGE-REQUEST-001` antes de qualquer alteração física —
nenhuma migration, schema ou banco foi tocado por este documento.)
