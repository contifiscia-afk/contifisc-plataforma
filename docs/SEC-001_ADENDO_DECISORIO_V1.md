# SEC-001 — Adendo Decisório V1

**Status:** ADENDO À PROPOSTA — resolve pontos explicitamente deixados em aberto por
`SEC-001_PROPOSTA_ARQUITETURAL_V1.md`. Ainda não é normativo (não vira ADR/MCD/COT/CDC/DST).
**Não altera** COT/MCD/CDC/DST/ADR, `schema.prisma` ou migrations. **Não cria** banco, RLS ou
autenticação. Este adendo **corrige e substitui** parte da análise da proposta original onde
uma revisão mais profunda revelou que a classificação inicial estava imprecisa — a correção é
declarada explicitamente em cada ponto, não escondida.

---

## 1. Tenant × Cliente/Organização × UnidadeEconomica

**Reavaliação:** a proposta original já não criava três entidades — tratava "Tenant" como
sinônimo de "Cliente/Organização". Este adendo torna essa decisão **explícita e definitiva**,
em vez de deixá-la implícita.

**Hipótese adotada:** `Tenant` = fronteira técnica de isolamento e propriedade de dados.
`UnidadeEconomica` = contexto econômico/tributário (inalterado). Um `Tenant` agrega 1..N
`UnidadeEconomica`.

**Teste da necessidade de um `Cliente`/`Organização` separado de `Tenant`:** a única justificativa
levantada na proposta original — "um contrato comercial agrupa várias UEs" — é exatamente o que
`Tenant` (agregador de N UEs) já resolve sozinho. Para uma entidade `Cliente`/`Organização`
**distinta** de `Tenant` ser necessária, precisaria existir um cenário real onde:
(a) um único `Tenant` (fronteira de isolamento técnico) devesse pertencer a múltiplas relações
comerciais distintas, ou (b) uma única relação comercial devesse abranger múltiplos `Tenant`s
com isolamento técnico rígido entre si (ex.: divisões de um mesmo grupo com exigência de
"muralha chinesa" entre elas, faturadas em conjunto).

Nenhum documento canônico vigente (CAF-001, MCD-001, COT-001) menciona faturamento,
multiplicidade contratual, ou necessidade de isolamento rígido intra-cliente. O caso de uso
declarado (CONTIFISC atende clientes PME/profissionais liberais) não apresenta esse requisito
hoje.

**Classificação: `Cliente/Organização` como entidade separada de `Tenant` = `REDUNDANTE_NESTA_FASE`.**

Decisão: **uma única entidade, `Tenant`**, definida estritamente como fronteira técnica de
isolamento/propriedade — sem atributos de CRM/faturamento/contrato (nome e status apenas, como já
proposto). Se um requisito real de faturamento/CRM surgir no futuro (ex.: um `Cliente` com
múltiplos `Tenant`s isolados), ele pode ser modelado **então**, como uma camada acima de `Tenant`
— não antecipado agora.

## 2. Ownership canônico × chave física de isolamento × autorização de acesso

Três eixos que **não** colapsam na mesma relação:

| Eixo | Pergunta que responde | Mecanismo |
|---|---|---|
| **Ownership canônico** | "De quem é este fato, no domínio tributário?" | FK de domínio já existente (ex.: `Receita.pessoa_fisica_id`/`pessoa_juridica_id`, XOR `ADR-C001`) — **não muda**, é uma decisão do MCD/CDC, não de segurança. |
| **Chave física de isolamento** | "A qual `Tenant` esta linha pertence, para fins de partição/RLS?" | `tenant_id` — materializado em algumas tabelas, derivado por relacionamento em outras (matriz §3 abaixo). **Não é o mesmo FK do ownership** sempre que o dono canônico (PF/PJ) não tem um único tenant. |
| **Autorização de acesso** | "Esta `ContaAcesso`, agora, pode ler/escrever esta linha?" | Avaliado em tempo de requisição contra `ContaAcesso ↔ Tenant`/`ContaAcesso ↔ UnidadeEconomica` + `PapelAcesso`/`Permissao` — **nunca** armazenado na própria linha. |

