---
title: 'Story 3.1 — Roster, melhor lineup e ganho marginal (puro)'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: '3646ca063fa3a5a26b8e438380c1e0092b2b54ba'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O Epic 2 congela a sessão e materializa `effective_pick_projection`, mas nada transforma picks em rosters, calcula o melhor lineup titular nem mede quanto um candidato agrega ao time do operador. Sem isso, `recommend_fast()` (3.2) não é roster-aware e a simulação (3.6) não pontua times.

**Approach:** Novo módulo de domínio puro `R/domain_roster.R` com quatro funções: `build_rosters()` (picks efetivas → roster por time), `best_lineup()` (roster + slots da liga → titulares que maximizam pontos projetados, FLEX de elegibilidade múltipla, classificação de cada jogador/slot), `marginal_gain()` (melhor lineup do operador com o candidato menos sem ele) e `roster_feasibility()` (achados bloqueantes quando os picks restantes do time não completam os slots obrigatórios). Determinístico, sem I/O.

## Boundaries & Constraints

**Always:**
- Domínio puro (AD-1): nenhum `import` de `shiny`/`DBI`/`RSQLite`/`yaml`/`jsonlite`/filesystem/relógio; todo input é argumento explícito; falha de domínio é **valor** (`domain_error()` ou achado), nunca exceção — salvo contrato estrutural (`stopifnot`), como `domain_schedule.R`.
- Determinismo: mesma entrada → saída `identical()` em qualquer execução, inclusive `LC_COLLATE=C`. Todo desempate é por `player_id` em ordem de byte (`order(..., method = "radix")`, como `league_sort_slots()`).
- `best_lineup()` maximiza a soma de pontos projetados dos titulares respeitando elegibilidade de posição; o slot `FLEX` aceita qualquer posição em `flex_eligibility` (`{RB, WR}` no V1). Solução ótima é fechada para os slots do V1 (ver Design Notes) — implementar direto, sem solver.
- Rótulo de cada jogador do roster: `titular` (slot da própria posição), `flex` (slot FLEX), `banco` (melhor reserva restante da sua posição), `redundancia` (reserva que não é o 1º da posição). Slots titulares sem jogador elegível → `empty_slots` (`titular_vazio`). `upgrade` (coluna lógica à parte) marca não-titular com `points` > pior titular de um slot elegível — normalmente vazio, só empate resolvido por `player_id` o produz.
- Achados de viabilidade usam `snapshot_quality_finding()` + `snapshot_quality_sort()` (formato de 1.5 / 2.1 / 2.2 / 2.4): `code` estável + mensagem PT-BR + `details`.
- `points` ausente/`NA`/`player_id` fora do snapshot ⇒ tratado como `-Inf` (nunca titula) + entrada em `warnings`; não bloqueia (campo opcional ausente é visível e não-bloqueante — contrato do Epic 1).

**Ask First:**
- Mudança na composição de slots do V1 ou em `flex_eligibility` além de `{RB, WR}`.
- Adicionar dependência de pacote.

