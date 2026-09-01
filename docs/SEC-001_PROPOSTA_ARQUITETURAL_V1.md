# SEC-001 — Proposta Arquitetural: Segurança, Identidade, Autorização e Isolamento de Tenant

**Status:** PROPOSTA PARA DECISÃO ARQUITETURAL — documento de análise, sem implementação.
**Tipo:** Architecture Decision Proposal (pré-ADR).
**Baseline consultada:** COT-001 V1.1, MCD-001 V1.2, CDC-001 V1.2, DST-001 V1.2, ADR-001 V1.0
(com Errata controlada nº2), `schema.prisma` v3, migration `20260901120000_init_baseline_fisica`
(validada em PostgreSQL 15 descartável — ver `INTEGRATION_TEST_REPORT.md`).
**Escopo:** decidir a arquitetura conceitual de segurança/tenant antes da criação de qualquer
banco persistente. Este documento **não** altera COT/MCD/CDC/DST/ADR/`schema.prisma`/migration,
**não** implementa código, autenticação, RLS ou tenant_id, e **não** resolve nenhum gap
tributário existente. Os objetos aqui descritos são **propostas conceituais**, não
incorporadas a nenhum catálogo canônico.

**Dependência declarada:** partes desta arquitetura (identidade/autorização do revisor de
`RevisaoTecnica`, hoje `DST-GAP-014`/`GAP-CDC-1.2-003`/`GAP-MCD-CR2-004`) também dependem de
`OBS-001` (observabilidade/auditoria operacional), documento ainda não criado. Este SEC-001
prepara a arquitetura de identidade que `OBS-001` vai precisar, mas não substitui `OBS-001`.

---

## 1. ContaAcesso × PessoaFisica × PessoaJuridica × UnidadeEconomica — diferenças fundamentais

| Objeto | O que é | O que NÃO é |
|---|---|---|
| `UnidadeEconomica` (COT-OBJ-001, já canônico) | Contexto agregador econômico/tributário — o "em nome de quem" os fatos fiscais são apurados. | Não é sujeito tributário, não é usuário, não é tenant por definição automática (ver §3-4). |
| `PessoaFisica` (COT-OBJ-002, já canônico) | Identidade **tributária** de uma pessoa física — CPF, dados fiscais, vínculos. | Não é identidade de login. **Já estabelecido em MCD-001 V1.2 §1/linha 39 e COT-001 V1.1 §13: "PessoaFisica não é ContaAcesso"** — este SEC-001 apenas formaliza a arquitetura em torno dessa regra já vigente. |
| `PessoaJuridica` (COT-OBJ-003, já canônico) | Identidade **tributária** de uma pessoa jurídica — CNPJ, regime, dados fiscais. | Não é usuário, não é tenant automaticamente (uma PJ pode ser a UE de um cliente, mas o tenant — ver §3-4 — pode agregar mais de uma PJ/UE). |
| `ContaAcesso` (**COT-OBJ-017, já catalogado, implementação bloqueada até este documento**) | Identidade de **autenticação** — quem loga no sistema. Pode ser uma pessoa (funcionário CONTIFISC, contato do cliente) ou uma conta de serviço (job, integração). | Não é um sujeito tributário. Não precisa corresponder a nenhum `PessoaFisica`/`PessoaJuridica` canônico. `COT-REL-119` já define a associação `ContaAcesso ↔ PessoaFisica` como **0..N:0..1, opcional** — reafirmado aqui como a cardinalidade correta. |
| `CredencialAcesso` (**COT-OBJ-018, já catalogado**) | Material autenticador (senha/hash, chave MFA, chave de API) vinculado a uma `ContaAcesso`. `COT-REL-120` já define `ContaAcesso:CredencialAcesso` como `1:N`. | Não é a própria identidade — é o mecanismo de prova dela. |

**Conclusão do item 1:** a arquitetura já catalogada (COT-OBJ-017/018, COT-REL-119/120) está
correta e não precisa ser renomeada. O que faltava — e é o objeto central deste documento — é
(a) o conceito de **Tenant** (inexistente no catálogo atual) e (b) o modelo de autorização
(papéis/permissões/escopo) em torno de `ContaAcesso`.

## 2. Identidade de autenticação × identidade tributária

São **eixos ortogonais**, nunca conflados:

