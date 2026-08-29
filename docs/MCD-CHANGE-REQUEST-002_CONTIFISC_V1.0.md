# MCD-CHANGE-REQUEST-002 — Integridade Relacional e Consistência Estrutural

**Versão:** 1.0  
**Status:** APROVADO — incorporado ao MCD-001 V1.2 e ao CDC-001 V1.2  
**Documento-alvo:** MCD-001 V1.1  
**Versão resultante:** MCD-001 V1.2 — baseline schema-ready pré-implementação  
**Dependências:** CAF-001, COT-001, MCD-001 V1.1, CDC-001 V1.1, DST-001 V1.1  
**Origem:** gaps formais CDC-001 V1.1 + revisão de integridade relacional do MCD V1.1

> Este Change Request não cria schema Prisma nem migration. Ele corrige o modelo canônico antes da primeira materialização física.

## 1. Objetivo
Eliminar fragilidades que ainda impedem considerar o MCD V1.1 pronto para desenho físico: FKs polimórficas em fatos centrais, relações N:N sem estrutura, ausência de identidade EqHop, conflito sem itens participantes e mistura entre lifecycle e qualidade do dado.

## 2. Decisão de arquitetura proposta
- Priorizar integridade referencial real em fatos financeiros e vínculos estruturais.
- Não criar um supertipo universal `Parte/SujeitoFiscal` nesta fase; isso alteraria excessivamente o COT e misturaria UE com sujeitos tributários.
- Usar estruturas relacionais de suporte quando a relação COT exige flexibilidade sem justificar novo objeto de negócio.
- Permitir referência polimórfica apenas em domínios de auditoria/observabilidade quando deliberadamente documentada e fora do ownership financeiro central.
- Não adicionar semântica de rateio, alocação ou classificação que ainda não esteja aprovada.
- Manter a primeira migration bloqueada até MCD V1.2 + CDC/DST sincronizados e ADR físico revisado.

