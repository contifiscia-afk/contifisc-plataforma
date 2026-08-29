import { describe, expect, it } from 'vitest';
import type { ERPAdapter } from '../../packages/integrations/src/ERPAdapter.js';
import { IntegrationGateway } from '../../packages/integrations/src/IntegrationGateway.js';

interface RawFixture {
  valor: string;
}

interface NormalizedFixture {
  valorNormalizado: string;
}

/** Adapter de teste genérico — não é um adapter oficial do pacote, existe só neste arquivo. */
class FixtureAdapter implements ERPAdapter<RawFixture, NormalizedFixture> {
  readonly nome = 'fixture';

  normalize(raw: RawFixture): NormalizedFixture {
    return { valorNormalizado: raw.valor.trim() };
  }
}

describe('IntegrationGateway', () => {
  it('registra e resolve um adapter pela chave técnica', () => {
    const gateway = new IntegrationGateway<RawFixture, NormalizedFixture>();
    gateway.register('fixture-source', new FixtureAdapter());

    const resolved = gateway.resolve('fixture-source');
    expect(resolved.nome).toBe('fixture');
  });

  it('delega normalize() ao adapter resolvido', () => {
    const gateway = new IntegrationGateway<RawFixture, NormalizedFixture>();
    gateway.register('fixture-source', new FixtureAdapter());

    const result = gateway.normalize('fixture-source', { valor: '  abc  ' });
    expect(result.valorNormalizado).toBe('abc');
  });

  it('rejeita registro duplicado na mesma chave', () => {
    const gateway = new IntegrationGateway<RawFixture, NormalizedFixture>();
    gateway.register('fixture-source', new FixtureAdapter());
    expect(() => gateway.register('fixture-source', new FixtureAdapter())).toThrow();
  });

  it('rejeita resolução de chave não registrada', () => {
    const gateway = new IntegrationGateway<RawFixture, NormalizedFixture>();
    expect(() => gateway.resolve('inexistente')).toThrow();
  });
});
