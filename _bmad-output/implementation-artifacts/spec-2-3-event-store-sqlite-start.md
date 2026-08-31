---
title: 'Story 2.3 — Event store SQLite mínimo'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: '99d1d3b8eb1e9e705c78488624dfa71a353cb0f0'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As Stories 2.1 e 2.2 produzem valores em memória, mas nada é durável. O Epic 3 (picks/undo/replay por eventos) e a Story 2.4 (`start_draft`) precisam de um event store SQLite: tabelas criadas no boot, log append-only com `event_sequence` monotônico, `effective_pick_projection` com as unicidades impostas pelo banco, e um wrapper de transação atômica.

**Approach:** Um schema SQLite mínimo (5 tabelas) e um adapter fino (`R/adapter_sqlite_event_store.R`): `event_store_connect()` (aplica os `PRAGMA`), `event_store_init()` (`CREATE TABLE IF NOT EXISTS`, idempotente), `event_store_next_sequence()`, `event_store_transaction()` (wrapper `DBI::dbWithTransaction` que devolve `domain_error` no rollback) e `draft_session_started()`. O boot chama `event_store_init()`. O use case `start_draft()` é a Story 2.4.

## Boundaries & Constraints

**Always:**
- AD-8: SQLite é o único system of record local. `event_store_connect()` aplica `PRAGMA journal_mode=WAL` e `PRAGMA foreign_keys=ON`. `event_store_init()` roda `CREATE TABLE IF NOT EXISTS` das 5 tabelas — idempotente, sem runner de migrations nem histórico de migrations (Sprint Change Proposal 2026-08-31).
- Log de eventos **append-only**: o adapter só expõe `INSERT`/`SELECT` sobre `draft_event`, nunca `UPDATE`/`DELETE`. Schema com `UNIQUE(draft_id, event_sequence)`; `event_store_next_sequence()` devolve `max(event_sequence) + 1` (ou `1`) para o draft. Sem constraint de unicidade no histórico de jogador.
- `effective_pick_projection` impõe no schema `UNIQUE(draft_id, overall_pick)` e `UNIQUE(draft_id, player_id)`.
- AD-4: `event_store_transaction(con, fn)` executa `fn` dentro de uma transação; qualquer erro faz rollback e vira `domain_error("event_store_transacao_falhou")` — nada é commitado.
- Falha → `domain_error()` (`code` estável, mensagem PT-BR, `details`). Nunca exceção não tratada para o chamador.
- `draft_id` de texto imutável; `event_type` em `UPPER_SNAKE_CASE`; timestamps UTC ISO-8601; `event_sequence` é a ordem autoritativa, nunca o timestamp.
- Testes usam um banco SQLite temporário (`withr::local_tempfile(fileext = ".sqlite")`); a conexão é fechada no teardown.

**Ask First:**
- Se o schema precisar de coluna/tabela além das 5 listadas no Code Map para o Epic 3 não ter que alterar um schema já criado (ex.: `draft_slot` precisa de mais que `overall_pick`/`round`/`pick_in_round`/`fantasy_team_id`/`is_user_team`?).

**Never:**
- Não implementar `start_draft`/`record_pick`/`undo_last_pick`/`correct_pick`/`complete`/replay — Stories 2.4 e 3.4.
- Não construir superfície Shiny nem `Validate and Lock`.
- Não hashear estado nem config; sem `canonical_json_v1`; sem `expected_state_hash`/`previous_state_hash`/`resulting_state_hash`.
- Não criar índices/otimizações de performance além das `UNIQUE` exigidas; não usar ORM.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Conectar num banco novo | `event_store_connect(path)` | conexão `DBI` válida; `PRAGMA journal_mode` → `wal`; `PRAGMA foreign_keys` → `1` |
| Inicializar | `event_store_init(con)` | cria `draft_session`, `draft_slot`, `draft_event`, `effective_pick_projection`, `draft_state` |
| Inicializar de novo | `event_store_init(con)` numa 2ª vez (com dados) | sem erro, sem perda de dados (idempotente) |
| Próxima sequência, draft sem eventos | `event_store_next_sequence(con, "d1")` | `1` |
| Próxima sequência, draft com eventos 1..k | idem | `k + 1` |
| `event_sequence` repetido | `INSERT` de `(draft_id, event_sequence)` já existente | o banco recusa (`UNIQUE`) |
| Projeção com `overall_pick` ou `player_id` duplicado no mesmo draft | `INSERT` conflitante | o banco recusa (as duas `UNIQUE`) |
| Transação que conclui | `event_store_transaction(con, fn)` com `fn` que faz N inserts | todos os inserts commitados; devolve o valor de `fn` |
| Transação que falha no meio | `fn` lança / retorna erro após alguns inserts | rollback total; `domain_error("event_store_transacao_falhou")`; banco sem nenhum insert de `fn` |
| Sessão não iniciada | `draft_session_started(con, "inexistente")` | `FALSE` |
| Sessão presente | `draft_session_started(con, id)` com linha em `draft_session` | `TRUE` |

