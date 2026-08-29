/**
 * Interfaces canônicas autorizadas na Fase 1 (MCD-001 V1.1 §17 / CDC-001 V1.1 §17 / DST-001 V1.1 §12).
 * Somente os 3 objetos abaixo. Sem FK/relacionamento embutido — associação é sempre via `Vinculo`
 * (COT-OBJ-004), que ainda depende de campos/enums fora do escopo desta rodada.
 *
 * Nomes de campo são exatamente os do MCD-001 V1.1 (snake_case, sem prefixo de tipo) — não
 * convertidos para camelCase (MCD-001 V1.1 §15: "Types canônicos novos usam os nomes V1.1").
 *
 * Qualquer campo, enum ou objeto adicional exigido por uma implementação futura deve gerar
 * um Change Request, não ser inferido aqui.
 */
import type { Uuid } from './Uuid.js';

/** DST-E008 — status_registro (ciclo de vida cadastral). */
export type StatusRegistro = 'ATIVO' | 'INATIVO' | 'ARQUIVADO';

/** DST-E001 — regime_tributario. */
export type RegimeTributario =
  | 'SIMPLES_NACIONAL'
  | 'LUCRO_PRESUMIDO'
  | 'LUCRO_REAL'
  | 'OUTRO'
  | 'NAO_INFORMADO';

/**
 * DST-GAP-001 — catálogo de conselhos profissionais ainda não aprovado.
 * Tipo opaco/branded aberto: não é união fechada, não deve ser inventada uma lista de códigos.
 */
export type ConselhoProfissional = string & { readonly __brand: 'ConselhoProfissional' };

/**
 * DST-GAP-002 — taxonomia de especialidades da saúde ainda não aprovada.
 * Tipo opaco/branded aberto: não é união fechada, não deve ser inventada uma lista de códigos.
 */
export type EspecialidadeSaude = string & { readonly __brand: 'EspecialidadeSaude' };

/**
 * COT-OBJ-001 -> MCD-F0001..F0005 -> CDC-UE-001 -> DST-T001
 * Unidade Econômica: contexto agregador interno; não é sujeito tributário.
 */
export interface UnidadeEconomica {
  readonly id: Uuid;
  readonly nome: string;
  readonly status_registro: StatusRegistro;
  readonly criado_em: string;
  readonly atualizado_em: string;
}

/**
 * COT-OBJ-002 -> MCD-F1001..F1008 -> CDC-PER-001 -> DST-T002
 * Pessoa Física: identidade tributária. Não é identidade de autenticação (CDC-PER-001, regra).
 */
export interface PessoaFisica {
  readonly id: Uuid;
  readonly cpf?: string;
  readonly nome: string;
  readonly data_nascimento?: string;
  /** DST-GAP-001 — catálogo ainda não formalizado; aguarda revisão DST específica. */
  readonly conselho_profissional?: ConselhoProfissional;
  readonly registro_profissional?: string;
  readonly uf_registro_profissional?: string;
  /** DST-GAP-002 — catálogo ainda não formalizado; aguarda revisão DST específica. */
  readonly especialidade_saude?: EspecialidadeSaude;
}

/**
 * COT-OBJ-003 -> MCD-F2001..F2007 -> CDC-EMP-001 -> DST-T003
 * Pessoa Jurídica: identidade tributária PJ. CNPJ não é PK interna.
 */
export interface PessoaJuridica {
  readonly id: Uuid;
  readonly cnpj?: string;
  readonly razao_social?: string;
  readonly regime_tributario?: RegimeTributario;
  readonly cnae_principal?: string;
  readonly data_abertura?: string;
  readonly municipio_ibge?: string;
}
