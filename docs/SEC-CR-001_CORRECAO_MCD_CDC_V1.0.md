# SEC-CR-001 — Correção Normativa Coordenada de MCD e CDC

**Versão:** 1.0
**Status:** RELATÓRIO DE CORREÇÃO — acompanha `MCD-001_CONTIFISC_Modelo_Canonico_de_Dados_V1.4.md`
e `CDC-001_CONTIFISC_Contrato_Canonico_de_Dados_V1.4.md`. Não altera `SEC-001`,
`SEC-CHANGE-REQUEST-001`, `COT-001`, `DST-001`, ADR, Prisma, migrations ou banco.
**Escopo:** corrigir exclusivamente os 2 achados `RELEVANTE` de
`SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`.

---

## 1. `ContaAcesso`

Verificação prévia (COT/CDC/SEC vigentes):

- `COT-001` V1.2 §3: `COT-OBJ-017` = `ContaAcesso` — "Identidade de autenticação separada da
  Pessoa Física tributária. Autorizada por Tenant (`COT-REL-131`) e, opcionalmente, por
  UnidadeEconomica (`COT-REL-132`)." Contrato: "SEC futuro".
- `SEC-001` V1.0 §1: `ContaAcesso` já catalogada desde `COT-001` V1.1; este documento formaliza a
  arquitetura em torno dela, sem renomeá-la.
- `SEC-001` V1.0 §13: menciona conceitualmente um atributo de tipo (`HUMANA`/`SERVICO`) para contas
  de serviço — **nunca formalizado por `SEC-CHANGE-REQUEST-001` V1.1**, cujo item 12 (contagem de
  campos aprovados) não inclui nenhum campo de `ContaAcesso`.
- `CDC-001` V1.3: nenhum contrato para `ContaAcesso` existia.

**Decisão:** incorporar exatamente um campo — `id` (`MCD-F10007`) — suficiente para:
- **identidade persistente** — `id` imutável, gerado pelo sistema;
- **participação nas associações de autorização** — permite `conta_acesso_id` (`MCD-F10008`) em
  `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` referenciar um alvo real;
- **rastreabilidade** — a identidade estável é o que torna um `ContaAcesso` referenciável por
  `EventoAuditoriaSeguranca` no futuro (quando esse objeto for detalhado).

**Não antecipado, conforme instruído:** `tipo` (`HUMANA`/`SERVICO`, mencionado em `SEC-001` §13
mas nunca aprovado por Change Request — registrado como `GAP-CDC-1.4-002`, explicitamente
diferido), senha, hash de senha, OAuth, refresh token, MFA físico, sessão, ou qualquer campo de
implementação de provedor.

**Precedente aplicado:** mesmo padrão já usado nesta mesma rodada de SEC-CR-001 para `Tenant`
(`MCD-F10001`) e `EventoAuditoriaSeguranca` (`MCD-F10006`) — ambos incorporados com apenas `id` na
V1.3, sem timestamps ou atributos adicionais.

**Resultado:** `MCD-001` V1.4 §8 (`MCD-F10007`); `CDC-001` V1.4 `CDC-SEC-005` (novo contrato,
`COT: COT-OBJ-017`).

---

## 2. `ContaAcessoTenant`

Campos estruturais avaliados e decisão:

| Campo | Necessário? | Decisão |
|---|---|---|
| `id` | Sim | Incorporado — `MCD-F10009`, próprio (não transversal, mesmo padrão de toda estrutura de suporte do catálogo). |
| `conta_acesso_id` | Sim | Incorporado — `MCD-F10008`, **transversal** (compartilhado com `ContaAcessoUnidadeEconomica`, mesma pergunta em ambos: "a qual `ContaAcesso` esta linha se refere"). |
| `tenant_id` | Sim | Incorporado — `MCD-F10010`, papel semântico de **concessão explícita**, distinto de `MCD-F10002` (âncora raiz) e `MCD-F10003` (metadado operacional transversal) apesar do nome físico comum. |
| `papel` | Já existia | `MCD-F10005`, inalterado — **nenhum enum criado**; continua vinculado a `DST-GAP-015`. |
| Timestamps | Não necessário como campo novo | Cobertos pelo mecanismo de metadados transversais já estabelecido em `MCD-001` §9 (mesmo tratamento de `ReceitaDocumentoFiscal`/`DocumentoFiscalArquivoOrigem`, que também não têm timestamp dedicado). |
| Vigência/status | Não incorporado | Mencionado apenas na descrição textual de `COT-SUP-005` (`COT-001` V1.2 §4), nunca aprovado por Change Request — registrado como `GAP-CDC-1.4-001`. |

