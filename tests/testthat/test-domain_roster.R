# I/O & Edge-Case Matrix de domain_roster (spec Story 3.1).

# Pool sintetico: 6 posicoes, points variados, 1 par empatado (tie_a/tie_b,
# WR 195), 1 sem points (nopj, WR NA).
pool <- function() {
  data.frame(
    player_id = c(
      "qb1", "qb2", "qb3",
      "rb1", "rb2", "rb3", "rb4", "rb5",
      "wr1", "wr2", "wr3", "wr4", "wr5",
      "te1", "te2",
      "k1", "k2",
      "dst1", "dst2",
      "tie_a", "tie_b",
      "nopj"
    ),
    position = c(
      "QB", "QB", "QB",
      "RB", "RB", "RB", "RB", "RB",
      "WR", "WR", "WR", "WR", "WR",
      "TE", "TE",
      "K", "K",
      "DST", "DST",
      "WR", "WR",
      "WR"
    ),
    points = c(
      300, 280, 260,
      250, 240, 230, 220, 210,
      200, 190, 180, 170, 160,
      150, 140,
      120, 115,
      110, 105,
      195, 195,
      NA
    ),
    stringsAsFactors = FALSE
  )
}

ss <- c(QB = 1L, RB = 2L, WR = 2L, TE = 1L, FLEX = 1L, K = 1L, DST = 1L)
fe <- c("RB", "WR")

# effective_picks de 3 times (join effective_pick_projection + draft_slot).
picks3 <- function() {
  data.frame(
    overall_pick = c(1, 2, 3, 4, 5, 6, 7, 8, 9),
    player_id = c("qb1", "rb1", "wr1", "rb2", "wr2", "rb3", "qb2", "wr3", "te1"),
    fantasy_team_id = c("tB", "tA", "tC", "tC", "tA", "tB", "tA", "tC", "tB"),
    stringsAsFactors = FALSE
  )
}

full_roster <- c(
  "qb1", "rb1", "rb2", "rb3", "wr1", "wr2", "wr3",
  "te1", "k1", "dst1", "rb4", "qb2", "wr4"
)

# --- build_rosters ----------------------------------------------------------

test_that("rosters de todos os times, cada um em ordem de overall_pick", {
  r <- build_rosters(picks3())
  expect_identical(names(r), c("tA", "tB", "tC"))
  expect_identical(r$tA, c("rb1", "wr2", "qb2"))
  expect_identical(r$tB, c("qb1", "rb3", "te1"))
  expect_identical(r$tC, c("wr1", "rb2", "wr3"))
  expect_identical(r, build_rosters(picks3()))
})

test_that("picks vazias -> list()", {
  expect_identical(build_rosters(picks3()[0, ]), list())
})

test_that("effective_picks malformado -> roster_picks_malformado", {
  expect_identical(build_rosters(42)$code, "roster_picks_malformado")
  expect_identical(build_rosters(picks3()[, c("player_id", "fantasy_team_id")])$code,
                   "roster_picks_malformado")

  na_pid <- picks3()
  na_pid$player_id[2] <- NA
  expect_identical(build_rosters(na_pid)$code, "roster_picks_malformado")

  blank_tid <- picks3()
  blank_tid$fantasy_team_id[3] <- "  "
  expect_identical(build_rosters(blank_tid)$code, "roster_picks_malformado")

  dup_op <- picks3()
  dup_op$overall_pick[2] <- 1
  e <- build_rosters(dup_op)
  expect_identical(e$code, "roster_picks_malformado")
  expect_identical(e$details$overall_pick, 1)
})

test_that("domain_error na entrada passa direto", {
  err <- domain_error("upstream", "erro anterior")
  expect_identical(build_rosters(err), err)
})

# --- best_lineup ----------------------------------------------------------