- **Identidade tributária** (MCD/COT existente): responde "de quem são estes fatos fiscais?" —
  `PessoaFisica`/`PessoaJuridica`/`UnidadeEconomica`. Existe independentemente de haver ou não
  alguém logado no sistema (ex.: dados importados em lote de um ERP não implicam login humano).
- **Identidade de autenticação** (`ContaAcesso`, proposta aqui): responde "quem está operando o
  sistema agora, e o que essa sessão pode fazer?" — não tem relação obrigatória com nenhum
  registro tributário. Um contador da CONTIFISC pode logar sem nunca ter um `PessoaFisica`
  canônico próprio (ele não é "sujeito tributário" de nenhum cliente); um cliente PF pode ter um
  `PessoaFisica` canônico rico (é sujeito tributário) e nunca ter feito login (`ContaAcesso`
  inexistente) porque só o contador opera o sistema em nome dele.

A associação entre os dois eixos (`COT-REL-119`) é **opcional e lateral** — nunca inferida, nunca
assumida por coincidência de CPF/nome.

## 3-4. Definição formal de Tenant

**Decisão proposta: Tenant ≠ UnidadeEconomica, Tenant ≠ CONTIFISC, Tenant = Cliente (novo
conceito canônico a propor).**

Análise das quatro hipóteses levantadas pela instrução:

| Hipótese | Avaliação |
|---|---|
| Tenant = CONTIFISC | Rejeitada. CONTIFISC é a operadora da plataforma (o "SaaS provider"), não uma fronteira de isolamento de dados — o problema a resolver é justamente isolar **entre clientes da CONTIFISC**, não isolar a CONTIFISC de si mesma. |
| Tenant = `UnidadeEconomica` | Rejeitada como definição automática (conforme instrução explícita). Um cliente real pode ter **múltiplas UEs** (ex.: holding + subsidiárias, ou pessoa física com atividade + empresa própria) que devem ser vistas por um mesmo conjunto de contas autorizadas como um grupo único. Fixar tenant = UE forçaria o cliente a gerenciar múltiplos logins/permissões redundantes para o que é, na prática, uma única relação contratual com a CONTIFISC. |
| Tenant = "outra entidade" (proposta) | **Aceita.** Um novo conceito canônico — aqui chamado `Tenant` (equivalente a "Cliente" ou "Organização Contratante") — como fronteira de isolamento e de contrato comercial, agregando 1..N `UnidadeEconomica`. |
| Tenant = "organização" | Mesma ideia da linha acima; "Tenant" e "Cliente"/"Organização" são sinônimos nesta proposta — o nome final é uma decisão de nomenclatura (DST), não arquitetural. |

**Modelo hierárquico proposto:** `Tenant` (1) → `UnidadeEconomica` (N). A UE continua sendo
exatamente o que já é no MCD/COT (contexto econômico/tributário) — ganha apenas uma FK/associação
para o `Tenant` ao qual pertence. Nenhuma semântica tributária de UE muda.

## 5-9. Cenários de acesso multi-UE / multi-cliente / cliente restrito / admin CONTIFISC / RBAC

O modelo `Tenant → UnidadeEconomica` combinado com uma associação **explícita e granular**
`ContaAcesso ↔ Tenant` (com possibilidade de refinar para `ContaAcesso ↔ UnidadeEconomica`
quando necessário) cobre todos os cenários pedidos:

| Cenário | Como o modelo resolve |
|---|---|
| **5.** Um usuário acessa múltiplas UEs | Se a `ContaAcesso` está associada ao `Tenant`, ela enxerga (por padrão) todas as UEs daquele Tenant. Cobre o caso de um sócio/contato do cliente que administra o grupo econômico inteiro. |
| **6.** Funcionário CONTIFISC acessa múltiplos clientes | A `ContaAcesso` do funcionário recebe **múltiplas associações explícitas** `ContaAcesso ↔ Tenant`, uma por cliente atendido — nunca um acesso implícito "vê tudo". |
| **7.** Cliente acessa exclusivamente suas UEs autorizadas | Quando o cliente precisa de granularidade abaixo do Tenant (ex.: um contato só deve ver 1 das 3 UEs do grupo), usa-se a associação secundária `ContaAcesso ↔ UnidadeEconomica`, que **restringe** o escopo padrão do Tenant a um subconjunto explícito de UEs. |
| **8.** Administrador CONTIFISC | Modelado como uma `ContaAcesso` do tipo interno com papel administrativo — **nunca como um bypass implícito de todas as regras**; mesmo o admin deveria ter suas ações auditadas e, preferencialmente, suas concessões cross-tenant explícitas (ver §10). Um "super-admin global" sem escopo deve existir apenas como um papel raríssimo, nomeado individualmente e fortemente auditado — não o padrão de acesso da equipe. |
| **9.** Perfis e RBAC | `PapelAcesso` (role) agrupa `Permissao` (capacidades granulares). A atribuição de um `PapelAcesso` a uma `ContaAcesso` é **contextual ao Tenant** (a mesma conta pode ter papel `CONTADOR_RESPONSAVEL` no cliente A e `LEITURA` no cliente B) — RBAC escopado, não global. |

