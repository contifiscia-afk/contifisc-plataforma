/**
 * Utilitário genérico de idempotência (CDC-001 V1.1 §9).
 * Não assume nomes de campo específicos (ex.: sistema_origem/identificador_origem) —
 * apenas compõe e faz hash de partes de string fornecidas pelo chamador.
 */
export type IdempotencyKey = string & { readonly __brand: 'IdempotencyKey' };

function fnv1a(input: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

export function buildIdempotencyKey(parts: readonly string[]): IdempotencyKey {
  if (parts.length === 0) {
    throw new TypeError('IdempotencyKey requer ao menos uma parte.');
  }
  const composite = parts.join('|');
  return fnv1a(composite) as IdempotencyKey;
}