**Consequência prática:** o achado central deste adendo (§3/§5) é que, para várias tabelas de
fato, o **ownership canônico** (PF/PJ) e a **chave de isolamento** (tenant) precisam de fontes
diferentes — assumir que "seguir o FK de ownership" resolve o tenant é exatamente o erro que a
proposta original cometeu de forma implícita e que este adendo corrige.

## 3 e 5. Matriz refinada das 20 tabelas

**Correção declarada:** a proposta original (`SEC-001_PROPOSTA_ARQUITETURAL_V1.md`, §20-25)
classificou genericamente "fatos ligados a UE/PF/PJ por FK" como um bloco homogêneo
`TENANT_DERIVED`. Uma análise dos caminhos relacionais reais no `schema.prisma` mostra que isso
está **errado para várias tabelas**: `Receita`, `ContribuicaoPrevidenciaria` e `EventoIRPF` ligam
apenas a `PessoaFisica`/`PessoaJuridica` (que são `GLOBAL_SHARED`, sem tenant próprio) — **não há
FK direto nem caminho relacional curto e unívoco até `UnidadeEconomica`**. O único caminho
possível passaria por `Vinculo`/`VinculoExtremidade`, que é opcional (pode não existir), não
unívoco (a mesma PF pode ter `Vinculo` com mais de uma UE) e semanticamente ambíguo (nem todo
`Vinculo` tem uma UE como uma de suas duas extremidades — `COT-REL-NORM-001` exige exatamente
duas extremidades, mas não exige que pelo menos uma seja `UnidadeEconomica`). Esta é uma correção
material da proposta original, não um refinamento cosmético.

