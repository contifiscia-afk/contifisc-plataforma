# SEC-001 — Auditoria de Consistência do Adendo V2

**Status:** AUDITORIA — verifica e corrige a consistência das decisões de
`SEC-001_ADENDO_DECISORIO_V2.md`. Não é normativo. **Não altera** COT/MCD/CDC/DST/ADR,
`schema.prisma` ou migrations. **Não cria** banco, RLS ou autenticação. Onde a auditoria encontra
um erro real no V2, ele é corrigido aqui explicitamente — não escondido.

---

## 1. A contradição da conclusão — resolvida com correção

A matriz do V2 lista `3 DECISION_BLOCKED` (`conflito_dado`, `conflito_dado_item`,
`revisao_tecnica`) enquanto a conclusão afirmava "ownership resolvido". Auditoria por tabela:

| | `conflito_dado` | `conflito_dado_item` | `revisao_tecnica` |
|---|---|---|---|
| **Motivo do bloqueio** | Tenant só seria alcançável via `objeto_id`/`tipo_objeto` (item filho), sem FK real | Referência polimórfica `objeto_id`/`tipo_objeto`, sem FK — o objeto raiz do problema | Referência polimórfica `objeto_revisado_id`/`tipo_objeto_revisado`, sem FK |
| **Dependência** | Depende da resolução de `conflito_dado_item` (herda o bloqueio do filho) | Depende de um novo campo transversal de segurança formalmente definido (ver §2 — **não** o reaproveitamento de F9001-F9010, que estava incorreto) | Mesma dependência de um novo campo transversal de segurança |
| **Participa da primeira baseline física?** | Sim — a tabela já existe fisicamente desde a migration V1 validada; será recriada em qualquer nova baseline | Sim, mesma razão | Sim, mesma razão |
| **Ausência da decisão compromete RLS?** | Compromete **apenas a si mesma** — nenhuma policy de outra tabela depende de `conflito_dado` para resolver tenant | Idem — o ponteiro é unidirecional (`conflito_dado_item → objeto qualquer`), nunca o inverso | Idem |
| **Compromete FK/ownership?** | Não — nenhuma das 17 tabelas com caminho já resolvido (matriz §7 abaixo) depende de `conflito_dado` para nada | Não | Não |
| **Pode ser formalmente diferida?** | **Sim, mas apenas sob uma condição explícita:** a tabela deve entrar na primeira baseline com RLS **default-deny** (`USING (false)`, sem exceção) até que o campo transversal de segurança seja formalizado — nunca "sem RLS" (aberta) nem "RLS aproximada" | Mesma condição | Mesma condição |

**Correção da conclusão do V2:** a análise confirma que os três bloqueios **não contaminam** as
outras 17 tabelas (não são bloqueantes *sistemicamente*) — mas **são**, eles próprios, uma parte
não resolvida da mesma baseline de segurança, e a mitigação segura (RLS `default-deny` até
decisão formal) é uma **decisão nova**, ainda não adotada, não algo que já estava implícito no
V2. Portanto **"ownership resolvido" era prematuro** — a conclusão correta desta rodada está no
§9, após incorporar também os achados dos itens 2-7 abaixo (que revelam mais uma tabela com
timing genuinely bloqueado — `arquivo_origem`, ver §5-6).

## 2. Correção: Tenant não reaproveita `F9001..F9010`

**Erro confirmado no V2:** a formulação "reaproveitando o padrão já estabelecido para
`MCD-F9001..F9010`" é ambígua e, lida literalmente, sugere reaproveitar os **IDs/semânticas** já
atribuídos (proveniência, processamento, qualidade) — o que está errado. `F9001..F9010` têm
significado fechado e não guardam nenhuma relação semântica com fronteira de tenant/segurança.

**Correção:** o único reaproveitamento válido é do **padrão arquitetural** "campo transversal —
aplicável a múltiplos objetos, decidido fisicamente de forma centralizada, documentado à parte do
catálogo principal de cada objeto" — não os números nem os significados.