test_that("roster completo: soma otima e FLEX = melhor RB/WR restante", {
  bl <- best_lineup(full_roster, pool(), ss, fe)
  expect_identical(bl$starters$QB, "qb1")
  expect_identical(bl$starters$RB, c("rb1", "rb2"))
  expect_identical(bl$starters$WR, c("wr1", "wr2"))
  expect_identical(bl$starters$TE, "te1")
  expect_identical(bl$starters$FLEX, "rb3") # 3o RB (230) > 3o WR (180)
  expect_identical(bl$starters$K, "k1")
  expect_identical(bl$starters$DST, "dst1")
  expect_identical(bl$total_points, 300 + 250 + 240 + 200 + 190 + 150 + 230 + 120 + 110)
  expect_identical(bl$empty_slots, character(0))
  expect_identical(bl$warnings, character(0))
  expect_identical(bl, best_lineup(full_roster, pool(), ss, fe))
})

test_that("cada jogador do roster recebe exatamente um rotulo", {
  bl <- best_lineup(full_roster, pool(), ss, fe)
  expect_setequal(bl$classification$player_id, unique(full_roster))
  expect_true(all(bl$classification$role %in%
                    c("titular", "flex", "banco", "redundancia")))
  expect_false(anyNA(bl$classification$role))
  expect_identical(bl$classification$player_id,
                   sort(unique(full_roster), method = "radix"))
})

test_that("roster parcial sem K/DST -> K e DST em empty_slots", {
  partial <- c("qb1", "rb1", "rb2", "rb3", "wr1", "wr2", "te1", "rb4", "wr3")
  bl <- best_lineup(partial, pool(), ss, fe)
  expect_identical(bl$empty_slots, c("DST", "K"))
  expect_identical(bl$starters$FLEX, "rb3")
  roles <- bl$classification$role[match(c("rb4", "wr3"), bl$classification$player_id)]
  expect_true(all(roles %in% c("banco", "redundancia")))
})

test_that("empate de projecao: menor player_id titula, o outro banco + upgrade", {
  roster <- c("qb1", "rb1", "rb2", "rb3", "wr1", "tie_a", "tie_b",
              "te1", "k1", "dst1")
  bl <- best_lineup(roster, pool(), ss, fe)
  expect_identical(bl$starters$WR, c("wr1", "tie_a"))
  expect_identical(bl$starters$FLEX, "rb3")
  cls <- bl$classification
  expect_identical(cls$role[cls$player_id == "tie_a"], "titular")
  expect_identical(cls$role[cls$player_id == "tie_b"], "banco")
  expect_true(cls$upgrade[cls$player_id == "tie_b"])
  expect_false(cls$upgrade[cls$player_id == "tie_a"])
})

test_that("jogador do roster sem projecao: nunca titula, entra em warnings", {
  roster <- c("qb1", "rb1", "rb2", "wr1", "wr2", "nopj",
              "te1", "k1", "dst1")
  bl <- best_lineup(roster, pool(), ss, fe)
  expect_identical(bl$warnings, "nopj")
  expect_false("nopj" %in% unlist(bl$starters, use.names = FALSE))
  expect_true(bl$classification$role[bl$classification$player_id == "nopj"] %in%
                c("banco", "redundancia"))
  expect_identical(bl$empty_slots, "FLEX") # so 2 WR, nenhum 3o RB/WR elegivel
})

test_that("starter_slots / flex_eligibility invalidos -> roster_config_invalido", {
  expect_identical(best_lineup(full_roster, pool(), c(QB = 1L), fe)$code,
                   "roster_config_invalido")
  expect_identical(best_lineup(full_roster, pool(), as.list(ss), fe)$code,
                   "roster_config_invalido")
  no_flex_key <- ss[names(ss) != "FLEX"]
  expect_identical(best_lineup(full_roster, pool(), no_flex_key, fe)$code,
                   "roster_config_invalido")
  expect_identical(best_lineup(full_roster, pool(), ss, c("RB", "TE"))$code,
                   "roster_config_invalido")
  expect_identical(best_lineup(full_roster, pool(), ss, character(0))$code,
                   "roster_config_invalido")
})

# --- marginal_gain ------------------------------------------------------

