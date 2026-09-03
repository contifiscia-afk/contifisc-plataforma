# SEC-CR-001 — Reconciliação Final da Baseline Canônica Pós-SEC

**Versão:** 1.0
**Status:** RELATÓRIO DE AUDITORIA FINAL — não altera nenhum documento normativo, ADR, Prisma,
migration ou banco. Não é uma nova revisão arquitetural.
**Fontes vigentes auditadas:** `SEC-001` V1.0, `SEC-CHANGE-REQUEST-001` V1.1, `COT-001` V1.2,
`MCD-001` V1.4, `DST-001` V1.3, `CDC-001` V1.4, `SEC-CR-001_RECONCILIACAO_CRUZADA_CANONICA_V1.0.md`,
`SEC-CR-001_CORRECAO_MCD_CDC_V1.0.md`.
**Objetivo exclusivo:** confirmar que a correção coordenada de `MCD-001`/`CDC-001` (V1.3 → V1.4)
eliminou os 2 achados `RELEVANTE` da reconciliação anterior, sem introduzir regressão.
**Método:** verificação programática (`grep`/contagem de IDs únicos) sobre o texto real dos seis
documentos vigentes, sem reaproveitar nenhuma contagem de relatórios anteriores.

---

## Resumo executivo

Os dois achados `RELEVANTE` da reconciliação cruzada anterior estão **RESOLVIDOS**. A correção
`MCD-001`/`CDC-001` V1.4 é estritamente aditiva sobre a V1.3 (nenhum ID removido, nenhum campo
aposentado retornou), coordenada entre os dois documentos (nenhuma divergência nova MCD × CDC), e
não introduziu nenhuma regressão nas invariantes de `SEC-001` já verificadas na reconciliação
anterior. Nenhum achado `CRITICAL` ou `RELEVANTE` novo foi encontrado.

```
BASELINE CANÔNICA PÓS-SEC RECONCILIADA — APTA PARA ADR
```

---

## 1. Contagens recalculadas (nenhuma reaproveitada de relatório anterior)

| Item | Contagem (esta auditoria) | Fonte |
|---|---|---|
| Objetos COT (`COT-OBJ-*`) | **20** | `COT-001` V1.2 (inalterado) |
| Estruturas de suporte COT (`COT-SUP-*`) | **6** | `COT-001` V1.2 (inalterado) |
| Relações COT (`COT-REL-101..132`, faixa vigente) | **32** | `COT-001` V1.2 (inalterado) |
| Campos MCD (`MCD-F*`, únicos) | **151** | `MCD-001` V1.4 (145 + 6 desta correção) |
| Termos DST (`DST-T*`) | **37** | `DST-001` V1.3 (inalterado) |
| Enums DST (`DST-E*`) | **12** (`E001..E012`, sem lacuna) | `DST-001` V1.3 (inalterado) |
| Gaps DST (`DST-GAP-*`) | **15** | `DST-001` V1.3 (inalterado) |
| Contratos CDC (incluindo `CDC-REL-001`/`002`, que são contratos, não constraints) | **26** | `CDC-001` V1.4 (25 + `CDC-SEC-005`) |
| Erros CDC (`CDC-ERR-*`) | **18** | `CDC-001` V1.4 (inalterado desde a V1.3) |
| Constraints/invariantes relacionais CDC (`CDC-REL-XXX-NNN`) | **13** | `CDC-001` V1.4 (10 + `CDC-REL-SEC-005/006/007`) |
| Gaps CDC (`GAP-CDC-*`) | **11** | `CDC-001` V1.4 (9 + `GAP-CDC-1.4-001/002`) |

`COT-001` e `DST-001` confirmados **bit-a-bit inalterados** nesta rodada — nenhuma linha destes
dois documentos foi tocada desde a reconciliação anterior (confirmado por `git status`: nenhum
desses dois arquivos aparece em nenhum commit desde `SEC-CR-001_CORRECAO_MCD_CDC_V1.0.md`).

---

