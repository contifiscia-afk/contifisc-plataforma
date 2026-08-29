import { describe, expect, it } from 'vitest';
import {
  assertCompetencia,
  isAfterCompetencia,
  isBeforeCompetencia,
  isCompetencia,
} from '../../packages/types/src/Competencia.js';

describe('Competencia', () => {
  it('aceita YYYY-MM', () => {
    expect(isCompetencia('2026-08')).toBe(true);
  });

  it('rejeita data fictícia no dia 1 (2026-08-01 não é competência válida)', () => {
    expect(isCompetencia('2026-08-01')).toBe(false);
    expect(() => assertCompetencia('2026-08-01')).toThrow(TypeError);
  });

  it('rejeita mês fora do intervalo 01-12', () => {
    expect(isCompetencia('2026-13')).toBe(false);
    expect(isCompetencia('2026-00')).toBe(false);
  });

  it('compara competências corretamente', () => {
    const a = assertCompetencia('2026-08');
    const b = assertCompetencia('2026-09');
    expect(isBeforeCompetencia(a, b)).toBe(true);
    expect(isAfterCompetencia(b, a)).toBe(true);
  });
});
