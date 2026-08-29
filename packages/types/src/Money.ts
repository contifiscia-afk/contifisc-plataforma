/**
 * Value Object de dinheiro. MCD-001 V1.1 §4: dinheiro é Decimal, NUMERIC(18,2), float proibido.
 * Armazenamento interno em bigint escalado (centavos) — nunca `number` do JS.
 * Não expõe valueOf/toPrimitive numérico: conversão para number exige chamada explícita e é sempre perdedora de precisão para valores fora de Number.isSafeInteger.
 */
const SCALE = 2;
const SCALE_FACTOR = 10n ** BigInt(SCALE);
const DECIMAL_STRING_REGEX = /^-?\d+(\.\d{1,2})?$/;

export class Money {
  private readonly cents: bigint;

  private constructor(cents: bigint) {
    this.cents = cents;
  }

  static fromString(value: string): Money {
    if (!DECIMAL_STRING_REGEX.test(value)) {
      throw new TypeError(`Valor monetário inválido (esperado decimal exato): ${value}`);
    }
    const negative = value.startsWith('-');
    const unsigned = negative ? value.slice(1) : value;
    const [whole = '0', fraction = ''] = unsigned.split('.');
    const paddedFraction = fraction.padEnd(SCALE, '0');
    const cents = BigInt(whole) * SCALE_FACTOR + BigInt(paddedFraction || '0');
    return new Money(negative ? -cents : cents);
  }

  static zero(): Money {
    return new Money(0n);
  }

  add(other: Money): Money {
    return new Money(this.cents + other.cents);
  }

  subtract(other: Money): Money {
    return new Money(this.cents - other.cents);
  }

  compareTo(other: Money): -1 | 0 | 1 {
    if (this.cents === other.cents) return 0;
    return this.cents > other.cents ? 1 : -1;
  }

  equals(other: Money): boolean {
    return this.cents === other.cents;
  }

  isNegative(): boolean {
    return this.cents < 0n;
  }

  toString(): string {
    const negative = this.cents < 0n;
    const abs = negative ? -this.cents : this.cents;
    const whole = abs / SCALE_FACTOR;
    const fraction = (abs % SCALE_FACTOR).toString().padStart(SCALE, '0');
    return `${negative ? '-' : ''}${whole}.${fraction}`;
  }

  /** Bloqueia `Number(money)`/aritmética implícita — só `toString()` explícito é permitido. */
  [Symbol.toPrimitive](hint: 'number' | 'string' | 'default'): string {
    if (hint === 'number') {
      throw new TypeError('Money não permite conversão implícita para number.');
    }
    return this.toString();
  }
}