## 3. Mudanças propostas
| ID | Área | Ação | Proposta | Justificativa |
|---|---|---|---|---|
| CR2-001 | Receita - titularidade relacional | SUBSTITUIR | `titular_id` + `tipo_titular` por `pessoa_fisica_id` e `pessoa_juridica_id`, ambos opcionais individualmente, com constraint XOR: exatamente um deve estar preenchido. | Elimina FK polimórfica em fato financeiro central e restaura integridade referencial. |
| CR2-002 | Vinculo - extremidades relacionais | SUBSTITUIR | `objeto_origem_id/tipo_objeto_origem` e `objeto_destino_id/tipo_objeto_destino` por estrutura relacional de suporte `VinculoExtremidade`, com duas extremidades por vínculo (`ORIGEM`, `DESTINO`) e exatamente uma FK preenchida entre UE/PF/PJ. | Mantém flexibilidade do COT sem perder FKs reais; evita supertipo artificial. |
| CR2-003 | Receita x DocumentoFiscal | ADICIONAR | Estrutura associativa `ReceitaDocumentoFiscal` com `id`, `receita_id`, `documento_fiscal_id`, timestamps técnicos e unicidade do par. Não adicionar rateio/percentual sem regra aprovada. | Materializa a relação N:N já prevista no COT sem inventar semântica financeira. |
| CR2-004 | DocumentoFiscal x ArquivoOrigem | SUBSTITUIR | Retirar `DocumentoFiscal.arquivo_origem_id` como vínculo único e criar `DocumentoFiscalArquivoOrigem` N:N (`id`, `documento_fiscal_id`, `arquivo_origem_id`, `papel_arquivo` opcional/aberto até DST). | Um documento pode ter XML/PDF/capturas/versões de evidência; um arquivo pode conter lote/mais de um documento. |
| CR2-005 | EqHop - identidade própria | ADICIONAR | Adicionar `ClassificacaoEquiparacaoHospitalar.id` (UUID) e timestamps de registro. Manter `receita_id` e `regra_versao_id`. | COT define a classificação como objeto versionado; sem identidade própria não há histórico/revisão robustos. |
| CR2-006 | ConflitoDado - itens envolvidos | ADICIONAR | Criar estrutura de suporte `ConflitoDadoItem` com `id`, `conflito_dado_id`, `tipo_objeto`, `objeto_id`, `sistema_origem`, `identificador_origem`, `papel_no_conflito`, `valor_hash` opcional. | Permite registrar os registros/fontes efetivamente conflitantes sem apagar evidências. |
| CR2-007 | Status de dado - separar processo e qualidade | SUBSTITUIR | Renomear o conceito atual `status_qualidade_dado` (IMPORTADO/VALIDADO/RECONCILIADO/OVERRIDDEN/SUPERSEDED/CANCELADO) para `status_processamento_dado`; criar novo `status_qualidade_dado` com semântica de qualidade independente. | Evita misturar workflow/lifecycle com qualidade intrínseca do dado. |
| CR2-008 | PessoaFisica MCD-F1005 - correção editorial | CORRIGIR | Corrigir a linha de `conselho_profissional`: Significado='Conselho profissional'; Tipo='Enum/Ref'; Unidade='-'. Sem mudança de nome ou semântica. | Corrige erro de ordenação de colunas no MCD V1.1. |
| CR2-009 | EqHop - booleano de validação | RENOMEAR | Renomear `validacao_tecnica` para `eh_validada_tecnicamente` se mantido como Boolean. Fonte de verdade da revisão continua `RevisaoTecnica`; o booleano é indicador derivado. | Alinha a convenção de booleanos e evita interpretar o indicador como registro de revisão. |
| CR2-010 | ResultadoCalculo x RGT | CLARIFICAR | `rule_set_id`, `rule_set_version` e `regra_versao_id` permanecem identificadores opacos nesta fase, sem FK/schema de regras até RGT-001. | Evita acoplamento prematuro do MCD ao futuro modelo físico de regras. |

## 4. Detalhamento das decisões críticas
### 4.1 Receita: remover titularidade polimórfica
O par `titular_id` + `tipo_titular` é inadequado para um fato financeiro central porque impede FK real no banco. A proposta é substituí-lo por `pessoa_fisica_id` e `pessoa_juridica_id`, com constraint XOR: exatamente um preenchido. `tipo_titular` deixa de ser necessário como fonte de verdade, podendo ser derivado.

**Constraint lógica:** `(pessoa_fisica_id IS NOT NULL) XOR (pessoa_juridica_id IS NOT NULL)`.

### 4.2 Vinculo: preservar flexibilidade sem supertipo artificial
O COT permite vínculos entre UE, PF e PJ. Em vez de seis FKs diretamente em `Vinculo` ou de um supertipo universal, propõe-se `VinculoExtremidade`: cada vínculo possui exatamente duas extremidades, uma `ORIGEM` e uma `DESTINO`; cada extremidade possui exatamente uma FK real preenchida entre UE/PF/PJ.

**Constraints mínimas:** 2 extremidades por vínculo; unicidade `(vinculo_id, lado_extremidade)`; XOR entre as três FKs de endpoint.

### 4.3 Receita x DocumentoFiscal
A relação N:N já existe conceitualmente no COT e deve ser materializada por `ReceitaDocumentoFiscal`. A associação não contém `valor_alocado`, `percentual` ou papel tributário nesta versão, porque isso criaria semântica não aprovada.

### 4.4 DocumentoFiscal x ArquivoOrigem
O campo único `arquivo_origem_id` em DocumentoFiscal é insuficiente para XML, PDF/DANFSe, lote, captura reprocessada e evidência complementar. A proposta é uma associação N:N. `ArquivoOrigem` continua RAW/imutável.

