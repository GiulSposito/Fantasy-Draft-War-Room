# I/O & Edge-Case Matrix do event store SQLite (spec Story 2.3).

# Abre um event store temporario ja inicializado; fecha no teardown.
local_event_store <- function(envir = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".sqlite", .local_envir = envir)
  con <- event_store_connect(path)
  withr::defer(DBI::dbDisconnect(con), envir = envir)
  event_store_init(con)
  con
}

# Insere uma linha minima em draft_session (pai das FKs).
seed_session <- function(con, draft_id) {
  DBI::dbExecute(
    con,
    "INSERT INTO draft_session (draft_id, created_at) VALUES (?, ?)",
    params = list(draft_id, "2026-08-31T00:00:00Z")
  )
}

append_event <- function(con, draft_id, seq) {
  DBI::dbExecute(
    con,
    "INSERT INTO draft_event (draft_id, event_sequence, event_type, payload_json, created_at)
     VALUES (?, ?, ?, ?, ?)",
    params = list(draft_id, seq, "TEST_EVENT", "{}", "2026-08-31T00:00:00Z")
  )
}

test_that("connect: PRAGMA WAL e foreign_keys ligados", {
  path <- withr::local_tempfile(fileext = ".sqlite")
  con <- event_store_connect(path)
  withr::defer(DBI::dbDisconnect(con))

  expect_true(DBI::dbIsValid(con))
  expect_identical(DBI::dbGetQuery(con, "PRAGMA journal_mode")[[1]], "wal")
  expect_identical(DBI::dbGetQuery(con, "PRAGMA foreign_keys")[[1]], 1L)
})

test_that("connect: caminho invalido -> erro de contrato", {
  expect_error(event_store_connect(character(0)))
  expect_error(event_store_connect(c("a", "b")))
  expect_error(event_store_connect(""))
})

test_that("init: cria as 5 tabelas e grava user_version = 1", {
  con <- local_event_store()
  expect_setequal(
    DBI::dbListTables(con),
    c("draft_session", "draft_slot", "draft_event", "effective_pick_projection", "draft_state")
  )
  expect_identical(event_store_schema_version(con), 1L)
})

test_that("schema: colunas de cada tabela batem com event-store-v1.md", {
  con <- local_event_store()
  expected <- list(
    draft_session = c(
      "draft_id", "created_at", "snapshot_id", "snapshot_content_hash",
      "scoring_identity", "league_rules_json", "engine_version", "random_seed"
    ),
    draft_slot = c(
      "draft_id", "overall_pick", "round", "pick_in_round", "fantasy_team_id",
      "is_user_team"
    ),
    draft_event = c("draft_id", "event_sequence", "event_type", "payload_json", "created_at"),
    effective_pick_projection = c("draft_id", "overall_pick", "player_id"),
    draft_state = c("draft_id", "status", "next_overall_pick")
  )
  for (tbl in names(expected)) {
    expect_identical(DBI::dbListFields(con, tbl), expected[[tbl]], info = tbl)
  }
})

test_that("init: idempotente -- roda 2x, dados entre as chamadas sobrevivem", {
  con <- local_event_store()
  seed_session(con, "d1")
  expect_silent(event_store_init(con))

  rows <- DBI::dbGetQuery(con, "SELECT draft_id FROM draft_session")
  expect_identical(rows$draft_id, "d1")
})

test_that("next_sequence: draft sem eventos -> 1", {
  con <- local_event_store()
  expect_identical(event_store_next_sequence(con, "d1"), 1L)
})

test_that("next_sequence: draft com eventos 1..k -> k+1, monotonico", {
  con <- local_event_store()
  seed_session(con, "d1")
  seed_session(con, "outro")
  append_event(con, "outro", 1L) # nao conta para "d1"

  seqs <- integer(0)
  for (i in 1:4) {
    s <- event_store_next_sequence(con, "d1")
    seqs <- c(seqs, s)
    append_event(con, "d1", s)
  }
  expect_identical(seqs, 1:4)
  expect_identical(event_store_next_sequence(con, "d1"), 5L)
})

test_that("draft_event: (draft_id, event_sequence) repetido -> banco recusa", {
  con <- local_event_store()
  seed_session(con, "d1")
  append_event(con, "d1", 1L)
  expect_error(append_event(con, "d1", 1L), regexp = "UNIQUE|constraint")
})

test_that("FK observada: draft_event / effective_pick_projection sem sessao pai -> recusa", {
  con <- local_event_store()
  expect_error(append_event(con, "fantasma", 1L), regexp = "FOREIGN KEY|constraint")
  expect_error(
    DBI::dbExecute(
      con,
      "INSERT INTO effective_pick_projection (draft_id, overall_pick, player_id) VALUES (?, ?, ?)",
      params = list("fantasma", 1L, "p1")
    ),
    regexp = "FOREIGN KEY|constraint"
  )
})

