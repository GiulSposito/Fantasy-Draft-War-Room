---
title: 'Story 2.4 — Use case start_draft e evento DRAFT_STARTED'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: '6c792429e14330657c4def0263457be13af82adf'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O event store (Story 2.3) existe, mas nada escreve nele. O comando `start` precisa: validar que config da liga (2.1) e ordem da 1ª rodada (2.2) estão viáveis, e — só então — anexar um `DRAFT_STARTED` que congela a proveniência e materializa o estado inicial, tudo numa transação. É o que fecha o Epic 2.

**Approach:** Domínio puro `R/domain_draft_session.R` (`new_draft_id()`, `draft_start_findings()`, `draft_started_payload()`) + use case `R/application_start_draft.R` (`start_draft()`): roda as precondições **fora** da transação (config/ordem inviável → devolve os achados, banco intocado); viável → uma `event_store_transaction()` que grava `draft_session` + `draft_slot` (de `snake_schedule`) + `DRAFT_STARTED` (`event_sequence = 1`) + `draft_state`.

## Boundaries & Constraints

**Always:**
- AD-4: `start_draft()` é o único caminho do comando `start`. Um evento imutável (`event_type = "DRAFT_STARTED"`); `draft_session` + todos os `draft_slot` + o evento (`event_sequence = 1`) + `draft_state` gravados na **mesma** `event_store_transaction()`; falha → rollback total, `domain_error`, nada commitado.
- **Precondições fora da transação:** `parse_league_teams()` + `draft_start_findings()` rodam antes de abrir qualquer transação. Achados não-vazios → `list(ok = FALSE, bloqueios = <achados ordenados>)`, **sem nenhum `INSERT`** — "nenhum evento quando inviável" sem depender de rollback.
- AD-6: o `DRAFT_STARTED` congela **valores resolvidos**, não hashes: `snapshot_id` + `snapshot_content_hash` + `scoring_identity` (o `scoring_hash` exibível) do snapshot do Epic 1; `league_rules_json` = `jsonlite::toJSON(league_config)`; `engine_version`; `random_seed` (opcional). O mesmo objeto é o `payload_json` do evento e as colunas de `draft_session`.
- `draft_state` inicial: `status = "DRAFTING"`, `next_overall_pick = 1L`. `draft_slot` vem de `snake_schedule(first_round_order, user_team_id, rounds = league_config$rounds)`, `user_team_id` = a linha `is_user` de `parse_league_teams()`.
- Domínio puro `R/domain_draft_session.R`: não importa `DBI`/`RSQLite`/`shiny`, não abre arquivo, não lê clock. `new_draft_id()` recebe o instante; o clock entra injetado no use case (`clock` → `POSIXct`). `new_draft_id()` → `"draft-<YYYYMMDDTHHMMSSZ UTC>"` (mirror de [new_snapshot_id()]).
- Falha → `domain_error()` (`code` estável, PT-BR, `details`). Nunca exceção não tratada. Reusa `validate_league_envelope`/`validate_first_round_order`/`snake_schedule`/`parse_league_teams`/`snapshot_quality_finding`/`snapshot_quality_sort`/`event_store_transaction` sem alterar assinaturas.
- Testes: domínio fora de SQLite; use case contra SQLite temporário (`event_store_connect` + `event_store_init`).

**Ask First:**
- Se a proveniência precisar congelar mais que `{snapshot_id, snapshot_content_hash, scoring_identity, league_rules_json, engine_version, random_seed}` (ex.: versão do schema do event store, lista de fontes do snapshot).