| Tabela | Derivação de Tenant | Joins (nº/caminho) | Unívoco? | Compartilhável entre tenants? | Risco de vazamento | Adequação RLS | Impacto performance | `tenant_id` físico? | Classificação |
|---|---|---|---|---|---|---|---|---|---|
| `unidade_economica` | Própria (FK direta a `Tenant`) | 0 | Sim | Não | Baixo | Ótima (coluna direta) | Nenhum | **Sim** | `TENANT_ROOT` |
| `pessoa_fisica` | N/A — não pertence a um tenant único | — | N/A | **Sim, por desenho** (§4) | Médio (mitigado por RLS de visibilidade relacional, não de posse) | Requer policy `EXISTS` multi-caminho (cara) | Alto se mal indexado | **Não** | `GLOBAL_SHARED` |
| `pessoa_juridica` | N/A | — | N/A | **Sim, por desenho** | Médio (idem) | Idem | Idem | **Não** | `GLOBAL_SHARED` |
| `fonte_pagadora` | N/A | — | N/A | **Sim, por desenho** (mesmo argumento de PF/PJ: um pagador pode aparecer em receitas de tenants não relacionados) | Médio | Idem | Idem | **Não** | `GLOBAL_SHARED` |
| `vinculo` / `vinculo_extremidade` | Condicional: se **uma das duas extremidades** do `Vinculo` é `UnidadeEconomica`, deriva por 1 hop a partir dela; **se nenhuma extremidade é UE** (`Vinculo` só entre PFs/PJs), **não há tenant derivável** | 1 hop (caso com UE) / indeterminado (caso sem UE) | Condicionalmente | Vínculo PF-PF pode, em tese, existir sem UE — caso residual sem tenant | Baixo no caso com UE; **indeterminado** no caso sem UE | Boa no caso com UE; inviável no caso sem UE | Baixo | **Não** (deriva quando possível) | `TENANT_DERIVED` **com exceção documentada** — caso `Vinculo` sem UE é um gap a resolver antes da implementação física |
| `receita` | **Corrigido nesta revisão.** Não há caminho curto/unívoco via PF/PJ. | Indeterminado via relação; precisa de fonte própria | **Não** | Indiretamente sim (herdaria a ambiguidade do dono PF/PJ) | **Alto** sem materialização | Inviável só por join | — | **Sim (materializado)** | `TENANT_MATERIALIZED_FOR_SECURITY` |
| `contribuicao_previdenciaria` | Mesma correção — só liga a `PessoaFisica`/`VinculoPrevidenciario` (que também só liga a PF) | Indeterminado | Não | Sim (idem) | Alto sem materialização | Inviável só por join | — | **Sim (materializado)** | `TENANT_MATERIALIZED_FOR_SECURITY` |
| `vinculo_previdenciario` | Mesma correção — só liga a `PessoaFisica` | Indeterminado | Não | Sim | Alto sem materialização | Inviável só por join | — | **Sim (materializado)** | `TENANT_MATERIALIZED_FOR_SECURITY` |
| `evento_irpf` | Mesma correção — liga a `PessoaFisica` (+ `FontePagadora`, também `GLOBAL_SHARED`) | Indeterminado | Não | Sim | Alto sem materialização | Inviável só por join | — | **Sim (materializado)** | `TENANT_MATERIALIZED_FOR_SECURITY` |
| `documento_fiscal` | Depende de `Receita` (via N:N `receita_documento_fiscal`), que por sua vez precisa de materialização (linha acima) | 2 hops via Receita, mas Receita não deriva sozinha | Não, sem materialização | Sim (documento pode, em tese, associar-se a receitas de mais de uma Receita/tenant) | Alto sem materialização | Inviável só por join | — | **Sim (materializado)**, com trigger validando consistência contra as `Receita` associadas | `TENANT_MATERIALIZED_FOR_SECURITY` |
| `receita_documento_fiscal` | Uma vez `receita`/`documento_fiscal` materializados, deriva de qualquer um dos dois (ambos devem bater) | 1 hop | Sim (após materialização dos pais) | Não (é uma associação, não um dado mestre) | Baixo, com trigger de consistência | Boa (subquery de 1 hop simples) | Baixo | Não (deriva) | `TENANT_DERIVED` |
| `arquivo_origem` | Depende de `documento_fiscal` (via N:N `documento_fiscal_arquivo_origem`) | 2 hops, múltiplos se associado a mais de um documento | Não, sem materialização | Sim, em tese (evidência RAW reaproveitada entre documentos de tenants diferentes — indesejável, deve ser proibido por trigger) | Alto sem materialização | Inviável só por join | — | **Sim (materializado)**, com trigger proibindo associação a `documento_fiscal` de outro tenant | `TENANT_MATERIALIZED_FOR_SECURITY` |
| `documento_fiscal_arquivo_origem` | Deriva de `documento_fiscal` (uma vez materializado) | 1 hop | Sim (após materialização do pai) | Não | Baixo, com trigger de consistência contra `arquivo_origem` | Boa | Baixo | Não (deriva) | `TENANT_DERIVED` |
| `classificacao_equiparacao_hospitalar` | Deriva de `receita_id` (obrigatório, `NOT NULL`) uma vez `Receita` materializada | 1 hop | Sim | Não | Baixo | Boa (subquery de 1 hop) | Baixo | Não (deriva) | `TENANT_DERIVED` |
| `cenario_tributario` | FK direta e obrigatória a `unidade_economica_id` | 1 hop, univocal | Sim | Não | Baixo | Ótima | Baixo | Opcional (pode materializar por performance, mas deriva com segurança sem materializar) | `TENANT_DERIVED` |
| `resultado_calculo` | Via `cenario_tributario_id` — **mas esse campo é nullable** | 2 hops quando presente; **indeterminado quando nulo** | Condicional | Não | Baixo quando `cenario_tributario_id` presente; **indeterminado** quando nulo | Boa condicionalmente | Baixo | Não, **exceto** se a regra de negócio permitir `ResultadoCalculo` sem `CenarioTributario` — nesse caso vira gap | `TENANT_DERIVED` **com exceção documentada** — ver "decisões bloqueadas" |
| `conflito_dado` | Via `ConflitoDadoItem.objeto_id` (polimórfico, sem FK) | Indeterminado — depende de resolver um ponteiro sem tipo garantido | Não | Estruturalmente possível (nada impede um conflito referenciar objetos de tenants diferentes — um erro grave se acontecer) | **Alto** | Inviável (não há FK para RLS usar) | — | Requer decisão própria (ver abaixo) | `DECISION_BLOCKED` |
| `conflito_dado_item` | Mesma razão do pai | Indeterminado | Não | Sim (mesmo risco) | **Alto** | Inviável | — | Requer decisão própria | `DECISION_BLOCKED` |
| `revisao_tecnica` | Via `objeto_revisado_id` (polimórfico, sem FK) | Indeterminado | Não | Sim (mesmo risco) | **Alto** | Inviável | — | Requer decisão própria | `DECISION_BLOCKED` |

