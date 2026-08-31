# I/O & Edge-Case Matrix de domain_league_config (spec Story 2.1).

league_rules_path <- test_path("..", "..", "config", "league_rules.yml")

# Mapa desserializado equivalente a `config/league_rules.yml`.
ref_map <- function(...) {
  base <- list(
    config_version = "league-config-v1",
    teams = 12L,
    rounds = 15L,
    scoring = "full_ppr",
    starter_slots = list(QB = 1L, RB = 2L, WR = 2L, TE = 1L, FLEX = 1L, K = 1L, DST = 1L),
    flex_eligibility = c("RB", "WR"),
    bench_size = 6L
  )
  utils::modifyList(base, list(...))
}

codes_of <- function(f) vapply(f, function(x) x$code, character(1L))
by_code <- function(f, code) Filter(function(x) identical(x$code, code), f)

# --- parse_league_config --------------------------------------------------

test_that("referencia viavel: parse identico a reference_league_config e envelope vazio", {
  parsed <- parse_league_config(ref_map())
  expect_identical(parsed, reference_league_config())
  expect_identical(validate_league_envelope(parsed), list())
})

test_that("config/league_rules.yml parseia, e viavel e bate com a referencia", {
  raw <- read_scoring_config(league_rules_path)
  expect_false(is_domain_error(raw))
  parsed <- parse_league_config(raw)
  expect_false(is_domain_error(parsed))
  expect_identical(parsed, reference_league_config())
  expect_identical(validate_league_envelope(parsed), list())
})

test_that("tipos canonicos: inteiros coeridos, textos e vetor nomeado", {
  p <- parse_league_config(ref_map(teams = 12, rounds = 15, bench_size = 6))
  expect_type(p$teams, "integer")
  expect_type(p$rounds, "integer")
  expect_type(p$bench_size, "integer")
  expect_type(p$config_version, "character")
  expect_type(p$scoring, "character")
  expect_type(p$starter_slots, "integer")
  expect_identical(names(p$starter_slots), c("QB", "RB", "WR", "TE", "FLEX", "K", "DST"))
  expect_type(p$flex_eligibility, "character")
})

test_that("YAML nao e mapa -> league_config_malformado", {
  for (bad in list(list(), 42, "x", c(1, 2, 3), list(1, 2))) {
    e <- parse_league_config(bad)
    expect_true(is_domain_error(e))
    expect_identical(e$code, "league_config_malformado")
  }
})

test_that("campo ausente -> league_config_campo_ausente com details$campo", {
  m <- ref_map()
  m$teams <- NULL
  e <- parse_league_config(m)
  expect_identical(e$code, "league_config_campo_ausente")
  expect_identical(e$details$campo, "teams")
})

test_that("tipo invalido -> league_config_tipo_invalido com details$campo", {
  e <- parse_league_config(ref_map(rounds = "quinze"))
  expect_identical(e$code, "league_config_tipo_invalido")
  expect_identical(e$details$campo, "rounds")

  e2 <- parse_league_config(ref_map(rounds = 15.5))
  expect_identical(e2$code, "league_config_tipo_invalido")
  expect_identical(e2$details$campo, "rounds")

  e3 <- parse_league_config(ref_map(starter_slots = list(QB = "um", RB = 2L)))
  expect_identical(e3$code, "league_config_tipo_invalido")
  expect_identical(e3$details$campo, "starter_slots.QB")
})

test_that("domain_error na entrada passa direto", {
  err <- read_scoring_config(file.path(withr::local_tempdir(), "nao-existe.yml"))
  expect_identical(parse_league_config(err), err)
})

# --- validate_league_envelope -------------------------------------------

test_that("times fora do envelope -> league_times_fora_do_envelope, grupo times_rounds", {
  for (n in c(7L, 15L)) {
    f <- validate_league_envelope(parse_league_config(ref_map(teams = n)))
    hit <- by_code(f, "league_times_fora_do_envelope")
    expect_length(hit, 1L)
    expect_identical(hit[[1]]$severity, "bloqueante")
    expect_identical(hit[[1]]$details$grupo, "times_rounds")
    expect_identical(hit[[1]]$details$encontrado, n)
  }
  # limites inclusivos 8 e 14 sao viaveis
  expect_length(validate_league_envelope(parse_league_config(ref_map(teams = 8L))), 0L)
  expect_length(validate_league_envelope(parse_league_config(ref_map(teams = 14L))), 0L)
})

test_that("rounds != 15 -> league_rounds_invalido, grupo times_rounds (sem roster_nao_preenche)", {
  f <- validate_league_envelope(parse_league_config(ref_map(rounds = 16L)))
  expect_identical(codes_of(f), "league_rounds_invalido")
  expect_identical(f[[1]]$details$grupo, "times_rounds")
})

