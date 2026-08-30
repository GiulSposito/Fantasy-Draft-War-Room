# Contrato de domain_error() / is_domain_error() (spec Story 1.1, review round 1).

test_that("domain_error monta a condicao classificada", {
  err <- domain_error(
    "posicao_fora_do_v1",
    "Posição 'LB' fora do conjunto V1.",
    list(raw = "LB", canonical = c("QB", "RB"))
  )
  expect_identical(
    class(err),
    c("posicao_fora_do_v1", "fdwr_domain_error", "error", "condition")
  )
  expect_identical(err$code, "posicao_fora_do_v1")
  expect_identical(err$message, "Posição 'LB' fora do conjunto V1.")
  expect_identical(err$details, list(raw = "LB", canonical = c("QB", "RB")))
})

test_that("domain_error usa lista de details vazia por padrao", {
  expect_identical(domain_error("x", "y")$details, list())
})

test_that("is_domain_error distingue domain_error de outros valores", {
  expect_true(is_domain_error(domain_error("x", "y")))
  expect_false(is_domain_error("um texto"))
  expect_false(is_domain_error(simpleError("boom")))
  expect_false(is_domain_error(NULL))
})
