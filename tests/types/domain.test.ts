import { describe, expect, it } from 'vitest';
import { generateUuid } from '../../packages/types/src/Uuid.js';
import type {
  ConselhoProfissional,
  PessoaFisica,
  PessoaJuridica,
  UnidadeEconomica,
} from '../../packages/types/src/domain.js';

describe('interfaces canônicas da Fase 1', () => {
  it('UnidadeEconomica aceita um objeto com os campos MCD-001 V1.1', () => {
    const ue: UnidadeEconomica = {
      id: generateUuid(),
      nome: 'Clínica Exemplo',
      status_registro: 'ATIVO',
      criado_em: new Date().toISOString(),
      atualizado_em: new Date().toISOString(),
    };
    expect(ue.status_registro).toBe('ATIVO');
  });

  it('PessoaFisica aceita conselho_profissional/especialidade_saude como branded types abertos', () => {
    const conselho = 'CRM' as ConselhoProfissional;
    const pf: PessoaFisica = {
      id: generateUuid(),
      nome: 'Fulano de Tal',
      conselho_profissional: conselho,
    };
    expect(pf.conselho_profissional).toBe('CRM');
  });

  it('PessoaJuridica aceita regime_tributario restrito ao DST-E001', () => {
    const pj: PessoaJuridica = {
      id: generateUuid(),
      regime_tributario: 'LUCRO_PRESUMIDO',
    };
    expect(pj.regime_tributario).toBe('LUCRO_PRESUMIDO');
  });
});