### Como impedir divergência entre `tenant_id` materializado e o ownership canônico

Para as tabelas marcadas `TENANT_MATERIALIZED_FOR_SECURITY` (`receita`,
`contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`,
`arquivo_origem`): como o dono canônico (PF/PJ) não tem tenant próprio, **não existe uma FK de
origem contra a qual um `CHECK`/trigger simples possa validar automaticamente o valor correto** —
diferente do padrão já usado nesta migration para outras constraints (ex.: XOR, vocabulário
fechado), aqui não há uma "fonte da verdade" estrutural para derivar o valor certo por
consulta. Isso significa:

- O valor de `tenant_id` nessas tabelas precisa ser **determinado e validado no momento da
  criação do fato**, pela camada de aplicação/serviço de domínio que sabe em nome de qual
  `UnidadeEconomica`/`Tenant` aquele fato está sendo registrado (informação que hoje **não está
  modelada em lugar nenhum do MCD/COT** — é um gap de modelagem pré-existente, exposto por esta
  análise de segurança, não introduzido por ela).
- O único controle estrutural (banco) possível é **negativo**, não positivo: um trigger pode
  IMPEDIR que um `UPDATE` mude `tenant_id` depois de criado (imutabilidade), e pode impedir
  inconsistência **entre tabelas relacionadas que já têm o valor** (ex.: `documento_fiscal`
  associado a receitas de `tenant_id` diferentes → rejeitar), mas não pode **inferir** o valor
  correto na ausência de uma FK confiável.
- **Recomendação:** tratar isto como uma dependência de um futuro Change Request de MCD/COT que
  adicione um vínculo explícito (direto ou via um novo objeto de suporte) entre estes fatos e a
  `UnidadeEconomica` de contexto — não apenas o dono tributário PF/PJ. Até essa decisão ser
  tomada, o `tenant_id` materializado nessas tabelas é **validado apenas pela aplicação no
  momento da escrita**, uma camada de defesa mais fraca do que o padrão "CHECK/trigger sempre
  correto" já estabelecido no restante desta migration — uma exceção documentada, não escondida.

### Vínculo sem UnidadeEconomica e ResultadoCalculo sem CenarioTributario

Dois casos residuais identificados nesta matriz que **bloqueiam** uma resposta 100% estrutural:
um `Vinculo` cujas duas extremidades são ambas PF/PJ (nenhuma UE) não tem nenhum tenant
derivável; um `ResultadoCalculo` com `cenario_tributario_id` nulo, idem. Nenhum dos dois é
resolvido por este adendo — ver "decisões ainda bloqueadas".

## 4. PF/PJ compartilhadas — cenário concreto e tratamento por RLS

**Cenário:** Dra. Ana (`PessoaFisica`, CPF único, `pessoa_fisica.id = X`) é sócia da Clínica Alfa
(`UnidadeEconomica A`, pertence ao `Tenant 1`, cliente "Alfa") e, **separadamente**, presta
consultoria autônoma faturada através da Clínica Beta (`UnidadeEconomica B`, pertence ao
`Tenant 2`, cliente "Beta") — dois clientes da CONTIFISC sem nenhuma relação entre si.

