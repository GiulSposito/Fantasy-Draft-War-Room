#!/usr/bin/env Rscript
# CLI de preparo do snapshot bundle (Story 1.4).
#
# UNICO componente do produto com rede (via `adapter_ffanalytics`). Coleta
# projecoes via `ffanalytics` aplicando o YAML de scoring, OU aceita um CSV
# manual (modo fallback), e emite um bundle canonico de 5 arquivos com hashes.
#
# Uso:
#   Rscript scripts/prepare_snapshot.R --scoring config/score_settings.yml \
#       --season 2025 --sources CBS,ESPN,FantasyPros \
#       [--pipeline-config config/snapshot_pipeline.yml] [--out <dir>]
#   Rscript scripts/prepare_snapshot.R --from-csv <projections.csv> \
#       --metadata <metadata.json> [--season 2025] \
#       [--pipeline-config config/snapshot_pipeline.yml] [--out <dir>]
#
# Flags: --scoring, --pipeline-config, --season, --sources, --from-csv,
#        --metadata, --out.
#
# Falha em qualquer etapa -> exit code != 0, mensagem PT-BR em stderr, nenhum
# bundle parcial em disco.

suppressMessages(pkgload::load_all(quiet = TRUE))

known_flags <- c(
  "scoring", "pipeline-config", "season", "sources", "from-csv", "metadata", "out"
)

or_default <- function(a, b) {
  if (is.null(a) || length(a) == 0L) {
    return(b)
  }
  if (length(a) == 1L && (is.na(a) || !nzchar(a))) {
    return(b)
  }
  a
}

parse_cli_args <- function(args) {
  opts <- list()
  i <- 1L
  while (i <= length(args)) {
    token <- args[[i]]
    if (!startsWith(token, "--")) {
      stop(sprintf("Argumento inesperado: %s", token))
    }
    key <- sub("^--", "", token)
    if (grepl("=", key, fixed = TRUE)) {
      parts <- strsplit(key, "=", fixed = TRUE)[[1]]
      key <- parts[[1]]
      value <- paste(parts[-1], collapse = "=")
      i <- i + 1L
    } else {
      if (i + 1L > length(args) || startsWith(args[[i + 1L]], "--")) {
        stop(sprintf("Faltou o valor de --%s", key))
      }
      value <- args[[i + 1L]]
      i <- i + 2L
    }
    if (!key %in% known_flags) {
      stop(sprintf("Flag desconhecida: --%s", key))
    }
    if (!is.null(opts[[key]])) {
      stop(sprintf("Flag repetida: --%s", key))
    }
    opts[[key]] <- value
  }
  opts
}

fail <- function(x) {
  message(if (is_domain_error(x)) x$message else as.character(x))
  quit(status = 1L, save = "no")
}

resolve_season <- function(raw) {
  if (is.null(raw) || length(raw) != 1L || is.na(raw) || !nzchar(raw)) {
    return(NULL)
  }
  n <- suppressWarnings(as.numeric(raw))
  if (is.na(n) || n != trunc(n)) {
    fail(sprintf("Temporada invalida: '%s' (esperado um ano inteiro).", raw))
  }
  if (n < 2000 || n > 2100) {
    fail(sprintf("Temporada fora do intervalo (2000-2100): %s.", raw))
  }
  as.integer(n)
}

run <- function() {
  opts <- parse_cli_args(commandArgs(trailingOnly = TRUE))

  scoring_path <- or_default(opts$scoring, file.path("config", "score_settings.yml"))
  pipeline_path <- or_default(
    opts[["pipeline-config"]], file.path("config", "snapshot_pipeline.yml")
  )

  scoring_parsed <- read_scoring_config(scoring_path)
  if (is_domain_error(scoring_parsed)) {
    fail(scoring_parsed)
  }
  size <- file.size(scoring_path)
  if (is.na(size)) {
    fail(sprintf("Arquivo de scoring ilegivel: %s", scoring_path))
  }
  scoring_raw_text <- rawToChar(readBin(scoring_path, "raw", n = size))
  Encoding(scoring_raw_text) <- "UTF-8"

  pipeline_config <- read_scoring_config(pipeline_path)
  if (is_domain_error(pipeline_config)) {
    fail(pipeline_config)
  }
  pv <- pipeline_config$pipeline_version
  if (is.null(pv) || length(pv) != 1L || is.na(pv) || !nzchar(as.character(pv))) {
    fail("config/snapshot_pipeline.yml sem pipeline_version.")
  }

  if (!is.null(opts[["from-csv"]])) {
    csv_df <- read_manual_projection_csv(opts[["from-csv"]])
    if (is_domain_error(csv_df)) {
      fail(csv_df)
    }
    overrides <- list()
    if (!is.null(opts$metadata)) {
      overrides <- read_metadata_overrides(opts$metadata)
      if (is_domain_error(overrides)) {
        fail(overrides)
      }
    }
    season <- resolve_season(or_default(opts$season, as.character(overrides$season)))
    if (is.null(season)) {
      fail("Modo CSV: informe --season ou 'season' no JSON de --metadata.")
    }
    source_list <- "manual-csv"
    collect_fn <- function() csv_df
  } else {
    season <- resolve_season(opts$season)
    if (is.null(season)) {
      fail("Modo coleta: --season e obrigatorio.")
    }
    sources <- trimws(strsplit(
      or_default(opts$sources, "CBS,ESPN,FantasyPros"), ",", fixed = TRUE
    )[[1]])
    sources <- sources[nzchar(sources)]
    if (length(sources) == 0L) {
      fail("Modo coleta: informe ao menos uma fonte em --sources.")
    }
    source_list <- sources
    collect_fn <- function() {
      collect_ffanalytics_projections(scoring_parsed, pipeline_config, season, sources)
    }
  }

  root <- resolve_snapshot_root(opts$out)
  write_fn <- function(snapshot_id, players, metrics, metadata, qa_report, scoring_text) {
    write_snapshot_bundle(root, snapshot_id, players, metrics, metadata, qa_report, scoring_text)
  }

  result <- prepare_snapshot(
    collect_fn = collect_fn,
    write_fn = write_fn,
    clock = function() Sys.time(),
    scoring_raw_text = scoring_raw_text,
    scoring_parsed = scoring_parsed,
    pipeline_config = pipeline_config,
    season = season,
    source_list = source_list
  )
  if (is_domain_error(result)) {
    fail(result)
  }

  cat("bundle_dir:", result$bundle_dir, "\n")
  cat("snapshot_id:", result$snapshot_id, "\n")
  quit(status = 0L, save = "no")
}

tryCatch(run(), error = function(e) fail(conditionMessage(e)))
