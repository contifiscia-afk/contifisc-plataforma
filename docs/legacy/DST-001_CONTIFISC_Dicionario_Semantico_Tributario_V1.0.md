# DST-001 — Dicionário Semântico Tributário da CONTIFISC

**Versão:** 1.0  
**Status:** Documento Fundador — V1  
**Dependências:** CAF-001, MCD-001, CDC-001  
**Consumidores:** COT-001, ATI-001, RGT-001, EVT-001, integrações, APIs, Skills e interface

> **Objetivo:** garantir que humanos, Claude Code, banco de dados, APIs e Skills usem o mesmo significado para cada conceito. O DST define semântica e códigos; não define fórmulas tributárias.

## 1. Regras semânticas
- Um termo canônico possui um significado oficial e um ID DST permanente.
- Sinônimos podem existir na interface, mas não podem alterar o significado canônico.
- Enum é código de domínio, não texto livre.
- `NAO_INFORMADO`, `PENDENTE`, `NAO_APLICAVEL` e `OUTRO` têm significados diferentes e não são intercambiáveis.
- Termos legais sujeitos a vigência devem apontar futuramente para regras versionadas no RGT.
- Descrição semântica não autoriza cálculo: lógica tributária somente entra em produção após regra aprovada.
- Claude Code não pode criar novo enum/código sem proposta de alteração do DST.

## 2. Glossário canônico V1
| ID | Termo técnico | Nome humano | Definição oficial | Domínio |
|---|---|---|---|---|
| DST-T001 | unidade_economica | Unidade Econômica | Agrupador interno do ecossistema econômico/tributário de um cliente. Não é sujeito tributário e não substitui CPF ou CNPJ. | DOM-CORE |
| DST-T002 | pessoa_fisica | Pessoa Física | Pessoa natural representada na plataforma, podendo assumir papéis como profissional da saúde, sócio, dependente ou titular de rendimentos. | DOM-PER |
| DST-T003 | empresa | Empresa / Pessoa Jurídica | Pessoa jurídica identificada canonicamente por ID interno e, quando disponível, CNPJ. | DOM-EMP |
| DST-T004 | competencia | Competência | Período mensal ao qual o fato econômico, tributário, previdenciário ou contábil é atribuído. Não é sinônimo de emissão, pagamento ou importação. | Transversal |
| DST-T005 | fato_canonico | Fato Canônico | Registro normalizado que representa um fato de negócio aceito pela camada canônica e mantém origem, tempo e qualidade. | Transversal |
| DST-T006 | dado_derivado | Dado Derivado | Resultado obtido por cálculo, classificação, agregação ou projeção. Nunca substitui silenciosamente o fato de origem. | Transversal |
| DST-T007 | fonte_dado | Fonte de Dados | Sistema, documento, usuário ou processo que originou um dado candidato ou fato canônico. | DOM-SYS |
| DST-T008 | proveniencia | Proveniência | Conjunto de metadados que permite rastrear o dado até sua origem e transformação. | DOM-SYS |
| DST-T009 | reconciliacao | Reconciliação | Processo de comparar fontes potencialmente equivalentes e resolver ou sinalizar divergências sem apagar o histórico. | DOM-SYS |
| DST-T010 | cenario_tributario | Cenário Tributário | Ambiente de simulação baseado em premissas que não altera fatos oficiais. | DOM-PLN |
| DST-T011 | equiparacao_hospitalar | Equiparação Hospitalar | Domínio de análise tributária voltado à identificação e segregação de receitas potencialmente sujeitas ao tratamento aplicável a serviços hospitalares, conforme regras legais aprovadas e vigentes. | DOM-EH |
| DST-T012 | receita_elegivel_eh | Receita Elegível EqHop | Parcela de receita classificada como elegível pelo conjunto de regras vigente e, quando exigido, validada tecnicamente. | DOM-EH |
| DST-T013 | receita_nao_elegivel_eh | Receita Não Elegível EqHop | Parcela de receita classificada como não elegível pelo conjunto de regras vigente. | DOM-EH |
| DST-T014 | receita_pendente_eh | Receita Pendente EqHop | Receita cuja elegibilidade não pode ser concluída com segurança por falta de evidência, regra ou validação. | DOM-EH |
| DST-T015 | contribuicao_previdenciaria | Contribuição Previdenciária | Fato de contribuição associado a uma pessoa, fonte/vínculo e competência. | DOM-PRE |
| DST-T016 | excedente_inss | Excedente Potencial de INSS | Resultado calculado que representa contribuição potencialmente superior ao limite aplicável, sujeito às regras legais da competência. | DOM-PRE |
| DST-T017 | rendimento_irpf | Rendimento IRPF | Fato de renda relevante à apuração/projeção do IRPF, classificado segundo natureza tributária. | DOM-IRP |
| DST-T018 | livro_caixa | Livro-Caixa | Conjunto de receitas e despesas escrituráveis/dedutíveis no contexto aplicável ao trabalho não assalariado, sujeito às regras vigentes. | DOM-IRP |
| DST-T019 | regra_tributaria | Regra Tributária | Interpretação aprovada e versionada que transforma base legal em lógica determinística ou critério de classificação. | Transversal |
| DST-T020 | validacao_tecnica | Validação Técnica | Ato humano autorizado que confirma, rejeita ou ajusta classificação ou resultado sujeito a revisão. | Transversal |

