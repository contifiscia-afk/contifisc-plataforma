// LOGICA CONTIFISC de PoC (provider-agnostica). Prisma sobre tabelas descartaveis do harness.
// Nao usa e-mail, organizacao ou papel do provedor em nenhuma decisao.
import { prisma } from "./auth-factory.mjs";

/** provider+issuer+subject -> ContaAcesso. Nunca por e-mail. */
export async function resolveConta(identity) {
  const ident = await prisma.identidadeAcessoExterna.findFirst({
    where: { provedor: identity.provider, emissor: identity.issuer, subject_externo: identity.subject },
    include: { conta: true },
  });
  if (!ident) return { ok: false, reason: "IDENTIDADE_SEM_CONTA" };
  if (ident.estado !== "ATIVA") return { ok: false, reason: `IDENTIDADE_${ident.estado}` };
  if (ident.conta.status !== "ATIVA") return { ok: false, reason: `CONTA_${ident.conta.status}` };
  return { ok: true, contaId: ident.conta_acesso_id, categoria: ident.conta.categoria, tipo: ident.conta.tipo };
}

/** Concessao vigente? O RELOGIO E O DO BANCO (now()), nunca o do navegador. Sem job/varredor. */
export async function podeUsarTenant(contaId, tenantId) {
  const r = await prisma.$queryRaw`
    select exists (
      select 1
        from conta_acesso_tenant c
        join tenant t on t.id = c.tenant_id
       where c.conta_acesso_id = ${contaId}::uuid
         and c.tenant_id       = ${tenantId}::uuid
         and t.status = 'ATIVO'
         and c.vigencia_inicio <= now()
         and (c.vigencia_fim is null or now() < c.vigencia_fim)
    ) as ok`;
  return r[0].ok === true;
}

/** Mesmo predicado, com instante explicito (para testar fronteiras exatas). Em producao o instante e now() do banco. */
export async function vigenteEm(concessaoId, at) {
  const r = await prisma.$queryRaw`
    select (vigencia_inicio <= ${at}::timestamptz and (vigencia_fim is null or ${at}::timestamptz < vigencia_fim)) as ok
      from conta_acesso_tenant where id = ${concessaoId}::uuid`;
  return r[0].ok === true;
}

export async function listarTenantsVigentes(contaId) {
  const r = await prisma.$queryRaw`
    select c.tenant_id, c.papel
      from conta_acesso_tenant c join tenant t on t.id = c.tenant_id
     where c.conta_acesso_id = ${contaId}::uuid and t.status = 'ATIVO'
       and c.vigencia_inicio <= now() and (c.vigencia_fim is null or now() < c.vigencia_fim)
     order by c.tenant_id`;
  return r;
}

/** Pipeline completo: sessao do provedor -> identidade -> ContaAcesso -> (opcional) tenant. */
export async function principalFromRequest(idp, request, { tenantId, bypassSessionCache = true } = {}) {
  const identity = await idp.resolve(request, { bypassSessionCache });
  if (!identity) return { ok: false, reason: "NAO_AUTENTICADO" };
  const conta = await resolveConta(identity);
  if (!conta.ok) return { ok: false, reason: conta.reason, identity };
  if (tenantId) {
    const ok = await podeUsarTenant(conta.contaId, tenantId);
    if (!ok) return { ok: false, reason: "TENANT_NAO_AUTORIZADO", identity, contaId: conta.contaId };
  }
  return { ok: true, contaId: conta.contaId, identity, categoria: conta.categoria };
}

// ---------- helpers de setup de fixtures FICTICIAS ----------
export async function novaConta({ categoria = "CLIENTE", tipo = "HUMANA", status = "ATIVA" } = {}) {
  return prisma.contaAcesso.create({ data: { categoria, tipo, status } });
}
export async function vincular(conta, { provider = "better_auth", issuer = "poc-local", subject, estado = "ATIVA" }) {
  return prisma.identidadeAcessoExterna.create({ data: { provedor: provider, emissor: issuer, subject_externo: subject, conta_acesso_id: conta.id, estado, metodo_verificacao_vinculo: "poc-admin" } });
}
export async function novoTenant(status = "ATIVO") { return prisma.tenantPoc.create({ data: { status } }); }
export async function conceder(conta, tenant, papel, { inicio, fim, origem = "REGULAR" } = {}) {
  return prisma.contaAcessoTenantPoc.create({ data: { conta_acesso_id: conta.id, tenant_id: tenant.id, papel, origem, ...(inicio ? { vigencia_inicio: inicio } : {}), ...(fim !== undefined ? { vigencia_fim: fim } : {}) } });
}

