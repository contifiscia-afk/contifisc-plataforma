# Revisão de Minimalidade, Cardinalidade e Classificação Canônica — `SEC-CHANGE-REQUEST-001 V1.0`

**Status:** RELATÓRIO DE REVISÃO — não altera `SEC-CHANGE-REQUEST-001_V1.0.md`, nem
COT/MCD/CDC/DST/ADR, `schema.prisma`, migrations ou banco.

---

## 1. Os cinco objetos candidatos — classificação individual

**Critério aplicado:** um objeto só entra em COT/MCD se tiver identidade e semântica estáveis
da CONTIFISC, independentes do framework/provedor de autenticação que vier a ser escolhido.

| Objeto | Classificação | Justificativa |
|---|---|---|
| `Tenant` | **`CANONICO_OBRIGATORIO`** | Fronteira de isolamento/propriedade lógica — conceito puramente do domínio CONTIFISC, sem nenhuma dependência de qual framework de autenticação for adotado. Toda a resolução de ownership/tenant das 20 tabelas (SEC-001 V1.0 §11) depende dele. |
| `PapelAcesso` | **`DIFERIDO`** | Reavaliado no item 4 — um campo `papel` (texto, vocabulário aberto) já resolve os cenários hoje conhecidos, sem precisar de um objeto canônico próprio. Não descartado — pode se tornar `CANONICO_OBRIGATORIO` quando um requisito concreto de RBAC granular existir. |
| `Permissao` | **`DIFERIDO`** | Mesma razão — nenhum requisito hoje confirma a necessidade de decompor papéis em permissões atômicas. |
| `Sessao` | **`SEGURANCA_OPERACIONAL`** | Analisado em detalhe no item 2 — necessário para o sistema funcionar, mas sua forma concreta (revogação, refresh token, dispositivo) é inerentemente definida pelo provedor de autenticação escolhido, não uma semântica estável da CONTIFISC. |
| `EventoAuditoriaSeguranca` | **`CANONICO_OBRIGATORIO`** | Analisado em detalhe no item 3 — a necessidade de auditoria de segurança (LGPD, compliance interno) é da CONTIFISC, não do provedor, e deve sobreviver a uma eventual troca de provedor de autenticação. |

## 2. `Sessao` — análise específica

| Aspecto considerado | Avaliação |
|---|---|
| Revogação | Mecanismo já resolvido nativamente por qualquer provedor moderno (JWT com lista de revogação, sessão em banco gerenciada pelo próprio framework). |
| MFA | Estado por sessão é tipicamente parte do token/sessão do próprio provedor, não uma semântica de negócio da CONTIFISC. |
| Dispositivos | Fingerprinting de dispositivo é implementação específica de provedor. |
| Refresh tokens | Mecanismo de protocolo (OAuth2 e variantes) — inteiramente dependente do provedor escolhido. |
| Expiração | Mecânica padrão de sessão, gerenciada pelo provedor. |
| Auditoria | **Este é o único aspecto que precisa sobreviver independentemente do provedor** — mas o que precisa sobreviver é o **evento** ("houve um login/logout/revogação, por quem, quando, sob qual tenant"), não o **estado mutável** da sessão em si. |
| Auth.js ou outro provedor futuro | Qualquer um desses já implementa sua própria gestão de sessão — uma `Sessao` canônica da CONTIFISC seria, na melhor hipótese, redundante, e, na pior, divergente do estado real mantido pelo provedor. |
| Independência de fornecedor | Falha — a forma de uma "sessão" (JWT stateless vs. sessão em banco vs. sessão em cache) muda inteiramente conforme o fornecedor; não há uma forma estável a catalogar hoje. |
| Necessidade de persistência histórica | Existe, mas é satisfeita pelo **evento** de auditoria (login/logout/revogação registrados em `EventoAuditoriaSeguranca`), não pelo objeto de sessão em si, que perde relevância após expirar. |

**Determinação:** a CONTIFISC **não precisa** de um registro canônico próprio de sessão — a
sessão pode e deve permanecer implementação do futuro mecanismo de autenticação escolhido. O que
a CONTIFISC precisa registrar de forma canônica e durável são os **eventos** relacionados a
sessões (criada, revogada, expirada por inatividade) — e isso já está coberto por
`EventoAuditoriaSeguranca` (item 3), não exigindo um objeto `Sessao` separado. **Não confundir os
dois:** `EventoAuditoriaSeguranca` é um registro imutável de fatos passados; uma hipotética
`Sessao` seria um registro mutável de estado presente — são naturezas diferentes, e apenas a
primeira tem semântica estável o suficiente para ser canônica agora.

