// ============================================================================
// PoC ADR-C014 -- testes via Prisma Client $transaction() (EXPERIMENTAL)
// Roda contra 01_schema_fixed.sql aplicado em um container descartavel.
// Usa POC_DATABASE_URL (variavel de ambiente, nunca escrita em .env).
// Nao altera o schema.prisma canonico do projeto.
// ============================================================================
import { PrismaClient } from './generated-client/index.js';

const prisma = new PrismaClient({ datasourceUrl: process.env.POC_DATABASE_URL });

const T1 = '55555555-5555-5555-5555-555555555555';
const U1 = 'a5555555-5555-5555-5555-555555555555';
const C1 = 'c5555555-5555-5555-5555-555555555555'; // tem concessao em T1
const C2 = 'c6666666-6666-6666-6666-666666666666'; // sem concessao nenhuma
const CAT1 = 'd5555555-5555-5555-5555-555555555555';

async function seed() {
  await prisma.tenant.create({ data: { id: T1 } });
  await prisma.unidadeEconomica.create({ data: { id: U1, tenant_id: T1 } });
  await prisma.contaAcesso.create({ data: { id: C1 } });
  await prisma.contaAcesso.create({ data: { id: C2 } });
  await prisma.contaAcessoTenant.create({
    data: { id: CAT1, conta_acesso_id: C1, tenant_id: T1, papel: 'ADMIN' },
  });
  console.log('SEED: ok');
}

async function casoValido() {
  const id = 'e5555555-5555-5555-5555-555555555555';
  try {
    await prisma.$transaction([
      prisma.contaAcessoUnidadeEconomica.create({
        data: { id, conta_acesso_id: C1, unidade_economica_id: U1, papel: 'LEITURA' },
      }),
    ]);
    console.log('CASO VALIDO (Prisma $transaction, array): ACEITO (esperado)');
  } catch (err) {
    console.log('CASO VALIDO (Prisma $transaction, array): REJEITADO (inesperado) ->', err.message.split('\n')[0]);
  } finally {
    await prisma.contaAcessoUnidadeEconomica.deleteMany({ where: { id } }).catch(() => {});
  }
}

async function casoInvalido() {
  const id = 'e6666666-6666-6666-6666-666666666666';
  try {
    await prisma.$transaction([
      prisma.contaAcessoUnidadeEconomica.create({
        data: { id, conta_acesso_id: C2, unidade_economica_id: U1, papel: 'LEITURA' },
      }),
    ]);
    console.log('CASO INVALIDO (Prisma $transaction, array): ACEITO (inesperado -- deveria ter sido rejeitado)');
  } catch (err) {
    console.log('CASO INVALIDO (Prisma $transaction, array): REJEITADO (esperado) ->', err.message.split('\n').find(l => l.includes('ADR-C014')) ?? err.message.split('\n')[0]);
  }
}

async function casoDeferidoValido() {
  const caueId = 'e7777777-7777-7777-7777-777777777777';
  const catId = 'd7777777-7777-7777-7777-777777777777';
  try {
    // interactive transaction: insere a restricao (C2 x U1) e, na MESMA
    // transacao, cria a concessao que faltava -- estado intermediario
    // invalido, estado final valido.
    await prisma.$transaction(async (tx) => {
      await tx.contaAcessoUnidadeEconomica.create({
        data: { id: caueId, conta_acesso_id: C2, unidade_economica_id: U1, papel: 'LEITURA' },
      });
      // estado intermediario aqui e invalido (C2 ainda sem concessao em T1) --
      // mas o CONSTRAINT TRIGGER e DEFERRED, entao nenhuma excecao e lancada agora.
      await tx.contaAcessoTenant.create({
        data: { id: catId, conta_acesso_id: C2, tenant_id: T1, papel: 'OPERADOR' },
      });
    });
    console.log('CASO DEFERIDO VALIDO (Prisma $transaction interativa, estado intermediario invalido -> final valido): ACEITO (esperado)');
  } catch (err) {
    console.log('CASO DEFERIDO VALIDO: REJEITADO (inesperado) ->', err.message.split('\n')[0]);
  } finally {
    await prisma.contaAcessoUnidadeEconomica.deleteMany({ where: { id: caueId } }).catch(() => {});
    await prisma.contaAcessoTenant.deleteMany({ where: { id: catId } }).catch(() => {});
  }
}

async function casoDeferidoInvalido() {
  const caueId = 'e8888888-8888-8888-8888-888888888888';
  try {
    await prisma.$transaction(async (tx) => {
      await tx.contaAcessoUnidadeEconomica.create({
        data: { id: caueId, conta_acesso_id: C2, unidade_economica_id: U1, papel: 'LEITURA' },
      });
      // nunca cria a concessao correspondente -- estado final permanece invalido
    });
    console.log('CASO DEFERIDO INVALIDO (Prisma $transaction interativa): ACEITO (inesperado -- deveria ter sido rejeitado no commit)');
  } catch (err) {
    console.log('CASO DEFERIDO INVALIDO (Prisma $transaction interativa): REJEITADO (esperado) ->', err.message.split('\n').find(l => l.includes('ADR-C014')) ?? err.message.split('\n')[0]);
  }
}

async function main() {
  await seed();
  await casoValido();
  await casoInvalido();
  await casoDeferidoValido();
  await casoDeferidoInvalido();
}

main()
  .catch((e) => {
    console.error('ERRO NAO TRATADO:', e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
