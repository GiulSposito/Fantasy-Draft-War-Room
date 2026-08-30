# Adapter de arquivos do snapshot bundle (shell imperativo).
#
# UNICO ponto que abre arquivos do bundle e chama `utils::read.csv` /
# `jsonlite::fromJSON`. Faz apenas leitura crua + desserializacao de formato;
# nao valida schema, nao normaliza, nao junta -- isso e o dominio puro
# (`parse_snapshot_bundle()`). Devolve a lista crua ou um `domain_error`.

# Arquivos canonicos do bundle (nome do slot -> nome do arquivo).
snapshot_bundle_files <- c(
  players   = "players.csv",
  metrics   = "metrics.csv",
  metadata  = "metadata.json",
  qa_report = "qa-report.json"
)

#' Le e desserializa os 4 arquivos de um snapshot bundle
#'
#' @param bundle_dir Caminho do diretorio que contem
#'   `players.csv`, `metrics.csv`, `metadata.json`, `qa-report.json`.
#' @return `list(players = <data.frame>, metrics = <data.frame>,
#'   metadata = <list>, qa_report = <list>)` com os dados crus (sem validacao
#'   de schema); ou um [domain_error()] com `code`
#'   `"bundle_arquivo_ausente"` (arquivo faltando, `details$arquivo`) ou
#'   `"bundle_formato_invalido"` (CSV/JSON malformado, `details$arquivo`).
#' @export
read_snapshot_bundle <- function(bundle_dir) {
  stopifnot(is.character(bundle_dir), length(bundle_dir) == 1L, nzchar(bundle_dir))

  paths <- file.path(bundle_dir, snapshot_bundle_files)
  names(paths) <- names(snapshot_bundle_files)

  for (slot in names(snapshot_bundle_files)) {
    if (!file.exists(paths[[slot]])) {
      return(domain_error(
        "bundle_arquivo_ausente",
        sprintf("Arquivo do bundle ausente: %s.", snapshot_bundle_files[[slot]]),
        list(arquivo = unname(snapshot_bundle_files[[slot]]), bundle_dir = bundle_dir)
      ))
    }
  }

  players <- read_bundle_csv(paths[["players"]], "players.csv")
  if (is_domain_error(players)) {
    return(players)
  }
  metrics <- read_bundle_csv(paths[["metrics"]], "metrics.csv")
  if (is_domain_error(metrics)) {
    return(metrics)
  }
  metadata <- read_bundle_json(paths[["metadata"]], "metadata.json")
  if (is_domain_error(metadata)) {
    return(metadata)
  }
  qa_report <- read_bundle_json(paths[["qa_report"]], "qa-report.json")
  if (is_domain_error(qa_report)) {
    return(qa_report)
  }

  list(players = players, metrics = metrics, metadata = metadata, qa_report = qa_report)
}

# Le um CSV do bundle; qualquer erro de parsing vira bundle_formato_invalido.
# fileEncoding = "UTF-8-BOM" remove um BOM (exports de Excel) para a primeira
# coluna nao virar "﻿player_id".
read_bundle_csv <- function(path, arquivo) {
  out <- tryCatch(
    utils::read.csv(
      path,
      stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8-BOM"
    ),
    error = function(e) e
  )
  if (inherits(out, "error")) {
    return(snapshot_format_error(arquivo, conditionMessage(out)))
  }
  out
}

# Le um JSON do bundle; qualquer erro de parsing vira bundle_formato_invalido.
read_bundle_json <- function(path, arquivo) {
  out <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = TRUE),
    error = function(e) e
  )
  if (inherits(out, "error")) {
    return(snapshot_format_error(arquivo, conditionMessage(out)))
  }
  out
}

snapshot_format_error <- function(arquivo, causa) {
  domain_error(
    "bundle_formato_invalido",
    sprintf("Formato inválido em %s: %s", arquivo, causa),
    list(arquivo = arquivo)
  )
}