## 3. `EventoAuditoriaSeguranca` — verificação de escopo

| Conceito | É canônico? | Por quê |
|---|---|---|
| Evento de segurança/auditoria persistente (login, falha de autenticação, mudança de permissão, elevação de privilégio, acesso sensível, override, operação administrativa) | **Sim** | Necessidade de compliance (LGPD) e auditoria interna da própria CONTIFISC, que precisa sobreviver a qualquer troca de provedor de autenticação — o provedor pode não reter esse histórico pelo prazo/forma que a CONTIFISC precisa. |
| Log técnico (stack trace, request/response, métricas de performance) | **Não** | Pertence à camada de observabilidade de infraestrutura (ex.: Datadog/CloudWatch), nunca ao catálogo canônico — transformar "todos os logs da aplicação" em objetos canônicos seria uma inversão de escopo grave, explicitamente evitada aqui. |
| Sessão (item 2) | **Não** | Estado mutável, provider-owned — apenas os *eventos sobre* uma sessão (criação/revogação) entram em `EventoAuditoriaSeguranca`, nunca a sessão em si. |
| Evento de domínio `EVT-001` | **Não é o mesmo conceito** | `EVT-001` (ainda não escrito) trataria de uma arquitetura de eventos de domínio genérica (ex.: "ReceitaCriada", "RevisaoAprovada" para fins de integração/mensageria) — escopo muito mais amplo que segurança. `EventoAuditoriaSeguranca` é deliberadamente estreito (só a lista de eventos de segurança já enumerada no SEC-001 V1.0 §16). Se `EVT-001` um dia for escrito, pode haver reconciliação/unificação futura — **não é uma dependência bloqueante para este CR**, e não deve ser antecipada aqui. |

**Determinação:** `EventoAuditoriaSeguranca` permanece `CANONICO_OBRIGATORIO`, com escopo
estreito e explícito — apenas a lista de eventos de segurança já definida, nunca generalizado
para logging técnico.

## 4. `PapelAcesso` e `Permissao` — reavaliação de necessidade

**Comparação:**

| Modelo | Cobertura dos cenários exigidos | Custo/complexidade |
|---|---|---|
| `ContaAcesso → PapelAcesso → Permissao` (RBAC completo, 2 objetos + 1 relação N:N) | Cobre tudo, inclusive permissões atômicas hipotéticas | Maior — exige catálogo de permissões que nenhum requisito concreto hoje define |
| **Campo `papel` (texto, vocabulário aberto/`DST-GAP`) diretamente nas associações `ContaAcesso ↔ Tenant` e `ContaAcesso ↔ UnidadeEconomica`** | Cobre igualmente todos os cenários hoje conhecidos (funcionário CONTIFISC, administrador, cliente externo, múltiplos tenants, restrição por UE, segregação de funções por comparação de papel) | Menor — mesmo padrão já usado no projeto para vocabulário aberto (`tipo_vinculo`, `papel_vinculo` são campos `TEXT`/`DST-GAP` em `Vinculo`, **não objetos separados**) |

Verificação por cenário exigido:

- Funcionário CONTIFISC: `papel` por concessão de tenant (ex.: `"CONTADOR_RESPONSAVEL"`).
- Administrador: `papel` distinto e nomeado, concessão auditada — não exige objeto `PapelAcesso`.
- Cliente externo: `papel` restrito por concessão.
- Acesso a múltiplos tenants: múltiplas linhas de associação `ContaAcesso ↔ Tenant`, cada uma com
  seu próprio `papel` — já resolvido pela cardinalidade N:N já proposta.
- Restrição por UE: `ContaAcesso ↔ UnidadeEconomica`, com seu próprio `papel` se necessário.
- Segregação de funções: comparação de valores de `papel` (ex.: proibir que quem tem papel
  `SOLICITANTE` também tenha `REVISOR` para o mesmo tenant) — regra de aplicação, não estrutura
  de dado adicional.
