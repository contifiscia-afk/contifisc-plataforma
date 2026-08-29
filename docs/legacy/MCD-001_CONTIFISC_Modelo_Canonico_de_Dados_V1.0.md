# MCD-001 — Modelo Canônico de Dados da CONTIFISC

**Versão:** 1.0  
**Status:** Documento Fundador — V1  
**Dependência:** CAF-001  
**Escopo:** CONTIFISC Intelligence Platform — profissionais da saúde

> **Princípio central:** a plataforma não depende da nomenclatura ou do modelo de dados de qualquer ERP. Questor ou qualquer outro sistema é fonte externa; os dados são traduzidos pelo Gateway para o MCD antes do consumo pelas Skills.

## 1. Objetivo
Definir a gramática oficial dos dados: nomenclatura, tipos, identificadores, nulidade, precisão, versionamento, proveniência, qualidade e um catálogo inicial de campos fundamentais. O MCD não define fórmulas tributárias.

## 2. Decisões arquiteturais congeladas
- Um dado canônico possui um único nome técnico e identificador permanente.
- Skills não criam nomes alternativos para conceitos existentes.
- Integrações usam adaptadores; nomes de campos do ERP não vazam para o domínio.
- Dados importados, manuais, calculados e classificados por IA mantêm proveniência.
- Histórico por competência é obrigatório quando aplicável.
- A Unidade Econômica organiza múltiplos CPFs/CNPJs sem substituir suas identidades.
- EqHop possui domínio próprio; IRPF/Carnê-Leão e Previdenciário operam também sem PJ.

## 3. Convenção de nomenclatura
| Prefixo | Uso | Exemplo |
|---|---|---|
| id_ | identificador/referência | id_empresa |
| nr_ | número documental/registro | nr_cpf |
| nm_ | nome | nm_pessoa |
| cd_ | código/classificação | cd_regime_tributario |
| ds_ | descrição | ds_servico_fiscal |
| dt_ | data/competência/timestamp | dt_competencia |
| vl_ | valor monetário | vl_receita_bruta |
| pc_ | percentual | pc_participacao_societaria |
| qt_ | quantidade | qt_procedimentos |
| st_ | situação/status | st_elegibilidade_eh |
| tp_ | tipo/natureza | tp_rendimento_irpf |
| fl_ | booleano | fl_validacao_tecnica |
| sg_ | sigla | sg_uf_registro_profissional |

- **MCD-R001:** `snake_case`, ASCII e sem acentos.
- **MCD-R002:** sem abreviações ambíguas ou nomes dependentes de ERP.
- **MCD-R003:** um conceito não pode ter dois campos canônicos.
- **MCD-R004:** nome exibido pode mudar; nome técnico exige depreciação/versionamento.
- **MCD-R005:** IDs internos são UUID; CPF/CNPJ não são chaves primárias.
- **MCD-R006:** dinheiro usa decimal exato; `float` é proibido.
- **MCD-R007:** percentual canônico usa 32,0000 para representar 32%, salvo futura mudança formal no CDC.

## 4. Tipos canônicos
| Tipo | Implementação | Regra |
|---|---|---|
| UUID | UUID nativo | ID interno imutável. |
| Dinheiro | NUMERIC(18,2) | Sem ponto flutuante. |
| Percentual | NUMERIC(7,4) | Faixa validada por campo. |
| Date | DATE | Sem horário. |
| Competência | DATE no 1º dia do mês | Exibição YYYY-MM. |
| Timestamp TZ | TIMESTAMPTZ | Persistência UTC. |
| CPF/CNPJ | VARCHAR | Somente dígitos; máscara na UI. |
| Enum | Código estável | Descrição separada. |
| Boolean | BOOLEAN | null só quando semanticamente necessário. |

## 5. Nulidade, ausência e zero
- `null` = desconhecido, não informado, indisponível ou não aplicável conforme contrato.
- Zero = valor conhecido igual a zero; ausência nunca vira zero.
- Obrigatoriedade definitiva será definida no CDC por objeto/operação.
- Resultado calculado com entradas incompletas deve carregar status de qualidade/cálculo.

