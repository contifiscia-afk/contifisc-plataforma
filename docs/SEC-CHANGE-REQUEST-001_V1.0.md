# SEC-CHANGE-REQUEST-001 — Escopo de Alteração Canônica Derivado do SEC-001 V1.0

**Versão:** 1.0
**Status:** PROPOSTO PARA REVISÃO — especificação de escopo; **nenhuma alteração foi executada**.
**Origem normativa:** `docs/SEC-001_SEGURANCA_IDENTIDADE_AUTORIZACAO_E_ISOLAMENTO_DE_TENANT_V1.0.md`
(**APROVADO — baseline normativa de segurança da CONTIFISC**).
**Escopo:** especificar exatamente quais objetos, campos, relações e IDs precisariam ser
adicionados a `COT-001`, `MCD-001`, `CDC-001`, `DST-001` e `ADR-001` para implementar as decisões
do SEC-001 V1.0. **Este documento não altera nenhum dos documentos citados, não altera
`schema.prisma`, não cria migration, não cria banco, não implementa autenticação ou RLS.**

Nenhum ID novo proposto abaixo é atribuído definitivamente — todos são **candidatos**,
sinalizados como tal, a confirmar somente quando este Change Request for formalmente aprovado e
executado.

---

## Convenção deste documento

Cada alteração é apresentada no formato obrigatório:

```
origem normativa → objeto afetado → alteração → justificativa → documento a alterar →
impacto físico → dependências
```

Cada alteração é também marcada com uma categoria:

- **CANÔNICO** — entra em `COT`/`MCD`/`CDC`/`DST`.
- **ARQUITETURAL/FÍSICO** — pertence ao `ADR` (novo `ADR-002`, ver §Ordem recomendada).
- **SEGURANÇA** — autorização, RLS, sessão, credenciais, isolamento (conceitual; sem
  implementação).
- **DIFERIDO** — depende de `EVT-001`, `INT-001`, `OBS-001` ou de `DST-GAP-003`, ainda não
  fechados.

---

## 1-2. Novos objetos canônicos e objetos exclusivamente de segurança

| Candidato | Domínio | Natureza | Categoria |
|---|---|---|---|
| `Tenant` (`COT-OBJ-019` candidato) | `DOM-SEC` | Objeto canônico raiz — fronteira de isolamento | CANÔNICO |
| `PapelAcesso` (`COT-OBJ-020` candidato) | `DOM-SEC` | Exclusivamente de segurança — papel nomeado (role) | SEGURANÇA (conceitual) / CANÔNICO (catalogação) |
| `Permissao` (`COT-OBJ-021` candidato) | `DOM-SEC` | Exclusivamente de segurança — capacidade granular | SEGURANÇA (conceitual) / CANÔNICO (catalogação) |
| `Sessao` (`COT-OBJ-022` candidato) | `DOM-SEC` | Exclusivamente de segurança — login ativo | SEGURANÇA (conceitual) / CANÔNICO (catalogação) |
| `EventoAuditoriaSeguranca` (`COT-OBJ-023` candidato) | `DOM-SEC` | Exclusivamente de segurança — trilho de auditoria (distinto de `ConflitoDado`/`RevisaoTecnica`, que auditam domínio tributário, não segurança) | SEGURANÇA (conceitual) / CANÔNICO (catalogação) |

`ContaAcesso` (`COT-OBJ-017`) e `CredencialAcesso` (`COT-OBJ-018`) **já existem** e **não são
renomeados nem redefinidos** — este CR apenas remove o bloqueio "SEC futuro" já registrado contra
eles (`COT-001` V1.1 linha "SEC futuro"), sem especificar seus campos físicos definitivos, que
permanecem fora do escopo mínimo deste CR (ver Diferido, item 20).

## 3-4. Novas relações e cardinalidades