- Permissões granulares: **nenhum requisito concreto hoje** exige decompor papéis em permissões
  atômicas — fica como necessidade **potencial**, não confirmada.

**Determinação: `PapelAcesso` e `Permissao` como objetos canônicos separados são
`DIFERIDO`** — um campo `papel` (vocabulário aberto, mesmo padrão de `tipo_vinculo`/
`papel_vinculo`) nas duas associações já propostas resolve integralmente os cenários conhecidos,
sem inventar uma abstração de RBAC completa antes de haver necessidade concreta. **O vocabulário
de `papel` não é fechado por este documento** — permanece um novo `DST-GAP` candidato, mesma
regra já aplicada a `tipo_vinculo` (`DST-GAP-003`).

## 5. Associações de acesso — suficiência e semântica de restrição

As duas relações já propostas (`ContaAcesso ↔ Tenant` via `COT-SUP-005` candidato, `ContaAcesso ↔
UnidadeEconomica` via `COT-SUP-006` candidato) são **suficientes** para representar os cenários
exigidos — nenhuma relação adicional é necessária.

**Autorização por UE: complementa, restringe ou substitui a autorização por Tenant?**

**Restringe — nunca complementa nem substitui.** A concessão de `Tenant` estabelece o escopo
**padrão** (todas as UEs daquele tenant); uma concessão de UE **nunca amplia** esse escopo (não
faz sentido conceder acesso a uma UE que não pertence ao tenant já concedido), e **nunca
substitui** a concessão de Tenant (que continua sendo o pré-requisito — não existe concessão de UE
sem uma concessão de Tenant subjacente).

**Invariante obrigatória (não implementada agora, registrada para o ADR físico):** *quando
existir ao menos uma linha de `ContaAcesso ↔ UnidadeEconomica` para um dado par
(`ContaAcesso`, `Tenant`), a avaliação de autorização deve considerar **apenas** as UEs
explicitamente listadas para aquele par — a existência de uma restrição desliga o padrão "todas
as UEs do tenant" e liga um modelo de lista explícita (default-deny reforçado, nunca aditivo).*
Isso torna estruturalmente impossível interpretar uma restrição de UE como concessão automática
às demais UEs do mesmo tenant.

## 6. Auditoria das treze relações propostas

| Origem | Destino | Cardinalidade | Obrigatoriedade | Justificativa | Documento destino | Classificação |
|---|---|---|---|---|---|---|
| `UnidadeEconomica` | `Tenant` | N:1 | Obrigatória | Âncora raiz de todo o modelo de isolamento | COT, MCD, CDC | `OBRIGATORIA` |
| `Receita` | `UnidadeEconomica` | N:1 | Obrigatória | Contexto de apuração, distinto do titular PF/PJ — achado central do SEC-001 | COT, MCD, CDC | `OBRIGATORIA` |
| `ContribuicaoPrevidenciaria` | `UnidadeEconomica` | N:1 | Obrigatória | Mesma razão | COT, MCD, CDC | `OBRIGATORIA` |
| `VinculoPrevidenciario` | `UnidadeEconomica` | N:1 | Obrigatória | Mesma razão | COT, MCD, CDC | `OBRIGATORIA` |
| `EventoIRPF` | `UnidadeEconomica` | N:1 | Obrigatória | Mesma razão | COT, MCD, CDC | `OBRIGATORIA` |
| `DocumentoFiscal` | `UnidadeEconomica` | N:1 | Obrigatória | Mesma razão, própria (não apenas derivada de `Receita`) | COT, MCD, CDC | `OBRIGATORIA` |
| `ResultadoCalculo` | `UnidadeEconomica` | N:1 | Obrigatória | Sempre presente, mesmo com `CenarioTributario` (item 9) | COT, MCD, CDC | `OBRIGATORIA` |
| `ArquivoOrigem` | `Tenant` | N:1 | Obrigatória | Camada RAW não tem UE unívoca — tenant é a única fronteira estável | COT, MCD, CDC | `OBRIGATORIA` |
| `ConflitoDado` | `Tenant` | N:1 | Obrigatória | Conflito pode envolver mais de uma UE do mesmo tenant | COT, MCD, CDC | `OBRIGATORIA` |
| `RevisaoTecnica` | `Tenant` | N:1 | Obrigatória | Mesma razão de `ConflitoDado` | COT, MCD, CDC | `OBRIGATORIA` |
| `ContaAcesso` | `Tenant` (`COT-SUP-005`) | N:N | Obrigatória | Concessão explícita de acesso — não derivável de nada existente | COT, MCD, CDC | `OBRIGATORIA` |
| `ContaAcesso` | `UnidadeEconomica` (`COT-SUP-006`) | N:N opcional | Obrigatória (a relação; o uso por conta é opcional) | Restrição fina — não derivável da relação com `Tenant` | COT, MCD, CDC | `OBRIGATORIA` |
| `PapelAcesso` | `Permissao` (`COT-SUP-007`) | N:N | — | **Torna-se sem objeto** — `PapelAcesso` e `Permissao` foram reclassificados `DIFERIDO` (item 4); a relação não tem mais o que conectar | — | **`REMOVER`** |

