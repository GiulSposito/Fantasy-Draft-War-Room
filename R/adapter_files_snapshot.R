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

# --- Story 1.4: CSV manual + escrita do bundle ------------------------------

#' Le um CSV de projecoes manual (modo fallback) na forma crua comum
#'
#' Leitura crua apenas: nao valida colunas nem tipos -- isso e o dominio
#' ([build_snapshot_tables()]) e o parser da releitura.
#'
#' @param csv_path Caminho para o CSV manual.
#' @return `data.frame` (strings sem fator, nomes de coluna preservados); ou um
#'   [domain_error()] `"bundle_arquivo_ausente"` / `"bundle_formato_invalido"`.
#' @export
read_manual_projection_csv <- function(csv_path) {
  stopifnot(is.character(csv_path), length(csv_path) == 1L, nzchar(csv_path))
  if (!file.exists(csv_path) || dir.exists(csv_path)) {
    return(domain_error(
      "bundle_arquivo_ausente",
      sprintf("Arquivo de projecoes manual ausente: %s.", basename(csv_path)),
      list(arquivo = basename(csv_path))
    ))
  }
  read_bundle_csv(csv_path, basename(csv_path))
}

#' Le o JSON de overrides de metadata do modo CSV manual
#'
#' @param json_path Caminho para o JSON (`--metadata`).
#' @return Lista parseada; ou um [domain_error()] `"bundle_arquivo_ausente"` /
#'   `"bundle_formato_invalido"` (JSON malformado ou que nao e um objeto).
#' @export
read_metadata_overrides <- function(json_path) {
  stopifnot(is.character(json_path), length(json_path) == 1L, nzchar(json_path))
  if (!file.exists(json_path) || dir.exists(json_path)) {
    return(domain_error(
      "bundle_arquivo_ausente",
      sprintf("Arquivo de metadata ausente: %s.", basename(json_path)),
      list(arquivo = basename(json_path))
    ))
  }
  out <- read_bundle_json(json_path, basename(json_path))
  if (is_domain_error(out)) {
    return(out)
  }
  if (!is.list(out) || is.data.frame(out) || is.null(names(out))) {
    return(snapshot_format_error(basename(json_path), "não é um objeto JSON"))
  }
  out
}

#' Lista os snapshot bundles preparados sob `root`
#'
#' Enumera os subdiretorios diretos de `root` cujo nome casa com o padrao de
#' `snapshot_id` (`snap-<season>-<YYYYMMDDTHHMMSSZ>`, ver [new_snapshot_id()]) e
#' que contem os 4 arquivos canonicos (`snapshot_bundle_files`), ordenados por
#' nome em ordem decrescente. O filtro de padrao descarta os `tmp-snapshot-*` de
#' execucoes mortas de [write_snapshot_bundle()] (bundles meio-escritos).
#'
#' @param root Diretorio raiz dos bundles (default [resolve_snapshot_root()]).
#' @return Vetor de caminhos absolutos dos diretorios de bundle, ordem `desc`;
#'   `character(0)` se `root` nao existe ou nao tem bundle; um [domain_error()]
#'   `"snapshot_root_ilegivel"` se `root` existe mas nao e um diretorio legivel.
#' @export
list_snapshot_bundles <- function(root = resolve_snapshot_root()) {
  stopifnot(is.character(root), length(root) == 1L, nzchar(root))

  if (!dir.exists(root)) {
    if (file.exists(root)) {
      return(domain_error(
        "snapshot_root_ilegivel",
        sprintf("Não é um diretório: %s.", root),
        list(root = root)
      ))
    }
    return(character(0))
  }
  if (file.access(root, 4L) != 0L) {
    return(domain_error(
      "snapshot_root_ilegivel",
      sprintf("Diretório de snapshots ilegível: %s.", root),
      list(root = root)
    ))
  }

  subdirs <- list.dirs(root, full.names = TRUE, recursive = FALSE)
  keep <- vapply(subdirs, function(d) {
    grepl("^snap-[0-9]+-[0-9]{8}T[0-9]{6}Z$", basename(d)) &&
      all(file.exists(file.path(d, snapshot_bundle_files)))
  }, logical(1L))
  bundles <- subdirs[keep]
  bundles <- bundles[order(basename(bundles), method = "radix", decreasing = TRUE)]
  if (length(bundles)) normalizePath(bundles) else bundles
}

#' Resolve o diretorio raiz onde os bundles sao gravados
#'
#' @param out_override `--out` do CLI (ou `NULL`).
#' @return `out_override` expandido, ou
#'   `tools::R_user_dir("fantasydraftwarroom", "data")/snapshots`.
#' @export
resolve_snapshot_root <- function(out_override = NULL) {
  if (!is.null(out_override) && nzchar(out_override)) {
    return(path.expand(out_override))
  }
  file.path(tools::R_user_dir("fantasydraftwarroom", "data"), "snapshots")
}

