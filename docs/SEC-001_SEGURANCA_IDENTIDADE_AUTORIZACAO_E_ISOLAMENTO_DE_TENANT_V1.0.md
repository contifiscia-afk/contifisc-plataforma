# SEC-001 — Segurança, Identidade, Autorização e Isolamento de Tenant

**Versão:** 1.0
**Status:** CONSOLIDADO — PRONTO PARA APROVAÇÃO NORMATIVA (não é ainda ADR/MCD/COT/CDC/DST
aprovado; consolida decisões arquiteturais para decisão formal).
**Tipo:** Architecture Decision Record (proposta consolidada, pré-ADR de segurança).
**Escopo:** decisões conceituais de arquitetura de segurança, identidade, autorização e
isolamento de tenant. **Não implementa código, não cria Change Request, não altera COT-001,
MCD-001, CDC-001, DST-001 ou ADR-001, não altera `schema.prisma`, não cria migration, não toca
banco, não implementa autenticação ou RLS.**

**Material histórico consolidado por este documento** (ver §21 — não alterados, permanecem no
repositório como registro do processo decisório):
- `SEC-001_PROPOSTA_ARQUITETURAL_V1.md`
- `SEC-001_ADENDO_DECISORIO_V2.md`
- `SEC-001_AUDITORIA_CONSISTENCIA_V1.md`
- `SEC-001_RESOLUCAO_FINAL_V1.md`

Este documento contém **apenas decisões finais vigentes**. Alternativas comparadas e rejeitadas
durante o processo decisório (isolamento só na aplicação, `tenant_id` generalizado em todas as
tabelas, XOR entre `unidade_economica_id`/`cenario_tributario_id`, derivação de tenant via
referência polimórfica, reaproveitamento de `MCD-F9001..F9010`, entidade `Cliente/Organização`
separada de `Tenant`, entre outras) não são reproduzidas aqui como se ainda estivessem em aberto
— constam apenas nos documentos históricos listados acima.

---

## 1. Definições normativas

| Termo | Definição vigente |
|---|---|
| **`Tenant`** | Fronteira técnica de isolamento, segurança e propriedade lógica dos dados. **Não representa** `PessoaFisica`, `PessoaJuridica`, `UnidadeEconomica`, um usuário individual, nem necessariamente um cliente comercial. |
| **`UnidadeEconomica`** | Contexto econômico/tributário (definição já vigente em `COT-OBJ-001`/`MCD-001`, inalterada por este documento). |
| **`ContaAcesso`** | Identidade utilizada para autenticação/autorização, separada da identidade tributária. Já catalogada como `COT-OBJ-017` (`COT-001` V1.1); este documento formaliza a arquitetura em torno dela, sem renomeá-la. |

**Princípio normativo central:**

```
identidade tributária ≠ identidade de acesso ≠ tenant ≠ unidade econômica
```

Os quatro eixos respondem perguntas diferentes e nunca colapsam um no outro:
"de quem é este fato" (identidade tributária, PF/PJ) ≠ "quem está operando o sistema"
(identidade de acesso, `ContaAcesso`) ≠ "a qual fronteira de isolamento este dado pertence"
(`tenant`) ≠ "a qual contexto econômico/tributário este dado se refere" (`UnidadeEconomica`).

## 2. `Cliente`/`Organização`

**Decisão: `Cliente/Organização = REDUNDANTE_NESTA_FASE`.** Nenhuma entidade canônica separada de
`Tenant` é criada. `Tenant` cobre integralmente o requisito atual de agregação de 1..N
`UnidadeEconomica` sob uma mesma fronteira de isolamento.

## 3. Identidades globais

`PessoaFisica`, `PessoaJuridica` e `FontePagadora` **podem funcionar como identidades globais
compartilháveis entre contextos** (tenants) — nenhuma delas adquire ownership de tenant
automaticamente pela sua própria existência. O acesso aos **fatos** relacionados a elas (Receita,
Vínculo, Evento IRPF etc.) é determinado exclusivamente pelo contexto tenant-scoped **desses
fatos**, nunca pela simples existência de um vínculo/FK com a PF/PJ/FontePagadora.

## 4. Contextualização econômica dos fatos

