# Helpers puros do composition root (spec Story 1.1, review round 1).

test_that("resolve_bind_port aceita inteiros validos", {
  expect_identical(resolve_bind_port(3939L), 3939L)
  expect_identical(resolve_bind_port(8080), 8080L)
  expect_identical(resolve_bind_port(1), 1L)
  expect_identical(resolve_bind_port(65535), 65535L)
})

test_that("resolve_bind_port rejeita fora de faixa, nao-inteiro e nao-numero", {
  for (bad in list(0, -1, 70000, "abc", NA, c(1, 2), 3939.5)) {
    err <- resolve_bind_port(bad)
    expect_true(is_domain_error(err))
    expect_identical(err$code, "porta_invalida")
  }
})

test_that("bind_host e sempre loopback", {
  expect_identical(bind_host(), "127.0.0.1")
})
