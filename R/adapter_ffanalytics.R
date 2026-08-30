# Adapter de coleta de projecoes (shell de rede).
#
# UNICO importador de `ffanalytics` no pacote (AD-2). `ffanalytics` esta em
# Suggests + Remotes, nunca em Imports: o runtime live e `devtools::test()` nao
# podem depender dele. Este adapter e a unica parte que fala com a rede e nao e
# testado contra ela -- so smoke manual.
#
# Entrega o `data.frame` cru comum que `build_snapshot_tables()` consome.
#
# Contrato observado no commit fixado `1955daa0...`:
#   projections_table() -> avg_type, id, pos, points, sd_pts, dropoff, floor,
#     ceiling, points_vor, ..., pos_rank, tier
#   add_player_info()   -> + first_name, last_name, team, position, age, exp
#   add_adp/ecr/uncertainty() -> + adp / ecr / uncertainty (dependem de fontes
#     secundarias flaky; aplicados best-effort -- sao opcionais no schema).

#' Coleta projecoes agregadas via `ffanalytics` (commit fixado)
#'
#' Roda `scrape_data` -> `projections_table` -> `add_player_info` +
#' `add_adp`/`add_ecr`/`add_uncertainty` (best-effort) com a config de pipeline
#' versionada, e achata para o `data.frame` cru comum. Falha de pacote ausente,
#' de rede/parsing no nucleo, ou retorno vazio vira um [domain_error()] -- nunca
#' uma excecao propagada.
#'
#' @param scoring_parsed Lista do YAML de scoring ja parseada (objeto `scoring`
#'   do `ffanalytics`, passado direto como `scoring_rules`).
#' @param pipeline_config Lista de `config/snapshot_pipeline.yml` parseada
#'   (`vor_baseline`, `tier_thresholds`).
#' @param season Temporada (inteiro).
#' @param sources Vetor de fontes (`src` do `scrape_data`).
#' @return `data.frame` cru comum; ou um [domain_error()]
#'   (`ffanalytics_ausente`, `coleta_ffanalytics_falhou`).
#' @export
collect_ffanalytics_projections <- function(scoring_parsed, pipeline_config, season, sources) {
  if (!requireNamespace("ffanalytics", quietly = TRUE)) {
    return(domain_error(
      "ffanalytics_ausente",
      paste(
        "Pacote 'ffanalytics' nao instalado. Instale com",
        "renv::install('FantasyFootballAnalytics/ffanalytics@1955daa05efb4a1f38c9a4dee609c5c4eaf84b4d')"
      ),
      list()
    ))
  }

  vor_baseline <- ffanalytics_named_num(pipeline_config$vor_baseline)
  tier_thresholds <- ffanalytics_named_num(pipeline_config$tier_thresholds)
  bad_num <- function(x) is.null(x) || length(x) == 0L || !is.numeric(x) || anyNA(x)
  if (bad_num(vor_baseline) || bad_num(tier_thresholds)) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      "config de pipeline sem vor_baseline/tier_thresholds valido",
      list()
    ))
  }

  core <- tryCatch(
    {
      scraped <- ffanalytics::scrape_data(
        src = sources,
        pos = c("QB", "RB", "WR", "TE", "K", "DST"),
        season = as.integer(season),
        week = 0
      )
      projected <- ffanalytics::projections_table(
        scraped,
        scoring_rules = scoring_parsed,
        vor_baseline = vor_baseline,
        tier_thresholds = tier_thresholds
      )
      ffanalytics::add_player_info(projected)
    },
    error = function(e) e
  )

  if (inherits(core, "error")) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      sprintf("Coleta via ffanalytics falhou: %s", conditionMessage(core)),
      list(causa = conditionMessage(core), sources = sources, season = season)
    ))
  }
  if (!is.data.frame(core) || nrow(core) == 0L) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      "Coleta via ffanalytics retornou vazio (nenhuma projecao).",
      list(sources = sources, season = season)
    ))
  }

  # Enriquecimentos opcionais: um erro numa fonte secundaria degrada a coluna,
  # nao a coleta inteira.
  for (enrich in list(ffanalytics::add_adp, ffanalytics::add_ecr, ffanalytics::add_uncertainty)) {
    core <- tryCatch(enrich(core), error = function(e) core)
  }

  ffanalytics_flatten(as.data.frame(core, stringsAsFactors = FALSE))
}