# Escreve um data.frame como CSV canonico do bundle: UTF-8, LF, sem row names,
# celula vazia para NA (o parser exige "" e nao "NA" em opcionais).
snapshot_write_bundle_csv <- function(df, path) {
  utils::write.csv(df, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
}

# Escreve uma lista como JSON do bundle. `source_list`/`findings` como array
# mesmo com 1 elemento; escalares desembrulhados.
snapshot_write_bundle_json <- function(x, path) {
  if (!is.null(x$source_list)) {
    x$source_list <- as.list(as.character(x$source_list))
  }
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

#' Grava um snapshot bundle de forma atomica (5 arquivos + hash de conteudo)
#'
#' Monta os 5 arquivos num diretorio temporario dentro de `root`, calcula o
#' `content_hash` (grava `metadata.json` com placeholder -> [snapshot_content_hash()]
#' -> reescreve), e so entao `file.rename` para `<root>/<snapshot_id>/`. Falha
#' em qualquer etapa remove o temporario; nada parcial em disco. Recusa
#' diretorio de destino ja existente e raiz nao gravavel.
#'
#' @param root Diretorio raiz (de [resolve_snapshot_root()]).
#' @param snapshot_id Id da execucao (nome do diretorio final).
#' @param players,metrics `data.frame` canonicos ([build_snapshot_tables()]).
#' @param metadata Lista de metadata **sem** `content_hash`
#'   ([build_snapshot_metadata()]).
#' @param qa_report Lista do `qa-report.json` ([build_qa_report()]).
#' @param scoring_text Texto cru do YAML de scoring (copia byte-a-byte).
#' @return Caminho do diretorio do bundle gravado; ou um [domain_error()]
#'   (`bundle_saida_nao_gravavel`, `bundle_ja_existe`, ou o erro de hash).
#' @export
write_snapshot_bundle <- function(root, snapshot_id, players, metrics,
                                  metadata, qa_report, scoring_text) {
  if (!dir.exists(root)) {
    created <- dir.create(root, recursive = TRUE, showWarnings = FALSE)
    if (!created) {
      return(domain_error(
        "bundle_saida_nao_gravavel",
        sprintf("Nao foi possivel criar o diretorio de saida: %s.", root),
        list(root = root)
      ))
    }
  }
  if (file.access(root, mode = 2L) != 0L) {
    return(domain_error(
      "bundle_saida_nao_gravavel",
      sprintf("Diretorio de saida sem permissao de escrita: %s.", root),
      list(root = root)
    ))
  }

  target <- file.path(root, snapshot_id)
  if (file.exists(target)) {
    return(domain_error(
      "bundle_ja_existe",
      sprintf("O bundle '%s' ja existe em %s -- nada foi sobrescrito.", snapshot_id, root),
      list(snapshot_id = snapshot_id, bundle_dir = target)
    ))
  }

  tmp <- tempfile(pattern = "tmp-snapshot-", tmpdir = root)
  if (!dir.create(tmp, showWarnings = FALSE)) {
    return(domain_error(
      "bundle_saida_nao_gravavel",
      sprintf("Nao foi possivel criar o diretorio temporario em %s.", root),
      list(root = root)
    ))
  }
  cleanup <- function() unlink(tmp, recursive = TRUE, force = TRUE)

  written <- tryCatch(
    {
      snapshot_write_bundle_csv(players, file.path(tmp, "players.csv"))
      snapshot_write_bundle_csv(metrics, file.path(tmp, "metrics.csv"))
      writeBin(charToRaw(enc2utf8(scoring_text)), file.path(tmp, "scoring.yml"))
      snapshot_write_bundle_json(qa_report, file.path(tmp, "qa-report.json"))
      snapshot_write_bundle_json(
        c(metadata, list(content_hash = "0")),
        file.path(tmp, "metadata.json")
      )
      TRUE
    },
    error = function(e) e
  )
  if (inherits(written, "error")) {
    cleanup()
    return(domain_error(
      "bundle_saida_nao_gravavel",
      sprintf("Falha ao gravar arquivos do bundle: %s", conditionMessage(written)),
      list(root = root, causa = conditionMessage(written))
    ))
  }

  raw_files <- read_bundle_files_raw(tmp)
  if (is_domain_error(raw_files)) {
    cleanup()
    return(raw_files)
  }
  meta_read <- read_snapshot_bundle(tmp)
  if (is_domain_error(meta_read)) {
    cleanup()
    return(meta_read)
  }
  meta_parsed <- meta_read$metadata
  content_hash <- snapshot_content_hash(raw_files, meta_parsed)
  if (is_domain_error(content_hash)) {
    cleanup()
    return(content_hash)
  }
  snapshot_write_bundle_json(
    c(metadata, list(content_hash = content_hash)),
    file.path(tmp, "metadata.json")
  )

  if (!file.rename(tmp, target)) {
    cleanup()
    return(domain_error(
      "bundle_saida_nao_gravavel",
      sprintf("Nao foi possivel mover o bundle para %s.", target),
      list(root = root, target = target)
    ))
  }
  target
}
