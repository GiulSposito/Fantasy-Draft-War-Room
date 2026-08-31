# Configuracao da liga e envelope V1 (nucleo puro -- Story 2.1).
#
# `parse_league_config()` recebe o YAML de `config/league_rules.yml` JA
# desserializado (mapa nomeado) e devolve um objeto canonico tipado ou um
# `domain_error`. `validate_league_envelope()` impoe o envelope V1 (FR7/FR8)
# devolvendo achados bloqueantes por grupo afetado, no formato e na ordem
# canonica da Story 1.5 (`snapshot_quality_finding` + `snapshot_quality_sort`).
# `league_scoring_compat_finding()` dobra `verify_scoring_hash()` num aviso
# NAO bloqueante (AD-6).
#
# Nao abre arquivos, nao importa `yaml`/`jsonlite`, nao le o clock. O adapter
# de disco e `read_scoring_config()` (leitor generico de mapa-YAML), nao
# chamado aqui. Sem hashing da config de liga (Sprint Change Proposal
# 2026-08-31). `tiers` / `recommendation_policy` sao do `recommend_fast()`
# (Epic 3), nao deste modulo.

# Campos obrigatorios do mapa de configuracao de liga.
league_config_fields <- c(
  "config_version", "teams", "rounds", "scoring",
  "starter_slots", "flex_eligibility", "bench_size"
)

# Composicao EXATA de titulares do V1 (FR7) -- nao "9 titulares quaisquer".
league_v1_starter_slots <- c(
  QB = 1L, RB = 2L, WR = 2L, TE = 1L, FLEX = 1L, K = 1L, DST = 1L
)

# Posicoes elegiveis para o slot FLEX no V1 (FR8).
league_flex_positions <- c("RB", "WR")

# Envelope numerico do V1.
league_teams_min <- 8L
league_teams_max <- 14L
league_rounds_v1 <- 15L
league_bench_v1 <- 6L

league_config_type_error <- function(campo, esperado) {
  domain_error(
    "league_config_tipo_invalido",
    sprintf("Campo '%s' invalido na configuracao de liga: esperado %s.", campo, esperado),
    list(campo = campo)
  )
}

# Escalar de texto nao vazio, ou domain_error.
league_scalar_chr <- function(value, campo) {
  if (length(value) != 1L || !is.character(value) || is.na(value) || !nzchar(trimws(value))) {
    return(league_config_type_error(campo, "um texto nao vazio"))
  }
  as.character(value)
}

# Escalar numerico de valor inteiro coagido para `integer`, ou domain_error.
league_scalar_int <- function(value, campo) {
  if (length(value) != 1L || !is.numeric(value) || is.na(value) || value != round(value)) {
    return(league_config_type_error(campo, "um inteiro"))
  }
  as.integer(round(value))
}

# Mapa nomeado <chr, inteiro> -> vetor `integer` nomeado, ou domain_error.
league_int_map <- function(value, campo) {
  if (!is.list(value) && !is.numeric(value)) {
    return(league_config_type_error(campo, "um mapa de inteiros nomeado"))
  }
  nms <- names(value)
  named_ok <- length(value) > 0L && !is.null(nms) && !anyNA(nms) &&
    all(nzchar(nms)) && anyDuplicated(nms) == 0L
  if (!named_ok) {
    return(league_config_type_error(campo, "um mapa de inteiros com nomes unicos"))
  }
  out <- integer(length(value))
  names(out) <- nms
  for (i in seq_along(value)) {
    coerced <- league_scalar_int(value[[i]], paste0(campo, ".", nms[[i]]))
    if (is_domain_error(coerced)) {
      return(coerced)
    }
    out[[i]] <- coerced
  }
  out
}

# Vetor de texto (0+ entradas) -> `character`, ou domain_error. Vazio e
# permitido no parse -- a viabilidade e do envelope (`league_flex_invalido`).
league_chr_vec <- function(value, campo) {
  if (is.null(value)) {
    return(character(0))
  }
  flat <- if (is.list(value)) unlist(value, use.names = FALSE) else value
  if (is.null(flat)) {
    return(character(0))
  }
  if (!is.character(flat) || anyNA(flat) || !all(nzchar(trimws(flat)))) {
    return(league_config_type_error(campo, "uma lista de textos nao vazios"))
  }
  as.character(flat)
}

