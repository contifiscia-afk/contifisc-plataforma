# CDC-001 — Contrato Canônico de Dados da CONTIFISC

**Versão:** 1.0  
**Status:** Documento Fundador — V1 para implementação paralela  
**Dependências:** CAF-001, MCD-001 v1.0  
**Próximos consumidores:** DST-001, COT-001, ATI-001, GTI-001, MIT-001, APIs, eventos, integrações e Skills  

> **Função do CDC:** transformar o vocabulário do MCD em contratos de entrada, saída, validação, mutabilidade, compatibilidade e proveniência. O CDC não cria regra tributária; ele estabelece as fronteiras técnicas pelas quais dados entram, circulam e saem da plataforma.

## 1. Princípios obrigatórios
- **Contract-first:** APIs, eventos, DTOs e integrações são derivados dos contratos, não o contrário.
- **Vendor-neutral:** nenhum contrato canônico contém nomes ou estruturas específicas de Questor ou outro ERP.
- **Backward compatibility:** alterações compatíveis evoluem por versão minor; quebras exigem versão major e migração.
- **Fact vs derived:** fatos importados/manuais não podem ser sobrescritos por classificações, projeções ou cálculos.
- **Provenance by default:** todo dado externo mantém origem e identificador externo quando disponíveis.
- **Temporal awareness:** competência, emissão, vigência e registro são conceitos distintos.
- **Human review:** resultados de IA ou regras com revisão obrigatória mantêm status e evidência.
- **No silent conflict resolution:** divergências entre fontes são registradas e reconciliadas, nunca apagadas silenciosamente.

## 2. Tipos de campo no contrato
| Classificação | Significado | Regra |
|---|---|---|
| required | Obrigatório naquela operação | Ausência gera erro de validação. |
| conditional | Obrigatório se condição do objeto/operação for atendida | Condição deve ser explícita no contrato específico. |
| optional | Opcional | Ausência não pode ser convertida automaticamente em zero/string vazia. |
| input | Aceito na entrada | Sujeito a validação e normalização. |
| output | Produzido/devolvido | Não implica que o cliente possa alterá-lo. |
| input/output | Aceito e devolvido | Mutabilidade depende da política do campo. |

## 3. Políticas de mutabilidade
| Política | Uso |
|---|---|
| immutable | Criado uma vez e não alterado. |
| immutable_fact | Fato de origem; correções geram nova versão/ajuste, não sobrescrita silenciosa. |
| mutable | Pode ser atualizado com auditoria. |
| temporal | Alteração cria vigência/histórico. |
| reviewable | Pode ser classificado/revisado preservando histórico. |
| versioned_result | Resultado calculado/classificado ligado às versões de regra e inputs. |
| restricted | Alteração exige validação reforçada por ser identificador sensível/cadastral. |

## 4. Envelope canônico
Todo objeto trafegado entre integrações e núcleo deve poder ser envolvido por metadados padronizados.

```yaml
canonical_envelope:
  contract_id: CDC-REC-001
  contract_version: 1.0.0
  record_id: <uuid>
  economic_unit_id: <uuid|null>
  subject_id: <uuid|null>
  occurred_at: <timestamp|null>
  competence: <YYYY-MM|null>
  source:
    system: <canonical_source_code>
    external_record_id: <string|null>
    imported_at: <timestamp|null>
    raw_document_id: <uuid|null>
  quality:
    status: <canonical_quality_status>
  correlation_id: <uuid>
  payload: {}
```

**Nota:** alguns campos do envelope ainda não existem como campos MCD próprios. Eles são definidos aqui como requisitos contratuais transversais e deverão ser reconciliados com COT/MCD antes da implementação física definitiva. O Claude não deve criar campos persistentes novos sem registrar a extensão do MCD.

## 5. Regras gerais de validação
- CPF/CNPJ: persistir somente dígitos; validar tamanho e dígitos verificadores antes de marcar como válido.
- Dinheiro: decimal exato; escala mínima de 2 casas; nunca `float`.
- Percentual: usar a convenção do MCD (32,0000 = 32%) e validar faixa aplicável.
- Competência: normalizar internamente como mês de referência; não inferir competência apenas pela emissão sem regra.
- Timestamp: persistência em UTC; apresentação no fuso do usuário.
- Enums: aceitar apenas códigos publicados pelo DST/CDC; descrições livres não substituem códigos.
- UUID: IDs internos gerados pela plataforma; identificadores externos ficam em campos de origem.
- `null`, zero, string vazia e 'não aplicável' não são equivalentes.
- Dados pessoais em logs: registrar IDs e metadados suficientes para diagnóstico, evitando CPF/CNPJ/nome quando desnecessários.

