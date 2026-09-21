/**
 * CONTRATO CONCEITUAL `IdentityProvider` — Gate A / ADR-003 (PoC descartável; NÃO é código de produto).
 *
 * Objetivo: a CONTIFISC nunca acopla domínio (ContaAcesso, Tenant, entitlement, RBAC, RLS) ao SDK de um
 * fornecedor. Qualquer fornecedor (Better Auth hoje, outro amanhã) é um *adapter* que produz uma
 * `AuthenticatedIdentity`. Nomes não estão congelados.
 *
 * Regras de projeto (verificadas nos testes do Gate A):
 *  - O contrato entrega QUEM É (provider+issuer+subject) e COMO a sessão foi autenticada (nível/fatores).
 *  - O contrato NÃO entrega e-mail como identidade, nem organização/time/workspace, nem papéis, nem tenant.
 *  - Nada que o fornecedor devolva decide Tenant, entitlement, permissão, UE ou RLS.
 */

/** Nível de autenticação (AAL) CALCULADO/ATESTADO pela CONTIFISC — não é claim confiável do fornecedor. */
export type AuthenticationLevel = 1 | 2 | 3;

export type AuthFactor =
  | "pwd"          // senha (conhecimento)
  | "totp"         // autenticador TOTP (posse)
  | "otp"          // código por canal (e-mail/SMS)
  | "backup_code"  // código de recuperação
  | "passkey"      // WebAuthn (posse + verificação do usuário, quando UV=true)
  | "oauth";       // login federado (o nível de garantia depende do IdP externo — NÃO presumido)

export interface AuthenticatedIdentity {
  /** Chave do fornecedor, ex.: "better_auth" | "clerk" | "neon_auth". */
  readonly provider: string;
  /** Instância/ambiente do fornecedor (issuer/projeto). Evita colisão entre ambientes. */
  readonly issuer: string;
  /** Identificador ESTÁVEL e OPACO do usuário no fornecedor. Jamais e-mail. */
  readonly subject: string;
  /** Identificador da sessão no fornecedor (para revogação/auditoria). */
  readonly sessionId: string;
  /** Instante da autenticação primária (UTC). */
  readonly authenticatedAt: Date;
  /** Expiração da sessão no fornecedor, se conhecida. */
  readonly sessionExpiresAt?: Date;
  /** Nível atestado pela CONTIFISC para ESTA sessão. */
  readonly authenticationLevel: AuthenticationLevel;
  /** Fatores efetivamente verificados nesta sessão. */
  readonly factors: readonly AuthFactor[];
  /** Instante do último fator (re)verificado (step-up); base da exigência "verificado há ≤ N min". */
  readonly lastFactorVerifiedAt?: Date;
  /** De onde vem a evidência de nível/fatores (importante para auditoria). */
  readonly evidence: "contifisc_hook" | "provider_claim" | "unknown";
}

export interface ResolveOptions {
  /** Ignora qualquer cache de sessão do lado do cliente/cookie (obrigatório para decisões sensíveis). */
  readonly bypassSessionCache?: boolean;
}

export interface IdentityProvider {
  readonly provider: string;
  readonly issuer: string;

  /** Valida a sessão NO SERVIDOR (nunca só "cookie existe") e devolve a identidade, ou null. */
  resolve(request: { headers: Headers }, options?: ResolveOptions): Promise<AuthenticatedIdentity | null>;

  /** Revoga UMA sessão no fornecedor. */
  revokeSession(sessionId: string): Promise<void>;

  /** Revoga TODAS as sessões de um sujeito no fornecedor. */
  revokeAllSessions(subject: string): Promise<number>;

  /**
   * Step-up: reverifica um fator para a sessão atual e registra a elevação. Retorna false se o fornecedor
   * não suportar ou se a verificação falhar. Opcional: fornecedores sem step-up devem responder `unsupported`.
   */
  stepUp?(request: { headers: Headers }, proof: { factor: "totp" | "backup_code" | "otp"; code: string }): Promise<boolean>;
}

/** Política CONTIFISC: a sessão satisfaz o nível exigido para a operação? (independe do fornecedor) */
export function satisfiesAuthenticationLevel(
  id: AuthenticatedIdentity,
  required: { minLevel: AuthenticationLevel; maxFactorAgeSeconds?: number },
  now: Date,
): boolean {
  if (id.authenticationLevel < required.minLevel) return false;
  if (required.maxFactorAgeSeconds !== undefined) {
    const t = id.lastFactorVerifiedAt ?? id.authenticatedAt;
    if ((now.getTime() - t.getTime()) / 1000 > required.maxFactorAgeSeconds) return false;
  }
  return true;
}

/** Saída que o Gate A entrega ao Gate B (o Gate B estabelece o contexto transacional/RLS a partir dela). */
export interface ResolvedPrincipal {
  readonly contaAcessoId: string; // ContaAcesso ATIVA resolvida via IdentidadeAcessoExterna(ATIVA)
  readonly identity: AuthenticatedIdentity;
}