test_that("titulares != composicao V1 -> league_slots_invalido com esperado/encontrado", {
  for (rb in c(1L, 3L)) {
    f <- validate_league_envelope(parse_league_config(
      ref_map(starter_slots = ref_map()$starter_slots |> utils::modifyList(list(RB = rb)))
    ))
    expect_identical(codes_of(f), "league_slots_invalido")
    expect_identical(f[[1]]$details$grupo, "slots_flex")
    expect_identical(unname(f[[1]]$details$encontrado[["RB"]]), rb)
    expect_identical(unname(f[[1]]$details$esperado[["RB"]]), 2L)
  }
})

test_that("bench_size != 6 -> league_reservas_invalido E league_roster_nao_preenche_rounds", {
  f <- validate_league_envelope(parse_league_config(ref_map(bench_size = 5L)))
  expect_identical(codes_of(f), c("league_reservas_invalido", "league_roster_nao_preenche_rounds"))
  expect_true(all(vapply(f, function(x) identical(x$details$grupo, "slots_flex"), logical(1L))))
})

test_that("FLEX invalido ou vazio -> league_flex_invalido, grupo slots_flex", {
  f1 <- validate_league_envelope(parse_league_config(ref_map(flex_eligibility = c("RB", "TE"))))
  expect_identical(codes_of(f1), "league_flex_invalido")
  expect_identical(f1[[1]]$details$grupo, "slots_flex")

  f2 <- validate_league_envelope(parse_league_config(ref_map(flex_eligibility = list())))
  expect_identical(codes_of(f2), "league_flex_invalido")
})

test_that("multiplas violacoes: todas classificadas, ordem estavel entre execucoes", {
  m <- ref_map(teams = 7L, bench_size = 5L, flex_eligibility = c("RB", "TE"))
  a <- validate_league_envelope(parse_league_config(m))
  b <- validate_league_envelope(parse_league_config(m))
  expect_identical(a, b)
  expect_identical(codes_of(a), c(
    "league_flex_invalido",
    "league_reservas_invalido",
    "league_roster_nao_preenche_rounds",
    "league_times_fora_do_envelope"
  ))
  grupos <- vapply(a, function(x) x$details$grupo, character(1L))
  expect_true(all(grupos %in% c("times_rounds", "slots_flex", "scoring")))
})

test_that("determinismo sob LC_COLLATE=C", {
  m <- ref_map(teams = 7L, bench_size = 5L, flex_eligibility = c("RB", "TE"))
  unforced <- validate_league_envelope(parse_league_config(m))
  forced <- withr::with_locale(
    c(LC_COLLATE = "C"),
    validate_league_envelope(parse_league_config(m))
  )
  expect_identical(forced, unforced)
})

# --- league_scoring_compat_finding -------------------------------------

league_scoring <- function() {
  read_scoring_config(testthat::test_path("fixtures/snapshot-valid/scoring.yml"))
}
league_metadata <- function() {
  read_snapshot_bundle(testthat::test_path("fixtures/snapshot-valid"))$metadata
}

test_that("scoring compativel -> NULL", {
  expect_null(league_scoring_compat_finding(league_scoring(), league_metadata()))
})

test_that("scoring divergente -> aviso league_scoring_incompativel, nao bloqueia", {
  scoring <- league_scoring()
  scoring$passing$yards <- 0.05
  f <- league_scoring_compat_finding(scoring, league_metadata())
  expect_identical(f$code, "league_scoring_incompativel")
  expect_identical(f$severity, "aviso")
  expect_identical(f$details$grupo, "scoring")
  expect_true(nzchar(f$details$encontrado))
})

test_that("scoring ativo indisponivel -> aviso league_scoring_indisponivel preservando code/message", {
  err <- read_scoring_config(file.path(withr::local_tempdir(), "nao-existe.yml"))
  f <- league_scoring_compat_finding(err, league_metadata())
  expect_identical(f$code, "league_scoring_indisponivel")
  expect_identical(f$severity, "aviso")
  expect_identical(f$details$code, err$code)
  expect_identical(f$message, err$message)
})

# --- pureza -----------------------------------------------------------

test_that("dominio puro: sem I/O, sem yaml/jsonlite, sem clock", {
  src <- readLines(test_path("..", "..", "R", "domain_league_config.R"))
  code <- src[!grepl("^\\s*#", src) & !grepl("^#'", src)]
  forbidden <- paste(
    "readLines", "read\\.csv", "read_yaml", "read_scoring_config\\(",
    "fromJSON", "readBin", "\\bfile\\(", "file\\.exists", "file\\.path",
    "Sys\\.(time|getenv|Date|setlocale)", "proc\\.time", "\\bdate\\(",
    "library\\(", "yaml::", "jsonlite::",
    sep = "|"
  )
  expect_false(any(grepl(forbidden, code)))
})