**Resultado:** `MCD-001` V1.4 §8/§9 (`MCD-F10008/F10009/F10010`); `CDC-001` V1.4 `CDC-SEC-003`
completo com `id`, `conta_acesso_id`, `tenant_id`, `papel`.

---

## 3. `ContaAcessoUnidadeEconomica`

Mesma formalização:

| Campo | Necessário? | Decisão |
|---|---|---|
| `id` | Sim | Incorporado — `MCD-F10011`, próprio. |
| `conta_acesso_id` | Sim | Incorporado — `MCD-F10008`, mesmo campo transversal de `ContaAcessoTenant`. |
| `unidade_economica_id` | Sim | Incorporado — `MCD-F10012`, papel semântico de **restrição explícita**, distinto de `MCD-F10004` (contexto de apuração de um fato). |
| `papel` | Já existia | `MCD-F10005`, inalterado. |
| Timestamps | Não necessário | Mesmo mecanismo de §9. |
| Vigência/status | Não incorporado | Mesmo `GAP-CDC-1.4-001` (a descrição de `COT-SUP-006` nem chega a mencionar vigência — assimetria textual com `COT-SUP-005` já observada na reconciliação, não corrigida aqui por não envolver COT). |

**FKs reais suficientes para `ContaAcesso → UnidadeEconomica`:** confirmadas —
`conta_acesso_id` → `ContaAcesso.id` (`MCD-F10007`), `unidade_economica_id` →
`UnidadeEconomica.id`.

**Regra preservada:** autorização por UE **restringe** autorização previamente existente no
Tenant — nunca a concede isoladamente. Formalizada em `CDC-REL-SEC-001` (já existente, inalterada)
e reforçada estruturalmente por `CDC-REL-SEC-007` (nova, §4 abaixo): uma linha de
`ContaAcessoUnidadeEconomica` sem uma linha correspondente de `ContaAcessoTenant` para o mesmo par
(`ContaAcesso`, Tenant-da-UE) é dado inválido e nunca concede acesso por si só.

**Resultado:** `MCD-001` V1.4 §8/§9 (`MCD-F10011/F10012`, reuso de `MCD-F10008`); `CDC-001` V1.4
`CDC-SEC-004` completo.

---

## 4. Integridade das associações

Invariantes canônicos determinados (registrados para o `ADR`, não implementados como SQL):

| Invariante | Escopo | ID |
|---|---|---|
| Unicidade lógica de `(conta_acesso_id, tenant_id)` — no máximo uma concessão por par | `ContaAcessoTenant` | `CDC-REL-SEC-005` |
| Unicidade lógica de `(conta_acesso_id, unidade_economica_id)` — no máximo uma restrição por par | `ContaAcessoUnidadeEconomica` | `CDC-REL-SEC-006` |
| Toda restrição de UE pressupõe uma concessão de Tenant prévia para o mesmo par (`ContaAcesso`, Tenant-da-UE) | `ContaAcessoUnidadeEconomica` × `ContaAcessoTenant` | `CDC-REL-SEC-007` |

Nenhum destes três invariantes foi traduzido em `UNIQUE`/`CHECK`/trigger de banco — permanecem
registrados como regra canônica, com a forma física explicitamente delegada ao `ADR-002`
(`CDC-001` V1.4 §7).

Nenhum novo código de erro foi necessário: `CDC-ERR-014` (`RELATION_CARDINALITY`) cobre as duas
violações de unicidade; `CDC-ERR-018` (`SCOPE_VIOLATION`, já existente) cobre a violação de
"restrição sem concessão prévia".

---

## 5. `CredencialAcesso`

Verificado: a nova representação mínima de `ContaAcesso` (apenas `id`) **não exige nenhuma
alteração em `CredencialAcesso`**. `CredencialAcesso` (`COT-OBJ-018`) continua sem nenhum campo
MCD e sem contrato CDC — exatamente como na V1.3. Nenhuma expansão foi feita por conveniência.
Permanece explicitamente diferido, dependente do futuro Change Request de autenticação/RBAC
(`GAP-SEC-CR1-004`/`GAP-CDC-1.3-004`, ambos com nota de que `CredencialAcesso` continua
integralmente em aberto).

---

## 6. `MCD-F10004` — resolução da divergência de mutabilidade

Análise hospedeiro a hospedeiro (não uma escolha única para forçar coincidência entre os
documentos):

