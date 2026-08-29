import type { ERPAdapter } from './ERPAdapter.js';

/**
 * Registra e resolve adapters por uma chave técnica `string` genérica — não o enum canônico
 * `sistema_origem` (DST-E010), para não acoplar o Gateway ao enum de domínio.
 *
 * Sem persistência, sem import de @contifisc/core, sem dependência de Neon/Postgres/ERP concreto.
 */
export class IntegrationGateway<TRaw, TNormalized> {
  private readonly adapters = new Map<string, ERPAdapter<TRaw, TNormalized>>();

  register(key: string, adapter: ERPAdapter<TRaw, TNormalized>): void {
    if (this.adapters.has(key)) {
      throw new Error(`Já existe um adapter registrado para a chave "${key}".`);
    }
    this.adapters.set(key, adapter);
  }

  resolve(key: string): ERPAdapter<TRaw, TNormalized> {
    const adapter = this.adapters.get(key);
    if (!adapter) {
      throw new Error(`Nenhum adapter registrado para a chave "${key}".`);
    }
    return adapter;
  }

  normalize(key: string, raw: TRaw): TNormalized {
    return this.resolve(key).normalize(raw);
  }
}