## 3. Catálogo de enums V1
### DST-E001 — cd_regime_tributario
| Código | Nome exibido | Semântica |
|---|---|---|
| SIMPLES_NACIONAL | Simples Nacional | Regime do Simples Nacional; regras específicas ficam no RGT. |
| LUCRO_PRESUMIDO | Lucro Presumido | Regime de apuração pelo Lucro Presumido. |
| LUCRO_REAL | Lucro Real | Reservado para extensibilidade; não implica Skill V1 implementada. |
| OUTRO | Outro | Regime não coberto pelos códigos anteriores. |
| NAO_INFORMADO | Não informado | Regime ainda não determinado; não equivale a 'Outro'. |

### DST-E002 — tp_relacionamento
| Código | Nome exibido | Semântica |
|---|---|---|
| UE_PESSOA | UE ↔ Pessoa | Pessoa participa do contexto da Unidade Econômica. |
| UE_EMPRESA | UE ↔ Empresa | Empresa participa do contexto da Unidade Econômica. |
| SOCIO | Sócio | Pessoa/parte mantém vínculo societário com empresa. |
| PRO_LABORE | Pró-labore | Pessoa possui vínculo de pró-labore com empresa. |
| FONTE_RENDA | Fonte de renda | Vínculo entre titular e fonte pagadora. |
| DEPENDENTE_IRPF | Dependente IRPF | Vínculo de dependência fiscal no contexto do IRPF. |
| OUTRO | Outro | Vínculo não classificado nos códigos anteriores. |

### DST-E003 — cd_fonte_receita
| Código | Nome exibido | Semântica |
|---|---|---|
| NFS_E | NFS-e | Receita originada/documentada por NFS-e. |
| NF_E | NF-e | Receita originada/documentada por NF-e. |
| RECIBO_PF | Recibo PF | Receita documentada por recibo de pessoa física. |
| CARNE_LEAO | Carnê-Leão | Receita registrada no fluxo de Carnê-Leão. |
| INFORME_RENDIMENTOS | Informe de rendimentos | Receita proveniente de informe. |
| ERP | ERP | Receita recebida de sistema operacional/contábil sem fonte documental mais específica. |
| MANUAL | Manual | Entrada informada por usuário autorizado. |
| OUTRA | Outra | Fonte não enquadrada. |

### DST-E004 — tp_titular_receita
| Código | Nome exibido | Semântica |
|---|---|---|
| PF | Pessoa Física | Receita pertence à pessoa física. |
| PJ | Pessoa Jurídica | Receita pertence à pessoa jurídica. |
| INDEFINIDO | Indefinido | Titularidade ainda não determinada; exige resolução. |

### DST-E005 — st_qualidade_dado
| Código | Nome exibido | Semântica |
|---|---|---|
| VALIDO | Válido | Passou pelas validações aplicáveis. |
| PENDENTE_VALIDACAO | Pendente de validação | Ainda requer validação automática ou humana. |
| INCOMPLETO | Incompleto | Faltam dados necessários. |
| DIVERGENTE | Divergente | Conflita com outra fonte/fato relevante. |
| DUPLICADO | Duplicado | Potencial duplicidade identificada. |
| REJEITADO | Rejeitado | Não pode ingressar/ser usado como fato válido. |
| ESTIMADO | Estimado | Valor derivado de estimativa, não de fato confirmado. |

