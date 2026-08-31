# Calendario snake, times e ordem da primeira rodada (nucleo puro -- Story 2.2).
#
# Quatro funcoes de dominio:
#   - parse_league_teams()          -> modelo canonico de times (id imutavel,
#                                       exatamente um time do operador)
#   - snake_draw_order()            -> sorteio reprodutivel da ordem da 1a
#                                       rodada com seed registrada, sem vazar RNG
#   - validate_first_round_order()  -> a ordem e permutacao exata dos times
#   - snake_schedule()              -> gera todos os slots do snake
#
# Dominio puro (AD-1): nao abre arquivos, nao importa `yaml`/`jsonlite`/
# `shiny`/`DBI`, nao le o clock. Todo input e argumento explicito. Falha ->
# `domain_error()` (nunca excecao). Determinismo: mesma entrada -> saida
# `identical()` em qualquer execucao, inclusive sob `LC_COLLATE=C`.
#
# Persistencia, SQLite e o evento `DRAFT_STARTED` sao Story 2.3. A superficie
# Shiny de setup foi separada (ver `deferred-work.md`, split 2026-08-31).

# Inteiro finito de valor >= 1 no range de `integer`, ou domain_error.
# Espelha `league_scalar_int()` de `R/domain_league_config.R` mas com o `code`
# do schedule -- nao importar entre modulos de dominio.
schedule_pos_int <- function(value, campo) {
  ok <- length(value) == 1L && is.numeric(value) && is.finite(value) &&
    abs(value) <= .Machine$integer.max && value == round(value) && value >= 1
  if (!ok) {
    return(domain_error(
      "snake_parametro_invalido",
      sprintf("Parametro '%s' invalido: esperado um inteiro >= 1.", campo),
      list(campo = campo)
    ))
  }
  as.integer(round(value))
}

# Vetor de ids de time bem formado: >= 2 textos nao vazios e unicos
# (unicidade avaliada sobre o valor aparado, para "t1" e " t1" nao colidirem).
schedule_valid_ids <- function(ids) {
  is.character(ids) && length(ids) >= 2L && !anyNA(ids) &&
    all(nzchar(trimws(ids))) && anyDuplicated(trimws(ids)) == 0L
}

# Seed de sorteio valida: um inteiro finito no range de `integer`.
schedule_valid_seed <- function(seed) {
  length(seed) == 1L && is.numeric(seed) && is.finite(seed) &&
    abs(seed) <= .Machine$integer.max && seed == round(seed)
}

#' Interpreta os times cadastrados da liga num modelo canonico
#'
#' Recebe uma lista de mapas nomeados ja desserializados
#' (`{fantasy_team_id, display_name, is_user}`), valida forma, unicidade de id
#' e "exatamente um time do operador", e devolve um `data.frame` canonico em
#' ordem de cadastro. Nao valida o envelope numerico 8-14 (Story 2.1) -- aqui
#' so: >= 2 times, forma e unicidade.
#'
#' @param entries Lista de mapas nomeados, cada um com `fantasy_team_id`
#'   (texto nao vazio), `display_name` (texto nao vazio) e `is_user` (logico
#'   escalar).
#' @return `data.frame(fantasy_team_id <chr>, display_name <chr>,
#'   is_user <lgl>)` em ordem de cadastro; ou um [domain_error()]
#'   `"league_teams_malformado"` (forma), `"league_teams_id_invalido"`
#'   (`details$fantasy_team_id`) ou `"league_teams_usuario_invalido"`
#'   (`details$encontrados`).
#' @export
parse_league_teams <- function(entries) {
  if (is_domain_error(entries)) {
    return(entries)
  }
  malformado <- function(msg) domain_error("league_teams_malformado", msg, list())

  if (!is.list(entries) || is.data.frame(entries) || length(entries) < 2L) {
    return(malformado(
      "Times da liga malformados: esperado uma lista de ao menos 2 times."
    ))
  }

  n <- length(entries)
  ids <- character(n)
  display_name <- character(n)
  is_user <- logical(n)

  for (i in seq_len(n)) {
    e <- entries[[i]]
    nms <- names(e)
    has_fields <- is.list(e) && !is.null(nms) &&
      all(c("fantasy_team_id", "display_name", "is_user") %in% nms)
    if (!has_fields) {
      return(malformado(sprintf(
        "Time na posicao %d malformado: faltam campos {fantasy_team_id, display_name, is_user}.",
        i
      )))
    }

    id <- e$fantasy_team_id
    if (length(id) != 1L || !is.character(id) || is.na(id) || !nzchar(trimws(id))) {
      return(domain_error(
        "league_teams_id_invalido",
        sprintf("Identificador de time invalido na posicao %d.", i),
        list(fantasy_team_id = id)
      ))
    }

    nm <- e$display_name
    if (length(nm) != 1L || !is.character(nm) || is.na(nm) || !nzchar(trimws(nm))) {
      return(malformado(sprintf(
        "Nome de exibicao invalido para o time '%s'.", id
      )))
    }

    u <- e$is_user
    if (length(u) != 1L || !is.logical(u) || is.na(u)) {
      return(malformado(sprintf(
        "Campo 'is_user' invalido para o time '%s': esperado TRUE ou FALSE.", id
      )))
    }

    ids[[i]] <- trimws(as.character(id))
    display_name[[i]] <- as.character(nm)
    is_user[[i]] <- u
  }

  dup <- unique(ids[duplicated(ids)])
  if (length(dup) > 0L) {
    return(domain_error(
      "league_teams_id_invalido",
      sprintf("Identificador(es) de time duplicado(s): %s.", paste(dup, collapse = ", ")),
      list(fantasy_team_id = dup)
    ))
  }

  n_user <- sum(is_user)
  if (n_user != 1L) {
    return(domain_error(
      "league_teams_usuario_invalido",
      sprintf("Deve haver exatamente um time do operador; encontrados %d.", n_user),
      list(encontrados = n_user)
    ))
  }

  data.frame(
    fantasy_team_id = ids,
    display_name = display_name,
    is_user = is_user,
    stringsAsFactors = FALSE
  )
}