### 4.5 Polimorfismo: exceção controlada
`ConflitoDadoItem.objeto_id` pode permanecer referência genérica porque pertence ao domínio de auditoria/reconciliação, não ao ownership financeiro. Essa exceção deve ser registrada em ADR e validada em aplicação. Para `Receita` e `Vinculo`, polimorfismo sem FK não é aceito.

## 5. Campos/estruturas propostos
| MCD ID | Estrutura | Campo | Tipo | Obrig. | Semântica |
|---|---|---|---|---|---|
| MCD-F3010 | Receita | pessoa_fisica_id | UUID/FK | Condicional XOR | Titular PF; substitui titularidade polimórfica. |
| MCD-F3011 | Receita | pessoa_juridica_id | UUID/FK | Condicional XOR | Titular PJ; substitui titularidade polimórfica. |
| MCD-F2520 | VinculoExtremidade | id | UUID | Sim | PK técnica da extremidade. |
| MCD-F2521 | VinculoExtremidade | vinculo_id | UUID/FK | Sim | Vínculo pai. |
| MCD-F2522 | VinculoExtremidade | lado_extremidade | Enum | Sim | ORIGEM ou DESTINO. |
| MCD-F2523 | VinculoExtremidade | unidade_economica_id | UUID/FK | XOR | Endpoint UE. |
| MCD-F2524 | VinculoExtremidade | pessoa_fisica_id | UUID/FK | XOR | Endpoint PF. |
| MCD-F2525 | VinculoExtremidade | pessoa_juridica_id | UUID/FK | XOR | Endpoint PJ. |
| MCD-F4301 | ReceitaDocumentoFiscal | id | UUID | Sim | PK associativa. |
| MCD-F4302 | ReceitaDocumentoFiscal | receita_id | UUID/FK | Sim | Receita. |
| MCD-F4303 | ReceitaDocumentoFiscal | documento_fiscal_id | UUID/FK | Sim | Documento fiscal. |
| MCD-F4401 | DocumentoFiscalArquivoOrigem | id | UUID | Sim | PK associativa. |
| MCD-F4402 | DocumentoFiscalArquivoOrigem | documento_fiscal_id | UUID/FK | Sim | Documento fiscal. |
| MCD-F4403 | DocumentoFiscalArquivoOrigem | arquivo_origem_id | UUID/FK | Sim | Arquivo RAW/evidência. |
| MCD-F4404 | DocumentoFiscalArquivoOrigem | papel_arquivo | Enum/Ref | Não | Papel da evidência; catálogo DST pendente. |
| MCD-F5009 | ClassificacaoEquiparacaoHospitalar | id | UUID | Sim | Identidade própria. |
| MCD-F5010 | ClassificacaoEquiparacaoHospitalar | registrado_em | TimestampTZ | Sim | Registro do resultado. |
| MCD-F5011 | ClassificacaoEquiparacaoHospitalar | atualizado_em | TimestampTZ | Não | Atualização técnica sem apagar histórico. |
| MCD-F8650 | ConflitoDadoItem | id | UUID | Sim | PK do item. |
| MCD-F8651 | ConflitoDadoItem | conflito_dado_id | UUID/FK | Sim | Conflito pai. |
| MCD-F8652 | ConflitoDadoItem | tipo_objeto | Enum/Ref | Sim | Tipo canônico referenciado; catálogo controlado. |
| MCD-F8653 | ConflitoDadoItem | objeto_id | UUID | Condicional | Referência genérica controlada para domínio de auditoria. |
| MCD-F8654 | ConflitoDadoItem | sistema_origem | Enum/Ref | Não | Origem participante. |
| MCD-F8655 | ConflitoDadoItem | identificador_origem | Texto | Não | ID externo participante. |
| MCD-F8656 | ConflitoDadoItem | papel_no_conflito | Enum/Ref | Não | Candidato, referência, vencedor, descartado etc.; catálogo pendente. |
| MCD-F8657 | ConflitoDadoItem | valor_hash | Texto | Não | Hash opcional para comparação/auditoria. |
| MCD-F9010 | Metadado transversal | status_processamento_dado | Enum | Não | Workflow/lifecycle do dado. |

