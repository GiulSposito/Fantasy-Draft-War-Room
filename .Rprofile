source("renv/activate.R")

# Este projeto e um pacote R que tambem carrega um app Shiny de composition root
# (`app.R`). Declarar a opcao explicitamente evita que `shiny::runApp("app.R")`
# faca auto-source de `R/` para dentro do ambiente do app (e silencia o aviso
# correspondente). O dominio entra por carga explicita nas stories que o usam.
options(shiny.autoload.r = FALSE)
