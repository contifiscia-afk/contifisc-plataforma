# RLS-001 — Row-Level Security da CONTIFISC (pós-SEC)

**Versão:** 1.0
**Status:** PROPOSTA DE DESENHO FÍSICO — **NÃO APLICADA**. Nenhuma `CREATE POLICY`/
`ENABLE ROW LEVEL SECURITY` foi executada contra o Neon DEV (`contifisc-dev`) ou qualquer banco
persistente. Não implementa autenticação, não implementa Skills, não insere dado real.
**Tipo:** Documento normativo de segurança (paralelo a `ADR-001`, no domínio de RLS física).
**Baseline obrigatória:** `SEC-001` V1.0, `ADR-001` V1.1, `COT-001` V1.2, `MCD-001` V1.4,
`DST-001` V1.3, `CDC-001` V1.4, `SEC-CR-001_RECONCILIACAO_FINAL_V1.0.md`,
`ADR-001_RASTREABILIDADE_POS_SEC_V1.0.md`, `ADR-C014_POC_REPORT.md`,
`MIGRATION_INTEGRATION_TEST_REPORT.md`.

Artefatos que acompanham este documento (todos em `packages/core/prisma/rls/`, exceto a migration
draft):

- `RLS_MATRIX.md` — matriz 25/25 tabelas.
- `RLS_DESIGN_REVIEW.md` — reconciliação, achados, gate.
- `RLS_TEST_PLAN.md` — suíte de testes (especificada, não executada nesta revisão).
- `SECURITY_CONTEXT_CONTRACT.md` — **resolução do achado D2** (contexto de conta autenticada +
  tenant ativo, policy definitiva de `tenant`); adicionado numa segunda rodada desta mesma revisão.
- `packages/core/prisma/migrations/20260917130000_rls_tenant_isolation_DRAFT/migration.sql` —
  SQL proposto, marcado DRAFT, fora da cadeia ativa de migrations do Prisma. Já incorpora a
  resolução de D2 (funções auxiliares + policy definitiva de `tenant`).

## 1. Objetivo

Especificar e validar (por desenho, não ainda por PoC executada) a implementação física de RLS da
CONTIFISC, cobrindo as 25 tabelas físicas da baseline pós-SEC, de forma consistente com `SEC-001`
e `ADR-001` V1.1 §9. Este documento **não autoriza aplicação** — apenas consolida o desenho para
revisão humana e, quando aprovado, uma PoC descartável (mesma disciplina já usada para
`ADR-C005`/`ADR-C014`).

## 2. Escopo

Dentro do escopo: policies `CREATE POLICY` para as 25 tabelas, estratégia de contexto de sessão,
comportamento fail-closed, análise de connection pooling, arquitetura conceitual de roles,
convivência com `ADR-C014`, suíte de testes de isolamento, migration draft.

Fora do escopo (ver seção 19 do prompt que originou este trabalho, reproduzida aqui por
completude): Auth.js, login, OAuth, senha, MFA, sessões, portal de usuário, Skills tributárias,
`RGT-001`, `EVT-001`, `INT-001`, `F9005`/`F9006`, adapter Questor, dashboards, dados reais,
produção, staging, deploy de aplicação, `CREATE POLICY`/`ENABLE`/`FORCE RLS` reais no Neon, roles
definitivos.

## 3. Princípios (herdados de `SEC-001`/`ADR-001`, não reabertos)

- `Tenant` é exclusivamente a fronteira técnica de isolamento — nunca `UnidadeEconomica`,
  `PessoaFisica`, `PessoaJuridica`, `Cliente`/`Organização` ou identidade de autenticação
  (`SEC-001` §1).
- `identidade tributária ≠ identidade de acesso ≠ tenant ≠ unidade econômica` (`SEC-001` §1).
- Defesa em profundidade: autorização na aplicação **e** RLS no PostgreSQL — nunca RLS como única
  camada, nem aplicação como única camada (`SEC-001` §14).
- Fail-closed: ausência de contexto de tenant → zero linhas, nunca "ver tudo" (`ADR-001` §9.3).