- **Sem duplicação de CPF:** existe **uma única linha** `pessoa_fisica.id = X` no banco inteiro —
  nunca duplicada por tenant. Isso só é possível porque `pessoa_fisica` é `GLOBAL_SHARED`
  (§3) — se tivesse `tenant_id` direto (Alternativa B da proposta original), seria necessário
  duplicar a linha por tenant, quebrando a unicidade canônica de CPF que o MCD-001 já garante.
- **Sem vazamento entre tenants:** os **fatos** ligados a cada relação (`Vinculo` com a Clínica
  Alfa, `Receita` faturada pela Beta) carregam **cada um o seu próprio tenant** (derivado ou
  materializado, conforme a matriz §3) — o `Tenant 1` nunca vê os fatos do `Tenant 2` e
  vice-versa, mesmo que ambos apontem para o mesmo `pessoa_fisica.id`.
- **Sem autorização implícita ao outro tenant:** a visibilidade da **linha de perfil**
  `pessoa_fisica` (CPF, nome, dados profissionais — não financeiros) para cada tenant é
  justificada **independentemente**, por uma policy RLS baseada em existência de pelo menos um
  fato/vínculo daquele tenant específico apontando para aquele `pessoa_fisica.id` — nunca por
  "o Tenant 1 pode ver este CPF, logo o Tenant 2 também pode" (não há transitividade).

**Tratamento por RLS:** a policy sobre `pessoa_fisica` não pode ser uma comparação de coluna — deve
ser uma **união de todos os caminhos de fato que legitimamente relacionam aquela PF ao tenant
corrente**, por exemplo (pseudo-SQL ilustrativo, não uma proposta de implementação):

```
USING (
  EXISTS (SELECT 1 FROM vinculo_extremidade ve ... JOIN unidade_economica ue ... WHERE ve.pessoa_fisica_id = pessoa_fisica.id AND ue.tenant_id = current_tenant())
  OR EXISTS (SELECT 1 FROM receita r WHERE r.pessoa_fisica_id = pessoa_fisica.id AND r.tenant_id = current_tenant())
  OR EXISTS (SELECT 1 FROM contribuicao_previdenciaria cp WHERE cp.pessoa_fisica_id = pessoa_fisica.id AND cp.tenant_id = current_tenant())
  OR EXISTS (SELECT 1 FROM evento_irpf ei WHERE ei.pessoa_fisica_id = pessoa_fisica.id AND ei.tenant_id = current_tenant())
)
```

Isso é estruturalmente correto, mas caro (múltiplos `EXISTS`) e **frágil por omissão** — cada
nova tabela que referenciar `pessoa_fisica_id` no futuro precisa ser adicionada a esta policy
manualmente, ou o acesso a essa PF fica incompleto (falso negativo, não vazamento — mas quebra
funcional) ou, pior, uma tabela nova sem entrada na policy poderia mascarar um vazamento se a
lógica de "negar por padrão" não for respeitada à risca. Fica registrado como risco de manutenção
relevante para a fase de implementação física.

## 6. RLS: tenant por join × `tenant_id` materializado

| Critério | RLS com tenant derivado por joins | RLS com `tenant_id` materializado seletivamente |
|---|---|---|
| Complexidade das policies | Alta — `EXISTS` multi-tabela, potencialmente várias por policy (ver §4) | Baixa — `tenant_id = current_setting(...)`, uniforme |
| Performance | Pior em geral — subqueries correlacionadas por linha avaliada | Melhor — comparação direta, indexável |
| Índices | Múltiplos índices de suporte por caminho de `EXISTS` | Um índice composto `(tenant_id, ...)` por tabela |
| Risco de recursão | Baixo-moderado — policies que consultam tabelas que também têm RLS ativa empilham avaliação (não é recursão infinita, mas o plano de execução cresce) | Nenhum (sem subquery para outra tabela com RLS) |
| Manutenção | Cada nova tabela referenciando o alvo exige atualizar a policy manualmente | Risco trocado: divergência de coluna redundante em vez de policy desatualizada |
| Jobs | Funcionam, mas dependem da mesma cadeia de `EXISTS`, mais lento | Mesmo princípio de contexto de conexão, mais rápido |
| Prisma | Não participa da decisão em si — só precisa garantir o contexto de conexão certo | Idem |
| Conexões pooled | **Mesmo risco em ambas** (ver linha abaixo) | **Mesmo risco em ambas** |
| Contexto transacional | Obrigatório em ambas | Obrigatório em ambas |
| Risco de conexão reutilizada com tenant incorreto | **Idêntico nas duas abordagens** — é um risco do MECANISMO (`SET LOCAL`/GUC por transação, nunca `SET` de sessão) e do padrão de pooling, não da estratégia de derivação do tenant | Idêntico |

