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
