# Matriz de normalize_position (spec Story 1.1, I/O & Edge-Case Matrix).

test_that("posicao canonica passa direto", {
  expect_identical(normalize_position("QB"), "QB")
  for (pos in positions_v1) {
    expect_identical(normalize_position(pos), pos)
  }
})

test_that("variacoes de D/ST mapeiam para DST (case-insensitive)", {
  expect_identical(normalize_position("D/ST"), "DST")
  expect_identical(normalize_position("dst"), "DST")
  expect_identical(normalize_position("DEF"), "DST")
  expect_identical(normalize_position(" def "), "DST")
  expect_identical(normalize_position("D-ST"), "DST")
  expect_identical(normalize_position("DEFENSE"), "DST")
})

test_that("bare 'D' deixou de ser alias de DST", {
  err <- normalize_position("D")
  expect_true(is_domain_error(err))
  expect_identical(err$code, "posicao_fora_do_v1")
})

test_that("texto vazio ou so espacos vira erro de dominio", {
  for (blank in c("", "   ")) {
    err <- normalize_position(blank)
    expect_true(is_domain_error(err))
    expect_identical(err$code, "posicao_invalida")
  }
})

test_that("posicao fora do V1 vira erro de dominio estruturado, sem excecao", {
  err <- normalize_position("LB")
  expect_true(is_domain_error(err))
  expect_identical(err$code, "posicao_fora_do_v1")
  expect_match(err$message, "fora do conjunto V1")
  expect_identical(err$details$raw, "LB")
})

test_that("entrada nao-string vira erro de dominio", {
  err <- normalize_position(NA_character_)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "posicao_invalida")

  expect_true(is_domain_error(normalize_position(c("QB", "RB"))))
  expect_true(is_domain_error(normalize_position(1L)))
})

# --- parse_snapshot_bundle(): I/O & Edge-Case Matrix (spec Story 1.2) -------

valid_bundle_dir <- test_path("fixtures/snapshot-valid")

test_that("bundle valido -> objeto canonico tipado", {
  out <- parse_snapshot_bundle(read_snapshot_bundle(valid_bundle_dir))

  expect_false(is_domain_error(out))
  expect_s3_class(out, "fdwr_snapshot_bundle")
  expect_identical(names(out), c("metadata", "players", "qa_report"))
  expect_identical(nrow(out$players), 4L)
  expect_setequal(names(out$players), c("player_id", names(snapshot_schema()$players)[-1],
                                        names(snapshot_schema()$metrics)[-1]))

  # identidade + metricas unidas por player_id
  expect_true(all(c("display_name", "points", "vor", "tier", "tier_cliff") %in% names(out$players)))

  # posicoes normalizadas (D/ST -> DST)
  expect_setequal(out$players$position, c("QB", "RB", "WR", "DST"))

  # tipos coagidos
  expect_type(out$players$tier, "integer")
  expect_type(out$players$tier_cliff, "logical")
  expect_type(out$players$points, "double")

  # opcionais ausentes -> NA tipado, presentes preservados
  expect_true(all(is.na(out$players$floor)))
  expect_type(out$players$floor, "double")
  expect_true(all(is.na(out$players$sd_points)))
  expect_false(anyNA(out$players$adp))

  # determinismo
  expect_identical(out, parse_snapshot_bundle(read_snapshot_bundle(valid_bundle_dir)))

  # qa_report cru
  expect_type(out$qa_report, "list")

  # metadados exigidos e expostos
  for (campo in c("season", "generated_at", "pipeline_version", "source_list",
                  "scoring_hash", "content_hash", "qa_summary", "schema_version")) {
    expect_false(is.null(out$metadata[[campo]]))
  }
})

test_that("adapter domain_error passa direto pelo parser", {
  adapter_err <- read_snapshot_bundle(withr::local_tempdir())  # dir vazio
  expect_true(is_domain_error(adapter_err))
  expect_identical(parse_snapshot_bundle(adapter_err), adapter_err)
})

test_that("coluna obrigatoria ausente -> snapshot_coluna_ausente (details$campo)", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metrics$points <- NULL

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_coluna_ausente")
  expect_identical(err$details$arquivo, "metrics.csv")
  expect_identical(err$details$campo, "points")
})

test_that("tipo nao coercivel -> snapshot_tipo_invalido nomeia campo, valor, motivo", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metrics$tier <- as.character(d$metrics$tier)
  d$metrics$tier[2] <- "abc"

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_tipo_invalido")
  expect_identical(err$details$campo, "tier")
  expect_identical(err$details$valor, "abc")
  expect_identical(err$details$motivo, "nao_coercivel")
})

