# Prontidão para implementação — Fantasy Draft War Room

**Data:** 30-08-2026
**Gate:** CONCERNS → RESOLVIDO. Sprint liberado para geração.
**Avaliador:** bmad-sprint-planning (readiness gate)

## Resumo

Os Epics 1 a 5 de `_bmad-output/planning-artifacts/epics.md` estão bem decompostos, com histórias
independentemente implementáveis e rastreáveis aos requisitos do PRD, da arquitetura e do contrato de UX.

O gate inicial levantou três divergências entre `epics.md` e os artefatos de intent. O proprietário do
projeto (Giu) confirmou que as três são adições deliberadas ao escopo V1. As decisões foram registradas em
`decisions.md` (DEC-13, DEC-14, DEC-15) para restaurar a rastreabilidade.

---

## C1 — Epic 6 (Simulação e backtesting) — RESOLVIDO por DEC-13

O Epic 6 (FR59–FR62, histórias 6.1 a 6.4) permanece na V1 como uma **simulação offline simplificada e
determinística**, executada apenas por `scripts/simulate_draft.R`, fora do runtime live e do command
handling. É distinta do Simulation Lab completo (Monte Carlo assíncrono, aprendizado da mesa, comparação
ampla de estratégias), que continua na Versão 3.

Divergências originais, agora cobertas por DEC-13:

| Artefato | Localização | Conteúdo original |
|---|---|---|
| `docs/fantasy-draft-war-room-spec.md` | linhas 28, 34, 116, 1952 em diante | Simulação e backtesting como Versão 3. |
| `prd.md` | linha 67, linhas 153, 161 | "Não incluído no V1"; PERF-007 e REP-001 como V3. |
| `ARCHITECTURE-SPINE.md` | seção "Deferred" | "V3 simulation engine ... wait until ...". |
| `architecture/.memlog.md` | linha 13 | "V3 simulation remain outside V1." |
| `ux-designs/EXPERIENCE.md` | linha 110 | "Não há ... simulação ... no V1." |

As alocações V3 de PERF-007, REP-001, REL-004 e REL-005 continuam válidas para o Simulation Lab completo;
DEC-13 apenas admite a versão reduzida. A estratégia Pure VONA da história 6.1 é a aproximação por
distância até o próximo pick e ADP, sem modelo de mercado — não a VONA plena da Versão 2.

## C2 — FR58 (blacklist de jogadores) — RESOLVIDO por DEC-14

FR58 e a história 3.14 permanecem na V1. A blacklist pode ser materializada como arquivo YAML versionado,
consistente com AD-7. Não entra no `draft_state_hash` nem gera evento de draft; sobrevive a refresh como
configuração de sessão.

## C3 — Contagem de picks (168 contra 180) — RESOLVIDO por DEC-15

Times e rounds são configurados por YAML validado (8–14 times, 15 rounds). Os números citados nos
documentos são referência, não requisito. A fixture de benchmark adota uma configuração válida única e
registra a contagem de picks efetiva no resultado. Critérios de aceite e histórias que citam "168 picks"
devem ser lidos como "a contagem de picks da fixture de benchmark registrada".

---

## Situação

Gate liberado. `sprint-status.yaml` pode ser gerado com os 6 epics.