test_that("draft_slot: PK composta recusa duplicata; CHECK recusa is_user_team = 2", {
  con <- local_event_store()
  seed_session(con, "d1")
  slot <- function(pick, team, is_user) {
    DBI::dbExecute(
      con,
      "INSERT INTO draft_slot
         (draft_id, overall_pick, round, pick_in_round, fantasy_team_id, is_user_team)
       VALUES (?, ?, ?, ?, ?, ?)",
      params = list("d1", pick, 1L, pick, team, is_user)
    )
  }
  slot(1L, "t1", 1L)
  slot(2L, "t2", 0L)
  expect_error(slot(1L, "t3", 0L), regexp = "PRIMARY KEY|UNIQUE|constraint")
  expect_error(slot(3L, "t3", 2L), regexp = "CHECK|constraint")
})

test_that("effective_pick_projection: overall_pick ou player_id repetido -> banco recusa", {
  con <- local_event_store()
  seed_session(con, "d1")
  ins <- function(pick, player) {
    DBI::dbExecute(
      con,
      "INSERT INTO effective_pick_projection (draft_id, overall_pick, player_id) VALUES (?, ?, ?)",
      params = list("d1", pick, player)
    )
  }
  ins(1L, "p1")
  expect_error(ins(1L, "p2"), regexp = "UNIQUE|constraint") # overall_pick dup
  expect_error(ins(2L, "p1"), regexp = "UNIQUE|constraint") # player_id dup
  ins(2L, "p2") # ok
  expect_identical(
    DBI::dbGetQuery(con, "SELECT COUNT(*) FROM effective_pick_projection")[[1]],
    2L
  )
})

test_that("transaction: conclui -> commita todos os inserts e devolve o valor de fn", {
  con <- local_event_store()
  out <- event_store_transaction(con, function(c) {
    seed_session(c, "d1")
    append_event(c, "d1", 1L)
    append_event(c, "d1", 2L)
    "ok"
  })
  expect_identical(out, "ok")
  expect_identical(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM draft_event")[[1]], 2L)
})

test_that("transaction: fn lanca apos inserts parciais -> rollback total + domain_error", {
  con <- local_event_store()
  out <- event_store_transaction(con, function(c) {
    seed_session(c, "d1")
    append_event(c, "d1", 1L)
    stop("boom")
  })
  expect_true(is_domain_error(out))
  expect_identical(out$code, "event_store_transacao_falhou")
  expect_match(out$details$causa, "boom")
  expect_identical(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM draft_session")[[1]], 0L)
  expect_identical(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM draft_event")[[1]], 0L)
})

test_that("transaction: fn RETORNA domain_error -> rollback total + domain_error", {
  con <- local_event_store()
  out <- event_store_transaction(con, function(c) {
    seed_session(c, "d1")
    domain_error("regra_violada", "nao pode")
  })
  expect_true(is_domain_error(out))
  expect_identical(out$code, "event_store_transacao_falhou")
  expect_match(out$details$causa, "nao pode")
  expect_identical(DBI::dbGetQuery(con, "SELECT COUNT(*) FROM draft_session")[[1]], 0L)
})

test_that("draft_session_started: ausente -> FALSE, presente -> TRUE", {
  con <- local_event_store()
  expect_false(draft_session_started(con, "inexistente"))
  seed_session(con, "d1")
  expect_true(draft_session_started(con, "d1"))
})

test_that("resolve_event_store_path: override vence; sem override cai no R_user_dir", {
  p <- withr::local_tempfile(fileext = ".sqlite")
  expect_identical(resolve_event_store_path(p), path.expand(p))
  expect_match(resolve_event_store_path(NULL), "draft-store\\.sqlite$")
})

test_that("resolve_event_store_path: override degenerado -> erro de contrato", {
  expect_error(resolve_event_store_path(c("a", "b")))
  expect_error(resolve_event_store_path(NA_character_))
})

test_that("boot_event_store: compoe caminho, conecta e inicializa", {
  path <- withr::local_tempfile(fileext = ".sqlite")
  con <- boot_event_store(path)
  withr::defer(DBI::dbDisconnect(con))

  expect_false(is_domain_error(con))
  expect_setequal(
    DBI::dbListTables(con),
    c("draft_session", "draft_slot", "draft_event", "effective_pick_projection", "draft_state")
  )
})

test_that("boot_event_store: diretorio nao-criavel -> domain_error event_store_indisponivel", {
  f <- withr::local_tempfile(fileext = ".sqlite")
  file.create(f) # arquivo onde boot espera poder criar um diretorio
  out <- boot_event_store(file.path(f, "sub", "draft-store.sqlite"))
  expect_true(is_domain_error(out))
  expect_identical(out$code, "event_store_indisponivel")
})