### DST-E006 — st_elegibilidade_eh
| Código | Nome exibido | Semântica |
|---|---|---|
| ELEGIVEL | Elegível | Critérios aprovados atendidos para a parcela classificada. |
| NAO_ELEGIVEL | Não elegível | Critérios aprovados não atendidos. |
| PENDENTE | Pendente | Informação/evidência insuficiente para conclusão. |
| REVISAO_TECNICA | Revisão técnica | Exige decisão humana especializada. |
| NAO_APLICAVEL | Não aplicável | Objeto/receita fora do escopo da análise. |

### DST-E007 — tp_rendimento_irpf
| Código | Nome exibido | Semântica |
|---|---|---|
| TRIBUTAVEL_PF | Tributável PF | Rendimento sujeito à tributação na pessoa física conforme regra aplicável. |
| TRIBUTAVEL_EXCLUSIVA | Tributação exclusiva/definitiva | Rendimento sujeito a regime específico de tributação exclusiva/definitiva. |
| ISENTO_NAO_TRIBUTAVEL | Isento/não tributável | Rendimento classificado como isento ou não tributável conforme regra. |
| SUJEITO_CARNE_LEAO | Sujeito a Carnê-Leão | Rendimento classificado para fluxo de Carnê-Leão. |
| PENDENTE_CLASSIFICACAO | Pendente | Natureza tributária ainda não concluída. |

### DST-E008 — st_registro
| Código | Nome exibido | Semântica |
|---|---|---|
| ATIVO | Ativo | Registro operacionalmente ativo. |
| INATIVO | Inativo | Registro preservado, porém não ativo. |
| ARQUIVADO | Arquivado | Registro histórico fora do fluxo operacional corrente. |

### DST-E009 — tp_documento_fiscal
| Código | Nome exibido | Semântica |
|---|---|---|
| NFS_E | NFS-e | Nota Fiscal de Serviço eletrônica. |
| NF_E | NF-e | Nota Fiscal eletrônica de mercadorias/produtos. |
| OUTRO | Outro | Outro documento fiscal suportado por adaptador. |

### DST-E010 — cd_sistema_origem
| Código | Nome exibido | Semântica |
|---|---|---|
| QUESTOR | Questor | Origem Questor via adaptador; não cria dependência de domínio. |
| NEON_DB | Neon/PostgreSQL hospedado | Origem técnica somente quando aplicável a importações; banco operacional não deve ser tratado como fonte de negócio. |
| MANUAL | Manual | Entrada por usuário autorizado. |
| DOCUMENTO | Documento | Origem documental genérica. |
| CNIS | CNIS | Origem previdenciária CNIS. |
| CARNE_LEAO | Carnê-Leão | Origem de dados do fluxo Carnê-Leão. |
| OUTRO | Outro | Fonte ainda não especializada. |

## 4. Regras de uso de estados especiais
| Estado | Significado | Pode ser tratado como zero? | Pode ser tratado como válido? |
|---|---|---|---|
| NAO_INFORMADO | Dado ainda não fornecido/determinado | Não | Não |
| PENDENTE | Processo de classificação/validação ainda aberto | Não | Não |
| NAO_APLICAVEL | Conceito não se aplica ao objeto | Não | Sim, como estado final sem valor |
| OUTRO | Valor conhecido, mas fora da taxonomia atual | Não | Depende do contrato |
| ESTIMADO | Valor calculado/estimado, não confirmado | Não | Somente para usos que aceitem estimativa |

## 5. Semântica temporal
- `dt_competencia`: mês ao qual o fato é atribuído para a finalidade do domínio.
- `dt_emissao`: data de emissão do documento; não determina automaticamente competência.
- `dt_importacao`: momento em que a plataforma recebeu/processou o dado.
- `dt_inicio_vinculo` e `dt_fim_vinculo`: vigência do relacionamento.
- Regra tributária deve possuir vigência própria; usar regra vigente na competência/fato conforme especificação do motor.