## 4. Fronteira Tenant — reafirmação física

`Tenant` (tabela `tenant`) tem exatamente uma coluna (`id`) — nenhum atributo comercial. Uma
`UnidadeEconomica` pertence a exatamente um `Tenant` (`tenant_id NOT NULL`, `ADR-D021`). Todos os
fatos tributários pertencem a um `Tenant` **indiretamente**, via `UnidadeEconomica` (6 hosts de
`MCD-F10004`, `TENANT_DERIVADO_POR_RLS`) ou **diretamente** (3 objetos com `tenant_id`
materializado: `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`).

## 5. Identidade global versus fato tenant-scoped

`PessoaFisica`, `PessoaJuridica`, `FontePagadora` e `ContaAcesso` são identidades/registros
**globais compartilhados** — nenhuma RLS de isolamento por tenant é aplicada a elas (policy
permissiva explícita, ver `RLS_MATRIX.md` e `RLS_DESIGN_REVIEW.md` D1). O isolamento nunca depende
de restringir quem vê a identidade — depende de restringir quem vê os **fatos** que a referenciam
(`ADR-001` §10). Ver matriz completa em `RLS_MATRIX.md`.

## 6. Matriz das 25 tabelas

Ver `packages/core/prisma/rls/RLS_MATRIX.md` — documento dedicado, 25/25 classificadas, nenhuma
sem policy explícita ou justificativa de ausência (`evento_auditoria_seguranca`, item 25, é o único
caso de "zero policies", e é uma decisão deliberada de fail-closed por ausência de campos, não uma
omissão).

## 7. Contexto transacional

Toda transação que toca dado tenant-scoped deve emitir, como **primeira instrução**:

```sql
BEGIN;
SET LOCAL app.current_tenant_id = '<uuid do tenant autorizado>';
-- queries...
COMMIT;
```

Nunca `SET` de sessão (`SET` sem `LOCAL`) — isso persistiria na conexão física além da transação,
criando o vetor de vazamento identificado por `SEC-001` §14.

## 8. `SET LOCAL` — variáveis e leitura

**Duas variáveis** (ver `SECURITY_CONTEXT_CONTRACT.md`, que resolve o achado D2 originalmente
registrado nesta seção):

- `app.current_tenant_id` (ACTIVE TENANT CONTEXT, `ADR-D028`) — tenant ativo da transação.
- `app.current_conta_acesso_id` (AUTHENTICATED ACCOUNT CONTEXT, proposto pelo contrato) —
  identidade autenticada da sessão. Usada **apenas** pela policy definitiva de `tenant` (§17).

As duas são dimensões distintas, nunca fundidas numa só (uma conta pode ter concessão em múltiplos
tenants — contrato §1). Leitura em toda policy: **nunca** `current_setting(...)::uuid` inline —
sempre via `contifisc_current_tenant_id()`/`contifisc_current_conta_acesso_id()` (funções `STABLE`
que nunca lançam exceção, sempre retornam `NULL` em ausência/formato inválido — contrato §3,
correção de robustez sobre o desenho original desta seção).

## 9. Estratégia fail-closed

Toda policy usa o padrão `coluna_tenant = current_setting('app.current_tenant_id', true)::uuid`
(ou o `EXISTS`/join equivalente para tenant derivado) — **nunca** `COALESCE` ou qualquer padrão que
desative o filtro quando o contexto está ausente. Quando `current_setting(...)` retorna `NULL`, a
comparação `NULL::uuid = coluna` avalia para `NULL` (não `true`), e o PostgreSQL trata `NULL` em
`USING`/`WITH CHECK` como "negar" — resultado: 0 linhas visíveis/gravváveis, nunca erro, nunca
"todos os tenants". Confirmado por leitura da semântica padrão de RLS do PostgreSQL; **não
verificado empiricamente nesta sessão** (ver `RLS_DESIGN_REVIEW.md` D5 — Docker indisponível).

## 10. Connection pooling (Neon)

