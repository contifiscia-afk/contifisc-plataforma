const SEMVER_REGEX = /^(\d+)\.(\d+)\.(\d+)$/;

export type SemVer = string & { readonly __brand: 'SemVer' };

export function isSemVer(value: string): value is SemVer {
  return SEMVER_REGEX.test(value);
}

export function assertSemVer(value: string): SemVer {
  if (!isSemVer(value)) {
    throw new TypeError(`Versão semântica inválida (esperado MAJOR.MINOR.PATCH): ${value}`);
  }
  return value;
}

function parts(value: SemVer): [number, number, number] {
  const match = SEMVER_REGEX.exec(value);
  if (!match) {
    throw new TypeError(`Versão semântica inválida: ${value}`);
  }
  return [Number(match[1]), Number(match[2]), Number(match[3])];
}

export function compareSemVer(a: SemVer, b: SemVer): -1 | 0 | 1 {
  const pa = parts(a);
  const pb = parts(b);
  for (let i = 0; i < 3; i += 1) {
    if (pa[i] !== pb[i]) {
      return pa[i]! > pb[i]! ? 1 : -1;
    }
  }
  return 0;
}
