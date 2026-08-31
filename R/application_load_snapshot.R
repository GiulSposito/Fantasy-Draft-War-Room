# Caso de uso: carregar um snapshot bundle para o preparo (shell de aplicacao).
#
# Diferente de `prepare_snapshot_verify()` (fail-fast), este roda parse + os
# dois hashes + a qualidade em modo COLETAR-TUDO e devolve um view-model
# deterministico. Nunca `stop()`: qualquer falha vira um achado bloqueante.
# Os leitores entram injetados (default = adapters reais) -> testavel sem disco.
#
# A 1.7 e o gate pre-Epic-2: nada roda o parser antes, entao a falha do
# `parse_snapshot_bundle()` (bundle vazio, join orfao, schema_version invalido)
# tambem trava o avanco aqui. O `verify_content_hash` mora aqui (nao na 1.5):
# precisa dos bytes crus, que so o chamador tem.

# View-model dos metadados exibiveis (temporada, geracao, fontes, metodo,
# scoring, identidade de conteudo). Valores crus; o modulo Shiny formata.
snapshot_view_metadata <- function(meta) {
  list(
    temporada = meta$season,
    geracao = meta$generated_at,
    fontes = meta$source_list,
    metodo = meta$pipeline_version,
    scoring = meta$scoring_hash,
    identidade_de_conteudo = meta$content_hash
  )
}

# Cobertura por posicao V1 a partir das posicoes ja normalizadas do parser.
snapshot_coverage <- function(players) {
  tab <- table(factor(as.character(players$position), levels = positions_v1))
  out <- as.list(as.integer(tab))
  names(out) <- names(tab)
  out
}

# Dobra um domain_error num achado bloqueante preservando code/message/details.
snapshot_error_finding <- function(err) {
  snapshot_quality_finding(
    err$code, "bloqueante", err$message,
    if (is.list(err$details)) err$details else list()
  )
}

# Le com o adapter injetado sem nunca lancar (race listar<->ler faz
# `read_bundle_files_raw` chamar `readBin(n = file.size())` com NA e abortar).
snapshot_safe_read <- function(fn, arg, code) {
  tryCatch(fn(arg), error = function(e) domain_error(code, conditionMessage(e), list()))
}

#' Carrega e valida um snapshot bundle para o preparo (coletar-tudo)
#'
#' @param bundle_dir Caminho (character escalar) do diretorio do bundle.
#' @param read_bundle,read_raw,read_scoring Leitores injetaveis (default = os
#'   adapters reais). `read_scoring` recebe `file.path(bundle_dir, "scoring.yml")`.
#' @return `list(ok, metadata, coverage, avisos, bloqueios, advance_allowed)`.
#'   `ok` = a leitura estrutural + o parse do bundle passaram.
#'   `bloqueios`/`avisos` sao achados `list(code, severity, message, details)`
#'   em ordem canonica ([snapshot_quality_sort()]).
#'   `advance_allowed <- length(bloqueios) == 0L`. Nunca lanca; duas chamadas
#'   sobre o mesmo bundle -> `identical()`.
#' @export
load_snapshot_for_preparation <- function(bundle_dir,
                                          read_bundle = read_snapshot_bundle,
                                          read_raw = read_bundle_files_raw,
                                          read_scoring = read_scoring_config) {
  if (!is.character(bundle_dir) || length(bundle_dir) != 1L ||
        is.na(bundle_dir) || !nzchar(bundle_dir)) {
    return(list(
      ok = FALSE, metadata = NULL, coverage = NULL, avisos = list(),
      bloqueios = list(snapshot_quality_finding(
        "bundle_dir_invalido", "bloqueante", "Caminho de bundle inválido.", list()
      )),
      advance_allowed = FALSE
    ))
  }

  deser <- snapshot_safe_read(read_bundle, bundle_dir, "bundle_arquivo_ausente")
  if (is_domain_error(deser)) {
    raw <- deser
    scoring <- deser
  } else {
    raw <- snapshot_safe_read(read_raw, bundle_dir, "bundle_arquivo_ausente")
    scoring <- snapshot_safe_read(
      read_scoring, file.path(bundle_dir, "scoring.yml"), "bundle_scoring_ilegivel"
    )
  }

  # Qualidade (coletar-tudo) ja cobre: falha de leitura do bundle (deser e
  # domain_error), scoring divergente, scoring indisponivel, qa-report, etc.
  findings <- validate_snapshot_quality(deser, scoring)
  parsed <- parse_snapshot_bundle(deser)

  if (!is_domain_error(deser)) {
    # Falha do parser fail-fast (bundle vazio / join orfao / schema_version):
    # nada roda o parser antes da 1.7, entao ela trava o avanco.
    if (is_domain_error(parsed)) {
      findings <- c(findings, list(snapshot_error_finding(parsed)))
    }
    # Content hash: fora do coletar-tudo da 1.5 (precisa dos bytes crus).
    if (is_domain_error(raw)) {
      findings <- c(findings, list(snapshot_error_finding(raw)))
    } else if (is.list(deser$metadata) && !is.data.frame(deser$metadata)) {
      ch <- tryCatch(
        verify_content_hash(raw, deser$metadata),
        error = function(e) {
          domain_error("snapshot_content_hash_erro", conditionMessage(e), list(
            esperado = hash_field(deser$metadata$content_hash), encontrado = NA_character_
          ))
        }
      )
      if (is_domain_error(ch)) {
        findings <- c(findings, list(snapshot_error_finding(ch)))
      }
    }
  }

  findings <- snapshot_quality_sort(findings)
  bloqueios <- Filter(function(f) identical(f$severity, "bloqueante"), findings)
  avisos <- Filter(function(f) identical(f$severity, "aviso"), findings)

  meta_ok <- !is_domain_error(deser) &&
    is.list(deser$metadata) && !is.data.frame(deser$metadata)

  list(
    ok = !is_domain_error(deser) && !is_domain_error(raw) && !is_domain_error(parsed),
    metadata = if (meta_ok) snapshot_view_metadata(deser$metadata) else NULL,
    coverage = if (!is_domain_error(parsed)) snapshot_coverage(parsed$players) else NULL,
    avisos = avisos,
    bloqueios = bloqueios,
    advance_allowed = length(bloqueios) == 0L
  )
}
