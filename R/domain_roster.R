# Roster, melhor lineup titular e ganho marginal (nucleo puro -- Story 3.1).
#
# Quatro funcoes de dominio:
#   - build_rosters()       -> picks efetivas (join de effective_pick_projection
#                              + draft_slot) para o roster de cada time
#   - best_lineup()          -> roster + slots da liga -> titulares que maximizam
#                              pontos projetados (FLEX de elegibilidade multipla)
#                              + classificacao de cada jogador
#   - marginal_gain()        -> quanto um candidato agrega ao melhor lineup do
#                              operador (com o candidato menos sem ele)
#   - roster_feasibility()   -> achados bloqueantes quando os picks restantes do
#                              time nao completam os slots obrigatorios
#
# Dominio puro (AD-1): nao importa `DBI`/`RSQLite`/`shiny`/`yaml`/`jsonlite`, nao
# abre arquivo, nao le o clock, nao chama `snake_schedule()` nem recalcula
# `points`/`vor`/`tier`. Todo input e argumento explicito. Falha de dominio e
# valor (`domain_error()` ou achado), nunca excecao. Determinismo: mesma entrada
# -> saida `identical()` em qualquer execucao, inclusive sob `LC_COLLATE=C` --
# todo desempate e por `player_id` em ordem de byte (`method = "radix"`).
#
# O ganho marginal alimenta `recommend_fast()` roster-aware (3.2) e a avaliacao
# da simulacao (3.6). Os use cases de comando e o runner sao 3.4/3.6.

# --- helpers privados -------------------------------------------------------

# Inteiro finito >= 0 no range de `integer`, ou domain_error.
roster_valid_count <- function(value) {
  ok <- length(value) == 1L && is.numeric(value) && is.finite(value) &&
    value >= 0 && value == round(value) && abs(value) <= .Machine$integer.max
  if (!ok) {
    return(domain_error(
      "roster_parametro_invalido",
      "Parametro 'remaining_picks' invalido: esperado um inteiro >= 0.",
      list(campo = "remaining_picks")
    ))
  }
  as.integer(round(value))
}

# `starter_slots` (vetor int nomeado com as 7 chaves do V1) + `flex_eligibility`
# (subconjunto nao-vazio de {RB, WR}) -- a forma de `parse_league_config()`.
# Sucesso -> `list(starter_slots, flex_eligibility)` coagidos; senao domain_error.
roster_validate_config <- function(starter_slots, flex_eligibility) {
  inv <- function(msg, d = list()) domain_error("roster_config_invalido", msg, d)

  nms <- names(starter_slots)
  slots_ok <- is.numeric(starter_slots) && length(starter_slots) > 0L &&
    !is.null(nms) && !anyNA(nms) && all(nzchar(nms)) &&
    anyDuplicated(nms) == 0L && !anyNA(starter_slots) &&
    all(is.finite(starter_slots))
  if (!slots_ok) {
    return(inv("starter_slots invalido: esperado um vetor inteiro nomeado nao vazio."))
  }
  if (any(starter_slots != round(starter_slots)) || any(starter_slots < 0)) {
    return(inv("starter_slots invalido: as contagens devem ser inteiros >= 0."))
  }
  expected <- names(league_v1_starter_slots)
  if (!setequal(nms, expected)) {
    return(inv(
      sprintf("starter_slots invalido: esperado exatamente as chaves {%s}.",
              paste(sort(expected, method = "radix"), collapse = ", ")),
      list(esperado = sort(expected, method = "radix"),
           encontrado = sort(nms, method = "radix"))
    ))
  }

  flex_ok <- is.character(flex_eligibility) && length(flex_eligibility) > 0L &&
    !anyNA(flex_eligibility) && all(nzchar(trimws(flex_eligibility))) &&
    all(flex_eligibility %in% league_flex_positions)
  if (!flex_ok) {
    return(inv(
      sprintf("flex_eligibility invalido: esperado um subconjunto nao-vazio de {%s}.",
              paste(league_flex_positions, collapse = ", ")),
      list(permitido = league_flex_positions)
    ))
  }

  slots <- as.integer(round(starter_slots))
  names(slots) <- nms
  list(starter_slots = slots, flex_eligibility = as.character(flex_eligibility))
}

