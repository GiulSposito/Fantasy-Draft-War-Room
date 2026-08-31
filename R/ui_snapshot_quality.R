# Modulo Shiny "Selecionar e validar snapshot" (apresentacao pura).
#
# Dominio-neutro: lista bundles, exige selecao explicita, chama o caso de uso
# `load_snapshot_for_preparation()` e mapeia o view-model para tags + tokens.
# Nenhuma regra de "o que bloqueia" aqui -- isso e o caso de uso, testado fora
# do Shiny. Valores visuais so via tokens de `www/theme.css`.
#
# `snapshot_quality_server()` devolve `valid_snapshot`: um `reactive()` que
# rende `list(bundle_dir, view_model)` quando ha um bundle confirmado e sem
# bloqueios, senao `NULL`. Esse e o input imutavel da sessao em preparo:
# trocar o snapshot exige `Reiniciar preparo` (limpa view-model + selecao).

recuperacao_texto <- paste(
  "Para corrigir: rode scripts/prepare_snapshot.R novamente",
  "ou reinicie o preparo e escolha outro snapshot."
)

#' UI do modulo "Selecionar e validar snapshot"
#'
#' @param id Namespace do modulo.
#' @return Uma `shiny.tag` (`<section>`).
#' @export
snapshot_quality_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$section(
    class = "fdwr-snapshot-quality t-data",
    shiny::tags$h2(class = "t-display", "Qualidade do snapshot"),
    shiny::uiOutput(ns("picker")),
    shiny::uiOutput(ns("region"))
  )
}

#' Server do modulo "Selecionar e validar snapshot"
#'
#' @param id Namespace do modulo.
#' @param list_fn Funcao que lista os bundles ([list_snapshot_bundles()]).
#' @param load_fn Funcao `(bundle_dir)` que devolve o view-model
#'   ([load_snapshot_for_preparation()]).
#' @return `reactive()` com `list(bundle_dir, view_model)` do snapshot valido
#'   confirmado, ou `NULL`.
#' @export
snapshot_quality_server <- function(id,
                                    list_fn = list_snapshot_bundles,
                                    load_fn = load_snapshot_for_preparation) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    rv <- shiny::reactiveValues(selected = NULL, vm = NULL, busy = FALSE)

    shiny::observeEvent(input$confirm, {
      shiny::req(input$bundle)
      if (!is.null(rv$selected)) {
        return() # ja confirmado: trocar exige Reiniciar preparo
      }
      rv$busy <- TRUE
      rv$selected <- input$bundle
      # ponytail: carregamento sincrono bloqueia o processo R; aria-busy e
      # emitido no markup mas alterna no mesmo flush. tryCatch garante que o
      # modulo nunca derruba a sessao e que rv$busy sempre volta a FALSE.
      rv$vm <- tryCatch(load_fn(input$bundle), error = function(e) NULL)
      rv$busy <- FALSE
    })

    shiny::observeEvent(input$restart, {
      rv$selected <- NULL
      rv$vm <- NULL
      rv$busy <- FALSE
    })

    output$picker <- shiny::renderUI({
      if (!is.null(rv$selected)) {
        return(shiny::tagList(
          shiny::tags$p(
            class = "t-label",
            sprintf("Snapshot selecionado: %s", basename(rv$selected))
          ),
          shiny::actionButton(ns("restart"), "Reiniciar preparo")
        ))
      }
      bundles <- list_fn()
      if (is_domain_error(bundles)) {
        return(shiny::tags$p(
          role = "alert", style = "color: var(--color-danger)",
          sprintf("%s Rode scripts/prepare_snapshot.R.", bundles$message)
        ))
      }
      if (length(bundles) == 0L) {
        return(shiny::tags$p(
          "Nenhum bundle preparado. Rode scripts/prepare_snapshot.R para gerar um."
        ))
      }
      choices <- as.list(bundles)
      names(choices) <- basename(bundles)
      shiny::tagList(
        shiny::selectInput(ns("bundle"), "Snapshot", choices = choices),
        shiny::actionButton(ns("confirm"), "Confirmar e validar")
      )
    })

    output$region <- shiny::renderUI({
      body <- if (!is.null(rv$selected) && is.null(rv$vm)) {
        # confirmado mas load_fn falhou/devolveu NULL: nunca em branco.
        shiny::div(
          role = "alert", style = "color: var(--color-danger)",
          shiny::tags$p(class = "t-label", "Falha ao carregar o snapshot"),
          shiny::tags$p(recuperacao_texto)
        )
      } else {
        snapshot_quality_body(rv$vm)
      }
      shiny::div(
        id = ns("result"), class = "t-data", `aria-live` = "polite",
        `aria-busy` = if (isTRUE(rv$busy)) "true" else "false",
        body
      )
    })

    valid_snapshot <- shiny::reactive({
      if (!is.null(rv$vm) && isTRUE(rv$vm$advance_allowed)) {
        list(bundle_dir = rv$selected, view_model = rv$vm)
      } else {
        NULL
      }
    })

    # Estado observavel para testes de `testServer` (e leitores de tela).
    output$status <- shiny::renderText({
      if (is.null(rv$vm)) {
        if (!is.null(rv$selected)) "erro" else "aguardando"
      } else if (isTRUE(rv$vm$advance_allowed)) {
        "válido"
      } else {
        "bloqueado"
      }
    })
    shiny::outputOptions(output, "status", suspendWhenHidden = FALSE)

    valid_snapshot
  })
}