## 6. Campos removidos/depreciados
| Campo V1.1 | Destino | Motivo |
|---|---|---|
| Receita.titular_id | REMOVIDO em V1.2 | Substituído por FKs explícitas PF/PJ. |
| Receita.tipo_titular | DERIVADO / não persistido como fonte de verdade | Derivável pelas FKs XOR. |
| Vinculo.objeto_origem_id | REMOVIDO | Substituído por VinculoExtremidade. |
| Vinculo.tipo_objeto_origem | REMOVIDO | Derivável pela FK preenchida na extremidade. |
| Vinculo.objeto_destino_id | REMOVIDO | Substituído por VinculoExtremidade. |
| Vinculo.tipo_objeto_destino | REMOVIDO | Derivável pela FK preenchida na extremidade. |
| DocumentoFiscal.arquivo_origem_id | REMOVIDO | Substituído por associação N:N. |
| Metadado.status_qualidade_dado V1.1 | RENOMEADO semanticamente | Valores atuais tornam-se status_processamento_dado. |
| ClassificacaoEqHop.validacao_tecnica | RENOMEADO/DERIVADO | `eh_validada_tecnicamente`; revisão formal permanece RevisaoTecnica. |

## 7. Ajustes necessários no DST
| ID | Enum | Valores | Decisão |
|---|---|---|---|
| DST-E009 | status_processamento_dado | IMPORTADO, VALIDADO, RECONCILIADO, OVERRIDDEN, SUPERSEDED, CANCELADO | Renomeia semanticamente o enum hoje associado a status_qualidade_dado. |
| DST-E011 | status_qualidade_dado | NAO_AVALIADO, VALIDO, INCOMPLETO, DIVERGENTE, SUSPEITO | Novo eixo independente de qualidade. `DIVERGENTE` não substitui ConflitoDado. |
| DST-E012 | lado_extremidade | ORIGEM, DESTINO | Enum técnico-canônico mínimo para VinculoExtremidade. |

O DST-001 V1.1 deverá ser revisado para V1.2 após aprovação deste Change Request. Nenhum código deve implementar DST-E011/DST-E012 antes da aprovação.

## 8. Ajustes necessários no CDC
- `CDC-REC-001`: substituir titularidade polimórfica pelas duas FKs XOR.
- `CDC-REL-001`: trocar endpoints polimórficos por contrato de `VinculoExtremidade`.
- `CDC-FIS-001`: retirar `arquivo_origem_id` direto e adicionar contrato associativo.
- `CDC-EH-001`: identidade deixa de ser PENDENTE-MCD e passa a `id`.
- `CDC-CFD-001`: adicionar contrato para itens do conflito.
- `CDC-SYS-001`: separar `status_processamento_dado` de `status_qualidade_dado`.

## 9. Impacto no COT
Não é proposta a criação de novos objetos tributários de negócio. `VinculoExtremidade`, `ReceitaDocumentoFiscal`, `DocumentoFiscalArquivoOrigem` e `ConflitoDadoItem` são estruturas relacionais de suporte à materialização do COT. O COT deve receber nota/versão de alinhamento deixando isso explícito.

