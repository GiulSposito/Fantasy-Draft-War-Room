# Caso de uso: preparar um snapshot bundle (shell de aplicacao).
#
# Primeiro caso de uso do pacote. Orquestra comandos de dominio
# (`build_snapshot_tables`, `build_snapshot_metadata`, `build_qa_report`) +
# ports (o `collect_fn` e `write_fn` injetados, o parser da releitura). Nao
# abre a rede, nao le arquivo diretamente exceto na releitura de verificacao.
# O clock entra como funcao injetada -> `generated_at` e `snapshot_id`
# deterministicos nos testes.

#' Prepara e valida um snapshot bundle
#'
#' @param collect_fn Funcao sem argumentos que devolve o `data.frame` cru comum
#'   (coleta `ffanalytics` ou CSV manual) ou um [domain_error()].
#' @param write_fn Funcao `(snapshot_id, players, metrics, metadata, qa_report,
#'   scoring_text)` que grava o bundle atomicamente e devolve o caminho do
#'   diretorio ou um [domain_error()] (tipicamente [write_snapshot_bundle()]
#'   com a raiz ja fechada).
#' @param clock Funcao sem argumentos que devolve o instante atual (`POSIXct`).
#' @param scoring_raw_text Texto cru do YAML de scoring (copia byte-a-byte para
#'   `scoring.yml`).
#' @param scoring_parsed Lista do YAML de scoring ja parseada.
#' @param pipeline_config Lista de `config/snapshot_pipeline.yml` parseada.
#' @param season Temporada (inteiro).
#' @param source_list Vetor de fontes agregadas para o `metadata.json`.
#' @return `list(snapshot_id, bundle_dir)` no sucesso; um [domain_error()] em
#'   qualquer falha (nenhum bundle parcial permanece em disco).
#' @export
prepare_snapshot <- function(collect_fn, write_fn, clock,
                             scoring_raw_text, scoring_parsed,
                             pipeline_config, season, source_list) {
  now <- clock()
  generated_at <- format(as.POSIXct(now, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  snapshot_id <- new_snapshot_id(season, now)

  raw <- collect_fn()
  if (is_domain_error(raw)) {
    return(raw)
  }

  tables <- build_snapshot_tables(raw)
  if (is_domain_error(tables)) {
    return(tables)
  }

  scoring_hash <- scoring_config_hash(scoring_parsed)
  if (is_domain_error(scoring_hash)) {
    return(scoring_hash)
  }

  qa_report <- build_qa_report(tables$players, generated_at)
  qa_summary <- sprintf("%d jogadores, 0 bloqueios", nrow(tables$players))
  metadata <- build_snapshot_metadata(
    snapshot_id = snapshot_id,
    season = season,
    generated_at = generated_at,
    pipeline_version = pipeline_config$pipeline_version,
    source_list = source_list,
    scoring_hash = scoring_hash,
    qa_summary = qa_summary
  )

  bundle_dir <- write_fn(
    snapshot_id = snapshot_id,
    players = tables$players,
    metrics = tables$metrics,
    metadata = metadata,
    qa_report = qa_report,
    scoring_text = scoring_raw_text
  )
  if (is_domain_error(bundle_dir)) {
    return(bundle_dir)
  }

  verified <- prepare_snapshot_verify(bundle_dir)
  if (is_domain_error(verified)) {
    unlink(bundle_dir, recursive = TRUE, force = TRUE)
    return(verified)
  }

  list(snapshot_id = snapshot_id, bundle_dir = bundle_dir)
}

# Rele o bundle do disco (inclusive scoring.yml) e roda parser + verificacao
# dos dois hashes. Frozen Boundary: o bundle emitido e "relido do disco e passa
# por parse_snapshot_bundle(), verify_content_hash() e verify_scoring_hash()" --
# entao o scoring vem do arquivo gravado, nao do objeto em memoria.
prepare_snapshot_verify <- function(bundle_dir) {
  parsed <- parse_snapshot_bundle(read_snapshot_bundle(bundle_dir))
  if (is_domain_error(parsed)) {
    return(parsed)
  }
  raw_files <- read_bundle_files_raw(bundle_dir)
  if (is_domain_error(raw_files)) {
    return(raw_files)
  }
  content_check <- verify_content_hash(raw_files, parsed$metadata)
  if (is_domain_error(content_check)) {
    return(content_check)
  }
  scoring_on_disk <- read_scoring_config(file.path(bundle_dir, "scoring.yml"))
  if (is_domain_error(scoring_on_disk)) {
    return(scoring_on_disk)
  }
  scoring_check <- verify_scoring_hash(scoring_on_disk, parsed$metadata)
  if (is_domain_error(scoring_check)) {
    return(scoring_check)
  }
  invisible(NULL)
}
