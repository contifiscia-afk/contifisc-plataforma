# SEC-001 — Resolução Final dos Quatro Objetos Bloqueados

**Status:** ANÁLISE FINAL — decide se `ArquivoOrigem`, `ConflitoDado`, `ConflitoDadoItem` e
`RevisaoTecnica` bloqueiam ou não a aprovação normativa do SEC-001. Não é normativo. **Não
altera** COT/MCD/CDC/DST/ADR, `schema.prisma` ou migrations. **Não cria** banco, RLS ou
autenticação.

---

## 1. `tenant_id` × `unidade_economica_id` — separação definitiva

| Conceito | Responde | Natureza |
|---|---|---|
| `tenant_id` | "A qual fronteira de isolamento/segurança este registro pertence?" | Segurança — nunca um conceito tributário. |
| `unidade_economica_id` | "A qual contexto econômico/tributário este registro se refere?" | Domínio — já existia antes de qualquer preocupação de segurança. |

Não são equivalentes nem substituíveis um pelo outro. Aplicando aos quatro objetos em análise:

| Objeto | Precisa de `tenant_id`? | Precisa de `unidade_economica_id`? |
|---|---|---|
| `ArquivoOrigem` | **Sim** (único, conhecido desde a ingestão) | **Não** (ver §2 — um arquivo pode abranger mais de uma UE) |
| `ConflitoDado` | **Sim** (contexto de segurança da operação de reconciliação) | **Não** (um conflito pode envolver mais de uma UE do mesmo tenant — ver §3) |
| `ConflitoDadoItem` | **Sim, mas derivado do pai** — não precisa de coluna própria | Não |
| `RevisaoTecnica` | **Sim** (contexto de segurança da operação de revisão) | **Não** (o objeto revisado pode ou não ter UE — ver §5) |

Em nenhum dos quatro objetos "ambos são necessários" nem "nenhum é necessário" — todos os quatro
caem na categoria "apenas tenant necessário" (três com valor próprio, um derivado do pai). Isso já
é, em si, uma simplificação real em relação à rodada anterior, que ainda cogitava a necessidade de
`unidade_economica_id` nesses quatro objetos.

## 2. `ArquivoOrigem`

**Hipótese confirmada:** `tenant_id NOT NULL` desde a ingestão; **nenhum** `unidade_economica_id`
direto (não apenas nullable — **ausente**, pela razão abaixo).

### Verificação por cenário

| Cenário | Tenant conhecido? | UE conhecida? |
|---|---|---|
| Upload manual por cliente | **Sim** — a `ContaAcesso` do cliente já está autenticada e associada a um `Tenant` (proposta original SEC-001, `ContaAcesso ↔ Tenant`) antes mesmo de o upload ocorrer | Não necessariamente — o cliente pode ter múltiplas UEs sob o mesmo tenant e o arquivo pode não indicar qual |
| Importação ERP | **Sim** — a credencial/integração (`ERPAdapter`) é configurada por tenant | Não necessariamente |
| Coleta automática | **Sim** — o job roda sob um contexto de tenant explícito (proposta original SEC-001, §26) | Não necessariamente |
| Arquivo com dados de múltiplas UEs do mesmo tenant | Sim, um único tenant | **Múltiplas UEs em um único arquivo** — este é o cenário decisivo (ver abaixo) |
| Arquivo sem UE ainda identificada | Sim | Não |
| Arquivo inválido | Sim (a tentativa de upload ainda ocorreu sob um tenant) | Não aplicável |
| Reprocessamento | Sim (inalterado) | Pode gerar novas atribuições de UE ao longo do tempo, a partir do mesmo arquivo |
| Deduplicação física de bytes | Sim (por registro lógico, nunca pelos bytes — adendo anterior, inalterado) | Não aplicável |

**Achado decisivo:** o cenário "arquivo contendo dados de múltiplas UEs do mesmo tenant" (ex.: um
extrato consolidado de holding cobrindo várias subsidiárias) prova que `unidade_economica_id`
como **FK direta única** em `ArquivoOrigem` seria **conceitualmente errado** — uma coluna FK só
pode apontar para uma UE, mas o arquivo pode legitimamente pertencer a várias. Forçar uma UE
única aqui seria inventar uma restrição de domínio que não existe (exatamente o tipo de erro que
esta rodada pede para evitar).

**Cardinalidade correta:**

```
ArquivoOrigem N:1 Tenant   (tenant_id NOT NULL — sempre exatamente um)
ArquivoOrigem sem UE direta — a granularidade de UE só se aplica na camada Canonical
  (DocumentoFiscal.unidade_economica_id, já resolvido em rodada anterior), nunca na camada RAW
```

