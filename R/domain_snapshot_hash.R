# Identidade de conteudo do snapshot bundle (nucleo puro).
#
# Funcoes puras e deterministicas: nao abrem arquivos, nao importam `yaml`.
# Usam `digest` (SHA-256 e computacao pura). O adapter le os bytes crus e
# parseia o YAML; aqui normaliza, serializa canonicamente e hasheia.
#
# Contrato AD-12 (`canonical_json`) e AD-3 (manifesto do bundle). O requisito
# central e "hash identico entre maquinas", entao toda operacao sensivel a
# locale (marca decimal, colacao de strings, encoding) e forcada para a forma
# byte-estavel.

# Fonte unica de verdade dos 4 arquivos do manifesto de conteudo.
# `scoring.yml` NAO entra aqui (identidade propria via scoring_config_hash).
# O adapter (`read_bundle_files_raw`) deriva desta mesma constante.
snapshot_bundle_files <- c(
  "players.csv", "metrics.csv", "metadata.json", "qa-report.json"
)

#' Serializa um valor R para JSON canonico (contrato AD-12)
#'
#' UTF-8, LF, chaves de objeto ordenadas em ordem de byte (`method = "radix"`,
#' independente de `LC_COLLATE`), `null` explicito, `true`/`false`, marca
#' decimal sempre `"."` (independente de `OutDec`), numeros de valor inteiro
#' sem parte decimal, demais reais em decimal fixo de 10 casas, sem notacao
#' cientifica.
#'
#' @param x Lista nomeada (objeto, nomes completos e unicos), lista sem nomes
#'   ou vetor atomico sem nomes (array), ou escalar. `NULL`/`NA` viram `null`.
#'   `NaN`/`Inf`/`-Inf`, nomes parciais/duplicados, ou vetor atomico nomeado
#'   com `length > 1` sao `stop()` (ambiguos / nao representaveis).
#' @return Uma string com o JSON canonico.
#' @export
canonical_json <- function(x) {
  if (is.null(x)) {
    return("null")
  }

  if (is.list(x)) {
    nms <- names(x)
    if (length(x) == 0L) {
      return(if (is.null(nms)) "[]" else "{}")
    }
    if (!is.null(nms) && any(nzchar(nms))) {
      if (anyNA(nms) || !all(nzchar(nms)) || anyDuplicated(nms)) {
        stop("canonical_json: objeto com nomes ausentes, vazios ou duplicados.")
      }
      ord <- order(nms, method = "radix")
      parts <- vapply(
        ord,
        function(i) paste0(cj_escape_string(nms[[i]]), ":", canonical_json(x[[i]])),
        character(1L)
      )
      return(paste0("{", paste(parts, collapse = ","), "}"))
    }
    parts <- vapply(x, canonical_json, character(1L))
    return(paste0("[", paste(parts, collapse = ","), "]"))
  }

  if (!is.null(names(x)) && length(x) > 1L) {
    stop("canonical_json: vetor atomico nomeado com length > 1 e ambiguo.")
  }
  if (length(x) == 0L) {
    return("null")
  }
  if (length(x) > 1L) {
    parts <- vapply(seq_along(x), function(i) canonical_json(unname(x[i])), character(1L))
    return(paste0("[", paste(parts, collapse = ","), "]"))
  }

  if (is.na(x)) {
    if (isTRUE(is.nan(x))) {
      stop("canonical_json: NaN nao e representavel em JSON canonico.")
    }
    return("null")
  }
  if (is.logical(x)) {
    return(if (x) "true" else "false")
  }
  if (is.character(x)) {
    return(cj_escape_string(x))
  }
  if (is.numeric(x)) {
    if (!is.finite(x)) {
      stop("canonical_json: numero nao-finito nao e representavel em JSON canonico.")
    }
    if (x == round(x) && abs(x) < 2^53) {
      return(sprintf("%.0f", x))
    }
    return(formatC(x, format = "f", digits = 10L, decimal.mark = "."))
  }
  cj_escape_string(as.character(x))
}

# Escapa uma string para um literal JSON entre aspas. Formas curtas para os
# escapes comuns; demais pontos de codigo < 0x20 como `\u00xx`.
cj_escape_string <- function(s) {
  s <- as.character(s)
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub("\"", "\\\"", s, fixed = TRUE)
  s <- gsub("\b", "\\b", s, fixed = TRUE)
  s <- gsub("\f", "\\f", s, fixed = TRUE)
  s <- gsub("\n", "\\n", s, fixed = TRUE)
  s <- gsub("\r", "\\r", s, fixed = TRUE)
  s <- gsub("\t", "\\t", s, fixed = TRUE)
  for (cp in c(1:7, 11L, 14:31)) {
    s <- gsub(intToUtf8(cp), sprintf("\\u%04x", cp), s, fixed = TRUE)
  }
  paste0("\"", s, "\"")
}

