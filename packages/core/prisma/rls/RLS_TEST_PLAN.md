# RLS_TEST_PLAN — CONTIFISC pós-SEC

**Status:** ESPECIFICADO, **NÃO EXECUTADO** nesta sessão (Docker Desktop indisponível — ver
`RLS_DESIGN_REVIEW.md` §1/D5). Todos os testes usam dados sintéticos obviamente fictícios, criados
e destruídos em PostgreSQL 15 descartável. **Nenhum teste toca o Neon DEV.**

## Fixture sintética (comum a todos os testes)

```sql
-- Tenants
INSERT INTO tenant (id) VALUES
  ('00000000-0000-0000-0000-00000000000a'), -- Tenant A
  ('00000000-0000-0000-0000-00000000000b'); -- Tenant B

-- Contas de acesso (identidade minima, sem auth)
INSERT INTO conta_acesso (id) VALUES
  ('00000000-0000-0000-0000-0000000000ca'), -- Conta A
  ('00000000-0000-0000-0000-0000000000cb'); -- Conta B

INSERT INTO conta_acesso_tenant (id, conta_acesso_id, tenant_id, papel) VALUES
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000ca',
   '00000000-0000-0000-0000-00000000000a', 'ADMIN_TENANT'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000cb',
   '00000000-0000-0000-0000-00000000000b', 'ADMIN_TENANT');

-- Unidades Economicas
INSERT INTO unidade_economica (id, nome, status_registro, criado_em, atualizado_em, tenant_id) VALUES
  ('00000000-0000-0000-0000-0000000000ea', 'UE-A (sintetica)', 'ATIVA', now(), now(),
   '00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-0000000000eb', 'UE-B (sintetica)', 'ATIVA', now(), now(),
   '00000000-0000-0000-0000-00000000000b');

-- Fato sintetico minimo em cada categoria relevante (receita, arquivo_origem,
-- conflito_dado, revisao_tecnica, conta_acesso_unidade_economica) --
-- omitido aqui por brevidade, ver script de fixture completo a produzir na
-- PoC (nao criado nesta revisao — apenas especificado).
```

Toda transação de teste segue o padrão (atualizado após a resolução de D2 —
`SECURITY_CONTEXT_CONTRACT.md`):

```sql
BEGIN;
SET LOCAL app.current_conta_acesso_id = '<uuid da conta autenticada do cenário>';
SET LOCAL app.current_tenant_id = '<uuid do tenant ativo do cenário>';
-- query/asserção
COMMIT; -- ou ROLLBACK, dependendo do teste
```

Testes que exercitam apenas a matriz das 24 tabelas restantes (T01–T31, já especificados) podem
omitir `app.current_conta_acesso_id` sem efeito — nenhuma delas depende dessa variável. Os testes
novos desta seção (T32+) exercitam especificamente a policy definitiva de `tenant`.

## Testes

