# I/O & Edge-Case Matrix de domain_schedule (spec Story 2.2).

team_entry <- function(id, name = paste("Time", id), is_user = FALSE) {
  list(fantasy_team_id = id, display_name = name, is_user = is_user)
}

# 12 times canonicos, o 3o e o do operador.
ref_entries <- function() {
  ids <- c("t01", "t02", "t03", "t04", "t05", "t06",
           "t07", "t08", "t09", "t10", "t11", "t12")
  lapply(ids, function(id) team_entry(id, is_user = identical(id, "t03")))
}

# --- parse_league_teams -------------------------------------------------

test_that("times validos -> data.frame canonico em ordem de cadastro", {
  df <- parse_league_teams(ref_entries())
  expect_s3_class(df, "data.frame")
  expect_identical(names(df), c("fantasy_team_id", "display_name", "is_user"))
  expect_type(df$fantasy_team_id, "character")
  expect_type(df$display_name, "character")
  expect_type(df$is_user, "logical")
  expect_identical(df$fantasy_team_id, vapply(ref_entries(), `[[`, character(1L), "fantasy_team_id"))
  expect_identical(which(df$is_user), 3L)
})

test_that("forma invalida -> league_teams_malformado", {
  for (bad in list(42, "x", ref_entries()[[1]], list(team_entry("a")),
                   list(team_entry("a"), list(display_name = "x", is_user = FALSE)))) {
    e <- parse_league_teams(bad)
    expect_true(is_domain_error(e))
    expect_identical(e$code, "league_teams_malformado")
  }
})

test_that("id vazio, nao-texto ou duplicado -> league_teams_id_invalido", {
  e1 <- parse_league_teams(list(team_entry("", is_user = TRUE), team_entry("b")))
  expect_identical(e1$code, "league_teams_id_invalido")

  e2 <- parse_league_teams(list(team_entry(5L, is_user = TRUE), team_entry("b")))
  expect_identical(e2$code, "league_teams_id_invalido")
  expect_identical(e2$details$fantasy_team_id, 5L)

  e3 <- parse_league_teams(list(
    team_entry("dup", is_user = TRUE), team_entry("b"), team_entry("dup")
  ))
  expect_identical(e3$code, "league_teams_id_invalido")
  expect_identical(e3$details$fantasy_team_id, "dup")
})

test_that("ids que so diferem por espaco em volta colidem -> league_teams_id_invalido", {
  e <- parse_league_teams(list(
    team_entry("t1", is_user = TRUE), team_entry(" t1")
  ))
  expect_identical(e$code, "league_teams_id_invalido")
  expect_identical(e$details$fantasy_team_id, "t1")
})

test_that("time do operador != 1 -> league_teams_usuario_invalido com details$encontrados", {
  none <- parse_league_teams(list(team_entry("a"), team_entry("b")))
  expect_identical(none$code, "league_teams_usuario_invalido")
  expect_identical(none$details$encontrados, 0L)

  two <- parse_league_teams(list(
    team_entry("a", is_user = TRUE), team_entry("b", is_user = TRUE)
  ))
  expect_identical(two$code, "league_teams_usuario_invalido")
  expect_identical(two$details$encontrados, 2L)
})

test_that("is_user nao-logico -> league_teams_malformado", {
  e <- parse_league_teams(list(
    list(fantasy_team_id = "a", display_name = "A", is_user = "yes"),
    team_entry("b")
  ))
  expect_identical(e$code, "league_teams_malformado")
})

test_that("domain_error na entrada passa direto", {
  err <- domain_error("upstream", "erro anterior")
  expect_identical(parse_league_teams(err), err)
})

# --- snake_draw_order -------------------------------------------------

test_that("sorteio reprodutivel: identical, permutacao, sem tocar o RNG global", {
  set.seed(123)
  runif(1)
  before <- get(".Random.seed", envir = globalenv())

  ids <- ref_entries() |> vapply(`[[`, character(1L), "fantasy_team_id")
  a <- snake_draw_order(ids, seed = 42)
  b <- snake_draw_order(ids, seed = 42)

  after <- get(".Random.seed", envir = globalenv())
  expect_identical(a, b)
  expect_setequal(a, ids)
  expect_length(a, length(ids))
  expect_identical(before, after)
})

