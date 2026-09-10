# PoC ADR-C014 — Relatório de Validação Empírica

**Status:** PoC EXPERIMENTAL, EXECUTADA E CONCLUÍDA. Todos os containers e volumes descartáveis
foram destruídos ao final. Nenhum `schema.prisma` canônico, migration real, documento normativo,
RLS, autenticação, aplicação ou banco persistente foi alterado.

**A variante anteriormente chamada "fixed" (`01_schema_fixed.sql`) foi tratada nesta rodada como
CANDIDATA — não como solução previamente validada.** Sua validade é estabelecida exclusivamente
pelos resultados empíricos abaixo.

---

## 1. Ambiente — versões efetivamente utilizadas

| Componente | Versão |
|---|---|
| PostgreSQL | **15.19** (Debian 15.19-1.pgdg13+2), imagem oficial `postgres:15` |
| Docker Engine | **29.7.2** (API 1.55) |
| Docker Desktop | **4.88.1** (build 237512) |
| Prisma CLI / `@prisma/client` | **6.19.3** |
| Node.js | **v24.19.0** |

Três containers descartáveis foram usados, todos destruídos ao final (`docker rm -f`), junto com
os 4 volumes anônimos que cada `docker run` desta sessão criou (volumes de outras sessões,
datados de 29/08 e 01/09, foram explicitamente preservados, não removidos):

- `poc-c014-naive` — variante ingênua (`00_schema_naive.sql`), porta `55521`.
- `poc-c014-candidate` — variante candidata (`01_schema_fixed.sql`), porta `55522`.
- `poc-c014-repro` — segunda aplicação da variante candidata, do zero, porta `55523` (repetibilidade).

---

## 2. HIPOTESE

