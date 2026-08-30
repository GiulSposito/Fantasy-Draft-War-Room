# I/O & Edge-Case Matrix de validate_snapshot_quality (spec Story 1.5).

valid_dir <- test_path("fixtures/snapshot-valid")
raw_bundle <- function() read_snapshot_bundle(valid_dir)
active_scoring <- function() read_scoring_config(file.path(valid_dir, "scoring.yml"))

finding_codes <- function(f) vapply(f, function(x) x$code, character(1L))
blockers <- function(f) Filter(function(x) identical(x$severity, "bloqueante"), f)
by_code <- function(f, code) Filter(function(x) identical(x$code, code), f)

test_that("bundle saudavel + scoring compativel -> zero bloqueantes", {
  f <- validate_snapshot_quality(raw_bundle(), active_scoring())
  expect_length(blockers(f), 0L)
  expect_true(all(vapply(f, function(x) x$severity, "") == "aviso"))
})

test_that("campo obrigatorio de jogador NA -> bloqueante por (campo, player_id, tabela)", {
  d <- raw_bundle()
  d$metrics$points[2] <- NA
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_campo_obrigatorio_ausente")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$severity, "bloqueante")
  expect_identical(hit[[1]]$details$campo, "points")
  expect_identical(hit[[1]]$details$player_id, "p2")
  expect_identical(hit[[1]]$details$tabela, "metrics.csv")
})

test_that("campo de players NA e coluna de players ausente -> ambos com campo/player_id/tabela", {
  d <- raw_bundle()
  d$players$normalized_name[2] <- NA
  d$players$position <- NULL
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_campo_obrigatorio_ausente")

  nn <- Filter(function(x) x$details$campo == "normalized_name", hit)
  expect_length(nn, 1L)
  expect_identical(nn[[1]]$details$player_id, "p2")
  expect_identical(nn[[1]]$details$tabela, "players.csv")

  pos <- Filter(function(x) x$details$campo == "position", hit)
  expect_length(pos, 1L)
  expect_true(is.na(pos[[1]]$details$player_id))
  expect_identical(pos[[1]]$details$tabela, "players.csv")
})

test_that("coluna obrigatoria ausente -> bloqueante com player_id NA e tabela", {
  d <- raw_bundle()
  d$metrics$vor <- NULL
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_campo_obrigatorio_ausente")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$details$campo, "vor")
  expect_true(is.na(hit[[1]]$details$player_id))
  expect_identical(hit[[1]]$details$tabela, "metrics.csv")
})

test_that("player_id em branco em metrics.csv -> flagado por tabela", {
  d <- raw_bundle()
  d$metrics$player_id[3] <- ""
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- Filter(function(x) {
    x$code == "snapshot_campo_obrigatorio_ausente" &&
      x$details$campo == "player_id" && identical(x$details$tabela, "metrics.csv")
  }, f)
  expect_length(hit, 1L)
})

test_that("metadado obrigatorio ausente -> snapshot_metadado_ausente (campo)", {
  d <- raw_bundle()
  d$metadata$qa_summary <- NULL
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_metadado_ausente")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$details$campo, "qa_summary")
  expect_identical(hit[[1]]$severity, "bloqueante")
})

test_that("metadado multi-elemento todo NA -> ausente", {
  d <- raw_bundle()
  d$metadata$source_list <- c(NA, NA)
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_metadado_ausente")
  expect_true("source_list" %in% vapply(hit, function(x) x$details$campo, ""))
})

test_that("metadata presente mas nao-objeto -> snapshot_metadado_ilegivel, sem cascata nem scoring", {
  d <- raw_bundle()
  d$metadata <- c("a", "b")
  f <- validate_snapshot_quality(d, active_scoring())
  expect_length(by_code(f, "snapshot_metadado_ilegivel"), 1L)
  expect_length(by_code(f, "snapshot_metadado_ausente"), 0L)
  expect_length(by_code(f, "snapshot_scoring_incompativel"), 0L)
})

test_that("player_id duplicado -> snapshot_player_id_duplicado (player_id)", {
  d <- raw_bundle()
  d$metrics <- rbind(d$metrics, d$metrics[1, ])
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_player_id_duplicado")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$details$player_id, "p1")
})

test_that("nome ambiguo sem desambiguacao -> snapshot_nome_ambiguo (player_ids)", {
  d <- raw_bundle()
  d$players$normalized_name[3] <- d$players$normalized_name[2]
  d$players$position[3] <- d$players$position[2]
  d$players$nfl_team[3] <- d$players$nfl_team[2]
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_nome_ambiguo")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$severity, "bloqueante")
  expect_identical(hit[[1]]$details$player_ids, c("p2", "p3"))
  expect_identical(hit[[1]]$details$normalized_name, "christian mccaffrey")
})

