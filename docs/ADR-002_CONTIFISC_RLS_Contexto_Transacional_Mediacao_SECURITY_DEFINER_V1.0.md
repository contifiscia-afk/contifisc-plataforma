# ADR-002 — RLS, Contexto Transacional e Mediação `SECURITY DEFINER`

**Versão:** 1.0
**Status:** **APROVADO.** Revisado integralmente contra o SQL empiricamente validado
(`RLS_POC_CORRECTION_REPORT.md`, `RLS_PRE_NEON_REVIEW_REPORT.md`) e confirmado sem divergência.
Aprovação autoriza o registro formal de `ADR-D031/D032/D033` como baseline física vigente — a
aplicação real no Neon DEV é autorizada separadamente, na mesma sessão, pelas fases subsequentes
(`RLS_NEON_DEPLOYMENT_REPORT.md`).
**Tipo:** Architecture Decision Record — complementar, aditivo.
**Supersede:** Nenhum. **Não reabre nem reescreve `ADR-001` V1.1**, que permanece a baseline física
histórica aprovada do domínio tributário + segurança/tenant (matriz RLS conceitual, `ADR-D028`
contexto de sessão, `ADR-C011..C014`). Este ADR registra, de forma **aditiva**, as decisões físicas
novas que a implementação real e a PoC empírica (`RLS_POC_REPORT.md`,
`RLS_POC_CORRECTION_REPORT.md`) tornaram necessárias e que `ADR-001` V1.1 não antecipava em nível
de detalhe suficiente.
**Baseline obrigatória:** `ADR-001` V1.1 (inalterado), `SEC-001` V1.0, `SECURITY_CONTEXT_CONTRACT.md`,
`RLS-001`, `RLS_MATRIX.md`, `RLS_POC_REPORT.md`, `RLS_POC_CORRECTION_REPORT.md`.

## 0. Por que este ADR existe

`ADR-001` V1.1 §9 definiu a **estratégia conceitual** de RLS (matriz de 25 tabelas, variável de
sessão `app.current_tenant_id`, fail-closed, pooling, roles conceituais) mas deixou expressamente
"nenhuma `CREATE POLICY` é escrita nesta revisão" (§9, reafirmação final) — a implementação física
real ficou para uma etapa posterior. Ao implementar e **testar empiricamente** essa estratégia
(`RLS_POC_REPORT.md`), 2 dos 25 desenhos (`tenant`, `vinculo`/`vinculo_extremidade`) revelaram uma
limitação estrutural do PostgreSQL não antecipada por `ADR-001`: **uma policy RLS não pode
consultar, via SQL comum, uma tabela que também tem RLS+`FORCE` ativas, sem que o PostgreSQL
reaplique a policy da tabela consultada** — causando recursão infinita (quando a tabela consultada
é a mesma) ou reacoplamento indevido de contexto (quando é outra tabela protegida por uma dimensão
diferente). A correção (`RLS_POC_CORRECTION_REPORT.md`) introduziu um mecanismo físico novo —
funções `SECURITY DEFINER` de mediação mínima, com um role interno dedicado — que não é mencionado
em `ADR-001` V1.1 e precisa de registro formal próprio.

## 1. Decisões físicas novas

### ADR-D031 — Role interno `contifisc_rls_mediator`

| Aspecto | Decisão |
|---|---|
| Atributos | `NOSUPERUSER`, `NOLOGIN`, `BYPASSRLS` |
| Propósito | **Exclusivamente** ser owner das 2 funções `SECURITY DEFINER` de `ADR-D032` |
| Não é | Role de runtime (`contifisc_app`), de migration/admin (`contifisc_migration`), nem de provisioning (`contifisc_provisioning`, `ADR-001`/`SECURITY_CONTEXT_CONTRACT.md` §5) — quatro papéis distintos, nunca colapsados |
| Credenciais | Nenhuma — `NOLOGIN` torna impossível autenticar diretamente como este role |
| Uso pela aplicação | **Nunca**, direto ou indireto — a aplicação só invoca as 2 funções (via `EXECUTE`, `ADR-D032`), nunca assume a identidade do role |
| Privilégios nas tabelas | Mínimos: `GRANT SELECT` (nunca `INSERT`/`UPDATE`/`DELETE`) apenas nas 3 tabelas que as funções leem (`conta_acesso_tenant`, `vinculo_extremidade`, `unidade_economica`) |
| Justificativa do `BYPASSRLS` | Necessário e suficiente — `SECURITY DEFINER` sozinho **não** basta sob `FORCE ROW LEVEL SECURITY` (demonstrado empiricamente, `RLS_POC_CORRECTION_REPORT.md` §4, teste SD12: função idêntica com owner sem `BYPASSRLS` retornou resultado incorreto) |

### ADR-D032 — Funções `SECURITY DEFINER` de mediação mínima