| Hospedeiro | Política resultante | Tipo de correção (das 4 opções do enunciado) | Justificativa |
|---|---|---|---|
| `Receita` | `Versionado` | Segue mecanismo de correção controlada já existente | Mesma família de tratamento das FKs de titularidade (`pessoa_fisica_id`/`pessoa_juridica_id`, `MCD-F3010`/`F3011`, ambas `Versionado`). Correção preferencialmente via `ConflitoDado`/`RevisaoTecnica`; fisicamente aceita `UPDATE`. |
| `ContribuicaoPrevidenciaria` | `Versionado` | Idem | Mesmo padrão de `pessoa_fisica_id` (`MCD-F6007`, `Versionado`). |
| `VinculoPrevidenciario` | `Versionado` | Idem | Mesmo padrão dos demais campos relacionais do objeto (`Temporal`/correção controlada). |
| `EventoIRPF` | `Versionado` | Idem | Mesmo padrão de `pessoa_fisica_id` (`MCD-F7009`, `Versionado`). |
| `DocumentoFiscal` | `Versionado` | Idem | Consistente com a nota de timing já registrada (`DST-001` §11.1, `CDC-FIS-001`): o campo pode precisar de correção quando a reconciliação com uma `Receita` associada revelar UE diferente. |
| **`ResultadoCalculo`** | **`Imutável`** | **Substitui registro** | `ResultadoCalculo` é um snapshot reproduzível por desenho — todos os demais campos do objeto já são `Imutável` porque qualquer mudança de entrada exige um **novo** `ResultadoCalculo` (novo `id`, novo `input_snapshot_hash`), nunca edição in-place. `unidade_economica_id` segue a mesma regra: a "correção" é calcular um novo resultado. |

**Os seis hospedeiros NÃO compartilham a mesma política de mutabilidade — isso é reportado
explicitamente, não mascarado.** A semântica do campo permanece uniforme nos 6 (mesma pergunta
respondida, confirmado em `DST-001` V1.3 §11.1); apenas a política física de mutabilidade diverge,
e diverge por uma razão estrutural genuína (a filosofia de imutabilidade específica de
`ResultadoCalculo`, pré-existente e mais restritiva que a generalização inicial do campo
transversal).

**Aplicação coerente em MCD e CDC:**
- `MCD-001` V1.4 §8.1 (nova subseção): documenta a política dividida, com a tabela acima.
- `CDC-001` V1.4: os 5 hospedeiros com `Versionado` **não mudaram** (já estavam corretos desde a
  V1.3); `CDC-CAL-001` foi corrigido de `versioned` para `immutable` — a correção foi no sentido
  de alinhar o contrato à filosofia de imutabilidade já vigente para os demais campos do próprio
  `ResultadoCalculo`, não de "fazer os documentos coincidirem" por escolha arbitrária.

**Verificação programática:** confirmado por grep direto nas seis linhas de tabela do CDC-001
V1.4 — 5 ocorrências de `unidade_economica_id | MCD-F10004 | ... | versioned` e exatamente 1
ocorrência de `... | immutable` (`CDC-CAL-001`), correspondendo exatamente à tabela de `MCD-001`
V1.4 §8.1.

---

## 7. `ResultadoCalculo` — obrigatoriedade de `unidade_economica_id`

Conforme instruído, a análise de `MCD-F10004` (§6 acima) foi aproveitada para revisitar
`GAP-SEC-CR1-003` (cenário hipotético "resultado técnico/global sem UE") — nenhuma análise nova e
independente foi conduzida.

**Constatação:** a conclusão de que `ResultadoCalculo` é identificado por um conjunto fechado de
inputs (incluindo `unidade_economica_id`, ao lado de `engine_id`/`engine_version`/`rule_set_id`/
`rule_set_version`/`input_snapshot_hash`) é **consistente com, mas não prova**, que a
obrigatoriedade atual de `unidade_economica_id` (`required`) esteja correta — um "resultado
técnico/global" hipotético, se existir, também precisaria fazer parte desse conjunto fechado de
inputs, apenas com um valor de UE nulo/especial, o que a análise de mutabilidade não resolve.

**Decisão:** a obrigatoriedade **não foi alterada**. `GAP-SEC-CR1-003` permanece registrado como
gap controlado, sem fechamento por inferência. Nenhum XOR foi introduzido entre
`unidade_economica_id` e `cenario_tributario_id` — a coexistência sem exclusividade mútua
(`CDC-REL-SEC-003`) permanece inalterada.

---

## 8. Contagens recalculadas programaticamente (não reaproveitadas de relatórios anteriores)

