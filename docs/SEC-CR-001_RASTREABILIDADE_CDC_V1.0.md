# Rastreabilidade `SEC-CHANGE-REQUEST-001` V1.1 → CDC-001 V1.3

**Status:** RELATÓRIO CURTO — acompanha a atualização do CDC. Não altera
SEC/COT/MCD/DST/ADR/Prisma/migrations/banco.

| Conceito exigido | Incorporado em | ID(s) atribuído(s) |
|---|---|---|
| `Tenant` (contrato canônico) | CDC-001 V1.3 §6 | `CDC-SEC-001` (campo: `id` = `MCD-F10001`) |
| `EventoAuditoriaSeguranca` (contrato canônico) | CDC-001 V1.3 §6 | `CDC-SEC-002` (campo: `id` = `MCD-F10006`) |
| `ContaAcesso ↔ Tenant` | CDC-001 V1.3 §6 | `CDC-SEC-003` (campo: `papel` = `MCD-F10005`) — reconcilia o placeholder `CDC-SEC-001 (a criar)` de `COT-001 V1.2` (`COT-SUP-005`) |
| `ContaAcesso ↔ UnidadeEconomica` (restrição) | CDC-001 V1.3 §6 | `CDC-SEC-004` (campo: `papel` = `MCD-F10005`) — reconcilia o placeholder `CDC-SEC-002 (a criar)` de `COT-001 V1.2` (`COT-SUP-006`) |
| `UnidadeEconomica.tenant_id` (âncora raiz) | CDC-001 V1.3, `CDC-UE-001` | `MCD-F10002`, imutável |
| `tenant_id` transversal (ArquivoOrigem, ConflitoDado, RevisaoTecnica) | CDC-001 V1.3, `CDC-ARQ-001`/`CDC-CFD-001`/`CDC-REV-001` | `MCD-F10003`, imutável, 3 hospedeiros |
| `unidade_economica_id` transversal (6 fatos) | CDC-001 V1.3, `CDC-REC-001`/`CDC-PRE-001`/`CDC-PREV-001`/`CDC-IRP-001`/`CDC-FIS-001`/`CDC-CAL-001` | `MCD-F10004`, versionado, 6 hospedeiros |
| Uniformidade semântica de `MCD-F10004` (nuance de timing em DocumentoFiscal) | CDC-001 V1.3, nota em `CDC-FIS-001` | Confirmado workflow/timing, não divergência semântica — reafirma `DST-001` V1.3 §11.1 |
| `ConflitoDadoItem` sem `tenant_id` próprio | CDC-001 V1.3, `CDC-CFD-002` (nota reafirmada, nenhum campo novo) | Deriva de `conflito_dado_id` → `ConflitoDado.tenant_id` (`MCD-F8651`, já vigente) |
| `ResultadoCalculo` sem XOR (`unidade_economica_id` × `cenario_tributario_id`) | CDC-001 V1.3, `CDC-CAL-001` + `CDC-REL-SEC-003` | Coexistência explícita, consistência exigida quando ambos presentes |
| `papel` — vocabulário aberto | CDC-001 V1.3, `CDC-SEC-003`/`CDC-SEC-004` | `MCD-F10005`; `DST-GAP-015` referenciado, nenhum enum criado |
| Semântica de restrição por UE (nunca amplia/substitui/concede Tenant) | CDC-001 V1.3, `CDC-SEC-004` + `CDC-REL-SEC-001` | Invariante formal registrada como constraint relacional |
| `PessoaFisica`/`PessoaJuridica`/`FontePagadora` preservados sem `tenant_id` | CDC-001 V1.3, `CDC-PER-001`/`CDC-EMP-001`/`CDC-FPG-001` (notas reafirmadas, nenhum campo novo) | Identidade global confirmada, sem alteração de campos |
| `Sessao`/`PapelAcesso`/`Permissao` — não contratualizados | CDC-001 V1.3 §12 | Confirmado `SEGURANCA_OPERACIONAL`/`DIFERIDO`, nenhum contrato criado |
| Estrutura para futura FK composta `(unidade_economica_id, tenant_id)` | CDC-001 V1.3, `CDC-REL-SEC-004` | Registrado como pendência exclusiva do ADR — nenhuma constraint física criada |

## Classificação de todas as diferenças frente ao CDC-001 V1.2

| Diferença | Classificação |
|---|---|
| 4 novos contratos (`CDC-SEC-001..004`) | `SEC-CR-001` |
| Novos campos em `CDC-UE-001`, `CDC-REC-001`, `CDC-PRE-001`, `CDC-PREV-001`, `CDC-IRP-001`, `CDC-FIS-001`, `CDC-CAL-001`, `CDC-ARQ-001`, `CDC-CFD-001`, `CDC-REV-001` | `SEC-CR-001` |
| Novas constraints `CDC-REL-SEC-001..004` | `SEC-CR-001` |
| Novos erros `CDC-ERR-017`/`CDC-ERR-018` | `SEC-CR-001` |
| `tenant_id` adicionado ao envelope canônico (§3) | `SEC-CR-001` |
| Nota em §9 distinguindo `tenant_id`/`unidade_economica_id` da família de proveniência | `SEC-CR-001` |
| Novos gaps `GAP-CDC-1.3-001..004` | `SEC-CR-001` |
| Nota de status em `GAP-CDC-1.2-003` (SEC-001 aprovado não resolve o gap) | `SINCRONIZACAO_COT_MCD_DST` |
| Numeração final `CDC-SEC-001..004` divergindo do placeholder preliminar `CDC-SEC-001/002 (a criar)` de `COT-001 V1.2` | `SINCRONIZACAO_COT_MCD_DST` — o COT já marcava a numeração como não-vinculante ("a criar"); nenhuma alteração ao COT foi necessária |
| Versão, dependências e "Próximo documento" atualizados | `SINCRONIZACAO_COT_MCD_DST` |
| `CDC-SEC-003`/`CDC-SEC-004` contratualizam somente `papel` — `id`/FKs estruturais das associações sem ID MCD | `INCONSISTENCIA` (não-bloqueante) — ver achado abaixo |