# Achata a saida do ffanalytics para a forma crua comum: uma linha por jogador,
# colunas renomeadas.
ffanalytics_flatten <- function(df) {
  needed <- c("id", "pos", "points", "points_vor", "tier", "pos_rank")
  faltando <- setdiff(needed, names(df))
  if (length(faltando) > 0L) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      sprintf(
        "Contrato de projections_table mudou: colunas ausentes (%s).",
        paste(faltando, collapse = ", ")
      ),
      list(faltando = faltando, colunas = names(df))
    ))
  }

  if (anyNA(df$id) || !all(nzchar(trimws(as.character(df$id))))) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      "Coleta via ffanalytics: coluna 'id' com valor ausente ou vazio.",
      list()
    ))
  }

  # Uma linha por jogador: fica com as linhas avg_type == "average".
  if ("avg_type" %in% names(df)) {
    if (!"average" %in% df$avg_type) {
      return(domain_error(
        "coleta_ffanalytics_falhou",
        "Coleta via ffanalytics: nenhuma linha com avg_type == 'average'.",
        list(avg_type = unique(as.character(df$avg_type)))
      ))
    }
    df <- df[df$avg_type == "average", , drop = FALSE]
  }
  df <- df[!duplicated(df$id), , drop = FALSE]

  pick <- function(col) if (col %in% names(df)) df[[col]] else NULL

  as_chr_blank <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x
  }
  display_name <- pick("player")
  if (is.null(display_name)) {
    first <- pick("first_name")
    last <- pick("last_name")
    if (is.null(first) && is.null(last)) {
      return(domain_error(
        "coleta_ffanalytics_falhou",
        "Coleta via ffanalytics: sem 'player' nem 'first_name'/'last_name' para o nome.",
        list()
      ))
    }
    left <- if (is.null(first)) rep("", nrow(df)) else as_chr_blank(first)
    right <- if (is.null(last)) rep("", nrow(df)) else as_chr_blank(last)
    display_name <- trimws(paste(left, right))
  }
  display_name <- as_chr_blank(display_name)
  if (!all(nzchar(trimws(display_name)))) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      "Coleta via ffanalytics: display_name vazio para uma ou mais linhas.",
      list()
    ))
  }

  out <- data.frame(
    player_id = as.character(df$id),
    display_name = display_name,
    position = as.character(df$pos),
    points = as.numeric(df$points),
    vor = as.numeric(df$points_vor),
    tier = as.numeric(df$tier),
    pos_rank = as.numeric(df$pos_rank),
    stringsAsFactors = FALSE
  )
  for (mapping in list(
    c("nfl_team", "team"), c("bye_week", "bye"),
    c("floor", "floor"), c("ceiling", "ceiling"), c("sd_points", "sd_pts"),
    c("ecr", "ecr"), c("adp", "adp"), c("uncertainty", "uncertainty")
  )) {
    value <- pick(mapping[[2]])
    if (!is.null(value)) {
      out[[mapping[[1]]]] <- value
    }
  }
  rownames(out) <- NULL
  out
}

# Lista nomeada (do YAML) -> vetor numerico nomeado (o que o ffanalytics espera).
ffanalytics_named_num <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NULL)
  }
  out <- tryCatch(
    suppressWarnings(vapply(x, function(v) as.numeric(v)[[1L]], numeric(1L))),
    error = function(e) NULL
  )
  if (is.null(out)) {
    return(NULL)
  }
  names(out) <- names(x)
  out
}
