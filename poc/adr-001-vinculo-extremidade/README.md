# PoC — ADR-001 §5.1 / §15 passo 2 (ADR-C005 / COT-REL-NORM-001)

**Experimental, isolada e descartável.** Não representa o schema canônico da CONTIFISC, não é
usada por nenhum `package.json` do monorepo (fora dos globs `apps/*`/`packages/*`) e não deve
ser promovida a código de produção sem uma decisão explícita separada.

## O que esta PoC prova

Que uma `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED` no PostgreSQL consegue impor
"todo `Vinculo` deve ter exatamente duas `VinculoExtremidade`, uma `ORIGEM` e uma `DESTINO`"
(ADR-C005 / `COT-REL-NORM-001`) — e que esse comportamento é idêntico quando as mesmas operações
passam por `prisma.$transaction()` (forma array e forma interativa).

## Modelo mínimo (não é o MCD inteiro)

`unidade_economica`, `pessoa_fisica`, `pessoa_juridica` (só `id`), `vinculo` (`id`,
`tipo_vinculo`) e `vinculo_extremidade` (`id`, `vinculo_id`, `lado_extremidade`, 3 FKs opcionais
XOR). Ver `sql/001_schema.sql`.

## Como reproduzir

```bash
# 1. Subir um Postgres 15 descartável (porta 55432, nunca a oficial do projeto)
docker run -d --name adr001-poc-pg15 \
  -e POSTGRES_USER=poc_user -e POSTGRES_PASSWORD=poc_pass_disposable \
  -e POSTGRES_DB=adr001_poc -p 55432:5432 postgres:15

# 2. Aplicar o schema mínimo + seed
docker exec -i adr001-poc-pg15 psql -U poc_user -d adr001_poc -v ON_ERROR_STOP=1 < sql/001_schema.sql
docker exec -i adr001-poc-pg15 psql -U poc_user -d adr001_poc -v ON_ERROR_STOP=1 < sql/002_seed.sql

# 3. Rodar os 9 cenários via SQL direto
bash tests/run-sql-scenarios.sh

# 4. Rodar os 6 cenários equivalentes via Prisma $transaction
cd prisma-poc
npm install
npx prisma generate
node run-transaction-tests.mjs

# 5. Descartar o container
docker rm -f adr001-poc-pg15
```

`prisma-poc/.env` (gitignorado, não versionado) define `POC_DATABASE_URL` apontando para o
container efêmero — nunca a `DATABASE_URL` oficial do projeto, que permanece vazia em
`.env.example` na raiz.

## Por que Prisma 6.19.3, não a versão mais recente

`npm view prisma version` resolve hoje para `8.0.0-rc.12` (release candidate, não GA). Ao tentar
gerar o client com Prisma 7.10.0 (a última linha estável completa), a geração falhou:

```
Error: Prisma schema validation - (get-config wasm)
error: The datasource property `url` is no longer supported in schema files.
Move connection URLs for Migrate to `prisma.config.ts` and pass either `adapter`
for a direct database connection or `accelerateUrl` for Accelerate to the
`PrismaClient` constructor.
```

Prisma 7+ remove `datasource.url` do `schema.prisma` em favor de `prisma.config.ts` + driver
adapters (`@prisma/adapter-pg`). Isso é uma mudança arquitetural relevante para uma futura
proposta de `schema.prisma` canônico — ver relatório da PoC para detalhes. Para validar o padrão
que o ADR-001 pressupõe (`datasource db { url = env(...) }` clássico), a PoC foi fixada em
`prisma@6.19.3`/`@prisma/client@6.19.3`, a última linha major anterior a essa mudança.
