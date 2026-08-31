# Adapter do event store SQLite (shell imperativo).
#
# UNICO ponto que abre o banco SQLite e chama DBI/RSQLite. Expoe apenas
# INSERT/SELECT sobre o log de eventos (append-only, nunca UPDATE/DELETE).
# A forma executavel do schema sao as strings CREATE TABLE IF NOT EXISTS em
# `event_store_schema` -- devem concordar com `inst/schema/event-store-v1.md`.
# Story 2.4 (`start_draft`) e o Epic 3 (picks/undo/replay) e que PREENCHEM as
# tabelas; aqui e so criar o schema e os primitivos de sequencia/transacao.

# Versao do schema, gravada em `PRAGMA user_version` por `event_store_init()`.
event_store_schema_v <- 1L

# DDL das 5 tabelas, na ordem de criacao (FK aponta para `draft_session`).
event_store_schema <- c(
  draft_session = "
    CREATE TABLE IF NOT EXISTS draft_session (
      draft_id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      snapshot_id TEXT,
      snapshot_content_hash TEXT,
      scoring_identity TEXT,
      league_rules_json TEXT,
      engine_version TEXT,
      random_seed INTEGER
    )",
  draft_slot = "
    CREATE TABLE IF NOT EXISTS draft_slot (
      draft_id TEXT NOT NULL REFERENCES draft_session(draft_id),
      overall_pick INTEGER NOT NULL,
      round INTEGER NOT NULL,
      pick_in_round INTEGER NOT NULL,
      fantasy_team_id TEXT NOT NULL,
      is_user_team INTEGER NOT NULL CHECK (is_user_team IN (0, 1)),
      PRIMARY KEY (draft_id, overall_pick)
    )",
  draft_event = "
    CREATE TABLE IF NOT EXISTS draft_event (
      draft_id TEXT NOT NULL REFERENCES draft_session(draft_id),
      event_sequence INTEGER NOT NULL,
      event_type TEXT NOT NULL,
      payload_json TEXT,
      created_at TEXT NOT NULL,
      UNIQUE (draft_id, event_sequence)
    )",
  effective_pick_projection = "
    CREATE TABLE IF NOT EXISTS effective_pick_projection (
      draft_id TEXT NOT NULL REFERENCES draft_session(draft_id),
      overall_pick INTEGER NOT NULL,
      player_id TEXT NOT NULL,
      UNIQUE (draft_id, overall_pick),
      UNIQUE (draft_id, player_id)
    )",
  draft_state = "
    CREATE TABLE IF NOT EXISTS draft_state (
      draft_id TEXT PRIMARY KEY REFERENCES draft_session(draft_id),
      status TEXT NOT NULL,
      next_overall_pick INTEGER
    )"
)

#' Resolve o caminho do arquivo do event store
#'
#' Mirror de [resolve_snapshot_root()]: um override explicito vence; sem ele
#' cai no diretorio de dados do usuario. O default le
#' `getOption("fdwr.event_store_path")`.
#'
#' @param override Caminho explicito (string unica) ou `NULL`. Default: o valor
#'   de `getOption("fdwr.event_store_path")`.
#' @return `override` expandido (`path.expand`), ou
#'   `tools::R_user_dir("fantasydraftwarroom", "data")/draft-store.sqlite`.
#' @export
resolve_event_store_path <- function(override = getOption("fdwr.event_store_path")) {
  stopifnot(
    is.null(override) ||
      (is.character(override) && length(override) == 1L && !is.na(override))
  )
  if (!is.null(override) && nzchar(override)) {
    return(path.expand(override))
  }
  file.path(tools::R_user_dir("fantasydraftwarroom", "data"), "draft-store.sqlite")
}

#' Abre uma conexao com o event store SQLite
#'
#' Aplica `PRAGMA journal_mode=WAL` e `PRAGMA foreign_keys=ON`. RSQLite cria o
#' **arquivo** se nao existir, mas nao o diretorio pai -- o chamador garante o
#' diretorio (ver [boot_event_store()]). O chamador e dono da conexao e deve
#' fecha-la (`DBI::dbDisconnect`).
#'
#' @param path Caminho do arquivo SQLite.
#' @return Uma conexao `DBI`. Emite `warning()` se o modo WAL nao pegou (o banco
#'   ainda funciona em rollback-journal).
#' @export
event_store_connect <- function(path) {
  stopifnot(is.character(path), length(path) == 1L, nzchar(path))
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  mode <- DBI::dbGetQuery(con, "PRAGMA journal_mode=WAL")[[1]]
  if (!identical(tolower(mode), "wal")) {
    warning(sprintf("event store nao entrou em modo WAL (journal_mode=%s).", mode))
  }
  DBI::dbExecute(con, "PRAGMA foreign_keys=ON")
  con
}

#' Cria as 5 tabelas do event store (idempotente)
#'
#' `CREATE TABLE IF NOT EXISTS` das 5 tabelas + `PRAGMA user_version = 1`. Sem
#' runner de migrations, sem historico de migrations. Rodar de novo num banco
#' com dados nao apaga nada.
#'
#' @param con Conexao de [event_store_connect()].
#' @return `con`, invisivel.
#' @export
event_store_init <- function(con) {
  for (ddl in event_store_schema) {
    DBI::dbExecute(con, ddl)
  }
  DBI::dbExecute(con, sprintf("PRAGMA user_version = %d", event_store_schema_v))
  invisible(con)
}