# Resolve `ids` -> data.frame(player_id, position, points) alinhado a `ids`.
# `points` ausente/`NA`/nao-finito e `player_id` fora de `players` -> `-Inf`
# (nunca titula). `position` ausente -> `NA` (agrupa em bloco proprio).
roster_resolve <- function(ids, players) {
  ids <- as.character(ids)
  pos <- rep(NA_character_, length(ids))
  pts <- rep(-Inf, length(ids))
  usable <- is.data.frame(players) && nrow(players) > 0L &&
    all(c("player_id", "position", "points") %in% names(players))
  if (usable) {
    m <- match(ids, as.character(players$player_id))
    hit <- !is.na(m)
    pos[hit] <- toupper(trimws(as.character(players$position[m[hit]])))
    p <- suppressWarnings(as.numeric(players$points[m[hit]]))
    p[!is.finite(p)] <- -Inf
    pts[hit] <- p
  }
  data.frame(player_id = ids, position = pos, points = pts,
             stringsAsFactors = FALSE)
}

# Ordem de preferencia canonica: `points` desc, `player_id` asc (byte).
roster_pref_order <- function(df) {
  order(-df$points, df$player_id, method = "radix")
}

# --- funcoes de dominio -----------------------------------------------------

#' Constroi o roster de cada time a partir das picks efetivas
#'
#' Recebe o join de `effective_pick_projection` + `draft_slot` (o chamador -- 3.4
#' / a simulacao -- faz o join em `overall_pick`) e devolve, por time, a
#' sequencia de `player_id` na ordem de `overall_pick`.
#'
#' @param effective_picks `data.frame(overall_pick, player_id, fantasy_team_id)`.
#'   `overall_pick` inteiro `>= 1` e unico; `player_id` unico e nao vazio;
#'   `fantasy_team_id` nao vazio (ambos sao aparados antes de agrupar).
#' @return Lista nomeada por `fantasy_team_id` (nomes em ordem de byte) de
#'   vetores `character` de `player_id` ordenados por `overall_pick`; `list()`
#'   para 0 linhas; ou um [domain_error()] `"roster_picks_malformado"`.
#' @export
build_rosters <- function(effective_picks) {
  if (is_domain_error(effective_picks)) {
    return(effective_picks)
  }
  bad <- function(msg, d = list()) domain_error("roster_picks_malformado", msg, d)

  if (!is.data.frame(effective_picks)) {
    return(bad("effective_picks malformado: esperado um data.frame."))
  }
  need <- c("overall_pick", "player_id", "fantasy_team_id")
  miss <- setdiff(need, names(effective_picks))
  if (length(miss) > 0L) {
    return(bad(
      sprintf("effective_picks malformado: coluna(s) ausente(s): %s.",
              paste(miss, collapse = ", ")),
      list(colunas = miss)
    ))
  }
  if (nrow(effective_picks) == 0L) {
    return(list())
  }

  # `as.character` primeiro: um `overall_pick` factor coage pelo rotulo, nao pelo
  # codigo interno (espelha o cuidado de `parse_league_teams()`).
  op <- suppressWarnings(as.numeric(as.character(effective_picks$overall_pick)))
  pid <- trimws(as.character(effective_picks$player_id))
  tid <- trimws(as.character(effective_picks$fantasy_team_id))

  if (any(!is.finite(op)) || any(op != round(op)) || any(op < 1)) {
    return(bad("effective_picks malformado: overall_pick deve ser inteiro >= 1."))
  }
  if (any(is.na(pid) | !nzchar(pid))) {
    return(bad("effective_picks malformado: player_id ausente ou vazio."))
  }
  if (any(is.na(tid) | !nzchar(tid))) {
    return(bad("effective_picks malformado: fantasy_team_id ausente ou vazio."))
  }
  if (anyDuplicated(op) != 0L) {
    return(bad(
      "effective_picks malformado: overall_pick duplicado.",
      list(overall_pick = unique(op[duplicated(op)]))
    ))
  }
  if (anyDuplicated(pid) != 0L) {
    return(bad(
      "effective_picks malformado: player_id duplicado entre picks.",
      list(player_id = unique(pid[duplicated(pid)]))
    ))
  }

  teams <- sort(unique(tid), method = "radix")
  out <- lapply(teams, function(t) {
    idx <- which(tid == t)
    pid[idx][order(op[idx], method = "radix")]
  })
  names(out) <- teams
  out
}

