# I/O & Edge-Case Matrix de start_draft (spec Story 2.4), contra SQLite temporario.

make_teams <- function(n = 12L, user = 1L) {
  lapply(seq_len(n), function(i) {
    list(
      fantasy_team_id = sprintf("t%02d", i),
      display_name = sprintf("Team %d", i),
      is_user = i == user
    )
  })
}

team_ids <- function(n = 12L) sprintf("t%02d", seq_len(n))

codes <- function(x) vapply(x, function(f) f$code, character(1L))

good_meta <- list(
  snapshot_id = "snap-2025-20260101T000000Z",
  content_hash = "sha256:abc123",
  scoring_hash = "sha256:scoring99"
)

fixed_clock <- function(when = "2026-08-31 12:00:00") {
  function() as.POSIXct(when, tz = "UTC")
}

local_event_store <- function(envir = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".sqlite", .local_envir = envir)
  con <- event_store_connect(path)
  withr::defer(DBI::dbDisconnect(con), envir = envir)
  event_store_init(con)
  con
}

run_ok <- function(con, ..., seed = NULL, clock = fixed_clock()) {
  start_draft(
    con, good_meta, reference_league_config(), make_teams(), team_ids(),
    seed = seed, clock = clock, engine_version = "9.9", ...
  )
}

count <- function(con, tbl) {
  DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", tbl))$n
}

expect_empty_store <- function(con) {
  for (tbl in c("draft_session", "draft_slot", "draft_event", "draft_state")) {
    testthat::expect_identical(count(con, tbl), 0L, info = tbl)
  }
}

test_that("start viavel: materializa os 4 grupos numa transacao", {
  con <- local_event_store()
  out <- run_ok(con, seed = 123L)

  expect_true(out$ok)
  expect_identical(out$draft_id, "draft-20260831T120000Z")

  expect_identical(count(con, "draft_session"), 1L)
  expect_identical(count(con, "draft_slot"), 180L) # 12 times * 15 rounds
  expect_identical(count(con, "draft_event"), 1L)
  expect_identical(count(con, "draft_state"), 1L)

  sess <- DBI::dbGetQuery(con, "SELECT * FROM draft_session")
  expect_identical(sess$snapshot_id, good_meta$snapshot_id)
  expect_identical(sess$snapshot_content_hash, good_meta$content_hash)
  expect_identical(sess$scoring_identity, good_meta$scoring_hash)
  expect_identical(sess$engine_version, "9.9")
  expect_identical(as.integer(sess$random_seed), 123L)
  expect_identical(jsonlite::fromJSON(sess$league_rules_json)$rounds, 15L)

  ev <- DBI::dbGetQuery(con, "SELECT * FROM draft_event")
  expect_identical(ev$event_type, "DRAFT_STARTED")
  expect_identical(ev$event_sequence, 1L)
  expect_identical(jsonlite::fromJSON(ev$payload_json)$snapshot_id, good_meta$snapshot_id)

  st <- DBI::dbGetQuery(con, "SELECT * FROM draft_state")
  expect_identical(st$status, "DRAFTING")
  expect_identical(st$next_overall_pick, 1L)
})

test_that("draft_slot segue a ordem snake, overall_pick continuo 1..180", {
  con <- local_event_store()
  run_ok(con)
  slots <- DBI::dbGetQuery(
    con, "SELECT * FROM draft_slot ORDER BY overall_pick"
  )
  expect_identical(slots$overall_pick, 1:180)

  r1 <- slots$fantasy_team_id[slots$round == 1L]
  r2 <- slots$fantasy_team_id[slots$round == 2L]
  expect_identical(r1, team_ids())
  expect_identical(r2, rev(team_ids())) # round par = inverso do impar

  # pick 1 e pick 24 (fim do round 2) sao do mesmo time no snake
  expect_identical(slots$fantasy_team_id[1L], slots$fantasy_team_id[24L])
  expect_identical(slots$fantasy_team_id[1L], "t01")

  user_slots <- unique(slots$fantasy_team_id[slots$is_user_team == 1L])
  expect_identical(user_slots, "t01")
})

