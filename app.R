# Composition root. Apenas compoe: sem regra de negocio, sem I/O de dados.
#
# Sobe o Shiny exclusivamente em loopback. Se a porta alvo estiver ocupada ou
# a configuracao de porta for invalida, encerra com mensagem acionavel e exit
# nao-zero -- nunca tenta outra porta, nunca escuta em interface publica.

# Helpers puros do bootstrap (autoload de R/ esta desligado de proposito).
source("R/domain_errors.R")
source("R/app_bootstrap.R")
source("R/ui_theme.R")

port <- resolve_bind_port(getOption("fdwr.port", 3939L))
if (is_domain_error(port)) {
  message(port$message)
  quit(status = 1L, save = "no")
}
host <- bind_host()

# Guarda de colisao de porta: httpuv (vem com shiny) tenta um servidor efemero
# em loopback. Sucesso -> libera e segue. Erro de porta em uso -> aborta com
# mensagem acionavel; qualquer outro erro -> propaga a causa real.
probe <- tryCatch(
  httpuv::startServer(host, port, list()),
  error = function(e) e
)
if (inherits(probe, "error")) {
  msg <- conditionMessage(probe)
  # httpuv sinaliza "Failed to create server" para falha de bind (porta ocupada
  # e o caso dominante num bind de loopback); libuv escreve o detalhe "address
  # already in use" so no stderr, fora da condicao.
  if (grepl("failed to create server|address already in use|in use", msg, ignore.case = TRUE)) {
    message(sprintf(
      "Porta %d em uso. Libere-a ou defina options(fdwr.port=) e reinicie.",
      port
    ))
    quit(status = 1L, save = "no")
  }
  stop(msg, call. = FALSE)
}
httpuv::stopServer(probe)

ui <- shiny::fluidPage(
  fdwr_theme_head(),
  shiny::tags$h1("Fantasy Draft War Room"),
  shiny::tags$p("Composition root ativo. Superficies entram nas proximas stories.")
)

server <- function(input, output, session) {
}

shiny::runApp(
  shiny::shinyApp(ui = ui, server = server),
  host = host,
  port = port,
  launch.browser = FALSE
)