Distinção normativa: **titular tributário do fato** (quem legalmente possui o fato — PF/PJ, já
resolvido pelo MCD/CDC vigente, `ADR-C001`) é diferente de **contexto econômico da ocorrência**
(sob qual `UnidadeEconomica` o fato está sendo administrado/apurado).

**Decisão:** as seguintes ocorrências canônicas requerem relação explícita com
`UnidadeEconomica`, distinta e adicional ao FK de titularidade tributária já existente:

| Objeto | Relação com `UnidadeEconomica` |
|---|---|
| `Receita` | Direta e obrigatória. |
| `ContribuicaoPrevidenciaria` | Direta e obrigatória. |
| `VinculoPrevidenciario` | Direta e obrigatória. |
| `EventoIRPF` | Direta e obrigatória. |
| `DocumentoFiscal` | Direta e obrigatória, própria (não apenas derivada de `Receita` associada). |
| `ResultadoCalculo` | Direta e obrigatória, sempre presente — inclusive quando associado a um `CenarioTributario` (que já identifica `UnidadeEconomica` de forma obrigatória desde a migration V1 validada; os dois valores devem ser consistentes entre si, não mutuamente exclusivos). |

**Nenhum ID de campo MCD é atribuído nesta etapa** — a formalização de IDs, nomes de campo e
contratos CDC/ADR fica para o `SEC-CHANGE-REQUEST-001` (§20).

## 5. `ArquivoOrigem`

- Pertence à **zona RAW** (evidência imutável, conforme distinção RAW/Canonical/Derived já
  estabelecida pela Errata controlada nº2 do `ADR-001`).
- `tenant_id` **obrigatório desde a ingestão** — obtido do **contexto autenticado/autorizado da
  operação** que realiza o upload/importação/coleta (a `ContaAcesso` ou conta de serviço já opera
  sob um `Tenant` conhecido antes mesmo de o arquivo existir), nunca inferido do conteúdo do
  arquivo.
- **Não exige `unidade_economica_id` direto.** Um único arquivo pode conter informações de
  múltiplas `UnidadeEconomica` pertencentes ao **mesmo** tenant (ex.: extrato consolidado de um
  grupo econômico) — uma FK direta e única para UE seria estruturalmente incorreta nesse caso.
- A identificação de qual(is) UE(s) o conteúdo do arquivo pertence ocorre **posteriormente**, na
  normalização/canonicalização (materializada em `DocumentoFiscal.unidade_economica_id`, §4) —
  nunca na camada RAW.
- O registro lógico (a linha `ArquivoOrigem`) é **tenant-scoped**; a deduplicação **física** dos
  bytes no armazenamento pode existir **desde que não produza compartilhamento de
  autorização** — dois tenants nunca compartilham a mesma linha lógica, mesmo que apontem para o
  mesmo blob físico deduplicado.
- **Regra absoluta:** acesso nunca é concedido por igualdade de hash. `object key`/URL de
  armazenamento **não constituem autorização** — todo acesso a bytes é mediado pela verificação
  do tenant do registro lógico correspondente, nunca por posse de uma chave/URL.

## 6. `ConflitoDado`

- `tenant_id` **materializado** (coluna própria).
- Proveniente do **contexto seguro da operação de reconciliação** que cria o registro — **não
  escolhido arbitrariamente pelo serviço**, e sim herdado do contexto de tenant sob o qual esse
  serviço já está operando no momento da criação.
- **Não derivado da referência polimórfica** (`objeto_id`/`tipo_objeto`) — essa referência
  permanece exclusivamente um mecanismo de auditoria/reconciliação, nunca de ownership/isolamento.
- **Conflito cross-tenant é proibido por padrão** — nenhum `ConflitoDado` pode legitimamente
  agregar itens de tenants diferentes, salvo requisito de negócio explícito futuro (inexistente
  hoje).

## 7. `ConflitoDadoItem`

- **Sem `tenant_id` próprio.**
- Tenant **derivado obrigatoriamente de `ConflitoDado`** (via `conflito_dado_id`, FK real já
  existente e obrigatória).
- Essa FK pai constitui o **caminho canônico** para isolamento deste objeto — não há necessidade
  nem justificativa para materialização redundante.
