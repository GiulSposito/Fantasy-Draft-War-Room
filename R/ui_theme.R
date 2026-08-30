# Helper fino do composition root para a camada visual. Dominio-neutro: sem
# regra de negocio, sem estado de aplicacao.
#
# `app.R` sobe um objeto `shinyApp` (nao um diretorio de app), entao o Shiny NAO
# monta `./www` automaticamente. Para servir `www/theme.css` sem tocar no boot do
# `app.R`, o helper registra `shiny::addResourcePath("fdwr-theme", "www")` — um
# efeito colateral global idempotente, a forma minima de referenciar o asset
# estatico. `"www"` e resolvido relativo ao working directory do processo: o
# composition root, iniciado da raiz do repo — a mesma premissa que as chamadas
# `source()` relativas do `app.R` ja fazem.

#' Cabecalho HTML com o stylesheet de tema
#'
#' `DESIGN.md` (frontmatter YAML) e a fonte unica dos valores visuais;
#' `www/theme.css` e a materializacao 1:1 desses tokens como CSS custom
#' properties; o teste de completude token<->CSS em `test-ui_theme.R` (caso "a")
#' e o guarda de consistencia entre os dois.
#'
#' Registra `shiny::addResourcePath("fdwr-theme", "www")` (idempotente) porque o
#' `app.R` compoe um objeto `shinyApp` e o Shiny nao serve `./www` nesse modo.
#' `"www"` e relativo ao working directory do processo (a raiz do repo).
#'
#' @return Uma `shiny.tag` (`<head>`) contendo o `<link rel="stylesheet">` para
#'   `fdwr-theme/theme.css`.
#' @export
fdwr_theme_head <- function() {
  shiny::addResourcePath("fdwr-theme", "www")
  shiny::tags$head(
    shiny::tags$link(rel = "stylesheet", href = "fdwr-theme/theme.css")
  )
}
