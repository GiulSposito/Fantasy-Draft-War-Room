# Mapeamento cru -> canonico do snapshot bundle (nucleo puro).
#
# Recebe o `data.frame` cru comum (produzido pelo adapter de coleta ou pelo
# adapter de CSV manual), o clock ja resolvido em valor, e a config de pipeline
# ja parseada -- tudo como argumento. Nao abre arquivos, nao le o relogio, nao
# importa `ffanalytics`/`yaml`. Retorna valores ou `domain_error`.
#
# A validacao final e autoridade do parser (`parse_snapshot_bundle()`): o
# bundle emitido e relido do disco e reparseado antes de reportar sucesso.
# Aqui a gente monta as tabelas na forma do `snapshot_schema()`, deriva os
# campos calculados e falha cedo no que o parser nao conseguiria diagnosticar
# bem (posicao fora do V1 na origem, `pos_rank` ausente para o `tier_cliff`).

#' Normaliza um nome para busca/desambiguacao (minusculo, sem acento)
#'
#' Locale-independente para entrada ASCII: remove os diacriticos do bloco
#' Latin-1 por [chartr()] e so entao aplica [tolower()] (que e estavel para
#' `A-Z`). Espacos em branco sao colapsados para um unico espaco.
#'
#' @param x Vetor de caracteres (nome de apresentacao).
#' @return Vetor de caracteres normalizado, mesmo comprimento.
#' @export
snapshot_normalized_name <- function(x) {
  x <- as.character(x)
  accented <- "ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÑñÇçÝýÿŸ"
  plain <- "AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuNnCcYyyY"
  x <- chartr(accented, plain, x)
  # ponytail: tolower e locale-estavel so para ASCII (Turkish-I e o teto);
  # a entrada ja passou pelo chartr, entao caracteres nao-ASCII sao raros.
  x <- tolower(x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

#' Deriva `tier_cliff` a partir de `pos_rank` e `tier` dentro da posicao
#'
#' V1: o ultimo jogador de cada `tier` por posicao (maior `pos_rank` do grupo
#' posicao+tier) recebe `TRUE` -- "pegue antes do degrau".
#'
#' @param position Vetor de posicoes ja normalizadas.
#' @param pos_rank Vetor de rank posicional (coercivel a numero, sem `NA`).
#' @param tier Vetor de tier (coercivel a numero, sem `NA`).
#' @return Vetor logico do mesmo comprimento, ou um [domain_error()]
#'   `"coleta_ffanalytics_falhou"` se `pos_rank`/`tier` nao derem para agrupar.
#' @export
derive_tier_cliff <- function(position, pos_rank, tier) {
  stopifnot(
    length(position) == length(pos_rank),
    length(position) == length(tier)
  )
  pos_chr <- as.character(position)
  if (anyNA(pos_chr) || !all(nzchar(trimws(pos_chr)))) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      "Nao da para derivar tier_cliff: position ausente ou inconsistente.",
      list(position_na = which(is.na(pos_chr) | !nzchar(trimws(pos_chr))))
    ))
  }
  pr <- suppressWarnings(as.numeric(pos_rank))
  tr <- suppressWarnings(as.numeric(tier))
  if (anyNA(pr) || anyNA(tr)) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      "Nao da para derivar tier_cliff: pos_rank ou tier ausente ou nao numerico.",
      list(pos_rank_na = which(is.na(pr)), tier_na = which(is.na(tr)))
    ))
  }
  key <- paste(pos_chr, tr, sep = "|")
  grp_max <- tapply(pr, key, max)
  unname(as.logical(pr == grp_max[key]))
}

#' Monta o `snapshot_id` da execucao
#'
#' @param season Temporada (inteiro).
#' @param clock_value Instante ja resolvido (`POSIXct` ou coercivel).
#' @return `"snap-<season>-<AAAAMMDDTHHMMSSZ em UTC>"`.
#' @export
new_snapshot_id <- function(season, clock_value) {
  season_int <- suppressWarnings(as.integer(season))
  stamp <- tryCatch(
    format(as.POSIXct(clock_value, tz = "UTC"), "%Y%m%dT%H%M%SZ", tz = "UTC"),
    error = function(e) NA_character_
  )
  if (length(season_int) != 1L || is.na(season_int) ||
        length(stamp) != 1L || is.na(stamp)) {
    stop("snapshot_id: season ou instante invalido")
  }
  sprintf("snap-%d-%s", season_int, stamp)
}

# Colunas cruas essenciais: sem elas a montagem nao comeca.
snapshot_raw_required <- c("player_id", "display_name", "position", "points", "vor", "tier")