**Nenhuma relação redundante ou derivável foi encontrada entre as 12 relações mantidas** — cada
uma resolve uma necessidade estrutural própria, sem sobreposição com outra. **1 relação removida**
(`PapelAcesso ↔ Permissao`), consequência direta da simplificação do item 4.

**Ajuste necessário decorrente da remoção:** as associações `COT-SUP-005`/`COT-SUP-006` devem
incorporar diretamente um campo `papel` (ver item 4) para não perder a capacidade de diferenciar
concessões — este ajuste é registrado aqui como pendência para a próxima revisão do CR, não
implementado por este relatório.

## 7. Auditoria dos dez campos propostos

**Critério aplicado:** nenhum campo pode existir apenas "para facilitar consultas" — cada um
precisa ser a **única fonte de verdade** para o dado que representa, não uma cópia de
conveniência de algo já derivável.

| Objeto | Campo | Finalidade | Nullable? | Fonte | Invariante | Impacto físico | Classificação |
|---|---|---|---|---|---|---|---|
| `UnidadeEconomica` | `tenant_id` | Âncora raiz do isolamento | Não | Atribuído na criação da UE | Toda UE pertence a exatamente 1 tenant | Nova coluna + FK | `OBRIGATORIO` |
| `Receita` | `unidade_economica_id` | Contexto de apuração (≠ titular PF/PJ) | Não | Processo de lançamento já conhece a UE | Toda Receita canônica pertence a exatamente 1 UE | Nova coluna + FK | `OBRIGATORIO` |
| `ContribuicaoPrevidenciaria` | `unidade_economica_id` | Idem | Não | Idem | Idem | Nova coluna + FK | `OBRIGATORIO` |
| `VinculoPrevidenciario` | `unidade_economica_id` | Idem | Não | Idem | Idem | Nova coluna + FK | `OBRIGATORIO` |
| `EventoIRPF` | `unidade_economica_id` | Idem | Não | Idem | Idem | Nova coluna + FK | `OBRIGATORIO` |
| `DocumentoFiscal` | `unidade_economica_id` | Idem, própria (não apenas herdada de `Receita`) | Não | Processo de ingestão canônica | Idem | Nova coluna + FK | `OBRIGATORIO` |
| `ResultadoCalculo` | `unidade_economica_id` | Idem, coexiste com `cenario_tributario_id` | Não | Processo de cálculo | Consistente com `CenarioTributario.unidade_economica_id` quando ambos presentes (item 9) | Nova coluna + FK + constraint de consistência | `OBRIGATORIO` |
| `ArquivoOrigem` | `tenant_id` | Fronteira de segurança da camada RAW | Não | Contexto autenticado da ingestão | Arquivo pode cobrir múltiplas UEs do mesmo tenant, nunca mais de um tenant | Nova coluna + FK | `OBRIGATORIO` |
| `ConflitoDado` | `tenant_id` | Fronteira de segurança da reconciliação | Não | Contexto do serviço de reconciliação | Nunca agrega itens de tenants diferentes | Nova coluna + FK | `OBRIGATORIO` |
| `RevisaoTecnica` | `tenant_id` | Fronteira de segurança da revisão | Não | Contexto do processo de revisão | Nunca inferido do objeto revisado | Nova coluna + FK | `OBRIGATORIO` |