- A referência polimórfica própria do item (`objeto_id`/`tipo_objeto`) **não constitui
  ownership** — continua exclusivamente um mecanismo de auditoria/reconciliação.

## 8. `RevisaoTecnica`

- `tenant_id` **materializado** (coluna própria).
- Proveniente do **contexto autenticado/autorizado da operação** de revisão — a identidade do
  revisor (quem, especificamente, realizou a revisão) é registrada **separadamente**, para fins
  de auditoria, e **não é a fonte livre do valor de tenant** (o tenant vem do contexto de
  sessão/autorização da operação, não é inferido ou escolhido a partir de quem é o revisor).
- A referência polimórfica (`objeto_revisado_id`/`tipo_objeto_revisado`) **permanece mecanismo de
  revisão/auditoria**, nunca de ownership/isolamento.

## 9. `tenant_id` × `unidade_economica_id`

```
tenant_id             = fronteira/contexto de segurança
unidade_economica_id  = contexto econômico/tributário
```

Os dois campos **não são semanticamente equivalentes** e nunca devem ser tratados como
intercambiáveis. Quando ambos coexistirem na mesma tabela, devem ser **estruturalmente
consistentes entre si** (ver §10).

## 10. Integridade de banco — decisão arquitetural preferencial

Para qualquer tabela onde `tenant_id` e `unidade_economica_id` coexistam, a decisão arquitetural
preferencial é uma **FK composta**, garantindo consistência de forma puramente declarativa (não
apenas por validação de aplicação, que isoladamente **não é garantia suficiente**):

```
(unidade_economica_id, tenant_id)
    REFERENCES unidade_economica(id, tenant_id)
```

Para viabilizar essa FK composta, `unidade_economica` precisará de uma chave candidata compatível,
potencialmente:

```
UNIQUE (id, tenant_id)
```

**A forma SQL/Prisma definitiva será decidida e validada pelo ADR/Change Request físico
subsequente — não implementada agora.**

## 11. Matriz normativa das 20 tabelas

| # | Tabela | Estratégia |
|---|---|---|
| 1 | `unidade_economica` | `TENANT_ID_RAIZ` |
| 2 | `pessoa_fisica` | `SEM_TENANT_ID` |
| 3 | `pessoa_juridica` | `SEM_TENANT_ID` |
| 4 | `fonte_pagadora` | `SEM_TENANT_ID` |
| 5 | `vinculo` | `TENANT_DERIVADO_POR_RLS` |
| 6 | `vinculo_extremidade` | `TENANT_DERIVADO_POR_RLS` |
| 7 | `receita` | `TENANT_DERIVADO_POR_RLS` |
| 8 | `contribuicao_previdenciaria` | `TENANT_DERIVADO_POR_RLS` |
| 9 | `vinculo_previdenciario` | `TENANT_DERIVADO_POR_RLS` |
| 10 | `evento_irpf` | `TENANT_DERIVADO_POR_RLS` |
| 11 | `documento_fiscal` | `TENANT_DERIVADO_POR_RLS` |
| 12 | `arquivo_origem` | `TENANT_ID_MATERIALIZADO` |
| 13 | `receita_documento_fiscal` | `TENANT_DERIVADO_POR_RLS` |
| 14 | `documento_fiscal_arquivo_origem` | `TENANT_DERIVADO_POR_RLS` |
| 15 | `classificacao_equiparacao_hospitalar` | `TENANT_DERIVADO_POR_RLS` |
| 16 | `cenario_tributario` | `TENANT_DERIVADO_POR_RLS` |
| 17 | `resultado_calculo` | `TENANT_DERIVADO_POR_RLS` |
| 18 | `conflito_dado` | `TENANT_ID_MATERIALIZADO` |
| 19 | `conflito_dado_item` | `TENANT_DERIVADO_DO_PAI` |
| 20 | `revisao_tecnica` | `TENANT_ID_MATERIALIZADO` |

**Totais:** `TENANT_ID_RAIZ`=1 · `SEM_TENANT_ID`=3 · `TENANT_DERIVADO_POR_RLS`=12 ·
`TENANT_ID_MATERIALIZADO`=3 · `TENANT_DERIVADO_DO_PAI`=1.

