import { describe, expect, it } from 'vitest';
import { assertUuid, generateUuid, isUuid } from '../../packages/types/src/Uuid.js';

describe('Uuid', () => {
  it('aceita um UUID v4 válido', () => {
    expect(isUuid('123e4567-e89b-42d3-a456-426614174000')).toBe(true);
  });

  it('rejeita string que não é UUID v4', () => {
    expect(isUuid('not-a-uuid')).toBe(false);
    expect(() => assertUuid('not-a-uuid')).toThrow(TypeError);
  });

  it('gera um UUID v4 válido', () => {
    const id = generateUuid();
    expect(isUuid(id)).toBe(true);
  });
});