| # | Relação (candidata `COT-REL-*`, a partir de 121) | Cardinalidade | Categoria |
|---|---|---|---|
| 1 | `UnidadeEconomica → Tenant` | N:1 | CANÔNICO |
| 2 | `Receita → UnidadeEconomica` | N:1 | CANÔNICO |
| 3 | `ContribuicaoPrevidenciaria → UnidadeEconomica` | N:1 | CANÔNICO |
| 4 | `VinculoPrevidenciario → UnidadeEconomica` | N:1 | CANÔNICO |
| 5 | `EventoIRPF → UnidadeEconomica` | N:1 | CANÔNICO |
| 6 | `DocumentoFiscal → UnidadeEconomica` | N:1 | CANÔNICO |
| 7 | `ResultadoCalculo → UnidadeEconomica` | N:1 | CANÔNICO |
| 8 | `ArquivoOrigem → Tenant` | N:1 | CANÔNICO |
| 9 | `ConflitoDado → Tenant` | N:1 | CANÔNICO |
| 10 | `RevisaoTecnica → Tenant` | N:1 | CANÔNICO |
| 11 | `ContaAcesso ↔ Tenant` (via `COT-SUP-005` candidato) | N:N (com papel e vigência) | SEGURANÇA |
| 12 | `ContaAcesso ↔ UnidadeEconomica` (via `COT-SUP-006` candidato) | N:N opcional (restrição fina) | SEGURANÇA |
| 13 | `PapelAcesso ↔ Permissao` (via `COT-SUP-007` candidato) | N:N | SEGURANÇA |

**Nota sobre `ConflitoDadoItem`:** nenhuma relação nova — deriva tenant obrigatoriamente da
relação já existente `ConflitoDadoItem → ConflitoDado` (`conflito_dado_id`, FK real já vigente).

## 5-6. Novos campos e obrigatoriedade

| Campo candidato | Objeto | Tipo | Obrigatório? | Categoria |
|---|---|---|---|---|
| `tenant_id` | `UnidadeEconomica` | FK → `Tenant` | **Obrigatório** | CANÔNICO |
| `unidade_economica_id` | `Receita` | FK → `UnidadeEconomica` | **Obrigatório** | CANÔNICO |
| `unidade_economica_id` | `ContribuicaoPrevidenciaria` | FK → `UnidadeEconomica` | **Obrigatório** | CANÔNICO |
| `unidade_economica_id` | `VinculoPrevidenciario` | FK → `UnidadeEconomica` | **Obrigatório** | CANÔNICO |
| `unidade_economica_id` | `EventoIRPF` | FK → `UnidadeEconomica` | **Obrigatório** | CANÔNICO |
| `unidade_economica_id` | `DocumentoFiscal` | FK → `UnidadeEconomica` | **Obrigatório** | CANÔNICO |
| `unidade_economica_id` | `ResultadoCalculo` | FK → `UnidadeEconomica` | **Obrigatório** (mesmo quando `cenario_tributario_id` presente — devem ser consistentes, não mutuamente exclusivos) | CANÔNICO |
| `tenant_id` (campo transversal de segurança, item 7) | `ArquivoOrigem` | FK → `Tenant` | **Obrigatório** desde a criação | CANÔNICO + SEGURANÇA |
| `tenant_id` (idem) | `ConflitoDado` | FK → `Tenant` | **Obrigatório** | CANÔNICO + SEGURANÇA |
| `tenant_id` (idem) | `RevisaoTecnica` | FK → `Tenant` | **Obrigatório** | CANÔNICO + SEGURANÇA |

**`ConflitoDadoItem` não recebe nenhum campo novo** — tenant é sempre lido através de
`conflito_dado_id` (ver item 11).

**`ArquivoOrigem` não recebe `unidade_economica_id`** — decisão explícita do SEC-001 V1.0 §5, não
revisitada por este CR (ver item 9).

## 7. Candidato a campo transversal `tenant_id` — ID próprio

**Nenhum ID de `MCD-F9001..F9010` é reutilizado.** Proposta:

| Item | Valor candidato |
|---|---|
| ID de campo | `MCD-F9011` — **sugestão, não atribuída**; a numeração definitiva do domínio `DOM-SEC` (prefixo candidato `F10xxx`, próximo bloco de milhar livre após `DOM-SYS`/`F9xxx`) fica a critério da aprovação formal do CR. |
| Nome canônico | `tenant_id` |
| Significado | Identificador do `Tenant` (fronteira de isolamento/segurança) responsável pelo registro — aplicável apenas aos objetos que não possuem caminho de domínio confiável até `UnidadeEconomica` (`ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`). |
| Aplicabilidade | **Restrita** a esses três objetos — ao contrário de `F9001..F9010`, não é generalizável aos demais 17 objetos, que resolvem tenant por relação de domínio própria (item 8) ou por herança do pai (`ConflitoDadoItem`). |
| Distinção explícita | Nenhuma relação semântica com proveniência (`F9001`-`F9003`), estado de processamento/qualidade (`F9004`/`F9010`), registro canônico (`F9007`), data de fato (`F9008`) ou evidência RAW transversal (`F9009`). |