## 6. Proveniência e independência de ERP
Todo registro importado deve ser rastreável. O Gateway normaliza o payload e preserva sistema de origem, ID externo, data de importação e arquivo bruto quando aplicável. Trocar o Questor por outro ERP deve alterar o adaptador, não as Skills.
```text
ERP / XML / PDF / CNIS / Informe / Manual
                ↓
        Adaptador / Parser
                ↓
     Validação + Normalização
                ↓
               MCD
                ↓
      Objetos / Eventos / Skills
```

## 7. Domínios canônicos
| Código | Domínio | Responsabilidade |
|---|---|---|
| DOM-CORE | Núcleo / Identidade | Entidades e vínculos estruturais. |
| DOM-PER | Pessoas | Pessoas físicas e profissionais da saúde. |
| DOM-EMP | Empresas | Pessoas jurídicas e regimes. |
| DOM-REL | Relacionamentos | Vínculos entre UE, CPF e CNPJ. |
| DOM-REC | Receitas | Receitas PJ/PF e fontes pagadoras. |
| DOM-FIS | Fiscal | NFS-e/NF-e e metadados fiscais. |
| DOM-EH | Equiparação Hospitalar | Classificação e segregação EqHop. |
| DOM-PRE | Previdenciário | Contribuições, vínculos, teto e excedentes. |
| DOM-IRP | IRPF / Carnê-Leão | Rendimentos, deduções e projeções. |
| DOM-PLN | Planejamento | Cenários e resultados tributários. |
| DOM-SYS | Sistema / Auditoria | Origem, qualidade, versão e auditoria. |