## 6. Erros contratuais
| Código | Categoria | Uso |
|---|---|---|
| CDC-ERR-001 | VALIDATION_REQUIRED | Campo obrigatório ausente. |
| CDC-ERR-002 | VALIDATION_FORMAT | Formato inválido. |
| CDC-ERR-003 | VALIDATION_RANGE | Valor fora da faixa permitida. |
| CDC-ERR-004 | ENUM_UNKNOWN | Código de enum não reconhecido. |
| CDC-ERR-005 | CONTRACT_VERSION | Versão de contrato incompatível. |
| CDC-ERR-006 | DUPLICATE_SOURCE_RECORD | Registro externo potencialmente duplicado. |
| CDC-ERR-007 | SOURCE_CONFLICT | Fontes apresentam fatos divergentes. |
| CDC-ERR-008 | IMMUTABLE_FIELD | Tentativa de sobrescrever fato/ID imutável. |
| CDC-ERR-009 | MCD_FIELD_UNKNOWN | Campo não registrado no MCD. |
| CDC-ERR-010 | REVIEW_REQUIRED | Resultado exige validação técnica/humana. |

## 7. Contratos canônicos V1

### CDC-UE-001 — Unidade Econômica

**Domínio:** `DOM-CORE`  
**Versão:** `1.0.0`  
**Identidade:** `id_unidade_economica`  
**Objetivo:** Representar o contexto econômico/tributário agregador sem substituir CPF ou CNPJ.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_unidade_economica | MCD-F0001 | output | required | system | immutable |
| nm_unidade_economica | MCD-F0002 | input/output | required | manual | mutable |
| st_registro | MCD-F0003 | input/output | required | system/manual | mutable |
| dt_criacao | MCD-F0004 | output | required | system | immutable |
| dt_atualizacao | MCD-F0005 | output | required | system | mutable |

Regras:
- A UE é contexto organizador interno; não é sujeito tributário.
- CPF e CNPJ podem ser vinculados por relacionamentos com vigência.
- Exclusão física é proibida quando houver fatos tributários vinculados; usar inativação.

### CDC-PER-001 — Pessoa Física

**Domínio:** `DOM-PER`  
**Versão:** `1.0.0`  
**Identidade:** `id_pessoa`  
**Objetivo:** Representar pessoa física, profissional da saúde, sócio, dependente ou outro papel.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_pessoa | MCD-F1001 | output | required | system | immutable |
| nr_cpf | MCD-F1002 | input/output | conditional | manual/import | restricted |
| nm_pessoa | MCD-F1003 | input/output | required | manual/import | mutable |
| dt_nascimento | MCD-F1004 | input/output | optional | manual/import | mutable |
| cd_conselho_profissional | MCD-F1005 | input/output | optional | manual | mutable |
| nr_registro_profissional | MCD-F1006 | input/output | optional | manual | mutable |
| sg_uf_registro_profissional | MCD-F1007 | input/output | optional | manual | mutable |
| cd_especialidade_saude | MCD-F1008 | input/output | optional | manual | mutable |

Regras:
- CPF, quando informado, deve ser normalizado para 11 dígitos e validado.
- Dados profissionais são atributos condicionais; nem toda Pessoa Física é profissional da saúde.
- Identidade de login/autenticação não deve ser confundida com Pessoa Física tributária.

### CDC-EMP-001 — Empresa

**Domínio:** `DOM-EMP`  
**Versão:** `1.0.0`  
**Identidade:** `id_empresa`  
**Objetivo:** Representar pessoa jurídica e atributos cadastrais necessários aos módulos tributários.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_empresa | MCD-F2001 | output | required | system | immutable |
| nr_cnpj | MCD-F2002 | input/output | conditional | manual/import | restricted |
| nm_razao_social | MCD-F2003 | input/output | optional | manual/import | mutable |
| cd_regime_tributario | MCD-F2004 | input/output | conditional | manual/import | temporal |
| cd_cnae_principal | MCD-F2005 | input/output | optional | manual/import | temporal |
| dt_abertura_empresa | MCD-F2006 | input/output | optional | manual/import | mutable |
| cd_municipio_ibge | MCD-F2007 | input/output | optional | manual/import | temporal |