Se `tenant_id` (ou equivalente) precisar se tornar campo canônico transversal para
`ConflitoDado`/`ConflitoDadoItem`/`RevisaoTecnica`, isso exige:

- **Novo ID:** proposto `MCD-F9011` (número sugerido para a próxima posição livre na família
  `DOM-SYS`/metadados transversais — **não atribuído por este documento**, fica para o Change
  Request formal decidir o ID definitivo).
- **Novo significado:** "identificador do `Tenant`/`UnidadeEconomica` de contexto de segurança
  responsável por este registro de auditoria/revisão — aplicável **exclusivamente** aos objetos
  de exceção polimórfica (`ConflitoDado`, `ConflitoDadoItem`, `RevisaoTecnica`), nunca aos demais
  objetos do catálogo, que resolvem tenant por relação de domínio própria." Distinto de todos os
  10 campos F9001-F9010 (nenhum deles trata de fronteira de isolamento/segurança).
- **Novo requisito:** aplicabilidade **restrita** a 3 objetos nomeados — ao contrário de
  F9001-F9010, que são potencialmente aplicáveis a qualquer objeto `DOM-SYS`/fato, este novo
  campo **não deve** ser generalizado para os demais 17 objetos (que já têm caminho de domínio
  próprio, per §3-4 do adendo V2).
- **Novo Change Request:** formalização própria — pode ser incluído no escopo do
  `SEC-CHANGE-REQUEST-001` (§8 abaixo) ou desmembrado em um CR específico, a critério de quem
  aprovar.
- **Impacto explícito:**
  - **MCD:** novo campo (ID pendente de atribuição formal), com parágrafo explícito
    diferenciando-o de `F9001..F9010`.
  - **CDC:** novo contrato — a decidir se estende `CDC-SYS-001` (metadados transversais
    existente) ou recebe contrato próprio, dado o escopo restrito (3 objetos, não geral).
  - **COT:** nenhum objeto novo — apenas um campo nos 3 objetos já catalogados.
  - **DST:** nenhum vocabulário fechado novo (é uma referência/UUID, não um enum) — mas pode
    valer um termo semântico no dicionário distinguindo "tenant de segurança" de "contexto
    econômico/tributário" (UE), para evitar confusão futura entre os dois conceitos.
  - **ADR:** nova decisão física (`ADR-D*` própria) — **não** uma reaplicação de `ADR-D016`/
    `ADR-D017` (que são especificamente sobre `F9004`/`F9007`), um `ADR-D*` novo e nomeado.

Nenhuma dessas mudanças é executada aqui — ficam registradas como proposta de escopo (§8).

## 3. `ResultadoCalculo` — XOR reavaliado

**Verificação da estrutura atual de `CenarioTributario`** (já existente, validada na migration
V1): `CenarioTributario.unidade_economica_id` é **`NOT NULL`** — toda `CenarioTributario` já
identifica sua UE de forma obrigatória e inequívoca. Este fato muda a análise por completo.

| Cenário | `cenario_tributario_id` | UE conhecida via | XOR necessário? |
|---|---|---|---|
| **A.** Resultado direto na UE, sem cenário | Ausente | `unidade_economica_id` próprio (novo) | — |
| **B.** Resultado produzido para um `CenarioTributario` | Presente | `CenarioTributario.unidade_economica_id` (já `NOT NULL`, já resolvido, **sem precisar de nenhuma FK nova**) | — |
| **C.** Resultado de cenário em que a UE também é conhecida | Presente | **É o mesmo caso B** — como `CenarioTributario` sempre tem UE, não existe um "B sem C" — todo caso B já é também C. Não é um cenário distinto. | — |
| **D.** Resultado técnico/global eventualmente sem UE | — | **Não confirmado nos documentos canônicos.** `COT-OBJ-014` descreve `ResultadoCalculo` exclusivamente no domínio de cálculo tributário/planejamento — nenhuma evidência de uso fora desse domínio. | Fica como possibilidade **não descartada por inferência** — se existir, é um bloqueio genuíno adicional, não resolvido aqui. |