**Never:**
- Não ler SQLite, chamar `snake_schedule()` de dentro do domínio, nem recalcular `points`/`vor`/`tier`.
- Não implementar `recommend_fast()`, estratégias, busca, use cases de comando ou o runner de simulação (3.2–3.6).
- Não modelar disponibilidade/urgência de mercado. Não emitir texto de UI nem formatação.

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída esperada | Erro |
|---|---|---|---|
| Rosters de todos os times | `effective_picks` = `data.frame(overall_pick, player_id, fantasy_team_id)`, 2+ times | Lista nomeada por `fantasy_team_id` → vetor `player_id` em ordem de `overall_pick` | N/A |
| Picks vazias | `data.frame` com 0 linhas | `list()` | N/A |
| `effective_picks` malformado | não-`data.frame`; coluna faltando; `player_id`/`fantasy_team_id` `NA`/vazio; `overall_pick` duplicado | — | `domain_error("roster_picks_malformado", ...)` |
| Lineup — roster completo | 15 jogadores válidos + `starter_slots` V1 + `flex_eligibility` `c("RB","WR")` + `players` do snapshot | `list(starters=<slot→player_id>, total_points, classification=data.frame(player_id, role, upgrade), empty_slots=chr, warnings=chr)`; soma ótima; FLEX = melhor RB/WR restante | N/A |
| Lineup — roster parcial | 9 jogadores, sem K/DST | K e DST em `empty_slots`; demais rotulados `titular`/`flex`/`banco`/`redundancia` | N/A |
| Empate de projeção | 2 jogadores da mesma posição, `points` iguais, disputando 1 slot | Menor `player_id` titula; o outro `banco` + `upgrade = TRUE` | N/A |
| Jogador do roster sem projeção | sem linha em `players` ou `points` `NA` | Nunca titula; `player_id` em `warnings`; rotulado `banco`/`redundancia` | não bloqueia |
| `starter_slots`/`flex_eligibility` inválidos | não vindos de `parse_league_config()` (tipo errado, chave FLEX ausente, FLEX fora de `{RB,WR}`) | — | `domain_error("roster_config_invalido", ...)` |
| Ganho marginal | `candidate_id` fora do roster do operador + roster + `players` + config | `numeric(1)` ≥ 0 = `total_points(roster ∪ cand) − total_points(roster)` | N/A |
| Candidato já no roster / sem projeção | `candidate_id` no roster, ou sem `points` | `0`; nunca negativo | não bloqueia |
| Viabilidade — obrigatório inatingível | `roster` + `remaining_picks` (int ≥ 0) + config; slots obrigatórios abertos > picks restantes | Lista ordenada de `snapshot_quality_finding("roster_slot_obrigatorio_inatingivel", "bloqueante", <msg>, list(slot, faltando, picks_restantes))` | N/A |
| Viabilidade — tudo alcançável | picks restantes ≥ slots obrigatórios abertos | `list()` | N/A |
| `remaining_picks` inválido | negativo, `NA`, não inteiro | — | `domain_error("roster_parametro_invalido", ...)` |
| Determinismo | qualquer linha acima, 2× (inclusive `LC_COLLATE=C`) | resultados `identical()` | N/A |

</frozen-after-approval>

## Code Map

- `R/domain_roster.R` — **novo**. As 4 funções `@export` + helpers privados. Cabeçalho de comentário no padrão de `R/domain_schedule.R:1-18`.
- `R/domain_errors.R` — `domain_error()` / `is_domain_error()`. Reusar.
- `R/domain_snapshot_quality.R` — `snapshot_quality_finding(code, severity, message, details)` e `snapshot_quality_sort(items)`; `roster_feasibility()` os reusa (mesmo uso em `domain_league_config.R` e `domain_draft_session.R`).
- `R/domain_league_config.R:24-29` — `league_v1_starter_slots` (`QB=1,RB=2,WR=2,TE=1,FLEX=1,K=1,DST=1`) e `league_flex_positions` (`c("RB","WR")`): a forma de `parse_league_config()$starter_slots` / `$flex_eligibility`. `best_lineup()` recebe esses **valores** como argumentos, não o objeto de config inteiro. `league_sort_slots():203` é o padrão de ordenação radix a espelhar.
- `R/domain_snapshot_schema.R:18-36` — contrato de jogador: `player_id`, `position` (`QB/RB/WR/TE/K/DST`), `points` obrigatórios. `best_lineup()` só usa esses três.
- `R/domain_snapshot.R:64-69,155-161` — o parser devolve `$players` como `data.frame` já unido players+metrics (tem `player_id`, `position` normalizada, `points`). É esse `data.frame` que os chamadores passam como `players`.
- `inst/schema/event-store-v1.md:38-52,69-81` — `effective_pick_projection` = `(draft_id, overall_pick, player_id)`; `draft_slot` = `(..., overall_pick, fantasy_team_id, ...)`. O chamador (3.4 / simulação) faz o join em `overall_pick` e passa `data.frame(overall_pick, player_id, fantasy_team_id)` a `build_rosters()`.
- `tests/testthat/test-domain_schedule.R:1-30` — padrão de teste de domínio: fixtures no topo, um `test_that` por linha da matriz, `expect_identical` para determinismo. Espelhar em `tests/testthat/test-domain_roster.R`.