#' Interpreta o YAML de regras da liga (ja desserializado) num objeto canonico
#'
#' Parser PURO no split das Stories 1.2/1.5: recebe o mapa que o adapter
#' ([read_scoring_config()]) ja leu, valida forma e tipo, coage numericos de
#' valor inteiro para `integer`. Nao abre arquivos.
#'
#' @param parsed_yaml Mapa nomeado -- o retorno de [read_scoring_config()]
#'   sobre `config/league_rules.yml`.
#' @return Em caso de sucesso, `list(config_version <chr>, teams <int>,
#'   rounds <int>, scoring <chr>, starter_slots <int nomeado>,
#'   flex_eligibility <chr>, bench_size <int>)`. Em caso de falha, um
#'   [domain_error()] `"league_config_malformado"` (nao e mapa nomeado),
#'   `"league_config_campo_ausente"` (`details$campo`) ou
#'   `"league_config_tipo_invalido"` (`details$campo`).
#' @export
parse_league_config <- function(parsed_yaml) {
  if (is_domain_error(parsed_yaml)) {
    return(parsed_yaml)
  }
  nms <- names(parsed_yaml)
  is_named_map <- is.list(parsed_yaml) && !is.data.frame(parsed_yaml) &&
    length(parsed_yaml) > 0L && !is.null(nms) && !anyNA(nms) && all(nzchar(nms))
  if (!is_named_map) {
    return(domain_error(
      "league_config_malformado",
      "Configuracao de liga malformada: esperado um mapa YAML nomeado nao vazio.",
      list()
    ))
  }

  for (campo in league_config_fields) {
    if (!campo %in% nms || is.null(parsed_yaml[[campo]])) {
      return(domain_error(
        "league_config_campo_ausente",
        sprintf("Campo obrigatorio ausente na configuracao de liga: %s.", campo),
        list(campo = campo)
      ))
    }
  }

  config_version <- league_scalar_chr(parsed_yaml$config_version, "config_version")
  if (is_domain_error(config_version)) {
    return(config_version)
  }
  scoring <- league_scalar_chr(parsed_yaml$scoring, "scoring")
  if (is_domain_error(scoring)) {
    return(scoring)
  }
  teams <- league_scalar_int(parsed_yaml$teams, "teams")
  if (is_domain_error(teams)) {
    return(teams)
  }
  rounds <- league_scalar_int(parsed_yaml$rounds, "rounds")
  if (is_domain_error(rounds)) {
    return(rounds)
  }
  bench_size <- league_scalar_int(parsed_yaml$bench_size, "bench_size")
  if (is_domain_error(bench_size)) {
    return(bench_size)
  }
  starter_slots <- league_int_map(parsed_yaml$starter_slots, "starter_slots")
  if (is_domain_error(starter_slots)) {
    return(starter_slots)
  }
  flex_eligibility <- league_chr_vec(parsed_yaml$flex_eligibility, "flex_eligibility")
  if (is_domain_error(flex_eligibility)) {
    return(flex_eligibility)
  }

  list(
    config_version = config_version,
    teams = teams,
    rounds = rounds,
    scoring = scoring,
    starter_slots = starter_slots,
    flex_eligibility = flex_eligibility,
    bench_size = bench_size
  )
}

#' A configuracao de liga de referencia (identica ao parse do YAML versionado)
#'
#' @return O mesmo objeto que [parse_league_config()] produz sobre
#'   `config/league_rules.yml` (12 times, Full PPR, composicao V1, 6 reservas).
#' @export
reference_league_config <- function() {
  parse_league_config(list(
    config_version = "league-config-v1",
    teams = 12L,
    rounds = 15L,
    scoring = "full_ppr",
    starter_slots = list(QB = 1L, RB = 2L, WR = 2L, TE = 1L, FLEX = 1L, K = 1L, DST = 1L),
    flex_eligibility = c("RB", "WR"),
    bench_size = 6L
  ))
}

# Vetor int nomeado em ordem de byte dos nomes (chave de details estavel).
league_sort_slots <- function(slots) {
  slots[order(names(slots), method = "radix")]
}

league_envelope_finding <- function(code, message, grupo, details = list()) {
  snapshot_quality_finding(code, "bloqueante", message, c(list(grupo = grupo), details))
}