**Nenhum dos dez campos existe por conveniência de consulta** — todos são a única fonte
estrutural do respectivo dado, confirmando a auditoria já feita nas rodadas anteriores do SEC-001.
**Nenhum campo removido nesta auditoria.**

**Achado adicional (não um dos dez, decorrente do item 4/6):** recomenda-se **adicionar** um
campo `papel` (texto, vocabulário aberto) às associações `COT-SUP-005` e `COT-SUP-006` — não
contido nos dez originais, e não implementado por este relatório, mas necessário para que a
remoção de `PapelAcesso`/`Permissao` não deixe uma lacuna funcional.

## 8. `tenant_id` transversal (`MCD-F9011` candidato) — confirmação

| Propriedade exigida | Confirmado? |
|---|---|
| Semântica exclusivamente de segurança | Sim — nenhuma relação com proveniência/processamento/qualidade (`F9001..F9010`). |
| Não reutiliza `F9001..F9010` | Sim. |
| Não implica que todas as tabelas devam possuir a coluna | Sim — aplicado a exatamente 3 objetos (`ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`), não generalizado. |
| Aplicado somente aos objetos determinados pelo SEC-001 | Sim. |
| Continua ID candidato até aprovação do CR | Sim — nenhum documento foi alterado para atribuí-lo definitivamente. |

**Achado (gap de especificação, não contradição):** o `CR V1.0` original não propôs um ID
candidato **distinto** para `UnidadeEconomica.tenant_id` — esse campo é estruturalmente diferente
de `MCD-F9011` (é a **âncora raiz**, não um campo transversal aplicado a objetos "órfãos" de
caminho de domínio) e deveria receber seu **próprio** ID candidato (ex.: um campo do bloco
`DOM-SEC`, distinto de `F9011`), a corrigir na próxima revisão do CR.

## 9. `ResultadoCalculo` — confirmação de não-XOR

Confirmado: o `CR V1.0` (item 13) **não** introduz XOR entre `unidade_economica_id` e
`cenario_tributario_id` — preserva exatamente a coexistência determinada na auditoria SEC
(`SEC-001_AUDITORIA_CONSISTENCIA_V1.md` §3): `CenarioTributario.unidade_economica_id` já é
`NOT NULL` desde a migration V1 validada, então as duas FKs não competem por ownership; devem
apenas ser consistentes entre si quando ambas presentes. Nenhuma correção necessária neste ponto.

## 10. Integridade `Tenant` × `UnidadeEconomica`

Confirmado: a estratégia `(unidade_economica_id, tenant_id) → unidade_economica(id, tenant_id)`
exige uma chave candidata `UNIQUE(id, tenant_id)` em `unidade_economica` — já registrada
corretamente no `CR V1.0` (itens 22-23) como decisão **arquitetural/física para o ADR**, **não**
implementada no escopo canônico deste CR além de garantir que a **relação**
`UnidadeEconomica → Tenant` (item 6 desta revisão) exista — o que já está corretamente proposto.
Nenhuma correção necessária neste ponto.

## 11. Ordem documental — reavaliação

**Ordem original do `CR V1.0`:** `COT → MCD → CDC → DST → ADR`.

**Problema identificado:** o `DST` só pode registrar um gap semântico (ex.: o novo `DST-GAP`
candidato para o vocabulário de `papel`, item 4) **depois** que o campo correspondente já existe
no `MCD` — a ordem original não deixava essa dependência explícita, e colocava `DST` depois de
`CDC`, quando não há necessidade de `CDC` preceder `DST` (o contrato de obrigatoriedade/
mutabilidade de um campo não depende de sua vocabulário estar aberto ou fechado). Além disso, a
ordem original não incluía uma etapa de **reconciliação cruzada** antes do `ADR` — todas as
rodadas anteriores deste projeto (MCD V1.1→V1.2, CDC V1.1→V1.2, COT V1.0→V1.1, e a própria Errata
controlada nº2 do `ADR-001`) incluíram essa auditoria de fechamento como passo padrão antes de
qualquer decisão física.

**Ordem revisada e recomendada:**

```
COT/MCD estrutural (novos objetos, campos e relações)
  → DST (vocabulário/gaps dos campos recém-criados, incluindo o novo DST-GAP de `papel`)
  → CDC (contratos — direção, obrigatoriedade, mutabilidade)
  → reconciliação (auditoria cruzada COT × MCD × CDC × DST, mesmo padrão já usado no projeto)
  → ADR (decisões físicas: tipos, FKs, FK composta, RLS conceitual, impacto Prisma)
```