Regras:
- Regime tributário e CNAE são temporalmente sensíveis; mudanças devem preservar vigência/histórico.
- CNPJ não é chave primária interna.
- O mesmo CNPJ não deve gerar empresas duplicadas no mesmo tenant/contexto sem regra explícita de consolidação.

### CDC-REL-001 — Relacionamento Econômico/Tributário

**Domínio:** `DOM-REL`  
**Versão:** `1.0.0`  
**Identidade:** `id_relacionamento`  
**Objetivo:** Representar vínculos entre pessoas, empresas e Unidade Econômica com papel e vigência.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_relacionamento | MCD-F2501 | output | required | system | immutable |
| tp_relacionamento | MCD-F2502 | input/output | required | manual/import | temporal |
| pc_participacao_societaria | MCD-F2503 | input/output | optional | manual/import | temporal |
| dt_inicio_vinculo | MCD-F2504 | input/output | optional | manual/import | temporal |
| dt_fim_vinculo | MCD-F2505 | input/output | optional | manual/import | temporal |

Regras:
- Relacionamentos são objetos de primeira classe, não simples foreign keys.
- Participação societária só é aplicável a vínculos societários.
- O contrato físico futuro deve incluir origem e destino do vínculo; os IDs específicos serão adicionados ao MCD quando COT formalizar os objetos.

### CDC-REC-001 — Receita Canônica

**Domínio:** `DOM-REC`  
**Versão:** `1.0.0`  
**Identidade:** `id_receita`  
**Objetivo:** Normalizar receitas de PJ/PF para uso fiscal, EqHop, IRPF, planejamento e dashboards.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_receita | MCD-F3001 | output | required | system | immutable |
| vl_receita_bruta | MCD-F3002 | input/output | conditional | import/manual | immutable_fact |
| dt_emissao | MCD-F3003 | input/output | optional | import/manual | immutable_fact |
| dt_competencia | MCD-F3004 | input/output | conditional | import/manual | immutable_fact |
| cd_fonte_receita | MCD-F3005 | input/output | conditional | classification/manual | reviewable |
| tp_titular_receita | MCD-F3006 | input/output | conditional | system/classification | reviewable |
| id_fonte_pagadora | MCD-F3007 | input/output | optional | import/manual | reviewable |
| vl_retencoes | MCD-F3008 | input/output | optional | import/manual | immutable_fact |

Regras:
- Valor monetário deve ser >= 0 no contrato padrão; estornos/cancelamentos serão modelados por evento/status, não por valor negativo sem regra.
- Competência não é sinônimo de emissão ou pagamento.
- Uma receita original não pode ser sobrescrita por uma classificação derivada.

### CDC-FIS-001 — Documento Fiscal

**Domínio:** `DOM-FIS`  
**Versão:** `1.0.0`  
**Identidade:** `id_documento_fiscal`  
**Objetivo:** Representar NFS-e, NF-e e outros documentos fiscais sem depender do layout do emissor/ERP.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_documento_fiscal | MCD-F4001 | output | required | system | immutable |
| tp_documento_fiscal | MCD-F4002 | input/output | required | parser/manual | immutable_fact |
| nr_documento_fiscal | MCD-F4003 | input/output | optional | parser/manual | immutable_fact |
| ch_documento_fiscal | MCD-F4004 | input/output | optional | parser/api | immutable_fact |
| cd_servico_fiscal | MCD-F4005 | input/output | optional | parser/api | immutable_fact |
| ds_servico_fiscal | MCD-F4006 | input/output | optional | parser/api | immutable_fact |
| vl_documento_fiscal | MCD-F4007 | input/output | optional | parser/api | immutable_fact |
| id_arquivo_origem | MCD-F4008 | input/output | optional | system | immutable |

