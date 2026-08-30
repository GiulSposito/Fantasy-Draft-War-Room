# read_snapshot_bundle(): leitura crua + desserializacao (spec Story 1.2).

valid_dir <- test_path("fixtures/snapshot-valid")

test_that("le o fixture valido nos 4 slots", {
  bundle <- read_snapshot_bundle(valid_dir)
  expect_false(is_domain_error(bundle))
  expect_identical(names(bundle), c("players", "metrics", "metadata", "qa_report"))
  expect_s3_class(bundle$players, "data.frame")
  expect_s3_class(bundle$metrics, "data.frame")
  expect_identical(nrow(bundle$players), 4L)
  expect_identical(nrow(bundle$metrics), 4L)
  expect_identical(bundle$metadata$snapshot_id, "snap-2025-0001")
  expect_identical(bundle$metadata$source_list, c("CBS", "ESPN", "FantasyPros"))
  expect_type(bundle$qa_report, "list")
})

test_that("nao converte strings em fatores nem mangla nomes de coluna", {
  bundle <- read_snapshot_bundle(valid_dir)
  expect_type(bundle$players$display_name, "character")
  expect_true("tier_cliff" %in% names(bundle$metrics))
})

test_that("arquivo ausente vira domain_error com details$arquivo", {
  tmp <- withr::local_tempdir()
  file.copy(
    list.files(valid_dir, full.names = TRUE),
    tmp
  )
  file.remove(file.path(tmp, "metrics.csv"))

  err <- read_snapshot_bundle(tmp)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_arquivo_ausente")
  expect_identical(err$details$arquivo, "metrics.csv")
})

test_that("JSON malformado vira bundle_formato_invalido", {
  tmp <- withr::local_tempdir()
  file.copy(list.files(valid_dir, full.names = TRUE), tmp)
  writeLines("{ not valid json ", file.path(tmp, "metadata.json"))

  err <- read_snapshot_bundle(tmp)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_formato_invalido")
  expect_identical(err$details$arquivo, "metadata.json")
})

test_that("CSV com BOM UTF-8 (export Excel) parseia sem renomear a 1a coluna", {
  tmp <- withr::local_tempdir()
  file.copy(list.files(valid_dir, full.names = TRUE), tmp)
  players_path <- file.path(tmp, "players.csv")
  body <- readLines(players_path, encoding = "UTF-8")
  con <- file(players_path, open = "wb")
  writeBin(charToRaw("﻿"), con)
  writeBin(charToRaw(paste0(paste(body, collapse = "\n"), "\n")), con)
  close(con)

  bundle <- read_snapshot_bundle(tmp)
  expect_false(is_domain_error(bundle))
  expect_identical(names(bundle$players)[1], "player_id")
  expect_false(is_domain_error(parse_snapshot_bundle(bundle)))
})

test_that("bundle_dir invalido -> erro de contrato", {
  expect_error(read_snapshot_bundle(character(0)))
  expect_error(read_snapshot_bundle(c("a", "b")))
  expect_error(read_snapshot_bundle(""))
})

# --- Story 1.4: CSV manual + escrita do bundle ----------------------------

test_that("read_manual_projection_csv: le o fixture; arquivo ausente -> domain_error", {
  df <- read_manual_projection_csv(test_path("fixtures/manual-projection.csv"))
  expect_s3_class(df, "data.frame")
  expect_true(all(c("player_id", "tier_cliff") %in% names(df)))

  err <- read_manual_projection_csv(test_path("fixtures/nao-existe.csv"))
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_arquivo_ausente")
})

test_that("read_metadata_overrides: objeto JSON ok; array -> bundle_formato_invalido", {
  tmp <- withr::local_tempdir()
  ok <- file.path(tmp, "meta.json")
  writeLines('{"season": 2025}', ok)
  expect_equal(read_metadata_overrides(ok)$season, 2025)

  arr <- file.path(tmp, "arr.json")
  writeLines("[1, 2, 3]", arr)
  err <- read_metadata_overrides(arr)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_formato_invalido")
})