# Normaliza um campo de hash de metadata: NULL/ausente/vazio -> NA_character_.
hash_field <- function(value) {
  if (is.null(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
    return(NA_character_)
  }
  as.character(value)
}

#' SHA-256 (hex minusculo) sobre o texto, apos normalizar para bytes UTF-8
#'
#' `enc2utf8()` garante que a mesma sequencia de caracteres acentuados hasheie
#' os mesmos bytes esteja ela marcada como `latin1` ou `UTF-8`.
#'
#' @param text String unica.
#' @return SHA-256 em hex minusculo.
#' @keywords internal
sha256_hex <- function(text) {
  stopifnot(is.character(text), length(text) == 1L, !is.na(text))
  digest::digest(enc2utf8(text), algo = "sha256", serialize = FALSE)
}

#' Hash canonico do conteudo de um snapshot bundle (AD-3)
#'
#' SHA-256 de um manifesto canonico dos 4 arquivos (`snapshot_bundle_files`):
#' cada arquivo com quebras de linha normalizadas para LF e resumido por
#' SHA-256; `metadata.json` entra pela sua forma canonica **sem** o campo
#' derivado `content_hash` (assim o hash nao depende da formatacao do JSON em
#' disco, mas depende de todo campo de conteudo, inclusive `scoring_hash`).
#' `scoring.yml` fica **fora** do manifesto.
#'
#' @param raw_files Lista nomeada pelos nomes de arquivo do bundle com o
#'   conteudo cru de cada arquivo como string -- o retorno de
#'   `read_bundle_files_raw()`. Se for um [domain_error()], passa direto.
#' @param metadata `metadata.json` ja parseado (lista). Se for um
#'   [domain_error()], passa direto.
#' @return SHA-256 em hex minusculo, deterministico e identico entre maquinas
#'   para o mesmo conteudo.
#' @export
snapshot_content_hash <- function(raw_files, metadata) {
  if (is_domain_error(raw_files)) {
    return(raw_files)
  }
  if (is_domain_error(metadata)) {
    return(metadata)
  }
  stopifnot(is.list(raw_files), is.list(metadata))
  if (!setequal(names(raw_files), snapshot_bundle_files)) {
    stop(
      "raw_files precisa conter exatamente: ",
      paste(snapshot_bundle_files, collapse = ", ")
    )
  }

  manifest <- list()
  for (path in snapshot_bundle_files) {
    payload <- if (identical(path, "metadata.json")) {
      canonical_json(metadata[setdiff(names(metadata), "content_hash")])
    } else {
      gsub("\r\n?", "\n", raw_files[[path]], perl = TRUE)
    }
    manifest[[path]] <- sha256_hex(payload)
  }

  sha256_hex(canonical_json(manifest))
}

#' Verifica se `raw_files` bate com `metadata$content_hash`
#'
#' @param raw_files Retorno de `read_bundle_files_raw()`.
#' @param metadata `metadata.json` parseado.
#' @return `NULL` (invisivel) se `snapshot_content_hash()` for igual a
#'   `metadata$content_hash`; senao um [domain_error()]
#'   `"snapshot_content_incompativel"` com `details = list(esperado,
#'   encontrado)`. Um [domain_error()] em qualquer argumento passa direto.
#' @export
verify_content_hash <- function(raw_files, metadata) {
  if (is_domain_error(raw_files)) {
    return(raw_files)
  }
  if (is_domain_error(metadata)) {
    return(metadata)
  }
  stopifnot(is.list(metadata))
  encontrado <- snapshot_content_hash(raw_files, metadata)
  esperado <- hash_field(metadata$content_hash)
  if (identical(encontrado, esperado)) {
    return(invisible(NULL))
  }
  domain_error(
    "snapshot_content_incompativel",
    sprintf(
      "Hash de conteudo incompativel: esperado '%s', encontrado '%s'.",
      esperado, encontrado
    ),
    list(esperado = esperado, encontrado = encontrado)
  )
}

#' Hash canonico da configuracao de scoring
#'
#' SHA-256 da forma canonica ([canonical_json()]) do YAML de scoring ja
#' parseado (chaves ordenadas, `null` explicito, decimal fixo). Nao depende da
#' inferencia de tipo do `yaml` (`4` e `4.0` produzem `"4"`).
#'
#' @param parsed_scoring Lista parseada de `scoring.yml` -- de
#'   `read_scoring_config()`. Se for um [domain_error()], passa direto.
#' @return SHA-256 em hex minusculo.
#' @export
scoring_config_hash <- function(parsed_scoring) {
  if (is_domain_error(parsed_scoring)) {
    return(parsed_scoring)
  }
  sha256_hex(canonical_json(parsed_scoring))
}

#' Verifica se o scoring parseado bate com `metadata$scoring_hash`
#'
#' Nao aplica o gate de compatibilidade (Story 2.6) -- so expoe o resultado.
#'
#' @param parsed_scoring Lista parseada de `scoring.yml`. Se for um
#'   [domain_error()], passa direto.
#' @param metadata `metadata.json` parseado. Se for um [domain_error()], passa
#'   direto.
#' @return `NULL` (invisivel) se `scoring_config_hash(parsed_scoring)` for
#'   igual a `metadata$scoring_hash`; senao um [domain_error()]
#'   `"snapshot_scoring_incompativel"` com `details = list(esperado,
#'   encontrado)` (`esperado = NA_character_` se o campo estiver
#'   ausente/vazio).
#' @export
verify_scoring_hash <- function(parsed_scoring, metadata) {
  if (is_domain_error(parsed_scoring)) {
    return(parsed_scoring)
  }
  if (is_domain_error(metadata)) {
    return(metadata)
  }
  stopifnot(is.list(metadata))
  encontrado <- scoring_config_hash(parsed_scoring)
  esperado <- hash_field(metadata$scoring_hash)
  if (identical(encontrado, esperado)) {
    return(invisible(NULL))
  }
  domain_error(
    "snapshot_scoring_incompativel",
    sprintf(
      "Hash de scoring incompativel: esperado '%s', encontrado '%s'.",
      esperado, encontrado
    ),
    list(esperado = esperado, encontrado = encontrado)
  )
}