| Item | V1.3 (legado) | V1.4 | Diferença |
|---|---|---|---|
| Campos MCD (`MCD-F*`, únicos) | 145 | **151** | +6 (`MCD-F10007..F10012`) |
| Contratos CDC (excluindo `CDC-ERR-*`) | 25 | **26** | +1 (`CDC-SEC-005`) |
| Erros CDC (`CDC-ERR-*`) | 18 | **18** | 0 — confirmado idêntico por diff |
| Constraints relacionais CDC (`CDC-REL-XXX-NNN`) | 10 | **13** | +3 (`CDC-REL-SEC-005/006/007`) |
| Gaps CDC (`GAP-CDC-*`) | 9 | **11** | +2 (`GAP-CDC-1.4-001/002`); 2 preexistentes atualizados (`1.3-003`/`1.3-004`, não removidos) |
| Gaps MCD (`GAP-MCD-CR2-*` + `GAP-SEC-CR1-*`) | 9 | **9** | 0 — nenhum novo gap MCD criado; `GAP-SEC-CR1-004` apenas atualizado in-place |
| Ocorrências de `MCD-F10008` (transversal) | — | **2** | Confirmado por grep: exatamente 2 hospedeiros (`ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`), nenhuma duplicidade |
| Ocorrências de `MCD-F10004` por política | — | **5 `versioned` + 1 `immutable`** | Confirmado por grep direto nas 6 linhas de tabela |

**Verificação bidirecional MCD × CDC (V1.4):** nenhum `MCD-F*` referenciado pelo CDC está ausente
do catálogo MCD; nenhum `MCD-F*` do catálogo está ausente do CDC — confirmado por `comm`
bidirecional, resultado vazio nas duas direções.

---

## 9. Preservação — diff contra V1.3, classificação de cada alteração

**Verificação de preservação (automatizada):** todos os 145 `MCD-F*` da V1.3 permanecem presentes
na V1.4 (`comm -23` vazio); todos os 25 contratos CDC e os 18 erros da V1.3 permanecem presentes
na V1.4 por ID (`comm -23` vazio nas duas comparações); as 10 constraints relacionais da V1.3
permanecem presentes. **Mudança estritamente aditiva na dimensão de IDs**, exceto pela correção de
política de `MCD-F10004` (mesmo ID, mesmo significado, política corrigida — não uma remoção).

| Alteração | Classificação |
|---|---|
| `MCD-F10007..F10012` (novos campos MCD) | `CORRECAO_RECONCILIACAO_001` |
| `CDC-SEC-005` (novo contrato) | `CORRECAO_RECONCILIACAO_001` |
| Novos campos em `CDC-SEC-003`/`CDC-SEC-004` | `CORRECAO_RECONCILIACAO_001` |
| `CDC-REL-SEC-005/006/007` (novos invariantes) | `CORRECAO_RECONCILIACAO_001` |
| Correção de mutabilidade de `MCD-F10004` (MCD §8.1) | `CORRECAO_RECONCILIACAO_001` |
| Correção de mutabilidade de `unidade_economica_id` em `CDC-CAL-001` (versioned → immutable) | `CORRECAO_RECONCILIACAO_001` |
| `GAP-CDC-1.3-003`/`1.3-004` marcados parcialmente resolvidos | `CORRECAO_RECONCILIACAO_001` |
| `GAP-CDC-1.4-001` (vigência/status, residual) | `CORRECAO_RECONCILIACAO_001` — desmembramento de um gap já existente, não uma descoberta nova |
| `GAP-CDC-1.4-002` (`ContaAcesso.tipo` diferido) | `CORRECAO_RECONCILIACAO_001` — formaliza um diferimento implícito já presente em `SEC-001` §13, não uma descoberta nova |
| **Divisão de política de mutabilidade de `MCD-F10004` entre os 6 hospedeiros** (o fato de que uma política única não é sustentável) | **Achado transparente, não uma "correção simples"** — reportado explicitamente conforme instruído (§6), e resolvido nesta mesma versão através de uma nota dedicada (`MCD-001` V1.4 §8.1), não deixado como pendência |

**Nenhuma alteração fora do escopo dos 2 achados `RELEVANTE` foi introduzida.** Nenhuma
`INSCONSISTENCIA_NOVA` bloqueante foi encontrada durante a correção — a única nuance nova (divisão
de política por hospedeiro) foi imediatamente resolvida com justificativa explícita, não deixada
em aberto.

---

## 10. `COT-001` — avaliação da menção não aprovada de "vigência da concessão"

Conforme instruído, `COT-001` não foi alterado. Avaliação da menção em `COT-001` V1.2 §4
(`COT-SUP-005`: "com campo papel... e vigência da concessão"):