Ver análise completa em `RLS_DESIGN_REVIEW.md` D6. Resumo: o pooler do Neon opera em modo
transacional (compatível com PgBouncer transaction-mode) — `SET LOCAL` é escopado à transação e é
revertido no `COMMIT`/`ROLLBACK`, antes da conexão física voltar ao pool. Isso é estruturalmente
compatível com o requisito de `SEC-001` §14. **Não testado empiricamente contra o endpoint pooled
real do Neon nesta sessão** — recomendado como primeiro passo da PoC (T22 em `RLS_TEST_PLAN.md`).
Para migration/administração, a conexão **direct** (sem `-pooler`) continua preferencial, como já
usado nesta sessão para aplicar a migration inaugural.

## 11. Prisma

O Prisma não gerencia `SET LOCAL` nem RLS (`ADR-001` §6/§16) — a emissão de
`SET LOCAL app.current_tenant_id` deve ocorrer como raw query, primeira instrução de toda
transação que toca dado tenant-scoped, via middleware/wrapper de transação (não implementado nesta
revisão — é trabalho de camada de aplicação, fora de escopo aqui). O PoC de `ADR-C014` já validou
que `$transaction()` do Prisma (tanto em array quanto interativa) mapeia para uma única transação
PostgreSQL — precedente relevante, mas não um teste específico de `SET LOCAL` + RLS, que continua
pendente (`RLS_TEST_PLAN.md`).

## 12. `USING`/`WITH CHECK`

Todas as 24 tabelas com policy real (excluindo `evento_auditoria_seguranca`, sem nenhuma) usam
`FOR ALL` com `USING` e `WITH CHECK` **idênticos** — justificativa: como o predicado sempre resolve
o tenant da linha (própria coluna ou via join/`EXISTS`), aplicar o mesmo predicado nos dois lados
garante tanto que a leitura quanto a escrita (incluindo o valor **novo** em `UPDATE`) respeitem o
tenant ativo, sem necessidade de diferenciar `SELECT`/`INSERT`/`UPDATE`/`DELETE` individualmente.
Isso também bloqueia por construção o cenário "mover um registro para outro tenant via `UPDATE`"
(T10 em `RLS_TEST_PLAN.md`) — o `WITH CHECK` rejeita a linha nova se ela não pertencer ao tenant da
sessão.

## 13. Tenant materializado

5 tabelas: `UnidadeEconomica` (raiz), `ArquivoOrigem`, `ConflitoDado`, `RevisaoTecnica`,
`ContaAcessoTenant`. Policy direta por igualdade de coluna. `WITH CHECK` no `INSERT` garante que o
banco rejeita fisicamente um `tenant_id` de payload de API divergente do contexto de sessão
(reforço físico do requisito de `ADR-001` §8 — a aplicação continua responsável por nunca aceitar
`tenant_id` do payload, mas agora há uma segunda camada).

## 14. Tenant derivado (join de 1–2 hops)

13 tabelas (`Vinculo`, `VinculoExtremidade`, `Receita`, `ContribuicaoPrevidenciaria`,
`VinculoPrevidenciario`, `EventoIRPF`, `DocumentoFiscal`, `ReceitaDocumentoFiscal`,
`DocumentoFiscalArquivoOrigem`, `ClassificacaoEquiparacaoHospitalar`, `CenarioTributario`,
`ResultadoCalculo`, `ContaAcessoUnidadeEconomica`). Predicado `EXISTS` correlacionado, sempre
terminando em `unidade_economica.tenant_id = current_setting(...)::uuid`. Custo de join adicional
em tempo de execução, mitigado por `IDX-006` (`unidade_economica.tenant_id`, já presente na
migration inaugural aplicada).

## 15. Tenant derivado do pai

`ConflitoDadoItem` — deriva exclusivamente via `conflito_dado_id → conflito_dado.tenant_id`. A
referência polimórfica (`objeto_id`/`tipo_objeto`) nunca é usada para derivar tenant (`ADR-D024`,
reafirmado, não reaberto).

