# Caso de uso: `start_draft` e o evento `DRAFT_STARTED` (shell de aplicacao -- Story 2.4).
#
# Unico caminho do comando `start` (AD-4). Fluxo:
#   1. guarda `league_config` que ja e `domain_error` (falha upstream)
#   2. extrai a proveniencia do snapshot (`snapshot_id` / `content_hash` /
#      `scoring_hash`, ja aparados) -- metadata degenerado -> `domain_error`
#   3. valida `seed` e o instante do `clock()` -> `domain_error` se invalidos
#      (antes de qualquer precondicao ou transacao)
#   4. `parse_league_teams()` + `draft_start_findings()` rodam FORA de qualquer
#      transacao: achados -> `list(ok = FALSE, bloqueios = ...)`, banco intocado
#   5. viavel -> uma `event_store_transaction()` que grava `draft_session` +
#      todos os `draft_slot` + o `DRAFT_STARTED` (`event_sequence = 1`) +
#      `draft_state`; falha em qualquer `INSERT` -> rollback total + `domain_error`
#
# Nao implementa picks/undo/correcao/replay (Story 3.4) nem superficie Shiny.

# Extrai e valida a proveniencia do snapshot a partir do metadata parseado.
start_draft_provenance <- function(snapshot_metadata) {
  if (is_domain_error(snapshot_metadata)) {
    return(snapshot_metadata)
  }
  invalido <- function(campo, msg) {
    domain_error("start_snapshot_proveniencia_invalida", msg, list(campo = campo))
  }
  if (!is.list(snapshot_metadata) || is.data.frame(snapshot_metadata)) {
    return(invalido(NA_character_, "Metadados do snapshot invalidos: esperado uma lista nomeada."))
  }
  for (campo in c("snapshot_id", "content_hash", "scoring_hash")) {
    v <- snapshot_metadata[[campo]]
    if (length(v) != 1L || !is.character(v) || is.na(v) || !nzchar(trimws(v))) {
      return(invalido(campo, sprintf("Metadados do snapshot sem '%s' utilizavel.", campo)))
    }
  }
  list(
    snapshot_id = trimws(as.character(snapshot_metadata$snapshot_id)),
    content_hash = trimws(as.character(snapshot_metadata$content_hash)),
    scoring_hash = trimws(as.character(snapshot_metadata$scoring_hash))
  )
}

# Seed: `NULL` (ausente) ou um inteiro finito no range de `integer` (espelha
# `schedule_valid_seed` de 2.2). Devolve `NULL`, o inteiro coagido, ou um
# `domain_error`.
start_draft_seed <- function(seed) {
  if (is.null(seed)) {
    return(NULL)
  }
  ok <- length(seed) == 1L && is.numeric(seed) && is.finite(seed) &&
    abs(seed) <= .Machine$integer.max && seed == round(seed)
  if (!ok) {
    return(domain_error(
      "start_seed_invalida",
      "Seed do sorteio de ordem invalida: esperado um inteiro finito ou NULL.",
      list(seed = seed)
    ))
  }
  as.integer(seed)
}

# `clock()` tem que devolver um instante `POSIXct` escalar nao-`NA` -- rejeita
# `NA`, `Date` (viraria `...T000000Z` silencioso) e epoch numerico. Devolve o
# instante ou um `domain_error`.
start_draft_clock <- function(now) {
  if (!inherits(now, "POSIXct") || length(now) != 1L || is.na(now)) {
    return(domain_error(
      "start_clock_invalido",
      "O relogio injetado nao devolveu um instante POSIXct valido.",
      list(valor = format(now))
    ))
  }
  now
}