**`1 + 3 + 12 + 3 + 1 = 20`** ✓ — zero `BLOQUEADO`.

## 12. Autorização — arquitetura conceitual

*(Modelo conceitual — implementação física fora do escopo deste documento.)*

| Elemento | Definição vigente |
|---|---|
| `ContaAcesso` | Identidade de autenticação (já `COT-OBJ-017`). |
| `CredencialAcesso` | Material autenticador vinculado a uma `ContaAcesso`, `1:N` (já `COT-OBJ-018`/`COT-REL-120`). |
| `PapelAcesso` | Papel nomeado (role), agregando `Permissao`. |
| `Permissao` | Capacidade granular (ex.: `RECEITA_LER`, `REVISAO_APROVAR`). |
| `ContaAcesso ↔ Tenant` | Concessão explícita de acesso a um tenant inteiro, com papel associado — nunca implícita. |
| Autorização por `UnidadeEconomica` | **Opcional** — restrição fina abaixo do escopo padrão do `Tenant`, usada apenas quando o acesso não deve cobrir todas as UEs daquele tenant. |
| Administrador interno CONTIFISC | Concessão nomeada e auditada — nunca um papel "vê tudo" implícito, mesmo para a equipe interna. |
| Funcionários com acesso a múltiplos tenants | Múltiplas concessões explícitas `ContaAcesso ↔ Tenant`, uma por cliente atendido. |
| Usuários externos (clientes) | Limitados exclusivamente aos tenants/UEs explicitamente concedidos. |
| Menor privilégio | Negar por padrão; nenhuma `ContaAcesso` enxerga nenhum tenant/UE sem concessão explícita. |
| Segregação de funções | Expressa via composição de `Permissao`/`PapelAcesso` (ex.: proibir que a mesma conta submeta e aprove a própria `RevisaoTecnica`) — regra de negócio, não constraint estrutural. |

## 13. Autenticação — requisitos consolidados

*(Requisitos conceituais — nenhum fornecedor/framework escolhido nesta etapa.)*

| Requisito | Consolidação |
|---|---|
| MFA | `CredencialAcesso` deve suportar múltiplos tipos de credencial por conta (não apenas senha), sem redesenho futuro necessário para adicioná-los. |
| Sessões | Entidade `Sessao` (conceitual) rastreando início, expiração e revogação de logins ativos. |
| Recuperação de acesso | Mecanismo de token de curta duração, uso único, vinculado a canal verificado. |
| Expiração/revogação | Toda `Sessao` e `CredencialAcesso` deve ser revogável independentemente. |
| Credenciais | Nunca armazenadas em texto claro; sempre hash/referência. |
| Contas de serviço | `ContaAcesso` com atributo de tipo (`HUMANA`/`SERVICO`), usando credenciais não-interativas (chave de API), nunca senha+MFA pensados para humano. |
| APIs | Mesmo modelo `ContaAcesso`/`PapelAcesso`/`Tenant` serve a uma futura API — muda apenas o mecanismo de credencial (token/JWT de curta duração ou chave de API). |

## 14. RLS — Row-Level Security

**Princípio normativo:** `defesa em profundidade = autorização na aplicação + PostgreSQL RLS`.
**Isolamento somente na aplicação não é aceitável como estratégia única.**

RLS deve respeitar integralmente a matriz de 20 tabelas (§11) — policies diretas por
`tenant_id` (`TENANT_ID_RAIZ`/`TENANT_ID_MATERIALIZADO`), policies de derivação por FK real
(`TENANT_DERIVADO_DO_PAI`), policies de derivação por join de 1 hop (`TENANT_DERIVADO_POR_RLS`),
e policies de união de caminhos relacionais para as tabelas `SEM_TENANT_ID` (identidades globais,
§3).

O contexto de tenant em conexões pooled **deve ser estabelecido de forma transacional segura**
(`SET LOCAL` por transação, nunca `SET` de sessão). **Risco explícito registrado:** reuso de
conexão de pool com contexto de tenant residual de uma transação anterior é o principal vetor de
falha de todo o modelo de RLS baseado em contexto de conexão — deve ser tratado como requisito de
desenho de primeira classe na implementação física, não um detalhe.

