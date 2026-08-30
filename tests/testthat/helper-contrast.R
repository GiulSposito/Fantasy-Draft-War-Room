# Helpers puros de contraste WCAG 2.x (spec Story 1.6). Sem I/O, sem Shiny:
# recebem cores hex e devolvem numeros. Auto-carregados pelo testthat; usados
# pelo teste de tema para pinar os limiares AA de DESIGN.md / AD-3.

#' Luminancia relativa de uma cor (WCAG 2.x)
#'
#' @param hex Cor em `#RRGGBB` (qualquer formato aceito por [grDevices::col2rgb()]).
#' @return Escalar em `[0, 1]`.
wcag_relative_luminance <- function(hex) {
  channels <- grDevices::col2rgb(hex)[, 1L] / 255
  linear <- ifelse(
    channels <= 0.03928,
    channels / 12.92,
    ((channels + 0.055) / 1.055)^2.4
  )
  sum(linear * c(0.2126, 0.7152, 0.0722))
}

#' Razao de contraste entre duas cores (WCAG 2.x)
#'
#' @param a,b Cores hex.
#' @return Escalar `>= 1` (`(L_claro + 0.05) / (L_escuro + 0.05)`).
wcag_contrast_ratio <- function(a, b) {
  la <- wcag_relative_luminance(a)
  lb <- wcag_relative_luminance(b)
  (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}