### Achado: `INCONSISTENCIA` não-bloqueante em `GAP-CDC-1.3-003`

A incorporação de `SEC-CHANGE-REQUEST-001` V1.1 ao `MCD-001 V1.3` catalogou apenas o campo
`papel` (`MCD-F10005`) para as duas novas estruturas relacionais de suporte
(`ContaAcessoTenant`, `ContaAcessoUnidadeEconomica`), sem atribuir IDs MCD para a identidade
própria (`id`) e as FKs estruturais (`conta_acesso_id`, `tenant_id`, `unidade_economica_id`)
dessas mesmas estruturas — diferente do precedente já usado para outras associações N:N do
catálogo (ex.: `ReceitaDocumentoFiscal` tem `id`/`receita_id`/`documento_fiscal_id` totalmente
catalogados). Isso impede que `CDC-SEC-003`/`CDC-SEC-004` sejam contratos completos nesta versão.

**Tratamento:** nenhum ID MCD foi inventado para preencher a lacuna (regra obrigatória desta
etapa: não alterar MCD). Os dois contratos foram escritos deliberadamente mínimos (apenas
`papel`), e a lacuna foi registrada como `GAP-CDC-1.3-003`, com escopo preciso, para ser
resolvida na reconciliação cruzada seguinte (provável patch pontual ao MCD, sem novas decisões
arquiteturais). Isso segue o mesmo padrão já estabelecido e não-bloqueante usado historicamente
para `ContaAcesso`/`CredencialAcesso` (catalogados no COT há várias versões sem detalhamento
completo de campos).

**Nenhuma outra diferença sem causa identificada permanece.**

## Verificação estrutural (item 13 da especificação)

| Verificação | Resultado |
|---|---|
| Todos os campos MCD aplicáveis (`MCD-F10001..F10006`) têm representação contratual | ✓ — os 6 novos IDs aparecem em pelo menos um contrato CDC cada (verificado por grep) |
| Nenhum campo CDC existe sem correspondência MCD | ✓ — nenhum campo novo foi adicionado além de `MCD-F10001..F10006`; nenhuma coluna inventada (ex.: `id`/FKs de `CDC-SEC-003`/`004` foram deliberadamente omitidas, não inventadas) |
| Todos os novos objetos COT têm contrato ou justificativa explícita | ✓ — `COT-OBJ-019`→`CDC-SEC-001`; `COT-OBJ-020`→`CDC-SEC-002`; `COT-SUP-005`→`CDC-SEC-003`; `COT-SUP-006`→`CDC-SEC-004` |
| Cardinalidades COT/CDC compatíveis | ✓ — todas as novas relações (`COT-REL-121..132`) são N:1 ou N:N simples, sem XOR/cardinalidade especial exceto onde já formalizado (`CDC-REL-SEC-001/003`) |
| Termos/gaps DST corretamente referenciados | ✓ — `DST-T031..037` e `DST-GAP-015` referenciados nos contratos correspondentes |
| Nenhum ID CDC reutilizado | ✓ — confirmado por diff automatizado: os 21 contratos e 16 erros da V1.2 permanecem intactos; `CDC-SEC-001..004` e `CDC-ERR-017/018` são estritamente novos |
| Nenhum campo aposentado retornou | ✓ — busca por `MCD-F2506..2509`, `MCD-F3006`, `MCD-F3009`, `MCD-F4008` não encontrou ocorrências |
| Todos os 139 campos MCD referenciados na V1.2 permanecem referenciados na V1.3 | ✓ — confirmado por diff automatizado (`comm -23` vazio) |

**Preservação da V1.2:** confirmado por diff automatizado — os 21 contratos canônicos
(`CDC-UE-001` … `CDC-SYS-001`) e os 16 erros (`CDC-ERR-001..016`) da V1.2 permanecem presentes
por ID na V1.3, sem nenhuma remoção. A V1.3 é estritamente aditiva sobre a lista de IDs: +4
contratos (`CDC-SEC-001..004`), +2 erros (`CDC-ERR-017/018`), +4 constraints relacionais
(`CDC-REL-SEC-001..004`), +4 gaps (`GAP-CDC-1.3-001..004`), +6 campos MCD referenciados
(`MCD-F10001..F10006`, aplicados a 10 contratos existentes + 4 novos). Nenhum contrato existente
teve campo removido; contratos modificados tiveram apenas linhas de campo/regras **adicionadas**
(revisão manual de prosa confirma nenhuma reescrita de regra pré-existente).

Uma inconsistência foi encontrada (`GAP-CDC-1.3-003`) — não-bloqueante, com causa identificada e
tratamento registrado para a reconciliação cruzada.

**CDC PÓS-SEC SINCRONIZADO — PRONTO PARA RECONCILIAÇÃO CRUZADA**