A resolução por UE acontece **depois**, quando o arquivo é decomposto em um ou mais
`DocumentoFiscal` (cada um com sua própria UE, via `DocumentoFiscalArquivoOrigem`) — a mesma
evidência RAW pode originar documentos canônicos de UEs diferentes (do mesmo tenant), sem que
isso exija nenhuma FK múltipla ou tabela de associação nova em `ArquivoOrigem`. Uma associação
posterior `ArquivoOrigem ↔ UnidadeEconomica` (N:N) permanece uma opção **futura e opcional** (ex.:
para telas de triagem que queiram marcar "este arquivo é relevante às UEs X e Y" antes de gerar
documentos canônicos) — não necessária para resolver a baseline de segurança agora.

**Classificação: `TENANT_ID_MATERIALIZADO`** — valor direto, obrigatório, sem FK de domínio que o
sustente (mesma natureza dos outros três objetos desta análise, ver §8).

## 3. `ConflitoDado`

**De onde vem o tenant na criação:** do **contexto operacional do serviço de reconciliação** que
cria o registro — esse serviço já buscou e comparou dados de um tenant específico antes de
detectar a divergência; carimbar esse tenant no momento da criação não introduz nenhuma inferência
nova, apenas registra um fato que o processo já conhece.

| Opção | Avaliação |
|---|---|
| A. Derivar do objeto envolvido | **Rejeitada** — exigiria resolver `objeto_id`/`tipo_objeto` (sem FK) para achar o tenant, exatamente o uso proibido da referência polimórfica como mecanismo de isolamento. |
| **B. `tenant_id` como contexto de segurança da operação** | **Recomendada.** Mesmo mecanismo do `ArquivoOrigem` (§2): valor carimbado pelo processo que cria o registro, não derivado de nenhuma FK. |
| C. Associação explícita com UE | Rejeitada pela mesma razão do `ArquivoOrigem` — um conflito pode envolver itens de mais de uma UE do mesmo tenant (ex.: reconciliação de uma transação intercompany entre duas UEs do mesmo cliente); uma FK única para UE seria conceitualmente errada. |
| D. Combinação tenant + UE opcional | Desnecessária — nenhum requisito de negócio hoje exige saber "qual UE" no nível do `ConflitoDado` para fins de segurança; se um relatório futuro precisar disso, pode ser obtido pela aplicação a partir dos itens, sem exigir uma coluna na tabela pai. |

**`ConflitoDado` pode envolver objetos de tenants diferentes?** **Não, por padrão de segurança**,
conforme a resposta preferencial indicada. Não há requisito de negócio documentado que exija o
contrário — reconciliar dados de dois clientes não relacionados entre si não é uma função legítima
do domínio de auditoria da CONTIFISC.

**Invariante proposta (não implementada agora):** *"Todo `ConflitoDadoItem` de um mesmo
`ConflitoDado` deve pertencer ao mesmo tenant do seu `ConflitoDado` pai — nenhum `ConflitoDado`
pode agregar itens de tenants diferentes."* Limite honesto: como `objeto_id` é polimórfico sem FK,
o PostgreSQL **não pode** verificar declarativamente que o objeto real referenciado pertence ao
tenant declarado — essa parte da invariante permanece, necessariamente, uma responsabilidade do
serviço de domínio que cria os itens (o mesmo limite que o próprio ADR-001 já reconhece para toda
a exceção polimórfica de reconciliação). O que **é** verificável estruturalmente — e deve ser —
é que todo `ConflitoDadoItem` aponte para o `tenant_id` correto do seu `ConflitoDado` pai (ver §4).

**Classificação: `TENANT_ID_MATERIALIZADO`.**

## 4. `ConflitoDadoItem`

`conflito_dado_item.conflito_dado_id` já é uma FK real e obrigatória (`NOT NULL`) para
`conflito_dado.id` — diferente do ponteiro polimórfico `objeto_id`, esta é uma relação
estruturalmente sólida e unívoca (todo item pertence a exatamente um conflito pai, sempre).

