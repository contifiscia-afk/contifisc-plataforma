/**
 * DST-T019 / MCD-F3004: competência é YYYY-MM, nunca uma data fictícia no dia 1.
 * Representada como string opaca validada — sem conversão para Date.
 */
const COMPETENCIA_REGEX = /^(\d{4})-(0[1-9]|1[0-2])$/;

export type Competencia = string & { readonly __brand: 'Competencia' };

export function isCompetencia(value: string): value is Competencia {
  return COMPETENCIA_REGEX.test(value);
}

export function assertCompetencia(value: string): Competencia {
  if (!isCompetencia(value)) {
    throw new TypeError(
      `Competência inválida (esperado YYYY-MM, ex.: 2026-08; não é uma data): ${value}`,
    );
  }
  return value;
}

function toComparable(value: Competencia): number {
  const match = COMPETENCIA_REGEX.exec(value)!;
  return Number(match[1]) * 12 + Number(match[2]);
}

export function isBeforeCompetencia(a: Competencia, b: Competencia): boolean {
  return toComparable(a) < toComparable(b);
}

export function isAfterCompetencia(a: Competencia, b: Competencia): boolean {
  return toComparable(a) > toComparable(b);
}

export function equalsCompetencia(a: Competencia, b: Competencia): boolean {
  return a === b;
}