#' Constroi `players` e `metrics` canonicos a partir do `data.frame` cru comum
#'
#' @param raw_df `data.frame` na forma crua comum: `player_id`, `display_name`,
#'   `position`, `points`, `vor`, `tier` obrigatorios; `nfl_team`, `bye_week`,
#'   `floor`, `ceiling`, `sd_points`, `ecr`, `adp`, `adp_sd`, `uncertainty`
#'   opcionais; `tier_cliff` (modo CSV manual) ou `pos_rank` (modo coleta, para
#'   derivar `tier_cliff`).
#' @return `list(players = <data.frame>, metrics = <data.frame>)` nas colunas e
#'   ordem do [snapshot_schema()]; ou um [domain_error()]
#'   (`snapshot_coluna_ausente`, `snapshot_tipo_invalido`,
#'   `snapshot_posicao_invalida`, `coleta_ffanalytics_falhou`).
#' @export
build_snapshot_tables <- function(raw_df) {
  if (!is.data.frame(raw_df) || nrow(raw_df) == 0L) {
    return(domain_error(
      "coleta_ffanalytics_falhou",
      "Projecoes cruas vazias ou em formato invalido (esperado data.frame com linhas).",
      list(linhas = if (is.data.frame(raw_df)) nrow(raw_df) else NA_integer_)
    ))
  }
  for (col in snapshot_raw_required) {
    if (!col %in% names(raw_df)) {
      return(domain_error(
        "snapshot_coluna_ausente",
        sprintf("Coluna obrigatoria ausente nas projecoes cruas: %s.", col),
        list(campo = col)
      ))
    }
  }

  schema <- snapshot_schema()

  norm_pos <- character(nrow(raw_df))
  for (i in seq_len(nrow(raw_df))) {
    res <- normalize_position(raw_df$position[[i]])
    if (is_domain_error(res)) {
      return(domain_error(
        "snapshot_posicao_invalida",
        sprintf(
          "Posicao invalida para player_id '%s': %s",
          raw_df$player_id[[i]], res$message
        ),
        list(player_id = raw_df$player_id[[i]], raw = raw_df$position[[i]])
      ))
    }
    norm_pos[[i]] <- res
  }

  take <- function(col, type, required) {
    if (!col %in% names(raw_df)) {
      return(if (required) NULL else NA)
    }
    coerced <- snapshot_coerce_column(raw_df[[col]], type, required)
    if (!coerced$ok) {
      return(domain_error(
        "snapshot_tipo_invalido",
        sprintf("Valor incompativel em %s (%s): '%s'.", col, coerced$motivo, coerced$value),
        list(campo = col, valor = coerced$value, motivo = coerced$motivo)
      ))
    }
    coerced$value
  }

  players <- list()
  for (col in names(schema$players)) {
    if (col == "normalized_name") {
      next
    }
    if (col == "position") {
      players[[col]] <- norm_pos
      next
    }
    value <- take(col, schema$players[[col]]$type, isTRUE(schema$players[[col]]$required))
    if (is_domain_error(value)) {
      return(value)
    }
    players[[col]] <- value
  }
  players$normalized_name <- snapshot_normalized_name(players$display_name)

  # player_id vazio/NA ja e rejeitado por snapshot_coerce_column (motivo "vazio");
  # aqui rejeitamos duplicados antes do write+unlink (o parser da releitura
  # tambem pegaria, mas fail-fast e mais barato).
  dup_err <- snapshot_reject_duplicate_ids(players$player_id, "projecoes cruas")
  if (is_domain_error(dup_err)) {
    return(dup_err)
  }

  metrics <- list(player_id = players$player_id)
  for (col in names(schema$metrics)) {
    if (col %in% c("player_id", "tier_cliff")) {
      next
    }
    value <- take(col, schema$metrics[[col]]$type, isTRUE(schema$metrics[[col]]$required))
    if (is_domain_error(value)) {
      return(value)
    }
    metrics[[col]] <- value
  }

  if ("tier_cliff" %in% names(raw_df)) {
    cliff <- take("tier_cliff", "logical", TRUE)
    if (is_domain_error(cliff)) {
      return(cliff)
    }
    metrics$tier_cliff <- cliff
  } else if ("pos_rank" %in% names(raw_df)) {
    cliff <- derive_tier_cliff(norm_pos, raw_df$pos_rank, metrics$tier)
    if (is_domain_error(cliff)) {
      return(cliff)
    }
    metrics$tier_cliff <- cliff
  }
  # senao: coluna ausente -> o parser da releitura reporta snapshot_coluna_ausente.

  players_df <- as.data.frame(
    players[intersect(names(schema$players), names(players))],
    stringsAsFactors = FALSE
  )
  metrics_df <- as.data.frame(
    metrics[intersect(names(schema$metrics), names(metrics))],
    stringsAsFactors = FALSE
  )

  list(players = players_df, metrics = metrics_df)
}

#' Monta o `metadata.json` do bundle (sem o campo derivado `content_hash`)
#'
#' @param snapshot_id,season,generated_at,pipeline_version,source_list,scoring_hash,qa_summary
#'   Valores ja resolvidos pela camada de aplicacao.
#' @return Lista nomeada com os metadados de conteudo. `content_hash` e
#'   acrescentado pelo adapter de escrita (`write_snapshot_bundle()`).
#' @export
build_snapshot_metadata <- function(snapshot_id, season, generated_at, pipeline_version,
                                    source_list, scoring_hash, qa_summary) {
  list(
    snapshot_id = as.character(snapshot_id),
    season = as.integer(season),
    generated_at = as.character(generated_at),
    pipeline_version = as.character(pipeline_version),
    source_list = as.character(source_list),
    scoring_hash = as.character(scoring_hash),
    qa_summary = as.character(qa_summary),
    schema_version = "snapshot-bundle-v1"
  )
}

#' Monta o `qa-report.json` estruturalmente valido (classificacao e a Story 1.5)
#'
#' @param players `data.frame` de jogadores canonicos (coluna `position`).
#' @param generated_at Timestamp UTC ISO-8601 (mesmo do metadata).
#' @return Lista com `schema_version`, `generated_at`, `findings` (vazio) e
#'   `coverage` (contagem por posicao, chaves ordenadas).
#' @export
build_qa_report <- function(players, generated_at) {
  counts <- table(as.character(players$position))
  coverage <- as.list(as.integer(counts))
  names(coverage) <- names(counts)
  coverage <- coverage[order(names(coverage), method = "radix")]
  list(
    schema_version = "qa-report-v1",
    generated_at = as.character(generated_at),
    findings = list(),
    coverage = coverage
  )
}