#' Melhor lineup titular do roster (maximiza pontos projetados)
#'
#' Preenche cada slot de posicao com os melhores da posicao e o `FLEX` com o
#' melhor jogador restante entre `flex_eligibility`. O otimo do V1 e fechado
#' (RB/WR/FLEX sao os unicos slots que compartilham elegibilidade -- ver Design
#' Notes da spec), entao a heuristica gulosa e a solucao exata. Desempate de
#' projecao e sempre por `player_id` em ordem de byte.
#'
#' @param roster_player_ids Vetor `character` de `player_id` do time.
#' @param players `data.frame` com `player_id`, `position` (QB/RB/WR/TE/K/DST) e
#'   `points` -- o `$players` de [parse_snapshot_bundle()]. `points`
#'   ausente/`NA` ou `player_id` fora dele => o jogador nunca titula e entra em
#'   `warnings`.
#' @param starter_slots Vetor `integer` nomeado com as 7 chaves do V1
#'   (`QB, RB, WR, TE, FLEX, K, DST`) -- o `$starter_slots` de
#'   [parse_league_config()].
#' @param flex_eligibility Vetor `character`, subconjunto nao-vazio de
#'   `{RB, WR}` -- o `$flex_eligibility` de [parse_league_config()].
#' @return `list(starters, total_points, classification, empty_slots, warnings)`:
#'   `starters` lista nomeada por tipo de slot -> `player_id` titulares;
#'   `total_points` soma dos `points` (finitos) dos titulares; `classification`
#'   `data.frame(player_id <chr>, role <chr>, upgrade <lgl>)` ordenado por
#'   `player_id`, `role` em `{titular, flex, banco, redundancia}`; `empty_slots`
#'   tipos de slot titular sem jogador elegivel, repetidos pela multiplicidade
#'   faltante, em ordem de byte; `warnings` `player_id` sem projecao.
#'   Config invalida => [domain_error()] `"roster_config_invalido"`.
#' @export
best_lineup <- function(roster_player_ids, players, starter_slots, flex_eligibility) {
  cfg <- roster_validate_config(starter_slots, flex_eligibility)
  if (is_domain_error(cfg)) {
    return(cfg)
  }
  starter_slots <- cfg$starter_slots
  flex_eligibility <- cfg$flex_eligibility

  stopifnot(is.null(roster_player_ids) || is.atomic(roster_player_ids))
  roster_ids <- unique(trimws(as.character(roster_player_ids)))
  roster_ids <- roster_ids[!is.na(roster_ids) & nzchar(roster_ids)]
  resolved <- roster_resolve(roster_ids, players)
  warnings <- sort(resolved$player_id[!is.finite(resolved$points)], method = "radix")

  resolved <- resolved[roster_pref_order(resolved), , drop = FALSE]

  pos_slots <- setdiff(names(starter_slots), "FLEX")
  assigned <- character(0)
  slot_assign <- list()

  fill <- function(eligible_pos, n) {
    pool <- resolved$player_id[
      !is.na(resolved$position) & resolved$position %in% eligible_pos &
        is.finite(resolved$points) & !resolved$player_id %in% assigned
    ]
    pool[seq_len(min(n, length(pool)))]
  }

  for (slot in pos_slots) {
    take <- fill(slot, starter_slots[[slot]])
    slot_assign[[slot]] <- take
    assigned <- c(assigned, take)
  }
  flex_take <- fill(flex_eligibility, starter_slots[["FLEX"]])
  slot_assign[["FLEX"]] <- flex_take
  assigned <- c(assigned, flex_take)

  starters <- slot_assign[names(league_v1_starter_slots)]

  total_points <- sum(resolved$points[resolved$player_id %in% assigned])

  # pior titular (finito) de cada tipo de slot -- base do flag `upgrade`.
  worst <- vapply(names(starter_slots), function(s) {
    a <- slot_assign[[s]]
    if (!length(a)) return(NA_real_)
    min(resolved$points[resolved$player_id %in% a])
  }, numeric(1L))

  # rotulos: titular / flex saem do otimo; o resto agrupa por posicao.
  role <- rep(NA_character_, length(roster_ids))
  names(role) <- roster_ids
  role[roster_ids %in% unlist(slot_assign[pos_slots], use.names = FALSE)] <- "titular"
  role[roster_ids %in% flex_take] <- "flex"

  non <- roster_ids[is.na(role[roster_ids])]
  if (length(non) > 0L) {
    nr <- roster_resolve(non, players)
    nr <- nr[roster_pref_order(nr), , drop = FALSE]
    grp <- ifelse(is.na(nr$position), "", nr$position)
    nr_role <- ifelse(!duplicated(grp), "banco", "redundancia")
    role[nr$player_id] <- nr_role
  }

  upgrade <- rep(FALSE, length(roster_ids))
  names(upgrade) <- roster_ids
  for (pid in non) {
    r <- resolved[resolved$player_id == pid, , drop = FALSE]
    if (!nrow(r) || !is.finite(r$points[1L]) || is.na(r$position[1L])) {
      next
    }
    elig <- character(0)
    if (r$position[1L] %in% names(starter_slots)) {
      elig <- c(elig, r$position[1L])
    }
    if (r$position[1L] %in% flex_eligibility) {
      elig <- c(elig, "FLEX")
    }
    w <- worst[elig]
    w <- w[!is.na(w)]
    # ponytail: `>=`, nao `>`. Sob jogo otimo nenhum reserva supera um titular,
    # entao so um empate resolvido por `player_id` dispara isto -- exatamente o
    # "normalmente vazio, so empate o produz" das Boundaries da spec.
    if (length(w) > 0L && r$points[1L] >= min(w)) {
      upgrade[pid] <- TRUE
    }
  }

  empty_slots <- character(0)
  for (slot in names(starter_slots)) {
    miss <- starter_slots[[slot]] - length(slot_assign[[slot]])
    if (miss > 0L) {
      empty_slots <- c(empty_slots, rep(slot, miss))
    }
  }
  empty_slots <- sort(empty_slots, method = "radix")

  classification <- data.frame(
    player_id = roster_ids,
    role = unname(role[roster_ids]),
    upgrade = unname(upgrade[roster_ids]),
    stringsAsFactors = FALSE
  )
  classification <- classification[
    order(classification$player_id, method = "radix"), , drop = FALSE
  ]
  rownames(classification) <- NULL

  list(
    starters = starters,
    total_points = total_points,
    classification = classification,
    empty_slots = empty_slots,
    warnings = warnings
  )
}