Categoria: **CANÔNICO** (MCD) + **ARQUITETURAL/FÍSICO** (ADR, decisão física do campo).

## 8. Relações `unidade_economica_id` determinadas pelo SEC

Já listadas no item 5 (`Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`,
`EventoIRPF`, `DocumentoFiscal`, `ResultadoCalculo`). Nenhuma relação `unidade_economica_id` é
proposta para `ArquivoOrigem`, `ConflitoDado`, `ConflitoDadoItem` ou `RevisaoTecnica` — para esses
quatro, a estratégia de segurança usa `tenant_id` (materializado ou derivado do pai), nunca UE
direta, por decisão já registrada no SEC-001 V1.0 (§5-8).

## 9-13. Mudanças específicas por objeto

| # | origem normativa | objeto afetado | alteração | justificativa | documento a alterar | impacto físico | dependências | categoria |
|---|---|---|---|---|---|---|---|---|
| 9 | SEC-001 V1.0 §5 | `ArquivoOrigem` | Adicionar `tenant_id` (obrigatório, FK candidata `MCD-F9011`); **não** adicionar `unidade_economica_id` | Camada RAW; um arquivo pode cobrir múltiplas UEs do mesmo tenant — FK única de UE seria conceitualmente errada | MCD (campo), COT (relação `ArquivoOrigem → Tenant`), CDC (contrato), ADR (decisão física + RLS conceitual) | Nova coluna `NOT NULL` + FK; nenhuma migration criada agora | Depende do candidato `MCD-F9011` (item 7) | CANÔNICO + SEGURANÇA |
| 10 | SEC-001 V1.0 §6 | `ConflitoDado` | Adicionar `tenant_id` (obrigatório, FK candidata `MCD-F9011`) | Serviço de reconciliação já opera sob um tenant conhecido; referência polimórfica não pode ser mecanismo de isolamento | MCD, COT (relação `ConflitoDado → Tenant`), CDC, ADR | Nova coluna `NOT NULL` + FK | Depende do candidato `MCD-F9011` | CANÔNICO + SEGURANÇA |
| 11 | SEC-001 V1.0 §7 | `ConflitoDadoItem` | **Nenhum campo novo.** Tenant sempre lido via `conflito_dado_id` (FK já vigente) | FK pai já é caminho canônico e unívoco; materializar seria duplicação sem benefício | Nenhuma alteração de campo — eventual nota explicativa em CDC/ADR documentando a estratégia de derivação | Nenhum | Depende da resolução do item 10 (`ConflitoDado.tenant_id`) | ARQUITETURAL/FÍSICO (documentação da estratégia, não um campo novo) |
| 12 | SEC-001 V1.0 §8 | `RevisaoTecnica` | Adicionar `tenant_id` (obrigatório, FK candidata `MCD-F9011`) | Processo de revisão opera sob tenant conhecido; identidade do revisor é auditoria separada, não fonte de tenant | MCD, COT (relação `RevisaoTecnica → Tenant`), CDC, ADR | Nova coluna `NOT NULL` + FK | Depende do candidato `MCD-F9011`; identidade do revisor continua dependente de `SEC-001`/`OBS-001` (`DST-GAP-014`, inalterado) | CANÔNICO + SEGURANÇA |
| 13 | SEC-001 V1.0 §4 | `ResultadoCalculo` | Adicionar `unidade_economica_id` (obrigatório, sempre presente); **sem** XOR com `cenario_tributario_id` | `CenarioTributario.unidade_economica_id` já é `NOT NULL` (V1 validada) — as duas FKs não competem por ownership; devem ser consistentes quando ambas presentes (item 22) | MCD, COT (relação `ResultadoCalculo → UnidadeEconomica`), CDC, ADR | Nova coluna `NOT NULL` + FK + trigger/constraint de consistência (item 22) | Nenhuma | CANÔNICO + ARQUITETURAL/FÍSICO |

## 14-17. Classificação final por estratégia de segurança

| Estratégia | Objetos | Quantidade |
|---|---|---|
| **14. Permanecem globais** (`SEM_TENANT_ID`) | `PessoaFisica`, `PessoaJuridica`, `FontePagadora` | 3 |
| **15. Derivam tenant** (`TENANT_DERIVADO_POR_RLS`, via `unidade_economica_id` próprio ou de 1 hop) | `Vinculo`, `VinculoExtremidade`, `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`, `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem`, `ClassificacaoEquiparacaoHospitalar`, `CenarioTributario`, `ResultadoCalculo` | 12 |
| **16. Materializam tenant** (`TENANT_ID_MATERIALIZADO`) | `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica` | 3 |
| **17. Derivam do pai** (`TENANT_DERIVADO_DO_PAI`) | `ConflitoDadoItem` | 1 |
| (Raiz) `TENANT_ID_RAIZ` | `UnidadeEconomica` | 1 |