test_that("ganho marginal = diferenca nao-negativa do melhor lineup", {
  roster <- c("qb1", "rb1", "wr1", "wr2", "te1", "k1", "dst1")
  g <- marginal_gain("rb2", roster, pool(), ss, fe)
  base <- best_lineup(roster, pool(), ss, fe)$total_points
  with_c <- best_lineup(c(roster, "rb2"), pool(), ss, fe)$total_points
  expect_identical(g, with_c - base)
  expect_gt(g, 0)
  expect_identical(g, marginal_gain("rb2", roster, pool(), ss, fe))
})

test_that("candidato ja no roster ou sem projecao -> 0", {
  expect_identical(marginal_gain("rb1", full_roster, pool(), ss, fe), 0)
  expect_identical(marginal_gain("nopj", full_roster, pool(), ss, fe), 0)
  expect_identical(marginal_gain("fantasma", full_roster, pool(), ss, fe), 0)
})

test_that("candidato que nao melhora o lineup -> 0, nunca negativo", {
  expect_identical(marginal_gain("rb5", full_roster, pool(), ss, fe), 0)
})

test_that("marginal_gain propaga config invalida", {
  expect_identical(marginal_gain("rb5", full_roster, pool(), c(QB = 1L), fe)$code,
                   "roster_config_invalido")
})

# --- roster_feasibility -----------------------------------------------

test_that("obrigatorio inatingivel -> achado bloqueante nomeando o slot", {
  res <- roster_feasibility(c("qb1", "rb1"), 3, pool(), ss, fe)
  expect_identical(vapply(res, `[[`, character(1L), "code"),
                   rep("roster_slot_obrigatorio_inatingivel", length(res)))
  slots <- vapply(res, function(f) f$details$slot, character(1L))
  expect_setequal(slots, c("DST", "FLEX", "K", "RB", "TE", "WR"))
  wr <- Filter(function(f) f$details$slot == "WR", res)[[1]]
  expect_identical(wr$details$faltando, 2L)
  expect_identical(wr$details$picks_restantes, 3L)
  expect_identical(wr$severity, "bloqueante")
  expect_identical(res, roster_feasibility(c("qb1", "rb1"), 3, pool(), ss, fe))
})

test_that("tudo alcancavel -> list()", {
  expect_identical(roster_feasibility(c("qb1", "rb1"), 20, pool(), ss, fe), list())
  expect_identical(roster_feasibility(full_roster, 0, pool(), ss, fe), list())
})

test_that("remaining_picks invalido -> roster_parametro_invalido", {
  for (bad in list(-1, NA, 1.5, "x", c(1, 2))) {
    e <- roster_feasibility(full_roster, bad, pool(), ss, fe)
    expect_true(is_domain_error(e))
    expect_identical(e$code, "roster_parametro_invalido")
  }
})

test_that("ganho marginal deslocando um titular = so a diferenca", {
  roster <- c("qb2", "rb1", "rb2", "wr1", "wr2", "te1", "k1", "dst1")
  g <- marginal_gain("qb1", roster, pool(), ss, fe) # qb1 300 desloca qb2 280
  expect_identical(g, 20)
})

# --- best_lineup: casos degenerados ----------------------------------

test_that("empty_slots com multiplicidade > 1: roster com 0 RB", {
  roster <- c("qb1", "wr1", "wr2", "te1", "k1", "dst1")
  bl <- best_lineup(roster, pool(), ss, fe)
  expect_identical(sum(bl$empty_slots == "RB"), 2L)
  expect_true("FLEX" %in% bl$empty_slots)
})

test_that("roster vazio -> todos os slots vazios, sem titular", {
  bl <- best_lineup(character(0), pool(), ss, fe)
  expect_identical(bl$total_points, 0)
  expect_identical(nrow(bl$classification), 0L)
  expect_identical(bl$empty_slots,
                   sort(rep(names(ss), ss), method = "radix"))
  expect_identical(length(unlist(bl$starters, use.names = FALSE)), 0L)
})

