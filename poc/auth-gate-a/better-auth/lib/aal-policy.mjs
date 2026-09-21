// Espelho JS (PoC) de satisfiesAuthenticationLevel do contrato contracts/identity-provider.ts.
export function satisfiesAuthenticationLevel(id, required, now = new Date()) {
  if (id.authenticationLevel < required.minLevel) return false;
  if (required.maxFactorAgeSeconds !== undefined) {
    const t = id.lastFactorVerifiedAt ?? id.authenticatedAt;
    if ((now.getTime() - t.getTime()) / 1000 > required.maxFactorAgeSeconds) return false;
  }
  return true;
}