**Conclusão do item 6:** o risco de vazamento por reuso de conexão de pool não é resolvido nem
agravado pela escolha entre join e materialização — é uma preocupação ortogonal, do desenho do
mecanismo de propagação de contexto (`SET LOCAL` obrigatório dentro de toda transação, nunca
`SET` de sessão; pool em modo que preserve isolamento de transação). A escolha real, por tabela,
deve seguir a matriz §3: **materializar exatamente onde a derivação relacional é ambígua ou
indeterminada** (`TENANT_MATERIALIZED_FOR_SECURITY`), **derivar por join simples de 1 hop** onde
o caminho é comprovadamente unívoco e raso (`TENANT_DERIVED`) — não uma escolha global única
entre as duas.

## 7. Migration baseline: A ou B?

**A.** manter V1 e criar V2 de segurança (camada aditiva sobre a V1 já validada).
**B.** preservar V1 apenas como artefato histórico de validação e gerar uma nova baseline
definitiva antes do primeiro banco persistente.

| Critério | A (V1 + V2 aditiva) | B (nova baseline única) |
|---|---|---|
| Auditabilidade | V1 nunca foi aplicada a um banco real — não há histórico real de produção para preservar; a "auditoria" de V1 já está integralmente coberta pelo `INTEGRATION_TEST_REPORT.md` e pelo commit git, independentemente de V1 continuar sendo "a migration 1" de algum banco real | Idêntica — nada se perde, porque nada real existia para se perder |
| Histórico | Manteria uma migration "pré-tenant" permanentemente registrada em `_prisma_migrations` de **todo** banco futuro, mesmo sabendo hoje que ela é estruturalmente incompleta (dado o achado do §3/§5) | V1 permanece como referência histórica em `docs`/`prisma/migrations/` do repositório (git), sem precisar ser "revivida" em todo banco novo |
| Implantação limpa | Pior — todo ambiente novo (dev/test/staging/prod) precisaria aplicar 2 migrations sequenciais para chegar ao mesmo estado, sendo que a V1 sozinha já é sabidamente incompleta para produção (não tem `Tenant`) | Melhor — 1 migration única e completa por ambiente novo |
| Manutenção | Pior — a V2 precisaria fazer `ALTER TABLE ADD COLUMN tenant_id` em **6 tabelas** (`receita`, `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`, `arquivo_origem` — achado deste adendo, maior do que se estimava na proposta original) mais criar `Tenant` e popular `unidade_economica.tenant_id` — uma migration de retrofit não trivial mesmo em banco vazio | Melhor — as mesmas tabelas nascem corretas na criação, sem `ALTER` incremental |
| Risco | Se a V1 chegasse a ser aplicada em qualquer banco com dados reais antes da V2, o retrofit exigiria decidir um valor de `tenant_id` para linhas já existentes sem fonte de verdade — risco real e evitável | Risco mínimo — nada real existe ainda para migrar |

**Decisão: B.** A V1 permanece como artefato histórico de validação técnica (preservada em
`prisma/migrations/20260901120000_init_baseline_fisica/` e em `INTEGRATION_TEST_REPORT.md`,
git commit já registrado) — **não é, e não deve se tornar, a primeira migration de nenhum banco
persistente.** Uma nova baseline definitiva, incorporando `Tenant` e a estratégia de `tenant_id`
da matriz §3 desde a criação das tabelas, deve ser produzida antes de qualquer banco persistente.
Isso **fortalece** (não substitui) a mesma decisão já registrada na proposta original — o achado
do §3/§5 (mais tabelas precisam de `tenant_id` materializado do que se estimava) torna o
argumento a favor de B ainda mais forte, não o contrário.