**Never:**
- Não implementar `record_pick`/`undo_last_pick`/`correct_pick`/`complete`/replay — Story 3.4.
- Não construir superfície Shiny nem `Validate and Lock` — a superfície de setup é uma story separada (`deferred-work.md`); `start_draft()` só devolve o resultado estruturado, não "explica na interface".
- Não alterar o schema do event store (Story 2.3) nem `event_store_*` do adapter.
- Não re-pontuar jogadores; `scoring_identity` é só identidade exibível.
- Não hashear estado nem config.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| `start` viável | `league_config` no envelope, `team_entries` com 1 `is_user`, `first_round_order` = permutação exata dos ids | `list(ok = TRUE, draft_id)`; 1 linha em `draft_session` (proveniência congelada); `N * 15` linhas em `draft_slot`; 1 `draft_event` `DRAFT_STARTED` `event_sequence = 1` com `payload_json` = a proveniência; 1 `draft_state` (`DRAFTING`, `next_overall_pick = 1`) |
| Envelope inválido | `league_config$teams = 7` | `list(ok = FALSE, bloqueios)` com o achado de `validate_league_envelope`, `details$grupo`; **nenhum** `INSERT` |
| Ordem incompleta / não-permutação | `first_round_order` sem um id, ou com id a mais/repetido | `list(ok = FALSE, bloqueios)` com o achado de ordem; nada gravado |
| Time do operador ≠ 1 | `team_entries` com 0 ou 2 `is_user`, ou id duplicado, ou forma inválida | `list(ok = FALSE, bloqueios)` (achado derivado do `domain_error` de `parse_league_teams`); nada gravado |
| `league_config` é `domain_error` | ex.: `parse_league_config` falhou upstream | devolve o mesmo `domain_error` |
| `snapshot_metadata` sem `snapshot_id`/`content_hash`/`scoring_hash` | metadata degenerado | `domain_error("start_snapshot_proveniencia_invalida", details$campo)` |
| Falha na escrita da transação | erro forçado num `INSERT` (ex.: `draft_id` colidindo) | rollback total; `domain_error("event_store_transacao_falhou")` propagado; banco sem a sessão, slots nem evento |
| Seed ausente | `start_draft(..., seed = NULL)` | `draft_session.random_seed` = `NULL`; `payload_json` sem `random_seed` (ou `null`) |
| Determinismo do payload | mesmos inputs + mesmo `clock` | `draft_started_payload(...)` → `identical()`; `new_draft_id()` → `identical()` |
| `draft_start_findings` viável | config + teams + ordem OK | `list()` |

</frozen-after-approval>

## Code Map

- `R/domain_draft_session.R` — **novo**, domínio puro. `new_draft_id(clock_value)` (mirror de [new_snapshot_id()] em `R/domain_snapshot_build.R:85`); `draft_start_findings(league_config, teams_df, first_round_order)` → lista ordenada de achados bloqueantes (`validate_league_envelope` + `validate_first_round_order` sobre `teams_df$fantasy_team_id`; `snapshot_quality_sort`); `draft_started_payload(snapshot_id, snapshot_content_hash, scoring_identity, league_config, engine_version, seed)` → lista nomeada.
- `R/application_start_draft.R` — **novo**, use case. `start_draft(con, snapshot_metadata, league_config, team_entries, first_round_order, seed = NULL, clock = Sys.time, engine_version = as.character(utils::packageVersion("fantasydraftwarroom")))`. Fluxo: guarda `is_domain_error(league_config)`; extrai/valida `snapshot_id`/`content_hash`/`scoring_hash` de `snapshot_metadata`; `teams <- parse_league_teams(team_entries)` (erro → achado); `findings <- draft_start_findings(...)`; se `length(findings)` → `list(ok = FALSE, bloqueios = findings)`; senão `snake_schedule()`, `new_draft_id(clock())`, `draft_started_payload()`, e `event_store_transaction(con, function(con) { <4 grupos de INSERT> })`; devolve `list(ok = TRUE, draft_id)` ou o `domain_error` do rollback.
- Reusar sem alterar: `event_store_transaction`/`event_store_next_sequence` (2.3, `R/adapter_sqlite_event_store.R` — colunas dos 4 `INSERT` em `event_store_schema` / `inst/schema/event-store-v1.md`); `validate_league_envelope` (2.1); `parse_league_teams`/`validate_first_round_order`/`snake_schedule` (2.2); `snapshot_quality_finding`/`snapshot_quality_sort` (`R/domain_snapshot_quality.R`, internos).
- `NAMESPACE` — `export()` à mão (convenção Stories 1.5–2.3): `start_draft`, `new_draft_id`, `draft_start_findings`, `draft_started_payload`.
- `tests/testthat/test-domain_draft_session.R`, `test-application_start_draft.R` — **novos**.
- Arquitetura: AD-4, AD-6, AD-8; ER `DRAFT_SESSION ||--o{ DRAFT_SLOT / DRAFT_EVENT`; PRD FR17, FR18, FR51, FR52; epic-2-context §"Technical Decisions".

## Tasks & Acceptance

