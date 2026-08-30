# Orquestracao do caso de uso prepare_snapshot (spec Story 1.4).
# collect_fn / write_fn injetados, clock fixo -> saida deterministica, sem rede.

fixtures_dir <- testthat::test_path("fixtures")

read_flat <- function() {
  utils::read.csv(
    file.path(fixtures_dir, "ffanalytics-flat.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

scoring_bits <- function() {
  path <- file.path(fixtures_dir, "snapshot-valid", "scoring.yml")
  list(
    parsed = read_scoring_config(path),
    text = rawToChar(readBin(path, "raw", n = file.size(path)))
  )
}

pipeline_cfg <- list(
  pipeline_version = "0.1.0",
  vor_baseline = list(QB = 13, RB = 35, WR = 36, TE = 13, K = 8, DST = 3),
  tier_thresholds = list(QB = 1, RB = 1, WR = 1, TE = 1, K = 1, DST = 0.1)
)

fixed_clock <- function(iso = "2026-08-30 16:00:00") {
  function() as.POSIXct(iso, tz = "UTC")
}

run_prepare <- function(collect_fn, root, clock = fixed_clock(), source_list = "manual-csv") {
  s <- scoring_bits()
  write_fn <- function(snapshot_id, players, metrics, metadata, qa_report, scoring_text) {
    write_snapshot_bundle(root, snapshot_id, players, metrics, metadata, qa_report, scoring_text)
  }
  prepare_snapshot(
    collect_fn = collect_fn,
    write_fn = write_fn,
    clock = clock,
    scoring_raw_text = s$text,
    scoring_parsed = s$parsed,
    pipeline_config = pipeline_cfg,
    season = 2025L,
    source_list = source_list
  )
}

test_that("sucesso: grava bundle de 5 arquivos que passa parser + verify de hash", {
  root <- withr::local_tempdir()
  res <- run_prepare(function() read_flat(), root)

  expect_false(is_domain_error(res))
  expect_identical(res$snapshot_id, "snap-2025-20260830T160000Z")
  expect_setequal(
    list.files(res$bundle_dir),
    c("players.csv", "metrics.csv", "metadata.json", "qa-report.json", "scoring.yml")
  )

  parsed <- parse_snapshot_bundle(read_snapshot_bundle(res$bundle_dir))
  expect_false(is_domain_error(parsed))
  raw <- read_bundle_files_raw(res$bundle_dir)
  expect_null(verify_content_hash(raw, parsed$metadata))
  expect_null(verify_scoring_hash(scoring_bits()$parsed, parsed$metadata))

  # points/vor/tier/tier_cliff preenchidos
  expect_false(anyNA(parsed$players$points))
  expect_false(anyNA(parsed$players$vor))
  expect_false(anyNA(parsed$players$tier))
  expect_false(anyNA(parsed$players$tier_cliff))
})

test_that("scoring.yml do bundle e copia byte-a-byte", {
  root <- withr::local_tempdir()
  res <- run_prepare(function() read_flat(), root)
  written <- rawToChar(readBin(
    file.path(res$bundle_dir, "scoring.yml"), "raw",
    n = file.size(file.path(res$bundle_dir, "scoring.yml"))
  ))
  expect_identical(written, scoring_bits()$text)
})

test_that("falha de coleta: erro propaga, write_fn nunca chamado, nada em disco", {
  root <- withr::local_tempdir()
  called <- 0L
  write_fn <- function(...) {
    called <<- called + 1L
    stop("nao deveria gravar")
  }
  res <- prepare_snapshot(
    collect_fn = function() domain_error("coleta_ffanalytics_falhou", "rede caiu"),
    write_fn = write_fn,
    clock = fixed_clock(),
    scoring_raw_text = scoring_bits()$text,
    scoring_parsed = scoring_bits()$parsed,
    pipeline_config = pipeline_cfg,
    season = 2025L,
    source_list = "x"
  )
  expect_true(is_domain_error(res))
  expect_identical(res$code, "coleta_ffanalytics_falhou")
  expect_identical(called, 0L)
  expect_length(list.files(root), 0L)
})

test_that("posicao invalida na coleta: aborta sem bundle parcial", {
  root <- withr::local_tempdir()
  bad <- read_flat()
  bad$position[2] <- "FB"
  res <- run_prepare(function() bad, root)
  expect_true(is_domain_error(res))
  expect_identical(res$code, "snapshot_posicao_invalida")
  expect_length(list.files(root), 0L)
})

test_that("duas execucoes: dois snapshot_id, dois diretorios, o primeiro intacto", {
  root <- withr::local_tempdir()
  res1 <- run_prepare(function() read_flat(), root, clock = fixed_clock("2026-08-30 16:00:00"))
  before <- file.info(file.path(res1$bundle_dir, "metadata.json"))$mtime
  res2 <- run_prepare(function() read_flat(), root, clock = fixed_clock("2026-08-30 17:30:00"))

  expect_false(identical(res1$snapshot_id, res2$snapshot_id))
  expect_true(dir.exists(res1$bundle_dir))
  expect_true(dir.exists(res2$bundle_dir))
  expect_setequal(
    list.files(root),
    c(basename(res1$bundle_dir), basename(res2$bundle_dir))
  )
  after <- file.info(file.path(res1$bundle_dir, "metadata.json"))$mtime
  expect_identical(before, after)
})

test_that("bundle repetido: mesmo clock -> bundle_ja_existe, primeiro nao tocado", {
  root <- withr::local_tempdir()
  res1 <- run_prepare(function() read_flat(), root)
  expect_false(is_domain_error(res1))
  res2 <- run_prepare(function() read_flat(), root)
  expect_true(is_domain_error(res2))
  expect_identical(res2$code, "bundle_ja_existe")
  expect_length(list.files(root), 1L)
})