## 6. Semântica de fatos, classificações e resultados
```text
RAW / documento original
        ↓
dado extraído/candidato
        ↓
fato canônico validado
        ↓
classificação / regra
        ↓
resultado derivado
        ↓
cenário / dashboard / explicação
```

O resultado derivado nunca muda retroativamente o significado do fato original. Reprocessamentos produzem nova versão do resultado, preservando lineage.

## 7. Equiparação Hospitalar — limites semânticos
- `ELEGIVEL` significa que os critérios da regra aprovada foram atendidos; não significa que um código de serviço isolado seja suficiente.
- `PENDENTE` indica insuficiência de evidência ou informação.
- `REVISAO_TECNICA` indica que o motor não deve concluir automaticamente.
- `pc_confianca_classificacao` mede confiança do classificador, não probabilidade jurídica de êxito.
- `fl_validacao_tecnica` registra revisão humana; não substitui a versão da regra utilizada.

## 8. IRPF/Carnê-Leão — limites semânticos
- `TRIBUTAVEL_PF`, `ISENTO_NAO_TRIBUTAVEL` e demais naturezas são classificações canônicas; critérios legais ficam no RGT.
- `SUJEITO_CARNE_LEAO` identifica fluxo de apuração, não autoriza inferir sozinho imposto devido.
- Projeção de IRPF é resultado derivado e deve permanecer separada de imposto efetivamente apurado/pago.

## 9. Previdenciário — limites semânticos
- `vl_inss_recolhido` representa valor identificado como recolhido na fonte considerada.
- `vl_teto_previdenciario` é referência legal da competência e deve ser versionada.
- `vl_excedente_inss` é resultado potencial; não equivale automaticamente a crédito reconhecido ou recuperável.
- Conflito entre CNIS, folha, pró-labore ou outros documentos deve ser reconciliado, não resolvido pela semântica do DST.

## 10. Regra para nomes de interface
A interface pode apresentar rótulos mais amigáveis, mas deve mapear 1:1 para o código canônico. Exemplo: `REVISAO_TECNICA` pode ser exibido como 'Requer revisão técnica', porém o payload continua usando `REVISAO_TECNICA`.

## 11. Política para Claude Code
```yaml
dst_policy:
  source_of_truth: docs/02-Data/DST-001.md
  allow_free_text_for_enum: false
  allow_new_enum_without_dst: false
  allow_semantic_redefinition: false
  ui_labels_may_differ: true
  payload_codes_are_stable: true
  tax_logic_in_dst: false
```

Se um contrato exigir valor que não exista na taxonomia, Claude deve gerar `DST-CHANGE-REQUEST` com termo/código proposto, definição, domínio, consumidores, impacto e motivo.

## 12. Pontos de atenção identificados
- `NEON_DB` foi incluído apenas para deixar explícita a diferença entre infraestrutura e fonte de negócio. A arquitetura não deve usar o banco operacional como sistema de origem de fatos importados, salvo caso técnico excepcional e documentado.
- Os enums desta V1 são mínimos. Não devem ser usados para antecipar toda a legislação de IRPF, EqHop, IBS/CBS ou glosas.
- Termos como 'profissional da saúde' devem ser papel/qualificação de Pessoa Física, não um tipo-base de pessoa.
- Não utilizar 'médico' como sinônimo genérico de profissional da saúde.

## 13. Critérios de aceite
- [ ] Termos fundamentais possuem definição não ambígua.
- [ ] Estados especiais estão semanticamente separados.
- [ ] Enums usados no MCD/CDC possuem códigos iniciais.
- [ ] Semântica temporal está definida.
- [ ] Fato, classificação, resultado e cenário estão separados.
- [ ] EqHop, IRPF e INSS possuem limites semânticos claros.
- [ ] Claude Code está impedido de criar enum livre sem governança.

## 14. Próximo documento
**COT-001 — Catálogo Oficial de Objetos Tributários.** O COT transformará MCD + CDC + DST em objetos conceituais, relacionamentos, cardinalidades, ownership semântico, ciclo de vida e dependências entre UE, Pessoa Física, Empresa, Receita, Documento Fiscal, Contribuição Previdenciária, Evento IRPF, Cenário e resultados derivados.

---
**Decisão de governança:** MCD define como o dado é representado; CDC define como ele trafega; DST define o que ele significa.