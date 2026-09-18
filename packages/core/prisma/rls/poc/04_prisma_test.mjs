import { PrismaClient } from "../../../../../node_modules/@prisma/client/index.js";

const prisma = new PrismaClient({
  datasources: { db: { url: process.env.POC_DATABASE_URL } },
});

async function run() {
  // Teste 1: SET LOCAL + query dentro do mesmo $transaction -> ve so o tenant A
  const asTenantA = await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe(
      "SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000aa'"
    );
    await tx.$executeRawUnsafe(
      "SET LOCAL app.current_tenant_id = 'aaaaaaaa-0000-0000-0000-00000000000a'"
    );
    return tx.$queryRawUnsafe("SELECT id FROM receita ORDER BY id");
  });
  console.log("TESTE 1 (Prisma $transaction, contexto Tenant A):", JSON.stringify(asTenantA));

  // Teste 2: nova chamada Prisma (pode reusar conexao do pool interno do Prisma) SEM novo SET LOCAL
  // dentro de uma NOVA transacao -> deve ver 0 linhas (contexto nao vaza entre transactions)
  const semContexto = await prisma.$transaction(async (tx) => {
    return tx.$queryRawUnsafe("SELECT id FROM receita ORDER BY id");
  });
  console.log(
    "TESTE 2 (Prisma $transaction NOVA, sem novo SET LOCAL, mesmo client/pool):",
    JSON.stringify(semContexto)
  );

  // Teste 3: contexto Tenant B, para confirmar que o pool interno do Prisma tambem nao vaza
  const asTenantB = await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe(
      "SET LOCAL app.current_conta_acesso_id = 'cccccccc-0000-0000-0000-0000000000bb'"
    );
    await tx.$executeRawUnsafe(
      "SET LOCAL app.current_tenant_id = 'bbbbbbbb-0000-0000-0000-00000000000b'"
    );
    return tx.$queryRawUnsafe("SELECT id FROM receita ORDER BY id");
  });
  console.log("TESTE 3 (Prisma $transaction, contexto Tenant B):", JSON.stringify(asTenantB));

  await prisma.$disconnect();
}

run().catch(async (e) => {
  console.error("ERRO:", e);
  await prisma.$disconnect();
  process.exit(1);
});
