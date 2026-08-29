# CAF-001 — CONTIFISC Architecture Framework (V1)

Versão: 1.0

## Missão
Construir a primeira plataforma brasileira de inteligência tributária integrada para profissionais da saúde.

### Pilares
- Simples Nacional
- Lucro Presumido
- Equiparação Hospitalar e segregação de receitas
- Gestão Híbrida (PJ + Carnê-Leão)
- IRPF completo
- Recuperação de INSS acima do teto
- Reforma Tributária (IBS/CBS)

## Princípios
1. Um dado é cadastrado apenas uma vez.
2. Toda Skill consome o Modelo Canônico de Dados.
3. Nenhum ERP é acoplado diretamente.
4. Toda alteração gera evento.
5. Todo cálculo possui rastreabilidade jurídica.

## Arquitetura
UE → Gateway → MCD → CDC → DST → COT → ATI → GTI → MIT → Skills

## Desenvolvimento paralelo (Claude)
Estrutura inicial:
- apps/web
- packages/core
- packages/types
- packages/ui
- packages/integrations
- packages/ai
- docs
- tests

## Banco inicial
- economic_units
- people
- companies
- integrations
- events
- documents
- jobs
- audit_logs

## Eventos mínimos
- Receita registrada
- XML recebido
- Pró-labore alterado
- Nova empresa cadastrada
- CNIS importado
- Informe IRPF importado

## Critérios de aceite
- Arquitetura congelada
- Estrutura criada
- Banco inicial criado
- Login funcional
- Gateway preparado