**Por que XOR estava errado:** XOR (`ADR-C001`/`ADR-C002`) é o padrão certo quando duas FKs são
**alternativas mutuamente exclusivas de ownership** (uma Receita pertence a PF OU PJ, nunca
ambos — são donos concorrentes de fato). Aqui, `unidade_economica_id` e `cenario_tributario_id`
**não competem pelo mesmo papel** — quando `cenario_tributario_id` existe, ele **já implica** a UE
(via sua própria FK obrigatória); ter também `unidade_economica_id` preenchido no
`ResultadoCalculo`, igual ao da UE do cenário, não é uma contradição — é uma **redundância
consistente e verificável**, não um conflito de ownership.

**Classificação: `AMBOS_PODEM_COEXISTIR`.**

Modelo recomendado (revisado): `unidade_economica_id` em `ResultadoCalculo` como campo **sempre
preenchido** (não opcional, não XOR) — presente tanto no caso A (única fonte de UE) quanto no
caso B (redundante, mas explícito e verificável por trigger contra
`cenario_tributario.unidade_economica_id`). Isso é **mais simples** que o XOR proposto no V2, e
mais robusto (nunca há ambiguidade sobre "qual dos dois checar"). O cenário D permanece uma
possibilidade em aberto, não descartada, não resolvida.

## 4. `DocumentoFiscal` — cardinalidade e uniqueness reavaliadas

**A cardinalidade `DocumentoFiscal N:1 UnidadeEconomica` está correta a nível de LINHA** (cada
registro pertence a exatamente uma UE) — mas a auditoria revela que a suposição implícita no V2
de que **"1 documento fiscal do mundo real = 1 linha `DocumentoFiscal`"** está errada em pelo
menos um cenário real:

- **Mesma chave/documento importado por dois tenants:** uma Nota Fiscal Eletrônica tem uma
  `chave_documento_fiscal` **globalmente única no mundo real** (44 dígitos, emitida pela SEFAZ) —
  mas o **mesmo documento real** é legitimamente relevante para **duas partes diferentes**: quem
  emite (receita) e quem recebe (despesa/custo). Se emissor e destinatário forem clientes
  **diferentes e não relacionados** da CONTIFISC, a mesma `chave_documento_fiscal` precisa
  aparecer nos livros de **dois tenants diferentes** — cada um com sua própria linha
  `DocumentoFiscal`, cada uma corretamente isolada por tenant, ambas com o **mesmo valor** de
  `chave_documento_fiscal`.
- **Uma nota associada a várias `Receita`s da mesma UE:** não altera a análise — continua N:1
  dentro do mesmo tenant, coberto pelo trigger de consistência já proposto no adendo V2.
- **Documento retificado/cancelado:** é uma dimensão de status/histórico (`status_processamento_
  dado` ou equivalente), ortogonal ao tenant — não afeta esta análise.
- **Documento usado como evidência em reconciliação:** o `ConflitoDado` que referencia este
  `DocumentoFiscal` via `objeto_id` deve ter seu próprio contexto de segurança (§2) coerente com
  o tenant do documento referenciado — uma validação cruzada a formalizar no CR, não uma mudança
  na classificação do `DocumentoFiscal` em si.

**Conclusão sobre uniqueness:** `chave_documento_fiscal` **não pode ter unicidade global** —
precisa ser **tenant-scoped** (ou, mais precisamente, `unidade_economica`-scoped, já que o tenant
em si não é a chave física de ownership do documento — ver §7). Hoje o schema não tem nenhum
`UNIQUE` sobre `chave_documento_fiscal` (só um índice simples de busca) — não há regressão a
corrigir, apenas uma diretriz para a futura decisão física: **se algum dia se decidir tornar
`chave_documento_fiscal` único, o unique deve ser composto com `unidade_economica_id`, nunca
sozinho.** Nenhuma constraint é criada nesta etapa (conforme instruído).

## 5. `ArquivoOrigem` — decomposição em quatro camadas