## 18. Impacto sobre os 20 objetos atuais

| Tipo de impacto | Objetos | Quantidade |
|---|---|---|
| Recebem novo campo `unidade_economica_id` | `Receita`, `ContribuicaoPrevidenciaria`, `VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`, `ResultadoCalculo` | 6 |
| Recebem novo campo `tenant_id` (transversal) | `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica` | 3 |
| Recebem novo campo `tenant_id` (raiz) | `UnidadeEconomica` | 1 |
| Sem alteração de campo, apenas estratégia de RLS documentada | `PessoaFisica`, `PessoaJuridica`, `FontePagadora`, `Vinculo`, `VinculoExtremidade`, `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem`, `ClassificacaoEquiparacaoHospitalar`, `CenarioTributario`, `ConflitoDadoItem` | 10 |
| **Total** | | **20** |

Nenhum dos 20 objetos é removido, renomeado ou tem seu ownership tributário (FK de titularidade
PF/PJ já existente) alterado por este CR.

## 19. Novos objetos de autorização

Já listados no item 2 (`PapelAcesso`, `Permissao`) e no item 3 (associações `ContaAcesso ↔
Tenant`, `ContaAcesso ↔ UnidadeEconomica`, `PapelAcesso ↔ Permissao`). Vocabulário de
`PapelAcesso` (nomes de papéis) **não é fechado por este CR** — permanece Enum/Ref aberto, mesmo
padrão dos demais `DST-GAP-*` ainda não fechados, registrado como novo gap semântico a criar
(`DST-GAP` candidato, número a atribuir pelo `DST-001`) — **nenhum nome de papel é inventado
aqui**.

## 20. Impacto sobre `ContaAcesso` e `CredencialAcesso`

`COT-OBJ-017`/`COT-OBJ-018` e `COT-REL-119`/`COT-REL-120` **não mudam de definição** — este CR
apenas remove a condição "implementação bloqueada até SEC-001" já registrada contra eles, agora
satisfeita pela aprovação do SEC-001 V1.0. **A especificação física completa de seus campos
(login, tipo HUMANA/SERVICO, hash de credencial, tipos de MFA etc.) permanece fora do escopo
mínimo deste CR** — é um detalhe de implementação de autenticação (SEC-001 V1.0 §13), não uma
decisão canônica de ownership/tenant, e não deve ser transformada em decisão canônica sem
necessidade (conforme instruído). Fica registrado como **DIFERIDO** para um Change Request de
autenticação específico, futuro.

## 21. Requisitos futuros para RLS

Já formalizados conceitualmente no SEC-001 V1.0 §14 (defesa em profundidade obrigatória; risco de
conexão pooled com contexto residual). Este CR **não** escreve nenhuma policy — apenas confirma
que a matriz de estratégias (itens 14-17) é a base sobre a qual as policies físicas serão escritas
no `ADR-002` (ver Ordem recomendada). Categoria: **ARQUITETURAL/FÍSICO** (a policy em si) +
**SEGURANÇA** (o princípio).

## 22. Requisitos de integridade `tenant_id` × `unidade_economica_id`

Aplica-se a qualquer objeto que venha a ter os dois campos simultaneamente (nenhum dos quatro
objetos deste CR tem os dois — mas a regra vale para qualquer materialização futura de
performance sobre os 12 objetos "derivam tenant", item 15). Decisão arquitetural preferencial
(inalterada desde o SEC-001 V1.0 §10, repetida aqui apenas para registro de escopo):

```
(unidade_economica_id, tenant_id)
    REFERENCES unidade_economica(id, tenant_id)
```

Categoria: **ARQUITETURAL/FÍSICO** (`ADR-002`). Não implementado por este CR.

## 23. Chave candidata `(id, tenant_id)` em `UnidadeEconomica`

Necessária para viabilizar a FK composta do item 22:

```
UNIQUE (id, tenant_id)
```

Categoria: **ARQUITETURAL/FÍSICO** (`ADR-002`). Não implementado por este CR.

## 24. Impactos esperados no Prisma/PostgreSQL (sem implementar)

