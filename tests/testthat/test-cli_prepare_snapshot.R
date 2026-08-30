# CLI scripts/prepare_snapshot.R end-to-end (spec Story 1.4 "Fallback E2E").
# Roda o script num processo separado via callr; sem rede (so o modo CSV).

pkg_root <- normalizePath(testthat::test_path("..", ".."))
script <- file.path(pkg_root, "scripts", "prepare_snapshot.R")
csv_fixture <- file.path(pkg_root, "tests", "testthat", "fixtures", "manual-projection.csv")
meta_fixture <- file.path(pkg_root, "tests", "testthat", "fixtures", "manual-metadata.json")

run_cli <- function(...) {
  testthat::skip_if_not_installed("callr")
  callr::rscript(
    script,
    cmdargs = c(...),
    wd = pkg_root,
    fail_on_status = FALSE,
    show = FALSE
  )
}

test_that("modo CSV: bundle valido, exit 0, stdout com bundle_dir/snapshot_id", {
  out <- withr::local_tempdir()
  res <- run_cli(
    "--from-csv", csv_fixture, "--metadata", meta_fixture, "--out", out
  )
  expect_identical(res$status, 0L)
  expect_match(res$stdout, "bundle_dir:")
  expect_match(res$stdout, "snapshot_id:")

  dir <- list.dirs(out, recursive = FALSE)
  expect_length(dir, 1L)
  expect_setequal(
    list.files(dir),
    c("players.csv", "metrics.csv", "metadata.json", "qa-report.json", "scoring.yml")
  )

  parsed <- parse_snapshot_bundle(read_snapshot_bundle(dir))
  expect_false(is_domain_error(parsed))
  raw <- read_bundle_files_raw(dir)
  expect_null(verify_content_hash(raw, parsed$metadata))
  expect_null(verify_scoring_hash(
    read_scoring_config(file.path(dir, "scoring.yml")), parsed$metadata
  ))
})

test_that("duas execucoes: dois snapshot_id, primeiro metadata.json intacto", {
  out <- withr::local_tempdir()
  r1 <- run_cli("--from-csv", csv_fixture, "--metadata", meta_fixture, "--out", out)
  expect_identical(r1$status, 0L)
  dir1 <- list.dirs(out, recursive = FALSE)
  mtime1 <- file.info(file.path(dir1, "metadata.json"))$mtime

  Sys.sleep(1.1)
  r2 <- run_cli("--from-csv", csv_fixture, "--metadata", meta_fixture, "--out", out)
  expect_identical(r2$status, 0L)

  id1 <- sub(".*snapshot_id: (\\S+).*", "\\1", gsub("\n", " ", r1$stdout))
  id2 <- sub(".*snapshot_id: (\\S+).*", "\\1", gsub("\n", " ", r2$stdout))
  expect_false(identical(id1, id2))
  expect_length(list.dirs(out, recursive = FALSE), 2L)
  expect_identical(file.info(file.path(dir1, "metadata.json"))$mtime, mtime1)
})

test_that("modo CSV sem --season nem season no metadata -> exit 1, stderr PT-BR", {
  out <- withr::local_tempdir()
  no_season <- file.path(withr::local_tempdir(), "m.json")
  writeLines('{"source_list": ["manual-csv"]}', no_season)
  res <- run_cli("--from-csv", csv_fixture, "--metadata", no_season, "--out", out)
  expect_identical(res$status, 1L)
  expect_match(res$stderr, "informe --season")
  expect_length(list.dirs(out, recursive = FALSE), 0L)
})

test_that("--from-csv com arquivo inexistente -> exit 1, mensagem PT-BR", {
  res <- run_cli("--from-csv", file.path(pkg_root, "nao-existe.csv"), "--season", "2025")
  expect_identical(res$status, 1L)
  expect_match(res$stderr, "ausente")
})

test_that("modo coleta sem --season -> exit 1, mensagem PT-BR", {
  res <- run_cli("--sources", "CBS")
  expect_identical(res$status, 1L)
  expect_match(res$stderr, "--season")
})

test_that("flag desconhecida -> exit 1", {
  res <- run_cli("--from-csv", csv_fixture, "--nope", "x")
  expect_identical(res$status, 1L)
  expect_match(res$stderr, "desconhecida")
})