| Critério | Avaliação |
|---|---|
| RLS | `EXISTS (SELECT 1 FROM conflito_dado cd WHERE cd.id = conflito_dado_item.conflito_dado_id AND cd.tenant_id = <tenant atual>)` — subquery de 1 hop sobre uma FK real, sem ambiguidade. |
| Performance | Boa — busca indexada por `conflito_dado_id` (já é FK, já indexável). |
| Integridade | Garantida pela própria FK já existente — não há como um `ConflitoDadoItem` existir sem um `ConflitoDado` pai. |
| Consulta direta da tabela | RLS aplica-se independentemente de como a query é escrita — não há risco adicional por acesso direto. |
| Risco de acesso sem join | Nenhum — RLS de banco não depende de a aplicação lembrar de fazer join algum. |
| Capacidade do PostgreSQL garantir consistência | Total, e de graça — não existe coluna redundante para dessincronizar, porque não há coluna nenhuma a materializar aqui. |

Materializar um `tenant_id` próprio em `ConflitoDadoItem` seria duplicação sem nenhum benefício —
ao contrário de `PessoaFisica`/`PessoaJuridica` (onde a "derivação" seria ambígua, múltipla e
cara), aqui a relação com o pai é única, obrigatória e barata de consultar.

**Classificação: `TENANT_DERIVED_FROM_PARENT`.**

## 5. `RevisaoTecnica`

Análise por tipo de revisão:

| Cenário revisado | UE do objeto revisado é conhecida? | Tenant do objeto revisado é conhecido? |
|---|---|---|
| Revisão de classificação EqHop | Sim, via `Receita.unidade_economica_id` (uma vez resolvido) — mas só acessível seguindo `objeto_revisado_id`, proibido | Idem |
| Revisão de `Receita` | Idem | Idem |
| Revisão de `DocumentoFiscal` | Idem | Idem |
| Revisão de `ConflitoDado` | O próprio `ConflitoDado` não tem UE própria (§3) — só tenant | Sim, via `ConflitoDado.tenant_id`, mas só acessível seguindo o ponteiro polimórfico, proibido |
| Eventual revisão de objeto global (ex.: uma `PessoaFisica`) | Não aplicável — objeto `GLOBAL_SHARED` | **Indeterminado** — não descartado por inferência (ver nota abaixo) |

Como em nenhum caso é permitido seguir `objeto_revisado_id`/`tipo_objeto_revisado` para obter
tenant/UE, a resposta é uniforme: **`RevisaoTecnica` recebe `tenant_id` (carimbado no momento da
criação pelo processo de revisão) e não recebe `unidade_economica_id`** — mesma lógica de
`ConflitoDado`, pela mesma razão (o objeto revisado pode, em tese, não ter uma única UE — o caso
de `ConflitoDado` já demonstra isso — e forçar uma FK de UE aqui herdaria a mesma inconsistência).

**De onde vem o tenant na criação:** do contexto operacional de quem realiza a revisão — a
`ContaAcesso` do revisor já está autenticada sob um `Tenant` específico (proposta original
SEC-001) no momento em que a revisão é registrada; esse é o valor carimbado, nunca inferido do
objeto revisado.

**Nota não resolvida (não descartada por inferência):** se algum dia existir uma revisão técnica
sobre um objeto genuinamente `GLOBAL_SHARED` (ex.: confirmar/corrigir dados cadastrais de uma
`PessoaFisica` isolada, sem relação com um tenant específico), o `tenant_id` carimbado nesse caso
representaria apenas "quem operacionalmente fez a revisão", não "a quem os dados pertencem" — uma
sutileza que só precisa ser resolvida se e quando esse caso de uso for confirmado. Não bloqueia a
baseline atual (não há hoje nenhum fluxo documentado de revisão sobre objetos `GLOBAL_SHARED`).

**Classificação: `TENANT_ID_MATERIALIZADO`.**

## 6. Regra de consistência para objetos com `tenant_id` **e** `unidade_economica_id`

Nenhum dos quatro objetos desta análise acabou precisando dos dois campos simultaneamente — mas a
regra abaixo permanece necessária para qualquer tabela das outras 16 que venha a adotar um
`tenant_id` materializado redundante por performance (decisão diferida, item 10).

| Opção | Como funciona | Força da garantia |
|---|---|---|
| **FK composta** (recomendada) | `ALTER TABLE <fato> ADD CONSTRAINT ... FOREIGN KEY (unidade_economica_id, tenant_id) REFERENCES unidade_economica (id, tenant_id)` — exige um `UNIQUE(id, tenant_id)` em `unidade_economica` (trivial, já que `id` sozinho já é único) | **Máxima** — puramente declarativa; um par incorreto simplesmente **não existe** na tabela referenciada, então o INSERT/UPDATE falha por violação de FK (23503), sem nenhum código customizado. |
| Trigger (`BEFORE INSERT/UPDATE`, validando) | Consulta `unidade_economica.tenant_id` e rejeita se o valor enviado não bater | Forte, mas exige PL/pgSQL customizado por tabela. |
| Trigger (derivando/sobrescrevendo) | Ignora o valor enviado pela aplicação e sempre recalcula `NEW.tenant_id` a partir da FK | Forte, mas ainda customizado; a aplicação nem precisaria enviar o campo. |
| Constraint trigger (`DEFERRABLE`) | Mesma lógica de trigger, mas adiada para o fim da transação | Desnecessária aqui — não há estado transitório multi-linha como em `ADR-C005`; a checagem é sempre de uma linha contra uma FK, imediata. |
| Coluna gerada (`GENERATED ALWAYS AS`) | Rejeitada — PostgreSQL não permite coluna gerada calculada a partir de outra tabela. |

