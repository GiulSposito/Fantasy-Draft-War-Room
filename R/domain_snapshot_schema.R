# Schema do snapshot bundle declarado como dado (nucleo puro).
#
# Fonte unica de verdade sobre colunas, tipos e obrigatoriedade dos 4 arquivos
# do bundle. Consumido por `parse_snapshot_bundle()` (validacao/coercao) e pelo
# doc de referencia `inst/schema/snapshot-bundle-v1.md`. Sem I/O, sem parsing.

#' Especificacao declarativa do snapshot bundle V1
#'
#' @return Lista nomeada com tres entradas (`players`, `metrics`, `metadata`).
#'   Cada entrada e uma lista de specs por campo: `list(type = <chr>, required
#'   = <lgl>)`. `type` e um de `"character"`, `"numeric"`, `"integer"`,
#'   `"logical"` (metadados usam apenas `type` informativo; a validacao de
#'   metadado checa somente presenca).
#' @export
snapshot_schema <- function() {
  list(
    players = list(
      player_id       = list(type = "character", required = TRUE),
      display_name    = list(type = "character", required = TRUE),
      normalized_name = list(type = "character", required = TRUE),
      position        = list(type = "character", required = TRUE),
      nfl_team        = list(type = "character", required = FALSE),
      bye_week        = list(type = "integer",   required = FALSE)
    ),
    metrics = list(
      player_id   = list(type = "character", required = TRUE),
      points      = list(type = "numeric",   required = TRUE),
      vor         = list(type = "numeric",   required = TRUE),
      tier        = list(type = "integer",   required = TRUE),
      tier_cliff  = list(type = "logical",   required = TRUE),
      floor       = list(type = "numeric",   required = FALSE),
      ceiling     = list(type = "numeric",   required = FALSE),
      sd_points   = list(type = "numeric",   required = FALSE),
      ecr         = list(type = "numeric",   required = FALSE),
      adp         = list(type = "numeric",   required = FALSE),
      adp_sd      = list(type = "numeric",   required = FALSE),
      uncertainty = list(type = "numeric",   required = FALSE)
    ),
    metadata = list(
      snapshot_id      = list(type = "character", required = TRUE),
      season           = list(type = "integer",   required = TRUE),
      generated_at     = list(type = "character", required = TRUE),
      pipeline_version = list(type = "character", required = TRUE),
      source_list      = list(type = "character", required = TRUE),
      scoring_hash     = list(type = "character", required = TRUE),
      content_hash     = list(type = "character", required = TRUE),
      qa_summary       = list(type = "character", required = TRUE),
      schema_version   = list(type = "character", required = TRUE)
    )
  )
}
