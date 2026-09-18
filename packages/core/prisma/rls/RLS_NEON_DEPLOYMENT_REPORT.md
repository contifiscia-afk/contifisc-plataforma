# RLS_NEON_DEPLOYMENT_REPORT — Fechamento e deploy controlado da RLS no Neon DEV

**Status: 1ª TENTATIVA DE DEPLOY FALHOU (privilégio) → CORRIGIDA E VALIDADA EMPIRICAMENTE →
`migrate resolve --rolled-back` EXECUTADO → ESTADO PRISMA RESULTANTE DIFERENTE DO ESPERADO →
PARADO CONFORME INSTRUÍDO, SEM REDEPLOY.** Nenhum schema, dado, policy, função ou role RLS existe
no Neon DEV neste momento — permanece byte-a-byte no mesmo estado da baseline pós-SEC original.

**ATUALIZAÇÃO FINAL (6ª sessão — ADENDO 6): `170000_rls_mediator_schema_usage` APLICADA no Neon DEV (checkpoint Git
`69384f7`); mediator USAGE=true/CREATE=false; RLS 25/25, 30 policies; S01–S17 aprovados em DIRECT e POOLED; ADR-C005 e
ADR-C014 preservados; cleanup completo; CRITICAL=0, RELEVANTE=0. GATE: `RLS PÓS-SEC — IMPLANTADA E VALIDADA NO NEON DEV`.
As seções "REQUER REVISÃO" abaixo são o registro cronológico anterior, superado pelo ADENDO 6.**

**ATUALIZAÇÃO (5ª sessão — ADENDO 4): sucessora `20260918160000_...` APLICADA no Neon DEV (histórico 1/2/3
correto; status pós-deploy `up to date`; RLS 25/25, 30 policies, mediator correto). Introspecção achou que o
mediator NÃO tem USAGE no schema `public` do Neon (7 policies inoperantes p/ runtime; fail-closed). Smoke tests
S01–S17 NÃO executados (parada por instrução); role temporário removido; sem dados. Correção candidata validada
só em PG18 descartável (`GRANT USAGE ON SCHEMA public TO contifisc_rls_mediator`), aguardando autorização.**

**ATUALIZAÇÃO (4ª sessão): experimento do Prisma 6.19.3 em PG18.6 descartável (ADENDO 3) — o placeholder
passa no `status` mas o `deploy` o aplicaria como linha APPLIED com o nome antigo; o deploy SEM placeholder
produz o histórico desejado. Aguardando decisão. Neon DEV intocado.**

**ATUALIZAÇÃO (3ª sessão — recuperação da cadeia Prisma): nova migration criada por renomeação, mas
`prisma migrate status` reporta DIVERGÊNCIA de histórico (migration do banco ausente localmente) →
PARADO CONFORME INSTRUÍDO (Fases 4/5), SEM DEPLOY.** Ver "ADENDO 2" abaixo. Neon DEV continua
sem RLS e sem alterações.

---

## ADENDO 2 — Recuperação da cadeia Prisma (nova migration após tentativa ROLLED BACK)

### Rastreabilidade da tentativa histórica (registrada ANTES de alterar a cadeia local)

| Item | Valor |
|---|---|
| migration_name | `20260918150000_rls_tenant_isolation` |
| Status | FAILED → RESOLVED AS ROLLED BACK |
| Checksum da tentativa | `a82e3c088e9f8ea37eba4087f2303e83e2dcab48e2ba4d9a443f5ba183d255f9` (SUPERSEDED) |
| Causa | ownership / `SET ROLE` sob `neondb_owner` (+ `CREATE` do novo dono no schema) |
| Reuso do nome | proibido |

Tombstone em `rls/archive/20260918150000_rls_tenant_isolation.SUPERSEDED.md` (fora de
`prisma/migrations/`, ignorado pelo Prisma). Observação: a pasta original era **untracked** no Git
(nunca commitada), portanto o Git não guarda os bytes da tentativa antiga — só o checksum acima.

### Nova migration

- Pasta renomeada (`Move-Item`, sem editar o conteúdo):
  `20260918150000_rls_tenant_isolation` → `20260918160000_rls_tenant_isolation_privilege_fix`
- SHA-256 antes da renomeação: `AA95DDFA90B9A52CBB660282D75CBD41E0C08C89FA4AAF900A5C31262322BBEA`
- SHA-256 depois da renomeação: `AA95DDFA90B9A52CBB660282D75CBD41E0C08C89FA4AAF900A5C31262322BBEA`
  → **idêntico** (só o nome da pasta mudou).
- Conteúdo previamente validado 2x em PostgreSQL 18.6 com migration owner não-superuser.
- Migration inaugural intacta; a cadeia local agora tem exatamente 2 migrations.

### `prisma migrate status` após a reorganização (leitura apenas) — **DIVERGÊNCIA**

```
2 migrations found in prisma/migrations
Your local migration history and the migrations table from your database are different:
The last common migration is: 20260908120000_init_baseline_fisica_pos_sec
The migration have not yet been applied:
20260918160000_rls_tenant_isolation_privilege_fix
The migration from the database are not found locally in prisma/migrations:
20260918150000_rls_tenant_isolation
(exit code 1)
```

Interpretação: a nova migration aparece corretamente como pendente (e é a única pendente), mas o
Prisma trata a entrada rolled-back do banco cuja pasta não existe localmente como **divergência de
histórico**. O critério da instrução ("migration missing/divergência → PARE") foi atingido. O
`migrate deploy` num estado divergente tende a ser recusado pelo Prisma; forçá-lo exigiria
manipular o histórico, o que é proibido.

### Ações NÃO executadas (parada por instrução)

- Não foi feito deploy, `migrate resolve` adicional, `db push`, SQL manual ou qualquer escrita no Neon.
- Não foi reconciliado/alterado `_prisma_migrations`; nenhuma linha apagada/editada.
- Fases 6-12 (reconciliação, deploy, introspecção, S01-S17, cleanup) **não executadas**.
- Neon DEV: sem alteração nesta sessão (apenas `migrate status`, somente leitura).

### Opções para decisão (nenhuma aplicada)

1. **Marcador local da tentativa antiga**: recolocar uma pasta `20260918150000_rls_tenant_isolation/`
   em `prisma/migrations/` para satisfazer o histórico. Riscos: (a) não temos os bytes originais
   (checksum `a82e3c08...`), então seria um arquivo de conteúdo diferente do registrado — para uma
   migration `rolled_back` o Prisma pode ou não checar checksum (a validar empiricamente com
   `migrate status`, que é somente leitura); (b) manter uma pasta ativa antiga em `migrations/`
   conflita com a diretriz "não manter duas migrations ativas com o mesmo SQL" — mitigável se o
   marcador contiver apenas comentário SQL (no-op). Exige autorização explícita por contradizer a
   Fase 4.
2. **Resetar o Neon DEV** (banco de desenvolvimento, sem dados de negócio) e reaplicar a cadeia
   limpa (baseline + migration corrigida), como já feito antes na baseline. Perde-se o registro
   físico da tentativa rolled-back no banco (preservado apenas no tombstone/relatório) — contraria a
   instrução atual de preservar a linha, portanto também exige autorização explícita.
3. Manter a linha rolled-back e aguardar comportamento suportado pelo Prisma para ignorar
   migrations `rolled_back` ausentes (não confirmado nesta versão, Prisma 6.19.x).

Recomendação: opção 1 com marcador de comentário-only, validando o `migrate status` (leitura) antes
de qualquer deploy — mantém a linha rolled-back intacta no banco e evita reset.

### Classificação desta rodada

| Severidade | Qtde | Item |
|---|---|---|
| CRITICAL | 0 | — |
| RELEVANTE | 1 | Cadeia Prisma divergente: a linha rolled-back no banco não tem pasta local correspondente |
| MENOR | 1 | Pasta antiga era untracked; os bytes originais da tentativa não estão preservados no Git (só o checksum) |

**Gate:** `RLS PÓS-SEC — DEPLOY NO NEON DEV REQUER REVISÃO`

---

## ADENDO 3 — Experimento empírico do Prisma 6.19.3 com migration ROLLED BACK (PG 18.6 descartável)

Autorização recebida: Opção 1 em duas etapas (testar antes; placeholder só se comprovado). **Neon DEV
não foi tocado nesta rodada.** Ambiente: PostgreSQL 18.6 em container descartável, projeto scratch
fora do repositório (`C:\Dev\hist_scratch`, sem `.env`), Prisma CLI 6.19.3 (mesma versão do projeto),
schema e baseline idênticos aos do projeto. Migration "antiga" simulada com `SELECT 1/0;` (falha
proposital) — os bytes originais reais não existem mais.

Sequência base reproduzida: baseline aplicada → antiga falha (P3018) → `migrate resolve --rolled-back`.
Linha resultante em `_prisma_migrations`: `rolled_back_at` preenchido, `finished_at` nulo.

