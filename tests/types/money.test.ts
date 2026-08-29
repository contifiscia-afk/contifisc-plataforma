import { describe, expect, it } from 'vitest';
import { Money } from '../../packages/types/src/Money.js';

describe('Money', () => {
  it('soma dois valores com precisão exata', () => {
    const a = Money.fromString('10.10');
    const b = Money.fromString('0.20');
    expect(a.add(b).toString()).toBe('10.30');
  });

  it('compara valores corretamente', () => {
    const a = Money.fromString('10.00');
    const b = Money.fromString('9.99');
    expect(a.compareTo(b)).toBe(1);
    expect(b.compareTo(a)).toBe(-1);
    expect(a.compareTo(Money.fromString('10.00'))).toBe(0);
  });

  it('rejeita entrada não decimal exata (ex.: notação científica ou float impreciso)', () => {
    expect(() => Money.fromString('1e10')).toThrow(TypeError);
    expect(() => Money.fromString('10.001')).toThrow(TypeError);
  });

  it('não expõe conversão implícita para number', () => {
    const value = Money.fromString('10.30');
    expect(() => Number(value)).toThrow(TypeError);
    expect(() => +value).toThrow(TypeError);
  });

  it('permite conversão explícita para string (não numérica)', () => {
    const value = Money.fromString('10.30');
    expect(`${value}`).toBe('10.30');
  });
});
