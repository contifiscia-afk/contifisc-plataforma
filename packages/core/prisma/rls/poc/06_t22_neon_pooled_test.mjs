// T22 — teste transacional NAO DESTRUTIVO contra o Neon DEV real (direct e
// pooled). NUNCA loga DATABASE_URL/DATABASE_URL_POOLED. Nao toca tabelas de
// negocio, nao cria schema, nao aplica migration. So GUC sintetico via
// SET LOCAL + current_setting(), dentro de $transaction() do Prisma.

import { PrismaClient } from "../../../../../node_modules/@prisma/client/index.js";

async function testar(label, url) {
  const prisma = new PrismaClient({ datasources: { db: { url } } });
  const resultado = { label };

  try {
    // A. SET LOCAL visivel dentro da transacao
    const dentro = await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(
        "SET LOCAL app.contifisc_poc_context = 'valor-sintetico-t22'"
      );
      const r = await tx.$queryRawUnsafe(
        "SELECT current_setting('app.contifisc_poc_context', true) AS v"
      );
      return r[0].v;
    });
    resultado.A_dentro_da_transacao = dentro;

    // B. desaparece apos COMMIT (nova transaction, sem novo SET LOCAL)
    const posCommit = await prisma.$transaction(async (tx) => {
      const r = await tx.$queryRawUnsafe(
        "SELECT current_setting('app.contifisc_poc_context', true) AS v"
      );
      return r[0].v;
    });
    resultado.B_pos_commit_sem_novo_set_local = posCommit;

    // C. desaparece apos ROLLBACK
    try {
      await prisma.$transaction(async (tx) => {
        await tx.$executeRawUnsafe(
          "SET LOCAL app.contifisc_poc_context = 'outro-valor-sintetico'"
        );
        throw new Error("ROLLBACK_PROPOSITAL_T22");
      });
    } catch (e) {
      if (e.message !== "ROLLBACK_PROPOSITAL_T22") throw e;
    }
    const posRollback = await prisma.$transaction(async (tx) => {
      const r = await tx.$queryRawUnsafe(
        "SELECT current_setting('app.contifisc_poc_context', true) AS v"
      );
      return r[0].v;
    });
    resultado.C_pos_rollback = posRollback;

    // D. reutilizacao de conexao/pool interno do Prisma nao carrega contexto anterior
    const reuso1 = await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(
        "SET LOCAL app.contifisc_poc_context = 'sessao-1'"
      );
      const r = await tx.$queryRawUnsafe(
        "SELECT current_setting('app.contifisc_poc_context', true) AS v"
      );
      return r[0].v;
    });
    const reuso2 = await prisma.$transaction(async (tx) => {
      const r = await tx.$queryRawUnsafe(
        "SELECT current_setting('app.contifisc_poc_context', true) AS v"
      );
      return r[0].v;
    });
    resultado.D_reuso_conexao = { sessao1: reuso1, sessao2_sem_set_local: reuso2 };

    // Versao do Postgres (sem expor host/credenciais)
    const versao = await prisma.$queryRawUnsafe("SELECT version() AS v");
    resultado.postgres_version = versao[0].v;

    resultado.status = "OK";
  } catch (err) {
    resultado.status = "ERRO";
    resultado.erro = err.message;
  } finally {
    await prisma.$disconnect();
  }

  return resultado;
}

const direct = process.env.T22_DIRECT_URL;
const pooled = process.env.T22_POOLED_URL;

const out = {};
if (direct) out.direct = await testar("direct", direct);
if (pooled) out.pooled = await testar("pooled", pooled);

console.log(JSON.stringify(out, null, 2));