## 16. Associações de acesso

`ContaAcessoTenant` (materializado) e `ContaAcessoUnidadeEconomica` (derivado via UE). Ver §17
(`ADR-C014`) para a relação entre as duas.

## 17. `ADR-C014`

As triggers `trg_caue_requires_grant_fixed`/`trg_cat_blocks_if_dependents`/
`trg_ue_tenant_change_guard` **já estão ativas** na migration inaugural pós-SEC aplicada ao Neon
DEV (verificado nesta revisão — não presumido). RLS **não substitui** esse mecanismo: RLS controla
visibilidade/escrita por sessão; `ADR-C014` garante o invariante estrutural entre
`ContaAcessoUnidadeEconomica` e `ContaAcessoTenant`, independente de qual sessão está operando. Os
dois coexistem sem conflito de lock ou de responsabilidade (`RLS_DESIGN_REVIEW.md` D3).

## 18. Roles / bypass (proposta conceitual, nada criado)

Três papéis propostos, nenhum criado nesta revisão:

| Role | Uso | RLS |
|---|---|---|
| `contifisc_migration` | Dono dos objetos; `prisma migrate deploy` | Não sujeito (é o dono; `FORCE ROW LEVEL SECURITY` existe justamente para não depender disso permanecer assim) |
| `contifisc_app` | Runtime da aplicação | Sujeito integralmente — **nunca** `BYPASSRLS`, **nunca** superuser, **nunca** dono das tabelas |
| `contifisc_admin_op` | Operação administrativa futura, nomeada e auditada (`SEC-001` §12) | Sujeito — nenhum bypass "mágico"; caminho de aplicação auditado, gerando `EventoAuditoriaSeguranca` quando esse objeto for detalhado (`GAP-CDC-1.3-002`) |
| `contifisc_provisioning` *(proposto na resolução de D2)* | Provisionamento de `Tenant` novo e primeira `ContaAcessoTenant` (bootstrap — não há concessão prévia possível para a primeira linha) | `BYPASSRLS`, usado **apenas** por caminho administrativo auditado, nunca pelo runtime da aplicação — ver `SECURITY_CONTEXT_CONTRACT.md` §5 |

