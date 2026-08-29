import { describe, expect, it } from 'vitest';
import { buildIdempotencyKey } from '../../packages/types/src/IdempotencyKey.js';

describe('IdempotencyKey', () => {
  it('gera a mesma chave para as mesmas partes', () => {
    const a = buildIdempotencyKey(['ERP_CONTABIL', 'abc-123']);
    const b = buildIdempotencyKey(['ERP_CONTABIL', 'abc-123']);
    expect(a).toBe(b);
  });

  it('gera chaves diferentes para partes diferentes', () => {
    const a = buildIdempotencyKey(['ERP_CONTABIL', 'abc-123']);
    const b = buildIdempotencyKey(['ERP_CONTABIL', 'abc-124']);
    expect(a).not.toBe(b);
  });

  it('rejeita chamada sem partes', () => {
    expect(() => buildIdempotencyKey([])).toThrow(TypeError);
  });
});