</frozen-after-approval>

## Code Map

- `inst/schema/event-store-v1.md` — **novo**, referência normativa (padrão de `inst/schema/snapshot-bundle-v1.md`): as 5 tabelas, colunas, PKs, `UNIQUE`, e uma nota do que a Story 2.4 / Epic 3 preenchem. A forma executável são as strings `CREATE TABLE IF NOT EXISTS` no adapter; os dois devem concordar.
- `R/adapter_sqlite_event_store.R` — **novo**. Único ponto de I/O de DB. `resolve_event_store_path(override = getOption("fdwr.event_store_path"))` (mirror de [resolve_snapshot_root()] em `R/adapter_files_snapshot.R:251`, default `tools::R_user_dir("fantasydraftwarroom", "data")/draft-store.sqlite`); `event_store_connect(path)`; `event_store_init(con)` (grava `PRAGMA user_version = 1`); `event_store_schema_version(con)`; `event_store_next_sequence(con, draft_id)`; `event_store_transaction(con, fn)`; `draft_session_started(con, draft_id)`; e o helper de boot `boot_event_store(override)` (resolve caminho + `dir.create` do diretório de dados + connect + init; devolve conexão ou `domain_error("event_store_indisponivel")`).
- `R/app_bootstrap.R` — **sem mudança**: o header "helpers puros do composition root, sem I/O" continua verdade; o helper de boot que faz I/O mora no adapter (`boot_event_store()`).
- `app.R` — `source()` do novo adapter + `boot_event_store()` no boot, depois da guarda de porta; `domain_error` → `message()` + `quit(1)`; `shiny::onStop()` fecha a conexão no shutdown. Não muda o fluxo de porta/host.
- `DESCRIPTION` — `DBI` e `RSQLite` em `Imports` (já no `renv.lock` após `renv::install("RSQLite")`).
- `NAMESPACE` — `export()` à mão (convenção Stories 1.5–2.2, ver `deferred-work.md`), ordem alfabética: `boot_event_store`, `draft_session_started`, `event_store_connect`, `event_store_init`, `event_store_next_sequence`, `event_store_schema_version`, `event_store_transaction`, `resolve_event_store_path`.
- `R/domain_errors.R` — `domain_error()`, `is_domain_error()`. Reusar.
- `tests/testthat/test-adapter_sqlite_event_store.R` — **novo**. Cobre toda a I/O & Edge-Case Matrix contra um SQLite temporário.
- Arquitetura: AD-4, AD-8; ER `DRAFT_SESSION ||--o{ DRAFT_SLOT / DRAFT_EVENT / EFFECTIVE_PICK_PROJECTION`; PRD FR51, FR52.

## Tasks & Acceptance

**Execution:**
- [x] `DESCRIPTION` — `DBI`, `RSQLite` em `Imports`.
- [x] `inst/schema/event-store-v1.md` — referência das 5 tabelas: `draft_session` (`draft_id` PK TEXT, `created_at` TEXT, `status` TEXT, `snapshot_id` TEXT, `snapshot_content_hash` TEXT, `scoring_identity` TEXT, `league_rules_json` TEXT, `engine_version` TEXT, `random_seed` INTEGER NULL); `draft_slot` (`draft_id` TEXT, `overall_pick` INTEGER, `round` INTEGER, `pick_in_round` INTEGER, `fantasy_team_id` TEXT, `is_user_team` INTEGER, PK `(draft_id, overall_pick)`, FK `draft_id`); `draft_event` (`draft_id` TEXT, `event_sequence` INTEGER, `event_type` TEXT, `payload_json` TEXT, `created_at` TEXT, `UNIQUE(draft_id, event_sequence)`, FK `draft_id`); `effective_pick_projection` (`draft_id` TEXT, `overall_pick` INTEGER, `player_id` TEXT, `UNIQUE(draft_id, overall_pick)`, `UNIQUE(draft_id, player_id)`, FK `draft_id`); `draft_state` (`draft_id` TEXT PK, `status` TEXT, `next_overall_pick` INTEGER, FK `draft_id`).
- [x] `R/adapter_sqlite_event_store.R` — as 6 funções do Code Map. `event_store_connect()` aplica os dois `PRAGMA`. `event_store_init()` idempotente. `event_store_next_sequence()` = `SELECT COALESCE(MAX(event_sequence), 0) + 1`. `event_store_transaction()` embrulha `DBI::dbWithTransaction`, captura qualquer erro/`domain_error` retornado por `fn` e converte em `domain_error("event_store_transacao_falhou", details = list(causa = <mensagem>))` após o rollback.
- [x] `R/app_bootstrap.R` + `app.R` — compor caminho + `event_store_connect()` + `event_store_init()` no boot; `source()` do novo arquivo.
- [x] `NAMESPACE` — `export()` das 6 funções.
- [x] `tests/testthat/test-adapter_sqlite_event_store.R` — cobre a I/O & Edge-Case Matrix; usa `withr::local_tempfile`; fecha a conexão no teardown; afirma idempotência do `init` (roda 2×, insere linha entre as chamadas, confirma que sobrevive).

