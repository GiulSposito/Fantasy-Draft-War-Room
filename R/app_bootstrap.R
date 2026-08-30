# Helpers puros do composition root. Sem I/O, sem shiny: apenas decidem host e
# porta a partir da configuracao, e devolvem valor ou domain_error. O `app.R`
# (shell imperativo) e quem converte um domain_error em `stop()`/`quit()`.

#' Resolve a porta de bind a partir da configuracao
#'
#' @param raw Valor cru de `getOption("fdwr.port")` (ou equivalente).
#' @return Um inteiro em `1:65535` quando `raw` e um unico numero finito de
#'   valor inteiro no intervalo; caso contrario um [domain_error()] com
#'   `code = "porta_invalida"`.
#' @export
resolve_bind_port <- function(raw) {
  ok <- is.numeric(raw) &&
    length(raw) == 1L &&
    is.finite(raw) &&
    raw == trunc(raw) &&
    raw >= 1 &&
    raw <= 65535
  if (!ok) {
    return(domain_error(
      "porta_invalida",
      sprintf(
        "Porta inválida: %s. Defina options(fdwr.port=) com um inteiro entre 1 e 65535.",
        toString(raw)
      ),
      list(raw = raw)
    ))
  }
  as.integer(raw)
}

#' Host de bind do app
#'
#' @return Sempre `"127.0.0.1"`. O app nunca escuta em interface publica.
#' @export
bind_host <- function() {
  "127.0.0.1"
}