Regras:
- O documento bruto deve ser preservado ou referenciado quando disponível.
- Chaves externas podem variar por tipo de documento; não assumir unicidade universal sem tipo/emissor/contexto.
- Parser deve preservar o valor original e registrar transformação/normalização.

### CDC-EH-001 — Classificação de Equiparação Hospitalar

**Domínio:** `DOM-EH`  
**Versão:** `1.0.0`  
**Identidade:** `resultado_classificacao_eh (objeto a formalizar no COT)`  
**Objetivo:** Registrar resultado derivado de elegibilidade/segregação com rastreabilidade e revisão humana.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| st_elegibilidade_eh | MCD-F5001 | output | conditional | rule_engine/reviewer | versioned_result |
| pc_receita_elegivel_eh | MCD-F5002 | output | optional | rule_engine/reviewer | versioned_result |
| vl_receita_elegivel_eh | MCD-F5003 | output | optional | calculation | versioned_result |
| vl_receita_nao_elegivel_eh | MCD-F5004 | output | optional | calculation | versioned_result |
| pc_confianca_classificacao | MCD-F5005 | output | optional | classifier | versioned_result |
| fl_validacao_tecnica | MCD-F5006 | input/output | optional | reviewer | versioned_result |

Regras:
- NFS-e/CNAE/código de serviço isoladamente não determinam elegibilidade.
- Resultado deve registrar versão da regra, evidências e inputs utilizados no COT/RGT futuro.
- IA pode sugerir classificação; decisão tributária definitiva deve seguir regra aprovada e pontos de revisão definidos.

### CDC-PRE-001 — Contribuição Previdenciária

**Domínio:** `DOM-PRE`  
**Versão:** `1.0.0`  
**Identidade:** `id_contribuicao_previdenciaria`  
**Objetivo:** Normalizar contribuições por pessoa, vínculo e competência para análise previdenciária.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_contribuicao_previdenciaria | MCD-F6001 | output | required | system | immutable |
| vl_inss_recolhido | MCD-F6002 | input/output | conditional | cnis/payroll/manual | immutable_fact |
| vl_salario_contribuicao | MCD-F6003 | input/output | optional | cnis/payroll | immutable_fact |
| vl_teto_previdenciario | MCD-F6004 | output | conditional | legal_table | versioned_reference |
| vl_excedente_inss | MCD-F6005 | output | optional | calculation | versioned_result |
| id_vinculo_previdenciario | MCD-F6006 | input/output | optional | cnis/manual | temporal |

Regras:
- Múltiplas fontes na mesma competência devem coexistir e ser reconciliadas.
- CNIS não deve sobrescrever silenciosamente folha/pró-labore; divergências são registradas.
- Teto e cálculo devem ser reproduzíveis pela versão da tabela/regra aplicável à competência.

### CDC-IRP-001 — Evento de IRPF/Carnê-Leão

**Domínio:** `DOM-IRP`  
**Versão:** `1.0.0`  
**Identidade:** `id_evento_irpf`  
**Objetivo:** Normalizar fatos e resultados relevantes ao IRPF de forma independente de uma PJ.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_evento_irpf | MCD-F7001 | output | required | system | immutable |
| tp_rendimento_irpf | MCD-F7002 | input/output | conditional | classification/manual | reviewable |
| vl_rendimento_tributavel | MCD-F7003 | input/output | optional | import/manual | immutable_fact |
| vl_rendimento_isento | MCD-F7004 | input/output | optional | import/manual | immutable_fact |
| vl_deducao_irpf | MCD-F7005 | input/output | optional | import/manual | reviewable |
| vl_livro_caixa | MCD-F7006 | input/output | optional | carne/manual | reviewable |
| vl_irpf_retido | MCD-F7007 | input/output | optional | informe | immutable_fact |
| vl_irpf_projetado | MCD-F7008 | output | optional | calculation | versioned_result |

Regras:
- Rendimento tributável, isento e retenção são conceitos distintos e não mutuamente substituíveis.
- Projeções nunca sobrescrevem fatos declarados/importados.
- A classificação tributária deve manter origem, evidência e versão de regra.

### CDC-PLN-001 — Cenário Tributário