**Recomendação: FK composta** sempre que ambos os campos coexistirem — é a solução mais forte
("não aceitar apenas validação na aplicação" fica satisfeito por construção, não por checagem) e
a mais simples de manter (nenhum trigger customizado por tabela). Isso substitui e melhora a
proposta de trigger-de-derivação sugerida na rodada anterior.

## 7. RLS conceitual dos quatro objetos

| Objeto | Expressão conceitual da policy |
|---|---|
| `ArquivoOrigem` | Acesso direto por tenant: `USING (tenant_id = <tenant da sessão>)` |
| `ConflitoDado` | Acesso direto por tenant: `USING (tenant_id = <tenant da sessão>)` |
| `ConflitoDadoItem` | Acesso derivado por pai: `USING (EXISTS (SELECT 1 FROM conflito_dado cd WHERE cd.id = conflito_dado_item.conflito_dado_id AND cd.tenant_id = <tenant da sessão>))` |
| `RevisaoTecnica` | Acesso direto por tenant: `USING (tenant_id = <tenant da sessão>)` |

Nenhum dos quatro precisa de policy combinada (tenant + UE) — simplificação direta do resultado
do §1. Nenhum SQL de produção é escrito aqui — apenas a expressão conceitual pedida.

## 8. Novo campo transversal — atualização do candidato

Confirma-se a proposta da rodada anterior, **ampliada**: o mesmo campo transversal de segurança
serve agora a **quatro** objetos (não três) — `ArquivoOrigem`, `ConflitoDado`, `ConflitoDadoItem`
(por derivação, não por coluna própria) e `RevisaoTecnica` — todos compartilhando a mesma
característica estrutural: nenhum tem uma FK de domínio confiável da qual derivar tenant, e todos
recebem o valor carimbado pelo processo/sessão que os cria.

- **ID:** `MCD-F9011` continua sendo o **candidato sugerido** — **não atribuído
  definitivamente**, sujeito à aprovação formal do `SEC-CHANGE-REQUEST-001`. Nenhum ID existente
  (`F9001..F9010`) é reutilizado.
- Demais aspectos (significado, requisito, impacto MCD/CDC/COT/DST/ADR) permanecem os já
  descritos na auditoria anterior, apenas com o escopo de aplicação estendido a 3 objetos com
  coluna própria (`ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`) — `ConflitoDadoItem` não
  recebe o campo (deriva do pai, §4).

## 9. Matriz final 20/20