#' Inicia a sessao de draft e anexa o `DRAFT_STARTED`
#'
#' Roda as precondicoes (config no envelope V1, exatamente um time do operador,
#' ordem = permutacao exata dos ids) **fora** da transacao: inviavel -> devolve
#' os achados e o banco fica intocado. Viavel -> uma unica
#' [event_store_transaction()] grava `draft_session` (proveniencia congelada),
#' todos os `draft_slot` de [snake_schedule()], o evento `DRAFT_STARTED`
#' (`event_sequence = 1`, `payload_json` = a proveniencia) e o `draft_state`
#' inicial (`DRAFTING`, `next_overall_pick = 1`). Falha em qualquer `INSERT` ->
#' rollback total + `domain_error`.
#'
#' @param con Conexao do event store ([event_store_connect()] + [event_store_init()]).
#' @param snapshot_metadata `metadata.json` do snapshot selecionado, ja parseado
#'   (`snapshot_id`, `content_hash`, `scoring_hash`), ou um [domain_error()].
#' @param league_config Objeto de [parse_league_config()], ou um [domain_error()]
#'   (devolvido como esta).
#' @param team_entries Lista de mapas de times para [parse_league_teams()].
#' @param first_round_order Vetor `character` com a ordem da 1a rodada.
#' @param seed Seed do sorteio de ordem (inteiro finito) ou `NULL`. Validada
#'   uma vez antes da transacao; o valor coagido alimenta o payload e a coluna.
#' @param clock Funcao sem argumentos que devolve o instante (`POSIXct` escalar).
#' @param engine_version Versao do engine gravada na proveniencia.
#' @return Um de tres formatos, e o caller deve checar `is_domain_error()`
#'   **antes** de olhar `$ok`:
#'   \itemize{
#'     \item [domain_error()] -- `league_config` invalido, metadata degenerado,
#'       `seed`/`clock` invalido, ou rollback da transacao;
#'     \item `list(ok = FALSE, bloqueios = <achados ordenados>)` -- precondicoes
#'       (envelope / times / ordem) inviaveis, nada gravado;
#'     \item `list(ok = TRUE, draft_id)` -- sessao iniciada.
#'   }
#'   Um `if (out$ok)` sobre um `domain_error` quebra -- cheque o tipo primeiro.
#' @export
start_draft <- function(con, snapshot_metadata, league_config, team_entries,
                        first_round_order, seed = NULL, clock = Sys.time,
                        engine_version = as.character(utils::packageVersion("fantasydraftwarroom"))) {
  if (is_domain_error(league_config)) {
    return(league_config)
  }

  provenance <- start_draft_provenance(snapshot_metadata)
  if (is_domain_error(provenance)) {
    return(provenance)
  }

  seed_int <- start_draft_seed(seed)
  if (is_domain_error(seed_int)) {
    return(seed_int)
  }

  now <- start_draft_clock(clock())
  if (is_domain_error(now)) {
    return(now)
  }

  teams <- parse_league_teams(team_entries)
  findings <- draft_start_findings(league_config, teams, first_round_order)
  if (length(findings) > 0L) {
    return(list(ok = FALSE, bloqueios = findings))
  }

  user_team_id <- teams$fantasy_team_id[teams$is_user][[1L]]
  schedule <- snake_schedule(first_round_order, user_team_id, rounds = league_config$rounds)
  if (is_domain_error(schedule)) {
    # defensivo: draft_start_findings ja garante permutacao + rounds no envelope,
    # entao snake_schedule nao falha aqui
    return(schedule)
  }

  draft_id <- new_draft_id(now)
  created_at <- format(now, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  payload <- draft_started_payload(
    provenance$snapshot_id, provenance$content_hash, provenance$scoring_hash,
    league_config, engine_version, seed_int
  )
  payload_json <- as.character(jsonlite::toJSON(payload, auto_unbox = TRUE))

  result <- event_store_transaction(con, function(con) {
    DBI::dbExecute(
      con,
      "INSERT INTO draft_session
         (draft_id, created_at, snapshot_id, snapshot_content_hash, scoring_identity,
          league_rules_json, engine_version, random_seed)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      params = list(
        draft_id, created_at, payload$snapshot_id, payload$snapshot_content_hash,
        payload$scoring_identity, payload$league_rules_json, payload$engine_version,
        if (is.null(seed_int)) NA_integer_ else seed_int
      )
    )
    DBI::dbAppendTable(con, "draft_slot", data.frame(
      draft_id = draft_id,
      overall_pick = schedule$overall_pick,
      round = schedule$round,
      pick_in_round = schedule$pick_in_round,
      fantasy_team_id = schedule$fantasy_team_id,
      is_user_team = as.integer(schedule$is_user_team),
      stringsAsFactors = FALSE
    ))
    DBI::dbExecute(
      con,
      "INSERT INTO draft_event (draft_id, event_sequence, event_type, payload_json, created_at)
       VALUES (?, ?, ?, ?, ?)",
      params = list(draft_id, 1L, "DRAFT_STARTED", payload_json, created_at)
    )
    DBI::dbExecute(
      con,
      "INSERT INTO draft_state (draft_id, status, next_overall_pick) VALUES (?, ?, ?)",
      params = list(draft_id, "DRAFTING", 1L)
    )
    NULL
  })

  if (is_domain_error(result)) {
    return(result)
  }
  list(ok = TRUE, draft_id = draft_id)
}