Esta decisão **não é executada por este adendo** — permanece uma autorização futura em aberto.

---

## 8. Resultado consolidado

- **Definição recomendada de Tenant:** fronteira técnica de isolamento e propriedade de dados,
  agregando 1..N `UnidadeEconomica`. Sem atributos de CRM/faturamento.
- **Necessidade de `Cliente`/`Organização` separado:** **não** — classificado
  `REDUNDANTE_NESTA_FASE`. Uma única entidade (`Tenant`) cobre o requisito atual.
- **Classificação das 20 tabelas:** `TENANT_ROOT` (1: `unidade_economica`) · `GLOBAL_SHARED` (3:
  `pessoa_fisica`, `pessoa_juridica`, `fonte_pagadora`) · `TENANT_DERIVED` (8:
  `vinculo`/`vinculo_extremidade` com exceção documentada, `receita_documento_fiscal`,
  `documento_fiscal_arquivo_origem`, `classificacao_equiparacao_hospitalar`,
  `cenario_tributario`, `resultado_calculo` com exceção documentada) · `TENANT_MATERIALIZED_FOR_SECURITY`
  (6: `receita`, `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`,
  `documento_fiscal`, `arquivo_origem`) · `DECISION_BLOCKED` (3: `conflito_dado`,
  `conflito_dado_item`, `revisao_tecnica`).
- **Estratégia recomendada de `tenant_id`:** híbrida seletiva — materializar exatamente nas 6
  tabelas `TENANT_MATERIALIZED_FOR_SECURITY` (onde a derivação relacional é comprovadamente
  ambígua/indeterminada); derivar por join de 1 hop nas `TENANT_DERIVED`; nunca materializar em
  `GLOBAL_SHARED`.
- **Estratégia recomendada de RLS:** policies simples (`tenant_id = current_setting(...)`) nas
  tabelas materializadas e na raiz; policies `EXISTS` de 1 hop nas `TENANT_DERIVED`; policy de
  união de múltiplos caminhos (mais cara, com risco de omissão documentado) em `GLOBAL_SHARED`.
  Propagação de contexto sempre via `SET LOCAL` por transação, nunca `SET` de sessão.
- **Tratamento de PF/PJ compartilhadas:** linha canônica única, sem `tenant_id`; visibilidade
  do perfil (não dos fatos financeiros) concedida independentemente por tenant via união de
  caminhos relacionais — nunca por transitividade entre tenants.
- **Decisão migration baseline:** **B** — V1 preservada como artefato histórico; nova baseline
  definitiva (com `Tenant` + estratégia de `tenant_id` da matriz §3) precede qualquer banco
  persistente.
- **Decisões ainda bloqueadas (não resolvidas por este adendo):**
  1. Como determinar/validar estruturalmente o `tenant_id` correto em `receita`,
     `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, sem uma FK de
     origem confiável — depende de um futuro Change Request de MCD/COT adicionando contexto de
     UE a esses fatos.
  2. `conflito_dado`/`conflito_dado_item`/`revisao_tecnica` — referência polimórfica sem FK
     impede qualquer derivação ou validação estrutural de tenant.
  3. `Vinculo` cujas duas extremidades não incluem nenhuma `UnidadeEconomica` — tenant
     indeterminável.
  4. `ResultadoCalculo` com `cenario_tributario_id` nulo — tenant indeterminável.
  5. Risco de manutenção da policy de união de caminhos em `pessoa_fisica`/`pessoa_juridica`/
     `fonte_pagadora` ficar desatualizada quando uma nova tabela referenciá-las no futuro.

Nenhum destes cinco pontos é resolvido por inferência — permanecem registrados para decisão
explícita futura, no mesmo padrão de gaps já usado neste projeto (`ADR-GAP-*`/`DST-GAP-*`).

**SEC-001 AINDA POSSUI DECISÕES ARQUITETURAIS BLOQUEANTES**