#' Impoe o envelope V1 sobre uma configuracao de liga parseada
#'
#' Checa `teams` em 8-14; `rounds == 15`; `starter_slots` == composicao EXATA
#' do V1 (`QB=1, RB=2, WR=2, TE=1, FLEX=1, K=1, DST=1`, FR7); `bench_size == 6`;
#' `sum(starter_slots) + bench_size == rounds`; `flex_eligibility` subconjunto
#' nao-vazio de `{RB, WR}` (FR8). Cada violacao vira um achado bloqueante com
#' `details$grupo` em `{"times_rounds", "slots_flex", "scoring"}`.
#'
#' A checagem de "roster preenche os rounds" so roda quando `starter_slots` e
#' `rounds` ja estao dentro do envelope -- senao o achado especifico
#' (`league_slots_invalido` / `league_rounds_invalido`) ja aponta a causa.
#'
#' @param config Objeto de [parse_league_config()].
#' @return Lista ordenada ([snapshot_quality_sort()]) de achados
#'   `list(code, severity = "bloqueante", message, details)`. Config viavel ->
#'   `list()`. Mesma entrada -> `identical()`.
#' @export
validate_league_envelope <- function(config) {
  stopifnot(is.list(config), !is_domain_error(config))
  acc <- new.env(parent = emptyenv())
  acc$items <- list()
  add <- function(f) acc$items[[length(acc$items) + 1L]] <- f

  teams_ok <- config$teams >= league_teams_min && config$teams <= league_teams_max
  if (!teams_ok) {
    add(league_envelope_finding(
      "league_times_fora_do_envelope",
      sprintf(
        "Numero de times fora do envelope V1 (%d-%d): %d.",
        league_teams_min, league_teams_max, config$teams
      ),
      "times_rounds",
      list(encontrado = config$teams, minimo = league_teams_min, maximo = league_teams_max)
    ))
  }

  rounds_ok <- identical(config$rounds, league_rounds_v1)
  if (!rounds_ok) {
    add(league_envelope_finding(
      "league_rounds_invalido",
      sprintf("O V1 exige exatamente %d rounds; encontrado %d.", league_rounds_v1, config$rounds),
      "times_rounds",
      list(esperado = league_rounds_v1, encontrado = config$rounds)
    ))
  }

  slots_ok <- identical(league_sort_slots(config$starter_slots), league_sort_slots(league_v1_starter_slots))
  if (!slots_ok) {
    add(league_envelope_finding(
      "league_slots_invalido",
      "Composicao de titulares diferente da composicao exata do V1 (QB, 2 RB, 2 WR, TE, FLEX, K, D/ST).",
      "slots_flex",
      list(
        esperado = league_sort_slots(league_v1_starter_slots),
        encontrado = league_sort_slots(config$starter_slots)
      )
    ))
  }

  if (!identical(config$bench_size, league_bench_v1)) {
    add(league_envelope_finding(
      "league_reservas_invalido",
      sprintf("O V1 exige exatamente %d reservas; encontrado %d.", league_bench_v1, config$bench_size),
      "slots_flex",
      list(esperado = league_bench_v1, encontrado = config$bench_size)
    ))
  }

  # ponytail: quando slots e rounds estao no envelope, esta checagem e
  # equivalente a `bench_size == 6` -- mas a matriz da spec pede os dois
  # achados quando `bench_size` diverge, entao ambos sao emitidos.
  if (slots_ok && rounds_ok) {
    total <- sum(config$starter_slots) + config$bench_size
    if (!identical(as.integer(total), config$rounds)) {
      add(league_envelope_finding(
        "league_roster_nao_preenche_rounds",
        sprintf(
          "Titulares (%d) + reservas (%d) = %d, diferente dos %d rounds.",
          sum(config$starter_slots), config$bench_size, total, config$rounds
        ),
        "slots_flex",
        list(
          titulares = sum(config$starter_slots),
          reservas = config$bench_size,
          rounds = config$rounds
        )
      ))
    }
  }

  flex <- config$flex_eligibility
  if (length(flex) == 0L || !all(flex %in% league_flex_positions)) {
    add(league_envelope_finding(
      "league_flex_invalido",
      "FLEX aceita apenas um subconjunto nao-vazio de {RB, WR} no V1.",
      "slots_flex",
      list(encontrado = flex, permitido = league_flex_positions)
    ))
  }

  snapshot_quality_sort(acc$items)
}

#' Aviso NAO bloqueante de compatibilidade entre o scoring ativo e o snapshot
#'
#' Dobra [verify_scoring_hash()] num achado `severity = "aviso"` (AD-6): a
#' decisao de prosseguir e do operador, nao um gate.
#'
#' @param active_scoring_parsed Lista parseada do `scoring.yml` ativo -- de
#'   [read_scoring_config()]. Se for um [domain_error()], devolve um achado
#'   `"league_scoring_indisponivel"` preservando `code`/`message`.
#' @param snapshot_metadata `metadata.json` do snapshot selecionado, ja
#'   parseado (com `scoring_hash`).
#' @return `NULL` quando os hashes batem; senao um achado
#'   `list(code, severity = "aviso", message, details)` com `details$grupo =
#'   "scoring"`.
#' @export
league_scoring_compat_finding <- function(active_scoring_parsed, snapshot_metadata) {
  if (is_domain_error(active_scoring_parsed)) {
    return(snapshot_quality_finding(
      "league_scoring_indisponivel", "aviso", active_scoring_parsed$message,
      list(code = active_scoring_parsed$code, grupo = "scoring")
    ))
  }
  res <- verify_scoring_hash(active_scoring_parsed, snapshot_metadata)
  if (is.null(res)) {
    return(NULL)
  }
  details <- if (is.list(res$details)) res$details else list()
  snapshot_quality_finding(
    "league_scoring_incompativel", "aviso", res$message,
    list(
      esperado = if (is.null(details$esperado)) NA_character_ else details$esperado,
      encontrado = if (is.null(details$encontrado)) NA_character_ else details$encontrado,
      grupo = "scoring"
    )
  )
}