| Camada | O que é |
|---|---|
| **1. Registro lógico** | A linha `arquivo_origem` (id, nome, hash, tipo, referência, timestamps) — metadado **sobre** o arquivo. |
| **2. Objeto físico no storage** | Os bytes reais, em algum backend de armazenamento (`armazenamento_referencia` aponta para ele). |
| **3. Hash do conteúdo** | `hash_conteudo` — impressão digital do conteúdo, pode colidir entre uploads de tenants diferentes com bytes idênticos (coincidência, não é o mesmo caso de PF/PJ, onde o compartilhamento é uma feature desejada, não um acidente). |
| **4. Autorização de tenant** | Quem pode, hoje, requisitar acesso a este registro/arquivo. |

**Insight central: as camadas 1 e 4 podem — e devem — permanecer por tenant, enquanto a camada 2
pode ser deduplicada com segurança na infraestrutura, desde que o acesso a ela nunca seja direto
e sempre medeado pela camada 1.** Isso decompõe exatamente a falsa dicotomia "duplicar tudo" ×
"compartilhar tudo".

| Critério | A. Duplicar registro **e** bytes | **B. Duplicar registro lógico; deduplicar bytes com segurança** | C. Compartilhar registro canônico via associação tenant-scoped |
|---|---|---|---|
| Segurança | Máxima, mas cara | Alta — **desde que** o acesso aos bytes seja sempre mediado pelo registro lógico (nunca URL/chave direta e previsível) | Arriscada — um esquecimento na tabela de associação vaza acesso direto |
| LGPD | Simples (isolamento total) | Mais complexo — exige contagem de referências antes de liberar o blob físico ao excluir um registro lógico | Muito complicado — não há uma "linha própria" do tenant para anonimizar isoladamente |
| Risco de URL/object-key leakage | Baixo (chaves distintas) | Médio — mitigado exigindo URLs assinadas/temporárias emitidas sob demanda, nunca uma referência estática exposta | Alto — o registro compartilhado é, por natureza, um ponto único de possível exposição indevida |
| Custo de storage | Maior (duplicação real) | Menor (bytes deduplicados) | Menor, mas ao custo de segurança acima |
| Exclusão | Trivial e isolada | Precisa de contagem de referências | Ambígua — a quem pertence excluir? |
| Retenção | Independente por tenant | Precisa manter o blob enquanto qualquer referência lógica existir | Idem, mas sem um dono lógico claro |
| Auditoria | Trivial | Viável, com a relação lógica registrada separadamente do armazenamento físico | Mais difícil de provar isolamento retroativamente |
| Backup/restore | Simples por tenant | Backup completo do storage físico não expõe tenant diretamente (chaves opacas); restore seletivo precisa reconstruir as referências lógicas corretas | Mais complexo — um registro serve a múltiplos tenants no mesmo backup |