## 2. Reteste do antigo achado `RELEVANTE` nº 1 — `ContaAcesso` e associações

| Verificação | `ContaAcesso` | `ContaAcessoTenant` | `ContaAcessoUnidadeEconomica` |
|---|---|---|---|
| Identidade (`id`) | `MCD-F10007` ✓ | `MCD-F10009` ✓ | `MCD-F10011` ✓ |
| FK canônica para `ContaAcesso` | n/a | `conta_acesso_id` = `MCD-F10008` ✓ | `conta_acesso_id` = `MCD-F10008` ✓ (mesmo ID, transversal) |
| FK canônica para o segundo lado | n/a | `tenant_id` = `MCD-F10010` ✓ | `unidade_economica_id` = `MCD-F10012` ✓ |
| `papel` | n/a | `MCD-F10005` ✓ (reuso do já existente) | `MCD-F10005` ✓ (idem) |
| Cardinalidade | 1 (referenciado N vezes) | N:1 para `ContaAcesso`, N:1 para `Tenant` (associação N:N materializada) | N:1 para `ContaAcesso`, N:1 para `UnidadeEconomica` |
| Unicidade lógica | n/a | `(conta_acesso_id, tenant_id)` — `CDC-REL-SEC-005` ✓ | `(conta_acesso_id, unidade_economica_id)` — `CDC-REL-SEC-006` ✓ |
| Dependência da autorização por UE em relação ao Tenant | n/a | é o pré-requisito | `CDC-REL-SEC-007`: toda linha pressupõe uma linha de `ContaAcessoTenant` para o mesmo par (`ContaAcesso`, Tenant-da-UE) ✓ |
| Contrato CDC | `CDC-SEC-005` ✓ | `CDC-SEC-003` (completo) ✓ | `CDC-SEC-004` (completo) ✓ |

**`ContaAcesso` possui somente identidade canônica mínima:** confirmado por grep — o contrato
`CDC-SEC-005` tem exatamente uma linha de campo (`id`); nenhum atributo operacional de
autenticação (senha, hash, OAuth, refresh token, MFA, sessão, tipo `HUMANA`/`SERVICO`) foi
incorporado. `ContaAcesso.tipo` permanece explicitamente diferido (`GAP-CDC-1.4-002`).

**`CredencialAcesso` permanece diferido:** confirmado — nenhum campo MCD, nenhum contrato CDC.
Verificado nesta auditoria que nada na correção V1.4 criou necessidade estrutural para
`CredencialAcesso`.

**Classificação: `RESOLVIDO`.**

---

## 3. Reteste do antigo achado `RELEVANTE` nº 2 — mutabilidade de `MCD-F10004`

Auditoria das 6 ocorrências, comparando a linha de tabela do MCD e a linha de tabela
correspondente em cada contrato CDC:

| Hospedeiro | Política MCD (`MCD-001` V1.4 §8.1) | Política CDC (`CDC-001` V1.4) | Coincidem? |
|---|---|---|---|
| `Receita` (`CDC-REC-001`) | `Versionado` | `versioned` | ✓ |
| `ContribuicaoPrevidenciaria` (`CDC-PRE-001`) | `Versionado` | `versioned` | ✓ |
| `VinculoPrevidenciario` (`CDC-PREV-001`) | `Versionado` | `versioned` | ✓ |
| `EventoIRPF` (`CDC-IRP-001`) | `Versionado` | `versioned` | ✓ |
| `DocumentoFiscal` (`CDC-FIS-001`) | `Versionado` | `versioned` | ✓ |
| `ResultadoCalculo` (`CDC-CAL-001`) | `Imutável` | `immutable` | ✓ |

**Confirmado por grep direto nas 6 linhas de tabela do CDC:** exatamente 5 ocorrências de
`unidade_economica_id | MCD-F10004 | ... | versioned` e exatamente 1 ocorrência de
`... | immutable`. Nenhuma contradição MCD × CDC restante.

