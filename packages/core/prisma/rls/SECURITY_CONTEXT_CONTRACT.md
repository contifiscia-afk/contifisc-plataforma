# SECURITY CONTEXT CONTRACT — CONTIFISC pós-SEC

**Status:** PROPOSTA DE DESENHO — resolve o achado `RELEVANTE` D2 de `RLS_DESIGN_REVIEW.md`.
Nenhuma alteração aplicada ao Neon DEV. Nenhuma autenticação implementada. Nenhum objeto
canônico (`COT`/`MCD`/`CDC`/`DST`) alterado — este contrato é puramente um mecanismo físico de
sessão PostgreSQL, da mesma classe já autorizada por `ADR-D028` (`app.current_tenant_id`), apenas
estendido a uma segunda dimensão que o próprio `ADR-001` V1.1 §9.1 item 21 já presumia
implicitamente ("uma `ContaAcesso` só deve ver linhas de `tenant` para as quais possui concessão
... join reverso") sem nomear o mecanismo físico — este documento nomeia e especifica esse
mecanismo, não inventa semântica canônica nova.

## 1. Por que duas dimensões distintas (não uma)

| Dimensão | Pergunta que responde | Já existia? |
|---|---|---|
| **AUTHENTICATED ACCOUNT CONTEXT** (`app.current_conta_acesso_id`) | "Quem está autenticado nesta transação?" | Não — proposta nova desta revisão |
| **ACTIVE TENANT CONTEXT** (`app.current_tenant_id`) | "Qual tenant está ativo nesta transação, entre os autorizados para esta conta?" | Sim — `ADR-D028` |

**Por que não fundir as duas em uma só:** uma `ContaAcesso` pode ter concessões em múltiplos
tenants (`SEC-001` §12 — "Funcionários com acesso a múltiplos tenants: múltiplas concessões
explícitas"). A pergunta "quem é" (estável durante toda a sessão de trabalho do usuário) é
logicamente distinta da pergunta "qual tenant está sendo operado agora" (muda quando o usuário
troca de cliente numa UI multi-tenant, por exemplo). Uma única variável não conseguiria expressar
"a Conta X tem 3 tenants autorizados, mas está operando o Tenant B agora" — precisaria escolher
entre perder a informação de identidade ou a de tenant ativo. As duas dimensões são ortogonais e
devem permanecer variáveis separadas.

## 2. As variáveis

| Variável | Tipo lógico | Papel | Já autorizada por |
|---|---|---|---|
| `app.current_conta_acesso_id` | `uuid` (como texto no GUC) | Identidade autenticada da sessão (AUTHENTICATED ACCOUNT CONTEXT) | Proposta nova, mesma classe física de `ADR-D028` |
| `app.current_tenant_id` | `uuid` (como texto no GUC) | Tenant ativo da transação (ACTIVE TENANT CONTEXT) | `ADR-D028` (inalterado) |
| `app.current_unidade_economica_id` *(opcional)* | `uuid` (como texto no GUC) | Restrição fina **adicional**, nunca ampliação, dentro do Tenant já ativo (`SEC-001` §12: "Autorização por `UnidadeEconomica` — Opcional") | Slot do contrato reservado nesta revisão; **não usado por nenhuma policy das 25 tabelas atuais** — nenhuma policy de fato (`Receita`, `DocumentoFiscal` etc.) é restringida por UE via RLS nesta revisão. Usar esta variável para restringir fatos por UE é uma extensão futura, fora do escopo de resolver D2. |

Nenhuma das três variáveis é lida diretamente com `current_setting(...)::uuid` inline nas policies
(padrão usado no draft anterior) — ver §3, mudança que afeta as 24 tabelas restantes.

## 3. Leitura segura — funções auxiliares (impacto nas 24 tabelas restantes)

**Achado desta revisão (item 12 do prompt):** o padrão anterior
`current_setting('app.current_tenant_id', true)::uuid` tem uma falha de robustez não coberta pela
sessão anterior — se a aplicação, por bug, setar `app.current_tenant_id` para um valor que não é
um UUID válido (`'abc'`, string vazia após trim, etc.), o `::uuid` **lança erro** em vez de
retornar `NULL`. Um erro de query não é um vazamento de dado, mas quebra a garantia de "fail-closed
silencioso" e pode se comportar de forma inconsistente dependendo de como a aplicação trata exceção
(algumas implementações ingênuas capturam a exceção e, por engano, seguem em frente sem filtro).
Correção proposta: duas funções SQL `STABLE`, nunca lançam exceção, sempre retornam `NULL` em
ausência/formato inválido:

```sql
CREATE OR REPLACE FUNCTION contifisc_current_tenant_id() RETURNS uuid
LANGUAGE plpgsql STABLE AS $$
DECLARE
  raw text := current_setting('app.current_tenant_id', true);
BEGIN
  IF raw IS NULL OR raw = '' THEN
    RETURN NULL;
  END IF;
  RETURN raw::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION contifisc_current_conta_acesso_id() RETURNS uuid
LANGUAGE plpgsql STABLE AS $$
DECLARE
  raw text := current_setting('app.current_conta_acesso_id', true);
BEGIN
  IF raw IS NULL OR raw = '' THEN
    RETURN NULL;
  END IF;
  RETURN raw::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END;
$$;
```

**Todas as 24 tabelas com policy real** (as 23 já desenhadas na revisão anterior + a definitiva de
`tenant`, §5) devem usar `contifisc_current_tenant_id()` no lugar do `current_setting(...)::uuid`
inline. Isso **não muda nenhum predicado lógico** das 24 tabelas — é uma substituição mecânica de
robustez, não uma mudança de desenho. Nenhuma tabela ganha ou perde isolamento por causa desta
mudança.

## 4. Comportamento — tabela de decisão completa

| Cenário | `conta_acesso_id` | `tenant_id` | Comportamento |
|---|---|---|---|
| Ausência total de contexto | ausente | ausente | 0 linhas em toda tabela tenant-scoped (funções retornam `NULL`; toda comparação/`EXISTS` correlacionado com `NULL` nunca é `true`) |
| Só tenant setado | ausente | presente | 0 linhas — nenhuma tabela confia em `tenant_id` sozinho; a policy definitiva de `tenant` (§5) exige explicitamente `conta_acesso_id` para resolver a concessão |
| Só conta setada | presente | ausente | 0 linhas nas tabelas tenant-scoped por `tenant_id` (as 23 restantes); `tenant` (§5) pode listar os tenants da conta mesmo sem `tenant_id` ativo — ver nota em §5 |
| `conta_acesso_id` com formato inválido (não-UUID) | inválido | qualquer | Função retorna `NULL` (nunca erro) → mesmo efeito de ausência |
| `tenant_id` com formato inválido | qualquer | inválido | Idem |
| `conta_acesso_id` bem formado mas inexistente em `conta_acesso` | inexistente | qualquer | `EXISTS` contra `conta_acesso_tenant`/`conta_acesso` não encontra nada → 0 linhas |
| `tenant_id` bem formado mas inexistente em `tenant` | qualquer | inexistente | Idem |
| Conta válida + tenant válido, **sem** concessão (`ContaAcessoTenant`) para o par | válido, sem grant | válido, sem grant | 0 linhas — o banco verifica a concessão via `EXISTS`, nunca confia apenas no `tenant_id` informado pela aplicação (requisito explícito da tarefa) |
| Conta válida + tenant válido, **com** concessão | válido | válido, com grant | Acesso concedido às linhas do tenant, conforme a categoria de cada tabela (matriz) |

**Princípio geral:** todo caminho de falha (ausência, formato inválido, inexistência, falta de
concessão) converge para **o mesmo resultado observável — 0 linhas** — nunca um erro distinguível
que permita a um atacante inferir qual das causas ocorreu (nenhuma policy usa `RAISE EXCEPTION`
customizado), e nunca "ver tudo".

## 5. Policy definitiva de `tenant` (resolve D2)

```sql
DROP POLICY IF EXISTS tenant_isolation_provisorio ON tenant;

CREATE POLICY tenant_isolation ON tenant
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM conta_acesso_tenant cat
      WHERE cat.conta_acesso_id = contifisc_current_conta_acesso_id()
        AND cat.tenant_id = tenant.id
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conta_acesso_tenant cat
      WHERE cat.conta_acesso_id = contifisc_current_conta_acesso_id()
        AND cat.tenant_id = tenant.id
    )
  );
```

**Propriedades:**

- Usa **apenas** `app.current_conta_acesso_id` — deliberadamente **não** depende de
  `app.current_tenant_id` estar setado. Justificativa: a pergunta que esta policy responde é
  "quais tenants esta conta pode enxergar/trocar entre si" (plural, útil para uma futura UI de
  seleção de tenant) — não "o tenant ativo agora", que é uma pergunta diferente (§1). Uma conta com
  concessão em 3 tenants vê as 3 linhas de `tenant`, independentemente de qual está ativo em
  `app.current_tenant_id` no momento.
- O banco verifica a concessão diretamente (`EXISTS` contra `conta_acesso_tenant`) — nunca aceita
  `tenant_id` fornecido livremente pela aplicação como prova de autorização.
- Fail-closed: sem `app.current_conta_acesso_id` válido, `EXISTS` nunca é satisfeito → 0 linhas.
- `WITH CHECK` idêntico ao `USING` pela mesma justificativa geral do resto da matriz (§12 de
  `RLS-001`) — mas ver nota operacional abaixo sobre provisionamento.

**Nota operacional — provisionamento (não resolvida por RLS, documentada para não ser esquecida):**
criar um `Tenant` novo é, por definição, um evento sem nenhuma `ContaAcessoTenant` ainda existente
para ele (a concessão só pode ser criada depois que o tenant existe). Com `FORCE ROW LEVEL
SECURITY` ativa (`RLS-001` §19), **nem o role dono da tabela** conseguiria satisfazer este
`WITH CHECK` para o primeiro `INSERT` de um tenant novo, a menos que tenha `BYPASSRLS`. Isso não é
uma falha desta policy — é uma consequência esperada de fail-closed aplicado universalmente.
**Resolução proposta (arquitetura de roles, não uma nova policy):** o provisionamento de tenant/
primeira concessão deve ocorrer através de um role administrativo com `BYPASSRLS`
(`contifisc_provisioning`, distinto de `contifisc_app`), usado **apenas** por um caminho de
aplicação administrativo auditado (nunca pelo role de runtime da aplicação) — consistente com
`SEC-001` §12 ("Administrador interno CONTIFISC: concessão nomeada e auditada"). Nenhum role é
criado por este documento; esta é uma extensão do desenho conceitual de `RLS-001` §18, não uma
policy SQL.

## 6. Interação com `ContaAcessoUnidadeEconomica` e `ADR-C014`

Sem mudança em relação a `RLS-001` §17: `ADR-C014` (triggers já ativas no Neon DEV) continua sendo
o único mecanismo que garante "toda `ContaAcessoUnidadeEconomica` pressupõe uma
`ContaAcessoTenant` correspondente" — este contrato de contexto **não** substitui, duplica ou
enfraquece essa garantia. A policy de `conta_acesso_unidade_economica` (RLS_MATRIX item 24)
permanece inalterada por este documento — continua usando apenas `contifisc_current_tenant_id()`
(via `unidade_economica.tenant_id`), não `conta_acesso_id`, porque essa tabela não está na
categoria `RAIZ_PROPRIA_VISIVEL_POR_CONCESSAO` (só `tenant` está). Confirma-se explicitamente:
`ContaAcessoUnidadeEconomica` **nunca** amplia ou substitui `ContaAcessoTenant` — nem
conceitualmente (`SEC-001` §1.3 do prompt original / `CDC-REL-SEC-001`) nem fisicamente (nenhuma
policy desta revisão relaxa essa regra).

## 7. Pooling — reavaliação com duas variáveis

A análise de `RLS_DESIGN_REVIEW.md` D6 (Neon pooler transacional, `SET LOCAL` revertido no
`COMMIT`/`ROLLBACK` antes da conexão física voltar ao pool) se aplica **identicamente** às duas
variáveis — ambas são GUCs de aplicação, ambas transacionais via `SET LOCAL`, ambas revertidas no
mesmo instante. Não há superfície de risco adicional por serem duas variáveis em vez de uma: o
risco central (vazamento de contexto residual entre transações que reusam a mesma conexão física)
é o mesmo já analisado, agora aplicado a duas variáveis simultaneamente. **Ainda não testado
empiricamente contra o pooler real do Neon** — mesma limitação já registrada (D6), agora cobrindo
ambas as variáveis (ver `RLS_TEST_PLAN.md`, testes atualizados §8 abaixo).

Padrão transacional completo:

```sql
BEGIN;
SET LOCAL app.current_conta_acesso_id = '<uuid da conta autenticada>';
SET LOCAL app.current_tenant_id = '<uuid do tenant ativo>';
-- queries...
COMMIT;
```

`SET SESSION` continua proibido para as duas variáveis, pelo mesmo motivo já estabelecido
(`SEC-001` §14, `ADR-D028`).

## 8. Formato e validação — resumo normativo

- Formato: string de texto no GUC, sempre um UUID v4 (ou compatível) em texto — nunca outro tipo.
- Validação: delegada às funções `contifisc_current_tenant_id()`/`contifisc_current_conta_acesso_id()`
  (§3) — nunca cast inline nas policies.
- Quem popula: camada de aplicação/middleware de transação, a partir do resultado de autenticação
  (mecanismo de autenticação em si permanece fora de escopo — este contrato define **o que** a
  futura camada de autenticação deve entregar ao PostgreSQL, não **como** ela autentica).
- Nunca aceitar `tenant_id`/`conta_acesso_id` de payload de requisição como fonte — sempre do
  contexto de sessão já estabelecido (mesmo princípio de `ADR-001` §8, agora estendido às duas
  variáveis).

## 9. Classificação de D2

**D2 — RESOLVIDO NO DESENHO.**

Justificativa: a resolução não exigiu (a) implementar autenticação real, (b) alterar nenhum objeto
canônico `COT`/`MCD`/`CDC`/`DST`, nem (c) nenhuma decisão arquitetural além da já delegada a
"implementação" por `ADR-001` V1.1 §9.2/§9.4 (mecanismo físico de contexto de sessão). A segunda
variável (`app.current_conta_acesso_id`) é da mesma classe física já autorizada para
`app.current_tenant_id` — nomeia e especifica um mecanismo que o próprio `ADR-001` já presumia
conceitualmente (item 21 da matriz) sem detalhar. Nenhum novo Change Request foi necessário.

A única pendência remanescente (provisionamento via role `BYPASSRLS`, §5) é arquitetura de
**roles**, já prevista como não decidida em `RLS-001` §18/§20 — não é uma reabertura de D2, é uma
extensão consistente do que já estava marcado como "a decidir".
