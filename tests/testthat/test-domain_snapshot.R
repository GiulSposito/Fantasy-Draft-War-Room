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
