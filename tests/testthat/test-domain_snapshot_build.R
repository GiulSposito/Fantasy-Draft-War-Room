# Mapeamento cru -> canonico (spec Story 1.4, dominio puro).

flat_fixture <- function() {
  utils::read.csv(
    testthat::test_path("fixtures/ffanalytics-flat.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}
manual_fixture <- function() {
  utils::read.csv(
    testthat::test_path("fixtures/manual-projection.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# --- snapshot_normalized_name ---------------------------------------------

test_that("snapshot_normalized_name: minusculo, sem acento, espacos colapsados", {
  expect_identical(snapshot_normalized_name("Josh Allen"), "josh allen")
  expect_identical(snapshot_normalized_name("  José  Peña "), "jose pena")
  expect_identical(snapshot_normalized_name("D'Andre Swift"), "d'andre swift")
})

test_that("snapshot_normalized_name: estavel sob locale forcado", {
  withr::with_locale(c(LC_COLLATE = "C", LC_TIME = "C"), {
    expect_identical(snapshot_normalized_name("ÀÉÎÕÜÇñ"), "aeioucn")
  })
})

test_that("snapshot_normalized_name: vetorizado", {
  expect_identical(
    snapshot_normalized_name(c("A B", "Cristián")),
    c("a b", "cristian")
  )
})

# --- derive_tier_cliff ---------------------------------------------------

test_that("derive_tier_cliff: ultimo de um tier COM sucessor pior vira TRUE", {
  pos <- c("RB", "RB", "RB", "WR", "WR", "QB")
  rank <- c(1, 2, 3, 1, 2, 1)
  tier <- c(1, 1, 2, 1, 1, 1)
  # RB tier1 tem um tier2 depois -> seu ultimo (rank2) e TRUE.
  # RB tier2 e o tier final da posicao -> rank3 FALSE. WR/QB tem um tier so.
  expect_identical(
    derive_tier_cliff(pos, rank, tier),
    c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE)
  )
})

test_that("derive_tier_cliff: tier do meio em posicao de 3 tiers e TRUE, tier final FALSE", {
  pos <- rep("RB", 5)
  rank <- c(1, 2, 3, 4, 5)
  tier <- c(1, 1, 2, 3, 3)
  # tier1 last (rank2) TRUE; tier2 unico (rank3) TRUE; tier3 last (rank5) FALSE.
  expect_identical(
    derive_tier_cliff(pos, rank, tier),
    c(FALSE, TRUE, TRUE, FALSE, FALSE)
  )
})

test_that("derive_tier_cliff: pos_rank ausente -> domain_error", {
  err <- derive_tier_cliff(c("RB", "RB"), c(1, NA), c(1, 1))
  expect_true(is_domain_error(err))
  expect_identical(err$code, "coleta_ffanalytics_falhou")
})

# --- new_snapshot_id ---------------------------------------------------

test_that("new_snapshot_id: snap-<season>-<timestamp UTC compacto>", {
  id <- new_snapshot_id(2025, as.POSIXct("2026-08-30 16:34:59", tz = "UTC"))
  expect_identical(id, "snap-2025-20260830T163459Z")
})

test_that("new_snapshot_id: normaliza o instante para UTC", {
  id <- new_snapshot_id(2025, as.POSIXct("2026-08-30 13:00:00", tz = "America/Sao_Paulo"))
  expect_identical(id, "snap-2025-20260830T160000Z")
})

# --- build_snapshot_tables --------------------------------------------

test_that("modo coleta: monta players/metrics e deriva normalized_name/tier_cliff", {
  out <- build_snapshot_tables(flat_fixture())
  expect_false(is_domain_error(out))
  expect_identical(names(out), c("players", "metrics"))
  expect_identical(names(out$players), names(snapshot_schema()$players))
  expect_identical(names(out$metrics), names(snapshot_schema()$metrics))

  expect_identical(out$players$normalized_name[out$players$player_id == "f6"], "ja'marr chase")
  expect_type(out$metrics$tier, "integer")
  expect_type(out$metrics$tier_cliff, "logical")
  # RB tiers 1,2: f3 (rank2/tier1, tier2 existe) -> cliff; f4 (rank3/tier2,
  # tier final da posicao) -> FALSE; f2 (rank1/tier1) -> FALSE.
  cliff <- setNames(out$metrics$tier_cliff, out$metrics$player_id)
  expect_false(cliff[["f2"]])
  expect_true(cliff[["f3"]])
  expect_false(cliff[["f4"]])
})

test_that("modo CSV manual: usa tier_cliff dado, nao deriva", {
  out <- build_snapshot_tables(manual_fixture())
  expect_false(is_domain_error(out))
  cliff <- setNames(out$metrics$tier_cliff, out$metrics$player_id)
  expect_identical(cliff[["m1"]], TRUE)
  expect_identical(cliff[["m3"]], FALSE)
  # posicao normalizada
  expect_identical(out$players$position[out$players$player_id == "m4"], "DST")
})

test_that("opcionais ausentes viram NA tipado; presentes preservados", {
  out <- build_snapshot_tables(manual_fixture())
  expect_true(all(is.na(out$metrics$sd_points)))
  expect_true(is.na(out$metrics$ceiling[out$metrics$player_id == "m5"]))
  expect_false(anyNA(out$metrics$adp))
})

test_that("coluna crua obrigatoria ausente -> snapshot_coluna_ausente", {
  raw <- manual_fixture()
  raw$points <- NULL
  err <- build_snapshot_tables(raw)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_coluna_ausente")
  expect_identical(err$details$campo, "points")
})

test_that("posicao fora do V1 na origem -> snapshot_posicao_invalida com player_id", {
  raw <- flat_fixture()
  raw$position[3] <- "FB"
  err <- build_snapshot_tables(raw)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_posicao_invalida")
  expect_identical(err$details$player_id, "f3")
})

test_that("tier nao inteiro -> snapshot_tipo_invalido motivo nao_inteiro", {
  raw <- manual_fixture()
  raw$tier[2] <- 2.5
  err <- build_snapshot_tables(raw)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_tipo_invalido")
  expect_identical(err$details$motivo, "nao_inteiro")
})

test_that("raw vazio -> coleta_ffanalytics_falhou", {
  err <- build_snapshot_tables(manual_fixture()[0, ])
  expect_true(is_domain_error(err))
  expect_identical(err$code, "coleta_ffanalytics_falhou")
})

test_that("sem tier_cliff nem pos_rank: coluna omitida (parser da releitura reporta)", {
  raw <- manual_fixture()
  raw$tier_cliff <- NULL
  out <- build_snapshot_tables(raw)
  expect_false(is_domain_error(out))
  expect_false("tier_cliff" %in% names(out$metrics))
})

# --- build_snapshot_metadata / build_qa_report -----------------------

test_that("build_snapshot_metadata: sem content_hash, schema_version fixo", {
  meta <- build_snapshot_metadata(
    "snap-2025-x", 2025, "2026-08-30T16:00:00Z", "0.1.0",
    c("CBS", "ESPN"), strrep("a", 64L), "10 jogadores, 0 bloqueios"
  )
  expect_false("content_hash" %in% names(meta))
  expect_identical(meta$schema_version, "snapshot-bundle-v1")
  expect_identical(meta$season, 2025L)
  expect_identical(meta$source_list, c("CBS", "ESPN"))
})

test_that("build_qa_report: estruturalmente valido, coverage por posicao", {
  out <- build_snapshot_tables(flat_fixture())
  qa <- build_qa_report(out$players, "2026-08-30T16:00:00Z")
  expect_identical(qa$schema_version, "qa-report-v1")
  expect_identical(qa$findings, list())
  expect_identical(qa$coverage$RB, 3L)
  expect_identical(qa$coverage$QB, 1L)
  expect_identical(names(qa$coverage), sort(names(qa$coverage)))
})

# --- pureza ----------------------------------------------------------

test_that("R/domain_snapshot_build.R nao faz I/O, nao le clock, nao importa ffanalytics/yaml", {
  src <- readLines(test_path("..", "..", "R", "domain_snapshot_build.R"))
  code <- src[!grepl("^\\s*#", src) & !grepl("^#'", src)]
  forbidden <- paste(
    "readLines", "read\\.csv", "read_yaml", "fromJSON", "readBin", "file\\(",
    "file\\.exists", "Sys\\.(time|getenv)", "scrape_data", "projections_table",
    "library\\(", "ffanalytics::", "yaml::",
    sep = "|"
  )
  expect_false(any(grepl(forbidden, code)))
})
