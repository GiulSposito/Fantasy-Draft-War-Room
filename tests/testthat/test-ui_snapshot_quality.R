# Modulo Shiny "Selecionar e validar snapshot" (spec Story 1.7) -- testServer.

meta_ok <- list(
  temporada = 2025L, geracao = "2025-08-30T12:00:00Z", fontes = c("CBS", "ESPN"),
  metodo = "0.1.0", scoring = "s", identidade_de_conteudo = "c0ffee"
)
vm_ok <- list(
  ok = TRUE, advance_allowed = TRUE, metadata = meta_ok,
  coverage = list(QB = 1L, TE = 0L), avisos = list(), bloqueios = list()
)
blocker <- list(
  code = "snapshot_posicao_fora_do_v1", severity = "bloqueante",
  message = "Posicao invalida", details = list()
)
vm_blocked <- list(
  ok = TRUE, advance_allowed = FALSE, metadata = NULL, coverage = NULL,
  avisos = list(), bloqueios = list(blocker)
)

test_that("nada carrega ate uma confirmacao explicita", {
  calls <- 0L
  load_fn <- function(dir) {
    calls <<- calls + 1L
    vm_ok
  }
  shiny::testServer(
    snapshot_quality_server,
    args = list(list_fn = function() c("/b/snap-2"), load_fn = load_fn),
    {
      session$setInputs(bundle = "/b/snap-2")
      expect_identical(calls, 0L)
      expect_null(valid_snapshot())
      expect_identical(output$status, "aguardando")
    }
  )
})

test_that("bundle valido confirmado libera o avanco e expoe o snapshot", {
  shiny::testServer(
    snapshot_quality_server,
    args = list(list_fn = function() c("/b/snap-2"), load_fn = function(dir) vm_ok),
    {
      session$setInputs(bundle = "/b/snap-2", confirm = 1)
      expect_identical(output$status, "válido")
      got <- valid_snapshot()
      expect_identical(got$bundle_dir, "/b/snap-2")
      expect_true(got$view_model$advance_allowed)
    }
  )
})

test_that("bloqueio trava o avanco (snapshot nao exposto)", {
  shiny::testServer(
    snapshot_quality_server,
    args = list(list_fn = function() c("/b/snap-2"), load_fn = function(dir) vm_blocked),
    {
      session$setInputs(bundle = "/b/snap-2", confirm = 1)
      expect_identical(output$status, "bloqueado")
      expect_null(valid_snapshot())
    }
  )
})

test_that("load_fn que lanca -> status 'erro', regiao nao fica em branco", {
  shiny::testServer(
    snapshot_quality_server,
    args = list(
      list_fn = function() c("/b/snap-2"),
      load_fn = function(dir) stop("boom")
    ),
    {
      session$setInputs(bundle = "/b/snap-2", confirm = 1)
      expect_null(rv$vm)
      expect_false(isTRUE(rv$busy))
      expect_identical(output$status, "erro")
      expect_match(output$region$html, "Falha ao carregar")
    }
  )
})

test_that("trocar o snapshot confirmado exige Reiniciar preparo", {
  calls <- 0L
  load_fn <- function(dir) {
    calls <<- calls + 1L
    vm_ok
  }
  shiny::testServer(
    snapshot_quality_server,
    args = list(list_fn = function() c("/b/snap-1", "/b/snap-2"), load_fn = load_fn),
    {
      session$setInputs(bundle = "/b/snap-2", confirm = 1)
      expect_identical(rv$selected, "/b/snap-2")

      # tentar trocar sem reiniciar: ignorado
      session$setInputs(bundle = "/b/snap-1", confirm = 2)
      expect_identical(rv$selected, "/b/snap-2")
      expect_identical(calls, 1L)

      # reiniciar limpa view-model + selecao
      session$setInputs(restart = 1)
      expect_null(rv$selected)
      expect_null(rv$vm)
      expect_null(valid_snapshot())

      # agora aceita o novo
      session$setInputs(bundle = "/b/snap-1", confirm = 3)
      expect_identical(rv$selected, "/b/snap-1")
      expect_identical(calls, 2L)
    }
  )
})

test_that("picker: sem bundles -> 'Nenhum bundle preparado'; erro -> role=alert", {
  shiny::testServer(
    snapshot_quality_server,
    args = list(list_fn = function() character(0), load_fn = function(dir) vm_ok),
    expect_match(output$picker$html, "Nenhum bundle preparado")
  )
  shiny::testServer(
    snapshot_quality_server,
    args = list(
      list_fn = function() domain_error("snapshot_root_ilegivel", "Diretório ilegível.", list()),
      load_fn = function(dir) vm_ok
    ),
    {
      expect_match(output$picker$html, "role=\"alert\"")
      expect_match(output$picker$html, "Diret")
    }
  )
})

test_that("UI estatica cita a superficie (para o smoke test de boot)", {
  html <- as.character(snapshot_quality_ui("snapshot"))
  expect_match(html, "snapshot", ignore.case = TRUE)
})

# --- helpers de render puros (renderUI e lazy no testServer) --------------

test_that("snapshot_quality_body: bloqueio -> danger + acao de recuperacao", {
  html <- as.character(snapshot_quality_body(vm_blocked))
  expect_match(html, "--color-danger", fixed = TRUE)
  expect_match(html, "scripts/prepare_snapshot.R", fixed = TRUE)
  expect_match(html, "Avanço bloqueado", fixed = TRUE)
})

test_that("snapshot_quality_body: valido -> metadados (6 linhas) + cobertura + avanco liberado", {
  html <- as.character(snapshot_quality_body(vm_ok))
  rotulos <- c(
    "Temporada", "Geração", "Fontes", "Método", "Scoring", "Identidade de conteúdo"
  )
  for (rot in rotulos) expect_match(html, rot, fixed = TRUE)
  expect_match(html, "QB: 1", fixed = TRUE)
  expect_match(html, "Avanço liberado", fixed = TRUE)
})

test_that("snapshot_quality_warnings: opcional ausente -> 'Nao disponivel'; campo vazio -> message", {
  aviso <- function(details) {
    list(list(
      code = "snapshot_opcional_ausente", severity = "aviso",
      message = "mensagem-fallback", details = details
    ))
  }
  expect_match(
    as.character(snapshot_quality_warnings(aviso(list(campo = "floor")))),
    "floor: Não disponível neste snapshot", fixed = TRUE
  )
  expect_match(
    as.character(snapshot_quality_warnings(aviso(list()))),
    "mensagem-fallback", fixed = TRUE
  )
})