test_that("resolve_snapshot_root: --out vence; sem override cai no R_user_dir", {
  expect_identical(resolve_snapshot_root("/tmp/x"), path.expand("/tmp/x"))
  default_root <- resolve_snapshot_root(NULL)
  expect_match(default_root, "snapshots$")
})

write_bundle_inputs <- function() {
  raw <- utils::read.csv(
    testthat::test_path("fixtures/ffanalytics-flat.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  tables <- build_snapshot_tables(raw)
  scoring_path <- testthat::test_path("fixtures/snapshot-valid/scoring.yml")
  list(
    tables = tables,
    qa = build_qa_report(tables$players, "2026-08-30T16:00:00Z"),
    metadata = build_snapshot_metadata(
      "snap-2025-20260830T160000Z", 2025L, "2026-08-30T16:00:00Z", "0.1.0",
      "manual-csv", scoring_config_hash(read_scoring_config(scoring_path)),
      "7 jogadores, 0 bloqueios"
    ),
    scoring_text = rawToChar(readBin(scoring_path, "raw", n = file.size(scoring_path)))
  )
}

test_that("write_snapshot_bundle: round-trip -> parser + verify de hash passam", {
  root <- withr::local_tempdir()
  x <- write_bundle_inputs()
  dir <- write_snapshot_bundle(
    root, "snap-2025-20260830T160000Z",
    x$tables$players, x$tables$metrics, x$metadata, x$qa, x$scoring_text
  )
  expect_false(is_domain_error(dir))
  expect_setequal(
    list.files(dir),
    c("players.csv", "metrics.csv", "metadata.json", "qa-report.json", "scoring.yml")
  )

  parsed <- parse_snapshot_bundle(read_snapshot_bundle(dir))
  expect_false(is_domain_error(parsed))
  raw <- read_bundle_files_raw(dir)
  expect_null(verify_content_hash(raw, parsed$metadata))
  expect_null(verify_scoring_hash(read_scoring_config(file.path(dir, "scoring.yml")), parsed$metadata))
})

test_that("write_snapshot_bundle: recusa diretorio ja existente, sem sobrescrever", {
  root <- withr::local_tempdir()
  x <- write_bundle_inputs()
  args <- list(
    root, "snap-2025-20260830T160000Z",
    x$tables$players, x$tables$metrics, x$metadata, x$qa, x$scoring_text
  )
  first <- do.call(write_snapshot_bundle, args)
  expect_false(is_domain_error(first))
  marker <- file.path(first, "MARKER")
  file.create(marker)

  again <- do.call(write_snapshot_bundle, args)
  expect_true(is_domain_error(again))
  expect_identical(again$code, "bundle_ja_existe")
  expect_true(file.exists(marker))
  # nenhum diretorio temporario deixado para tras
  expect_length(list.files(root, pattern = "^tmp-snapshot-"), 0L)
})

test_that("config/snapshot_pipeline.yml versionado tem a forma que o adapter espera", {
  cfg <- read_scoring_config(testthat::test_path("..", "..", "config", "snapshot_pipeline.yml"))
  expect_false(is_domain_error(cfg))
  expect_type(cfg$pipeline_version, "character")
  expect_setequal(names(cfg$vor_baseline), c("QB", "RB", "WR", "TE", "K", "DST"))
  expect_setequal(names(cfg$tier_thresholds), c("QB", "RB", "WR", "TE", "K", "DST"))
  expect_true(all(vapply(cfg$vor_baseline, is.numeric, logical(1))))
})

test_that("write_snapshot_bundle: raiz nao gravavel -> bundle_saida_nao_gravavel", {
  skip_on_os("windows")
  skip_if(unname(Sys.info()["user"]) == "root", "root ignora permissoes de arquivo")
  root <- withr::local_tempdir()
  ro <- file.path(root, "readonly")
  dir.create(ro)
  Sys.chmod(ro, "0500")
  withr::defer(Sys.chmod(ro, "0700"))

  x <- write_bundle_inputs()
  err <- write_snapshot_bundle(
    ro, "snap-2025-x",
    x$tables$players, x$tables$metrics, x$metadata, x$qa, x$scoring_text
  )
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_saida_nao_gravavel")
})