**Acceptance Criteria:**
- Given um caminho de banco novo, when `event_store_connect()` + `event_store_init()` rodam, then a conexão tem `journal_mode = wal` e `foreign_keys` ligado, e as 5 tabelas existem.
- Given um banco já inicializado com dados, when `event_store_init()` roda de novo, then não há erro e nenhum dado é perdido.
- Given o `draft_event` de um draft, when eventos são anexados via `INSERT`, then `event_store_next_sequence()` devolve valores monotônicos crescentes (1, 2, 3…) e o schema recusa um `(draft_id, event_sequence)` repetido.
- Given a `effective_pick_projection`, when se tenta inserir `overall_pick` ou `player_id` repetido no mesmo `draft_id`, then o banco recusa.
- Given `event_store_transaction(con, fn)` cujo `fn` falha após inserts parciais, when a transação aborta, then o banco não contém nenhum dos inserts e o retorno é `domain_error("event_store_transacao_falhou")`.

## Design Notes

- **Wrapper de transação, não transação manual:** `DBI::dbWithTransaction()` já faz `BEGIN`/`COMMIT`/`ROLLBACK` e re-lança. `event_store_transaction()` só adiciona: (1) tratar um `domain_error` **retornado** por `fn` como falha (força rollback com `DBI::dbBreak()`), (2) converter a exceção num `domain_error` estável. Assim a Story 2.4 escreve `start_draft` como um `fn` que faz os 4 grupos de insert e não precisa saber de SQL de transação.
- **`is_user_team` como INTEGER:** SQLite não tem BOOLEAN; grava `0`/`1`. O adapter converte na leitura se expuser leitura de slots (Epic 4).
- **`league_rules_json` é conveniência de storage:** `jsonlite::toJSON` dos valores resolvidos de `parse_league_config()`; não é contrato de bytes (Sprint Change Proposal removeu hashes de config).

## Verification

**Commands:**
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint_package()'` — sem lint nos arquivos novos.
- `Rscript -e 'devtools::load_all(); p <- withr::local_tempfile(fileext=".sqlite"); con <- event_store_connect(p); event_store_init(con); print(DBI::dbGetQuery(con, "PRAGMA journal_mode")); print(sort(DBI::dbListTables(con)))'` — `wal` e as 5 tabelas.

## Suggested Review Order

**Schema — o contrato de dados**

- Ponto de entrada: as 5 tabelas como strings `CREATE TABLE IF NOT EXISTS`, PKs, as 3 `UNIQUE` de AD-8, FKs para `draft_session`, `CHECK (is_user_team IN (0,1))`.
  [`adapter_sqlite_event_store.R:14`](../../R/adapter_sqlite_event_store.R#L14)
- Referência normativa em prosa; o teste de colunas força os dois a concordarem.
  [`event-store-v1.md:1`](../../inst/schema/event-store-v1.md#L1)

**Adapter — I/O e atomicidade**

- Wrapper de transação: `dbWithTransaction` + carrega a falha (throw ou `domain_error` retornado) pra fora via `env` box, converte em `domain_error("event_store_transacao_falhou")` após rollback.
  [`adapter_sqlite_event_store.R:163`](../../R/adapter_sqlite_event_store.R#L163)
- `connect`: pragmas WAL + foreign_keys, `warning()` se WAL não pegou.
  [`adapter_sqlite_event_store.R:94`](../../R/adapter_sqlite_event_store.R#L94)
- `init` idempotente + stamp `PRAGMA user_version = 1` (Epic 3 detecta DB v1).
  [`adapter_sqlite_event_store.R:114`](../../R/adapter_sqlite_event_store.R#L114)
- `next_sequence`: read-then-write não-atômico; teto de escritor único no `# ponytail:`.
  [`adapter_sqlite_event_store.R:141`](../../R/adapter_sqlite_event_store.R#L141)
- Helper de boot: resolve caminho + `dir.create` + connect + init; `domain_error("event_store_indisponivel")` e não vaza conexão se `init` falha.
  [`adapter_sqlite_event_store.R:222`](../../R/adapter_sqlite_event_store.R#L222)

**Wiring de boot**

- `boot_event_store()` após a guarda de porta; `onStop` fecha a conexão (checkpoint do WAL) no shutdown.
  [`app.R:51`](../../app.R#L51)

**Periféricos**

- 8 exports à mão; `DBI`/`RSQLite` em Imports.
  [`NAMESPACE:2`](../../NAMESPACE#L2)
- Testes: FK observada, colunas via `dbListFields`, `draft_slot` PK+CHECK, branches de falha do boot.
  [`test-adapter_sqlite_event_store.R:112`](../../tests/testthat/test-adapter_sqlite_event_store.R#L112)
- Defer pra Story 2.4: `event_store_transaction` preservar `code`/`details` do `domain_error` original.
  [`deferred-work.md:127`](./deferred-work.md#L127)