## 10. Princípio do menor privilégio

- Padrão: **negar por padrão**. Nenhuma `ContaAcesso` enxerga nenhum `Tenant`/UE sem uma
  associação explícita.
- Nenhum papel "vê tudo" implicitamente, nem para equipe interna — cada relação
  funcionário↔cliente é uma concessão nomeada, revisável e revogável individualmente.
- Um número muito pequeno de contas "super-admin" (para operação de plataforma, não trabalho
  diário) deve existir como exceção nomeada, não como papel comum.

## 11. MFA (autenticação multifator)

Arquiteturalmente, `CredencialAcesso` deve suportar múltiplos **tipos** de credencial por conta
(senha + segundo fator), não um único par usuário/senha. O modelo conceitual (§ "Modelos
conceituais" abaixo) já reserva essa flexibilidade. MFA em si **não é implementado** neste
documento — apenas garantido que o modelo de dados não impede sua adoção futura (ex.: não seria
necessário redesenhar `CredencialAcesso` para adicionar TOTP/WebAuthn depois).

## 12. Sessões

Proposta de uma entidade `Sessao` (não incorporada ao COT/MCD ainda) para rastrear logins ativos,
sua expiração e revogação — necessária tanto para segurança (invalidar sessões comprometidas)
quanto para auditoria (quem estava logado quando uma ação sensível ocorreu). Boas práticas de
armazenamento (nunca token bruto, sempre hash/referência) são um princípio de implementação
futura, não deste documento.

## 13. Credenciais

`CredencialAcesso` nunca armazena segredo em texto claro (princípio, não implementação aqui).
Uma `ContaAcesso` pode ter 0 (conta ainda não ativada) a N credenciais (senha + MFA + chaves de
API para conta de serviço).

## 14. Recuperação de acesso

Requer um mecanismo de token de recuperação de curta duração, de uso único, vinculado a um canal
de comunicação verificado (e-mail cadastrado) — modelado como uma variação/subtipo de
`CredencialAcesso` ou uma entidade própria de "token efêmero", a decidir na fase de detalhamento
físico (fora do escopo desta proposta conceitual).

## 15. Auditoria de login e ações sensíveis

Proposta de uma entidade `EventoAuditoriaSeguranca` — **distinta** de `ConflitoDado`/
`RevisaoTecnica` (que auditam qualidade/decisão **tributária**, não segurança). Registra, no
mínimo: tentativas de login (sucesso/falha), mudanças de papel/permissão, troca de contexto de
tenant, e ações classificadas como sensíveis (ex.: aprovação de `RevisaoTecnica`, exportação de
dados). Deve ser **append-only** (sem UPDATE/DELETE de aplicação).

## 16. Segregação de funções (SoD)

Regra de negócio a ser expressa via `Permissao`/`PapelAcesso`, não via constraint estrutural: por
exemplo, nunca conceder a uma mesma `ContaAcesso` permissão simultânea de "submeter
ResultadoCalculo" e "aprovar a própria submissão via RevisaoTecnica" — modelável como uma regra
de composição de papéis a ser validada na camada de aplicação/autorização, não no schema físico.

## 17-19. Isolamento lógico, RLS × aplicação, defesa em profundidade

Tratado em profundidade na comparação de alternativas (§ "Comparação de alternativas" abaixo).
Recomendação adiantada: nenhuma camada isolada (nem só aplicação, nem só RLS) é suficiente
sozinha — a arquitetura recomendada combina modelo relacional correto **mais** RLS como rede de
segurança (defesa em profundidade real).

## 20-25. Impacto de `tenant_id` nas 20 tabelas atuais

**Achado central (CRÍTICO — determina toda a estratégia física):** nem toda tabela pode receber
um `tenant_id` direto sem risco de inconsistência, porque **`PessoaFisica`/`PessoaJuridica` (e,
por extensão, `FontePagadora`) não pertencem estruturalmente a um único tenant.** O CPF de uma
pessoa física é uma identidade única a nível nacional; nada no domínio real impede que a *mesma*
pessoa seja, simultaneamente, sujeito tributário de dois clientes **completamente diferentes e
não relacionados** da CONTIFISC (ex.: um médico sócio da Clínica A — cliente 1 — que também presta
serviço autônomo faturado através da Clínica B — cliente 2). Como o schema atual modela
`pessoa_fisica`/`pessoa_juridica` como uma **linha canônica única** (sem duplicação por tenant),
colocar um `tenant_id` direto nessas tabelas seria **estruturalmente incorreto**: ou a coluna
mentiria (só um dos dois tenants "donos"), ou forçaria duplicar a PF/PJ por tenant — o que
contradiz o modelo canônico já aprovado (MCD-001 V1.2, COT-001 V1.1) e exigiria uma revisão de
MCD/COT fora do escopo deste documento.

Classificação proposta por tabela:

| Categoria | Tabelas | Estratégia de tenant |
|---|---|---|
| **Raiz/agregador (tenant_id direto)** | `unidade_economica` | Ganha FK direta para `Tenant` — é o único ponto de ancoragem estrutural correto, porque uma UE (uma empresa/atividade específica) pertence inequivocamente a um cliente. |
| **Dado mestre potencialmente compartilhável entre tenants (NUNCA tenant_id direto — derivação relacional obrigatória)** | `pessoa_fisica`, `pessoa_juridica`, `fonte_pagadora` | O tenant de uma linha destas só existe **no contexto de uma associação específica** (ex.: "esta PF é sócia da UE X, que pertence ao Tenant Y") — nunca como propriedade da própria linha. |
| **Fatos/estruturas de suporte ligadas a uma UE/PF/PJ por FK** | `vinculo`, `vinculo_extremidade`, `receita`, `contribuicao_previdenciaria`, `evento_irpf`, `documento_fiscal`, `receita_documento_fiscal`, `arquivo_origem`, `documento_fiscal_arquivo_origem`, `classificacao_equiparacao_hospitalar`, `vinculo_previdenciario`, `cenario_tributario`, `resultado_calculo` | Tenant é **derivado** por um caminho relacional até `unidade_economica` (direto ou via `vinculo_extremidade`). Adicionar `tenant_id` redundante aqui é o risco central do item 23 (ver abaixo) — só se justifica sob a Alternativa D (híbrida), e mesmo assim exigiria trigger de sincronização. |
| **Exceção polimórfica de auditoria/reconciliação (tenant indeterminável sem resolver o objeto referenciado)** | `conflito_dado`, `conflito_dado_item`, `revisao_tecnica` | O tenant só é conhecido depois de resolver `objeto_id`/`objeto_revisado_id` (referência polimórfica sem FK) — um problema estrutural adicional, específico destas três tabelas, que precisa de tratamento próprio (provavelmente um `tenant_id` direto aqui é **defensável por exceção**, já que a alternativa — derivar via um `tipo_objeto` + `objeto_id` sem FK real — é ainda mais frágil). Marcado como ponto em aberto para a fase de detalhamento físico. |

**23. Risco de redundância/inconsistência:** aplicar `tenant_id` indiscriminadamente (Alternativa
B) sobre tabelas cujo tenant é *derivado* (a maioria da terceira categoria acima) cria uma cópia
que pode dessincronizar da fonte de verdade relacional (ex.: um `UPDATE` que move uma
`VinculoExtremidade` para outra UE sem atualizar o `tenant_id` "cache" da `Receita` associada).
Isso é uma classe de bug silencioso e perigoso — dados aparentemente isolados corretamente, mas
na verdade inconsistentes.

**24. Índices/UNIQUEs tenant-scoped:** sob qualquer alternativa que introduza `tenant_id` direto
(B ou D), índices/UNIQUEs que hoje não precisam de tenant explícito na chave (porque já derivam
de uma FK unicamente identificável, ex.: `uq_receita_documento_fiscal`) continuam corretos sem
mudança — a unicidade já é local ao par de FKs. Já índices de busca livre (ex.:
`documento_fiscal_chave_documento_fiscal_idx`) deveriam, sob B/D, virar compostos
`(tenant_id, chave_documento_fiscal)` para permitir bons planos de execução filtrados por tenant
— hoje não é estritamente necessário porque `chave_documento_fiscal` (chave de acesso de NFe)
já é nacionalmente única por desenho.

**25. FKs/constraints afetadas:** nenhuma das 20 FKs/25 CHECKs/1 trigger já validados
precisaria mudar sob a Alternativa C (nenhuma nova coluna nas tabelas de fato). Sob B/D, cada
nova coluna `tenant_id` redundante exigiria, no mínimo, um CHECK/trigger adicional garantindo
consistência com o tenant derivado relacionalmente — SQL manual adicional, no mesmo padrão já
usado nesta migration (nenhum ENUM, nenhuma constraint inventada fora do que for formalmente
decidido em um futuro ADR de segurança).

## 26-27. Jobs assíncronos e integrações/ERP

Tanto jobs em background quanto o `IntegrationGateway`/`ERPAdapter` (já existentes em
`packages/integrations`, hoje sem qualquer noção de tenant) precisam de um **contexto de
execução explícito** carregando o `Tenant`/`UnidadeEconomica` de cada unidade de trabalho — nunca
um job "roda para todo mundo" sem escopo declarado. Sob a Alternativa D, isso inclui abrir a
conexão/transação de banco já com `SET LOCAL` do tenant corrente, para que a RLS proteja mesmo
um job mal escrito.

## 28. Armazenamento de `ArquivoOrigem`

`armazenamento_referencia` (hoje um `VARCHAR(500)` livre) deveria, na implementação futura, seguir
uma convenção de namespace por tenant (ex.: prefixo/bucket por `Tenant`) — defesa em profundidade
também na camada de armazenamento de objetos, independente do isolamento em banco.

## 29. Logs sem vazamento entre tenants

Logs de aplicação/infra não devem misturar dados de tenants diferentes sem controle de acesso
equivalente ao dos dados primários; ferramentas de observabilidade compartilhadas (ex.: painel
único para toda a equipe CONTIFISC) são aceitáveis para a equipe interna (que já opera
cross-tenant sob concessões explícitas), mas nunca expostas a um cliente.

## 30. Backups/restores

Acha-se aqui um risco **RELEVANTE** ainda sem solução neste documento: um backup físico completo
do banco é a estratégia mais simples para disaster recovery, mas uma eventual necessidade de
"restaurar/exportar somente os dados do Tenant X" esbarra exatamente no mesmo problema de
`pessoa_fisica`/`pessoa_juridica` compartilháveis entre tenants (§20-23) — não é trivial recortar
um tenant sem também decidir o que fazer com as linhas de PF/PJ compartilhadas. Fica registrado
como ponto em aberto para tratamento físico futuro, não resolvido aqui.

## 31. LGPD, minimização e rastreabilidade

Também **RELEVANTE** e não resolvido aqui: um pedido de anonimização/exclusão (LGPD) sobre uma
`PessoaFisica` que participa de mais de um tenant não pode simplesmente apagar a linha canônica
(quebraria os fatos do(s) outro(s) tenant(s) legitimamente interessados). A resposta correta
provavelmente é anonimizar/pseudonimizar no nível do **fato** (por tenant), não da entidade
mestre compartilhada — uma decisão que merece um documento de conformidade próprio (fora do
escopo deste SEC-001), citado aqui como dependência futura.

## 32-36. Ambientes, secrets, contas de serviço, API, portal do cliente

| Item | Princípio arquitetural (não implementado aqui) |
|---|---|
| **32.** Ambientes dev/test/staging/prod | Bancos fisicamente isolados por ambiente; dados de produção nunca fluem para não-produção sem anonimização. |
| **33.** Secrets | `DATABASE_URL`, hashes de credencial, chaves de assinatura de sessão/JWT e segredos de MFA vivem em um gerenciador de secrets dedicado — nunca em `.env` versionado, nunca em `docs/`. |
| **34.** Contas de serviço | `ContaAcesso` ganha um atributo conceitual de **tipo** (`HUMANA` vs. `SERVICO`) — contas de serviço (jobs, integrações, CI/CD) usam credenciais não-interativas (chave de API), nunca senha+MFA pensados para humano. |
| **35.** Acesso via API | Mesmo modelo `ContaAcesso`/`PapelAcesso`/`Tenant` serve a uma futura API — o mecanismo de credencial muda (token/JWT de curta duração emitido a partir de uma `Sessao`, ou chave de API para conta de serviço), a autorização não. |
| **36.** App/portal do cliente | Também é só mais um consumidor do mesmo modelo — reforça por que o escopo do cliente deve ser sempre explícito por `Tenant`/UE, nunca assumido. |

---

## Comparação de alternativas de isolamento

| Critério | A — Só aplicação | B — `tenant_id` generalizado | C — Raiz/agregado + derivação relacional | D — Híbrida (C + RLS) |
|---|---|---|---|---|
| Segurança | Baixa — depende 100% de disciplina de código, sem segunda camada | Média — fácil de auditar, mas arrisca inconsistência silenciosa nas tabelas onde tenant é derivado | Boa — modelo correto, sem redundância, mas ainda depende da aplicação fazer o JOIN certo | **Alta** — RLS bloqueia mesmo se a aplicação esquecer o filtro |
| Risco de vazamento cross-tenant | **Alto** | Médio (alto se PF/PJ forem forçadas a ter tenant_id único, ver §20-23) | Médio | **Baixo** |
| Complexidade | Aparentemente baixa no schema, mas alta e distribuída no código | Alta — decisão artificial para PF/PJ/FontePagadora | Média — lógica de resolução de tenant centralizável | Alta — exige policies RLS + propagação de contexto por conexão |
| Performance | Boa (sem overhead de schema) | Boa (índice direto) | Boa para queries normais; JOINs extra só em relatórios cross-objeto | Boa se bem indexado; overhead de RLS geralmente pequeno |
| Manutenção | Frágil a longo prazo — cresce o risco com o número de módulos | Pior — cada tabela nova precisa lembrar de popular/sincronizar tenant_id | Boa — nada para dessincronizar | Exige disciplina para manter policies sincronizadas com o schema |
| Compatibilidade Prisma | Total, sem ajuda automática | Total | Total, mas exige `include`/`where` relacionais corretos em toda query | Prisma não gerencia RLS nativamente — exige `SET LOCAL` por conexão/transação e SQL manual (mesmo padrão já usado nos CHECKs desta migration) |
| Impacto nas migrations | Nenhum | Grande (~20 colunas + triggers de sincronização + quebra do modelo PF/PJ compartilhado) | Pequeno (1 FK em `unidade_economica` + tabelas novas) | Médio-alto (igual a C + `ENABLE ROW LEVEL SECURITY`/`CREATE POLICY` por tabela) |
| Auditoria | Fraca — só logs de aplicação | Boa para consulta ad-hoc | Média — consultas cross-tenant exigem JOINs (mitigável com views) | **Melhor** — provável formalmente via `pg_policies` |
| Integrações | Cada integração reimplementa o filtro | Simples de filtrar | Precisa conhecer o caminho relacional (centralizável) | Mais forte, mas exige contexto de conexão por chamada |
| Jobs assíncronos | Mesmo risco de esquecimento | Simples de filtrar | Mesmo — centralizável em um módulo de contexto | Mais forte, exige `SET LOCAL` por unidade de trabalho |
| Escalabilidade | Ok tecnicamente, risco cresce com o time | Boa, ao custo de um modelo incorreto para PF/PJ | Boa | Boa |

### Recomendação

**Alternativa D (híbrida), implementada em duas fases:**

1. **Fase imediata (o que este documento decide):** adotar o modelo relacional da Alternativa C
   — `Tenant` como novo agregador, `tenant_id` direto **somente** em `unidade_economica` (e,
   como exceção justificada, possivelmente nas três tabelas de exceção polimórfica —
   `conflito_dado`/`conflito_dado_item`/`revisao_tecnica`, a decidir em detalhamento físico
   futuro), derivação relacional para todo o resto. **Nenhum `tenant_id` em
   `pessoa_fisica`/`pessoa_juridica`/`fonte_pagadora`.**
2. **Fase de enrijecimento (trabalho físico futuro, não autorizado por este documento):**
   adicionar políticas PostgreSQL RLS como rede de segurança sobre o modelo relacional da fase 1
   — nunca a única camada, sempre em conjunto com os filtros corretos na aplicação (defesa em
   profundidade real, item 19).

Alternativas A e B são **rejeitadas**: A por não oferecer nenhuma segunda camada de defesa; B por
forçar uma coluna estruturalmente incorreta sobre dados mestres legitimamente compartilháveis
entre tenants.

---

## Modelos conceituais propostos (NÃO incorporados ao COT/MCD)

| Objeto | Propósito | Atributos-chave (conceituais) | Observação |
|---|---|---|---|
| `Tenant` | Fronteira comercial/de isolamento — o "cliente da CONTIFISC". | nome, status | Novo. Agrega 1..N `UnidadeEconomica`. |
| `ContaAcesso` | Identidade de autenticação. | identificador de login (e-mail), tipo (HUMANA/SERVICO), status | **Já catalogado como COT-OBJ-017** — este documento detalha o entorno, não redefine o objeto. |
| `CredencialAcesso` | Material autenticador. | tipo (senha/TOTP/WebAuthn/chave de API), hash/referência (nunca segredo em claro) | **Já catalogado como COT-OBJ-018.** |
| `PapelAcesso` | Papel nomeado (role) — agrupa permissões. | nome (ex.: `CONTADOR_RESPONSAVEL`, `LEITURA`, `ADMIN_CONTIFISC`) | Novo. Catálogo provavelmente aberto (Enum/Ref) inicialmente, como os demais vocabulários ainda não fechados do DST. |
| `Permissao` | Capacidade granular (ex.: `RECEITA_LER`, `REVISAO_APROVAR`). | código | Novo. `PapelAcesso` agrega N `Permissao`. |
| `ContaAcesso ↔ Tenant` | Concessão de acesso a um cliente inteiro, com papel. | conta, tenant, papel, concedido_em, revogado_em | Novo — associação N:N com atributos (papel, vigência). |
| `ContaAcesso ↔ UnidadeEconomica` | Restrição fina opcional, quando o acesso não deve cobrir todas as UEs do Tenant. | conta, unidade_economica, papel | Novo — usado só quando o padrão "todo o Tenant" precisa ser restringido. |
| `Sessao` | Login ativo. | conta, iniciada_em, expira_em, revogada_em | Novo. |
| `EventoAuditoriaSeguranca` | Log append-only de eventos de segurança. | tipo_evento, ocorrido_em, ator (conta), tenant (quando aplicável), resultado | Novo — distinto de `ConflitoDado`/`RevisaoTecnica` (auditoria de dado/decisão tributária, não de segurança). |

---

## Impacto nos documentos canônicos e na baseline física

| Documento | Mudança que a solução recomendada provocaria |
|---|---|
| **COT-001** | Adicionar `Tenant`, `PapelAcesso`, `Permissao`, `Sessao`, `EventoAuditoriaSeguranca` como novos `COT-OBJ-*`; adicionar `ContaAcessoTenant`/`ContaAcessoUnidadeEconomica` como novas `COT-SUP-*`; adicionar relacionamento `UnidadeEconomica → Tenant` (N:1). `ContaAcesso`/`CredencialAcesso` (COT-OBJ-017/018) e `COT-REL-119/120` permanecem sem alteração conceitual. |
| **MCD-001** | Novo domínio `DOM-SEC` detalhado (hoje só reservado); catálogo de campos para os objetos acima; novo campo `UnidadeEconomica.tenant_id` (FK). |
| **CDC-001** | Novos contratos canônicos para os objetos de `DOM-SEC`; possivelmente um novo "envelope de contexto de tenant" propagado em operações, paralelo conceitual ao envelope de metadados transversais (MCD-F9001..F9010) já existente. |
| **DST-001** | Novos vocabulários (ex.: status de `ContaAcesso`, tipos de evento de auditoria); `PapelAcesso` provavelmente como Enum/Ref aberto inicialmente (mesmo padrão de outros `DST-GAP-*`), não fechado por inferência. |
| **ADR-001** | **Não estendido** — recomenda-se um **ADR-002 dedicado** (Schema Físico de Segurança/Tenant), reaproveitando as convenções já estabelecidas (`TEXT + CHECK` para vocabulário fechado, UUID, `relationMode=foreignKeys`), mas como documento próprio, dado que é uma preocupação estruturalmente distinta (segurança/tenant) da preocupação tributária do ADR-001. |
| **`schema.prisma`** | Adicionar os models acima + `UnidadeEconomica.tenant_id`. **Não alterado nesta etapa.** |
| **Migration V1 validada** | Ver decisão obrigatória abaixo. |

### Decisão obrigatória: migration V1 permanece ou é substituída?

**Decisão: a migration V1 (`20260901120000_init_baseline_fisica`) deve ser tratada como
baseline de referência pré-tenant e NÃO deve ser a migration efetivamente aplicada ao primeiro
banco persistente. Uma nova migration incorporando `Tenant`/`tenant_id` desde a origem deve
preceder qualquer banco persistente.**

Justificativa:
- A V1 **nunca foi aplicada a nenhum banco persistente** (apenas a dois containers descartáveis,
  já destruídos) — não existe custo de migração de dados reais a considerar.
- Adicionar `Tenant` e `unidade_economica.tenant_id` **agora**, antes de qualquer dado real
  existir, é uma mudança estrutural pequena (1 tabela nova + 1 FK). Adicionar depois, com dados
  reais já em produção, exigiria backfill de `tenant_id` para todas as UEs existentes sem um
  valor-padrão logicamente correto, além de habilitar RLS sobre tabelas já em uso — uma operação
  ordens de magnitude mais arriscada.
- Isso não invalida o trabalho já feito: os 25 CHECKs, o trigger `ADR-C005`, e as 20 tabelas
  tributárias validadas na V1 continuam corretos e devem ser preservados **integralmente** na
  próxima versão da migration — a mudança é aditiva (novo agregador `Tenant` acima da UE), não
  uma reescrita do domínio tributário.

Esta decisão **não é executada neste documento** — fica registrada como a próxima etapa
arquitetural a ser explicitamente autorizada, envolvendo alteração de `schema.prisma` e geração
de uma migration V2 substituta.

---

## Classificação de riscos

| # | Achado | Classificação |
|---|---|---|
| 1 | `tenant_id` direto em `pessoa_fisica`/`pessoa_juridica`/`fonte_pagadora` é estruturalmente incorreto — essas linhas podem legitimamente ser compartilhadas entre tenants não relacionados. | **CRÍTICO** |
| 2 | Assumir `UnidadeEconomica = tenant` quebraria o caso de clientes com múltiplas UEs sob uma mesma relação contratual. | **CRÍTICO** |
| 3 | Recomendação de tratar a migration V1 como baseline pré-tenant, substituída antes de qualquer banco persistente, para evitar retrofit custoso e arriscado sobre dados reais. | **CRÍTICO** (decisão que evita um CRÍTICO futuro) |
| 4 | Backup/restore por tenant é inviável de forma trivial dado o compartilhamento de PF/PJ entre tenants — sem solução proposta neste documento. | **RELEVANTE** |
| 5 | LGPD (anonimização/exclusão) sobre PF/PJ compartilhadas exige tratamento por fato, não por entidade mestre — sem solução proposta neste documento; recomenda documento de conformidade próprio. | **RELEVANTE** |
| 6 | `conflito_dado`/`conflito_dado_item`/`revisao_tecnica` (exceção polimórfica) têm resolução de tenant não trivial — ponto em aberto para detalhamento físico. | **RELEVANTE** |
| 7 | Jobs assíncronos e `IntegrationGateway`/`ERPAdapter` hoje não têm nenhuma noção de contexto de tenant — precisa de um módulo de contexto de execução dedicado antes da implementação. | **RELEVANTE** |
| 8 | Least privilege exige que mesmo a equipe interna da CONTIFISC opere sob concessões explícitas por cliente, não acesso implícito "vê tudo" — decisão de política, não técnica. | **RELEVANTE** |
| 9 | Recomenda-se ADR-002 dedicado (não estender ADR-001) para o schema físico de segurança/tenant. | **EDITORIAL** |
| 10 | `PapelAcesso` como catálogo aberto inicialmente (Enum/Ref), seguindo o mesmo padrão já usado para os demais vocabulários ainda não fechados do DST. | **EDITORIAL** |
| 11 | `ContaAcesso`/`CredencialAcesso` (COT-OBJ-017/018) e `COT-REL-119/120` já estavam corretamente catalogados e não precisam de renomeação — este documento confirma e detalha o entorno. | **HISTÓRICO** (confirmação) |
| 12 | "PessoaFisica não é ContaAcesso" já era regra vigente (MCD-001 V1.2, COT-001 V1.1) — este documento não introduz a regra, apenas a aplica de forma consistente à arquitetura de tenant. | **HISTÓRICO** (confirmação) |

---

## Conclusão

Nenhuma dependência arquitetural impede a decisão: a análise cobriu os 36 pontos exigidos, as
quatro alternativas foram comparadas nos 11 critérios pedidos, os modelos conceituais foram
propostos sem incorporação prematura ao COT/MCD, e a decisão obrigatória sobre a migration V1
foi registrada com justificativa explícita.

**SEC-001 PRONTO PARA DECISÃO ARQUITETURAL**