| # | Cenário local | `migrate status` | `migrate deploy` | Histórico resultante |
|---|---|---|---|---|
| 1 | Controle: pasta antiga com bytes idênticos ao registrado | `Database schema is up to date!` | **reaplica** a antiga (falhou de novo em `1/0`) | **2ª linha** com o mesmo nome (checksum igual, `finished_at` nulo, `rolled_back_at` nulo) |
| 2 | Placeholder comentário-only (checksum diferente) + sucessora | **OK**: sem mismatch; sucessora = única pendente (exit 1 = "há pendentes") | aplica o placeholder **e** a sucessora | rolled-back + **nova linha APPLIED com o nome antigo** (checksum do placeholder) + sucessora APPLIED |
| 3 | Pasta antiga **ausente** + sucessora (estado atual do repo/Neon) | divergência ("migration from the database not found locally"), sucessora pendente, exit 1 | aplica **somente a sucessora**, sem erro | baseline APPLIED; antiga ROLLED BACK (intacta, 1 linha); sucessora APPLIED. Status pós-deploy: `up to date` |

(Cenário 3 executado em container recém-criado; uma 1ª tentativa falhou por artefato do teste — o role
`contifisc_rls_mediator` é global do cluster e sobrou de um cenário anterior — e foi refeita limpa.)

### Respostas às hipóteses da Fase A

- **`migrate status`**: comportamento **B** — exige/valida apenas a presença do `migration_name`;
  **não compara checksum** de migration rolled-back (cenário 2: sem `modified`/mismatch).
- **`migrate deploy`**: comportamento **D** (outro) — trata linha rolled-back como *não aplicada* e
  **reaplica qualquer pasta local com esse nome**, independentemente do checksum (cenários 1 e 2).

### Consequência para o placeholder (Fase B) — **NÃO restaurado**

O placeholder passa no `status`, mas o `deploy` o aplicaria e registraria o nome
`20260918150000_rls_tenant_isolation` como **APPLIED** (2ª linha). Isso contradiz o histórico
esperado (Fase F: a antiga permanece ROLLED BACK) e polui a evidência histórica. Enquadra-se em
"qualquer incompatibilidade" (Fase C) → **parada**. Nenhum placeholder foi criado no repositório.

### Correção de um achado anterior (registrado, não apagado)

O adendo anterior ("Achado Fase 12") afirmava que o Prisma trata o nome como terminal e que a
mesma pasta não poderia ser reaplicada. Isso vale **apenas para `migrate status`**. O experimento
mostra que `migrate deploy` **reaplicaria** a pasta de mesmo nome. A conclusão prática (não reusar o
nome) permanece correta e mais segura, mas a justificativa era incompleta.

### Achado central: o cenário 3 já produz o histórico desejado

Sem placeholder, com o estado local atual (`...150000` ausente; `...160000_rls_tenant_isolation_privilege_fix`
presente), o `deploy` aplicou somente a sucessora e deixou a linha rolled-back intacta — exatamente o
histórico da Fase F. O único incômodo é cosmético: enquanto a sucessora está pendente, `migrate status`
exibe o texto de divergência (exit 1). Não é um erro do `deploy`.

### Ressalvas

- Validação do cenário 3 usou superuser `postgres` (o foco era o comportamento de histórico do
  Prisma; a executabilidade sob role não-superuser já foi validada 2x na PoC anterior).