| Função | Responsabilidade | Retorno |
|---|---|---|
| `contifisc_conta_tem_acesso_tenant(conta_acesso_id uuid, tenant_id uuid)` | "Esta conta tem concessão `ContaAcessoTenant` para este tenant?" | `boolean` |
| `contifisc_vinculo_tem_extremidade_no_tenant(vinculo_id uuid, tenant_id uuid)` | "Este vínculo tem alguma extremidade UE deste tenant?" | `boolean` |

Propriedades obrigatórias (todas verificadas empiricamente, `RLS_POC_CORRECTION_REPORT.md` §4,
testes SD01-SD15):

- `LANGUAGE sql`, sem SQL dinâmico, sem `EXECUTE`, sem concatenação de parâmetros (SD09).
- `SET search_path = pg_catalog, public` fixo — imune a `search_path` malicioso da sessão
  chamadora e a objetos homônimos em schema controlável pelo chamador (SD07/SD08, demonstrado com
  um schema `evil` contendo uma linha forjada, ignorada corretamente).
- Todas as referências de tabela schema-qualificadas explicitamente (`public.<tabela>`).
- Retorno estritamente `boolean` — nunca uma linha, nunca um conjunto de linhas, nunca conteúdo de
  fato tributário (SD10).
- `REVOKE ALL ... FROM PUBLIC` explícito; `GRANT EXECUTE` apenas ao(s) role(s) que precisam
  (SD01/SD02).
- `NULL`/UUID malformado/inexistente em qualquer parâmetro resolve para `false` por construção
  (comparação nunca casa com `NULL`), nunca lança exceção, nunca concede acesso (SD03-SD06).
- Owner explicitamente `contifisc_rls_mediator` (SD11), nunca o role de runtime (SD14), nunca
  `PUBLIC`.
- **Proibição expressa:** nenhuma função deste padrão pode aceitar parâmetros que permitam
  reconstrução de consulta arbitrária, nem se tornar mecanismo genérico de bypass — cada função
  responde a exatamente uma pergunta de autorização, mínima e fixa.

**Escopo de aplicação — apenas onde estritamente necessário:** somente as 2 tabelas cujo desenho
de RLS exige consultar outra tabela também protegida por RLS (`tenant` → `conta_acesso_tenant`;
`vinculo`/`vinculo_extremidade` → `vinculo_extremidade`/`unidade_economica`). As demais 22 tabelas
da matriz **não usam nem precisam** deste mecanismo — resolvem tenant consultando apenas
`unidade_economica` sob a mesma variável que já protege a tabela derivada, sem composição
conflitante (`RLS_POC_REPORT.md`, confirmado empiricamente antes mesmo da correção).

### ADR-D033 — Policies de `vinculo`/`vinculo_extremidade` separadas por comando

**Decisão:** abandonar o padrão `FOR ALL` (usado nas demais 23 tabelas com policy) especificamente
para `vinculo` e `vinculo_extremidade`, substituindo por 4 policies cada (`SELECT`, `INSERT`,
`UPDATE`, `DELETE`).

| Tabela | Comando | `USING` | `WITH CHECK` | Justificativa |
|---|---|---|---|---|
| `vinculo` | `SELECT` | `contifisc_vinculo_tem_extremidade_no_tenant(id, ctx)` | — | Idêntico ao padrão das demais tabelas `TENANT_DERIVADO_POR_RLS` |
| `vinculo` | `INSERT` | — | `true` | **Estrutural, não de design**: `Vinculo` não tem nenhuma coluna própria que identifique tenant — é 100% derivado de extremidades que, por construção da FK, ainda não existem no momento do próprio `INSERT` do pai. Nenhum predicado é logicamente satisfazível aqui. A garantia de isolamento permanece intacta por 3 camadas independentes: (1) FK obriga `vinculo_extremidade` a referenciar um `vinculo` já existente, nunca o contrário; (2) `ADR-C005` (constraint trigger já validada) exige exatamente 2 extremidades até o `COMMIT`, sob pena de a transação inteira falhar — nenhum `Vinculo` "vazio" sobrevive; (3) a policy de `SELECT` (acima) continua exigindo extremidade válida do tenant ativo — um `Vinculo` inserido sem extremidades corretas fica permanentemente invisível a todos, nunca acessível |
| `vinculo` | `UPDATE` | `fn(id, ctx)` | `fn(id, ctx)` | Por esta altura as extremidades já existem (linha pré-existente) — o padrão função volta a ser satisfazível e idêntico ao das demais tabelas |
| `vinculo` | `DELETE` | `fn(id, ctx)` | — | Idem |
| `vinculo_extremidade` | `SELECT` | `fn(vinculo_id, ctx)` | — | Idêntico ao padrão geral |
| `vinculo_extremidade` | `INSERT` | — | `(unidade_economica_id IS NOT NULL AND EXISTS(...UE pertence ao tenant ativo...)) OR unidade_economica_id IS NULL` | **Checagem direta, não circular**: se a extremidade sendo inserida é ela mesma uma UE, valida diretamente contra `unidade_economica` (sem depender de nenhuma outra linha de `vinculo_extremidade`, eliminando o problema que causava C1). Se é PF/PJ (sem UE), é permitida — não carrega tenant próprio e não amplia superfície de vazamento (uma extremidade PF/PJ isolada nunca concede acesso a nenhum fato tributário); a garantia continua na policy de `SELECT`, que exige alguma extremidade UE do tenant certo para o vínculo inteiro ser visível |
| `vinculo_extremidade` | `UPDATE` | `fn(vinculo_id, ctx)` | `fn(vinculo_id, ctx)` | Extremidades irmãs já existem nesse ponto — padrão função aplicável |
| `vinculo_extremidade` | `DELETE` | `fn(vinculo_id, ctx)` | — | Idem |