#' Sorteia a ordem da primeira rodada de forma reprodutivel
#'
#' `set.seed(seed)` + `sample()`, reprodutivel por `(team_ids, seed)`. Salva o
#' `.Random.seed` do ambiente global antes e o restaura via `on.exit` -- nenhum
#' efeito colateral no RNG do processo.
#'
#' @param team_ids Vetor `character` com >= 2 ids nao vazios e unicos.
#' @param seed Inteiro finito. Registra-se com a sessao (Story 2.3).
#' @return Vetor `character` com `team_ids` permutado; ou um [domain_error()]
#'   `"snake_parametro_invalido"` (`details$campo`) ou `"snake_seed_invalida"`
#'   (`details$seed`).
#' @export
snake_draw_order <- function(team_ids, seed) {
  if (is_domain_error(team_ids)) {
    return(team_ids)
  }
  if (!schedule_valid_ids(team_ids)) {
    return(domain_error(
      "snake_parametro_invalido",
      "Parametro 'team_ids' invalido: esperado >= 2 textos nao vazios e unicos.",
      list(campo = "team_ids")
    ))
  }
  if (!schedule_valid_seed(seed)) {
    return(domain_error(
      "snake_seed_invalida",
      "Seed de sorteio invalida: esperado um inteiro finito.",
      list(seed = seed)
    ))
  }

  seed_name <- ".Random.seed"
  had_seed <- exists(seed_name, envir = globalenv(), inherits = FALSE)
  old_seed <- if (had_seed) {
    get(seed_name, envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (had_seed) {
      assign(seed_name, old_seed, envir = globalenv())
    } else if (exists(seed_name, envir = globalenv(), inherits = FALSE)) {
      rm(list = seed_name, envir = globalenv())
    }
  }, add = TRUE)

  # RNG fixado explicitamente -> reprodutivel entre versoes de R (o default de
  # `sample.kind` mudou no R 3.6).
  set.seed(as.integer(seed), kind = "Mersenne-Twister", sample.kind = "Rejection")
  sample(as.character(team_ids))
}

