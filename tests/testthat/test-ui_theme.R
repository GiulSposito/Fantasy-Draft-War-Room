# Camada visual base e tema escuro (spec Story 1.6).
#
# DESIGN.md (frontmatter YAML) e a fonte unica dos valores. Estes testes leem o
# arquivo CSS e o frontmatter e calculam tudo sem navegador.
#
# DESIGN.md vive sob _bmad-output/, que o .Rbuildignore exclui: sob R CMD check
# a partir de um pacote instalado ele nao existe -> skip_if_not(file.exists()).

design_path <- testthat::test_path(
  "..", "..", "_bmad-output", "planning-artifacts", "ux-designs",
  "ux-Fantasy Draft War Room-2026-08-29", "DESIGN.md"
)
theme_path <- testthat::test_path("..", "..", "www", "theme.css")

read_design_frontmatter <- function() {
  lines <- readLines(design_path, encoding = "UTF-8", warn = FALSE)
  fences <- which(lines == "---")
  stopifnot(length(fences) >= 2L)
  yaml::yaml.load(paste(lines[(fences[1L] + 1L):(fences[2L] - 1L)], collapse = "\n"))
}

read_theme_css <- function() {
  paste(readLines(theme_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

# Valor de uma custom property, `--nome: <valor>;` -> "<valor>" (ou NA).
css_custom_property <- function(css, name) {
  # name so contem letras, digitos e "-" (nao sao metacaracteres de regex).
  m <- regmatches(css, regexec(sprintf("%s:\\s*([^;]+);", name), css))[[1L]]
  if (length(m) < 2L) NA_character_ else trimws(m[[2L]])
}

# Tudo depois do `}` que fecha o bloco `:root { ... }` (unico bloco com literais).
css_outside_root <- function(css) {
  sub("(?s)^.*?\\n\\}\\n", "", css, perl = TRUE)
}

design_group_prefix <- c(colors = "--color-", spacing = "--space-", rounded = "--rounded-")
typography_suffix <- c(
  fontFamily = "family", fontSize = "size", fontWeight = "weight",
  lineHeight = "line-height", letterSpacing = "letter-spacing"
)


test_that("(a) todo token de DESIGN.md aparece no CSS com valor identico", {
  skip_if_not(file.exists(design_path))
  design <- read_design_frontmatter()
  css <- read_theme_css()

  for (group in names(design_group_prefix)) {
    tokens <- design[[group]]
    expect_named(tokens)
    for (name in names(tokens)) {
      prop <- paste0(design_group_prefix[[group]], name)
      expect_identical(
        css_custom_property(css, prop), as.character(tokens[[name]]),
        info = sprintf("%s.%s -> %s", group, name, prop)
      )
    }
  }

  for (role in names(design$typography)) {
    fields <- design$typography[[role]]
    expect_named(fields)
    for (key in names(fields)) {
      prop <- sprintf("--type-%s-%s", role, typography_suffix[[key]])
      expect_identical(
        css_custom_property(css, prop), as.character(fields[[key]]),
        info = prop
      )
    }
  }

  expect_identical(
    css_custom_property(css, "--focus-ring-width"),
    as.character(design$components[["focus-ring"]][["width"]])
  )
  expect_identical(
    css_custom_property(css, "--focus-ring-offset"),
    as.character(design$components[["focus-ring"]][["offset"]])
  )
})

test_that("(b) contrastes WCAG dos pares permitidos atingem os limiares AA", {
  skip_if_not(file.exists(design_path))
  co <- read_design_frontmatter()$colors
  surfaces <- c("canvas", "surface", "surface-raised")

  for (bg in surfaces) {
    expect_gte(wcag_contrast_ratio(co$ink, co[[bg]]), 4.5)
    expect_gte(wcag_contrast_ratio(co[["ink-muted"]], co[[bg]]), 4.5)
  }
  # indicadores nao textuais >= 3 sobre as surfaces onde aparecem
  for (bg in surfaces) {
    for (fg in c("action", "warning", "danger")) {
      expect_gte(wcag_contrast_ratio(co[[fg]], co[[bg]]), 3)
    }
  }
  expect_gte(wcag_contrast_ratio(co$focus, co$canvas), 3)
  expect_gte(wcag_contrast_ratio(co$focus, co[["surface-raised"]]), 3)
  # warning como texto (components.undo.foreground) -> limiar de texto
  expect_gte(wcag_contrast_ratio(co$warning, co$surface), 4.5)
  expect_gte(wcag_contrast_ratio(co$warning, co[["surface-raised"]]), 4.5)
  # action-ink sobre action (status-strip current-pick)
  expect_gte(wcag_contrast_ratio(co[["action-ink"]], co$action), 4.5)
})

test_that("(c) CSS nao tem modo claro nem segundo bloco de tema", {
  css <- read_theme_css()
  expect_false(grepl("prefers-color-scheme", css))
  expect_false(grepl("\\[data-theme", css))
  expect_length(gregexpr(":root", css, fixed = TRUE)[[1L]], 1L)
})

test_that("(d) fdwr_theme_head liga fdwr-theme/theme.css no <head>", {
  skip_if_not_installed("htmltools")
  # o helper e chamado do composition root (cwd = raiz do repo, onde `www/` vive)
  tag <- withr::with_dir(testthat::test_path("..", ".."), fdwr_theme_head())
  expect_s3_class(tag, "shiny.tag")
  html <- htmltools::doRenderTags(tag)
  expect_match(html, "<head>")
  expect_match(html, "rel=\"stylesheet\"")

  href <- sub('"$', "", sub('^href="', "", regmatches(html, regexpr('href="[^"]+"', html))))
  # primeiro segmento == prefixo passado a addResourcePath (contrato compartilhado)
  expect_identical(strsplit(href, "/", fixed = TRUE)[[1L]][[1L]], "fdwr-theme")
  expect_match(basename(href), "^theme\\.css$")
})

test_that("(reset) body e :focus-visible existem e usam tokens", {
  css <- read_theme_css()
  expect_match(css, "body\\s*\\{[^}]*background:\\s*var\\(--color-canvas\\)")
  expect_match(css, "body\\s*\\{[^}]*color:\\s*var\\(--color-ink\\)")
  expect_match(css, "body\\s*\\{[^}]*font-family:\\s*var\\(--type-data-family\\)")
  expect_match(
    css,
    ":focus-visible\\s*\\{[^}]*outline:\\s*var\\(--focus-ring-width\\)\\s+solid\\s+var\\(--focus-ring-color\\)"
  )
})

test_that("(literais) nenhuma cor fora do bloco :root", {
  outside <- css_outside_root(read_theme_css())
  expect_false(grepl("#[0-9a-fA-F]{3,8}", outside))
  expect_false(grepl("rgb\\(|hsl\\(", outside))
  # sanidade: css_outside_root de fato removeu o :root
  expect_false(grepl(":root", outside))
})

test_that("wcag_contrast_ratio: ancoras conhecidas", {
  expect_equal(wcag_contrast_ratio("#000000", "#FFFFFF"), 21, tolerance = 0.02)
  expect_equal(wcag_contrast_ratio("#777777", "#777777"), 1)
})

test_that("(integration) app.R serve o stylesheet de tema", {
  skip_on_cran()
  skip_if_not_installed("callr")
  repo_root <- normalizePath(testthat::test_path("..", ".."))
  port <- httpuv::randomPort()

  proc <- callr::r_bg(
    function(port) {
      options(fdwr.port = port)
      shiny::runApp("app.R", launch.browser = FALSE)
    },
    args = list(port = port),
    wd = repo_root,
    supervise = TRUE
  )
  withr::defer(proc$kill())

  base <- sprintf("http://127.0.0.1:%d", port)
  home <- NULL
  for (i in 1:60) {
    Sys.sleep(0.25)
    home <- tryCatch(
      suppressWarnings(paste(readLines(base, warn = FALSE), collapse = "\n")),
      error = function(e) NULL
    )
    if (!is.null(home) || !proc$is_alive()) break
  }
  if (is.null(home) && !proc$is_alive()) {
    fail(paste0(
      "app.R morreu durante o boot (regressao na fiacao de tema?):\n",
      paste(proc$read_all_error_lines(), collapse = "\n")
    ))
    return(invisible())
  }
  skip_if(is.null(home), "app nao subiu a tempo")

  # o modulo da Story 1.7 entra no ui/server do app.R
  expect_match(home, "fdwr-snapshot-quality")

  href <- sub('"$', "", sub('^href="', "", regmatches(home, regexpr('href="[^"]+theme\\.css"', home))))
  con <- url(file.path(base, href))
  on.exit(close(con), add = TRUE)
  body <- tryCatch(
    paste(readLines(con, warn = FALSE), collapse = "\n"),
    error = function(e) NULL
  )
  expect_false(is.null(body)) # readLines so falha se o GET nao for 200
  expect_match(body, "--color-canvas")
})