| Camada | Impacto esperado (futuro, não executado agora) |
|---|---|
| `schema.prisma` | 5 novos models (`Tenant`, `PapelAcesso`, `Permissao`, mais as 2-3 tabelas de associação/segurança conforme detalhamento físico); 10 novos campos escalares distribuídos em 9 models existentes (item 18); 13 novas relations (item 3-4). |
| PostgreSQL | Novas tabelas, novas colunas `NOT NULL` com FK, uma FK composta (item 22) condicionada à `UNIQUE(id, tenant_id)` (item 23), e (fase posterior, fora deste CR) `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY` por tabela, conforme a matriz de estratégias (itens 14-17). |
| Migration | Nenhuma migration nova é criada por este CR — apenas escopo para uma futura migration física (item 25). |

## 25. Impacto sobre a nova baseline física pós-SEC

Confirma a decisão já registrada no SEC-001 V1.0 §19 (Decisão B): a migration
`20260901120000_init_baseline_fisica` permanece artefato histórico pré-SEC, nunca aplicada a
banco persistente. Após a aprovação física deste CR (ADR-002 + atualização de `schema.prisma`),
uma **nova baseline física definitiva única** deve ser gerada, incorporando desde a origem: os 20
objetos tributários já validados na V1 (inalterados em sua lógica interna) **mais** `Tenant`,
`PapelAcesso`, `Permissao`, as associações de autorização, os 10 novos campos do item 18, a FK
composta do item 22-23, e (havendo aprovação física explícita e separada) as policies RLS. Essa
migration **não é criada agora**.

---

## Separação por categoria (consolidado)

### CANÔNICO (COT/MCD/CDC/DST)
Itens 1 (`Tenant`), 2 (`PapelAcesso`/`Permissao`/`Sessao`/`EventoAuditoriaSeguranca`, catalogação),
3-4 (13 relações), 5-6 (10 campos novos), 7 (`MCD-F9011` candidato), 8, 9, 10, 12, 13, 19
(catalogação de `PapelAcesso`/`Permissao`, sem fechar vocabulário).

### ARQUITETURAL/FÍSICO (ADR-002, novo)
Decisões físicas de FK/tipo para os itens acima; item 11 (documentação da estratégia de derivação
de `ConflitoDadoItem`); item 21 (policies RLS); item 22 (FK composta); item 23 (chave candidata);
item 24 (impacto Prisma/PostgreSQL); item 25 (nova baseline física).

### SEGURANÇA (conceitual, sem implementação)
Itens 2 (natureza dos objetos de segurança), 3-4 (relações 11-13, `ContaAcesso ↔ Tenant`/`UE`),
9-10-12 (uso de `tenant_id` materializado), 19 (arquitetura de autorização), 21 (princípio de
defesa em profundidade).

### DIFERIDO
- Especificação física completa de `ContaAcesso`/`CredencialAcesso` (item 20) — Change Request de
  autenticação futuro, separado.
- Fechamento do vocabulário de `PapelAcesso` — depende de decisão de produto/negócio, não deste
  CR.
- `Vinculo` sem nenhuma extremidade `UnidadeEconomica` — depende de `DST-GAP-003` (inalterado,
  não fechado por este CR).
- Identidade/autorização do revisor de `RevisaoTecnica` — depende de `OBS-001` (`DST-GAP-014`,
  inalterado).
- F9005/F9006 (`versao_schema`/`correlation_id`) — dependem de `EVT-001`/`INT-001`, sem relação
  com este CR além de compartilharem o domínio `DOM-SYS`.

---

## Matriz de rastreabilidade SEC-001 V1.0 → CR → Documento