- Comportamento observado em Prisma 6.19.3; pode mudar em outras versões.
- O `deploy` sobre o Neon só se justifica com nova autorização, pois o critério da Fase D ("nenhuma
  divergência por migration missing" no status) **não** é atendido no cenário 3.

### Opções (nenhuma aplicada)

1. **(Recomendada)** Autorizar `migrate deploy` DIRECT no Neon **no estado atual** (sem placeholder),
   aceitando que o `status` pré-deploy mostre o aviso de divergência. Evidência: cenário 3. Depois,
   introspecção e S01-S17 como planejado. O aviso some após o deploy (status pós-deploy = `up to date`).
2. Manter o critério "status sem divergência" e resetar o Neon DEV (contraria a preservação da linha
   rolled-back) — não recomendada.
3. Criar placeholder e aceitar a linha APPLIED com o nome antigo — contraria a Fase F; não recomendada.

### Classificação desta rodada

| Severidade | Qtde | Item |
|---|---|---|
| CRITICAL | 0 | — |
| RELEVANTE | 1 | O caminho do placeholder (Opção 1 original) contamina o histórico no `deploy`; o critério "status sem divergência" e o "histórico Fase F" são mutuamente exclusivos nesta versão do Prisma |
| MENOR | 1 | Justificativa anterior sobre o "nome terminal" estava incompleta (corrigida acima) |

**Gate:** `RLS PÓS-SEC — DEPLOY NO NEON DEV REQUER REVISÃO`

---

## ADENDO 4 — Deploy da sucessora no Neon DEV, introspecção e achado de `USAGE` no schema `public`

### Decisão formal recebida (registrada)

Autorizado o `prisma migrate deploy` (DIRECT) no estado local vigente: a pasta
`20260918150000_rls_tenant_isolation` **permanece ausente** de `prisma/migrations` (registro histórico
apenas no banco: FAILED → ROLLED BACK); sem placeholder; sem reaplicar; sem editar `_prisma_migrations`;
sem novo `migrate resolve`. O aviso de divergência pré-deploy do `migrate status` é **conhecido e aceito
exclusivamente neste incidente** (base: experimento do ADENDO 3, Prisma 6.19.3). Não generalizar.

### Reconciliação pré-deploy (Neon DEV, DIRECT, somente leitura)

| Item | Resultado |
|---|---|
| PostgreSQL | 18.6 (aarch64) |
| Banco / usuário | `neondb` (nome do banco; `contifisc-dev` é o nome do projeto Neon) / `neondb_owner` (não-superuser, BYPASSRLS, CREATEROLE) |
| Tabelas | 26 (25 de negócio + `_prisma_migrations`) |
| Policies / RLS enabled / forced / funções `contifisc_*` / role mediator | 0 / 0 / 0 / 0 / 0 |
| Linhas de negócio | 0 |
| `_prisma_migrations` | inaugural APPLIED (`afe5964170c5`); `20260918150000_rls_tenant_isolation` ROLLED BACK (`a82e3c088e9f`, `finished_at` nulo); sucessora ausente |
| Triggers ADR-C005 / ADR-C014 | 4 (1× `trg_vinculo_extremidades_check`, 3× `adr_c014_*`), todos DEFERRABLE INITIALLY DEFERRED |
| Constraints / índices (baseline) | 193 / 46 |

Nenhuma divergência além da ausência local da migration rolled-back.

### Checksum e deploy

- SHA-256 recalculado imediatamente antes do deploy de
  `20260918160000_rls_tenant_isolation_privilege_fix/migration.sql`:
  `AA95DDFA90B9A52CBB660282D75CBD41E0C08C89FA4AAF900A5C31262322BBEA` (**corresponde** ao SQL validado 2x).
- `prisma migrate status` pré-deploy (host DIRECT, sem `-pooler`): divergência conhecida/aceita; sucessora = única pendente.
- `prisma migrate deploy` (DIRECT): `Applying migration 20260918160000_rls_tenant_isolation_privilege_fix` →
  **"All migrations have been successfully applied."** (exit 0). Sem `db push`, SQL manual, `resolve` ou edição de histórico.

### Histórico Prisma pós-deploy (conforme esperado)

| # | migration | estado |
|---|---|---|
| 1 | `20260908120000_init_baseline_fisica_pos_sec` (`afe5964170c5`) | APPLIED |
| 2 | `20260918150000_rls_tenant_isolation` (`a82e3c088e9f`) | ROLLED BACK (linha intacta) |
| 3 | `20260918160000_rls_tenant_isolation_privilege_fix` (`aa95ddfa90b9`) | APPLIED (`applied_steps_count` = 1) |

`prisma migrate status` pós-deploy: **"Database schema is up to date!"** (exit 0) — como previsto no experimento.

### Introspecção pós-deploy (Neon real x PG18.6 validado)

| Verificação | Neon DEV | Esperado / PoC | Resultado |
|---|---|---|---|
| Tabelas de negócio com ENABLE / FORCE RLS | 25 / 25 (de 25) | 25/25 | OK |
| `_prisma_migrations` com RLS | não | não | OK |
| Policies | 30 (22 ALL, 2 SELECT, 2 INSERT, 2 UPDATE, 2 DELETE; 0 restritivas; 24 tabelas com policy) | 30 | OK |
| Vinculo / VinculoExtremidade | 4 policies por comando cada (SELECT/INSERT/UPDATE/DELETE) | 4+4 | OK |
| Tabela sem policy | somente `evento_auditoria_seguranca` | idem | OK |
| Mediator | NOSUPERUSER, NOLOGIN, BYPASSRLS, sem CREATEROLE/CREATEDB/REPLICATION | idem | OK |
| Funções SD (2) | owner = `contifisc_rls_mediator`, SECURITY DEFINER, STABLE, `search_path=pg_catalog, public`, ACL só do mediator, PUBLIC sem EXECUTE | idem | OK |
| Funções leitoras de GUC (2) | owner `neondb_owner`, não-SD, EXECUTE para PUBLIC (por desenho; só leem o GUC) | idem | OK (por desenho) |
| Membership no mediator | somente `neondb_owner` (grantor `cloud_admin`): admin_option=true, inherit=false, **set=false**; `pg_has_role(...,'SET')`=false | resíduo documentado (ADENDO 1) | OK |
| Mediator: CREATE em `public` | não | não | OK |
| Mediator: privilégios de tabela | SELECT em `conta_acesso_tenant`, `unidade_economica`, `vinculo_extremidade` (só) | 3× SELECT | OK |
| Roles `contifisc_*` | apenas o mediator (runtime `contifisc_app` ainda não existe — provisionamento futuro) | — | OK |
| Owner das 26 tabelas | `neondb_owner` | — | OK |
| Triggers ADR-C005 / ADR-C014 | 4, idênticos ao pré-deploy | idem | OK |
| Constraints / índices | 193 / 46 (idêntico à baseline) | idem | OK |
| Linhas de negócio | 0 | 0 | OK |
| **USAGE do mediator no schema `public`** | **não** (ACL do schema = `{neondb_owner=UC/neondb_owner}`; sem `PUBLIC=U`) | PoC PG18: sim (ACL padrão com `PUBLIC=U`) | **DIVERGÊNCIA — ver abaixo** |

### ACHADO RELEVANTE — o mediator não consegue acessar o schema `public` no Neon

**Fato.** No Neon DEV o schema `public` **não concede `USAGE` a PUBLIC** (ACL `{neondb_owner=UC/neondb_owner}`);
a migration não altera esse ACL (só concede/revoga `CREATE` ao mediator temporariamente). Logo, o role
`contifisc_rls_mediator` **não tem `USAGE` em `public`** e as funções SECURITY DEFINER
(`contifisc_conta_tem_acesso_tenant`, `contifisc_vinculo_tem_extremidade_no_tenant`) — que executam com os
privilégios do mediator e referenciam tabelas `public.*` — **não conseguem resolver os objetos**. A PoC em
PG18 não detectou isso porque o `public` da PoC tinha o ACL padrão (`PUBLIC=U`).

**Como foi observado no Neon (não por suposição).** Ao provisionar um role temporário de teste, o
`GRANT EXECUTE` nas funções SD só é possível como o próprio mediator (`SET LOCAL ROLE contifisc_rls_mediator`
dentro de uma janela atômica de membership). O passo falhou com
`ERROR: permission denied for schema public` **ao agir como mediator** — confirmando a ausência de USAGE.
A transação inteira foi revertida (membership e ACLs permaneceram idênticas ao pós-deploy; conferido).

**Alcance.** Policies que chamam funções SD: `tenant` (ALL), `vinculo` (SELECT/UPDATE/DELETE) e
`vinculo_extremidade` (SELECT/UPDATE/DELETE) = 7 policies. Para um runtime não-BYPASSRLS essas tabelas
falhariam com `permission denied for schema public` (fail-closed por erro, **não** vazamento). As demais
23 tabelas de negócio e os INSERTs de vinculo/vinculo_extremidade não dependem das funções SD.

**Reprodução e correção candidata em PG18.6 descartável (Neon-like; nada aplicado ao Neon).**
- Ambiente: `neon_like_owner` (LOGIN, não-superuser, CREATEROLE, BYPASSRLS) dono do schema, `public` com ACL
  `{neon_like_owner=UC/neon_like_owner}`; baseline + migration sucessora aplicadas **como esse role**
  (30 policies; mediator sem USAGE) — idêntico ao Neon.
- Bateria T-tests da PoC como `contifisc_app_test` (NOBYPASSRLS) **antes** da correção: 7 ocorrências de
  `permission denied for schema public` (T04, T26 e testes dependentes) além dos 3 erros de RLS esperados.
- Correção candidata, executada como o owner não-superuser: `GRANT USAGE ON SCHEMA public TO contifisc_rls_mediator;`
  (privilégio mínimo: só USAGE, sem CREATE — `has_schema_privilege(mediator,'public','CREATE')` continua `false`).
- Bateria **depois**: saída idêntica à referência aprovada (mesmas contagens de linhas
  `4,4,1,1,1,1,6,2,3,1,2,4,1,1,1,1,1,1,1,0,1,1` e mesmos IDs); restam apenas os 3 erros de RLS esperados (T07/T10/T18).
- Provisionamento do EXECUTE para o runtime, como owner não-superuser (após o USAGE): janela atômica
  `GRANT mediator TO CURRENT_USER WITH SET TRUE, INHERIT FALSE; SET LOCAL ROLE mediator; GRANT EXECUTE ... TO <runtime>;
  RESET ROLE; REVOKE mediator FROM CURRENT_USER;` funcionou; membership final idêntica à anterior
  (somente `admin_option=t, inherit=f, set=f`).

### Smoke tests S01–S17 — **NÃO EXECUTADOS (parada por instrução)**

Regra da tarefa: "divergência de segurança/introspecção → PARE antes dos smoke tests". Com 7 policies
inoperantes por falta de USAGE do mediator (e sem como conceder EXECUTE a um runtime de teste, pois isso exige
agir como mediator), S01–S17 não seriam conclusivos, e corrigir diretamente no Neon (SQL manual) é proibido.
Nenhum dado sintético foi inserido no Neon; o fixture **não** foi carregado. Os scripts
(`rls/poc/09_neon_smoke_s01_s17.mjs` — suíte S01–S17 direct/pooled, provisionamento, fixture e cleanup — e
`rls/poc/10_neon_readonly_query.mjs` — helper de consulta) foram salvos no repositório, **escritos mas ainda
não executados/validados** (a suíte `run` nunca rodou); serão exercitados após a correção.

### Cleanup / limpeza do que foi criado nesta rodada

Foi criado (e removido) no Neon um único artefato de teste: o role `contifisc_smoke_runtime` (NOLOGIN, NOBYPASSRLS),
com USAGE em `public`, DML nas 25 tabelas e uma membership `WITH SET TRUE` ao `neondb_owner`. Removido:
`REVOKE ALL` nas tabelas e no schema + `DROP ROLE` (a 1ª tentativa com `DROP OWNED BY` falhou por permissão e não
alterou nada). Confirmado após a limpeza: só existe o role `contifisc_rls_mediator` entre os `contifisc_*`;
ACL do schema `public` de volta a `{neondb_owner=UC/neondb_owner}`; 0 ACLs de tabela com resquício; ACLs das funções SD
inalteradas; membership do mediator inalterada; 0 linhas de negócio; `_prisma_migrations` com as 3 linhas acima.
RLS (25/25, 30 policies) e mediator **permanecem instalados**.

### Cronologia consolidada do incidente (1–16)

1. Migration original `20260918150000_rls_tenant_isolation` criada (checksum `a82e3c08...255f9`), validada em PG15/PG18 como superuser.
2. 1ª tentativa de `migrate deploy` no Neon (`neondb_owner`).
3. Falha: `must be able to SET ROLE contifisc_rls_mediator` (ownership) — superuser mascarava o problema nas PoCs.
4. Rollback automático da transação DDL (Neon permaneceu na baseline).
5. `prisma migrate resolve --rolled-back 20260918150000_rls_tenant_isolation`.
6. Correção de privilégios (membership temporária + `CREATE` temporário do novo dono no schema).
7. PoC PG18.6 com migration owner não-superuser, 2 execuções independentes (`aa95ddfa...2bbea`).
8. Renomeação para a sucessora `20260918160000_rls_tenant_isolation_privilege_fix` (checksum inalterado).
9. `migrate status`: divergência (linha rolled-back sem pasta local).
10. Experimento Prisma 6.19.3 em PG18.6 descartável (3 cenários — ADENDO 3).
11. Descoberta: `status` ignora checksum de rolled-back; `deploy` reaplica pasta de mesmo nome (placeholder contamina o histórico).
12. Decisão formal: manter a rolled-back ausente localmente; divergência pré-deploy aceita como exceção documentada.
13. Deploy da sucessora no Neon: **sucesso** (histórico 1/2/3 conforme esperado; status pós-deploy `up to date`).
14. Introspecção: tudo conforme, **exceto** o USAGE do mediator em `public` (achado acima).
15. Smoke tests S01–S17: **não executados** (parada por instrução); role temporário criado e removido.
16. Cleanup: concluído (sem dados; role de teste removido; RLS e mediator mantidos).

### Correção recomendada (NÃO aplicada; requer autorização)

Nova migration incremental (timestamp posterior, nome nunca usado), por exemplo
`20260918170000_rls_mediator_schema_usage`, com **um único comando**, idempotente e inofensivo em ambientes
com `PUBLIC=U`:

```sql
GRANT USAGE ON SCHEMA public TO contifisc_rls_mediator;
```

Antes de qualquer deploy: (a) checkpoint Git recuperável desta cadeia; (b) validar a nova migration em PG18.6
com `public` estilo Neon **como owner não-superuser**, 2 execuções independentes (o experimento acima já mostra o
resultado esperado); (c) `migrate deploy` DIRECT; (d) reintrospecção (mediator com `USAGE` e sem `CREATE`);
(e) provisionamento do role de teste/runtime (USAGE em `public`, DML, EXECUTE nas 2 funções SD via janela atômica
de membership) e execução de S01–S17 (direct e pooled) com dados sintéticos e limpeza.
O provisionamento do runtime real (`contifisc_app`) precisa incluir: USAGE em `public`, DML nas tabelas e
EXECUTE nas duas funções SD (esse último exige a janela de membership — ver acima).

### Regras de governança novas (recomendação/processo futuro, a partir deste incidente)

1. Migration candidata a banco persistente deve ter **checkpoint Git recuperável ANTES do primeiro `migrate deploy`**.
2. Migrations envolvendo `CREATE ROLE`, `GRANT/REVOKE`, ownership, `SECURITY DEFINER`, `BYPASSRLS` ou RLS devem ser
   testadas também com migration owner **não-superuser** **e** com o ACL de schema/roles do provedor-alvo (ex.: Neon:
   `public` sem `USAGE` para PUBLIC) — a PoC deve espelhar o ambiente, não só o produto.
3. Migration failed **não** deve ser apagada/renomeada sem análise do comportamento específico da versão do Prisma
   (`status` e `deploy` divergem para linhas rolled-back).
4. Divergência de `migrate status` **nunca** deve ser ignorada genericamente.
5. A autorização desta rodada é **exceção documentada** baseada em PoC específica do Prisma 6.19.3; não se estende a
   outras divergências de histórico.

### Classificação desta rodada

| Severidade | Qtde | Item |
|---|---|---|
| CRITICAL | 0 | Sem vazamento/bypass de isolamento; falha é fail-closed (erro de permissão) |
| RELEVANTE | 1 | Mediator sem `USAGE` em `public` no Neon → 7 policies (tenant, vinculo×3, vinculo_extremidade×3) inoperantes para o runtime; a PoC não espelhava o ACL do schema do Neon |
| MENOR | 1 | Provisionamento do EXECUTE do runtime nas funções SD exige janela de membership (documentar no runbook de provisionamento) |

### Gate

```
RLS PÓS-SEC — DEPLOY NO NEON DEV REQUER REVISÃO
```

---

## ADENDO 6 — Deploy da `170000`, introspecção, S01–S17 no Neon DEV e cleanup (**resultado final desta etapa**)

Este adendo **supera** as conclusões "REQUER REVISÃO" dos adendos anteriores (que permanecem como registro
cronológico). Checkpoint Git prévio: commit `69384f7` (working tree limpo).

### Pré-condições verificadas antes de tocar o Neon

- `HEAD = 69384f7` (`feat(rls): RLS pos-SEC (ADR-002) + migrations 160000/170000 - checkpoint pre-deploy`).
- SHA-256 do `20260918170000_rls_mediator_schema_usage/migration.sql` no working tree **e** no blob do `HEAD`
  (byte a byte, via `git show | sha256sum`): `2576CFC3800265CA04C75458D785A8667911682307275BF33E833DC5B13C2F9F` ✔.
  Blobs de `160000` (`aa95ddfa…2bbea`) e da inaugural (`afe59641…0e837`) também conferem.
  (Nota: o mesmo hash calculado via *pipe* do PowerShell diverge porque o pipeline reencoda texto; a verificação válida é
  a de bytes puros.)
- Neon DEV (read-only): PG 18.6; baseline APPLIED; `…150000` ROLLED BACK; `…160000` APPLIED; `…170000` ausente;
  25/25 RLS ENABLE+FORCE; 30 policies; mediator existente **sem USAGE** e sem CREATE em `public` (ACL do schema
  `{neondb_owner=UC/neondb_owner}`); só o role `contifisc_rls_mediator` entre os `contifisc_*`; 0 dados; 4 triggers
  ADR-C005/C014; 193 constraints / 46 índices; membership do mediator só `admin_option`, `set=false`.
- `prisma migrate status` pré-deploy: única migration pendente = `20260918170000_rls_mediator_schema_usage`; única
  divergência = a já aceita (rolled-back `…150000` ausente localmente). Nenhuma outra divergência.

### Deploy (DIRECT)

`prisma migrate deploy` → `Applying migration 20260918170000_rls_mediator_schema_usage` → **"All migrations have been
successfully applied."** (exit 0). Sem `db push`, SQL manual, `resolve` ou edição de histórico.

### Histórico Prisma final

| # | migration | estado | checksum (12) |
|---|---|---|---|
| 1 | `20260908120000_init_baseline_fisica_pos_sec` | APPLIED | `afe5964170c5` |
| 2 | `20260918150000_rls_tenant_isolation` | ROLLED BACK (intacta, `finished_at` nulo) | `a82e3c088e9f` |
| 3 | `20260918160000_rls_tenant_isolation_privilege_fix` | APPLIED | `aa95ddfa90b9` |
| 4 | `20260918170000_rls_mediator_schema_usage` | APPLIED | `2576cfc38002` |

`prisma migrate status` pós-deploy **e** após o cleanup: **"Database schema is up to date!"** (exit 0).

### Introspecção pós-deploy (Neon real x PG18.6 validado 2x)

| Verificação | Neon DEV | Resultado |
|---|---|---|
| `has_schema_privilege(mediator,'public','USAGE')` | **true** | OK |
| `has_schema_privilege(mediator,'public','CREATE')` | **false** | OK |
| ACL do schema `public` | `{neondb_owner=UC/neondb_owner, contifisc_rls_mediator=U/neondb_owner}` (nada para PUBLIC) | OK (idêntico à réplica PG18) |
| Mediator | NOSUPERUSER, NOLOGIN, BYPASSRLS, sem CREATEROLE/CREATEDB/REPLICATION | OK |
| Funções SD (2) | owner = mediator; SECURITY DEFINER; `search_path=pg_catalog, public`; ACL só do mediator; PUBLIC sem EXECUTE | OK |
| Funções leitoras de GUC (2) | owner `neondb_owner`, não-SD, EXECUTE p/ PUBLIC (por desenho) | OK |
| SELECT do mediator | somente `conta_acesso_tenant`, `unidade_economica`, `vinculo_extremidade` | OK |
| Membership no mediator | somente `neondb_owner` (grantor `cloud_admin`): admin=true, inherit=false, **set=false**; `pg_has_role(...,'SET')`=false | OK (resíduo documentado) |
| RLS | 25/25 ENABLE + FORCE; `_prisma_migrations` sem RLS | OK |
| Policies | 30 (22 ALL, 2 SELECT, 2 INSERT, 2 UPDATE, 2 DELETE); 4 por comando em Vinculo e VinculoExtremidade; só `evento_auditoria_seguranca` sem policy | OK |
| Triggers ADR-C005 / ADR-C014 | 4 (idênticos), DEFERRABLE INITIALLY DEFERRED | OK |
| Constraints / índices / tabelas | 193 / 46 / 26 (idêntico à baseline) | OK |
| Roles `contifisc_*` | somente o mediator (runtime real ainda não provisionado — fora de escopo) | OK |

### Revisão dos scripts 09 e 10 (antes de executar)

Não foram tratados como evidência por existirem. Revisão e correções (`09_neon_smoke_s01_s17.mjs`):
regex de erro do S09/S11 endurecidos (`/ADR-C005/`, `/ADR-C014/` em vez de `/./`); `setup` consolidado numa única
transação (role de teste + grants mínimos + janela atômica de membership para o `EXECUTE`); `teardown-role` reescrito
(o `DROP OWNED BY` do rascunho falhava por `INHERIT FALSE`, e o `EXECUTE` só pode ser revogado pelo mediator, então
usa a mesma janela atômica); `node --check` OK. **Bugs achados só ao executar:** (1) a fixture falhou na 1ª tentativa
(`cannot insert multiple commands into a prepared statement`) porque comentários no fim de linha (`...; -- Conta C`)
fundiam statements no split; (2) S10 usava `id like` em coluna `uuid`. Na 1ª execução da suíte (banco vazio por causa do
bug 1) só 5/16 passaram — resultado **descartado** (consequência de banco sem dados; nada foi persistido). Ambos os
bugs foram corrigidos e a fixture recarregada com banco comprovadamente vazio antes da suíte oficial.
`10_neon_readonly_query.mjs` (helper de consulta) executou sem alterações de comportamento.

### Provisionamento do runtime sintético e janela de membership

Role `contifisc_smoke_runtime`: NOSUPERUSER, **NOBYPASSRLS**, NOLOGIN, sem ownership, NOINHERIT; grants mínimos:
USAGE em `public`, SELECT/INSERT/UPDATE/DELETE nas 25 tabelas de negócio, EXECUTE nas 2 funções SD. Como o dono das
funções é o mediator, o `EXECUTE` exigiu **janela temporária de membership**, numa transação única:
`GRANT contifisc_rls_mediator TO neondb_owner WITH SET TRUE, INHERIT FALSE` → `SET LOCAL ROLE contifisc_rls_mediator`
→ `GRANT EXECUTE …` → `RESET ROLE` → `REVOKE contifisc_rls_mediator FROM neondb_owner`. Verificado depois (setup e
teardown): membership do mediator voltou a **somente `admin_option`, `set=false`, `owner_can_set=false`**; sem SET ROLE
residual. (A janela só funcionou porque o mediator agora tem USAGE — o mesmo passo falhou antes da `170000`.)
Nos testes o role é assumido por `SET LOCAL ROLE` a partir da sessão do owner (equivale para RLS a um login como
runtime, mas **não** exercita uma conexão autenticada como esse role; limitação registrada).

### Smoke tests S01–S17 (dados 100% sintéticos)

Executados no endpoint **DIRECT** (S15) e no **POOLED** `-pooler` com `pgbouncer=true` (S16); cada endpoint rodou a
suíte completa: **16/16 PASS em cada um** (15 testes + veredito do endpoint).

| Teste | Resultado (DIRECT e POOLED) |
|---|---|
| S01 Tenant A acessa o próprio tenant (receita, UE, tenant via função SD, documento, arquivo) | PASS |
| S02 Tenant A não acessa Tenant B (8 tabelas, contagens cross-tenant = 0) | PASS |
| S03 Conta sem concessão (Conta C) vê 0 tenants, com e sem tenant GUC | PASS |
| S04 Contexto ausente: 0 linhas em todas as tabelas com escopo; GLOBAL (pessoa_fisica) visível; GUC vazio | PASS |
| S05 Contexto inválido (4 variantes: texto, vazio, "null", UUID malformado): 0 linhas, sem erro | PASS |
| S06 INSERT próprio permitido (receita, arquivo_origem) | PASS |
| S07 INSERT cross-tenant bloqueado (receita, unidade_economica, arquivo_origem) | PASS |
| S08 UPDATE/DELETE cross-tenant: 0 linhas afetadas; UPDATE próprio = 1; mover UE p/ tenant B bloqueado; receita B intacta | PASS |
| S09 Vinculo novo válido (2 extremidades, commit sob runtime), visível ao Tenant A, invisível ao B; **ADR-C005**: vínculo com 1 extremidade rejeitado no COMMIT (`ADR-C005/COT-REL-NORM-001…`), nada persistiu | PASS |
| S10 Vinculo cross-tenant: ambas UE-B bloqueado; mista A+B bloqueado; B não vê vínculos de A; A vê 1a/2a e nunca o residual 3a; nada persistiu | PASS |
| S11 **ADR-C014**: concessão existente visível; runtime bloqueado; como owner (sem RLS) o trigger rejeita (`ADR-C014: conta_acesso_unidade_economica … sem conta_acesso_tenant correspondente`); nada persistiu | PASS |
| S12 SET LOCAL + COMMIT: GUC visível na transação; após COMMIT GUC vazio e 0 linhas; linha persistiu | PASS |
| S13 SET LOCAL + ROLLBACK: linha revertida; GUC vazio depois | PASS |
| S14 Prisma `$transaction()` interativa (insert/update/delete consistentes) e em array; conexão volta a `neondb_owner`, GUC vazio | PASS |
| S15 DIRECT (host sem `-pooler`): suíte completa | PASS |
| S16 POOLED (host `-pooler`, transaction pooling): suíte completa | PASS |
| S17 Reuso de conexão: 30 transações sequenciais com `connection_limit=1` alternando A/B/sem contexto/conta C, sem vazamento (nem de role, nem de GUC); 12 transações concorrentes, cada uma vendo só o próprio tenant | PASS |

Observação: no POOLED o S17 reportou 1 backend distinto em `pg_backend_pid()` — coerente com `connection_limit=1`, mas
não prova, por si só, o reuso de um mesmo backend por clientes distintos no pooler; a garantia vem de o contexto ser
sempre `SET LOCAL` (S12/S13/S17 confirmam que nada sobrevive à transação).

### Cleanup

- Dados sintéticos: fixture + linhas comitadas por S09/S12 (vinculo 5, vinculo_extremidade 10, receita 4, …) removidos
  por `TRUNCATE … CASCADE` das 25 tabelas de negócio (nunca `_prisma_migrations`) → **0 linhas**.
- `contifisc_smoke_runtime` removido (revoke de tabelas/schema, revoke do EXECUTE via janela atômica, `DROP ROLE`) →
  só o mediator sobra entre os `contifisc_*`; 0 ACLs de tabela com resquício; ACLs das funções SD de volta a
  `{mediator=X/mediator}`; ACL do schema de volta a `{owner=UC, mediator=U}`; 0 schemas/objetos extras; 26 tabelas.
- Permanecem: mediator, RLS (25/25, 30 policies), USAGE do mediator, as 4 migrations no histórico.
- Fixtures apenas sintéticos ("Sintetica/Ficticia", CPF/CNPJ zerados); nenhum dado real jamais entrou no Neon.

### Regra nova de teste (governança)

**Ambientes descartáveis de segurança devem reproduzir também as ACLs de schema (e demais defaults de privilégio)
do provedor-alvo — não apenas a versão do PostgreSQL e os roles.** (O achado do `USAGE` do mediator só apareceu no
Neon porque a PoC herdava o `PUBLIC=U` do PostgreSQL padrão.) Complementa as regras do ADENDO 4.

### Classificação final

| Severidade | Qtde | Item |
|---|---|---|
| CRITICAL | 0 | — |
| RELEVANTE | 0 | O achado RELEVANTE do ADENDO 4 (USAGE do mediator) foi corrigido pela `170000`, validado 2x em PG18.6 estilo Neon, aplicado e comprovado no Neon (S01–S17 direct e pooled) |
| MENOR | 3 | (a) Janela operacional de membership no mediator para conceder/revogar EXECUTE: concedida e **revogada na mesma transação**, verificada (`set=false`); documentar no runbook de provisionamento do runtime real. (b) `neondb_owner` mantém `admin_option` no mediator (concessão do provedor; inerente ao PG16+, sem SET/INHERIT). (c) `core.autocrlf=true` sem `.gitattributes` — risco de CRLF no checkout alterar o checksum (recomendação: `packages/core/prisma/migrations/**/migration.sql text eol=lf`) |

### Gate

```
RLS PÓS-SEC — IMPLANTADA E VALIDADA NO NEON DEV
```

Critérios: `170000` APPLIED ✔; mediator USAGE=true / CREATE=false ✔; 25/25 RLS ✔; 30 policies ✔; S01–S17 aprovados
(direct e pooled) ✔; ADR-C005 ✔; ADR-C014 ✔; cleanup completo ✔; histórico Prisma coerente ✔; zero dados reais ✔;
CRITICAL=0 ✔; RELEVANTE=0 ✔; nenhum secret ✔.

**Pendências fora do escopo desta etapa:** provisionamento do runtime real (`contifisc_app`: USAGE, DML, EXECUTE via
janela atômica), autenticação, frontend, Skills, RGT/EVT/INT. Nenhum commit/push feito nesta rodada — o relatório e
o script `09` estão modificados no working tree aguardando o commit do Bruno.

---

## ADENDO 5 — Correção incremental do ACL do mediator (`20260918170000_rls_mediator_schema_usage`)

Autorização recebida: corrigir a ausência de `USAGE` do `contifisc_rls_mediator` em `public` **exclusivamente**
por uma NOVA migration incremental. `20260918160000_rls_tenant_isolation_privilege_fix` (já APPLIED no Neon) e a
inaugural permanecem imutáveis; nada de SQL corretivo manual no Neon; `_prisma_migrations` intocada.

### Diferença de ACL: PostgreSQL padrão × Neon (causa do achado)

| Ambiente | ACL do schema `public` | Efeito para o mediator |
|---|---|---|
| PostgreSQL 15+ padrão (PoC anterior) | `{pg_database_owner=UC/pg_database_owner,=U/pg_database_owner}` — `=U` = **USAGE para PUBLIC** | o mediator herda USAGE via PUBLIC; as funções SD resolvem `public.*` |
| Neon DEV | `{neondb_owner=UC/neondb_owner}` — **sem USAGE para PUBLIC** | o mediator NÃO tem USAGE; as funções SD falham com `permission denied for schema public` |

Ausência descoberta na introspecção pós-deploy (ADENDO 4). **Alcance: 7 policies** (`tenant` ALL;
`vinculo` SELECT/UPDATE/DELETE; `vinculo_extremidade` SELECT/UPDATE/DELETE). **Sem vazamento**: a falha é um erro de
permissão (fail-closed); nenhuma linha indevida foi exposta.

### Migration candidata

`packages/core/prisma/migrations/20260918170000_rls_mediator_schema_usage/migration.sql` — comentários
documentais + **um único comando executável**:

```sql
GRANT USAGE ON SCHEMA public TO contifisc_rls_mediator;
```

Não concede CREATE, ownership, ALL, privilégios em tabelas, membership, LOGIN, SUPERUSER, BYPASSRLS nem nada a PUBLIC
(least privilege). Arquivo: 1.470 bytes, LF, sem BOM.

**SHA-256 (congelado após a validação 2x):**
`2576CFC3800265CA04C75458D785A8667911682307275BF33E833DC5B13C2F9F`

Para referência (imutáveis): `20260918160000_...` = `AA95DDFA90B9A52CBB660282D75CBD41E0C08C89FA4AAF900A5C31262322BBEA`;
inaugural = `AFE5964170C58FBBB3708D65D24D36B49ECA988273E4D0F8ECE40E95D060E837`.
Qualquer alteração posterior a este arquivo exige novo checksum e nova validação completa.

### Validação PG18.6 estilo Neon — 2 execuções independentes (2/2 aprovadas, 36/36 cada)

Cada execução: container `postgres:18` **novo** (18.6), sem reaproveitar estado; role `neon_like_owner`
(LOGIN, NOSUPERUSER, CREATEROLE, BYPASSRLS) dono do schema; `public` com ACL `{neon_like_owner=UC/neon_like_owner}`
(idêntico ao Neon); baseline + `160000` + `170000` aplicadas **como esse owner não-superuser**; runtime
`contifisc_app_test` provisionado por esse mesmo owner (janela `GRANT mediator TO CURRENT_USER WITH SET TRUE, INHERIT FALSE`
→ `SET LOCAL ROLE mediator` → `GRANT EXECUTE` → `RESET ROLE` → `REVOKE`, numa transação); container destruído
(`docker stop` + `docker rm -v`) ao final. Script: `validate_usage.ps1` (scratchpad da sessão).

| # | Verificação | Run 1 | Run 2 |
|---|---|---|---|
| PRE | mediator sem USAGE antes (reproduz o Neon); 30 policies; 25/25 RLS | OK | OK |
| 1 | mediator **tem** USAGE em `public` | OK | OK |
| 2 | mediator **não** tem CREATE em `public` | OK | OK |
| 3 | mediator NOLOGIN (e NOSUPERUSER/CREATEROLE/CREATEDB/REPLICATION off) | OK | OK |
| 4 | mediator BYPASSRLS | OK | OK |
| 5 | mediator dono das 2 funções SD + SECURITY DEFINER | OK | OK |
| 6 | `search_path = pg_catalog, public` (hardened) nas 2 funções | OK | OK |
| 7 | PUBLIC sem EXECUTE nas funções SD | OK | OK |
| 8 | SELECT do mediator restrito a `conta_acesso_tenant`, `unidade_economica`, `vinculo_extremidade` | OK | OK |
| 9 | owner sem SET ROLE para o mediator (membership só `admin_option`, `set=false`) | OK | OK |
| 10 | runtime sem BYPASSRLS | OK | OK |
| 11 | nenhuma policy mudou (md5 de definição completa, antes × depois) | OK | OK |
| 12 | nenhuma constraint mudou (md5) | OK | OK |
| 13 | nenhum índice mudou (md5) | OK | OK |
| — | funções (owner/secdef/config/ACL/corpo), triggers ADR-C005/C014, ACL de tabelas + RLS, mediator/membership: inalterados | OK | OK |
| — | ACL final do schema = `{owner=UC/owner, mediator=U/owner}` (nada para PUBLIC) | OK | OK |
| — | membership final após o provisionamento do runtime: só `admin_option`; sem SET ROLE residual | OK | OK |
| REG 02 | T-tests (25+ casos): só os 3 erros de RLS esperados (T07/T10/T18); 0 `permission denied`; ids e contagens idênticos à referência aprovada | OK | OK |
| REG 03 | persistência de SET LOCAL (commit/rollback/reuso de conexão) | OK | OK |
| REG 05 | SD03–SD15 (abuso de funções SD, search_path malicioso, forja de contexto, Vinculo sem recursão) | OK | OK |
| REG 04 | Prisma `$transaction` via TCP com runtime NOBYPASSRLS (A / sem contexto / B, sem vazamento) | OK | OK |

Ressalva de honestidade: uma execução de **ensaio** do próprio script de validação apontou 3 FAIL que eram bugs do
script (chave de parse com `|`; booleanos do psql `t/f` comparados com `true/false`) — a migration não estava
envolvida; o restante já passava. O script foi corrigido e as 2 execuções oficiais acima foram refeitas do zero.

`CRITICAL = 0`, `RELEVANTE = 0` nesta camada (PG18.6 estilo Neon).

### Observação de governança de repositório

`core.autocrlf=true` e não há `.gitattributes`. A árvore e o índice estão em LF (`git ls-files --eol`: `i/lf w/lf`),
então o blob commitado tem os mesmos bytes/checksum. Um checkout limpo no Windows com autocrlf poderia materializar CRLF
e alterar o checksum visto pelo Prisma. Recomendação (não aplicada): `.gitattributes` com
`packages/core/prisma/migrations/**/migration.sql text eol=lf`.

---

## ADENDO — Correção de executabilidade + achado no `migrate resolve` (2ª sessão desta etapa)

Esta seção documenta a continuação desta mesma etapa: correção do erro de privilégio da 1ª
tentativa, revalidação empírica completa, e o achado encontrado ao tentar destravar o histórico do
Prisma para uma nova tentativa.

### Causa raiz confirmada com precisão (não apenas a hipótese inicial)

A primeira tentativa falhou em `ALTER FUNCTION ... OWNER TO contifisc_rls_mediator` porque
`neondb_owner` (não-superuser) não era membro do role recém-criado. Investigação empírica nesta
sessão revelou que **existem 2 requisitos de privilégio distintos**, não 1:

1. O role executor precisa conseguir `SET ROLE` para o novo dono (membership) — a causa
   originalmente identificada.
2. **Achado adicional nesta sessão**: `ALTER ... OWNER TO` também exige que o **novo dono** tenha
   privilégio `CREATE` no schema de destino (proteção do próprio PostgreSQL contra escalação de
   privilégio via troca de dono, presente desde a reforma de privilégios do schema `public` na
   v15) — confirmado empiricamente: com apenas a membership concedida, o `ALTER FUNCTION` ainda
   falhava, agora com `permission denied for schema public`, até um `GRANT CREATE ON SCHEMA public
   TO contifisc_rls_mediator` também ser concedido.

### Solução implementada (migration corrigida)

Dentro da seção 1.6 do `migration.sql`, logo após `CREATE ROLE contifisc_rls_mediator`:

```sql
GRANT contifisc_rls_mediator TO CURRENT_USER;
GRANT CREATE ON SCHEMA public TO contifisc_rls_mediator;
-- ... (CREATE FUNCTION + ALTER FUNCTION ... OWNER TO, para as 2 funções) ...
REVOKE CREATE ON SCHEMA public FROM contifisc_rls_mediator;
REVOKE contifisc_rls_mediator FROM CURRENT_USER;
```

`CURRENT_USER` (não um nome fixo como `neondb_owner`) mantém a migration portátil entre DEV,
staging e produção futuros, qualquer que seja o role real que a execute.

### Membership temporária — resultado das perguntas A-H (todas testadas empiricamente)

| Pergunta | Resposta | Evidência |
|---|---|---|
| A. Migration owner consegue transferir ownership após `GRANT`? | **Sim** | `ALTER FUNCTION` retornou sucesso após os 2 `GRANT`s |
| B. Depois do `ALTER FUNCTION`, pode revogar membership? | **Sim** | Ambos os `REVOKE` executaram sem erro |
| C. As funções continuam pertencendo ao mediator após `REVOKE`? | **Sim** | Ownership é permanente, independente de a membership continuar ativa — confirmado por consulta a `pg_proc` após o `REVOKE` |
| D. Migration owner continua conseguindo `SET ROLE` mediator depois do `REVOKE`? | **Não** | `SET ROLE contifisc_rls_mediator` → `ERROR: permission denied to set role` |
| E. Runtime continua sem membership? | **Sim** | Nunca teve — `contifisc_app_test` só recebe `EXECUTE` nas 2 funções, nunca membership no mediator |
| F. Runtime continua sem `BYPASSRLS`? | **Sim** | `rolbypassrls=false` confirmado |
| G. Mediator continua `NOLOGIN`? | **Sim** | `rolcanlogin=false` confirmado |
| H. `SECURITY DEFINER` continua executando com os privilégios do owner correto? | **Sim** | `contifisc_conta_tem_acesso_tenant()` retornou resultado correto mesmo após o `REVOKE`, executando como o mediator |

**Achado residual, documentado e aceito (não removível sem superuser):** quando o migration owner
tem `CREATEROLE` (como `neondb_owner` no Neon), o próprio PostgreSQL 16+ concede a ele,
automaticamente no momento do `CREATE ROLE`, uma entrada em `pg_auth_members` com
`admin_option=true`/`set_option=false` para o role recém-criado — permite ao migration owner
**gerenciar** futuramente a concessão desse role (`GRANT`/`REVOKE` a terceiros), mas **não** permite
`SET ROLE`/assumir a identidade do mediator (isso já é bloqueado pelo `REVOKE`, item D). Tentativa
de remover esse resíduo via `REVOKE ADMIN OPTION FOR ... FROM ...` não teve efeito (`WARNING: role
... has not been granted membership ... by role ...` — o grant é do sistema, não de um `GRANT`
explícito revogável dessa forma). Isso é uma característica inerente do modelo `CREATEROLE` do
PostgreSQL, não uma falha desta migration.

### PoC com migration owner não-superuser (2 execuções independentes)

`postgres:18` (18.6) descartável, com um role `contifisc_test_migration_owner`
(`LOGIN NOSUPERUSER BYPASSRLS CREATEROLE`) criado especificamente para mimetizar `neondb_owner`
(confirmado que `neondb_owner` tem `BYPASSRLS`, porque `CREATE ROLE ... BYPASSRLS` só é permitido a
quem já tem esse atributo — e essa parte funcionou na 1ª tentativa real no Neon). Banco de teste com
esse role como **owner**, migration inteira (baseline + RLS corrigida) executada **conectado como
esse role**, nunca como `postgres`.

**Resultado (ambas as execuções, container destruído e recriado entre elas):**
- Baseline + RLS corrigida aplicadas limpo (`exit 0`).
- Checksums idênticos entre as 2 execuções.
- Estado final de privilégios exatamente como projetado (tabela acima, itens A-H).
- Regressão de segurança completa sem nenhum erro inesperado: SD01-SD15 (incluindo SD08 com schema
  `evil` forjado), `Tenant` C2 (conta A vê Tenant A sem `app.current_tenant_id`), `Vinculo`/
  `VinculoExtremidade` C1+C3 (criação de vínculo novo ponta a ponta bem-sucedida, cross-tenant
  bloqueado, sem recursão), fail-closed em todas as variantes, `SELECT`/`INSERT`/`UPDATE`/`DELETE`
  cross-tenant bloqueados, `SET LOCAL` sem resíduo, Prisma `$transaction()` (3/3), `ADR-C005`
  (vínculo incompleto rejeitado no `COMMIT`), `ADR-C014` (restrição sem concessão rejeitada pela
  RLS).

### Novo checksum

```
Anterior (SUPERSEDED — primeira tentativa de deploy, não aplicada com sucesso):
a82e3c088e9f8ea37eba4087f2303e83e2dcab48e2ba4d9a443f5ba183d255f9

Novo (candidato vigente):
aa95ddfa90b9a52cbb660282d75cbd41e0c08c89fa4aaf900a5c31262322bbea
```

Os dois arquivos **não são idênticos** — o novo contém os 4 comandos `GRANT`/`REVOKE` adicionais
descritos acima, além do cabeçalho do arquivo atualizado (status "definitiva" em vez de "DRAFT",
já que o checksum mudaria de qualquer forma).

### Reconciliação do Neon antes do `resolve` (Fase 10)

Reconfirmado, sem nenhuma alteração desde a Fase H original: 26 tabelas, 0 policies, 0 funções
`contifisc_*`, 0 roles `contifisc_*`, 0 tabelas com RLS `enabled`, 4 triggers não-internos (os da
baseline, `ADR-C005`/`ADR-C014`), 0 registros em `receita`. **Nenhum objeto parcial existe** —
confirmado antes de prosseguir para o `resolve`.

### `prisma migrate resolve --rolled-back` (Fase 11)

```
npx prisma migrate resolve --rolled-back "20260918150000_rls_tenant_isolation"
→ "Migration 20260918150000_rls_tenant_isolation marked as rolled back."
```

Comando aceito sem erro. `_prisma_migrations` após o comando:

```json
{
  "migration_name": "20260918150000_rls_tenant_isolation",
  "checksum": "a82e3c08...255f9",   // checksum ANTIGO — da tentativa que falhou
  "finished_at": null,
  "rolled_back_at": "2026-09-18T13:48:07.208Z"
}
```

### Achado (Fase 12) — estado do Prisma **diferente do esperado**, conforme instruído a verificar

`npx prisma migrate status` logo em seguida retornou:

```
Database schema is up to date!
```

**Isso não é o resultado esperado** ("RLS definitiva novamente pendente e elegível para deploy").
Investigação (leitura direta de `_prisma_migrations`, não alteração): o modelo de histórico do
Prisma trata cada nome de migration como um registro **terminal** — uma vez que existe QUALQUER
linha para `20260918150000_rls_tenant_isolation` em `_prisma_migrations` (aplicada ou marcada como
`rolled_back_at`), o Prisma considera esse **nome** definitivamente processado e não tenta
reaplicá-lo automaticamente em um novo `migrate deploy`, mesmo que o arquivo local `migration.sql`
correspondente tenha sido corrigido/alterado depois. `migrate resolve --rolled-back` é bookkeeping
histórico ("registrar que esta tentativa específica não teve efeito"), não um mecanismo de "tentar
de novo com o mesmo nome". O checksum registrado no histórico (`a82e3c08...255f9`, o antigo) também
nunca foi atualizado para o novo — reforça que o Prisma não associa o arquivo local corrigido a
essa entrada de forma alguma.

**Conclusão technique:** para reapresentar a correção a um `prisma migrate deploy`, o padrão correto
do Prisma é uma **migration nova, com nome/timestamp novo** — não reeditar o conteúdo de uma pasta
cujo nome já tem uma entrada terminal em `_prisma_migrations`. Isso não foi feito nesta sessão —
exigiria: (a) renomear a pasta corrigida para um timestamp novo (ex.:
`20260918160000_rls_tenant_isolation_v2` ou nome equivalente), (b) o que muda novamente o checksum
seria irrelevante já que a pasta em si é nova, (c) rodar `prisma migrate status` para confirmar que
o Prisma agora vê esse novo nome como pendente, (d) só então `prisma migrate deploy`.

**Por que parei aqui, sem fazer esse rename+redeploy nesta mesma sessão:** a tarefa desta etapa foi
explícita — "Se Prisma apresentar estado diferente: PARE e documente" — e o estado apresentado
(`up to date` em vez de "pendente") é exatamente uma divergência do esperado, não uma simples
formalidade a prosseguir. Não fiz nenhuma das ações proibidas (não editei `_prisma_migrations`
manualmente, não apaguei linha, não usei SQL direto no histórico, não usei `--applied`) — apenas
observei e documento o comportamento real, deixando a decisão de como prosseguir (nome novo vs.
outra estratégia) para autorização explícita subsequente.

---

## Fase A — ADR-002

**Aprovado.** `docs/ADR-002_CONTIFISC_RLS_Contexto_Transacional_Mediacao_SECURITY_DEFINER_V1.0.md`
(renomeado do DRAFT, conteúdo revisado e reconciliado, nenhuma divergência contra o SQL validado).
`ADR-D031/D032/D033` registrados formalmente. `ADR-001` V1.1 preservado sem alteração.

## Fase B — Migration definitiva

Promovida: `packages/core/prisma/migrations/20260917130000_rls_tenant_isolation_DRAFT/` →
`packages/core/prisma/migrations/20260918150000_rls_tenant_isolation/` (segunda migration da
cadeia, `20260908120000_init_baseline_fisica_pos_sec` intocada).

```
SHA-256: a82e3c088e9f8ea37eba4087f2303e83e2dcab48e2ba4d9a443f5ba183d255f9
```

Conteúdo do `migration.sql` **byte-idêntico** ao DRAFT validado (checksum confirmado antes e
depois da promoção) — apenas o nome da pasta mudou, nenhuma alteração oportunista.

## Fase C/D — PostgreSQL 18 descartável (1ª execução)

`postgres:18` (imagem oficial) → **PostgreSQL 18.6**, exatamente a mesma versão do Neon DEV.
Baseline + migration definitiva aplicadas limpo (`exit 0` em ambas). Regressão crítica completa
executada sem nenhuma divergência em relação às execuções anteriores em PostgreSQL 15:

- Introspecção: 25/25 tabelas com `RLS`+`FORCE`, 30 policies (22 tabelas com 1 `FOR ALL` + `vinculo`/
  `vinculo_extremidade` com 4 cada + `evento_auditoria_seguranca` com 0), triggers `ADR-C005`/
  `ADR-C014` presentes e inalterados.
- `contifisc_rls_mediator`: `NOLOGIN`✓, `BYPASSRLS`✓.
- `SECURITY DEFINER`: owner correto, `prosecdef=true`, `search_path` fixo, `PUBLIC` sem `EXECUTE`,
  ACL correto — idêntico às execuções anteriores.
- `Tenant`: conta A vê Tenant A, sem `app.current_tenant_id` setado; conta forjada/tenant
  forjado/sem concessão → 0.
- `Vinculo`/`VinculoExtremidade`: criação de vínculo novo ponta a ponta bem-sucedida (C1+C3);
  cross-tenant bloqueado; sem recursão.
- Fail-closed: ausente/vazio/UUID inválido/inexistente — todos 0 linhas, sem erro inesperado.
- `SET LOCAL`: `COMMIT`/`ROLLBACK`/reuso — sem resíduo.
- Prisma `$transaction()`: 3/3 sub-testes corretos.
- SD01-SD15: todos aprovados, incluindo SD08 (schema `evil` com linha forjada, ignorado
  corretamente).
- `ADR-C005`: vínculo com 1 extremidade rejeitado no `COMMIT`.
- `ADR-C014`: restrição de UE sem concessão de tenant rejeitada (pela RLS, antes mesmo do trigger).
- Concorrência real (2 conexões simultâneas, `pg_sleep` de 3s): sem vazamento.
- Runtime (`contifisc_app_test`): não owner, sem `BYPASSRLS` — confirmado.
- `SELECT` sem `WHERE`: não vaza cross-tenant.
- `INSERT`/`UPDATE`/`DELETE` cross-tenant: bloqueados.

**Nenhuma diferença de comportamento entre PG15 e PG18 encontrada.**

## Fase E — Reprodutibilidade PG18 (2ª execução)

Container destruído, novo `postgres:18` vazio criado. Checksums idênticos (baseline e RLS
definitiva). Reaplicação limpa. Subconjunto crítico reexecutado com resultado idêntico: `Tenant`
(C2), `Vinculo` novo (C1+C3), fail-closed, `ADR-C005`, `ADR-C014`, Prisma. Container destruído ao
final.

## Gate pré-deploy

```
CRITICAL = 0, RELEVANTE = 0 — GATE PRÉ-DEPLOY APROVADO, PROSSEGUIU PARA O NEON
```

## Fase F — Pré-flight Neon DEV

| Verificação | Resultado |
|---|---|
| Alvo | `contifisc-dev` (único projeto configurado localmente) |
| Versão PostgreSQL | `18.6` — idêntica à validada nas Fases C/D/E |
| Conexão usada para migration | `DIRECT` (sem `-pooler`) |
| SSL | `sslmode=require` na connection string (driver recusa conectar sem TLS); a métrica interna `pg_stat_ssl`/`SHOW ssl` do backend reporta `false`/`off` — **observação registrada, não bloqueante**: essa métrica reflete o hop interno proxy→compute da arquitetura do Neon, não necessariamente a criptografia do meu lado até a borda do Neon, que é imposta pelo próprio `sslmode=require` do driver |
| Tabelas | 26 (esperado) |
| Policies RLS | 0 (esperado) |
| Funções `contifisc_*` | 0 (esperado) |
| Roles `contifisc_*` | 0 (esperado) |
| Tabelas com RLS `enabled` | 0 (esperado) |
| Migration history antes do deploy | Só `20260908120000_init_baseline_fisica_pos_sec` aplicada; `20260918150000_rls_tenant_isolation` como única pendente (confirmado via `prisma migrate status`) |
| Dado de negócio | 0 (`receita`, `unidade_economica` — ambas vazias) |

Nenhuma migration inesperada pendente. Nenhum drift. **Pré-flight aprovado.**

## Fase G — Recovery

Neon Free (plano atual) suporta branches — não foi criado nenhum branch/recurso adicional nesta
sessão (nenhum recurso pago, nenhum recurso novo criado sem necessidade). **Estratégia de
recuperação adotada e documentada**: como o banco não contém nenhum dado de negócio (confirmado na
Fase F), a estratégia aceitável para DEV é a recriação integral a partir das migrations versionadas
— não foi necessário nenhum snapshot/branch prévio para este deploy. Caso o time deseje uma rede de
segurança adicional antes de autorizar uma nova tentativa, criar um branch Neon (gratuito no plano
atual) antes do próximo `migrate deploy` é a opção recomendada — **não executada nesta sessão**, por
não ter sido estritamente necessária dado o estado vazio do banco, e para não criar recursos além
do estritamente pedido.

## Fase H — Deploy: **FALHOU**

```
Horário: 2026-09-18 10:06:17 (America/Sao_Paulo)
Migration: 20260918150000_rls_tenant_isolation
SHA-256: a82e3c088e9f8ea37eba4087f2303e83e2dcab48e2ba4d9a443f5ba183d255f9
PostgreSQL: 18.6 (Neon DEV)
Comando: prisma migrate deploy --schema packages/core/prisma/schema.prisma
```

**Erro (SQLSTATE 42501):**

```
ERROR: must be able to SET ROLE "contifisc_rls_mediator"
```

### Causa raiz

A migration executa `CREATE ROLE contifisc_rls_mediator ...` e, em seguida,
`ALTER FUNCTION contifisc_conta_tem_acesso_tenant(uuid,uuid) OWNER TO contifisc_rls_mediator` —
transferir a propriedade de um objeto para outro role exige que o role atualmente conectado consiga
`SET ROLE` para o role de destino (ser membro dele, direta ou indiretamente). Em todos os 4
containers descartáveis (2× PG15, 2× PG18), a conexão usada era `postgres`, superuser local, que
sempre pode `SET ROLE` para qualquer role — mascarando esta exigência. No Neon, a conexão usa
`neondb_owner`, um role altamente privilegiado mas **não superuser**, e que **não é
automaticamente membro** de um role recém-criado por ele mesmo — `CREATE ROLE` não implica
`GRANT <novo role> TO <criador>` no PostgreSQL. Isso nunca foi exercitado em nenhuma das PoCs
porque nenhuma delas rodou como um role não-superuser executando a própria `CREATE ROLE`+
`ALTER FUNCTION ... OWNER TO` em sequência.

### O que aconteceu no Neon (confirmado por introspecção pós-falha)

| Item | Resultado |
|---|---|
| Tabelas | 26 (inalterado) |
| Policies | 0 (inalterado) |
| Funções `contifisc_*` | 0 (inalterado — `CREATE ROLE` e a primeira `CREATE FUNCTION` podem ter executado antes do erro, mas a transação inteira do arquivo de migration foi revertida automaticamente pelo PostgreSQL) |
| Roles `contifisc_*` | 0 (inalterado, mesma razão) |
| Tabelas com RLS `enabled` | 0 (inalterado) |
| Dado de negócio | 0 (inalterado) |
| `current_user`/`session_user` da conexão | `neondb_owner` / `neondb_owner` |

**O schema do Neon está byte-a-byte no mesmo estado de antes da tentativa.** O único efeito
colateral real: a tabela de controle `_prisma_migrations` agora tem uma linha para
`20260918150000_rls_tenant_isolation` com `finished_at = NULL` e `rolled_back_at = NULL` — o
Prisma marca essa migration como "falhou, não resolvida", e **bloqueará qualquer novo
`prisma migrate deploy`** até que essa entrada seja resolvida (via `prisma migrate resolve
--rolled-back 20260918150000_rls_tenant_isolation`, comando de bookkeeping do Prisma, não uma
correção manual de SQL) — **não executado nesta sessão**, por instrução explícita de não corrigir
manualmente após uma falha; registrado aqui como o passo necessário antes de qualquer nova
tentativa.

### Correção recomendada (não aplicada nesta sessão)

Adicionar, imediatamente após `CREATE ROLE contifisc_rls_mediator ...`, um:

```sql
GRANT contifisc_rls_mediator TO CURRENT_USER;
```

(`CURRENT_USER` em vez de um nome fixo como `neondb_owner`, para permanecer portátil entre
ambientes — funciona igualmente em `postgres` local ou em qualquer role de migration real usado no
futuro.) Isso concede ao role que está rodando a migration a capacidade de `SET ROLE` para
`contifisc_rls_mediator`, permitindo o `ALTER FUNCTION ... OWNER TO` seguinte. Esta correção **não
foi aplicada nesta sessão** — alterar o `migration.sql` muda seu checksum, o que exigiria repetir a
Fase C/D/E (validação PG18) sobre o arquivo corrigido antes de qualquer nova tentativa de deploy,
conforme a mesma disciplina já seguida em todo este processo.

## Fase I — Introspecção pós-deploy

Não aplicável de forma positiva (nada foi aplicado) — a introspecção de confirmação está na tabela
da Fase H acima, confirmando reversão completa e limpa.

## Fase J — Smoke tests

**Não executados** — dependiam do deploy ter sucesso. Nenhum dado sintético foi criado no Neon.

## Fase K — Esta documentação

Este arquivo.

## Fase L — Git

```
git status --short
?? docs/11-Security/
?? docs/ADR-002_CONTIFISC_RLS_Contexto_Transacional_Mediacao_SECURITY_DEFINER_V1.0.md
?? packages/core/prisma/migrations/20260918150000_rls_tenant_isolation/
?? packages/core/prisma/rls/

git diff --stat -- packages/core/prisma/migrations/20260908120000_init_baseline_fisica_pos_sec/
(vazio — migration inaugural intacta)
```

Nenhum `.env`, connection string, senha, token, dump ou log sensível em nenhum arquivo novo.
Nenhum commit realizado. Nenhum push realizado.

## Classificação final (atualizada após o adendo)

| Severidade | Quantidade | Itens |
|---|---|---|
| `CRITICAL` | 0 | Nenhum achado de isolamento/segurança em nenhuma das duas rodadas — as duas falhas (privilégio + bookkeeping do Prisma) são de **provisionamento/processo**, não de desenho de RLS |
| `RELEVANTE` | 1 | O `migration.sql` corrigido (checksum `aa95ddfa...2bbea`) **já não pode ser reaplicado sob o nome de pasta atual** (`20260918150000_rls_tenant_isolation`) via `prisma migrate deploy`, porque essa migration já tem uma entrada terminal (`rolled_back_at` preenchido) em `_prisma_migrations` — o Prisma não reexamina o conteúdo local de uma migration já resolvida. Corrigir exige uma migration com **nome novo** (não a mesma pasta reeditada) |
| `MENOR` | 1 | Métrica de SSL do backend (`pg_stat_ssl`/`SHOW ssl`) não reflete diretamente a criptografia cliente→borda do Neon — apenas uma observação de transparência, já registrada na Fase F, não um risco de segurança identificado |

**O achado de privilégio original (`SET ROLE`) está tecnicamente resolvido e validado 2x em
PostgreSQL 18 com um role não-superuser mimetizando o Neon** — não é mais um bloqueador em si. O
que bloqueia agora é exclusivamente a mecânica de bookkeeping do Prisma diante de uma migration já
marcada como rolled-back.

## Conclusão

```
RLS PÓS-SEC — DEPLOY NO NEON DEV REQUER REVISÃO
```

`RELEVANTE = 1`. Nenhum `CRITICAL` em nenhuma das duas rodadas. Nenhuma autenticação implementada.
Nenhum frontend criado. Nenhum seed permanente. Nenhuma Skill iniciada. Nenhum commit/push.

## Próximo passo recomendado

1. Renomear a pasta da migration corrigida para um timestamp novo, nunca antes tentado (ex.:
   `20260918160000_rls_tenant_isolation`, ou nome equivalente combinado com o time) — **não**
   reeditar o nome já usado na tentativa que falhou.
2. Rodar `prisma migrate status` para confirmar que o Prisma agora vê esse novo nome como pendente
   (e que a entrada antiga, `20260918150000_...`/`rolled_back_at` preenchido, permanece intacta no
   histórico como registro da tentativa anterior — nunca apagada).
3. `prisma migrate deploy` contra o Neon DEV com o novo nome.
4. Introspecção pós-deploy (Fase I) + smoke tests S01-S17 (Fase J), como já especificado.

Nenhum desses 4 passos foi executado nesta sessão — todos exigem nova autorização explícita. O
achado de privilégio (a parte tecnicamente mais complexa) já está resolvido e revalidado; o que
falta é puramente administrativo (escolher e aplicar o novo nome de migration).