O invariante `ADR-C014` — *"toda linha de `ContaAcessoUnidadeEconomica` deve corresponder a uma
linha de `ContaAcessoTenant` para o mesmo `conta_acesso_id` e o `tenant_id` da `UnidadeEconomica`
referenciada"* — pode ser garantido fisicamente em PostgreSQL por uma `CONSTRAINT TRIGGER
DEFERRABLE INITIALLY DEFERRED` (`trg_caue_requires_grant`), complementada por triggers simétricos
que impedem (a) remover uma concessão `ContaAcessoTenant` enquanto restrições dependentes existem
e (b) mover `UnidadeEconomica.tenant_id` de forma a órfãos restrições existentes.

Hipótese secundária, explicitada antes dos testes de concorrência: a versão **ingênua** desse
mecanismo (checagem por `SELECT EXISTS`, sem lock explícito) é vulnerável a uma corrida
TOCTOU (time-of-check-to-time-of-use) entre transações concorrentes que tocam a mesma linha de
`ContaAcessoTenant` a partir de tabelas diferentes; a correção candidata (`FOR KEY SHARE` na
leitura de `ContaAcessoTenant` dentro do trigger) deveria fechar essa corrida.

---

## 3. Cenários funcionais A–H (transação única) — variante INGÊNUA e CANDIDATA

Executados via `02_scenarios.sh` contra `poc-c014-naive`, `poc-c014-candidate` e (integralmente
repetidos) `poc-c014-repro`. **Resultado idêntico nas três execuções:**

| Caso | Verificação | Resultado observado |
|---|---|---|
| A | Concessão válida quando existe `ContaAcessoTenant` correspondente (`C1×U1`, `C1` autorizado em `T1`, `U1∈T1`) | **ACEITO** ✓ |
| B | Ausência de autorização Tenant bloqueando o commit (`C2` sem nenhum `ContaAcessoTenant`) | **REJEITADO no commit**, `ERRCODE=P0001`, mensagem `ADR-C014: ... sem conta_acesso_tenant correspondente` ✓ |
| C | Autorização em `T1` não permite UE de `T2` (`C1×U2`, `C1` só tem concessão em `T1`, `U2∈T2`) | **REJEITADO** ✓ |
| D | Remoção de `ContaAcessoTenant` não pode deixar `ContaAcessoUnidadeEconomica` órfã (tenta remover `C1×T1` enquanto o Caso A depende dele) | **REJEITADO**, `trg_cat_blocks_if_dependents` ✓ |
| E | Estado intermediário inválido dentro de transação deferida, seguido de estado final válido, comita (`INSERT` restrição antes, `INSERT` concessão depois, mesma transação) | **ACEITO** ✓ |
| F | Estado final inválido é rejeitado no commit (restrição inserida, concessão nunca criada) | **REJEITADO** ✓ |
| G | Mudança de UE para tenant não autorizado é bloqueada, quando aplicável (defesa em profundidade — canonicamente `unidade_economica_id` é `Imutável` em `ContaAcessoUnidadeEconomica`, então este teste valida o mecanismo mesmo que a aplicação nunca deva emitir esse `UPDATE`) | **REJEITADO** ✓ |
| H1 | Alteração de `UnidadeEconomica.tenant_id` não pode produzir cross-tenant silencioso (mover UE sem criar a concessão no novo tenant) | **REJEITADO**, `trg_ue_tenant_change_guard` ✓ |
| H2 | Mesma alteração, mas criando a concessão correspondente na mesma transação — estado final coerente | **ACEITO** ✓ |

Nenhuma divergência entre a variante ingênua e a candidata nos 8 cenários de transação única —
esperado, já que a correção candidata só afeta o comportamento **sob concorrência**, não a lógica
de validação de uma transação isolada.

---

## 4. Testes de concorrência — as duas direções + interação com `UnidadeEconomica.tenant_id`

**Metodologia:** como o mecanismo é uma `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`
(checagem só ocorre no `COMMIT`), a janela de corrida real entre duas transações concorrentes é
extremamente estreita (microssegundos) para ser observada de forma confiável por controle externo
via `bash`/`sleep`. Para tornar a corrida **deterministicamente observável**, foi usada a técnica
padrão de *delay injection*: uma cópia instrumentada de cada função de trigger, com um
`PERFORM pg_sleep(3)` inserido **depois** de a checagem confirmar "estado seguro" e **antes** do
`RETURN` — alargando artificialmente a janela real (mas nunca alterando a lógica de decisão em
si) para tornar a corrida reproduzível em vez de probabilística. Esta técnica é usada apenas para
diagnóstico; nenhuma versão instrumentada é candidata a produção.

### RACE 1 — `trg_caue_requires_grant` (INSERT restrição) vs `DELETE` de concessão concorrente

| | Ordem das operações | Bloqueio observado | Resultado após COMMIT | SQLSTATE |
|---|---|---|---|---|
| **Ingênua** | X: `BEGIN; INSERT CAUE; COMMIT` (checagem com delay de 3s) — Y: inicia 1s depois, `BEGIN; DELETE ContaAcessoTenant; COMMIT` | **Nenhum** — Y executa e comita livremente (13:53:38.564) enquanto X ainda está "dentro" do trigger (comita depois, 13:53:40.531) | **X: ACEITO. Y: ACEITO.** `cat_existe=false`, `caue_existe=true` | — (ambos sem erro) |
| **Candidata** | Mesma ordem, trigger A com `FOR KEY SHARE` | Y's `DELETE` bloqueou por **1985ms** (quase os 2s restantes do sleep de X) esperando o lock de X | X: ACEITO (13:53:24.362→24.363≈3.01s). **Y: REJEITADO** após o lock liberar — `trg_cat_blocks_if_dependents` viu o `CAUE` já comitado | `P0001` |

**FALHA_OBSERVADA (variante ingênua):** inconsistência real e reproduzível — `ContaAcessoUnidadeEconomica`
sobrevive após seu `ContaAcessoTenant` ser removido. Confirma a hipótese secundária.

**CORRECAO_CANDIDATA:** `FOR KEY SHARE` na leitura de `ContaAcessoTenant` dentro de
`trg_caue_requires_grant_fixed` (`01_schema_fixed.sql`, já presente sem alteração nesta rodada).

**VALIDACAO_DA_CORRECAO:** Y (`DELETE`) mediu **1985ms de bloqueio real**, terminando corretamente
rejeitado assim que o lock foi liberado e o dependente comitado ficou visível. `cat_existe=true`,
`caue_existe=true` — estado final consistente.

### RACE 2 — `trg_cat_blocks_if_dependents` (DELETE concessão) vs `INSERT` de restrição concorrente (direção inversa)

| | Ordem das operações | Bloqueio observado | Resultado após COMMIT | SQLSTATE |
|---|---|---|---|---|
| **Ingênua** | X: `BEGIN; DELETE ContaAcessoTenant; COMMIT` (checagem com delay de 3s) — Y: inicia 1s depois, `BEGIN; INSERT CAUE; COMMIT` | **Nenhum** — Y comita livremente (13:56:04.557) antes de X (13:56:06.318) | **X: ACEITO. Y: ACEITO.** `cat_existe=false`, `caue_existe=true` | — |
| **Candidata** | Mesma ordem, trigger A (não-delayed) com `FOR KEY SHARE`, trigger B com delay | Y's **commit** (não a instrução `INSERT` em si) bloqueou por **1978ms**, porque o `FOR KEY SHARE` de Y precisou aguardar o lock exclusivo que X (`DELETE`) já segurava | X: ACEITO (deleta). **Y: REJEITADO** — `FOR KEY SHARE` de Y, ao ser liberado, encontrou 0 linhas (já deletadas por X) | `P0001` |

**FALHA_OBSERVADA (variante ingênua):** mesma inconsistência de Race 1, produzida pelo mecanismo
inverso — confirma que a corrida existe **nas duas direções** solicitadas.

**VALIDACAO_DA_CORRECAO:** `cat_existe=false`, `caue_existe=false` — estado final consistente (os
dois concordam que a concessão não existe, e nenhuma restrição órfã foi criada).

### RACE 3 — `trg_caue_requires_grant` (INSERT restrição, lê `UnidadeEconomica.tenant_id`) vs `UPDATE` concorrente de `UnidadeEconomica.tenant_id`

| | Ordem das operações | Bloqueio observado | Resultado após COMMIT |
|---|---|---|---|
| **Ingênua** | X: `BEGIN; INSERT CAUE(C1,U1∈T1); COMMIT` (checagem com delay de 3s, lê `tenant_id` de U1 **sem lock explícito**) — Y: inicia 1s depois, `BEGIN; UPDATE U1.tenant_id=T2; COMMIT` | Y's `UPDATE` **bloqueou por ~2056ms** | Y: **REJEITADO** — `trg_ue_tenant_change_guard`, ao ser liberado, viu o `CAUE` de X já comitado e recusou órfão-lo |
| **Candidata** | Mesma ordem | Y's `UPDATE` bloqueou por **~2007ms** (mesmo padrão) | Y: **REJEITADO**, mesmo resultado |

**Achado relevante (não é uma correção do candidato, é um mecanismo independente já presente):**
o `UPDATE unidade_economica.tenant_id` **bloqueou fisicamente** em ambas as variantes — inclusive
na ingênua, onde nenhum `FOR KEY SHARE` explícito foi escrito para esta direção. A causa raiz é
que `conta_acesso_unidade_economica.unidade_economica_id REFERENCES unidade_economica(id)` faz o
PostgreSQL **automaticamente** tomar um lock `FOR KEY SHARE` sobre a linha de `unidade_economica`
referenciada assim que `X` insere a linha de `CAUE` (comportamento nativo de FK, não código
escrito por este PoC). Como `tenant_id` participa da constraint `UNIQUE(id, tenant_id)`
(`ADR-C011`), atualizar `tenant_id` é tratado pelo PostgreSQL como atualização de uma coluna de
chave, exigindo um lock que **conflita** com o `FOR KEY SHARE` que X já segura — por isso o
`UPDATE` de Y fica bloqueado até X liberar, independentemente de qualquer trigger.

Este mecanismo é **incidental**, não projetado deliberadamente para este fim — surge como efeito
colateral de `ADR-C011` (a chave candidata `UNIQUE(id, tenant_id)`, criada por outro motivo:
viabilizar uma futura FK composta). **Recomendação registrada (não bloqueante):** documentar
explicitamente esta dependência em `ADR-001`/comentário do schema, para que uma futura remoção de
`UNIQUE(id, tenant_id)` (por exemplo, se a FK composta prevista nunca se concretizar e alguém
"simplificar" o schema) não reabra esta corrida sem que ninguém perceba a conexão. Ver §11 (gate).

---

## 5. Deadlock

Nenhuma ocorrência de deadlock em nenhum dos testes — confirmado por `docker logs` de ambos os
containers de concorrência (`poc-c014-naive`, `poc-c014-candidate`), buscando por `deadlock`
(nenhuma linha encontrada). Analiticamente, o padrão de contenção observado é de **um único
recurso compartilhado** (a linha de `ContaAcessoTenant`, ou a linha de `UnidadeEconomica`) entre
duas transações — não há ordem cruzada de dois recursos distintos bloqueados em direções opostas,
que é a pré-condição estrutural para deadlock. O comportamento observado em todos os casos foi
fila/espera simples (uma transação aguarda a outra terminar), nunca impasse circular.

---

## 6. Testes via Prisma `$transaction()`

Executados contra `poc-c014-candidate`, usando um `schema.prisma` isolado (`poc-schema.prisma`,
client gerado em `generated-client/`, nunca tocando o `schema.prisma` canônico do projeto):

| Teste | Mecanismo Prisma | Resultado |
|---|---|---|
| Transação válida | `$transaction([...])` (array) | **ACEITO** — `create` de `ContaAcessoUnidadeEconomica` com concessão existente |
| Transação inválida | `$transaction([...])` (array) | **REJEITADO** — erro `P0001` do PostgreSQL propagado integralmente pelo Prisma (`ADR-C014: ... sem conta_acesso_tenant correspondente`) |
| Estado intermediário inválido → final válido | `$transaction(async (tx) => {...})` (interativa) — insere a restrição, depois a concessão, na mesma transação | **ACEITO** — confirma que `DEFERRABLE INITIALLY DEFERRED` funciona corretamente através do Prisma: o estado intermediário (sem concessão) não é validado até o `COMMIT` real emitido pelo Prisma ao final do callback |
| Estado final inválido | `$transaction(async (tx) => {...})` — insere só a restrição, nunca a concessão | **REJEITADO** — erro propagado corretamente no `catch` |

**Confirmado: o Prisma não interfere negativamente no comportamento do `CONSTRAINT TRIGGER`** — a
semântica de commit diferido é preservada integralmente, seja via `$transaction` em array (que o
Prisma executa como uma única transação SQL) ou via `$transaction` interativa.

---

## 7. Introspecção do catálogo PostgreSQL

Executada contra `poc-c014-candidate` (`05_introspection.sql`):

| Item | Resultado |
|---|---|
| `adr_c014_caue_requires_grant` (em `conta_acesso_unidade_economica`) | `tgdeferrable=t`, `tginitdeferred=t`, `eh_constraint_trigger=t` |
| `adr_c014_cat_blocks_if_dependents` (em `conta_acesso_tenant`) | `tgdeferrable=t`, `tginitdeferred=t`, `eh_constraint_trigger=t` |
| `adr_c014_ue_tenant_change_guard` (em `unidade_economica`) | `tgdeferrable=t`, `tginitdeferred=t`, `eh_constraint_trigger=t` |
| Funções associadas | Todas presentes com corpo (`trg_caue_requires_grant_fixed`, `trg_cat_blocks_if_dependents`, `trg_ue_tenant_change_guard`, + variantes instrumentadas de teste) |
| PKs | `tenant_pkey`, `unidade_economica_pkey`, `conta_acesso_pkey`, `conta_acesso_tenant_pkey`, `conta_acesso_unidade_economica_pkey` — 5, uma por tabela |
| FKs | `unidade_economica_tenant_id_fkey`, `conta_acesso_tenant_conta_acesso_id_fkey`, `conta_acesso_tenant_tenant_id_fkey`, `conta_acesso_unidade_economica_conta_acesso_id_fkey`, `conta_acesso_unidade_economica_unidade_economica_id_fkey` — 5, todas `ON DELETE RESTRICT`, exatamente as do desenho aprovado |
| UNIQUEs | `uq_unidade_economica_id_tenant` (`id,tenant_id`, ADR-C011), `uq_conta_acesso_tenant` (`conta_acesso_id,tenant_id`, ADR-C012), `uq_conta_acesso_unidade_economica` (`conta_acesso_id,unidade_economica_id`, ADR-C013) — as 3 esperadas |
| Total de tabelas do PoC | 5 (confirmado) |

Nenhuma estrutura inesperada, nenhuma ausente.

---

## 8. Repetibilidade

`01_schema_fixed.sql` aplicado **sem nenhuma modificação** (checksum MD5 idêntico ao arquivo do
repositório, verificado dentro e fora do container: `2ca0acce57565c8c203a8be20446207f`) em um
**terceiro container, PostgreSQL vazio** (`poc-c014-repro`):

- Os 8 cenários A–H reproduziram **exatamente** os mesmos resultados do primeiro container
  candidato.
- Race 1, reexecutada com a mesma instrumentação, reproduziu o **mesmo padrão de bloqueio**
  (~2000ms de espera) e o **mesmo resultado final consistente** (`cat_existe=true`,
  `caue_existe=true`).

**Repetibilidade em banco vazio confirmada.**

---

## 9. Limitações desta PoC (registradas, não resolvidas por inferência)

- A corrida real (sem instrumentação) é probabilística e de janela extremamente estreita — esta
  PoC prova a **existência estrutural** da vulnerabilidade (ingênua) e da **proteção estrutural**
  (candidata) via injeção de delay determinística, não via observação estatística da taxa de
  falha da versão sem instrumentação em produção. Isso é metodologicamente aceito como prova
  suficiente (mesma lógica de "prova por amplificação de janela" usada em testes de concorrência
  de bancos de dados em geral), mas não é uma medição de probabilidade real de ocorrência.
- A proteção observada em Race 3 depende de `UNIQUE(id, tenant_id)` (`ADR-C011`) permanecer no
  schema — não foi testado o comportamento **sem** essa constraint (não autorizado nesta etapa,
  pois alteraria o desenho já aprovado). Esta dependência foi documentada explicitamente (§4,
  Race 3) para que não seja quebrada inadvertidamente no futuro.
- O espelho exato de Race 3 (delay em `trg_ue_tenant_change_guard`, ao invés de em
  `trg_caue_requires_grant`) não foi executado separadamente — o mecanismo de proteção (lock de
  linha compartilhado via FK nativa) é simétrico por natureza (qualquer uma das duas transações
  que chegar primeiro bloqueia a outra, independentemente de qual delay foi instrumentado), e essa
  simetria já foi confirmada empiricamente nas Races 1/2 (mesma classe de mecanismo, testada nas
  duas direções com resultado idêntico). Registrado como simplificação de escopo, não como gap
  de cobertura material.
- Não foi testado volume/carga (múltiplas transações concorrentes simultâneas além de duas) — fora
  do escopo desta validação de correção, que é sobre corretude, não performance.

---

## 10. Diferença de design em relação à V1.0 original do candidato

Nenhuma. `01_schema_fixed.sql` foi executado **sem alteração** em todo este PoC. Nenhuma nova
variante experimental precisou ser criada, porque a candidata original já demonstrou fechar as
três corridas testadas (a terceira, por um mecanismo incidental e agora documentado, não por
código escrito neste PoC). Não houve necessidade de mascarar, contornar ou reescrever SQL para
fazer o gate passar.

---

## 11. Gate

| Achado | Severidade |
|---|---|
| Variante ingênua apresenta race condition real e reproduzível (Races 1 e 2) — **não é a variante recomendada, nunca esteve em `schema.prisma`/migration** | `CRITICAL` **da variante ingênua**, mas **não bloqueia o gate** — a ingênua nunca foi proposta para incorporação; sua falha é exatamente o que justifica a existência da variante candidata |
| Proteção de Race 3 depende de `UNIQUE(id, tenant_id)` (`ADR-C011`) permanecer no schema — dependência real, não documentada explicitamente até este relatório | `NAO_BLOQUEANTE` — mecanismo já presente e funcionando; requer apenas documentação explícita (recomendado: nota em `ADR-001` e/ou comentário no `schema.prisma` ao lado de `@@unique([id, tenant_id])`) para não ser removido inadvertidamente no futuro |
| Espelho exato de Race 3 (delay em C ao invés de A) não testado separadamente | `EDITORIAL` — simplificação de escopo justificada pela simetria do mecanismo, já validada nas Races 1/2 |
| Nenhuma falha encontrada na variante candidata em nenhum dos 8 cenários funcionais, 3 corridas de concorrência, 4 testes Prisma, introspecção ou repetibilidade | — |

**Contagem para a variante CANDIDATA (a que importa para a decisão de incorporação):**
`CRITICAL = 0`, `RELEVANTE = 0`.

### Verificação dos critérios de aprovação

| Critério | Atendido? |
|---|---|
| Todos os estados finais inválidos bloqueados | ✓ (B, C, D, F, G, H1 — candidata e ingênua, transação única) |
| Estados finais válidos aceitos | ✓ (A, E, H2 — candidata e ingênua) |
| Comportamento deferred previsível | ✓ (E e F provam commit diferido correto; introspecção confirma `tgdeferrable=t`/`tginitdeferred=t` nos 3 triggers) |
| Prisma `$transaction()` validado | ✓ (4/4 casos, incluindo estado intermediário inválido → final válido) |
| Concorrência sem race relevante | ✓ **somente para a candidata** — ingênua tem race CRITICAL, mas não é a variante proposta |
| Sem deadlock relevante | ✓ (nenhum deadlock em nenhum teste) |
| Segunda execução reproduzível | ✓ (container `poc-c014-repro`, checksum idêntico, mesmos resultados funcionais e de concorrência) |
| `CRITICAL = 0` (candidata) | ✓ |
| `RELEVANTE = 0` (candidata) | ✓ |

### Conclusão

```
ADR-C014 VALIDADO — APTO PARA INCORPORAÇÃO NA MIGRATION INAUGURAL PÓS-SEC
```

**Recomendação de acompanhamento (não bloqueante, não executada nesta etapa):** ao redigir a
migration inaugural, adicionar um comentário SQL junto a `UNIQUE(id, tenant_id)` em
`unidade_economica` explicando que essa constraint, além de preparar uma futura FK composta
(`ADR-C011`), também é uma dependência estrutural do fechamento de `ADR-C014` para o eixo
`UnidadeEconomica.tenant_id` — para que uma futura simplificação do schema não a remova sem
perceber essa segunda função.

Nenhuma migration foi gerada. Nenhum banco persistente foi criado. Não se avança automaticamente
para a próxima etapa.
