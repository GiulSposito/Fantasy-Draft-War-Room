# Adapter de coleta (spec Story 1.4). Puro / sem rede: exercita o guard de
# pacote ausente (linha da I/O-Matrix "ffanalytics ausente"), o achatamento de
# um data.frame em memoria com a forma da saida do projections_table mais o
# add_player_info, e a coercao da config numerica do pipeline.

test_that("collect_ffanalytics_projections: pacote ausente -> ffanalytics_ausente", {
  skip_if(
    requireNamespace("ffanalytics", quietly = TRUE),
    "ffanalytics instalado neste ambiente (o guard so dispara sem o pacote)"
  )
  err <- collect_ffanalytics_projections(list(), list(), 2025L, "CBS")
  expect_true(is_domain_error(err))
  expect_identical(err$code, "ffanalytics_ausente")
  expect_match(err$message, "renv::install")
})

flat_like <- function() {
  data.frame(
    id = c("1", "1", "1", "2", "2", "3"),
    pos = c("QB", "QB", "QB", "RB", "RB", "WR"),
    avg_type = c("average", "robust", "weighted", "average", "robust", "average"),
    points = c(300, 290, 310, 250, 240, 200),
    points_vor = c(90, 88, 95, 70, 66, 40),
    tier = c(1, 1, 1, 2, 2, 3),
    pos_rank = c(1, 1, 1, 3, 3, 5),
    sd_pts = c(30, 31, 29, 35, 36, 28),
    floor = c(260, 250, 270, 210, 205, 170),
    first_name = c("Josh", "Josh", "Josh", "Bijan", "Bijan", "CeeDee"),
    last_name = c("Allen", "Allen", "Allen", "Robinson", "Robinson", "Lamb"),
    team = c("BUF", "BUF", "BUF", "ATL", "ATL", "DAL"),
    stringsAsFactors = FALSE
  )
}

test_that("ffanalytics_flatten: renomeia, seleciona avg_type average, dedup id", {
  out <- ffanalytics_flatten(flat_like())
  expect_false(is_domain_error(out))
  expect_identical(out$player_id, c("1", "2", "3"))
  expect_true(all(c("player_id", "vor", "position", "sd_points") %in% names(out)))
  expect_false(any(c("id", "points_vor", "pos", "sd_pts", "avg_type") %in% names(out)))
  expect_identical(out$vor, c(90, 70, 40))
  expect_identical(out$position, c("QB", "RB", "WR"))
  expect_identical(out$display_name, c("Josh Allen", "Bijan Robinson", "CeeDee Lamb"))
  expect_identical(out$sd_points, c(30, 35, 28))
  expect_identical(out$floor, c(260, 210, 170))
})

test_that("ffanalytics_flatten: usa 'player' quando presente, senao first+last", {
  df <- flat_like()
  df$player <- paste0("P", df$id)
  out <- ffanalytics_flatten(df)
  expect_identical(out$display_name, c("P1", "P2", "P3"))
})

test_that("ffanalytics_flatten: coluna requerida ausente -> coleta_ffanalytics_falhou", {
  df <- flat_like()
  df$points_vor <- NULL
  err <- ffanalytics_flatten(df)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "coleta_ffanalytics_falhou")
  expect_identical(err$details$faltando, "points_vor")
})

test_that("ffanalytics_flatten: id NA/vazio -> coleta_ffanalytics_falhou", {
  df <- flat_like()
  df$id[1] <- NA
  expect_identical(ffanalytics_flatten(df)$code, "coleta_ffanalytics_falhou")
  df$id <- flat_like()$id
  df$id[1] <- ""
  expect_identical(ffanalytics_flatten(df)$code, "coleta_ffanalytics_falhou")
})

test_that("ffanalytics_flatten: avg_type presente sem 'average' -> coleta_ffanalytics_falhou", {
  df <- flat_like()
  df$avg_type <- "robust"
  err <- ffanalytics_flatten(df)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "coleta_ffanalytics_falhou")
})

test_that("ffanalytics_flatten: sem player/first/last -> coleta_ffanalytics_falhou", {
  df <- flat_like()
  df$first_name <- NULL
  df$last_name <- NULL
  err <- ffanalytics_flatten(df)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "coleta_ffanalytics_falhou")
})

test_that("ffanalytics_flatten: nomes todos NA/vazios -> coleta_ffanalytics_falhou", {
  df <- flat_like()
  df$first_name <- NA_character_
  df$last_name <- ""
  err <- ffanalytics_flatten(df)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "coleta_ffanalytics_falhou")
})

test_that("ffanalytics_flatten: sem coluna avg_type usa todas as linhas", {
  df <- flat_like()[flat_like()$avg_type == "average", ]
  df$avg_type <- NULL
  out <- ffanalytics_flatten(df)
  expect_identical(out$player_id, c("1", "2", "3"))
})

test_that("ffanalytics_named_num: lista nomeada -> vetor numerico nomeado; NULL -> NULL", {
  v <- ffanalytics_named_num(list(QB = 13, RB = 35))
  expect_identical(v, c(QB = 13, RB = 35))
  expect_null(ffanalytics_named_num(NULL))
  expect_null(ffanalytics_named_num(list()))
})
