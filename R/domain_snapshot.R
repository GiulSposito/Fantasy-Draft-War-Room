# Normalizacao de dados do snapshot (nucleo puro).
#
# Menor funcao de dominio real do produto: alimenta o parser do bundle (1.2) e a
# validacao de qualidade (1.5). Mapa + passthrough + erro estruturado. Nao toca
# em filesystem, parsing de arquivo nem APIs reativas.

# Conjunto canonico de posicoes do V1.
positions_v1 <- c("QB", "RB", "WR", "TE", "K", "DST")

# Variacoes aceitas de defesa/special-teams (comparadas em caixa alta).
dst_aliases <- c("DST", "D/ST", "D-ST", "DEF", "DEFENSE")

#' Normaliza uma posicao crua para o conjunto canonico do V1
#'
#' @param raw String com a posicao como veio da fonte.
#' @return A posicao canonica (`"QB"`, `"RB"`, `"WR"`, `"TE"`, `"K"` ou `"DST"`)
#'   em caso de sucesso; um [domain_error()] se `raw` nao for uma string unica ou
#'   nao mapear para o conjunto V1.
#' @export
normalize_position <- function(raw) {
  if (!is.character(raw) || length(raw) != 1L || is.na(raw)) {
    return(domain_error(
      "posicao_invalida",
      "Posição inválida: esperado um texto único não nulo.",
      list(raw = raw)
    ))
  }

  value <- toupper(trimws(raw))

  if (!nzchar(value)) {
    return(domain_error(
      "posicao_invalida",
      "Posição inválida: texto vazio.",
      list(raw = raw)
    ))
  }

  if (value %in% dst_aliases) {
    return("DST")
  }
  if (value %in% positions_v1) {
    return(value)
  }

  domain_error(
    "posicao_fora_do_v1",
    sprintf(
      "Posição '%s' fora do conjunto V1 (%s).",
      raw, paste(positions_v1, collapse = ", ")
    ),
    list(raw = raw, canonical = positions_v1)
  )
}