## Tasks & Acceptance

**Execution:**
- [x] `R/domain_roster.R` — `build_rosters(effective_picks)`: valida forma (`data.frame`; colunas `overall_pick`/`player_id`/`fantasy_team_id`; sem `NA`/vazio; `overall_pick` único) → `domain_error("roster_picks_malformado", ...)`; sucesso → lista nomeada por `fantasy_team_id` de vetores `player_id` ordenados por `overall_pick`; 0 linhas → `list()`.
- [x] `R/domain_roster.R` — `best_lineup(roster_player_ids, players, starter_slots, flex_eligibility)`: valida `starter_slots` (int nomeado com as 7 chaves do V1) e `flex_eligibility` (subconjunto não-vazio de `{RB,WR}`) → `domain_error("roster_config_invalido", ...)`. Resolve `points`/`position` por `player_id`; ausente ⇒ `-Inf` + aviso. Preenche slots de posição com os melhores da posição, depois `FLEX` com o melhor restante elegível; desempate `player_id` radix. Retorna `list(starters, total_points, classification, empty_slots, warnings)` com as regras de rótulo das Boundaries; `total_points` soma só titulares com `points` finito.
- [x] `R/domain_roster.R` — `marginal_gain(candidate_id, roster_player_ids, players, starter_slots, flex_eligibility)`: candidato já no roster ou sem projeção ⇒ `0`; senão `total_points(c(roster, candidate)) − total_points(roster)`, com clamp em `0` para ruído de ponto flutuante (tolerância `sqrt(.Machine$double.eps)`).
- [x] `R/domain_roster.R` — `roster_feasibility(roster_player_ids, remaining_picks, players, starter_slots, flex_eligibility)`: valida `remaining_picks` (int ≥ 0) → `domain_error("roster_parametro_invalido", ...)`. Conta slots obrigatórios (todos os titulares, incl. FLEX) ainda não preenchíveis pelo roster; se `abertos > remaining_picks`, emite um achado `roster_slot_obrigatorio_inatingivel` por tipo de slot afetado, ordenado por `snapshot_quality_sort()`. Alcançável → `list()`.
- [x] `R/domain_roster.R` — helpers privados (resolução `player_id → position/points` tolerante a ausência; contagem de titulares por posição; desempate radix). Sem `@export`.
- [x] `tests/testthat/test-domain_roster.R` — **novo**. Um `test_that` por linha da I/O Matrix + as ACs. Fixtures no topo: pool de ~20 jogadores sintéticos (6 posições, `points` variados, 1 par empatado, 1 sem `points`), `effective_picks` de 3 times. Cada função rodada 2× com `expect_identical`; um teste sob `withr::with_locale(c(LC_COLLATE = "C"), ...)`.
- [x] `NAMESPACE` — regenerar com `devtools::document()` (4 funções `@export`).

**Acceptance Criteria:**
- Given as picks efetivas de uma sessão (join de `effective_pick_projection` + `draft_slot`), when `build_rosters()` roda, then devolve o roster de **todos** os times, cada um como a sequência de `player_id` na ordem de `overall_pick`.
- Given um roster e os `starter_slots` + `flex_eligibility` do V1, when `best_lineup()` roda, then os titulares maximizam a soma de pontos projetados respeitando elegibilidade e o `FLEX` recebe o melhor jogador restante entre RB e WR.
- Given um roster parcialmente preenchido, when `best_lineup()` roda, then cada jogador do roster recebe exatamente um rótulo em `{titular, flex, banco, redundancia}` (e, quando aplicável, `upgrade = TRUE`) e os slots titulares sem jogador elegível aparecem em `empty_slots`.
- Given um candidato e o roster atual do operador, when `marginal_gain()` roda, then devolve a diferença não-negativa entre o melhor lineup com e sem o candidato, e `0` quando o candidato já está no roster ou não tem projeção.
- Given os picks restantes do time e os slots obrigatórios ainda abertos, when uma escolha tornaria impossível completar os obrigatórios, then `roster_feasibility()` devolve um achado bloqueante nomeando o slot, quantos faltam e quantos picks restam.
- Given a mesma entrada, when qualquer das quatro funções roda 2× (inclusive sob `LC_COLLATE=C`), then o resultado é `identical()`.
- Given `R/domain_roster.R`, when `grep -nE "DBI|RSQLite|dbConnect|Sys\\.|shiny|readLines|file\\.path|yaml|jsonlite"` roda, then só há ocorrências em nomes de variável ou comentário.