| Seção SEC-001 V1.0 | Item(ns) deste CR | Documento(s) de destino |
|---|---|---|
| §1 (Definições normativas) | — (conceitual, sem campo/objeto físico próprio) | Nenhum — já expresso na linguagem do SEC-001; referenciado por COT/MCD ao introduzir `Tenant` |
| §2 (`Cliente/Organização` redundante) | — | Nenhum objeto novo a criar (confirmação negativa) |
| §3 (Identidades globais) | 14 | Nenhuma alteração de campo — apenas confirmação de estratégia em ADR-002 |
| §4 (Contextualização econômica) | 5, 6, 8, 13 | MCD, COT, CDC, ADR-002 |
| §5 (`ArquivoOrigem`) | 9 | MCD, COT, CDC, ADR-002 |
| §6 (`ConflitoDado`) | 10 | MCD, COT, CDC, ADR-002 |
| §7 (`ConflitoDadoItem`) | 11 | ADR-002 (documentação, sem campo) |
| §8 (`RevisaoTecnica`) | 12 | MCD, COT, CDC, ADR-002 |
| §9 (`tenant_id` × `unidade_economica_id`) | 7, 22 | MCD (campo `F9011` candidato), ADR-002 (regra de consistência) |
| §10 (FK composta) | 22, 23 | ADR-002 |
| §11 (Matriz 20/20) | 14-18 | ADR-002 (mapa físico consolidado) |
| §12 (Autorização) | 1, 2, 3 (itens 11-13) | COT, MCD, CDC (catalogação); ADR-002 (físico); SEGURANÇA (princípios) |
| §13 (Autenticação) | 20 | DIFERIDO — Change Request de autenticação futuro |
| §14 (RLS) | 21 | ADR-002 |
| §15 (Jobs/integrações) | — | Nenhuma alteração canônica — princípio operacional, sem campo/objeto |
| §16 (Auditoria) | 2 (`EventoAuditoriaSeguranca`) | COT, MCD, CDC |
| §17 (LGPD) | — | Nenhuma alteração canônica neste CR — princípio, não estrutura de dado nova |
| §18 (Ambientes/secrets) | — | Nenhuma alteração canônica — prática operacional |
| §19 (Migration baseline) | 25 | Nenhum documento canônico — apenas confirmação de processo |
| §20 (Dependências futuras) | Seção "Diferido" | `DST-GAP-003`, `OBS-001`, `EVT-001`, `INT-001` (inalterados) |

## Ordem recomendada de atualização documental

Para evitar inconsistência temporária entre os documentos (ex.: MCD referenciando um objeto que o
COT ainda não catalogou), a ordem recomendada segue a mesma cadeia de dependência já usada neste
projeto ("COT define o que existe; MCD define os dados; CDC define contratos; DST define
significado; ADR define a implementação física"):

1. **`COT-001`** — catalogar `Tenant`, `PapelAcesso`, `Permissao`, `Sessao`,
   `EventoAuditoriaSeguranca` e as 13 relações (itens 1-4) primeiro, para que os demais
   documentos tenham um objeto/relação já existente ao qual referenciar.
2. **`MCD-001`** — catalogar os 10 novos campos (item 5-6) e o campo transversal candidato
   `MCD-F9011` (item 7), agora que os objetos/relações já existem no COT.
3. **`CDC-001`** — contratos (direção, obrigatoriedade, mutabilidade) para os campos/objetos já
   catalogados nos passos 1-2.
4. **`DST-001`** — vocabulário/semântica (ex.: registrar o novo gap aberto de `PapelAcesso`, sem
   fechá-lo) para os termos introduzidos.
5. **`ADR-001`** (via novo `ADR-002` dedicado) — decisões físicas: tipos, FKs, FK composta
   (item 22-23), estratégia de RLS por objeto (item 21), impacto em `schema.prisma` (item 24).

Nenhum desses cinco passos é executado por este documento.

---

## Verificação interna

| Verificação | Resultado |
|---|---|
| Todas as decisões normativas relevantes do SEC-001 V1.0 possuem destino documental | ✓ — ver matriz de rastreabilidade; as únicas linhas "Nenhum" correspondem a princípios operacionais (§15, §17, §18) que não introduzem campo/objeto novo, não a decisões sem destino |
| Nenhuma decisão nova foi introduzida sem origem no SEC-001 V1.0 | ✓ — cada item 1-25 cita a seção correspondente do SEC-001 V1.0 |
| Nenhum ID existente foi reutilizado | ✓ — `MCD-F9011`, `COT-OBJ-019..023`, `COT-SUP-005..007`, `COT-REL-121..133` são todos candidatos em faixas ainda livres, nenhum reaproveita `F9001..F9010` nem IDs `COT-*` já atribuídos |
| Nenhuma alteração física foi implementada | ✓ — nenhum `schema.prisma`, `ADR-001`, migration ou banco foi tocado |
| Nenhuma migration foi modificada | ✓ — `20260901120000_init_baseline_fisica` permanece intocada |
| Nenhum gap tributário foi resolvido indevidamente | ✓ — `DST-GAP-003` (tipo_vinculo), `DST-GAP-014` (identidade do revisor) e o vocabulário de `PapelAcesso` permanecem explicitamente abertos, não fechados por inferência |

Nenhuma inconsistência real foi encontrada.

**SEC-CHANGE-REQUEST-001 V1.0 PRONTO PARA REVISÃO**
