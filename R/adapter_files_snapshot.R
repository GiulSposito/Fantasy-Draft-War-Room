# Adapter de arquivos do snapshot bundle (shell imperativo).
#
# UNICO ponto que abre arquivos do bundle e chama `utils::read.csv` /
# `jsonlite::fromJSON` / `yaml::read_yaml`. Faz apenas leitura crua +
# desserializacao de formato; nao valida schema, nao normaliza, nao junta --
# isso e o dominio puro (`parse_snapshot_bundle()`). Devolve a lista crua ou
# um `domain_error`.
#
# A lista canonica dos 4 arquivos e `snapshot_bundle_files`
# (`R/domain_snapshot_hash.R`) -- fonte unica compartilhada com o hash.

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

  for (arquivo in snapshot_bundle_files) {
    if (!file.exists(file.path(bundle_dir, arquivo))) {
      return(domain_error(
        "bundle_arquivo_ausente",
        sprintf("Arquivo do bundle ausente: %s.", arquivo),
        list(arquivo = arquivo, bundle_dir = bundle_dir)
      ))
    }
  }

  players <- read_bundle_csv(file.path(bundle_dir, "players.csv"), "players.csv")
  if (is_domain_error(players)) {
    return(players)
  }
  metrics <- read_bundle_csv(file.path(bundle_dir, "metrics.csv"), "metrics.csv")
  if (is_domain_error(metrics)) {
    return(metrics)
  }
  metadata <- read_bundle_json(file.path(bundle_dir, "metadata.json"), "metadata.json")
  if (is_domain_error(metadata)) {
    return(metadata)
  }
  qa_report <- read_bundle_json(file.path(bundle_dir, "qa-report.json"), "qa-report.json")
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

#' Le os 4 arquivos do bundle como bytes crus (para o hash de conteudo)
#'
#' @param bundle_dir Caminho do diretorio do bundle.
#' @return `list("players.csv" = <string>, "metrics.csv" = ..., "metadata.json"
#'   = ..., "qa-report.json" = ...)` com o conteudo cru de cada arquivo (bytes
#'   declarados como UTF-8, conforme o contrato do bundle); ou um
#'   [domain_error()] `"bundle_arquivo_ausente"` (arquivo faltando, diretorio,
#'   ou sem permissao de leitura) ou `"bundle_formato_invalido"` (bytes NUL).
#' @export
read_bundle_files_raw <- function(bundle_dir) {
  stopifnot(is.character(bundle_dir), length(bundle_dir) == 1L, nzchar(bundle_dir))

  out <- vector("list", length(snapshot_bundle_files))
  names(out) <- snapshot_bundle_files
  for (arquivo in snapshot_bundle_files) {
    path <- file.path(bundle_dir, arquivo)
    if (!file.exists(path) || dir.exists(path) || file.access(path, 4L) != 0L) {
      return(domain_error(
        "bundle_arquivo_ausente",
        sprintf("Arquivo do bundle ausente ou ilegivel: %s.", arquivo),
        list(arquivo = arquivo, bundle_dir = bundle_dir)
      ))
    }
    bytes <- readBin(path, "raw", n = file.size(path))
    text <- tryCatch(rawToChar(bytes), error = function(e) e)
    if (inherits(text, "error")) {
      return(snapshot_format_error(arquivo, conditionMessage(text)))
    }
    Encoding(text) <- "UTF-8"
    out[[arquivo]] <- text
  }
  out
}

#' Le e parseia o YAML de scoring do bundle
#'
#' @param scoring_path Caminho para `scoring.yml`.
#' @return A lista (mapa) parseada (`yaml::read_yaml`); ou um [domain_error()]
#'   `"bundle_arquivo_ausente"` (arquivo faltando) ou
#'   `"bundle_formato_invalido"` (YAML malformado ou que nao e um mapa).
#' @export
read_scoring_config <- function(scoring_path) {
  stopifnot(is.character(scoring_path), length(scoring_path) == 1L, nzchar(scoring_path))

  if (!file.exists(scoring_path) || dir.exists(scoring_path)) {
    return(domain_error(
      "bundle_arquivo_ausente",
      sprintf("Arquivo do bundle ausente: %s.", basename(scoring_path)),
      list(arquivo = basename(scoring_path))
    ))
  }
  out <- tryCatch(yaml::read_yaml(scoring_path), error = function(e) e)
  if (inherits(out, "error")) {
    return(snapshot_format_error(basename(scoring_path), conditionMessage(out)))
  }
  if (!is.list(out) || is.null(names(out)) || length(out) == 0L) {
    return(snapshot_format_error(basename(scoring_path), "não é um mapa YAML"))
  }
  out
}