test_that("DRAFT_STARTED persistido: payload_json reflete a proveniencia congelada", {
  con <- local_event_store()
  run_ok(con, seed = 77L)
  payload <- jsonlite::fromJSON(
    DBI::dbGetQuery(con, "SELECT payload_json FROM draft_event")$payload_json
  )
  expect_identical(payload$scoring_identity, good_meta$scoring_hash)
  expect_identical(payload$engine_version, "9.9")
  expect_identical(payload$random_seed, 77L)
  expect_identical(jsonlite::fromJSON(payload$league_rules_json)$rounds, 15L)
})

test_that("engine_version default: grava a versao do pacote (string nao-vazia)", {
  con <- local_event_store()
  out <- start_draft(
    con, good_meta, reference_league_config(), make_teams(), team_ids(),
    clock = fixed_clock()
  )
  expect_true(out$ok)
  ver <- DBI::dbGetQuery(con, "SELECT engine_version FROM draft_session")$engine_version
  expect_true(is.character(ver) && length(ver) == 1L && nzchar(ver))
})

test_that("envelope invalido -> ok = FALSE, bloqueios, nenhum INSERT", {
  con <- local_event_store()
  cfg <- reference_league_config()
  cfg$teams <- 7L
  out <- start_draft(con, good_meta, cfg, make_teams(7L), team_ids(7L), clock = fixed_clock())

  expect_false(out$ok)
  expect_true("league_times_fora_do_envelope" %in% codes(out$bloqueios))
  expect_identical(out$bloqueios[[1L]]$details$grupo, "times_rounds")
  expect_empty_store(con)
})

test_that("ordem incompleta / duplicada / com id a mais -> ok = FALSE, nada gravado", {
  con <- local_event_store()
  bad_orders <- list(
    faltando = team_ids()[-4L],
    duplicado = c(team_ids()[-1L], "t02"),
    a_mais = c(team_ids(), "t13")
  )
  for (nm in names(bad_orders)) {
    out <- start_draft(
      con, good_meta, reference_league_config(), make_teams(), bad_orders[[nm]],
      clock = fixed_clock()
    )
    expect_false(out$ok, info = nm)
    expect_true("snake_ordem_invalida" %in% codes(out$bloqueios), info = nm)
  }
  expect_empty_store(con)
})

test_that("time do operador != 1 -> ok = FALSE, nada gravado", {
  con <- local_event_store()
  out <- start_draft(
    con, good_meta, reference_league_config(), make_teams(user = 0L), team_ids(),
    clock = fixed_clock()
  )
  expect_false(out$ok)
  expect_true("league_teams_usuario_invalido" %in% codes(out$bloqueios))
  expect_empty_store(con)
})

test_that("league_config e domain_error -> devolve o mesmo domain_error", {
  con <- local_event_store()
  err <- domain_error("league_config_malformado", "upstream falhou")
  out <- start_draft(con, good_meta, err, make_teams(), team_ids(), clock = fixed_clock())
  expect_identical(out, err)
  expect_empty_store(con)
})

test_that("snapshot_metadata degenerado -> domain_error start_snapshot_proveniencia_invalida", {
  con <- local_event_store()

  # falta content_hash
  out <- start_draft(
    con, list(snapshot_id = "s"), reference_league_config(), make_teams(), team_ids(),
    clock = fixed_clock()
  )
  expect_true(is_domain_error(out))
  expect_identical(out$code, "start_snapshot_proveniencia_invalida")
  expect_identical(out$details$campo, "content_hash")

  # data.frame -> campo NA
  out_df <- start_draft(
    con, as.data.frame(good_meta), reference_league_config(), make_teams(), team_ids(),
    clock = fixed_clock()
  )
  expect_true(is_domain_error(out_df))
  expect_identical(out_df$code, "start_snapshot_proveniencia_invalida")
  expect_identical(out_df$details$campo, NA_character_)

  expect_empty_store(con)
})

test_that("snapshot_metadata que ja e domain_error -> devolve o mesmo objeto", {
  con <- local_event_store()
  err <- domain_error("snapshot_indisponivel", "sem snapshot selecionado")
  out <- start_draft(con, err, reference_league_config(), make_teams(), team_ids(), clock = fixed_clock())
  expect_identical(out, err)
  expect_empty_store(con)
})