test_that("celula vazia em coluna obrigatoria -> snapshot_tipo_invalido motivo vazio", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metrics$points <- as.character(d$metrics$points)
  d$metrics$points[3] <- ""

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_tipo_invalido")
  expect_identical(err$details$campo, "points")
  expect_identical(err$details$motivo, "vazio")
})

test_that("tier_cliff vazio (obrigatorio) -> snapshot_tipo_invalido motivo vazio", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metrics$tier_cliff <- as.character(d$metrics$tier_cliff)
  d$metrics$tier_cliff[1] <- ""

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_tipo_invalido")
  expect_identical(err$details$campo, "tier_cliff")
  expect_identical(err$details$motivo, "vazio")
})

test_that("coluna inteira com valor nao inteiro -> motivo nao_inteiro, sem arredondar", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metrics$tier <- as.character(d$metrics$tier)
  d$metrics$tier[2] <- "2.7"

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_tipo_invalido")
  expect_identical(err$details$campo, "tier")
  expect_identical(err$details$motivo, "nao_inteiro")
})

test_that("colunas fora do schema sao descartadas", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$players$scraped_at <- "2025-08-30"

  out <- parse_snapshot_bundle(d)
  expect_false(is_domain_error(out))
  expect_false("scraped_at" %in% names(out$players))
})

test_that("nomes de coluna duplicados num CSV -> snapshot_formato_invalido", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  names(d$players)[names(d$players) == "nfl_team"] <- "player_id"

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_formato_invalido")
  expect_identical(err$details$arquivo, "players.csv")
})

test_that("player_id duplicado -> snapshot_player_id_duplicado (cada arquivo)", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$players <- rbind(d$players, d$players[1, ])
  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_player_id_duplicado")
  expect_identical(err$details$arquivo, "players.csv")
  expect_identical(err$details$player_id, "p1")

  d2 <- read_snapshot_bundle(valid_bundle_dir)
  d2$metrics <- rbind(d2$metrics, d2$metrics[2, ])
  err2 <- parse_snapshot_bundle(d2)
  expect_identical(err2$code, "snapshot_player_id_duplicado")
  expect_identical(err2$details$arquivo, "metrics.csv")
})

test_that("bundle vazio -> snapshot_bundle_vazio (nao crasha no fill)", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metrics <- d$metrics[0, ]

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_bundle_vazio")
})

test_that("schema_version incompativel -> snapshot_schema_incompativel", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metadata$schema_version <- "snapshot-bundle-v2"

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_schema_incompativel")
  expect_identical(err$details$encontrado, "snapshot-bundle-v2")
})

test_that("metadata como array/data.frame -> snapshot_formato_invalido", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metadata <- data.frame(a = 1)

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_formato_invalido")
  expect_identical(err$details$arquivo, "metadata.json")
})

test_that("metadado obrigatorio ausente -> snapshot_metadado_ausente", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  d$metadata$scoring_hash <- NULL

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_metadado_ausente")
  expect_identical(err$details$campo, "scoring_hash")
})

test_that("posicao em variacao D/ST normaliza; posicao invalida -> erro com player_id", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  expect_identical(d$players$position[d$players$player_id == "p4"], "D/ST")

  d$players$position[d$players$player_id == "p3"] <- "LB"
  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_posicao_invalida")
  expect_identical(err$details$player_id, "p3")
})

test_that("join incompleto -> snapshot_join_incompleto separa direcoes", {
  d <- read_snapshot_bundle(valid_bundle_dir)
  # p2 só em players; muda um id de metrics para criar órfão só em metrics
  d$metrics <- d$metrics[d$metrics$player_id != "p2", ]
  d$metrics$player_id[d$metrics$player_id == "p3"] <- "p9"

  err <- parse_snapshot_bundle(d)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_join_incompleto")
  expect_setequal(err$details$apenas_em_players, c("p2", "p3"))
  expect_identical(err$details$apenas_em_metrics, "p9")
})

test_that("parser de dominio nao abre arquivos nem importa jsonlite/utils", {
  candidates <- c(
    test_path("..", "..", "R", "domain_snapshot.R"),
    system.file("R", "domain_snapshot.R", package = "fantasydraftwarroom")
  )
  path <- Filter(function(p) nzchar(p) && file.exists(p), candidates)[1]
  skip_if(is.na(path) || is.null(path), "fonte de domain_snapshot.R indisponivel")

  src <- readLines(path)
  expect_false(any(grepl("read\\.csv|fromJSON|readLines|file\\.exists|readChar", src)))
  expect_false(any(grepl("jsonlite::|utils::|yaml::|library\\(", src)))
})