## 8. Catálogo inicial de campos fundamentais (71 campos)
A V1 congela a gramática e um vocabulário mínimo. Novos campos entram apenas quando objetos e Skills validados exigirem.
| ID | Domínio | Nome técnico | Significado | Tipo | Unidade | Origem típica | Obrig. V1 | Histórico |
|---|---|---|---|---|---|---|---|---|
| MCD-F0001 | DOM-CORE | id_unidade_economica | Identificador da Unidade Econômica | UUID | - | Sistema | Não | Sim |
| MCD-F0002 | DOM-CORE | nm_unidade_economica | Nome da Unidade Econômica | Texto(160) | - | Cadastro | Sim | Sim |
| MCD-F0003 | DOM-CORE | st_registro | Situação do registro | Enum | - | Sistema | Sim | Sim |
| MCD-F0004 | DOM-CORE | dt_criacao | Data/hora de criação | Timestamp TZ | - | Sistema | Sim | Sim |
| MCD-F0005 | DOM-CORE | dt_atualizacao | Data/hora da atualização | Timestamp TZ | - | Sistema | Sim | Sim |
| MCD-F1001 | DOM-PER | id_pessoa | Identificador da pessoa | UUID | - | Sistema | Não | Sim |
| MCD-F1002 | DOM-PER | nr_cpf | CPF | Texto(11) | dígitos | Cadastro/Importação | Cond. | Sim |
| MCD-F1003 | DOM-PER | nm_pessoa | Nome completo | Texto(200) | - | Cadastro/Importação | Sim | Sim |
| MCD-F1004 | DOM-PER | dt_nascimento | Data de nascimento | Date | - | Cadastro/Importação | Não | Sim |
| MCD-F1005 | DOM-PER | cd_conselho_profissional | Conselho profissional | Enum | - | Cadastro | Não | Sim |
| MCD-F1006 | DOM-PER | nr_registro_profissional | Número no conselho | Texto(30) | - | Cadastro | Não | Sim |
| MCD-F1007 | DOM-PER | sg_uf_registro_profissional | UF do conselho | Texto(2) | UF | Cadastro | Não | Sim |
| MCD-F1008 | DOM-PER | cd_especialidade_saude | Especialidade/área | Enum/Ref | - | Cadastro | Não | Sim |
| MCD-F2001 | DOM-EMP | id_empresa | Identificador da empresa | UUID | - | Sistema | Não | Sim |
| MCD-F2002 | DOM-EMP | nr_cnpj | CNPJ | Texto(14) | dígitos | ERP/Cadastro | Cond. | Sim |
| MCD-F2003 | DOM-EMP | nm_razao_social | Razão social | Texto(200) | - | ERP/Cadastro | Não | Sim |
| MCD-F2004 | DOM-EMP | cd_regime_tributario | Regime tributário | Enum | - | ERP/Cadastro | Cond. | Sim |
| MCD-F2005 | DOM-EMP | cd_cnae_principal | CNAE principal | Texto(7) | dígitos | ERP/Cadastro | Não | Sim |
| MCD-F2006 | DOM-EMP | dt_abertura_empresa | Data de abertura | Date | - | ERP/Cadastro | Não | Sim |
| MCD-F2007 | DOM-EMP | cd_municipio_ibge | Município IBGE | Texto(7) | IBGE | ERP/Cadastro | Não | Sim |
| MCD-F2501 | DOM-REL | id_relacionamento | Identificador do relacionamento | UUID | - | Sistema | Não | Sim |
| MCD-F2502 | DOM-REL | tp_relacionamento | Tipo de relacionamento | Enum | - | Cadastro/Sistema | Sim | Sim |
| MCD-F2503 | DOM-REL | pc_participacao_societaria | Participação societária | Decimal(7,4) | % | ERP/Cadastro | Não | Sim |
| MCD-F2504 | DOM-REL | dt_inicio_vinculo | Início do vínculo | Date | - | ERP/Cadastro | Não | Sim |
| MCD-F2505 | DOM-REL | dt_fim_vinculo | Fim do vínculo | Date | - | ERP/Cadastro | Não | Sim |
| MCD-F3001 | DOM-REC | id_receita | Identificador da receita | UUID | - | Sistema | Não | Sim |
| MCD-F3002 | DOM-REC | vl_receita_bruta | Valor bruto da receita | Decimal(18,2) | BRL | ERP/XML/Manual | Cond. | Sim |
| MCD-F3003 | DOM-REC | dt_emissao | Data de emissão | Date | - | XML/Documento | Não | Sim |
| MCD-F3004 | DOM-REC | dt_competencia | Competência | Date(Mês) | YYYY-MM | ERP/XML/Manual | Cond. | Sim |
| MCD-F3005 | DOM-REC | cd_fonte_receita | Fonte da receita | Enum/Ref | - | Classificação | Cond. | Sim |
| MCD-F3006 | DOM-REC | tp_titular_receita | Titularidade PJ/PF | Enum | - | Sistema/Classificação | Cond. | Sim |
| MCD-F3007 | DOM-REC | id_fonte_pagadora | Fonte pagadora | UUID/Ref | - | Importação/Cadastro | Não | Sim |
| MCD-F3008 | DOM-REC | vl_retencoes | Retenções vinculadas | Decimal(18,2) | BRL | XML/Informe | Não | Sim |
| MCD-F4001 | DOM-FIS | id_documento_fiscal | Identificador do documento fiscal | UUID | - | Sistema | Não | Sim |
| MCD-F4002 | DOM-FIS | tp_documento_fiscal | Tipo do documento fiscal | Enum | - | Importação | Sim | Sim |
| MCD-F4003 | DOM-FIS | nr_documento_fiscal | Número do documento | Texto(60) | - | XML/Documento | Não | Sim |
| MCD-F4004 | DOM-FIS | ch_documento_fiscal | Chave/ID externo | Texto(80) | - | XML/API | Não | Sim |
| MCD-F4005 | DOM-FIS | cd_servico_fiscal | Código do serviço | Texto(30) | - | XML/API | Não | Sim |
| MCD-F4006 | DOM-FIS | ds_servico_fiscal | Descrição do serviço | Texto longo | - | XML/API | Não | Sim |
| MCD-F4007 | DOM-FIS | vl_documento_fiscal | Valor total do documento | Decimal(18,2) | BRL | XML/API | Não | Sim |
| MCD-F4008 | DOM-FIS | id_arquivo_origem | Arquivo bruto de origem | UUID/Ref | - | Sistema | Não | Sim |
| MCD-F5001 | DOM-EH | st_elegibilidade_eh | Situação de elegibilidade EqHop | Enum | - | Motor/Validação | Cond. | Sim |
| MCD-F5002 | DOM-EH | pc_receita_elegivel_eh | Percentual elegível | Decimal(7,4) | % | Motor/Validação | Não | Sim |
| MCD-F5003 | DOM-EH | vl_receita_elegivel_eh | Valor elegível segregado | Decimal(18,2) | BRL | Cálculo | Não | Sim |
| MCD-F5004 | DOM-EH | vl_receita_nao_elegivel_eh | Valor não elegível segregado | Decimal(18,2) | BRL | Cálculo | Não | Sim |
| MCD-F5005 | DOM-EH | pc_confianca_classificacao | Confiança da classificação | Decimal(7,4) | % | IA/Classificador | Não | Sim |
| MCD-F5006 | DOM-EH | fl_validacao_tecnica | Validação humana/técnica | Boolean | - | CONTIFISC | Não | Sim |
| MCD-F6001 | DOM-PRE | id_contribuicao_previdenciaria | Identificador da contribuição | UUID | - | Sistema | Não | Sim |
| MCD-F6002 | DOM-PRE | vl_inss_recolhido | INSS recolhido | Decimal(18,2) | BRL | CNIS/Folha/Informe | Cond. | Sim |
| MCD-F6003 | DOM-PRE | vl_salario_contribuicao | Salário/base de contribuição | Decimal(18,2) | BRL | CNIS/Folha | Não | Sim |
| MCD-F6004 | DOM-PRE | vl_teto_previdenciario | Teto da competência | Decimal(18,2) | BRL | Tabela legal | Cond. | Sim |
| MCD-F6005 | DOM-PRE | vl_excedente_inss | Excedente potencial | Decimal(18,2) | BRL | Cálculo | Não | Sim |
| MCD-F6006 | DOM-PRE | id_vinculo_previdenciario | Fonte/vínculo previdenciário | UUID/Ref | - | CNIS/Cadastro | Não | Sim |
| MCD-F7001 | DOM-IRP | id_evento_irpf | Identificador do evento IRPF | UUID | - | Sistema | Não | Sim |
| MCD-F7002 | DOM-IRP | tp_rendimento_irpf | Natureza do rendimento | Enum | - | Classificação/Informe | Cond. | Sim |
| MCD-F7003 | DOM-IRP | vl_rendimento_tributavel | Rendimento tributável | Decimal(18,2) | BRL | Informe/Carnê/ERP | Não | Sim |
| MCD-F7004 | DOM-IRP | vl_rendimento_isento | Rendimento isento | Decimal(18,2) | BRL | Informe/ERP | Não | Sim |
| MCD-F7005 | DOM-IRP | vl_deducao_irpf | Dedução considerada | Decimal(18,2) | BRL | Documento/Carnê | Não | Sim |
| MCD-F7006 | DOM-IRP | vl_livro_caixa | Despesa de livro-caixa | Decimal(18,2) | BRL | Carnê/Manual | Não | Sim |
| MCD-F7007 | DOM-IRP | vl_irpf_retido | IRPF retido | Decimal(18,2) | BRL | Informe | Não | Sim |
| MCD-F7008 | DOM-IRP | vl_irpf_projetado | IRPF projetado | Decimal(18,2) | BRL | Cálculo | Não | Sim |
| MCD-F8001 | DOM-PLN | id_cenario_tributario | Identificador do cenário | UUID | - | Sistema | Não | Sim |
| MCD-F8002 | DOM-PLN | nm_cenario_tributario | Nome do cenário | Texto(120) | - | Usuário/Sistema | Sim | Sim |
| MCD-F8003 | DOM-PLN | vl_carga_tributaria_projetada | Carga projetada | Decimal(18,2) | BRL | Cálculo | Não | Sim |
| MCD-F8004 | DOM-PLN | vl_economia_tributaria_projetada | Economia projetada | Decimal(18,2) | BRL | Cálculo | Não | Sim |
| MCD-F9001 | DOM-SYS | cd_sistema_origem | Sistema de origem | Enum | - | Gateway | Sim | Sim |
| MCD-F9002 | DOM-SYS | id_registro_origem | ID externo de origem | Texto(120) | - | Gateway | Não | Sim |
| MCD-F9003 | DOM-SYS | dt_importacao | Data/hora de importação | Timestamp TZ | - | Gateway | Não | Sim |
| MCD-F9004 | DOM-SYS | st_qualidade_dado | Qualidade do dado | Enum | - | Validador | Não | Sim |
| MCD-F9005 | DOM-SYS | nr_versao_schema | Versão do schema | Texto(20) | SemVer | Sistema | Sim | Sim |
| MCD-F9006 | DOM-SYS | id_evento_auditoria | Evento de auditoria | UUID/Ref | - | Sistema | Não | Sim |