**Nenhum SQL de RLS é escrito nesta etapa.**

## 15. Jobs e integrações

Todo **job, worker, importação, adapter de integração (`ERPAdapter`/`IntegrationGateway`) ou
processamento assíncrono** que opere dados tenant-scoped deve possuir **contexto explícito de
tenant** estabelecido antes de qualquer operação de leitura/escrita. **Nenhum job deve operar
implicitamente no tenant de uma sessão/execução anterior** — cada unidade de trabalho declara seu
próprio contexto de tenant de forma independente e verificável.

## 16. Auditoria — princípio consolidado

Todo evento de segurança relevante deve ser registrado de forma **append-only**, diferenciando
explicitamente **ator** (`ContaAcesso`), **tenant**, **UE** (quando aplicável), **operação** e
**objeto afetado**. Eventos mínimos a cobrir: login, logout, falha de autenticação, alteração de
permissão, elevação de privilégio, acesso a dado sensível, revisão técnica, override, e operações
administrativas. Distinto de `ConflitoDado`/`RevisaoTecnica` (auditoria de qualidade/decisão
tributária) — este é um trilho de auditoria de **segurança**, não de domínio.

## 17. LGPD — princípios consolidados

Minimização de dados coletados; necessidade e finalidade explícita de cada coleta; menor
privilégio já cobre a dimensão de acesso; rastreabilidade via o trilho de auditoria (§16);
políticas de retenção definidas por tipo de dado; exclusão controlada — reconhecendo
explicitamente que identidades globais compartilhadas (`PessoaFisica`/`PessoaJuridica`/
`FontePagadora`, §3) não podem ser excluídas unilateralmente por um único tenant sem considerar
os demais tenants que legitimamente as referenciam (anonimização deve ocorrer no nível do fato
tenant-scoped, não da entidade mestre compartilhada); proteção de arquivos consistente com o
modelo de `ArquivoOrigem` (§5, nunca autorização por hash/URL); logs (§16) nunca devem conter
dados sensíveis em claro que permitam vazamento entre tenants pela própria camada de
observabilidade.

## 18. Ambientes e secrets

Separação física/lógica obrigatória entre dev, test, staging e produção — dados de produção nunca
fluem para não-produção sem anonimização. Secrets (strings de conexão, hashes de credencial,
chaves de assinatura, segredos de MFA) **não podem estar em código ou repositório** — vivem em um
gerenciador de secrets dedicado. Credenciais devem ser **segregadas por ambiente** (nenhuma
credencial de produção reutilizada em ambiente de desenvolvimento/teste).

## 19. Migration baseline

**Decisão B, formalizada:** a migration `20260901120000_init_baseline_fisica` (V1, validada em
PostgreSQL 15 descartável) **permanece como artefato histórico da baseline pré-SEC** — preservada
em `prisma/migrations/` e em `INTEGRATION_TEST_REPORT.md`, sem alteração. Como **nunca foi
aplicada a nenhum banco persistente**, ela **não será a baseline inaugural** de nenhum banco
persistente futuro. Após a aprovação normativa deste documento e a execução do
`SEC-CHANGE-REQUEST-001` (§20), deverá ser produzida uma **nova baseline física definitiva**,
incorporando desde a origem todas as decisões de segurança aqui aprovadas (`Tenant`,
`unidade_economica_id` nos fatos pertinentes, os três campos `tenant_id` materializados, e as
demais decisões físicas listadas). **Essa migration não é criada por este documento.**

## 20. Dependências futuras