**Execution:**
- [x] `R/domain_draft_session.R` — `new_draft_id()`, `draft_start_findings()`, `draft_started_payload()`.
- [x] `R/application_start_draft.R` — `start_draft()` conforme o fluxo do Code Map. Precondições fora da transação; a transação grava os 4 grupos (`draft_session`, `draft_slot` × N, `draft_event` `DRAFT_STARTED`, `draft_state`).
- [x] `NAMESPACE` — `export()` das 4 funções públicas (ordem alfabética, à mão).
- [x] `tests/testthat/test-domain_draft_session.R` — `new_draft_id` determinístico e no formato; `draft_start_findings` cobre envelope, ordem, e o caso viável (`list()`); `draft_started_payload` inclui/omite `random_seed` e é `identical()` para mesmos inputs.
- [x] `tests/testthat/test-application_start_draft.R` — cobre a I/O & Edge-Case Matrix contra um SQLite temporário: `start` viável materializa os 4 grupos numa transação; cada caso inviável não escreve nada; `league_config` `domain_error` passa direto; metadata degenerado; rollback; seed ausente.

**Acceptance Criteria:**
- Given `league_config` no envelope V1, `team_entries` com exatamente um time do operador e `first_round_order` = permutação exata dos ids cadastrados, when `start_draft()` roda, then um `DRAFT_STARTED` com `event_sequence = 1` é anexado, `draft_session` guarda `snapshot_id` + `snapshot_content_hash` + `scoring_identity` + `league_rules_json` + `engine_version` + `random_seed`, e `draft_slot`/`draft_state` são materializados na mesma transação; o retorno é `list(ok = TRUE, draft_id)`.
- Given config fora do envelope, ordem incompleta, ou time do operador ≠ 1, when `start_draft()` roda, then o retorno é `list(ok = FALSE, bloqueios = <achados>)` apontando o grupo afetado e **nenhuma** linha é escrita em nenhuma tabela.
- Given uma falha em qualquer `INSERT` da escrita, when a transação aborta, then o banco não contém a sessão, os slots nem o evento, e o retorno é um `domain_error`.
- Given `R/domain_draft_session.R`, when inspecionado, then não importa `DBI`/`RSQLite`/`shiny`, não abre arquivo, não lê o clock.

## Design Notes

- **Precondições fora da transação resolvem o item deferido da 2.3:** como `start_draft` valida config/ordem/times antes de abrir a transação, dentro dela só ocorrem erros genuínos de SQL — o embrulho genérico `event_store_transacao_falhou` basta, não é preciso preservar `code`/`details` no `event_store_transaction`.
- **Payload = colunas:** `draft_started_payload()` devolve a lista que é ao mesmo tempo o `payload_json` do evento e a fonte das colunas de proveniência de `draft_session` — uma só definição da proveniência congelada.

## Verification

**Commands:**
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint_package()'` — sem lint nos arquivos novos.
- Pureza: `grep -nE "DBI|RSQLite|dbConnect|Sys\\.|readLines|shiny|file\\.path" R/domain_draft_session.R` — só nomes de variável/comentário.

## Suggested Review Order

**Use case — o fluxo do `start`**

- Ponto de entrada: guardas (config `domain_error`, proveniência, `seed`, `clock`) → precondições fora da transação → uma `event_store_transaction`.
  [`application_start_draft.R:107`](../../R/application_start_draft.R#L107)
- A transação: `draft_session` + `draft_slot` (de `snake_schedule`, via `dbAppendTable`) + `DRAFT_STARTED` (`event_sequence = 1`) + `draft_state`, tudo no closure.
  [`application_start_draft.R:151`](../../R/application_start_draft.R#L151)

**Domínio puro**

- `draft_start_findings`: dobra `validate_league_envelope` + erro de `parse_league_teams` + `validate_first_round_order` numa lista ordenada; `list()` = viável.
  [`domain_draft_session.R:65`](../../R/domain_draft_session.R#L65)
- `draft_started_payload`: a proveniência congelada (AD-6) — mesma lista serve de `payload_json` e de colunas de `draft_session`.
  [`domain_draft_session.R:98`](../../R/domain_draft_session.R#L98)
- `new_draft_id`: `"draft-<stamp UTC>"`, mirror de `new_snapshot_id`.
  [`domain_draft_session.R:26`](../../R/domain_draft_session.R#L26)

**Guardas de entrada (patches do review)**

- `seed` validado uma vez (finito, range de `integer`); `clock()` tem que devolver `POSIXct` escalar; campos do metadata aparados antes de congelar.
  [`application_start_draft.R:44`](../../R/application_start_draft.R#L44)

**Periféricos**

- Testes: ordem snake nos slots, readback do `payload_json` persistido, rollback numa escrita **tardia** da transação.
  [`test-application_start_draft.R:261`](../../tests/testthat/test-application_start_draft.R#L261)
- 4 exports à mão.
  [`NAMESPACE:1`](../../NAMESPACE#L1)