## 9. Compartilhamento transversal
Campos pertencem ao modelo canônico, não às Skills.
| Informação | Produtores típicos | Consumidores típicos |
|---|---|---|
| Pró-labore (objeto futuro) | Folha/ERP/Manual | INSS, IRPF, Planejamento, Dashboard |
| vl_receita_bruta | ERP, NFS-e, manual | Fiscal, EqHop, Planejamento, Dashboard |
| dt_competencia | ERP, XML, informe, CNIS | Motores temporais |
| st_elegibilidade_eh | Motor EqHop + CONTIFISC | Planejamento, segregação, dashboards |
| vl_inss_recolhido | CNIS, folha, informes | Recuperação INSS, IRPF, planejamento |
| vl_rendimento_tributavel | Informe, Carnê-Leão, PJ/PF | IRPF, projeção, dashboard |

## 10. Regras críticas
### 10.1 Equiparação Hospitalar
- Classificação por documento/receita e possibilidade de segregação parcial quando aplicável.
- Percentual e valores segregados não substituem a receita original.
- Confiança automatizada e validação técnica são separadas.
- Base jurídica da elegibilidade fica fora do MCD.
### 10.2 INSS
- Suportar múltiplos vínculos/fontes no mesmo CPF e competência.
- CNIS, Meu INSS, folha e pró-labore são fontes, não modelos de domínio.
- Teto e excedente dependem de tabela legal versionada e Motor Previdenciário.
### 10.3 IRPF e Carnê-Leão
- Operação autônoma, inclusive sem CNPJ.
- Informes, Carnê-Leão, livro-caixa, múltiplas fontes e dados da PJ convergem ao canônico.
- Regras, limites e exceções do IRPF ficam fora do MCD.