- **Não afeta cardinalidade** — a relação `COT-REL-131` continua N:N, inalterada.
- **Não afeta objeto** — `ContaAcessoTenant` continua a mesma estrutura de suporte, sem novo
  objeto implícito.
- **Não afeta relação** — nenhuma nova relação é implicada pela menção.

**Conclusão:** a menção **não exige correção urgente** — permanece como **recomendação editorial
separada**, não bloqueante, a ser tratada em uma futura versão do COT (remover a menção, ou abrir
um Change Request específico para aprovar formalmente um campo de vigência). Registrada também em
`CDC-001` V1.4 como `GAP-CDC-1.4-001`.

---

## 11. Gate

### Reteste específico dos 2 achados que falharam na reconciliação anterior

**Teste 1 — `ContaAcesso` + duas associações possuem representação MCD/CDC estrutural completa?**

| Verificação | Resultado |
|---|---|
| `ContaAcesso.id` existe no MCD | ✓ `MCD-F10007` |
| `ContaAcesso` tem contrato CDC | ✓ `CDC-SEC-005` |
| `ContaAcessoTenant` tem `id` | ✓ `MCD-F10009` |
| `ContaAcessoTenant` tem `conta_acesso_id` | ✓ `MCD-F10008` |
| `ContaAcessoTenant` tem `tenant_id` | ✓ `MCD-F10010` |
| `ContaAcessoUnidadeEconomica` tem `id` | ✓ `MCD-F10011` |
| `ContaAcessoUnidadeEconomica` tem `conta_acesso_id` | ✓ `MCD-F10008` (transversal) |
| `ContaAcessoUnidadeEconomica` tem `unidade_economica_id` | ✓ `MCD-F10012` |
| Ambas as associações têm contrato CDC completo (não apenas `papel`) | ✓ `CDC-SEC-003`/`CDC-SEC-004` |

**Resultado: `PASSOU`.**

**Teste 2 — `MCD-F10004` possui política de mutabilidade idêntica e semanticamente justificável em
MCD e CDC?**

| Verificação | Resultado |
|---|---|
| MCD e CDC concordam para `Receita` | ✓ `Versionado`/`versioned` |
| MCD e CDC concordam para `ContribuicaoPrevidenciaria` | ✓ `Versionado`/`versioned` |
| MCD e CDC concordam para `VinculoPrevidenciario` | ✓ `Versionado`/`versioned` |
| MCD e CDC concordam para `EventoIRPF` | ✓ `Versionado`/`versioned` |
| MCD e CDC concordam para `DocumentoFiscal` | ✓ `Versionado`/`versioned` |
| MCD e CDC concordam para `ResultadoCalculo` | ✓ `Imutável`/`immutable` |
| A política (uniforme ou dividida) tem justificativa semântica, não é escolha arbitrária | ✓ §6 acima |

**Resultado: `PASSOU`** — nota: a "identidade" exigida pelo teste não significa um único valor
para os 6 hospedeiros, e sim que MCD e CDC **concordam entre si** em cada hospedeiro,
individualmente — o que se confirma. A divisão de política entre hospedeiros foi reportada
explicitamente (§6), não mascarada.

### Verificações adicionais

| Verificação | Resultado |
|---|---|
| Nenhum objeto operacional foi promovido (`Sessao`/`PapelAcesso`/`Permissao` continuam fora do COT/MCD/CDC) | ✓ confirmado por grep negativo |
| Nenhum enum foi inventado (`papel` continua Enum/Ref aberto, `DST-GAP-015` inalterado) | ✓ |
| Nenhum ID existente foi reutilizado (`MCD-F10007..F10012`, `CDC-SEC-005`, `CDC-REL-SEC-005..007` são todos novos, sem colisão) | ✓ confirmado por diff |
| Nenhuma decisão física foi implementada (nenhum SQL, RLS, FK composta ou migration) | ✓ |
| Nenhum gap foi artificialmente fechado (`GAP-SEC-CR1-003` permanece aberto; `GAP-CDC-1.3-003`/`1.3-004` marcados parcialmente resolvidos, com residual explícito, não fechados por completo sem base) | ✓ |
| `SEC-001`, `SEC-CHANGE-REQUEST-001`, `COT-001`, `DST-001`, ADR, Prisma, migrations, banco não foram alterados | ✓ confirmado por `git status` |

Nenhum achado `CRITICAL` ou `RELEVANTE` novo foi encontrado durante esta correção.

### Conclusão

```
CORREÇÕES MCD/CDC PÓS-SEC CONCLUÍDAS — PRONTAS PARA RECONCILIAÇÃO FINAL
```

Não avancei para ADR, Prisma ou migration.