| # | Descrição | Contexto (`SET LOCAL`) | Ação | Resultado esperado |
|---|---|---|---|---|
| T01 | Tenant A lê seus próprios fatos | `tenant_a` | `SELECT * FROM receita` | Só linhas cujo `unidade_economica_id` pertence à UE-A |
| T02 | Tenant A não lê fatos do Tenant B | `tenant_a` | `SELECT * FROM receita WHERE unidade_economica_id = 'UE-B'` | 0 linhas |
| T03 | Tenant B não lê fatos do Tenant A | `tenant_b` | idem, invertido | 0 linhas |
| T04 | Ausência de contexto retorna zero (fail-closed) | nenhum `SET LOCAL` emitido | `SELECT * FROM receita` | 0 linhas (nunca erro, nunca "ver tudo") |
| T05 | Tenant inválido (UUID que não existe em `tenant`) não concede acesso | `SET LOCAL app.current_tenant_id = '<uuid aleatório>'` | `SELECT * FROM receita` | 0 linhas |
| T06 | `INSERT` próprio permitido | `tenant_a` | `INSERT INTO receita (..., unidade_economica_id) VALUES (..., 'UE-A')` | Sucesso |
| T07 | `INSERT` cross-tenant rejeitado | `tenant_a` | `INSERT INTO receita (..., unidade_economica_id) VALUES (..., 'UE-B')` | Rejeitado por `WITH CHECK` (0 linhas afetadas / erro de policy) |
| T08 | `UPDATE` próprio permitido | `tenant_a` | `UPDATE receita SET valor_receita_bruta = 100 WHERE unidade_economica_id = 'UE-A'` | Sucesso |
| T09 | `UPDATE` cross-tenant rejeitado | `tenant_a` | `UPDATE receita SET ... WHERE unidade_economica_id = 'UE-B'` | 0 linhas afetadas (não visível por `USING`) |
| T10 | Tentativa de mover registro para outro tenant via `UPDATE` rejeitada | `tenant_a` | `UPDATE unidade_economica SET tenant_id = 'tenant_b' WHERE id = 'UE-A'` | Rejeitado por `WITH CHECK`; adicionalmente bloqueado por `trg_ue_tenant_change_guard` (defesa em profundidade, `ADR-C014`) |
| T11 | `DELETE` próprio conforme regra | `tenant_a` | `DELETE FROM conflito_dado WHERE tenant_id = 'tenant_a' ...` | Sucesso (tabela permite exclusão direta, `ADR-001` §8) |
| T12 | `DELETE` cross-tenant rejeitado | `tenant_a` | `DELETE FROM conflito_dado WHERE tenant_id = 'tenant_b' ...` | 0 linhas afetadas |
| T13 | Tenant derivado por `UnidadeEconomica` respeitado (`receita`, `contribuicao_previdenciaria`, `vinculo_previdenciario`, `evento_irpf`, `documento_fiscal`, `cenario_tributario`, `resultado_calculo`) | `tenant_a` / `tenant_b` | `SELECT` em cada uma das 7 tabelas | Cada uma isola corretamente por UE |
| T14 | `ConflitoDadoItem` deriva tenant exclusivamente do pai (`ConflitoDado`), nunca da referência polimórfica | `tenant_a` | `SELECT * FROM conflito_dado_item` com item cujo `objeto_id` aponta para objeto de outro tenant | Visibilidade segue `conflito_dado.tenant_id`, ignora `objeto_id`/`tipo_objeto` |
| T15 | `ArquivoOrigem` respeita tenant materializado | `tenant_a` / `tenant_b` | `SELECT` | Isola corretamente |
| T16 | `RevisaoTecnica` respeita tenant materializado | `tenant_a` / `tenant_b` | `SELECT` | Isola corretamente |
| T17 | `ConflitoDado` respeita tenant materializado | `tenant_a` / `tenant_b` | `SELECT` | Isola corretamente |
| T18 | `ContaAcessoUnidadeEconomica` não amplia `ContaAcessoTenant` | `tenant_a` | Criar restrição de UE cujo tenant não tem concessão em `conta_acesso_tenant` para a conta | Rejeitado por `ADR-C014` (`trg_caue_requires_grant_fixed`), independente da RLS |
| T19 | `ADR-C014` continua funcionando com RLS habilitada | `tenant_a` | Reexecutar os 8 cenários A–H de `ADR-C014_POC_REPORT.md` com RLS `ENABLE`/`FORCE` ativas | Mesmos resultados do PoC original (RLS não deve interferir na trigger, que roda como `SECURITY DEFINER` implícito de `BEFORE`/constraint trigger, fora do filtro de linha de `SELECT`) |
| T20 | Transação termina e contexto `SET LOCAL` desaparece | `tenant_a` numa transação, depois nova transação sem `SET LOCAL` na mesma conexão | `SELECT` na segunda transação | 0 linhas (T04) — confirma que `SET LOCAL` não vazou para a transação seguinte na mesma conexão física |
| T21 | Conexão reutilizada não herda tenant anterior | Transação 1 com `tenant_a`, `COMMIT`, Transação 2 na mesma conexão física com `tenant_b` | `SELECT` na Transação 2 | Só dados do Tenant B — nenhum resíduo de A |
| T22 | Teste com conexão pooled (Neon `-pooler`) | idem T20/T21, mas via string de conexão pooled | Mesmo resultado — **não executado nesta revisão** (ver `RLS_DESIGN_REVIEW.md` D6); PRIORITÁRIO na PoC real antes de qualquer aplicação |
| T23 | Teste com conexão direct (quando aplicável — ex. migrations/admin) | idem, via conexão direta | Mesmo resultado esperado (não é o caminho de runtime da aplicação, mas deve continuar seguro) |
| T24 | Comportamento de *owner*/*bypass* verificado explicitamente | Executar como o role dono das tabelas (sem `BYPASSRLS`), com `FORCE ROW LEVEL SECURITY` ativa | RLS **continua** se aplicando ao dono (é exatamente o propósito de `FORCE`) — só um role com `BYPASSRLS`/superuser escaparia, e nenhum role de aplicação deve ter esse atributo |
| T25 | Query sem `WHERE` de tenant não vaza dado por causa da RLS | `tenant_a` | `SELECT * FROM receita` (sem nenhum filtro na query) | RLS filtra automaticamente — resultado idêntico a uma query que tivesse `WHERE` explícito por tenant, provando que a aplicação **não pode** esquecer o filtro e vazar dado |

## Testes adicionais específicos desta revisão (além do mínimo pedido)

| # | Descrição | Por quê |
|---|---|---|
| T26 | `Vinculo`/`VinculoExtremidade` com ambas extremidades UE (mesmo tenant) — visível | Caminho principal da policy de 2 hops (seção 6 do draft) |
| T27 | `Vinculo` com uma extremidade UE e outra PF — extremidade PF deriva tenant da irmã UE | Valida o `OR`/caso 2 da policy de `vinculo_extremidade` |
| T28 | `Vinculo` com as duas extremidades PF/PJ (nenhuma UE) — invisível a QUALQUER tenant | Confirma o comportamento fail-closed da exceção residual (D4) — não é falha, é o resultado esperado e documentado |
| T29 | Tabelas `GLOBAL_COMPARTILHADO` (`pessoa_fisica`, `pessoa_juridica`, `fonte_pagadora`, `conta_acesso`) visíveis independente de `app.current_tenant_id` | Confirma D1 — policy permissiva não é regressão |
| T30 | `evento_auditoria_seguranca`: nenhuma linha visível/inserível por nenhum contexto, mesmo com `app.current_tenant_id` válido | Confirma fail-closed por ausência de policy (item 25 da matriz) |
| T31 | `tenant`: sessão com `app.current_tenant_id = A` só vê a linha do Tenant A, nunca a do Tenant B | Valida a policy provisória (D2) — reafirma que é mais restritiva, nunca mais permissiva, que a versão conceitual completa |

## Testes da resolução de D2 (`SECURITY_CONTEXT_CONTRACT.md`)

| # | Descrição | Contexto | Ação | Resultado esperado |
|---|---|---|---|---|
| T32 | Conta A + Tenant A autorizados (concessão existe) | `conta=A, tenant=A` | `SELECT * FROM tenant` | Linha do Tenant A visível |
| T33 | Conta A tentando Tenant B sem concessão | `conta=A, tenant=B` | `SELECT * FROM tenant WHERE id = 'B'` | 0 linhas — `tenant_id` sozinho não basta, precisa de `ContaAcessoTenant` |
| T34 | Conta inexistente (UUID bem formado, sem linha em `conta_acesso`) | `conta=<uuid aleatório>, tenant=A` | `SELECT * FROM tenant` | 0 linhas |
| T35 | Tenant inexistente | `conta=A, tenant=<uuid aleatório>` | `SELECT * FROM receita` (tabela derivada) | 0 linhas |
| T36 | Conta ausente (`app.current_conta_acesso_id` nunca setado) | `tenant=A` apenas | `SELECT * FROM tenant` | 0 linhas |
| T37 | Tenant ausente (`app.current_tenant_id` nunca setado) | `conta=A` apenas | `SELECT * FROM receita` | 0 linhas (tabelas derivadas continuam exigindo `app.current_tenant_id`) |
| T38 | Conta válida + tenant com formato inválido (`'not-a-uuid'`) | `conta=A, tenant='xyz'` | Qualquer `SELECT` em tabela derivada | 0 linhas, **sem erro** (`contifisc_current_tenant_id()` retorna `NULL`, não lança exceção) — valida a correção do achado D7 |
| T39 | Tenant válido + conta sem nenhuma concessão em lugar nenhum | `conta=<conta órfã>, tenant=A` | `SELECT * FROM tenant` | 0 linhas |
| T40 | UE pertencente ao tenant correto | `conta=A, tenant=A` | `SELECT * FROM receita` com `unidade_economica_id` de UE-A | Visível |
| T41 | UE pertencente a outro tenant | `conta=A, tenant=A` | `SELECT * FROM receita` com `unidade_economica_id` de UE-B | 0 linhas |
| T42 | `ContaAcessoUnidadeEconomica` sem `ContaAcessoTenant` correspondente | `conta=A, tenant=A` | `INSERT INTO conta_acesso_unidade_economica (...)` para UE de um tenant sem concessão prévia | Rejeitado por `ADR-C014` (`trg_caue_requires_grant_fixed`) — independente da RLS, mecanismo já ativo no Neon DEV |
| T43 | Reutilização da conexão após `COMMIT` | Transação 1: `conta=A, tenant=A`, `COMMIT`. Transação 2, mesma conexão física, sem novo `SET LOCAL` | `SELECT * FROM tenant` na Transação 2 | 0 linhas — nenhum resíduo de contexto sobrevive ao `COMMIT` |
| T44 | Rollback não deixa contexto residual | Transação 1: `conta=A, tenant=A`, `ROLLBACK`. Transação 2, mesma conexão, sem `SET LOCAL` | `SELECT * FROM tenant` | 0 linhas — `ROLLBACK` também reverte `SET LOCAL` |
| T45 | Pooler Neon — as duas variáveis via conexão pooled | `conta=A, tenant=A` via string `-pooler` | `SELECT`/`INSERT` nas tabelas afetadas por D2 | Mesmo resultado da conexão direta — **prioritário, não executado nesta revisão** |
| T46 | Tentativa de forjar `tenant_id` (setar um tenant para o qual a conta não tem concessão, mas tentar ler fatos daquele tenant) | `conta=A, tenant=B (forjado)` | `SELECT * FROM receita` de UE pertencente ao Tenant B | 0 linhas — a policy de `receita` depende de `unidade_economica.tenant_id = app.current_tenant_id`, mas nada impede a aplicação de "forjar" um `tenant_id` sem concessão; **a defesa real está na aplicação nunca aceitar um `tenant_id` que a conta não possui** (fora do alcance físico da policy de `receita`, que confia no valor de `app.current_tenant_id` já validado no login) — ver nota abaixo |
| T47 | Tentativa de forjar `conta_acesso_id` | `conta=<uuid de outra conta, forjado>, tenant=A` | `SELECT * FROM tenant` | Retorna os tenants da conta forjada, não da conta real — **a defesa real está inteiramente na camada de autenticação popular corretamente `app.current_conta_acesso_id`; nenhuma policy RLS pode validar que o GUC recebido corresponde à identidade real, porque essa validação é, por definição, o próprio ato de autenticar** |

**Nota crítica sobre T46/T47 — limite estrutural desta camada, não um defeito:** RLS protege contra
"a aplicação esqueceu o filtro" e contra "a conta tem o `tenant_id` mas não a concessão real" —
**não** protege contra "a camada de aplicação/autenticação está comprometida ou com bug e seta um
`app.current_conta_acesso_id`/`app.current_tenant_id` errado por conta própria". Esse é
precisamente o motivo de `SEC-001` §14 exigir "defesa em profundidade = autorização na aplicação +
RLS", nunca RLS isolada. Este contrato **assume** que a camada de aplicação (fora de escopo aqui)
popula os dois GUCs corretamente a partir de uma autenticação real e de uma seleção de tenant já
validada contra as concessões da conta — a policy de `tenant` (§5 do contrato) é o que permite à
própria aplicação **verificar** quais tenants uma conta pode selecionar, fechando esse ciclo, mas
não pode proteger contra uma camada de autenticação que já esteja mentindo sobre quem é o usuário.

## Critérios de aprovação (espelha `ADR-001` V1.1 §17 + item 21 do prompt original)

- Todos os estados finais inválidos bloqueados (T02/T03/T05/T07/T09/T10/T12/T18).
- Estados finais válidos aceitos (T01/T06/T08/T11).
- Fail-closed sem contexto (T04) e com contexto inválido (T05).
- `SET LOCAL` não vaza entre transações/conexões reutilizadas (T20/T21).
- Compatibilidade com pooling Neon confirmada empiricamente (T22) — **pendente**, não executado.
- `ADR-C014` continua íntegro com RLS ativa (T19).
- Nenhuma query sem filtro explícito vaza dado (T25).
- `CRITICAL = 0`, `RELEVANTE = 0` na execução real (a executar).

**Execução real desta suíte é o próximo passo recomendado antes de qualquer aplicação — ver
`RLS_DESIGN_REVIEW.md` §6.**
