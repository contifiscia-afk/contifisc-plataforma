import { describe, expect, it } from 'vitest';
import { assertSemVer, compareSemVer, isSemVer } from '../../packages/types/src/SemVer.js';

describe('SemVer', () => {
  it('aceita formato MAJOR.MINOR.PATCH', () => {
    expect(isSemVer('1.2.3')).toBe(true);
    expect(isSemVer('1.2')).toBe(false);
    expect(isSemVer('v1.2.3')).toBe(false);
  });

  it('compara versões corretamente', () => {
    const a = assertSemVer('1.2.3');
    const b = assertSemVer('1.10.0');
    expect(compareSemVer(a, b)).toBe(-1);
    expect(compareSemVer(b, a)).toBe(1);
    expect(compareSemVer(a, a)).toBe(0);
  });
});
