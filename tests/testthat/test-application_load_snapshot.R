# I/O & Edge-Case Matrix de load_snapshot_for_preparation (spec Story 1.7).

valid_dir <- test_path("fixtures/snapshot-valid")

# Copia o fixture valido (5 arquivos) para um tmp dir mutavel.
fresh_bundle <- function() {
  d <- withr::local_tempdir(.local_envir = parent.frame())
  file.copy(list.files(valid_dir, full.names = TRUE), d)
  d
}

codes <- function(x) vapply(x, function(f) f$code, character(1L))

test_that("bundle saudavel -> ok, advance liberado, metadados + cobertura + avisos", {
  vm <- load_snapshot_for_preparation(valid_dir)
  expect_true(vm$ok)
  expect_true(vm$advance_allowed)
  expect_length(vm$bloqueios, 0L)
  expect_identical(vm$metadata$temporada, 2025L)
  expect_identical(vm$metadata$fontes, c("CBS", "ESPN", "FantasyPros"))
  expect_false(is.null(vm$metadata$identidade_de_conteudo))
  expect_identical(vm$coverage$QB, 1L)
  expect_identical(vm$coverage$TE, 0L)
  expect_gt(length(vm$avisos), 0L)
  expect_true(all(vapply(vm$avisos, function(a) a$severity, "") == "aviso"))
})

test_that("achado bloqueante (posicao fora do V1) -> advance bloqueado, causa concreta", {
  d <- fresh_bundle()
  players <- utils::read.csv(file.path(d, "players.csv"), check.names = FALSE)
  players$position[1] <- "FB"
  utils::write.csv(players, file.path(d, "players.csv"), row.names = FALSE)

  vm <- load_snapshot_for_preparation(d)
  expect_false(vm$advance_allowed)
  expect_true("snapshot_posicao_fora_do_v1" %in% codes(vm$bloqueios))
})

test_that("content hash divergente -> bloqueio snapshot_content_incompativel (code de dominio)", {
  d <- fresh_bundle()
  meta <- jsonlite::fromJSON(file.path(d, "metadata.json"))
  meta$content_hash <- paste(rep("0", 64), collapse = "")
  jsonlite::write_json(meta, file.path(d, "metadata.json"), auto_unbox = TRUE, pretty = TRUE)

  vm <- load_snapshot_for_preparation(d)
  expect_false(vm$advance_allowed)
  hit <- Filter(function(b) b$code == "snapshot_content_incompativel", vm$bloqueios)
  expect_length(hit, 1L)
  expect_false(is.null(hit[[1]]$details$esperado))
  expect_false(is.null(hit[[1]]$details$encontrado))
})

test_that("scoring divergente -> bloqueio preservando code", {
  d <- fresh_bundle()
  scoring_path <- file.path(d, "scoring.yml")
  writeLines(c(readLines(scoring_path), "extra_key: 1"), scoring_path)

  vm <- load_snapshot_for_preparation(d)
  expect_false(vm$advance_allowed)
  expect_true("snapshot_scoring_incompativel" %in% codes(vm$bloqueios))
})

test_that("scoring.yml ausente -> bloqueio snapshot_scoring_indisponivel, avanco travado", {
  d <- fresh_bundle()
  file.remove(file.path(d, "scoring.yml"))

  vm <- load_snapshot_for_preparation(d)
  expect_false(vm$advance_allowed)
  expect_true("snapshot_scoring_indisponivel" %in% codes(vm$bloqueios))
})

test_that("falha de leitura (arquivo sumiu) -> ok=FALSE com o domain_error", {
  d <- fresh_bundle()
  file.remove(file.path(d, "metrics.csv"))

  vm <- load_snapshot_for_preparation(d)
  expect_false(vm$ok)
  expect_false(vm$advance_allowed)
  expect_true("bundle_arquivo_ausente" %in% codes(vm$bloqueios))
  expect_null(vm$metadata)
})

test_that("falha do parser (bundle vazio) trava o avanco", {
  d <- fresh_bundle()
  players <- utils::read.csv(file.path(d, "players.csv"), check.names = FALSE)
  utils::write.csv(players[0, ], file.path(d, "players.csv"), row.names = FALSE)

  vm <- load_snapshot_for_preparation(d)
  expect_false(vm$ok)
  expect_false(vm$advance_allowed)
  expect_true("snapshot_bundle_vazio" %in% codes(vm$bloqueios))
})

test_that("bundle_dir invalido -> view-model bloqueado, nunca lanca", {
  for (bad in list(NA_character_, "", character(0), c("a", "b"), 42)) {
    vm <- load_snapshot_for_preparation(bad)
    expect_false(vm$ok)
    expect_false(vm$advance_allowed)
    expect_identical(vm$bloqueios[[1]]$code, "bundle_dir_invalido")
  }
})

test_that("opcionais ausentes -> aviso 'Nao disponivel', advance inalterado", {
  vm <- load_snapshot_for_preparation(valid_dir)
  opt <- Filter(function(a) a$code == "snapshot_opcional_ausente", vm$avisos)
  expect_gt(length(opt), 0L)
  expect_true("floor" %in% vapply(opt, function(a) a$details$campo, ""))
  expect_true(vm$advance_allowed)
})

test_that("determinismo: mesmo bundle, 2 leituras -> identical", {
  expect_identical(
    load_snapshot_for_preparation(valid_dir),
    load_snapshot_for_preparation(valid_dir)
  )
})

test_that("nunca lanca: metadata.json degenerado (array) -> view-model, sem erro", {
  d <- fresh_bundle()
  writeLines("[1,2,3]", file.path(d, "metadata.json"))
  vm <- load_snapshot_for_preparation(d)
  expect_false(vm$advance_allowed)
  expect_true("snapshot_metadado_ilegivel" %in% codes(vm$bloqueios))
})

test_that("leitores injetaveis: load_fn nao toca o disco real", {
  fake_deser <- read_snapshot_bundle(valid_dir)
  fake_raw <- read_bundle_files_raw(valid_dir)
  fake_scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
  vm <- load_snapshot_for_preparation(
    "/caminho/inexistente",
    read_bundle = function(...) fake_deser,
    read_raw = function(...) fake_raw,
    read_scoring = function(...) fake_scoring
  )
  expect_true(vm$advance_allowed)
})