**Domínio:** `DOM-PLN`  
**Versão:** `1.0.0`  
**Identidade:** `id_cenario_tributario`  
**Objetivo:** Representar simulações sem alterar fatos oficiais.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| id_cenario_tributario | MCD-F8001 | output | required | system | immutable |
| nm_cenario_tributario | MCD-F8002 | input/output | required | manual/system | mutable |
| vl_carga_tributaria_projetada | MCD-F8003 | output | optional | calculation | versioned_result |
| vl_economia_tributaria_projetada | MCD-F8004 | output | optional | calculation | versioned_result |

Regras:
- Cenário é sandbox: nunca modifica fatos oficiais.
- Resultado deve registrar premissas, inputs e versões de regras.
- Comparações exigem mesma base temporal ou aviso explícito.

### CDC-SYS-001 — Envelope de Proveniência

**Domínio:** `DOM-SYS`  
**Versão:** `1.0.0`  
**Identidade:** `metadados transversais`  
**Objetivo:** Padronizar metadados de origem, qualidade, versão e auditoria para fatos canônicos.

| Campo | MCD | Direção | Obrigatoriedade | Produtor típico | Mutabilidade |
|---|---|---|---|---|---|
| cd_sistema_origem | MCD-F9001 | input/output | required | gateway/system | immutable_fact |
| id_registro_origem | MCD-F9002 | input/output | optional | gateway | immutable_fact |
| dt_importacao | MCD-F9003 | output | optional | gateway | immutable |
| st_qualidade_dado | MCD-F9004 | input/output | optional | validator/reviewer | versioned_state |
| nr_versao_schema | MCD-F9005 | input/output | required | system | immutable_fact |
| id_evento_auditoria | MCD-F9006 | output | optional | system | immutable |

Regras:
- Todo payload de integração deve indicar versão de schema.
- Proveniência não deve ser removida em transformações posteriores.
- Logs não devem expor dados pessoais desnecessários.

## 8. Regras de reconciliação entre fontes
- Não existe uma prioridade global única de fontes. A autoridade depende do domínio, fato e competência.
- XML/documento fiscal pode ser fonte documental do documento; ERP pode ser fonte operacional; CNIS pode ser fonte previdenciária oficial; banco pode ser fonte de movimentação financeira. O CDC não presume que uma fonte sempre vence outra.
- Quando duas fontes descrevem o mesmo fato e divergem, criar ocorrência de conflito com referências às duas origens.
- Correção manual deve registrar usuário/responsável, justificativa, data e fato substituído/superseded; não apagar o original.
- Regras específicas de precedência serão definidas por domínio nos contratos futuros e no COT/RGT.

## 9. Idempotência e deduplicação
- Integrações devem aceitar reprocessamento sem duplicar fatos.
- Preferir chave de idempotência composta por `sistema_origem + id_registro_origem + versão/identidade documental` quando disponível.
- Quando não houver ID externo confiável, usar fingerprint/hash do documento ou conjunto de campos, sempre mantendo possibilidade de revisão.
- Deduplicação automática com baixa confiança deve sinalizar `DUPLICATE_SOURCE_RECORD`, não excluir registro.

## 10. Versionamento dos contratos
```text
1.0.0 -> contrato inicial
1.1.0 -> novo campo opcional / enum compatível
1.1.1 -> correção documental sem mudança semântica
2.0.0 -> remoção, mudança de significado/tipo ou obrigatoriedade incompatível
```

Clientes/Skills devem declarar a versão consumida. Durante migrações, duas versões podem coexistir. A versão de contrato usada em cálculos ou importações deve ser auditável.

## 11. Contratos de evento — padrão mínimo
O catálogo completo ficará no EVT-001, mas todo evento futuro deve obedecer a este envelope:

```yaml
event:
  event_id: <uuid>
  event_type: <namespace.action>
  event_version: 1.0.0
  occurred_at: <timestamp>
  recorded_at: <timestamp>
  correlation_id: <uuid>
  causation_id: <uuid|null>
  economic_unit_id: <uuid|null>
  subject_id: <uuid|null>
  contract_id: <CDC-...>
  contract_version: <semver>
  payload: {}
```

Eventos são notificações de fatos/alterações relevantes; não substituem a base canônica autoritativa. Consumidores devem ser idempotentes.

## 12. Contrato de cálculo/resultado
Todo cálculo tributário, previdenciário ou projeção deverá ser reproduzível.