test_that("snake_draw_order restaura ausencia de .Random.seed", {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  out <- snake_draw_order(c("a", "b", "c"), seed = 1)
  expect_setequal(out, c("a", "b", "c"))
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("snake_draw_order golden: RNG fixo, vetor permutado exato para seed 42", {
  expect_identical(
    snake_draw_order(c("a", "b", "c", "d", "e"), seed = 42),
    c("a", "e", "d", "c", "b")
  )
})

test_that("domain_error em team_ids passa direto", {
  err <- domain_error("upstream", "erro anterior")
  expect_identical(snake_draw_order(err, seed = 1), err)
})

test_that("seed invalida -> snake_seed_invalida com details$seed", {
  for (bad in list("x", 1.5, Inf, NA)) {
    e <- snake_draw_order(c("a", "b"), seed = bad)
    expect_true(is_domain_error(e))
    expect_identical(e$code, "snake_seed_invalida")
  }
})

test_that("team_ids invalido -> snake_parametro_invalido", {
  for (bad in list(c("a"), c("a", "a"), c("a", NA), c("a", ""), list("a", "b"))) {
    e <- snake_draw_order(bad, seed = 1)
    expect_true(is_domain_error(e))
    expect_identical(e$code, "snake_parametro_invalido")
    expect_identical(e$details$campo, "team_ids")
  }
})

# --- validate_first_round_order --------------------------------------

test_that("ordem = permutacao exata -> NULL", {
  ids <- c("a", "b", "c", "d")
  expect_null(validate_first_round_order(c("c", "a", "d", "b"), ids))
})

test_that("ordem incompleta / sobrando / repetida -> snake_ordem_invalida", {
  ids <- c("a", "b", "c", "d")

  falta <- validate_first_round_order(c("a", "b", "c"), ids)
  expect_identical(falta$code, "snake_ordem_invalida")
  expect_identical(falta$details$faltando, "d")

  sobra <- validate_first_round_order(c("a", "b", "c", "d", "e"), ids)
  expect_identical(sobra$details$sobrando, "e")

  rep <- validate_first_round_order(c("a", "b", "c", "c"), ids)
  expect_identical(rep$details$duplicados, "c")
  expect_identical(rep$details$faltando, "d")
})

test_that("vazio/vazio nao e permutacao valida", {
  expect_identical(
    validate_first_round_order(character(0), character(0))$code,
    "snake_ordem_invalida"
  )
})

test_that("team_ids com duplicata -> snake_ordem_invalida com os duplicados nos details", {
  e <- validate_first_round_order(c("a", "b"), c("a", "a", "b"))
  expect_identical(e$code, "snake_ordem_invalida")
  expect_identical(e$details$duplicados, "a")
})

test_that("comprimento de order != team_ids -> invalido mesmo sem ids faltando/sobrando", {
  # order com repeticao: setdiff nos dois sentidos vazio, mas nao e permutacao
  e <- validate_first_round_order(c("a", "b", "b"), c("a", "b"))
  expect_identical(e$code, "snake_ordem_invalida")
})

test_that("domain_error em order ou team_ids passa direto", {
  err <- domain_error("upstream", "erro anterior")
  expect_identical(validate_first_round_order(err, c("a", "b")), err)
  expect_identical(validate_first_round_order(c("a", "b"), err), err)
})

# --- snake_schedule --------------------------------------------------

test_that("snake golden: [A,B,C,D] x 2 rounds", {
  df <- snake_schedule(c("A", "B", "C", "D"), user_team_id = "C", rounds = 2L)
  expect_identical(df$fantasy_team_id, c("A", "B", "C", "D", "D", "C", "B", "A"))
  expect_identical(df$pick_in_round, rep(1:4, 2L))
  expect_identical(df$round, rep(1:2, each = 4L))
  expect_identical(df$overall_pick, 1:8)
  expect_identical(df$is_user_team, df$fantasy_team_id == "C")
})

test_that("schedule feliz: 12 ids, rounds=15, um slot por time por round", {
  ids <- ref_entries() |> vapply(`[[`, character(1L), "fantasy_team_id")
  df <- snake_schedule(ids, user_team_id = ids[3], rounds = 15L)

  expect_identical(nrow(df), 180L)
  expect_identical(df$overall_pick, 1:180)
  expect_identical(df$fantasy_team_id[1:12], ids)
  expect_identical(df$fantasy_team_id[13:24], rev(ids))
  expect_identical(sum(df$is_user_team), 15L)
  expect_true(all(df$fantasy_team_id[df$is_user_team] == ids[3]))
  per_round <- table(df$round, df$fantasy_team_id)
  expect_true(all(per_round == 1L))
  # round par = inverso exato do impar anterior
  for (r in seq(2L, 15L, by = 2L)) {
    even <- df$fantasy_team_id[df$round == r]
    odd <- df$fantasy_team_id[df$round == r - 1L]
    expect_identical(even, rev(odd))
  }
})

test_that("schedule deterministico entre execucoes", {
  ids <- c("x", "y", "z")
  expect_identical(
    snake_schedule(ids, "y", rounds = 7L),
    snake_schedule(ids, "y", rounds = 7L)
  )
})

test_that("parametro invalido -> snake_parametro_invalido com details$campo", {
  e1 <- snake_schedule(c("a"), "a", rounds = 15L)
  expect_identical(e1$code, "snake_parametro_invalido")
  expect_identical(e1$details$campo, "first_round_order")

  e2 <- snake_schedule(c("a", "a"), "a", rounds = 15L)
  expect_identical(e2$details$campo, "first_round_order")

  e3 <- snake_schedule(c("a", "b"), "a", rounds = 1.5)
  expect_identical(e3$code, "snake_parametro_invalido")
  expect_identical(e3$details$campo, "rounds")

  e4 <- snake_schedule(c("a", "b"), "a", rounds = 0L)
  expect_identical(e4$details$campo, "rounds")
})

test_that("time do operador fora da ordem -> snake_time_usuario_ausente", {
  e <- snake_schedule(c("a", "b", "c"), user_team_id = "z", rounds = 3L)
  expect_identical(e$code, "snake_time_usuario_ausente")
})

test_that("rounds que estouraria o range de integer -> snake_parametro_invalido, nao excecao", {
  e <- snake_schedule(c("a", "b"), "a", rounds = 2e9)
  expect_true(is_domain_error(e))
  expect_identical(e$code, "snake_parametro_invalido")
  expect_identical(e$details$campo, "rounds")
})

test_that("domain_error em first_round_order passa direto", {
  err <- domain_error("upstream", "erro anterior")
  expect_identical(snake_schedule(err, "a"), err)
})

# --- pureza / determinismo -----------------------------------------

test_that("dominio puro: sem I/O, sem yaml/jsonlite, sem clock, sem shiny/DBI", {
  src <- readLines(test_path("..", "..", "R", "domain_schedule.R"))
  code <- src[!grepl("^\\s*#", src) & !grepl("^#'", src)]
  forbidden <- paste(
    "readLines", "read\\.csv", "read_yaml", "read_scoring_config\\(",
    "fromJSON", "readBin", "\\bfile\\(", "file\\.exists", "file\\.path",
    "Sys\\.(time|getenv|Date|setlocale)", "proc\\.time", "\\bdate\\(",
    "library\\(", "yaml::", "jsonlite::", "shiny", "\\bDBI\\b",
    sep = "|"
  )
  expect_false(any(grepl(forbidden, code)))
})

test_that("determinismo sob LC_COLLATE=C", {
  ids <- c("b", "a", "c", "d")
  unforced_order <- snake_draw_order(ids, seed = 7)
  unforced_sched <- snake_schedule(ids, "a", rounds = 6L)
  forced <- withr::with_locale(
    c(LC_COLLATE = "C"),
    list(
      order = snake_draw_order(ids, seed = 7),
      sched = snake_schedule(ids, "a", rounds = 6L)
    )
  )
  expect_identical(forced$order, unforced_order)
  expect_identical(forced$sched, unforced_sched)
})