Nenhum valor mágico de `app.current_tenant_id` (ex.: um UUID reservado tratado como "todos os
tenants" pelas policies) é proposto — isso seria um bypass disfarçado, proibido por `ADR-001` §9.5.

## 19. `FORCE ROW LEVEL SECURITY`

Proposta: ativar em todas as 25 tabelas (draft já inclui). Consequência: RLS se aplica mesmo ao
dono da tabela, exceto role com `BYPASSRLS`/superuser. Como `contifisc_app` nunca deve ser o dono,
`FORCE` é defesa em profundidade de baixo custo — não muda o comportamento esperado se os roles
forem provisionados corretamente, mas protege contra erro futuro de provisionamento.

## 20. Operações administrativas

Ver §18. Nenhuma operação administrativa cross-tenant contorna RLS via valor mágico — a estratégia
preferencial (a validar em PoC futura, não decidida por este documento) é um role PostgreSQL
distinto, usado apenas por caminhos de aplicação auditados.

## 21. Auditoria

`EventoAuditoriaSeguranca` permanece `BLOQUEADO — SEM CAMPOS PARA POLICY` (RLS habilitada, zero
policies) até `GAP-CDC-1.3-002` fechar. Nenhuma tentativa de antecipar colunas ou policy para essa
tabela foi feita.

## 22. Testes

Ver `RLS_TEST_PLAN.md` — 31 testes especificados (25 do escopo mínimo + 6 adicionais desta
revisão), **não executados** nesta sessão (Docker indisponível).

## 23. Dados sintéticos

Toda fixture de teste usa UUIDs e nomes obviamente fictícios (`UE-A (sintética)` etc.) — nenhum
CPF/CNPJ/NFS-e/dado financeiro real é usado em nenhum artefato desta revisão.

## 24. Limitações desta revisão

1. Nenhum teste foi executado empiricamente (Docker indisponível nesta sessão) — desenho segue
   diretamente a matriz já aprovada por `ADR-001`, mas sem evidência própria ainda.
2. Compatibilidade `SET LOCAL` × pooler Neon é análise arquitetural, não teste contra o endpoint
   real.
3. Policy de `tenant` (`RAIZ_PROPRIA_VISIVEL_POR_CONCESSAO`) — **resolvida** nesta mesma revisão
   (achado D2, agora `RESOLVIDO NO DESENHO`; ver `SECURITY_CONTEXT_CONTRACT.md`).
4. Policy `GLOBAL_COMPARTILHADO` como permissiva explícita é uma decisão desta revisão dentro do
   espaço deixado em aberto por `ADR-001` §10 — não uma decisão já fixada anteriormente.

## 25. Gaps

Nenhum gap novo é criado. Gaps preexistentes relevantes e seu status nesta revisão:
`DST-GAP-003`/`GAP-SEC-CR1-002` (exceção residual `Vinculo` sem extremidade UE) — reafirmado, não
resolvido, comportamento fail-closed-seguro implementado. `GAP-CDC-1.3-002`
(`EventoAuditoriaSeguranca`) — reafirmado, RLS bloqueada por ausência de policy. `F9005`/`F9006` —
intocados.

## 26. Critérios para autorização de aplicação futura

1. Achado `RELEVANTE` D2 resolvido por decisão humana explícita.
2. `RLS_TEST_PLAN.md` executado integralmente em PostgreSQL 15 descartável, `CRITICAL = 0` e
   `RELEVANTE = 0` no resultado real.
3. T22 (pooled Neon) executado com sucesso especificamente.
4. Revisão humana do diff completo (`RLS_MATRIX.md`, `RLS_DESIGN_REVIEW.md`, migration draft).
5. Só então: mover a migration draft para a cadeia ativa do Prisma e autorizar
   `prisma migrate deploy` contra o Neon DEV — nunca `prisma db push`.

---

## Atualização pós-PoC — CRITICALs C1/C2/C3 corrigidos

A PoC descartável real (`packages/core/prisma/rls/RLS_POC_REPORT.md`) encontrou 2 `CRITICAL`
(recursão infinita em `vinculo`/`vinculo_extremidade`, e a policy de `tenant` reacoplada a
`app.current_tenant_id` por composição de RLS) que a revisão estática não previu. Um terceiro
(bloqueio de `INSERT` de `Vinculo` novo) foi descoberto durante a correção. Os 3 foram corrigidos
com 2 funções `SECURITY DEFINER` hardened (owner `contifisc_rls_mediator`, `BYPASSRLS`,
`search_path` fixo, `PUBLIC` sem `EXECUTE`, 15/15 testes de abuso passando) e revalidados
empiricamente em 2 execuções independentes — ver
`packages/core/prisma/rls/RLS_POC_CORRECTION_REPORT.md`. A migration DRAFT já reflete a correção;
a evidência original das falhas permanece preservada em `RLS_POC_REPORT.md`, não apagada.

## Gate final desta execução (atualizado após a resolução de D2 e das correções C1/C2/C3)

```
RLS D2 — CONTEXTO DE SEGURANÇA DEFINIDO E APTO PARA PoC DESCARTÁVEL
```

`CRITICAL = 0`, `RELEVANTE = 0` (ver `RLS_DESIGN_REVIEW.md` §4/§5). O achado D2 foi resolvido no
próprio desenho, sem implementar autenticação e sem alterar nenhum objeto canônico. Esta execução
**não** aplicou nada ao Neon DEV, não alterou a migration inaugural, não implementou autenticação,
não fez commit nem push, não avançou para nenhuma outra camada. Próximo passo: executar
`RLS_TEST_PLAN.md` (agora com os testes T32–T47 de D2 incluídos) em PostgreSQL 15 descartável antes
de qualquer aplicação real — ver `RLS-001` §26 e `RLS_DESIGN_REVIEW.md` §6.