## 10. Gaps que permanecem após CR-002
| Gap | Tema | Tratamento |
|---|---|---|
| GAP-MCD-CR2-001 | VinculoExtremidade e COT | Estrutura é relacional de suporte, não novo objeto tributário. COT deve registrar explicitamente que a relação COT-OBJ-004 pode ser materializada por extremidades técnicas. |
| GAP-MCD-CR2-002 | DocumentoFiscalArquivoOrigem.papel_arquivo | Catálogo DST ainda não existe; campo permanece Enum/Ref aberto ou pode ser omitido na primeira persistência. |
| GAP-MCD-CR2-003 | ConflitoDadoItem.tipo_objeto/papel_no_conflito | Catálogos dependem de OBS/reconciliação; não criar union fechada antes da revisão. |
| GAP-MCD-CR2-004 | Revisor de RevisaoTecnica | Continua fora do MCD tributário até SEC-001/OBS-001. |
| GAP-MCD-CR2-005 | FontePagadora.identificador_fiscal | Validação tipada CPF/CNPJ/Exterior permanece para revisão posterior; não bloqueia schema inicial. |

## 11. Versionamento e exceção pré-implementação
As mudanças incluem renomes e remoções incompatíveis. Em SemVer estrito, isso normalmente exigiria MCD V2.0. Entretanto, **nenhum schema físico/migration de produção foi autorizado ou executado** e V1.1 foi declarado baseline documental da Fase 1. Propõe-se, por exceção de governança, publicar MCD V1.2 como correção pré-implementação. Esta exceção deve ser registrada no changelog. Após a primeira migration, qualquer quebra equivalente exigirá major version.

## 12. Critérios para considerar o MCD V1.2 schema-ready
- [ ] Receita possui titularidade com FK real e XOR validável.
- [ ] Vinculo possui materialização relacional com duas extremidades e FKs reais.
- [ ] Relação Receita-DocumentoFiscal está materializada sem semântica inventada.
- [ ] DocumentoFiscal aceita múltiplas evidências RAW.
- [ ] EqHop possui identidade própria.
- [ ] ConflitoDado referencia participantes/fontes.
- [ ] Processamento/lifecycle e qualidade do dado são conceitos separados.
- [ ] Erro editorial MCD-F1005 está corrigido.
- [ ] CDC e DST correspondentes foram sincronizados.
- [ ] ADR físico define constraints, índices, delete policy e estratégia Prisma/PostgreSQL.
- [ ] Nenhuma migration existe antes da aprovação dos itens acima.

## 13. Efeito sobre a Fase 1 em execução
A Fase 1 atual (infraestrutura genérica, Gateway, Value Objects e interfaces `UnidadeEconomica`, `PessoaFisica`, `PessoaJuridica`) **não é bloqueada** por este Change Request. O CR-002 bloqueia apenas o avanço para `Receita`, `Vinculo`, `DocumentoFiscal`, EqHop, reconciliação persistente e schema físico.

## 14. Instrução para Claude Code enquanto status = PROPOSTO
```yaml
mcd_change_request_002:
  status: PROPOSED
  implement_as_canonical: false
  create_prisma_schema_from_it: false
  create_migration: false
  allowed_current_phase:
    - generic_infrastructure
    - integration_gateway
    - unidade_economica_types
    - pessoa_fisica_types
    - pessoa_juridica_types
  blocked_until_approval:
    - receita
    - vinculo
    - documento_fiscal
    - equiparacao_hospitalar_persistence
    - conflito_dado_persistence
    - prisma_physical_schema
  rule: "Do not infer or pre-implement proposed CR-002 structures."
```

## 15. Decisão solicitada
**Recomendação:** APROVAR o MCD-CHANGE-REQUEST-002 e, em seguida, emitir o **MCD-001 V1.2** incorporando as mudanças. Depois, sincronizar **CDC-001 V1.2** e **DST-001 V1.2** antes da proposta/ADR de schema Prisma.

**Status final:** APROVADO. Incorporado a `MCD-001 V1.2` e `CDC-001 V1.2` (ambos vigentes). Próximo bloqueio documental: `DST-001 V1.2`. Schema físico/migration continuam não autorizados até essa sincronização e o ADR físico.

---
**Governança:** este documento está incorporado ao MCD-001 V1.2 e ao CDC-001 V1.2 — permanece como registro histórico da decisão, não como fonte de verdade isolada.