**Por que isso não reduz isolamento cross-tenant** (item explicitamente exigido pela revisão):
nenhuma das regras de `INSERT` acima permite a um `ContaAcesso` do Tenant A **ler** ou **modificar**
um `Vinculo`/`VinculoExtremidade` existente do Tenant B — a permissividade é estritamente sobre
**criar linhas novas**, e mesmo assim: (a) uma UE de outro tenant continua explicitamente rejeitada
no `INSERT` da extremidade (testado, `RLS_POC_CORRECTION_REPORT.md` §2); (b) o `UNIQUE(vinculo_id,
lado_extremidade)` (`ADR-C003`) impede "completar" um vínculo alheio que já tenha suas 2
extremidades preenchidas; (c) `ADR-C005` bloqueia qualquer vínculo com cardinalidade diferente de
exatamente 2 até o `COMMIT`. Testado e confirmado empiricamente (T26-T28, C1/C3 do
`RLS_POC_CORRECTION_REPORT.md`, reproduzido em 2 execuções independentes).

### Coexistência com `ADR-C014`, pooling Neon e Prisma (confirmação explícita)

- **`ADR-C014`** (triggers `trg_caue_requires_grant_fixed`/`trg_cat_blocks_if_dependents`/
  `trg_ue_tenant_change_guard`, já ativos desde a migration inaugural): nenhuma das 3 decisões
  desta revisão o altera, remove ou enfraquece. `conta_acesso_unidade_economica` continua usando o
  padrão de função simples (contra `unidade_economica` apenas), sem precisar do mecanismo de
  mediação — os dois sistemas operam em camadas independentes (RLS = visibilidade por sessão;
  `ADR-C014` = invariante estrutural entre tabelas, independente de sessão) e foram testados juntos
  sem conflito (T18/T19/T42, reproduzido em todas as execuções de PoC).
- **Pooling Neon**: `SET LOCAL app.current_tenant_id`/`app.current_conta_acesso_id` confirmados
  empiricamente compatíveis com o pooler transacional do Neon (endpoint `-pooler`) — T22,
  `RLS_PRE_NEON_REVIEW_REPORT.md` §4: contexto visível dentro da transação, ausente após
  `COMMIT`/`ROLLBACK`, sem resíduo em reuso de conexão.
- **Prisma `$transaction()`**: confirmado que `SET LOCAL` e as queries subsequentes usam a mesma
  conexão física dentro de uma `$transaction()`, e que o pool interno do Prisma não vaza contexto
  entre transações — testado contra containers descartáveis e contra o Neon real (direct e
  pooled), sem divergência.

## 2. Gate

| Achado | Severidade |
|---|---|
| `ADR-D031/D032/D033` revisados contra o SQL validado nesta aprovação | ✓ — nenhuma divergência encontrada |
| Nenhuma decisão canônica (`COT`/`MCD`/`CDC`/`DST`) alterada | ✓ confirmado — tudo aqui é físico/implementação |
| Nenhuma decisão física já aprovada em `ADR-001` V1.1 reaberta sem conflito concreto | ✓ — `ADR-001` permanece integralmente vigente; este ADR apenas preenche um nível de detalhe físico que `ADR-001` deliberadamente não desceu (§9, "nenhuma `CREATE POLICY` é escrita") |

**Contagem:** `CRITICAL = 0`, `RELEVANTE = 0`.

### Conclusão do gate

```
ADR-002 V1.0 — APROVADO
```

## 3. Decisão

**Aprovado.** Nenhuma divergência encontrada entre este documento e o SQL empiricamente validado
(checksum `a82e3c08...255f9` da migration DRAFT correspondente, `RLS_POC_CORRECTION_REPORT.md`
§8/`RLS_PRE_NEON_REVIEW_REPORT.md` §7). A aprovação registra formalmente `ADR-D031/D032/D033` como
baseline física vigente. A aplicação real no Neon DEV segue como fase subsequente autorizada
separadamente na mesma sessão — ver `RLS_NEON_DEPLOYMENT_REPORT.md`.

---
**Governança:** `ADR-001` continua a baseline física primária do domínio tributário + segurança/
tenant. Este `ADR-002` é estritamente aditivo, cobrindo exclusivamente o mecanismo de mediação
`SECURITY DEFINER` e a estrutura de policies por comando de `Vinculo`/`VinculoExtremidade` — nunca
reescreve, reabre ou contradiz decisão de `ADR-001` sem conflito concreto documentado.
