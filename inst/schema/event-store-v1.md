# Event store SQLite — schema V1

Referência normativa das 5 tabelas do event store local. A forma **executável**
deste documento são as strings `CREATE TABLE IF NOT EXISTS` em
`R/adapter_sqlite_event_store.R` (`event_store_schema`) — os dois devem concordar.

O banco é um único arquivo SQLite em
`tools::R_user_dir("fantasydraftwarroom", "data")/draft-store.sqlite`
(`resolve_event_store_path()`). `event_store_connect()` aplica
`PRAGMA journal_mode=WAL` e `PRAGMA foreign_keys=ON`; `event_store_init()` roda o
DDL abaixo, grava `PRAGMA user_version = 1` (lido por
`event_store_schema_version()`; o Epic 3 detecta bancos v1 por ele), é idempotente
(`CREATE TABLE IF NOT EXISTS`) e não tem runner nem histórico de migrations
(Sprint Change Proposal 2026-08-31).

O log de eventos é **append-only**: o adapter só expõe `INSERT`/`SELECT` sobre
`draft_event`, nunca `UPDATE`/`DELETE`. Não há constraint de unicidade no
histórico de jogador. `event_sequence` é a ordem autoritativa dos eventos de um
draft, nunca o timestamp.

## `draft_session`

Uma linha por sessão de draft. Escrita uma vez pelo `DRAFT_STARTED` (Story 2.4);
congela a proveniência. O estado da sessão vive só em `draft_state.status` (não
há coluna de status duplicada aqui).

| Coluna | Tipo | Notas |
|---|---|---|
| `draft_id` | TEXT | **PK**. Id de texto imutável |
| `created_at` | TEXT | Timestamp UTC ISO-8601 |
| `snapshot_id` | TEXT | Do snapshot bundle (Epic 1) |
| `snapshot_content_hash` | TEXT | `snapshot_content_hash` do bundle (Epic 1) |
| `scoring_identity` | TEXT | Identidade do scoring exibida (não re-pontua) |
| `league_rules_json` | TEXT | `jsonlite::toJSON` dos valores resolvidos de `parse_league_config()` — conveniência de storage, não contrato de bytes |
| `engine_version` | TEXT | Versão do engine no `start` |
| `random_seed` | INTEGER NULL | Seed opcional do sorteio de ordem |

## `draft_slot`

Um slot do calendário snake por linha. Preenchida pela Story 2.4 a partir de
`snake_schedule()`.

| Coluna | Tipo | Notas |
|---|---|---|
| `draft_id` | TEXT | FK → `draft_session(draft_id)` |
| `overall_pick` | INTEGER | Overall pick contínuo (1..N) |
| `round` | INTEGER | Rodada |
| `pick_in_round` | INTEGER | Pick dentro da rodada |
| `fantasy_team_id` | TEXT | Id de texto imutável do time |
| `is_user_team` | INTEGER | `0`/`1`, **`CHECK (is_user_team IN (0,1))`** (SQLite não tem BOOLEAN); o adapter converte na leitura se expuser slots (Epic 4) |

**PK** `(draft_id, overall_pick)`.

## `draft_event`

Log append-only. Preenchida pela Story 2.4 (`DRAFT_STARTED`) e pelo Epic 3
(picks / undo / correção).

| Coluna | Tipo | Notas |
|---|---|---|
| `draft_id` | TEXT | FK → `draft_session(draft_id)` |
| `event_sequence` | INTEGER | Monotônico por draft; `event_store_next_sequence()` devolve `max + 1` (ou `1`) |
| `event_type` | TEXT | `UPPER_SNAKE_CASE` |
| `payload_json` | TEXT | Payload serializado do evento |
| `created_at` | TEXT | Timestamp UTC ISO-8601 |

**`UNIQUE(draft_id, event_sequence)`** — o banco recusa uma sequência repetida.

## `effective_pick_projection`

Projeção materializada dos picks efetivos. Substituída na mesma transação do
evento pelo Epic 3.

| Coluna | Tipo | Notas |
|---|---|---|
| `draft_id` | TEXT | FK → `draft_session(draft_id)` |
| `overall_pick` | INTEGER | |
| `player_id` | TEXT | |

**`UNIQUE(draft_id, overall_pick)`** e **`UNIQUE(draft_id, player_id)`** — o banco
impõe pick único e jogador único por draft.

## `draft_state`

Estado derivado corrente da sessão. Substituído na mesma transação pelo Epic 3.

| Coluna | Tipo | Notas |
|---|---|---|
| `draft_id` | TEXT | **PK**. FK → `draft_session(draft_id)` |
| `status` | TEXT | Vocabulário: `DRAFTING` (sessão em andamento), `COMPLETED` (transição terminal única — a arquitetura não tem `abort`) |
| `next_overall_pick` | INTEGER | Próximo overall pick a registrar |