| # | Tabela | Classificação | Nota |
|---|---|---|---|
| 1 | `unidade_economica` | `TENANT_ID_RAIZ` | Ancora a FK real para `Tenant`. |
| 2 | `pessoa_fisica` | `SEM_TENANT_ID` | Global, RLS por união de fatos. |
| 3 | `pessoa_juridica` | `SEM_TENANT_ID` | Idem. |
| 4 | `fonte_pagadora` | `SEM_TENANT_ID` | Idem. |
| 5 | `vinculo` | `TENANT_DERIVADO_POR_RLS` | Exceção residual: sem UE em nenhuma extremidade, sem tenant (depende de `DST-GAP-003`). |
| 6 | `vinculo_extremidade` | `TENANT_DERIVADO_POR_RLS` | Mesma exceção. |
| 7 | `receita` | `TENANT_DERIVADO_POR_RLS` | Via `unidade_economica_id` próprio (`NOT NULL`). |
| 8 | `contribuicao_previdenciaria` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 9 | `vinculo_previdenciario` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 10 | `evento_irpf` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 11 | `documento_fiscal` | `TENANT_DERIVADO_POR_RLS` | Via `unidade_economica_id` próprio (`NOT NULL`). |
| 12 | `arquivo_origem` | **`TENANT_ID_MATERIALIZADO`** | **Resolvido nesta rodada.** `tenant_id NOT NULL`, sem UE direta (§2). |
| 13 | `receita_documento_fiscal` | `TENANT_DERIVADO_POR_RLS` | Via `receita`/`documento_fiscal`. |
| 14 | `documento_fiscal_arquivo_origem` | `TENANT_DERIVADO_POR_RLS` | Via `documento_fiscal`. |
| 15 | `classificacao_equiparacao_hospitalar` | `TENANT_DERIVADO_POR_RLS` | Via `receita`. |
| 16 | `cenario_tributario` | `TENANT_DERIVADO_POR_RLS` | Via `unidade_economica_id` próprio, já `NOT NULL` desde a V1. |
| 17 | `resultado_calculo` | `TENANT_DERIVADO_POR_RLS` | Via `unidade_economica_id` próprio (sempre presente). |
| 18 | `conflito_dado` | **`TENANT_ID_MATERIALIZADO`** | **Resolvido nesta rodada.** `tenant_id` carimbado pelo serviço de reconciliação (§3). |
| 19 | `conflito_dado_item` | **`TENANT_DERIVADO_DO_PAI`** | **Resolvido nesta rodada.** Via `conflito_dado_id` (FK real, `NOT NULL`) (§4). |
| 20 | `revisao_tecnica` | **`TENANT_ID_MATERIALIZADO`** | **Resolvido nesta rodada.** `tenant_id` carimbado pelo processo de revisão (§5). |

**Soma:** `TENANT_ID_RAIZ`=1 · `SEM_TENANT_ID`=3 · `TENANT_DERIVADO_POR_RLS`=12 ·
`TENANT_ID_MATERIALIZADO`=3 · `TENANT_DERIVADO_DO_PAI`=1 · `BLOQUEADO`=**0**.
`1+3+12+3+1+0 = 20`. ✓ **Nenhuma tabela permanece bloqueada.**

## 10. Decisões diferidas — reclassificadas

| # | Decisão | Classificação | Impacto |
|---|---|---|---|
| 1 | Formalização exata do campo transversal de segurança (ID definitivo `MCD-F9011` ou outro, contrato CDC) | **Dependente de documento futuro** (`SEC-CHANGE-REQUEST-001`) | Não bloqueia a aprovação **arquitetural** — bloqueia apenas a implementação física até o CR ser aprovado. |
| 2 | Fluxo RAW→Canonical de `ArquivoOrigem` (quando/como um `DocumentoFiscal` é gerado a partir da evidência) | **Não bloqueante** | Reduzido de escopo nesta rodada: como `ArquivoOrigem` não carrega mais UE, esta decisão virou uma questão de desenho de pipeline/ETL, não de segurança. |
| 3 | Cenário D de `ResultadoCalculo` (resultado técnico/global sem UE) | **Não bloqueante** | Se confirmado no futuro, exige um Change Request para tornar `unidade_economica_id` opcional novamente — não compromete a baseline atual, que assume (sem inventar) que esse caso não existe hoje. |
| 4 | `Vinculo` sem nenhuma extremidade UE | **Dependente de documento futuro** (`DST-GAP-003`) | Ambas as ramificações já identificadas são seguras; a decisão final só ajusta qual delas se aplica, não introduz risco de segurança em nenhum dos dois casos. |
| 5 | Materializar `tenant_id` nas 12 tabelas `TENANT_DERIVADO_POR_RLS` (performance) | **Não bloqueante** | Puramente uma otimização; correção e segurança já garantidas pela derivação relacional sem a materialização. |

**Nenhuma das cinco é bloqueante para a aprovação normativa da arquitetura.**

---

## 11. Gate final

Os quatro objetos foram resolvidos **sem inventar semântica de domínio**: nenhum vocabulário
DST foi fechado por inferência, nenhuma regra tributária nova foi criada, nenhuma UE foi forçada
onde a UE não é unívoca (`ArquivoOrigem`, `ConflitoDado`). A resolução reaproveita exclusivamente
(a) o padrão arquitetural de campo transversal já precedente no projeto (aplicado a um novo campo
com ID próprio, não reaproveitando `F9001..F9010`), e (b) uma FK real já existente
(`conflito_dado_item.conflito_dado_id`) para o único caso de derivação por pai. A matriz das 20
tabelas fecha sem nenhum `BLOQUEADO`. As cinco decisões diferidas remanescentes são todas
não-bloqueantes ou dependentes de documentos futuros que não impedem a aprovação desta
arquitetura — apenas condicionam sua implementação física subsequente.

**SEC-001 PRONTO PARA APROVAÇÃO NORMATIVA**