Este relatório **corrige** a recomendação de ordem do `CR V1.0` — a ordem original não estava
errada ao ponto de gerar inconsistência grave, mas a nova ordem reduz o risco de retrabalho
(evita escrever `CDC` antes de `DST` decidir algo que afete a redação do contrato) e mantém
consistência com o padrão de reconciliação já estabelecido neste projeto.

## 12. Baseline — confirmação

| Item | Confirmado? |
|---|---|
| Migration pré-SEC (`20260901120000_init_baseline_fisica`) permanece histórica | Sim — sem alteração, sem novo status. |
| Nenhum banco persistente recebeu a migration | Sim — aplicada somente a dois containers descartáveis, ambos destruídos. |
| Nova baseline somente após documentos canônicos sincronizados | Sim — depende da conclusão da sequência do item 11 (COT/MCD→DST→CDC→reconciliação→ADR) antes de qualquer trabalho em `schema.prisma`. |
| Prisma somente depois da aprovação documental | Sim — nenhuma alteração de `schema.prisma` é autorizada antes da aprovação formal do CR revisado e do `ADR` físico subsequente. |
| PostgreSQL descartável será novamente utilizado para validação | Sim — mesmo padrão já usado para a V1 (dois containers Docker descartáveis, aplicação da migration, bateria de testes, destruição ao final) deve se repetir para a nova baseline antes de qualquer banco persistente. |

Nenhuma correção necessária neste ponto.

---

## 13. Resultado consolidado

- **Quantidade final recomendada de novos objetos canônicos:** **2** (`Tenant`,
  `EventoAuditoriaSeguranca`) — reduzido de 5. `Sessao` reclassificada `SEGURANCA_OPERACIONAL`
  (não canônica); `PapelAcesso`/`Permissao` reclassificados `DIFERIDO`.
- **Quantidade final recomendada de relações:** **12** — reduzido de 13 (removida
  `PapelAcesso ↔ Permissao`, consequência da remoção dos dois objetos).
- **Quantidade final recomendada de campos:** **10** — mantidos integralmente, todos confirmados
  como fonte única de verdade, nenhum removido. **+1 recomendação adicional** (`papel` nas
  associações `COT-SUP-005`/`006`) para compensar a remoção de `PapelAcesso`.
- **Itens removidos:** `PapelAcesso` e `Permissao` como objetos canônicos separados; relação
  `PapelAcesso ↔ Permissao`.
- **Itens diferidos:** `PapelAcesso`, `Permissao` (podem voltar a ser canônicos se um requisito
  concreto de RBAC granular surgir); `Sessao` permanece de responsabilidade do futuro provedor de
  autenticação, revisitável apenas se um gap concreto do provedor escolhido exigir persistência
  própria.
- **Inconsistências encontradas (nenhuma bloqueante, todas corrigíveis):**
  1. Falta um ID MCD candidato próprio para `UnidadeEconomica.tenant_id`, distinto de
     `MCD-F9011` (item 8).
  2. Ordem documental original não considerava a dependência `MCD → DST` nem a etapa de
     reconciliação cruzada (item 11) — corrigida.
  3. A remoção de `PapelAcesso`/`Permissao` deixa uma lacuna funcional que precisa ser preenchida
     por um campo `papel` nas duas associações de acesso (itens 4, 6, 7) — não incorporada ainda
     ao texto do CR.
- **Ordem documental recomendada:** `COT/MCD estrutural → DST → CDC → reconciliação → ADR`
  (substituindo `COT → MCD → CDC → DST → ADR` do `CR V1.0`).

Como as três inconsistências acima exigem que o **texto do próprio `SEC-CHANGE-REQUEST-001`**
seja ajustado (remoção de 2 objetos e 1 relação, adição de 1 campo em cada uma das 2 associações,
adição de um ID MCD candidato distinto para `UnidadeEconomica.tenant_id`, e correção da seção de
ordem documental) antes de poder ser considerado a versão final para aprovação — este relatório
não pode concluir que o CR está pronto **como está hoje escrito**.

**SEC-CHANGE-REQUEST-001 REQUER CORREÇÃO**