## Design Notes

**O ótimo do V1 é fechado (sem solver):** os únicos slots que compartilham elegibilidade são RB, WR e FLEX. QB/TE/K/DST recebem trivialmente o melhor da posição. Para RB/WR/FLEX: os 2 slots de RB querem os 2 melhores RB; os 2 de WR os 2 melhores WR; o FLEX quer o melhor entre o 3º RB e o 3º WR. Nenhuma realocação aumenta a soma. Implementar direto.

**Classificação — algoritmo:** (1) roda o ótimo → titulares + ocupante do FLEX. (2) `titular`/`flex` saem daí. (3) não-titulares agrupados por posição, ordenados `points` desc / `player_id` asc: 1º de cada posição = `banco`, resto = `redundancia`. (4) `upgrade = TRUE` para não-titular com `points` > pior titular de um slot que ele poderia ocupar (posição própria ou FLEX). (5) `empty_slots` = tipos de slot titular sem jogador elegível, repetidos pela multiplicidade faltante (ex.: falta 1 RB + K → `c("K","RB")` radix).

**`classification`:** `data.frame(player_id <chr>, role <chr>, upgrade <lgl>)`, uma linha por jogador do roster, ordenado por `player_id`.

## Verification

**Commands:**
- `Rscript -e 'devtools::document()'` — NAMESPACE atualizado, sem erro.
- `Rscript -e 'devtools::test(filter = "domain_roster")'` — 0 falhas, 0 warnings.
- `Rscript -e 'devtools::test()'` — suíte inteira 0 falhas.
- `Rscript -e 'lintr::lint("R/domain_roster.R")'` — sem lint.
- `grep -nE "DBI|RSQLite|dbConnect|Sys\\.|shiny|readLines|file\\.path|yaml|jsonlite" R/domain_roster.R` — só nomes de variável/comentário.

## Suggested Review Order

**Melhor lineup e classificação**

- Ponto de entrada: otimizador de slot fechado (posição primeiro, FLEX depois) — a intenção de design toda está aqui.
  [`domain_roster.R:210`](../../R/domain_roster.R#L210)

- Laço do flag `upgrade`: `>=` deliberado, não `>` — só empate resolvido por `player_id` dispara (ver comentário `ponytail:`).
  [`domain_roster.R:289`](../../R/domain_roster.R#L289)

- `empty_slots` repetido pela multiplicidade faltante; `total_points` soma só titulares finitos.
  [`domain_roster.R:249`](../../R/domain_roster.R#L249)

- Impõe a forma canônica de `parse_league_config()` (7 chaves exatas, FLEX ⊆ {RB,WR}).
  [`domain_roster.R:43`](../../R/domain_roster.R#L43)

- Resolução tolerante a projeção ausente / `player_id` fora do snapshot → `-Inf` + `warnings`.
  [`domain_roster.R:86`](../../R/domain_roster.R#L86)

**Roster e ganho marginal**

- Picks efetivas → roster por time; saneamento (factor-safe, `trimws`, `overall_pick >= 1` e único, `player_id` único).
  [`domain_roster.R:124`](../../R/domain_roster.R#L124)

- `best_lineup(roster ∪ candidato) − best_lineup(roster)`; clamp em 0 para ruído de ponto flutuante e regra "nunca negativo".
  [`domain_roster.R:362`](../../R/domain_roster.R#L362)

**Viabilidade**

- Achado bloqueante por slot obrigatório inatingível; mensagem carrega o déficit agregado (`total_abertos`).
  [`domain_roster.R:380`](../../R/domain_roster.R#L380)

**Testes**

- Um `test_that` por linha da I/O Matrix + ACs + os 9 casos do review; determinismo 2× e sob `LC_COLLATE=C`.
  [`test-domain_roster.R:1`](../../tests/testthat/test-domain_roster.R#L1)