#' Valida que a ordem da primeira rodada e uma permutacao exata dos times
#'
#' @param order Vetor com os ids na ordem proposta para a 1a rodada.
#' @param team_ids Vetor com os ids dos times cadastrados.
#' @return `NULL` se `order` e permutacao exata de `team_ids`; senao um
#'   [domain_error()] `"snake_ordem_invalida"` com
#'   `details = list(faltando, sobrando, duplicados)`.
#' @export
validate_first_round_order <- function(order, team_ids) {
  if (is_domain_error(order)) {
    return(order)
  }
  if (is_domain_error(team_ids)) {
    return(team_ids)
  }
  order <- as.character(order)
  team_ids <- as.character(team_ids)

  team_dups <- unique(team_ids[duplicated(team_ids)])
  if (length(team_dups) > 0L) {
    return(domain_error(
      "snake_ordem_invalida",
      "Times cadastrados tem ids duplicados; a ordem nao pode ser validada.",
      list(faltando = character(0), sobrando = character(0), duplicados = team_dups)
    ))
  }

  faltando <- setdiff(team_ids, order)
  sobrando <- setdiff(order, team_ids)
  duplicados <- unique(order[duplicated(order)])
  is_permutation <- length(order) == length(team_ids) && length(order) > 0L &&
    length(faltando) == 0L && length(sobrando) == 0L && length(duplicados) == 0L
  if (is_permutation) {
    return(NULL)
  }
  domain_error(
    "snake_ordem_invalida",
    "Ordem da primeira rodada nao e uma permutacao exata dos times cadastrados.",
    list(faltando = faltando, sobrando = sobrando, duplicados = duplicados)
  )
}

#' Gera todos os slots do calendario snake
#'
#' Round impar segue `first_round_order`; round par e o inverso exato do impar
#' anterior; exatamente um slot por time por round; `overall_pick` continuo de
#' 1 a `N * rounds`. Funcao pura e deterministica -- reusada por
#' `scripts/simulate_draft.R` (Epic 3), por isso `rounds` e parametro.
#'
#' @param first_round_order Vetor `character` com a ordem da 1a rodada
#'   (>= 2 ids nao vazios e unicos).
#' @param user_team_id Id do time do operador -- deve estar em
#'   `first_round_order`.
#' @param rounds Numero de rounds (inteiro >= 1, default `15L`).
#' @return `data.frame` com `overall_pick <int>`, `round <int>`,
#'   `pick_in_round <int>`, `fantasy_team_id <chr>`, `is_user_team <lgl>`; ou um
#'   [domain_error()] `"snake_parametro_invalido"` (`details$campo`) ou
#'   `"snake_time_usuario_ausente"`.
#' @export
snake_schedule <- function(first_round_order, user_team_id, rounds = 15L) {
  if (is_domain_error(first_round_order)) {
    return(first_round_order)
  }
  if (!schedule_valid_ids(first_round_order)) {
    return(domain_error(
      "snake_parametro_invalido",
      "Parametro 'first_round_order' invalido: esperado >= 2 textos nao vazios e unicos.",
      list(campo = "first_round_order")
    ))
  }
  rounds_int <- schedule_pos_int(rounds, "rounds")
  if (is_domain_error(rounds_int)) {
    return(rounds_int)
  }
  # Teto: `n * rounds` precisa caber em `integer` (senao `character(NA)` lanca).
  n_slots <- as.double(length(first_round_order)) * as.double(rounds_int)
  if (rounds_int > 1000L || n_slots > .Machine$integer.max) {
    return(domain_error(
      "snake_parametro_invalido",
      "Parametro 'rounds' invalido: o numero de slots excede o limite suportado.",
      list(campo = "rounds")
    ))
  }
  user_id_ok <- length(user_team_id) == 1L && is.character(user_team_id) &&
    !is.na(user_team_id) && nzchar(trimws(user_team_id))
  if (!user_id_ok) {
    return(domain_error(
      "snake_parametro_invalido",
      "Parametro 'user_team_id' invalido: esperado um texto nao vazio.",
      list(campo = "user_team_id")
    ))
  }

  first_round_order <- as.character(first_round_order)
  if (!user_team_id %in% first_round_order) {
    return(domain_error(
      "snake_time_usuario_ausente",
      "O time do operador nao esta na ordem da primeira rodada.",
      list(user_team_id = user_team_id)
    ))
  }

  n <- length(first_round_order)
  total <- n * rounds_int
  fantasy_team_id <- character(total)
  for (r in seq_len(rounds_int)) {
    ord <- if (r %% 2L == 1L) first_round_order else rev(first_round_order)
    fantasy_team_id[(r - 1L) * n + seq_len(n)] <- ord
  }

  data.frame(
    overall_pick = seq_len(total),
    round = rep(seq_len(rounds_int), each = n),
    pick_in_round = rep(seq_len(n), times = rounds_int),
    fantasy_team_id = fantasy_team_id,
    is_user_team = fantasy_team_id == user_team_id,
    stringsAsFactors = FALSE
  )
}