# --- mapeamento view-model -> tags (puro) ---------------------------------

snapshot_quality_body <- function(vm) {
  if (is.null(vm)) {
    return(shiny::tags$p(class = "t-label", "Nenhum snapshot carregado."))
  }
  shiny::tagList(
    snapshot_quality_blockers(vm$bloqueios),
    if (!is.null(vm$metadata)) snapshot_quality_metadata(vm$metadata),
    if (!is.null(vm$coverage)) snapshot_quality_coverage(vm$coverage),
    snapshot_quality_warnings(vm$avisos),
    if (isTRUE(vm$advance_allowed)) {
      shiny::tags$p(class = "t-label", "Snapshot válido. Avanço liberado.")
    }
  )
}

snapshot_quality_blockers <- function(bloqueios) {
  if (!length(bloqueios)) {
    return(NULL)
  }
  shiny::div(
    role = "alert", style = "color: var(--color-danger)",
    shiny::tags$p(class = "t-label", "Avanço bloqueado"),
    shiny::tags$ul(lapply(bloqueios, function(b) {
      shiny::tags$li(sprintf("[%s] %s", b$code, b$message))
    })),
    shiny::tags$p(recuperacao_texto)
  )
}

snapshot_quality_metadata <- function(meta) {
  rows <- list(
    c("Temporada", as.character(meta$temporada)),
    c("Geração", as.character(meta$geracao)),
    c("Fontes", paste(as.character(meta$fontes), collapse = ", ")),
    c("Método", as.character(meta$metodo)),
    c("Scoring", as.character(meta$scoring)),
    c("Identidade de conteúdo", as.character(meta$identidade_de_conteudo))
  )
  shiny::tags$dl(lapply(rows, function(r) {
    shiny::tagList(shiny::tags$dt(r[[1]]), shiny::tags$dd(r[[2]]))
  }))
}

snapshot_quality_coverage <- function(coverage) {
  shiny::tagList(
    shiny::tags$p(class = "t-label", "Cobertura"),
    shiny::tags$ul(lapply(names(coverage), function(pos) {
      shiny::tags$li(sprintf("%s: %d", pos, as.integer(coverage[[pos]])))
    }))
  )
}

snapshot_quality_warnings <- function(avisos) {
  if (!length(avisos)) {
    return(NULL)
  }
  shiny::div(
    style = "color: var(--color-warning)",
    shiny::tags$p(class = "t-label", "Avisos"),
    shiny::tags$ul(lapply(avisos, function(a) {
      campo <- a$details$campo
      txt <- if (identical(a$code, "snapshot_opcional_ausente") &&
                   length(campo) == 1L && !is.na(campo) && nzchar(campo)) {
        sprintf("%s: Não disponível neste snapshot", campo)
      } else {
        a$message
      }
      shiny::tags$li(txt)
    }))
  )
}
