# Sessao de draft: id, precondicoes e proveniencia congelada (nucleo puro -- Story 2.4).
#
# Tres funcoes de dominio:
#   - new_draft_id()          -> id de texto imutavel a partir do instante (mirror
#                                de `new_snapshot_id()`)
#   - draft_start_findings()  -> achados bloqueantes das precondicoes do `start`
#                                (envelope da liga + times + ordem da 1a rodada)
#   - draft_started_payload() -> a proveniencia congelada do `DRAFT_STARTED`;
#                                a mesma lista serve de `payload_json` e de
#                                colunas de `draft_session`
#
# Dominio puro (AD-1): nao importa `DBI`/`RSQLite`/`shiny`, nao abre arquivo, nao
# le o clock -- o instante entra como argumento e o use case (`start_draft`) e que
# injeta o relogio. Falha estrutural de `new_draft_id` e `stop()` (contrato), o
# resto e valor. `jsonlite::toJSON` e a unica serializacao (AD-6:
# `league_rules_json`), deterministica para a mesma entrada.

#' Monta o `draft_id` da sessao a partir do instante
#'
#' Mirror de [new_snapshot_id()]. Recebe o instante ja resolvido (o use case
#' injeta o clock); nao le `Sys.time()`.
#'
#' @param clock_value Instante (`POSIXct` ou coercivel).
#' @return `"draft-<AAAAMMDDTHHMMSSZ em UTC>"`.
#' @export
new_draft_id <- function(clock_value) {
  stamp <- tryCatch(
    format(as.POSIXct(clock_value, tz = "UTC"), "%Y%m%dT%H%M%SZ", tz = "UTC"),
    error = function(e) NA_character_
  )
  if (length(stamp) != 1L || is.na(stamp)) {
    stop("draft_id: instante invalido")
  }
  sprintf("draft-%s", stamp)
}

# Dobra um `domain_error` num achado bloqueante, fixando `details$grupo`
# (sobrescreve uma chave `grupo` que ja exista em `err$details`).
draft_error_finding <- function(err, grupo) {
  base <- if (is.list(err$details)) err$details else list()
  snapshot_quality_finding(
    err$code, "bloqueante", err$message,
    modifyList(base, list(grupo = grupo))
  )
}

#' Achados bloqueantes das precondicoes do `start`
#'
#' Roda as validacoes que devem passar antes de qualquer `INSERT`:
#' [validate_league_envelope()] (config no envelope V1), a forma dos times
#' (`teams_df` ja e um `domain_error` quando [parse_league_teams()] falhou), a
#' coerencia entre a contagem de times cadastrados e `league_config$teams`, e
#' [validate_first_round_order()] (ordem = permutacao exata dos ids). Cada
#' violacao vira um achado bloqueante com `details$grupo` apontando o grupo
#' afetado (`"times_rounds"` / `"slots_flex"` / `"scoring"` do envelope,
#' `"times"`, `"ordem"`).
#'
#' @param league_config Objeto de [parse_league_config()] (ou um `domain_error`).
#' @param teams_df `data.frame` de [parse_league_teams()], ou o `domain_error`
#'   que ela devolveu.
#' @param first_round_order Vetor com a ordem proposta para a 1a rodada.
#' @return Lista ordenada ([snapshot_quality_sort()]) de achados
#'   `list(code, severity = "bloqueante", message, details)`. Tudo viavel ->
#'   `list()`. Mesma entrada -> `identical()`.
#' @export
draft_start_findings <- function(league_config, teams_df, first_round_order) {
  findings <- validate_league_envelope(league_config)

  if (is_domain_error(teams_df)) {
    findings <- c(findings, list(draft_error_finding(teams_df, "times")))
  } else {
    cfg_teams <- if (is.list(league_config)) league_config$teams else NULL
    if (length(cfg_teams) == 1L && is.numeric(cfg_teams) && is.finite(cfg_teams) &&
          !identical(nrow(teams_df), as.integer(cfg_teams))) {
      findings <- c(findings, list(snapshot_quality_finding(
        "league_times_cadastrados_divergem", "bloqueante",
        sprintf(
          "Times cadastrados (%d) divergem de league_config$teams (%d).",
          nrow(teams_df), as.integer(cfg_teams)
        ),
        list(
          grupo = "times", cadastrados = nrow(teams_df),
          esperado = as.integer(cfg_teams)
        )
      )))
    }
    order_check <- validate_first_round_order(first_round_order, teams_df$fantasy_team_id)
    if (is_domain_error(order_check)) {
      findings <- c(findings, list(draft_error_finding(order_check, "ordem")))
    }
  }

  snapshot_quality_sort(findings)
}

#' Proveniencia congelada do `DRAFT_STARTED` (AD-6)
#'
#' Congela **valores resolvidos**, nao hashes de estado/config: id e content
#' hash do snapshot do Epic 1, a identidade exibivel do scoring, os valores
#' parseados da configuracao de liga (`jsonlite::toJSON`), a versao do engine e a
#' seed opcional. A lista devolvida e ao mesmo tempo o `payload_json` do evento e
#' a fonte das colunas de `draft_session` -- uma so definicao da proveniencia.
#'
#' @param snapshot_id,snapshot_content_hash,scoring_identity Valores resolvidos
#'   do snapshot selecionado.
#' @param league_config Objeto de [parse_league_config()] (valores resolvidos).
#' @param engine_version Versao do engine no `start` (texto).
#' @param seed A seed **registrada** do sorteio de ordem (inteiro) ou `NULL` --
#'   proveniencia de "houve um sorteio com esta seed". NAO e garantia de que
#'   `snake_draw_order(team_ids, seed)` reproduz a ordem congelada: a ordem pode
#'   ter sido reordenada manualmente depois do sorteio. Omitida do payload
#'   quando `NULL`.
#' @return Lista nomeada `list(snapshot_id, snapshot_content_hash,
#'   scoring_identity, league_rules_json, engine_version[, random_seed])`.
#'   Mesma entrada -> `identical()`.
#' @export
draft_started_payload <- function(snapshot_id, snapshot_content_hash, scoring_identity,
                                  league_config, engine_version, seed = NULL) {
  payload <- list(
    snapshot_id = as.character(snapshot_id),
    snapshot_content_hash = as.character(snapshot_content_hash),
    scoring_identity = as.character(scoring_identity),
    league_rules_json = as.character(jsonlite::toJSON(league_config, auto_unbox = TRUE)),
    engine_version = as.character(engine_version)
  )
  if (!is.null(seed)) {
    payload$random_seed <- as.integer(seed)
  }
  payload
}