| Dependência | O que falta | Natureza |
|---|---|---|
| `SEC-CHANGE-REQUEST-001` | Formalizar no MCD/COT/CDC os novos campos/objetos (`Tenant`, `unidade_economica_id` nos 6 fatos do §4, campo transversal de segurança para `ArquivoOrigem`/`ConflitoDado`/`RevisaoTecnica` com ID próprio — nunca reaproveitando `MCD-F9001..F9010`), e no ADR as decisões físicas correspondentes (incluindo a FK composta do §10) | Detalhe físico/documental pendente — a **decisão arquitetural** já está aprovada por este documento; falta apenas a formalização canônica. |
| `DST-GAP-003` (`tipo_vinculo`) | Fechamento do vocabulário determinará se todo `Vinculo` deve ter ao menos uma extremidade `UnidadeEconomica`, ou se `Vinculo`/`VinculoExtremidade` sem UE permanece uma exceção residual legítima | Detalhe físico pendente — ambas as ramificações já identificadas como seguras; não bloqueia a aprovação deste documento. |
| `ADR-001`/novo `ADR-002` | Decisões físicas de segurança/tenant (tipos, FKs, a FK composta do §10, políticas RLS) precisam de um ADR próprio, não uma extensão do `ADR-001` (que trata do domínio tributário) | Detalhe físico pendente. |
| `EVT-001` | F9005/F9006 (`versao_schema`/`correlation_id`) permanecem bloqueados — sem relação direta com este SEC-001, mas parte do mesmo grupo de metadados transversais `DOM-SYS` | Decisão arquitetural de outro domínio, não afeta este documento. |
| `INT-001` | Mesma razão de `EVT-001` | Idem. |
| `OBS-001` | Identidade/autorização do revisor de `RevisaoTecnica` (`DST-GAP-014`) depende também de `OBS-001` (observabilidade/auditoria operacional), ainda não escrito — este SEC-001 prepara a arquitetura de identidade que `OBS-001` vai consumir, mas não o substitui | Documento futuro, dependente. |

**Nenhuma das dependências acima bloqueia a aprovação arquitetural deste documento** — todas são
detalhes de formalização física/documental ou dependências de domínios distintos, não lacunas na
própria decisão de segurança/tenant.

## 21. Status dos documentos preparatórios

Os quatro documentos que originaram esta consolidação são reclassificados como:

**`HISTÓRICO / MATERIAL DE DECISÃO`**

- `SEC-001_PROPOSTA_ARQUITETURAL_V1.md`
- `SEC-001_ADENDO_DECISORIO_V2.md`
- `SEC-001_AUDITORIA_CONSISTENCIA_V1.md`
- `SEC-001_RESOLUCAO_FINAL_V1.md`

Nenhum desses quatro arquivos foi alterado por esta consolidação — permanecem no repositório
integralmente, registrando o processo decisório (incluindo alternativas comparadas e rejeitadas,
e os dois erros identificados e corrigidos ao longo do processo: o reaproveitamento indevido de
`F9001..F9010` e o XOR desnecessário em `ResultadoCalculo`). **Este documento (`V1.0`) passa a
ser a referência normativa do SEC-001 a partir de sua aprovação.**

## 22. Verificação interna de consistência (gate)

| Verificação | Resultado |
|---|---|
| Matriz fecha em exatamente 20 tabelas, zero `BLOQUEADO` | ✓ (§11: `1+3+12+3+1=20`) |
| Nenhum reaproveitamento semântico de `MCD-F9001..F9010` | ✓ — o eventual novo campo transversal de segurança (§5, §6, §8) é tratado como pendente de ID e contrato próprios no `SEC-CHANGE-REQUEST-001`, nunca reaproveitando os IDs/significados de `F9001..F9010` |
| Nenhum `tenant_id` confundido com UE | ✓ — §9 formaliza a distinção; nenhuma tabela da matriz (§11) trata os dois campos como equivalentes |
| Nenhum ownership derivado de referência polimórfica | ✓ — §6/§7/§8 reafirmam explicitamente que `objeto_id`/`tipo_objeto`/`objeto_revisado_id`/`tipo_objeto_revisado` permanecem mecanismo de auditoria, nunca de isolamento |
| Nenhuma autenticação confundida com `PessoaFisica` | ✓ — §1 formaliza `identidade tributária ≠ identidade de acesso`; `ContaAcesso ↔ PessoaFisica` continua associação opcional (`COT-REL-119`, inalterada) |
| Nenhuma implementação introduzida | ✓ — nenhum código, migration, alteração de `schema.prisma`, RLS ou documento normativo (COT/MCD/CDC/DST/ADR) foi criado ou alterado por este documento |

Nenhuma contradição real foi encontrada nesta verificação.

**SEC-001 V1.0 CONSOLIDADO — PRONTO PARA APROVAÇÃO**
