# Dominio puro da sessao de draft (spec Story 2.4).

instant <- as.POSIXct("2026-08-31 12:34:56", tz = "UTC")

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

test_that("new_draft_id: formato draft-<stamp UTC> e deterministico", {
  expect_identical(new_draft_id(instant), "draft-20260831T123456Z")
  expect_identical(new_draft_id(instant), new_draft_id(instant))
  # instante em outro tz -> mesmo stamp UTC
  expect_identical(
    new_draft_id(as.POSIXct("2026-08-31 09:34:56", tz = "America/Sao_Paulo")),
    "draft-20260831T123456Z"
  )
})

test_that("new_draft_id: instante invalido -> stop", {
  expect_error(new_draft_id("nao e uma data"))
  expect_error(new_draft_id(NA))
})

test_that("draft_start_findings: tudo viavel -> list()", {
  found <- draft_start_findings(
    reference_league_config(),
    parse_league_teams(make_teams()),
    team_ids()
  )
  expect_identical(found, list())
})

test_that("draft_start_findings: envelope invalido -> achado com details$grupo", {
  cfg <- reference_league_config()
  cfg$teams <- 7L
  found <- draft_start_findings(cfg, parse_league_teams(make_teams(7L)), team_ids(7L))
  expect_true("league_times_fora_do_envelope" %in% codes(found))
  hit <- Filter(function(f) f$code == "league_times_fora_do_envelope", found)[[1L]]
  expect_identical(hit$severity, "bloqueante")
  expect_identical(hit$details$grupo, "times_rounds")
})

test_that("draft_start_findings: ordem nao-permutacao -> achado grupo 'ordem'", {
  found <- draft_start_findings(
    reference_league_config(),
    parse_league_teams(make_teams()),
    team_ids()[-3L]
  )
  hit <- Filter(function(f) f$code == "snake_ordem_invalida", found)[[1L]]
  expect_identical(hit$details$grupo, "ordem")
})

test_that("draft_start_findings: parse_league_teams falhou -> achado grupo 'times'", {
  found <- draft_start_findings(
    reference_league_config(),
    parse_league_teams(make_teams(user = 0L)), # 0 times do operador -> domain_error
    team_ids()
  )
  hit <- Filter(function(f) f$code == "league_teams_usuario_invalido", found)[[1L]]
  expect_identical(hit$details$grupo, "times")
})

test_that("draft_error_finding: chave 'grupo' preexistente em details e sobrescrita", {
  err <- domain_error("qualquer", "msg", list(grupo = "antigo", extra = 1L))
  fnd <- draft_error_finding(err, "novo")
  expect_identical(fnd$details$grupo, "novo")
  expect_identical(fnd$details$extra, 1L)
  expect_identical(sum(names(fnd$details) == "grupo"), 1L)
})

test_that("draft_start_findings: mesma entrada -> identical()", {
  a <- draft_start_findings(reference_league_config(), parse_league_teams(make_teams(7L)), team_ids(7L))
  b <- draft_start_findings(reference_league_config(), parse_league_teams(make_teams(7L)), team_ids(7L))
  expect_identical(a, b)
})

test_that("draft_started_payload: inclui random_seed quando dado, omite quando NULL", {
  cfg <- reference_league_config()
  com <- draft_started_payload("snap-1", "hash-1", "scoring-1", cfg, "9.9", seed = 42L)
  sem <- draft_started_payload("snap-1", "hash-1", "scoring-1", cfg, "9.9", seed = NULL)

  expect_identical(com$random_seed, 42L)
  expect_false("random_seed" %in% names(sem))
  expect_identical(com$snapshot_id, "snap-1")
  expect_identical(com$snapshot_content_hash, "hash-1")
  expect_identical(com$scoring_identity, "scoring-1")
  expect_identical(com$engine_version, "9.9")
  expect_true(nzchar(com$league_rules_json))
  expect_identical(jsonlite::fromJSON(com$league_rules_json)$teams, 12L)
})

test_that("draft_started_payload: mesma entrada -> identical()", {
  cfg <- reference_league_config()
  expect_identical(
    draft_started_payload("s", "h", "sc", cfg, "1.0", seed = 7L),
    draft_started_payload("s", "h", "sc", cfg, "1.0", seed = 7L)
  )
})
