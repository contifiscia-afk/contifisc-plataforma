const UUID_V4_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type Uuid = string & { readonly __brand: 'Uuid' };

export function isUuid(value: string): value is Uuid {
  return UUID_V4_REGEX.test(value);
}

export function assertUuid(value: string): Uuid {
  if (!isUuid(value)) {
    throw new TypeError(`Valor não é um UUID v4 válido: ${value}`);
  }
  return value;
}

export function generateUuid(): Uuid {
  return crypto.randomUUID() as Uuid;
}
