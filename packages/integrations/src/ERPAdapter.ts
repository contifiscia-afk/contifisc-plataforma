/**
 * Gateway de Integração — CAF-001 objetivo 5 / MCD-001 V1.1 §17 / CDC-001 V1.1 §17.
 *
 * Interface genérica, sem shape de negócio fixado. `TNormalized` é livre porque nenhum
 * objeto COT com FK obrigatória (Receita, Vinculo, DocumentoFiscal, etc.) está implementado
 * nesta Fase 1 — fixar um shape aqui equivaleria a inventar um contrato antes do MCD/CDC.
 *
 * Nenhum adapter concreto (Questor ou outro) é implementado aqui.
 */
export interface ERPAdapter<TRaw, TNormalized> {
  readonly nome: string;
  normalize(raw: TRaw): TNormalized;
}