#' Versao do schema gravada no banco
#'
#' @param con Conexao do event store.
#' @return `PRAGMA user_version` como inteiro (`0` num banco nunca inicializado).
#'   ponytail: so o stamp; a checagem de mismatch e da story que primeiro mudar
#'   o schema (Epic 3).
#' @export
event_store_schema_version <- function(con) {
  as.integer(DBI::dbGetQuery(con, "PRAGMA user_version")[[1]])
}

#' Proxima `event_sequence` de um draft
#'
#' @param con Conexao do event store.
#' @param draft_id Id de texto do draft.
#' @return `max(event_sequence) + 1` para o draft, ou `1` se ele nao tem eventos.
#'   ponytail: read-then-write nao-atomico; assume escritor unico (processo
#'   Shiny local) chamando dentro de `event_store_transaction`.
#' @export
event_store_next_sequence <- function(con, draft_id) {
  stopifnot(is.character(draft_id), length(draft_id) == 1L, nzchar(draft_id))
  row <- DBI::dbGetQuery(
    con,
    "SELECT COALESCE(MAX(event_sequence), 0) + 1 AS next_seq FROM draft_event WHERE draft_id = ?",
    params = list(draft_id)
  )
  as.integer(row$next_seq)
}

#' Executa `fn` dentro de uma transacao atomica
#'
#' Embrulha [DBI::dbWithTransaction()]. `fn(con)` faz os inserts; qualquer erro
#' lancado, ou um [domain_error()] *retornado* por `fn`, forca rollback total e
#' vira `domain_error("event_store_transacao_falhou")` -- nada e commitado. Se
#' `fn` retorna normalmente, devolve o valor de `fn` e a transacao commita.
#'
#' @param con Conexao do event store.
#' @param fn Funcao `function(con) { ... }`.
#' @return O valor de `fn`; ou `domain_error("event_store_transacao_falhou")`
#'   (`details$causa` = mensagem da falha).
#' @export
event_store_transaction <- function(con, fn) {
  stopifnot(is.function(fn))
  # Environment (reference semantics) para carregar a falha para fora da
  # transacao: apos `dbBreak()`, `dbWithTransaction()` devolve `NULL` e nao ha
  # como distinguir isso de um retorno legitimo pelo valor.
  box <- new.env(parent = emptyenv())
  box$err <- NULL
  result <- tryCatch(
    DBI::dbWithTransaction(con, {
      value <- fn(con)
      if (is_domain_error(value)) {
        box$err <- value
        DBI::dbBreak()
      }
      value
    }),
    error = function(e) {
      box$err <- e
      e
    }
  )
  if (!is.null(box$err)) {
    return(domain_error(
      "event_store_transacao_falhou",
      "A transacao do event store falhou; nenhuma alteracao foi gravada.",
      list(causa = conditionMessage(box$err))
    ))
  }
  result
}

#' A sessao de um draft ja foi iniciada?
#'
#' @param con Conexao do event store.
#' @param draft_id Id de texto do draft.
#' @return `TRUE` se ha uma linha em `draft_session` para `draft_id`.
#' @export
draft_session_started <- function(con, draft_id) {
  stopifnot(is.character(draft_id), length(draft_id) == 1L, nzchar(draft_id))
  row <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM draft_session WHERE draft_id = ?",
    params = list(draft_id)
  )
  row$n > 0L
}

#' Compoe o caminho do event store e abre + inicializa o banco no boot
#'
#' Shell do bootstrap: resolve o caminho, garante o diretorio de dados (RSQLite
#' so cria o arquivo), conecta (aplica os PRAGMA) e roda o
#' `CREATE TABLE IF NOT EXISTS`. O `app.R` (shell) so decide o que fazer com um
#' [domain_error()].
#'
#' @param override Caminho explicito (`getOption("fdwr.event_store_path")`) ou
#'   `NULL` para o default de [resolve_event_store_path()].
#' @return Conexao `DBI` inicializada; ou um [domain_error()]
#'   `"event_store_indisponivel"` (`details$causa`).
#' @export
boot_event_store <- function(override = getOption("fdwr.event_store_path")) {
  path <- resolve_event_store_path(override)
  dir <- dirname(path)
  if (!dir.exists(dir) && !dir.create(dir, recursive = TRUE, showWarnings = FALSE)) {
    return(domain_error(
      "event_store_indisponivel",
      sprintf("Nao foi possivel criar o diretorio do event store: %s.", dir),
      list(causa = "dir_create_falhou", dir = dir)
    ))
  }
  con <- tryCatch(event_store_connect(path), error = function(e) e)
  if (inherits(con, "error")) {
    return(domain_error(
      "event_store_indisponivel",
      sprintf("Nao foi possivel abrir o event store em %s.", path),
      list(causa = conditionMessage(con), path = path)
    ))
  }
  init <- tryCatch(event_store_init(con), error = function(e) e)
  if (inherits(init, "error")) {
    try(DBI::dbDisconnect(con), silent = TRUE)
    return(domain_error(
      "event_store_indisponivel",
      sprintf("Nao foi possivel inicializar o event store em %s.", path),
      list(causa = conditionMessage(init), path = path)
    ))
  }
  con
}