**Recomendação: Opção B.** `ArquivoOrigem` permanece **`TENANT_OWNED` na camada lógica** — nunca
duas linhas lógicas de tenants diferentes se fundem, mesmo com hash idêntico. A regra obrigatória
do enunciado ("um tenant nunca pode adquirir acesso a arquivo de outro tenant apenas porque o
hash é igual") é satisfeita **sem duplicar bytes físicos**: a deduplicação acontece exclusivamente
na camada de armazenamento (uma preocupação de custo/infraestrutura), nunca na camada de
autorização, e o acesso ao arquivo nunca é direto — é sempre uma URL assinada/temporária emitida
depois de verificar a que tenant o `ArquivoOrigem` (registro lógico) pertence.

## 6. `UnidadeEconomica` nos fatos — RAW × Canonical × Derived

**Achado desta auditoria (correção ao V2, que não havia considerado o timing de ingestão):**
exigir `unidade_economica_id` como `NOT NULL` **desde a criação** em toda tabela quebraria fluxos
legítimos de ingestão — especificamente, evidência **RAW** (`ArquivoOrigem`) pode, e
frequentemente vai, existir **antes** de o sistema saber a que UE/tenant ela pertence (ex.: um
arquivo recebido por um canal de intake genérico, aguardando classificação/triagem).

Usando a própria distinção RAW/Canonical/Derived já estabelecida no projeto (Errata controlada
nº2 do ADR-001):

| Tabela | Camada | Cardinalidade com UE | Obrigatoriedade recomendada | Pode existir sem UE resolvida? | Momento em que a FK se torna obrigatória |
|---|---|---|---|---|---|
| `Receita` | Canonical (fato) | N:1 | `NOT NULL` | Não — um fato canônico sem contexto de apuração não deveria existir como `Receita`; ambiguidade pré-classificação pertence a uma etapa RAW/staging, não a esta tabela | Na criação do registro canônico |
| `ContribuicaoPrevidenciaria` | Canonical (fato) | N:1 | `NOT NULL` | Não, mesma razão | Na criação |
| `VinculoPrevidenciario` | Canonical (fato/relação) | N:1 | `NOT NULL` | Não, mesma razão | Na criação |
| `EventoIRPF` | Canonical (fato) | N:1 | `NOT NULL` | Não, mesma razão | Na criação |
| `DocumentoFiscal` | Canonical (representação normalizada) | N:1 | `NOT NULL` | Não — por definição, "canônico" já implica classificação concluída | Na criação do registro canônico (a evidência RAW associada pode ter chegado antes, sem UE) |
| `ArquivoOrigem` | **RAW** (evidência imutável) | N:1 quando classificado; **indefinido antes disso** | **Nullable** — único caso, entre os seis, onde a FK não pode ser exigida desde a criação | **Sim, legitimamente** — é exatamente o propósito da camada RAW (preservar evidência antes/independente da classificação) | Só quando (e se) o arquivo é vinculado a um `DocumentoFiscal`/fato canônico — a obrigatoriedade é do **elo**, não do `ArquivoOrigem` em si |

**Consequência de segurança para o estado "não classificado":** enquanto
`ArquivoOrigem.unidade_economica_id` for nulo, o registro não pode ser visível a **nenhum**
tenant — apenas a um papel interno de triagem/intake da própria CONTIFISC (reaproveitando o
modelo de `PapelAcesso`/menor privilégio já proposto na primeira proposta SEC-001). Isso não é
uma exceção de segurança — é o próprio "negar por padrão" aplicado ao caso em que nem o tenant
ainda é conhecido.

## 7. Classificação final de `tenant_id` físico (20 tabelas)

Após estabelecer a FK de domínio `unidade_economica_id` nos fatos pertinentes (§3, §4, §6):

| # | Tabela | Classificação | Justificativa breve |
|---|---|---|---|
| 1 | `unidade_economica` | `TENANT_ID_RAIZ` | Ancora a FK real para `Tenant`. |
| 2 | `pessoa_fisica` | `SEM_TENANT_ID` | Global, RLS por união de fatos (adendo V1 §4). |
| 3 | `pessoa_juridica` | `SEM_TENANT_ID` | Idem. |
| 4 | `fonte_pagadora` | `SEM_TENANT_ID` | Idem, justificativa ainda mais forte (adendo V2 §10). |
| 5 | `vinculo` | `TENANT_DERIVADO_POR_RLS` | 1-2 hops via extremidade UE, quando existente (exceção residual documentada, adendo V2 §7). |
| 6 | `vinculo_extremidade` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 7 | `receita` | `TENANT_DERIVADO_POR_RLS` | Via novo `unidade_economica_id` (1 hop), `NOT NULL` no canônico. |
| 8 | `contribuicao_previdenciaria` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 9 | `vinculo_previdenciario` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 10 | `evento_irpf` | `TENANT_DERIVADO_POR_RLS` | Idem. |
| 11 | `documento_fiscal` | `TENANT_DERIVADO_POR_RLS` | Via novo `unidade_economica_id` próprio (1 hop), `NOT NULL` no canônico. |
| 12 | `arquivo_origem` | **`BLOQUEADO`** | FK nullable por desenho (RAW), risco de referência multi-tenant (§5) — exige desenho próprio de RLS para o estado "não classificado", não resolvido aqui. |
| 13 | `receita_documento_fiscal` | `TENANT_DERIVADO_POR_RLS` | Via `receita`/`documento_fiscal` (ambos já resolvidos), com trigger de consistência. |
| 14 | `documento_fiscal_arquivo_origem` | `TENANT_DERIVADO_POR_RLS` | Via `documento_fiscal`. |
| 15 | `classificacao_equiparacao_hospitalar` | `TENANT_DERIVADO_POR_RLS` | Via `receita` (FK já obrigatória). |
| 16 | `cenario_tributario` | `TENANT_DERIVADO_POR_RLS` | Via `unidade_economica_id` próprio, já `NOT NULL` — nenhuma mudança necessária aqui. |
| 17 | `resultado_calculo` | `TENANT_DERIVADO_POR_RLS` | Via `unidade_economica_id` próprio (sempre presente, §3), consistente com `cenario_tributario` quando este existir. |
| 18 | `conflito_dado` | **`BLOQUEADO`** | Depende do novo campo transversal de segurança (§2), ainda não formalizado. |
| 19 | `conflito_dado_item` | **`BLOQUEADO`** | Idem. |
| 20 | `revisao_tecnica` | **`BLOQUEADO`** | Idem. |

**Soma:** `TENANT_ID_RAIZ`=1 · `SEM_TENANT_ID`=3 · `TENANT_DERIVADO_POR_RLS`=12 · `BLOQUEADO`=4.
`1+3+12+4 = 20`. ✓ Nenhuma tabela recebeu `TENANT_ID_MATERIALIZADO` como classificação
**primária** — com a FK de domínio agora existindo em todos os 16 casos não bloqueados, a
derivação por 1 hop é suficiente estruturalmente; materializar um `tenant_id` redundante nessas
tabelas passa a ser **opcional, puramente por performance**, nunca uma necessidade estrutural.

**Se um `tenant_id` materializado for adotado (por performance) em qualquer uma das 12 tabelas
`TENANT_DERIVADO_POR_RLS`:** a divergência entre `registro.tenant_id` e
`registro.unidade_economica.tenant_id` é impedida **não por validação, mas por derivação
automática no banco** — um trigger `BEFORE INSERT OR UPDATE` que **calcula** (não apenas
verifica) `NEW.tenant_id := (SELECT tenant_id FROM unidade_economica WHERE id =
NEW.unidade_economica_id)` a cada escrita. Isso torna a coluna um valor **inteiramente
governado pelo banco**, nunca confiável a partir da aplicação — mais forte do que "a aplicação
valida" (explicitamente insuficiente, conforme a instrução) e mais forte até do que um `CHECK`
que apenas rejeita valores incorretos: aqui, a aplicação **nem precisa enviar** o valor — o banco
o calcula sempre.

---

## 8. Escopo atualizado do `SEC-CHANGE-REQUEST-001`

*(Somente esta seção é atualizada; nenhum documento normativo é alterado agora.)*

### Alterações canônicas obrigatórias (MCD/COT/CDC)

- Novo objeto `Tenant` (`COT-OBJ-*`, domínio `DOM-SEC`) + `UnidadeEconomica.tenant_id`.
- Novo campo `unidade_economica_id` (`NOT NULL`) em `Receita`, `ContribuicaoPrevidenciaria`,
  `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`.
- Novo campo `unidade_economica_id` (`NOT NULL`, sempre presente — **sem XOR**, ver §3) em
  `ResultadoCalculo`.
- Novo campo `unidade_economica_id` (**nullable**, populado só após classificação) em
  `ArquivoOrigem`.
- Novo campo transversal de segurança (ID formal pendente, proposto `MCD-F9011`) em
  `ConflitoDado`, `ConflitoDadoItem`, `RevisaoTecnica` — com contrato/semântica **próprios**,
  explicitamente não herdados de `F9001..F9010`.

### Alterações físicas (ADR)

- 6 novas decisões físicas de FK (uma por tabela do primeiro grupo acima).
- 1 nova decisão física para `ResultadoCalculo.unidade_economica_id` — sem CHECK XOR (revisão do
  V2); trigger de consistência contra `cenario_tributario.unidade_economica_id` quando ambos
  presentes.
- Diretriz física (não constraint ainda): uniqueness futura de `chave_documento_fiscal`, se
  adotada, deve ser composta com `unidade_economica_id` — nunca global (§4).
- Diretriz física para `ArquivoOrigem`: deduplicação de bytes na camada de armazenamento é
  permitida; deduplicação do registro lógico entre tenants é **proibida** (§5).
- Se algum `tenant_id` materializado for adotado por performance: trigger de derivação
  automática (não apenas validação) a partir da FK de domínio (§7).

### Alterações de segurança/RLS

- RLS `default-deny` obrigatório em `ConflitoDado`, `ConflitoDadoItem`, `RevisaoTecnica` até o
  campo transversal de segurança (`MCD-F9011` proposto) ser formalizado e implementado.
- RLS de `ArquivoOrigem` precisa de uma policy de dois estados: sem UE → visível apenas a papel
  interno de triagem; com UE → derivado normalmente.
- Acesso a bytes de `ArquivoOrigem` nunca direto — sempre via URL assinada/temporária emitida
  após checagem de tenant do registro lógico.

### Decisões diferidas (não resolvidas por este documento)

1. Formalização exata do campo transversal de segurança para os 3 objetos poliomórficos
   (ID definitivo, contrato CDC próprio ou extensão de `CDC-SYS-001`).
2. Desenho completo do fluxo RAW→Canonical de `ArquivoOrigem` (quem/como classifica, papel de
   triagem, prazo máximo em estado não classificado).
3. Confirmação ou descarte do cenário D de `ResultadoCalculo` (resultado técnico/global sem UE) —
   não descartado por inferência.
4. `Vinculo` sem nenhuma extremidade `UnidadeEconomica` — condicionado ao fechamento futuro de
   `DST-GAP-003` (herdado do adendo V2, não revisitado nesta auditoria).
5. Decisão final sobre materializar ou não `tenant_id` físico nas 12 tabelas
   `TENANT_DERIVADO_POR_RLS` (otimização de performance, não estrutural).

---

## 9. Gate final

A auditoria confirma avanço real e substancial: **16 das 20 tabelas** têm hoje um caminho de
ownership/tenant conceitualmente resolvido, justificado por relação de domínio genuína (não
`tenant_id` solto), com timing de obrigatoriedade compatível com ingestão RAW legítima. Os
achados desta rodada também **corrigiram** dois erros do adendo V2 (reaproveitamento indevido de
`F9001..F9010`; XOR desnecessário em `ResultadoCalculo`) e **identificaram um bloqueio adicional**
não visto antes (`arquivo_origem`, por causa do timing RAW e do risco de referência multi-tenant
por hash) — o que, somado aos 3 bloqueios polimórficos já conhecidos, totaliza **4 tabelas ainda
sem resolução física completa**, cada uma com uma mitigação de contenção identificada (RLS
default-deny) mas **nenhuma delas formalmente adotada ainda**.

Como o enunciado desta auditoria exige: a conclusão "resolvido" só se sustenta se os bloqueios
forem comprovadamente não bloqueantes **para a baseline física de segurança como um todo** — e
embora não sejam bloqueantes *sistemicamente* (não contaminam as outras 16 tabelas), eles
**são**, eles próprios, decisões de segurança pendentes dentro do mesmo escopo que o SEC-001 se
propõe a fechar.

**SEC-001 AINDA BLOQUEADO PARA APROVAÇÃO NORMATIVA**

(bloqueio agora restrito e nomeado: 4 tabelas — `arquivo_origem`, `conflito_dado`,
`conflito_dado_item`, `revisao_tecnica` — mais as 5 decisões diferidas do §8; as 16 tabelas
restantes têm modelo de ownership/tenant resolvido e não precisam de nova rodada de análise.)