test_that("players inutilizavel -> roster inteiro em warnings, nenhum titular", {
  for (bad in list(domain_error("x", "y"),
                   data.frame(id = "a", pts = 1))) {
    bl <- best_lineup(full_roster, bad, ss, fe)
    expect_setequal(bl$warnings, unique(full_roster))
    expect_identical(length(unlist(bl$starters, use.names = FALSE)), 0L)
    expect_identical(bl$empty_slots, sort(rep(names(ss), ss), method = "radix"))
  }
})

test_that("ids duplicados no roster -> dedup, sem linha duplicada", {
  bl <- best_lineup(c("qb1", "qb1", "rb1"), pool(), ss, fe)
  expect_identical(bl$classification$player_id, c("qb1", "rb1"))
})

test_that("FLEX com empate entre RB e WR -> menor player_id (byte) titula", {
  players <- data.frame(
    player_id = c("rb_hi1", "rb_hi2", "wr_hi1", "wr_hi2", "a_rb", "z_wr"),
    position = c("RB", "RB", "WR", "WR", "RB", "WR"),
    points = c(300, 290, 280, 270, 100, 100),
    stringsAsFactors = FALSE
  )
  roster <- players$player_id
  bl <- best_lineup(roster, players, ss, fe)
  expect_identical(bl$starters$FLEX, "a_rb")
  expect_identical(bl, best_lineup(roster, players, ss, fe))
})

# --- build_rosters: coercao e validacao -----------------------------

test_that("overall_pick factor -> ordem correta pelo rotulo, nao pelo codigo", {
  p <- data.frame(
    overall_pick = factor(c(9, 10)), # niveis ordenados como texto: "10" < "9"
    player_id = c("p9", "p10"),
    fantasy_team_id = c("t1", "t1"),
    stringsAsFactors = FALSE
  )
  expect_identical(build_rosters(p)$t1, c("p9", "p10"))
})

test_that("overall_pick NA / fracionario / < 1 -> roster_picks_malformado", {
  for (val in list(NA, 1.5, 0, -3)) {
    p <- picks3()
    p$overall_pick[1] <- val
    expect_identical(build_rosters(p)$code, "roster_picks_malformado")
  }
})

test_that("player_id repetido entre dois times -> roster_picks_malformado", {
  p <- picks3()
  p$player_id[5] <- p$player_id[1]
  e <- build_rosters(p)
  expect_identical(e$code, "roster_picks_malformado")
  expect_identical(e$details$player_id, p$player_id[1])
})

test_that("fantasy_team_id com espaco em volta nao gera time duplicado", {
  p <- picks3()
  p$fantasy_team_id[1] <- paste0(" ", p$fantasy_team_id[1])
  expect_identical(build_rosters(p), build_rosters(picks3()))
})

# --- determinismo / pureza -------------------------------------------

test_that("determinismo sob LC_COLLATE=C nas quatro funcoes", {
  base <- list(
    rosters = build_rosters(picks3()),
    lineup = best_lineup(full_roster, pool(), ss, fe),
    gain = marginal_gain("rb5", full_roster, pool(), ss, fe),
    feas = roster_feasibility(c("qb1", "rb1"), 3, pool(), ss, fe)
  )
  forced <- withr::with_locale(c(LC_COLLATE = "C"), list(
    rosters = build_rosters(picks3()),
    lineup = best_lineup(full_roster, pool(), ss, fe),
    gain = marginal_gain("rb5", full_roster, pool(), ss, fe),
    feas = roster_feasibility(c("qb1", "rb1"), 3, pool(), ss, fe)
  ))
  expect_identical(forced, base)
})

test_that("dominio puro: sem I/O, sem yaml/jsonlite, sem clock, sem shiny/DBI", {
  src <- readLines(test_path("..", "..", "R", "domain_roster.R"))
  code <- src[!grepl("^\\s*#", src) & !grepl("^#'", src)]
  forbidden <- paste(
    "DBI", "RSQLite", "dbConnect", "Sys\\.", "shiny", "readLines",
    "file\\.path", "\\byaml\\b", "jsonlite", "read\\.csv", "fromJSON",
    "library\\(",
    sep = "|"
  )
  expect_false(any(grepl(forbidden, code)))
})