test_that("nome ambiguo agrupa por posicao NORMALIZADA (DST vs D/ST)", {
  d <- raw_bundle()
  d$players$display_name[1] <- d$players$display_name[4]
  d$players$normalized_name[1] <- d$players$normalized_name[4]
  d$players$nfl_team[1] <- d$players$nfl_team[4]
  d$players$position[1] <- "DST"   # p4 e "D/ST"; normalizam ao mesmo
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_nome_ambiguo")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$details$player_ids, c("p1", "p4"))
})

test_that("nome em branco nao produz snapshot_nome_ambiguo espurio", {
  d <- raw_bundle()
  d$players$normalized_name[2] <- ""
  d$players$normalized_name[3] <- ""
  d$players$position[3] <- d$players$position[2]
  d$players$nfl_team[3] <- d$players$nfl_team[2]
  f <- validate_snapshot_quality(d, active_scoring())
  expect_length(by_code(f, "snapshot_nome_ambiguo"), 0L)
})

test_that("nome repetido mas desambiguavel -> sem achado", {
  d <- raw_bundle()
  d$players$normalized_name[3] <- d$players$normalized_name[2]  # posicao/time distintos
  f <- validate_snapshot_quality(d, active_scoring())
  expect_length(by_code(f, "snapshot_nome_ambiguo"), 0L)
})

test_that("posicao fora do V1 -> snapshot_posicao_fora_do_v1 (player_id, raw)", {
  d <- raw_bundle()
  d$players$position[1] <- "FB"
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "snapshot_posicao_fora_do_v1")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$details$player_id, "p1")
  expect_identical(hit[[1]]$details$raw, "FB")
})

test_that("ADP invalido quando informado -> snapshot_adp_invalido (inclui NaN)", {
  for (bad in list(-1, 0, Inf, NaN)) {
    d <- raw_bundle()
    d$metrics$adp[1] <- bad
    f <- validate_snapshot_quality(d, active_scoring())
    hit <- by_code(f, "snapshot_adp_invalido")
    expect_length(hit, 1L)
    expect_identical(hit[[1]]$severity, "bloqueante")
    expect_identical(hit[[1]]$details$player_id, "p1")
  }
})

test_that("ADP alto e legitimo -> sem achado (sem limite superior)", {
  d <- raw_bundle()
  d$metrics$adp[1] <- 9999
  f <- validate_snapshot_quality(d, active_scoring())
  expect_length(by_code(f, "snapshot_adp_invalido"), 0L)
})

test_that("ADP ausente (coluna toda NA) -> aviso snapshot_opcional_ausente, sem bloqueante", {
  d <- raw_bundle()
  d$metrics$adp <- NA
  f <- validate_snapshot_quality(d, active_scoring())
  expect_length(by_code(f, "snapshot_adp_invalido"), 0L)
  opt <- by_code(f, "snapshot_opcional_ausente")
  expect_true("adp" %in% vapply(opt, function(x) x$details$campo, ""))
  expect_true(all(vapply(opt, function(x) x$severity, "") == "aviso"))
})

test_that("scoring divergente -> bloqueante snapshot_scoring_incompativel (esperado, encontrado)", {
  scoring <- active_scoring()
  scoring$passing$yards <- 0.05
  f <- validate_snapshot_quality(raw_bundle(), scoring)
  hit <- by_code(f, "snapshot_scoring_incompativel")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$severity, "bloqueante")
  expect_false(is.null(hit[[1]]$details$esperado))
  expect_false(is.null(hit[[1]]$details$encontrado))
})

test_that("scoring indisponivel (domain_error) -> um bloqueante snapshot_scoring_indisponivel, code preservado", {
  err <- read_scoring_config(file.path(withr::local_tempdir(), "scoring.yml"))
  expect_true(is_domain_error(err))
  f <- validate_snapshot_quality(raw_bundle(), err)
  bl <- blockers(f)
  expect_length(bl, 1L)
  expect_identical(bl[[1]]$code, "snapshot_scoring_indisponivel")
  expect_identical(bl[[1]]$message, err$message)
  expect_identical(bl[[1]]$details$code, err$code)
  expect_length(by_code(f, "snapshot_scoring_incompativel"), 0L)
})

test_that("qa-report ausente -> bloqueante qa_report_ausente", {
  d <- raw_bundle()
  d$qa_report <- NULL
  f <- validate_snapshot_quality(d, active_scoring())
  hit <- by_code(f, "qa_report_ausente")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$severity, "bloqueante")
})

test_that("qa-report objeto sem chave findings -> bloqueante qa_report_ausente", {
  d <- raw_bundle()
  d$qa_report <- list(schema_version = "qa-report-v1")
  f <- validate_snapshot_quality(d, active_scoring())
  expect_length(by_code(f, "qa_report_ausente"), 1L)
})

test_that("qa-report findings [] (Story 1.4) -> nenhum achado de qa", {
  d <- raw_bundle()
  d$qa_report$findings <- list()
  f <- validate_snapshot_quality(d, active_scoring())
  expect_length(by_code(f, "qa_report_ausente"), 0L)
  expect_length(by_code(f, "qa_report_bloqueante"), 0L)
})

