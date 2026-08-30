# Erros de dominio estruturados.
#
# Nucleo puro: sem I/O, sem shiny, sem clock. Uma falha de dominio e um VALOR
# (condicao classificada) retornado ao chamador, nunca uma excecao lancada.
# O shell imperativo decide se converte em `stop()`, mensagem de UI ou log.

#' Cria uma condicao de erro de dominio
#'
#' @param code String estavel, `snake_case`, identificando a classe do erro.
#'   Vira a primeira classe S3 da condicao, entao o chamador pode despachar por
#'   `code` sem comparar mensagens.
#' @param message Mensagem PT-BR voltada ao operador.
#' @param details Lista nomeada machine-readable com o contexto do erro.
#' @return Objeto de condicao com classes
#'   `c(code, "fdwr_domain_error", "error", "condition")`.
#' @export
domain_error <- function(code, message, details = list()) {
  stopifnot(
    is.character(code), length(code) == 1L, !is.na(code), nzchar(code),
    is.character(message), length(message) == 1L, !is.na(message),
    is.list(details)
  )
  structure(
    class = c(code, "fdwr_domain_error", "error", "condition"),
    list(message = message, call = NULL, code = code, details = details)
  )
}

#' Testa se um valor e um erro de dominio
#'
#' @param x Qualquer valor.
#' @return `TRUE` se `x` foi produzido por [domain_error()].
#' @export
is_domain_error <- function(x) {
  inherits(x, "fdwr_domain_error")
}