```yaml
calculation_result:
  calculation_id: <uuid>
  engine_id: <string>
  engine_version: <semver>
  rule_set_id: <string>
  rule_set_version: <semver>
  competence: <YYYY-MM|period>
  input_snapshot_hash: <hash>
  calculated_at: <timestamp>
  review_status: <status>
  result: {}
```

## 13. Regras para IA e extração documental
- Documento bruto -> extração -> dado candidato -> validação -> fato canônico. Pular etapas é proibido para fatos críticos.
- Extração por IA deve registrar modelo/parser, versão, confiança e referência ao documento de origem quando disponível.
- Confiança de IA não equivale a validade jurídica ou tributária.
- Dados classificados automaticamente podem exigir revisão humana conforme a Skill.
- Motor determinístico deve executar cálculos tributários; LLM pode explicar, extrair ou sugerir classificação, mas não inventar regra legal.

## 14. Segurança e multi-tenancy — requisitos contratuais
- Todo acesso a objeto canônico deve estar contextualizado por tenant/organização e autorização.
- UE não substitui tenant; é entidade de negócio dentro do contexto autorizado.
- CPF, CNPJ e dados fiscais são minimizados em logs e mensagens de erro.
- Operações de override/revisão exigem trilha de auditoria.
- Contratos não devem expor campos sensíveis por padrão; respostas devem ser definidas por necessidade do consumidor.

## 15. Política operacional para Claude Code
```yaml
cdc_policy:
  contract_first: true
  source_of_truth:
    - docs/02-Data/MCD-001.md
    - docs/02-Data/CDC-001.md
  allow_unregistered_payload_field: false
  allow_breaking_change_without_major_version: false
  preserve_raw_source: true
  preserve_provenance: true
  preserve_history: true
  calculations_are_reproducible: true
  events_are_idempotent: true
  external_vendor_schema_in_domain: false
```

Ao detectar necessidade de campo não previsto, o Claude deve gerar uma proposta `MCD-CHANGE-REQUEST` contendo: conceito, domínio, nome sugerido, tipo, origem, consumidores, justificativa, impacto e contrato que motivou a mudança. A implementação funcional aguarda aprovação.

## 16. Critérios de aceite do CDC-001 V1
- [ ] Todos os contratos V1 referenciam campos existentes no MCD, exceto metadados transversais explicitamente marcados para futura formalização.
- [ ] Entrada, saída, obrigatoriedade e mutabilidade estão separadas.
- [ ] Fatos, resultados derivados e cenários não se sobrescrevem.
- [ ] Proveniência, conflito e reconciliação estão previstos.
- [ ] Troca de ERP não exige alteração dos contratos canônicos.
- [ ] Contratos suportam IRPF/Carnê-Leão e INSS sem CNPJ.
- [ ] EqHop preserva receita original e exige rastreabilidade de classificação.
- [ ] Versionamento e compatibilidade estão definidos.
- [ ] Eventos e cálculos possuem envelopes mínimos reproduzíveis.
- [ ] Claude Code possui política explícita para impedir deriva de schema.

## 17. Pendências deliberadas para os próximos documentos
- **DST-001:** códigos e significado oficial dos enums/status/tipos.
- **COT-001:** objetos, cardinalidades, relacionamentos, ownership semântico e ciclo de vida.
- **RGT-001:** regras legais/tributárias versionadas e vigências.
- **EVT-001:** catálogo completo de eventos.
- **INT-001:** adaptadores, mapeamentos e contratos de integração por fonte.
- **SEC-001/OBS-001:** autorização, auditoria, retenção, observabilidade e tratamento detalhado de dados sensíveis.

## 18. Próximo documento
**DST-001 — Dicionário Semântico Tributário.** Antes de formalizar os objetos no COT, o DST deverá congelar o significado dos termos e códigos usados pelos contratos: regime tributário, fonte de receita, titularidade PJ/PF, status de qualidade, elegibilidade EqHop, tipos de relacionamento, natureza de rendimento e demais enums essenciais.

---
**Decisão de governança:** CDC define a interface estável entre dados e software. Skills podem evoluir internamente, mas não podem quebrar contratos compartilhados sem versionamento formal.