## 11. Qualidade de dados
Estados conceituais mínimos: `VALIDO`, `PENDENTE_VALIDACAO`, `INCOMPLETO`, `DIVERGENTE`, `DUPLICADO`, `REJEITADO`, `ESTIMADO`. Divergências não podem ser sobrescritas silenciosamente.

## 12. Versionamento e depreciação
- SemVer para documento/schema.
- Campo opcional compatível: versão minor; mudança incompatível/remoção: major.
- IDs/campos nunca são reutilizados com outro significado.
- Campo depreciado permanece documentado durante migração.
- Toda alteração mapeia impacto em CDC, COT, ATI, eventos, APIs, Skills e migrações.

## 13. Política para Claude Code
```yaml
mcd_policy:
  source_of_truth: docs/02-Data/MCD-001.md
  allow_new_field_without_mcd: false
  allow_erp_field_names_in_domain_models: false
  money_type: decimal
  ids: uuid
  naming: snake_case
  unknown_value: null
  zero_is_unknown: false
  preserve_provenance: true
  preserve_history: true
```
Antes de criar tabela, DTO, schema, evento ou endpoint, o Claude deve procurar o campo no MCD. Se não existir, deve registrar proposta de extensão e não inventar nomenclatura.

## 14. Fora do escopo desta V1
- Todos os campos possíveis de IRPF, Carnê-Leão, EqHop, IBS/CBS e glosas.
- Enums definitivos e contratos completos.
- Fórmulas tributárias e bases legais.
- Modelo físico final, índices e retenção LGPD detalhada.

## 15. Critérios de aceite
- [ ] Convenção de nomes congelada.
- [ ] Tipos monetários, percentuais, datas e nulidade padronizados.
- [ ] Independência de ERP garantida pelo Gateway.
- [ ] EqHop, IRPF/Carnê-Leão e INSS autônomos no modelo.
- [ ] Múltiplos CPFs/CNPJs suportados pela Unidade Econômica.
- [ ] Novos campos sujeitos a governança e versionamento.

## 16. Próximo documento
**CDC-001 — Contrato Canônico de Dados:** obrigatoriedade por objeto/operação, entrada/saída, validações, compatibilidade e contratos executáveis para APIs, eventos e integrações.

---
**Decisão de governança:** esta V1 congela a gramática do sistema, não todo o vocabulário. O MCD crescerá por demanda validada das Skills e objetos.