test_that("qa-report data.frame de 2+ linhas com severidade mista -> um bloqueante + um aviso", {
  d <- raw_bundle()
  d$qa_report$findings <- data.frame(
    code = c("cobertura_critica", "fonte_degradada"),
    severity = c("bloqueante", "aviso"),
    message = c("sem QBs", "ADP parcial"),
    stringsAsFactors = FALSE
  )
  f <- validate_snapshot_quality(d, active_scoring())
  bl <- by_code(f, "qa_report_bloqueante")
  av <- by_code(f, "qa_report_aviso")
  expect_length(bl, 1L)
  expect_length(av, 1L)
  expect_identical(bl[[1]]$message, "sem QBs")
  expect_identical(bl[[1]]$details$qa_code, "cobertura_critica")
  expect_identical(av[[1]]$message, "ADP parcial")
})

test_that("opcionais ausentes -> aviso, nunca bloqueante", {
  f <- validate_snapshot_quality(raw_bundle(), active_scoring())
  opt <- by_code(f, "snapshot_opcional_ausente")
  expect_gt(length(opt), 0L)
  expect_true(all(vapply(opt, function(x) x$severity, "") == "aviso"))
  expect_true(all(c("floor", "ceiling", "sd_points") %in% vapply(opt, function(x) x$details$campo, "")))
})

test_that("posicao do V1 sem nenhum jogador -> aviso, ordem canonica exata", {
  f <- validate_snapshot_quality(raw_bundle(), active_scoring())
  cov <- by_code(f, "snapshot_cobertura_anomala")
  expect_identical(vapply(cov, function(x) x$details$posicao, ""), c("K", "TE"))
  expect_true(all(vapply(cov, function(x) x$severity, "") == "aviso"))
})

test_that("problemas simultaneos: sequencia de codes canonica exata e estavel", {
  d <- raw_bundle()
  d$metrics <- rbind(d$metrics, d$metrics[1, ])   # duplicata p1
  d$players$position[2] <- "FB"                   # posicao invalida p2
  d$metrics$adp[3] <- 0                           # ADP invalido p3
  scoring <- active_scoring()
  scoring$passing$yards <- 0.05                   # scoring divergente

  a <- validate_snapshot_quality(d, scoring)
  b <- validate_snapshot_quality(d, scoring)
  expect_identical(a, b)

  expect_identical(finding_codes(a), c(
    "snapshot_adp_invalido",
    "snapshot_player_id_duplicado",
    "snapshot_posicao_fora_do_v1",
    "snapshot_scoring_incompativel",
    "snapshot_cobertura_anomala",   # K
    "snapshot_cobertura_anomala",   # RB (p2 deixou de ser RB)
    "snapshot_cobertura_anomala",   # TE
    "snapshot_opcional_ausente",    # adp_sd
    "snapshot_opcional_ausente",    # ceiling
    "snapshot_opcional_ausente",    # ecr
    "snapshot_opcional_ausente",    # floor
    "snapshot_opcional_ausente",    # sd_points
    "snapshot_opcional_ausente"     # uncertainty
  ))
})

test_that("determinismo sob locale forcado", {
  d <- raw_bundle()
  d$metrics <- rbind(d$metrics, d$metrics[1, ])
  d$players$position[2] <- "FB"
  unforced <- validate_snapshot_quality(d, active_scoring())
  forced <- withr::with_locale(c(LC_COLLATE = "C"), validate_snapshot_quality(d, active_scoring()))
  expect_identical(forced, unforced)
})

test_that("deserialized nao-lista e nao-erro -> um bloqueante snapshot_bundle_ilegivel", {
  f <- validate_snapshot_quality("nao e um bundle", active_scoring())
  expect_length(f, 1L)
  expect_identical(f[[1]]$code, "snapshot_bundle_ilegivel")
  expect_identical(f[[1]]$severity, "bloqueante")
})

test_that("adapter falhou: exatamente um bloqueante derivado, code + message + details preservados", {
  err <- read_snapshot_bundle(withr::local_tempdir())
  expect_true(is_domain_error(err))
  f <- validate_snapshot_quality(err, active_scoring())
  expect_length(f, 1L)
  expect_identical(f[[1]]$severity, "bloqueante")
  expect_identical(f[[1]]$code, err$code)
  expect_identical(f[[1]]$message, err$message)
  expect_identical(f[[1]]$details, err$details)
})

test_that("dominio puro: sem I/O, sem yaml/jsonlite/ffanalytics/clock", {
  src <- readLines(test_path("..", "..", "R", "domain_snapshot_quality.R"))
  code <- src[!grepl("^\\s*#", src) & !grepl("^#'", src)]
  forbidden <- paste(
    "readLines", "read\\.csv", "read_yaml", "fromJSON", "readBin", "file\\(",
    "file\\.exists", "Sys\\.(time|getenv)", "scrape_data", "projections_table",
    "library\\(", "ffanalytics::", "yaml::", "jsonlite::",
    sep = "|"
  )
  expect_false(any(grepl(forbidden, code)))
})
