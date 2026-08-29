// PoC descartável — testa se prisma.$transaction() produz o mesmo comportamento
// observado via SQL direto para a constraint trigger diferida (ADR-C005 / COT-REL-NORM-001).
// Também serve para validar, na prática, import ESM do Prisma Client neste projeto
// ("type": "module") e execução de $transaction.
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const UE = '00000000-0000-4000-8000-000000000001';
const PF = '00000000-0000-4000-8000-000000000002';
const PJ = '00000000-0000-4000-8000-000000000003';

let pass = 0;
let fail = 0;

function report(ok, label, detail) {
  if (ok) {
    pass += 1;
    console.log(`PASS: ${label}`);
  } else {
    fail += 1;
    console.log(`FAIL: ${label}`);
    if (detail) console.log(`  detalhe: ${detail}`);
  }
}

async function reset() {
  await prisma.$executeRawUnsafe('TRUNCATE vinculo_extremidade, vinculo CASCADE;');
}

async function main() {
  console.log(`Prisma Client conectado. Import ESM funcionou (PrismaClient === ${typeof PrismaClient}).`);

  // Cenário A: $transaction (forma array) — ORIGEM + DESTINO — deve ser aceito.
  await reset();
  const vinculoIdA = '20000000-0000-4000-8000-000000000001';
  try {
    await prisma.$transaction([
      prisma.vinculo.create({ data: { id: vinculoIdA, tipoVinculo: 'POC_GENERICO' } }),
      prisma.vinculoExtremidade.create({
        data: { vinculoId: vinculoIdA, ladoExtremidade: 'ORIGEM', pessoaFisicaId: PF },
      }),
      prisma.vinculoExtremidade.create({
        data: { vinculoId: vinculoIdA, ladoExtremidade: 'DESTINO', pessoaJuridicaId: PJ },
      }),
    ]);
    const count = await prisma.vinculoExtremidade.count({ where: { vinculoId: vinculoIdA } });
    report(count === 2, '$transaction (array) com ORIGEM+DESTINO é aceito e persiste 2 linhas', `count=${count}`);
  } catch (err) {
    report(false, '$transaction (array) com ORIGEM+DESTINO é aceito e persiste 2 linhas', err.message);
  }

  // Cenário B: $transaction (forma array) — só ORIGEM — deve ser REJEITADO pelo trigger diferido.
  await reset();
  const vinculoIdB = '20000000-0000-4000-8000-000000000002';
  try {
    await prisma.$transaction([
      prisma.vinculo.create({ data: { id: vinculoIdB, tipoVinculo: 'POC_GENERICO' } }),
      prisma.vinculoExtremidade.create({
        data: { vinculoId: vinculoIdB, ladoExtremidade: 'ORIGEM', pessoaFisicaId: PF },
      }),
    ]);
    report(false, '$transaction (array) com apenas ORIGEM deve ser rejeitado no commit', 'transação não lançou erro (inesperado)');
  } catch (err) {
    const matches = /ADR-C005\/COT-REL-NORM-001/.test(err.message);
    report(matches, '$transaction (array) com apenas ORIGEM deve ser rejeitado no commit', matches ? undefined : err.message);
  }
  const countAfterB = await prisma.vinculoExtremidade.count({ where: { vinculoId: vinculoIdB } });
  report(countAfterB === 0, 'rollback confirmado: nenhuma linha do vínculo B persistiu após a rejeição', `count=${countAfterB}`);

  // Cenário C: $transaction interativa (callback) — ORIGEM + DESTINO — deve ser aceito.
  await reset();
  const vinculoIdC = '20000000-0000-4000-8000-000000000003';
  try {
    await prisma.$transaction(async (tx) => {
      await tx.vinculo.create({ data: { id: vinculoIdC, tipoVinculo: 'POC_GENERICO' } });
      await tx.vinculoExtremidade.create({
        data: { vinculoId: vinculoIdC, ladoExtremidade: 'ORIGEM', unidadeEconomicaId: UE },
      });
      // Estado intermediário: dentro da transação interativa, só 1 extremidade existe ainda.
      const intermediateCount = await tx.vinculoExtremidade.count({ where: { vinculoId: vinculoIdC } });
      report(intermediateCount === 1, 'estado intermediário (1 linha) é legível dentro da transação interativa, sem erro', `count=${intermediateCount}`);
      await tx.vinculoExtremidade.create({
        data: { vinculoId: vinculoIdC, ladoExtremidade: 'DESTINO', pessoaFisicaId: PF },
      });
    });
    const count = await prisma.vinculoExtremidade.count({ where: { vinculoId: vinculoIdC } });
    report(count === 2, '$transaction interativa (callback) com ORIGEM+DESTINO é aceita', `count=${count}`);
  } catch (err) {
    report(false, '$transaction interativa (callback) com ORIGEM+DESTINO é aceita', err.message);
  }

  // Cenário D: $transaction interativa — só DESTINO — deve ser REJEITADO no commit implícito ao fim do callback.
  await reset();
  const vinculoIdD = '20000000-0000-4000-8000-000000000004';
  try {
    await prisma.$transaction(async (tx) => {
      await tx.vinculo.create({ data: { id: vinculoIdD, tipoVinculo: 'POC_GENERICO' } });
      await tx.vinculoExtremidade.create({
        data: { vinculoId: vinculoIdD, ladoExtremidade: 'DESTINO', pessoaJuridicaId: PJ },
      });
    });
    report(false, '$transaction interativa com apenas DESTINO deve ser rejeitada no commit', 'transação não lançou erro (inesperado)');
  } catch (err) {
    const matches = /ADR-C005\/COT-REL-NORM-001/.test(err.message);
    report(matches, '$transaction interativa com apenas DESTINO deve ser rejeitada no commit', matches ? undefined : err.message);
  }

  await reset();
  console.log('\n==========================================');
  console.log(`RESULTADO PRISMA $transaction: ${pass} passaram, ${fail} falharam (de ${pass + fail} cenários)`);
  console.log('==========================================');

  await prisma.$disconnect();
  process.exit(fail === 0 ? 0 : 1);
}

main().catch(async (err) => {
  console.error('Erro fatal na PoC:', err);
  await prisma.$disconnect();
  process.exit(1);
});