test_that("proveniencia congelada apara espaco em volta dos campos do metadata", {
  con <- local_event_store()
  meta <- list(
    snapshot_id = "  snap-x  ", content_hash = " hash-x\n", scoring_hash = "\tsc-x "
  )
  start_draft(
    con, meta, reference_league_config(), make_teams(), team_ids(), clock = fixed_clock()
  )
  sess <- DBI::dbGetQuery(con, "SELECT * FROM draft_session")
  expect_identical(sess$snapshot_id, "snap-x")
  expect_identical(sess$snapshot_content_hash, "hash-x")
  expect_identical(sess$scoring_identity, "sc-x")
})

test_that("seed invalida (fracionaria / fora de range) -> domain_error start_seed_invalida", {
  con <- local_event_store()
  for (bad in list(1.5, .Machine$integer.max + 1, Inf, NA_real_, c(1L, 2L))) {
    out <- start_draft(
      con, good_meta, reference_league_config(), make_teams(), team_ids(),
      seed = bad, clock = fixed_clock()
    )
    expect_true(is_domain_error(out))
    expect_identical(out$code, "start_seed_invalida")
  }
  expect_empty_store(con)
})

test_that("clock invalido (NA / Date) -> domain_error start_clock_invalido", {
  con <- local_event_store()
  for (bad_clock in list(function() NA, function() as.Date("2026-08-31"), function() 12345)) {
    out <- start_draft(
      con, good_meta, reference_league_config(), make_teams(), team_ids(),
      clock = bad_clock
    )
    expect_true(is_domain_error(out))
    expect_identical(out$code, "start_clock_invalido")
  }
  expect_empty_store(con)
})

test_that("falha na escrita do 1o INSERT (draft_id colidindo) -> rollback total", {
  con <- local_event_store()
  expect_true(run_ok(con)$ok)

  out <- run_ok(con) # mesmo clock -> mesmo draft_id -> PK de draft_session colide
  expect_true(is_domain_error(out))
  expect_identical(out$code, "event_store_transacao_falhou")

  # o banco ainda tem so a primeira sessao
  expect_identical(count(con, "draft_session"), 1L)
  expect_identical(count(con, "draft_slot"), 180L)
  expect_identical(count(con, "draft_event"), 1L)
})

test_that("falha numa escrita TARDIA da transacao -> rollback das escritas anteriores", {
  con <- local_event_store()
  draft_id <- "draft-20260831T120000Z" # o que fixed_clock() produz

  # pre-insere um DRAFT_STARTED orfao para esse draft_id: o INSERT de draft_event
  # dentro do closure vai bater no UNIQUE(draft_id, event_sequence) -- DEPOIS de
  # draft_session e draft_slot ja terem sido escritos no mesmo closure.
  DBI::dbExecute(con, "PRAGMA foreign_keys=OFF")
  DBI::dbExecute(
    con,
    "INSERT INTO draft_event (draft_id, event_sequence, event_type, payload_json, created_at)
     VALUES (?, 1, 'DRAFT_STARTED', '{}', '2026-08-31T00:00:00Z')",
    params = list(draft_id)
  )

  out <- run_ok(con)
  expect_true(is_domain_error(out))
  expect_identical(out$code, "event_store_transacao_falhou")

  expect_identical(count(con, "draft_session"), 0L) # escrito e revertido
  expect_identical(count(con, "draft_slot"), 0L)    # escrito e revertido
  expect_identical(count(con, "draft_event"), 1L)   # so o orfao pre-inserido
})

test_that("seed ausente -> random_seed NULL e payload sem random_seed", {
  con <- local_event_store()
  expect_true(run_ok(con, seed = NULL)$ok)

  sess <- DBI::dbGetQuery(con, "SELECT random_seed FROM draft_session")
  expect_true(is.na(sess$random_seed))

  payload <- jsonlite::fromJSON(
    DBI::dbGetQuery(con, "SELECT payload_json FROM draft_event")$payload_json
  )
  expect_false("random_seed" %in% names(payload))
})
