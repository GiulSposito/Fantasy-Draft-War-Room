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

#' Interpreta um snapshot bundle ja desserializado em objeto canonico tipado
#'
#' Parser PURO: recebe os dados que o adapter
#' ([read_snapshot_bundle()]) ja leu e desserializou, valida contra
#' [snapshot_schema()], coage tipos, exige os metadados obrigatorios,
#' normaliza `position` via [normalize_position()] e junta identidade +
#' metricas por `player_id`. Nao abre arquivos, nao importa `jsonlite`/`utils`.
#'
#' @param deserialized Lista com `players` (`data.frame`), `metrics`
#'   (`data.frame`), `metadata` (lista) e `qa_report` (lista) -- o retorno de
#'   [read_snapshot_bundle()]. Se `deserialized` ja for um [domain_error()]
#'   (o adapter falhou) ele passa direto sem alteracao.
#' @return Em caso de sucesso, uma lista de classe `"fdwr_snapshot_bundle"`
#'   com `metadata` (cru), `players` (`data.frame` unido, posicoes
#'   normalizadas, apenas colunas do schema, opcionais ausentes como `NA`
#'   tipado) e `qa_report` (cru). Em caso de falha, um [domain_error()] com
#'   `code`: `snapshot_formato_invalido`, `snapshot_schema_incompativel`,
#'   `snapshot_metadado_ausente`, `snapshot_coluna_ausente`,
#'   `snapshot_tipo_invalido`, `snapshot_bundle_vazio`,
#'   `snapshot_player_id_duplicado`, `snapshot_posicao_invalida` ou
#'   `snapshot_join_incompleto` -- ou o proprio erro do adapter
#'   (`bundle_arquivo_ausente`, `bundle_formato_invalido`).
#' @export
parse_snapshot_bundle <- function(deserialized) {
  if (is_domain_error(deserialized)) {
    return(deserialized)
  }

  schema <- snapshot_schema()

  metadata_err <- snapshot_validate_metadata(deserialized$metadata, schema$metadata)
  if (is_domain_error(metadata_err)) {
    return(metadata_err)
  }

  players <- snapshot_validate_table(deserialized$players, schema$players, "players.csv")
  if (is_domain_error(players)) {
    return(players)
  }
  metrics <- snapshot_validate_table(deserialized$metrics, schema$metrics, "metrics.csv")
  if (is_domain_error(metrics)) {
    return(metrics)
  }

  if (nrow(players) == 0L || nrow(metrics) == 0L) {
    return(domain_error(
      "snapshot_bundle_vazio",
      "Bundle vazio: players.csv e metrics.csv precisam de ao menos uma linha.",
      list(players = nrow(players), metrics = nrow(metrics))
    ))
  }

  dup_err <- snapshot_reject_duplicate_ids(players$player_id, "players.csv")
  if (is_domain_error(dup_err)) {
    return(dup_err)
  }
  dup_err <- snapshot_reject_duplicate_ids(metrics$player_id, "metrics.csv")
  if (is_domain_error(dup_err)) {
    return(dup_err)
  }

  players <- snapshot_fill_optional_na(players, schema$players)
  metrics <- snapshot_fill_optional_na(metrics, schema$metrics)
  players <- players[, intersect(names(schema$players), names(players)), drop = FALSE]
  metrics <- metrics[, intersect(names(schema$metrics), names(metrics)), drop = FALSE]

  normalized <- character(nrow(players))
  for (i in seq_len(nrow(players))) {
    result <- normalize_position(players$position[[i]])
    if (is_domain_error(result)) {
      return(domain_error(
        "snapshot_posicao_invalida",
        sprintf(
          "Posição inválida para player_id '%s': %s",
          players$player_id[[i]], result$message
        ),
        list(player_id = players$player_id[[i]], raw = players$position[[i]])
      ))
    }
    normalized[[i]] <- result
  }
  players$position <- normalized

  orphans <- snapshot_orphan_ids(players$player_id, metrics$player_id)
  if (length(orphans$apenas_em_players) > 0L || length(orphans$apenas_em_metrics) > 0L) {
    fmt <- function(ids) if (length(ids) == 0L) "nenhum" else paste(ids, collapse = ", ")
    return(domain_error(
      "snapshot_join_incompleto",
      sprintf(
        "player_id órfãos no join: só em players.csv: %s; só em metrics.csv: %s.",
        fmt(orphans$apenas_em_players), fmt(orphans$apenas_em_metrics)
      ),
      list(
        apenas_em_players = orphans$apenas_em_players,
        apenas_em_metrics = orphans$apenas_em_metrics
      )
    ))
  }

  merged <- merge(players, metrics, by = "player_id", sort = TRUE)
  rownames(merged) <- NULL

  structure(
    list(
      metadata = deserialized$metadata,
      players = merged,
      qa_report = deserialized$qa_report
    ),
    class = "fdwr_snapshot_bundle"
  )
}

# --- helpers puros ----------------------------------------------------------