#' Ganho marginal de um candidato para o roster do operador
#'
#' `best_lineup(roster + candidato) - best_lineup(roster)`. Nunca negativo.
#'
#' @param candidate_id `player_id` do candidato (fora do roster do operador).
#' @param roster_player_ids Roster atual do operador.
#' @param players,starter_slots,flex_eligibility Como em [best_lineup()].
#' @return `numeric(1)` `>= 0`: a diferenca de `total_points` do melhor lineup
#'   com e sem o candidato; `0` quando o candidato ja esta no roster, nao tem
#'   projecao, ou o ganho e ruido de ponto flutuante
#'   (`< sqrt(.Machine$double.eps)`). Config invalida => o [domain_error()] de
#'   [best_lineup()].
#' @export
marginal_gain <- function(candidate_id, roster_player_ids, players,
                          starter_slots, flex_eligibility) {
  cid <- as.character(candidate_id)
  roster <- as.character(roster_player_ids)
  if (length(cid) != 1L || is.na(cid) || !nzchar(trimws(cid))) {
    return(0)
  }
  if (cid %in% roster) {
    return(0)
  }
  cand <- roster_resolve(cid, players)
  if (!is.finite(cand$points[1L])) {
    return(0)
  }
  without <- best_lineup(roster, players, starter_slots, flex_eligibility)
  if (is_domain_error(without)) {
    return(without)
  }
  with_cand <- best_lineup(c(roster, cid), players, starter_slots, flex_eligibility)
  if (is_domain_error(with_cand)) {
    return(with_cand)
  }
  gain <- with_cand$total_points - without$total_points
  if (gain < sqrt(.Machine$double.eps)) 0 else gain
}

#' Viabilidade do roster: os obrigatorios ainda cabem nos picks restantes?
#'
#' Conta os slots titulares (incl. `FLEX`) que o roster atual nao preenche e,
#' se forem mais que `remaining_picks`, emite um achado bloqueante por tipo de
#' slot afetado.
#'
#' @param roster_player_ids Roster atual do time.
#' @param remaining_picks Inteiro `>= 0`: picks que o time ainda tem.
#' @param players,starter_slots,flex_eligibility Como em [best_lineup()].
#' @return Lista ordenada ([snapshot_quality_sort()]) de achados
#'   `snapshot_quality_finding("roster_slot_obrigatorio_inatingivel",
#'   "bloqueante", <msg>, list(slot, faltando, picks_restantes, total_abertos))`
#'   -- a mensagem carrega o deficit agregado; `list()` se tudo e alcancavel; ou
#'   um [domain_error()] `"roster_parametro_invalido"` / `"roster_config_invalido"`.
#' @export
roster_feasibility <- function(roster_player_ids, remaining_picks, players,
                               starter_slots, flex_eligibility) {
  rp <- roster_valid_count(remaining_picks)
  if (is_domain_error(rp)) {
    return(rp)
  }
  bl <- best_lineup(roster_player_ids, players, starter_slots, flex_eligibility)
  if (is_domain_error(bl)) {
    return(bl)
  }
  open <- bl$empty_slots
  total_abertos <- length(open)
  if (total_abertos <= rp) {
    return(list())
  }
  findings <- lapply(sort(unique(open), method = "radix"), function(s) {
    faltando <- sum(open == s)
    snapshot_quality_finding(
      "roster_slot_obrigatorio_inatingivel", "bloqueante",
      sprintf(
        paste0("Slot obrigatorio '%s': %d de %d slots obrigatorios abertos ",
               "nao cabem nos %d picks restantes."),
        s, faltando, total_abertos, rp
      ),
      list(slot = s, faltando = faltando, picks_restantes = rp,
           total_abertos = total_abertos)
    )
  })
  snapshot_quality_sort(findings)
}