**Mesma semântica canônica preservada:** a correção alterou apenas a coluna de política de
mutabilidade — nome, tipo, cardinalidade e obrigatoriedade de `MCD-F10004` permanecem idênticos
nos 6 hospedeiros (confirmado por diff textual contra a V1.3, `SEC-CR-001_CORRECAO_MCD_CDC_V1.0.md`
§9). A verificação de uniformidade semântica de `DST-001` V1.3 §11.1 ("mesma pergunta respondida
nos 6 hospedeiros") permanece válida e não foi contradita pela correção de política física.

**Princípio explicitado (conforme instruído):**

> Mesmo ID semântico transversal ≠ obrigação de mesma política de mutabilidade em todos os
> hospedeiros.

Este princípio está agora documentado explicitamente em `MCD-001` V1.4 §8.1, com justificativa
individual por hospedeiro — não é uma exceção silenciosa, é uma regra declarada: um campo
transversal (mesmo ID, mesmo significado) pode ter política de mutabilidade física diferente por
hospedeiro quando a filosofia de mutabilidade pré-existente de um hospedeiro específico (aqui,
`ResultadoCalculo` como snapshot reproduzível) justificar a exceção.

**Classificação: `RESOLVIDO`.**

---

## 4. Regressão MCD × CDC

Reconciliação programática completa dos 151 IDs `MCD-F*` vigentes contra `CDC-001` V1.4:

| Verificação | Resultado |
|---|---|
| MCD sem CDC | **Nenhum** — checagem bidirecional (`comm -23`) vazia |
| CDC sem MCD | **Nenhum** — checagem bidirecional (`comm -13`) vazia |
| IDs duplicados no catálogo MCD (mesma linha de tabela repetida com conteúdo diferente) | **Nenhum** — cada `MCD-F*` aparece exatamente uma vez como linha de catálogo |
| Campos aposentados reintroduzidos (`MCD-F2506..2509`, `F3006`, `F3009`, `F4008`) | **Nenhum** — busca vazia em `MCD-001` V1.4 e `CDC-001` V1.4 |
| Campo em objeto incorreto | **Nenhum** — hospedeiros de cada campo transversal (`MCD-F10003`→3, `MCD-F10004`→6, `MCD-F10005`→2, `MCD-F10008`→2) conferem exatamente com a lista aprovada |
| Divergência de nullability/obrigatoriedade | **Nenhuma** — todos os 12 campos `DOM-SEC` (`MCD-F10001..F10012`) são "Sim" no MCD e "required" no CDC, sem exceção |
| Divergência de mutabilidade | **Nenhuma restante** — a única divergência conhecida (`MCD-F10004`) foi resolvida (§3) |
| Divergência semântica | **Nenhuma** — nenhum campo teve seu significado alterado pela correção |

**Campos transversais legítimos (múltiplos hospedeiros, mesmo papel) confirmados, sem
duplicidade indevida:**

| Campo | Hospedeiros | Papel único confirmado |
|---|---|---|
| `MCD-F10003` | `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica` | "a qual fronteira de segurança este registro pertence" (metadado operacional) |
| `MCD-F10004` | `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`, `ResultadoCalculo` | "sob qual UE este fato é administrado" |
| `MCD-F10005` | `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica` | "papel da concessão/restrição" |
| **`MCD-F10008`** *(novo nesta correção)* | `ContaAcessoTenant`, `ContaAcessoUnidadeEconomica` | "a qual `ContaAcesso` esta linha se refere" — mesma pergunta nos 2 hospedeiros, papel idêntico, não uma reutilização indevida |

Nenhum dos IDs próprios de hospedeiro único (`MCD-F10001`, `MCD-F10002`, `MCD-F10006`,
`MCD-F10007`, `MCD-F10009`, `MCD-F10010`, `MCD-F10011`, `MCD-F10012`) foi indevidamente
compartilhado entre objetos diferentes.

**Conclusão da seção: nenhuma regressão encontrada.**

---

## 5. Regressão COT × MCD × CDC

Cadeia estrutural `COT → MCD → CDC` para os elementos de segurança, reverificada:

| Elemento COT | MCD | CDC | Cadeia coerente? |
|---|---|---|---|
| `COT-OBJ-017` (`ContaAcesso`) | `MCD-F10007` | `CDC-SEC-005` | ✓ |
| `COT-OBJ-018` (`CredencialAcesso`) | nenhum (diferido, confirmado deliberado) | nenhum contrato (diferido) | ✓ — ausência consistente em ambas as camadas, não uma lacuna assimétrica |
| `COT-OBJ-019` (`Tenant`) | `MCD-F10001` | `CDC-SEC-001` | ✓ (inalterado desde a V1.3) |
| `COT-OBJ-020` (`EventoAuditoriaSeguranca`) | `MCD-F10006` | `CDC-SEC-002` | ✓ (inalterado) |
| `COT-SUP-005` (`ContaAcessoTenant`) | `MCD-F10005`, `F10008`, `F10009`, `F10010` | `CDC-SEC-003` | ✓ — **antes incompleta, agora completa** |
| `COT-SUP-006` (`ContaAcessoUnidadeEconomica`) | `MCD-F10005`, `F10008`, `F10011`, `F10012` | `CDC-SEC-004` | ✓ — **antes incompleta, agora completa** |
| `COT-REL-131` (`ContaAcesso ↔ Tenant`) | materializada via `ContaAcessoTenant`, agora com FKs reais | `CDC-SEC-003` | ✓ — a relação COT agora depende de estrutura MCD/CDC que **existe** |
| `COT-REL-132` (`ContaAcesso ↔ UnidadeEconomica`) | materializada via `ContaAcessoUnidadeEconomica`, agora com FKs reais | `CDC-SEC-004` | ✓ — idem |

**Nenhuma relação COT depende de estrutura inexistente no MCD/CDC** — esta era exatamente a
condição que falhava na reconciliação anterior (`COT-REL-131`/`132` dependiam de estruturas de
suporte sem identidade/FK própria) e que agora está satisfeita.

**Conclusão da seção: cadeia estrutural coerente, regressão anterior corrigida, nenhuma nova
quebra encontrada.**

---

## 6. DST

| Verificação | Resultado |
|---|---|
| Nenhum enum novo surgiu | ✓ — `DST-E001..E012` idênticos; nenhuma referência a um `DST-E013` ou equivalente em `MCD-001` V1.4/`CDC-001` V1.4 |
| `DST-GAP-015` (`papel`) permanece aberto | ✓ — confirmado nos três documentos (`DST-001`, `MCD-001` V1.4, `CDC-001` V1.4): `papel` continua Enum/Ref aberto, nenhum catálogo fechado, nenhuma tentativa de fechamento por inferência |
| Nenhum gap DST antigo foi fechado por consequência acidental da correção | ✓ — `DST-GAP-001..014` não são mencionados em nenhuma parte de `MCD-001` V1.4/`CDC-001` V1.4 relativa à correção; `DST-001` em si não foi tocado |
| Nenhum conceito operacional foi promovido | ✓ — busca negativa confirma que `Sessao`, `PapelAcesso`, `Permissao` não aparecem como `COT-OBJ-*`, `MCD-F*` ou `CDC-*` em nenhum dos documentos vigentes |

**Conclusão: `FECHADO`, sem regressão.**

---

## 7. Invariantes de `SEC-001` — reverificação

| Invariante | Status |
|---|---|
| `tenant_id ≠ unidade_economica_id` | ✓ Mantido — `MCD-F10002`/`F10003` (tenant) permanecem distintos de `MCD-F10004` (UE); a correção acrescentou `MCD-F10010` (tenant de concessão) e `MCD-F10012` (UE de restrição), ambos também distintos entre si e dos quatro campos pré-existentes |
| `PessoaFisica`/`PessoaJuridica` ≠ `ContaAcesso` | ✓ Mantido — `CDC-PER-001`/`CDC-EMP-001` continuam sem nenhum campo de acesso; `CDC-SEC-005` (`ContaAcesso`) é um contrato inteiramente separado |
| `ContaAcesso × Tenant` = concessão básica | ✓ Mantido e agora estruturalmente completo (`CDC-SEC-003`) |
| `ContaAcesso × UnidadeEconomica` = restrição adicional | ✓ Mantido e agora estruturalmente completo (`CDC-SEC-004`), com a dependência formalizada (`CDC-REL-SEC-007`) |
| `ConflitoDadoItem` deriva tenant do pai | ✓ Mantido — confirmado por grep, nenhum campo `tenant_id` foi adicionado a `ConflitoDadoItem`/`CDC-CFD-002` |
| `ResultadoCalculo` sem XOR entre `cenario_tributario_id`/`unidade_economica_id` | ✓ Mantido — `CDC-REL-SEC-003` inalterado; a correção de mutabilidade (§3) não introduziu nenhuma exclusividade |
| Referências polimórficas não determinam ownership | ✓ Mantido — nenhuma alteração tocou `ConflitoDadoItem.objeto_id`/`tipo_objeto` ou `RevisaoTecnica.objeto_revisado_id`/`tipo_objeto_revisado` |

**Nenhuma regressão nas invariantes de `SEC-001`.**

---

## 8. Reavaliação dos achados não bloqueantes anteriores (status apenas, sem correção)

| Achado | Status |
|---|---|
| Obrigatoriedade de `ResultadoCalculo.unidade_economica_id` (`GAP-SEC-CR1-003`) | `CONTINUA_GAP_CONTROLADO` — a análise de mutabilidade (§3) reforça, sem provar, que o campo faz parte de um conjunto fechado de inputs do snapshot; a obrigatoriedade não foi alterada; o gap permanece registrado e aberto, não fechado por inferência |
| Rastreamento de `SEC-001` §15 (contexto de tenant explícito em jobs/integrações) | `CONTINUA_GAP_CONTROLADO` — nenhum documento canônico ganhou um campo ou gap formal para isso nesta rodada, pois não é uma decisão de campo/objeto canônico; permanece uma nota de implementação futura (Gateway/Skills), não estrutural |
| Expressão "vigência da concessão" em `COT-001` §4 (`COT-SUP-005`) | `CONTINUA_GAP_CONTROLADO` — desmembrado formalmente em `GAP-CDC-1.4-001` pela correção; não afeta cardinalidade, objeto ou relação (confirmado em `SEC-CR-001_CORRECAO_MCD_CDC_V1.0.md` §10); recomendação editorial separada para uma futura versão do COT, **não** promovida a bloqueio |

Nenhum destes três itens foi transformado em bloqueio sem razão estrutural — todos permanecem
`GAP_CONTROLADO`, consistente com sua natureza (nenhum impede schema físico válido hoje).

---

## 9. Gate

| Achado | Severidade |
|---|---|
| — | `CRITICAL`: **0** |
| — | `RELEVANTE`: **0** |
| Obrigatoriedade de `ResultadoCalculo.unidade_economica_id` ainda não confirmada empiricamente (`GAP-SEC-CR1-003`) | `NAO_BLOQUEANTE` |
| `SEC-001` §15 sem gap de rastreamento formal | `NAO_BLOQUEANTE` |
| "Vigência da concessão" em `COT-001` §4 (`GAP-CDC-1.4-001`) | `EDITORIAL` |
| `ContaAcesso.tipo` (HUMANA/SERVICO) diferido (`GAP-CDC-1.4-002`) | `NAO_BLOQUEANTE` — decisão consciente, aguardando Change Request de autenticação/RBAC |

**Contagem do gate:** `CRITICAL = 0`, `RELEVANTE = 0`.

### Conclusão do gate

```
BASELINE CANÔNICA PÓS-SEC RECONCILIADA — APTA PARA ADR
```

Nenhuma correção adicional foi feita por este relatório. Não avancei para ADR, Prisma ou
migration.