# Metadados obrigatorios: presenca (nao NULL/NA/"") + schema_version esperado.
snapshot_validate_metadata <- function(metadata, spec) {
  if (!is.list(metadata) || is.data.frame(metadata)) {
    return(domain_error(
      "snapshot_formato_invalido",
      "metadata.json não desserializou para um objeto JSON.",
      list(arquivo = "metadata.json")
    ))
  }
  for (campo in names(spec)) {
    if (!isTRUE(spec[[campo]]$required)) {
      next
    }
    value <- metadata[[campo]]
    missing <- is.null(value) ||
      (length(value) == 0L) ||
      (length(value) == 1L && is.na(value)) ||
      (is.character(value) && length(value) == 1L && !nzchar(value))
    if (missing) {
      return(domain_error(
        "snapshot_metadado_ausente",
        sprintf("Metadado obrigatório ausente: %s.", campo),
        list(campo = campo)
      ))
    }
  }
  if (!identical(as.character(metadata$schema_version), "snapshot-bundle-v1")) {
    return(domain_error(
      "snapshot_schema_incompativel",
      sprintf(
        "schema_version incompatível: esperado 'snapshot-bundle-v1', encontrado '%s'.",
        as.character(metadata$schema_version)
      ),
      list(encontrado = metadata$schema_version)
    ))
  }
  invisible(NULL)
}

# Valida forma, colunas obrigatorias e coage tipos das colunas conhecidas.
snapshot_validate_table <- function(df, spec, arquivo) {
  if (!is.data.frame(df)) {
    return(domain_error(
      "snapshot_formato_invalido",
      sprintf("%s não desserializou para uma tabela.", arquivo),
      list(arquivo = arquivo)
    ))
  }
  if (anyDuplicated(names(df)) > 0L) {
    return(domain_error(
      "snapshot_formato_invalido",
      sprintf("%s tem nomes de coluna duplicados.", arquivo),
      list(arquivo = arquivo)
    ))
  }
  for (col in names(spec)) {
    if (isTRUE(spec[[col]]$required) && !col %in% names(df)) {
      return(domain_error(
        "snapshot_coluna_ausente",
        sprintf("Coluna obrigatória ausente em %s: %s.", arquivo, col),
        list(arquivo = arquivo, campo = col)
      ))
    }
  }
  for (col in names(spec)) {
    if (!col %in% names(df)) {
      next
    }
    coerced <- snapshot_coerce_column(df[[col]], spec[[col]]$type, isTRUE(spec[[col]]$required))
    if (!coerced$ok) {
      return(domain_error(
        "snapshot_tipo_invalido",
        sprintf(
          "Valor incompatível em %s.%s (%s): '%s'.",
          arquivo, col, coerced$motivo, coerced$value
        ),
        list(arquivo = arquivo, campo = col, valor = coerced$value, motivo = coerced$motivo)
      ))
    }
    df[[col]] <- coerced$value
  }
  df
}

# Coage um vetor para o tipo do schema. Retorna list(ok, value[, motivo]):
# ok = FALSE e motivo em {"vazio", "nao_coercivel", "nao_inteiro"}.
snapshot_coerce_column <- function(x, type, required) {
  chr <- trimws(as.character(x))
  blank <- is.na(x) | !nzchar(chr)

  if (required && any(blank)) {
    return(list(ok = FALSE, value = "", motivo = "vazio"))
  }

  if (type == "character") {
    out <- as.character(x)
    out[blank] <- NA_character_
    return(list(ok = TRUE, value = out))
  }

  num <- switch(
    type,
    numeric = suppressWarnings(as.numeric(chr)),
    integer = suppressWarnings(as.numeric(chr)),
    logical = snapshot_coerce_logical(chr),
    return(list(ok = TRUE, value = x))
  )

  bad <- !blank & is.na(num)
  if (any(bad)) {
    return(list(ok = FALSE, value = chr[which(bad)[1L]], motivo = "nao_coercivel"))
  }
  if (type == "integer") {
    non_int <- !blank & !is.na(num) & num != round(num)
    if (any(non_int)) {
      return(list(ok = FALSE, value = chr[which(non_int)[1L]], motivo = "nao_inteiro"))
    }
    num <- as.integer(round(num))
  }
  num[blank] <- NA
  list(ok = TRUE, value = num)
}

snapshot_coerce_logical <- function(chr) {
  low <- tolower(chr)
  out <- rep(NA, length(chr))
  out[low %in% c("true", "t", "1", "yes", "y")] <- TRUE
  out[low %in% c("false", "f", "0", "no", "n")] <- FALSE
  out
}

# Garante que toda coluna do schema exista no df; ausente -> NA tipado.
snapshot_fill_optional_na <- function(df, spec) {
  typed_na <- list(
    character = NA_character_, numeric = NA_real_,
    integer = NA_integer_, logical = NA
  )
  for (col in names(spec)) {
    if (!col %in% names(df)) {
      df[[col]] <- typed_na[[spec[[col]]$type]]
    }
  }
  df
}

# player_id presentes em exatamente um dos vetores (orfaos do join).
snapshot_orphan_ids <- function(players_ids, metrics_ids) {
  p <- as.character(players_ids)
  m <- as.character(metrics_ids)
  list(apenas_em_players = setdiff(p, m), apenas_em_metrics = setdiff(m, p))
}

# Rejeita player_id repetido dentro de um arquivo (integridade estrutural).
snapshot_reject_duplicate_ids <- function(ids, arquivo) {
  ids <- as.character(ids)
  dup <- unique(ids[duplicated(ids)])
  if (length(dup) == 0L) {
    return(invisible(NULL))
  }
  domain_error(
    "snapshot_player_id_duplicado",
    sprintf("player_id duplicado em %s: %s", arquivo, paste(dup, collapse = ", ")),
    list(arquivo = arquivo, player_id = dup)
  )
}
