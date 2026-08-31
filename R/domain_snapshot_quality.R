# Validacao de qualidade do snapshot (nucleo puro, modo coletar-tudo).
#
# Complemento de `parse_snapshot_bundle()` (fail-fast): roda TODAS as checagens
# sobre o bundle desserializado cru e devolve uma lista ordenada e
# deterministica de achados `list(code, severity, message, details)`. Cada
# achado e "bloqueante" ou "aviso". Nao abre arquivos, nao importa
# `yaml`/`jsonlite`/`ffanalytics`, nao le o clock. Nao altera o parser.
#
# `verify_content_hash` precisa dos bytes crus dos arquivos e e responsabilidade
# do chamador (superficie / gate), nao desta funcao -- content hash nao entra na
# lista coletar-tudo.

#' Constroi e valida um achado de qualidade do snapshot
#'
#' @param code String estavel `snake_case` da classe do achado.
#' @param severity `"bloqueante"` ou `"aviso"`.
#' @param message Mensagem PT-BR factual.
#' @param details Lista nomeada machine-readable.
#' @return `list(code, severity, message, details)`.
#' @keywords internal
snapshot_quality_finding <- function(code, severity, message, details = list()) {
  stopifnot(
    is.character(code), length(code) == 1L, !is.na(code), nzchar(code),
    identical(severity, "bloqueante") || identical(severity, "aviso"),
    is.character(message), length(message) == 1L, !is.na(message),
    is.list(details)
  )
  list(code = code, severity = severity, message = message, details = details)
}

# Chave estavel e locale-independente de um `details` para desempate de ordem.
snapshot_quality_detail_key <- function(details) {
  if (!length(details)) {
    return("")
  }
  nms <- names(details)
  if (is.null(nms)) {
    nms <- as.character(seq_along(details))
  }
  ord <- order(nms, method = "radix")
  parts <- vapply(ord, function(i) {
    paste0(nms[[i]], "=", paste(as.character(details[[i]]), collapse = ","))
  }, character(1L))
  paste(parts, collapse = "|")
}

#' Ordem canonica dos achados (severidade, code, chave de details)
#'
#' `bloqueante` antes de `aviso`, depois `code` em ordem de byte
#' (`method = "radix"`), depois uma chave estavel de `details`. Independe de
#' locale; duas execucoes sobre a mesma entrada dao uma lista `identical()`.
#'
#' @param findings Lista de achados de [snapshot_quality_finding()].
#' @return A mesma lista, reordenada.
#' @keywords internal
snapshot_quality_sort <- function(findings) {
  if (!length(findings)) {
    return(findings)
  }
  sev <- vapply(
    findings,
    function(f) if (identical(f$severity, "bloqueante")) 0L else 1L,
    integer(1L)
  )
  code <- vapply(findings, function(f) f$code, character(1L))
  key <- vapply(findings, function(f) snapshot_quality_detail_key(f$details), character(1L))
  findings[order(sev, code, key, method = "radix")]
}

# "Ausente" para uma celula crua: NA/NaN ou texto so com espacos.
snapshot_quality_blank <- function(x) {
  is.na(x) | (is.character(x) & !nzchar(trimws(x)))
}

# Vetor de player_id como character; NA tipado quando a coluna nao existe.
snapshot_quality_id_col <- function(df) {
  if ("player_id" %in% names(df)) as.character(df$player_id) else rep(NA_character_, nrow(df))
}

# Extrai as entradas de `qa_report$findings` (data.frame, lista ou vazio).
snapshot_quality_qa_entries <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(list())
  }
  if (is.data.frame(x)) {
    return(lapply(seq_len(nrow(x)), function(i) as.list(x[i, , drop = FALSE])))
  }
  if (is.list(x)) {
    # `findings` como objeto JSON unico (jsonlite nao simplifica p/ data.frame
    # quando ha so uma entrada com forma irregular): um list(code=, severity=,
    # message=) solto -- envolve como lista de 1 entrada.
    looks_like_entry <- any(c("code", "severity", "message") %in% names(x)) &&
      !any(vapply(x, is.list, logical(1L)))
    if (looks_like_entry) {
      return(list(x))
    }
    return(x)
  }
  list()
}

snapshot_quality_scalar_chr <- function(x, fallback) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) x else fallback
}

#' Valida a qualidade de um snapshot bundle desserializado (coletar-tudo)
#'
#' Roda todas as checagens semanticas e estruturais que o gate de inicio e a
#' superficie "Qualidade do snapshot" (Story 1.7) precisam: campos obrigatorios
#' de jogador, metadados obrigatorios, `player_id` duplicado, nome ambiguo,
#' posicao fora do conjunto V1, ADP invalido quando informado, hash de scoring
#' divergente, `qa-report` ausente ou com achado bloqueante, opcionais ausentes
#' (aviso) e cobertura anomala de posicao (aviso). Nunca aborta no primeiro
#' problema.
#'
#' @param deserialized `list(players, metrics, metadata, qa_report)` cru -- o
#'   retorno de [read_snapshot_bundle()]. Se ja for um [domain_error()] (o
#'   adapter falhou), devolve exatamente um achado bloqueante que preserva o
#'   `code` e a mensagem. Se nao for lista nem `domain_error`, devolve um
#'   `snapshot_bundle_ilegivel`.
#'
#'   Pre-condicao: `parse_snapshot_bundle()` (fail-fast) roda antes no pipeline.
#'   Ele cobre `snapshot_bundle_vazio` (players/metrics sem linhas),
#'   `snapshot_join_incompleto` e a validacao do *valor* de `schema_version` --
#'   checagens que esta lista coletar-tudo NAO replica. A lista e complemento do
#'   parser (checagens semanticas + modo coletar-tudo), nao substituto: um
#'   bundle estruturalmente degenerado ja foi barrado pelo parser antes de
#'   chegar aqui.
#' @param active_scoring_parsed Lista parseada do `scoring.yml` ativo -- de
#'   [read_scoring_config()]. Se for um [domain_error()], devolve um
#'   `snapshot_scoring_indisponivel` e pula a checagem de hash de scoring.
#' @return Lista ordenada de achados `list(code, severity, message, details)`.
#'   `severity` e `"bloqueante"` ou `"aviso"`. Ordem canonica
#'   ([snapshot_quality_sort()]); duas execucoes -> `identical()`.
#' @export
validate_snapshot_quality <- function(deserialized, active_scoring_parsed) {
  if (is_domain_error(deserialized)) {
    return(list(snapshot_quality_finding(
      deserialized$code, "bloqueante", deserialized$message,
      if (is.list(deserialized$details)) deserialized$details else list()
    )))
  }
  if (!is.list(deserialized) || is.data.frame(deserialized)) {
    return(list(snapshot_quality_finding(
      "snapshot_bundle_ilegivel", "bloqueante",
      "Bundle ilegível: esperado uma lista desserializada ou um erro de domínio.",
      list()
    )))
  }

  schema <- snapshot_schema()
  players <- deserialized$players
  metrics <- deserialized$metrics
  metadata <- deserialized$metadata
  players_illegible <- !is.null(players) && !is.data.frame(players)
  metrics_illegible <- !is.null(metrics) && !is.data.frame(metrics)
  if (!is.data.frame(players)) {
    players <- data.frame()
  }
  if (!is.data.frame(metrics)) {
    metrics <- data.frame()
  }
  metadata_ok <- is.list(metadata) && !is.data.frame(metadata)
  metadata_illegible <- !is.null(metadata) && !metadata_ok

  # scoring ativo inutilizavel: domain_error (adapter falhou) OU tipo degenerado
  # (nao-lista / data.frame) -- espelha os guards de `deserialized`/`metadata`.
  scoring_unusable <- NULL
  if (is_domain_error(active_scoring_parsed)) {
    scoring_unusable <- list(
      message = active_scoring_parsed$message, code = active_scoring_parsed$code
    )
  } else if (!is.list(active_scoring_parsed) || is.data.frame(active_scoring_parsed)) {
    scoring_unusable <- list(
      message = "Scoring ativo indisponivel: esperado uma lista parseada ou um erro de dominio.",
      code = "scoring_tipo_invalido"
    )
  }

  acc <- new.env(parent = emptyenv())
  acc$items <- list()
  add <- function(f) acc$items[[length(acc$items) + 1L]] <- f

  # --- tabela ilegivel (nao desserializou para data.frame) ---------------
  if (players_illegible) {
    add(snapshot_quality_finding(
      "snapshot_tabela_ilegivel", "bloqueante",
      "players.csv nao desserializou para uma tabela.",
      list(tabela = "players.csv")
    ))
  }
  if (metrics_illegible) {
    add(snapshot_quality_finding(
      "snapshot_tabela_ilegivel", "bloqueante",
      "metrics.csv nao desserializou para uma tabela.",
      list(tabela = "metrics.csv")
    ))
  }

  # --- scoring indisponivel (adapter do scoring falhou / tipo invalido) ---
  if (!is.null(scoring_unusable)) {
    add(snapshot_quality_finding(
      "snapshot_scoring_indisponivel", "bloqueante", scoring_unusable$message,
      list(code = scoring_unusable$code)
    ))
  }

  # --- campos obrigatorios de jogador ------------------------------------
  check_required <- function(df, spec, tabela) {
    ids <- snapshot_quality_id_col(df)
    for (campo in names(spec)) {
      if (!isTRUE(spec[[campo]]$required)) {
        next
      }
      if (!campo %in% names(df)) {
        add(snapshot_quality_finding(
          "snapshot_campo_obrigatorio_ausente", "bloqueante",
          sprintf("Coluna obrigatória ausente em %s: %s.", tabela, campo),
          list(campo = campo, player_id = NA_character_, tabela = tabela)
        ))
        next
      }
      for (i in which(snapshot_quality_blank(df[[campo]]))) {
        add(snapshot_quality_finding(
          "snapshot_campo_obrigatorio_ausente", "bloqueante",
          sprintf(
            "Campo obrigatório '%s' ausente para player_id '%s' em %s.",
            campo, ids[[i]], tabela
          ),
          list(campo = campo, player_id = ids[[i]], tabela = tabela)
        ))
      }
    }
  }
  if (!players_illegible) {
    check_required(players, schema$players, "players.csv")
  }
  if (!metrics_illegible) {
    check_required(metrics, schema$metrics, "metrics.csv")
  }

  # --- metadados obrigatorios ----------------------------------------------
  if (metadata_illegible) {
    add(snapshot_quality_finding(
      "snapshot_metadado_ilegivel", "bloqueante",
      "metadata.json não desserializou para um objeto JSON.",
      list()
    ))
  } else {
    for (campo in names(schema$metadata)) {
      value <- if (metadata_ok) metadata[[campo]] else NULL
      missing <- is.null(value) ||
        length(value) == 0L ||
        all(is.na(value)) ||
        (is.character(value) && length(value) == 1L && !nzchar(trimws(value)))
      if (missing) {
        add(snapshot_quality_finding(
          "snapshot_metadado_ausente", "bloqueante",
          sprintf("Metadado obrigatório ausente: %s.", campo),
          list(campo = campo)
        ))
      }
    }
  }

  # --- player_id duplicado -----------------------------------------------
  dup_ids <- character(0)
  for (df in list(players, metrics)) {
    if ("player_id" %in% names(df)) {
      ids <- as.character(df$player_id)
      ids <- ids[!snapshot_quality_blank(ids)]
      dup_ids <- c(dup_ids, ids[duplicated(ids)])
    }
  }
  for (pid in sort(unique(dup_ids), method = "radix")) {
    add(snapshot_quality_finding(
      "snapshot_player_id_duplicado", "bloqueante",
      sprintf("player_id duplicado: %s.", pid),
      list(player_id = pid)
    ))
  }

  # --- posicao normalizada (reusada por ambiguidade e cobertura) ---------
  n_players <- nrow(players)
  norm_pos <- character(n_players)
  norm_ok <- logical(n_players)
  has_position <- "position" %in% names(players) && n_players > 0L
  if (has_position) {
    for (i in seq_len(n_players)) {
      raw_pos <- as.character(players$position[[i]])
      r <- normalize_position(raw_pos)
      if (is_domain_error(r)) {
        norm_pos[[i]] <- raw_pos
        norm_ok[[i]] <- FALSE
      } else {
        norm_pos[[i]] <- r
        norm_ok[[i]] <- TRUE
      }
    }
  }

  # --- nome ambiguo sem desambiguacao -----------------------------------
  if (n_players > 0L && all(c("normalized_name", "position") %in% names(players))) {
    ids <- snapshot_quality_id_col(players)
    nn_raw <- as.character(players$normalized_name)
    valid_row <- !snapshot_quality_blank(nn_raw)
    nn <- tolower(trimws(nn_raw))
    team <- if ("nfl_team" %in% names(players)) {
      toupper(trimws(as.character(players$nfl_team)))
    } else {
      rep(NA_character_, n_players)
    }
    team[is.na(team) | !nzchar(team)] <- "<sem-time>"
    key <- paste(nn, norm_pos, team, sep = "\r")
    for (k in unique(key[duplicated(key)])) {
      grp <- which(key == k & valid_row)
      pids <- sort(unique(ids[grp]), method = "radix")
      if (length(pids) >= 2L) {
        add(snapshot_quality_finding(
          "snapshot_nome_ambiguo", "bloqueante",
          sprintf(
            "Nome ambíguo sem desambiguação: '%s' (player_ids %s).",
            players$normalized_name[grp][1L], paste(pids, collapse = ", ")
          ),
          list(normalized_name = players$normalized_name[grp][1L], player_ids = pids)
        ))
      }
    }
  }

  # --- posicao fora do V1 ------------------------------------------------
  if (has_position) {
    ids <- snapshot_quality_id_col(players)
    for (i in seq_len(n_players)) {
      if (norm_ok[[i]] || isTRUE(snapshot_quality_blank(players$position[[i]]))) {
        next
      }
      add(snapshot_quality_finding(
        "snapshot_posicao_fora_do_v1", "bloqueante",
        sprintf(
          "Posição fora do conjunto V1 para player_id '%s': '%s'.",
          ids[[i]], norm_pos[[i]]
        ),
        list(player_id = ids[[i]], raw = norm_pos[[i]])
      ))
    }
  }
  present_pos <- norm_pos[norm_ok]

  # --- ADP invalido quando informado ------------------------------------
  # ponytail: sem limite superior de ADP -- um ADP alto e um jogador que sai
  # tarde / nao draftado, dado legitimo. So <= 0 ou nao-finito bloqueia.
  if ("adp" %in% names(metrics) && nrow(metrics) > 0L) {
    ids <- snapshot_quality_id_col(metrics)
    raw_adp <- metrics$adp
    num <- suppressWarnings(as.numeric(as.character(raw_adp)))
    present <- !snapshot_quality_blank(raw_adp) | is.nan(num)
    bad <- present & (!is.finite(num) | num <= 0)
    for (i in which(bad)) {
      add(snapshot_quality_finding(
        "snapshot_adp_invalido", "bloqueante",
        sprintf("ADP inválido para player_id '%s': %s.", ids[[i]], as.character(raw_adp[[i]])),
        list(player_id = ids[[i]], valor = as.character(raw_adp[[i]]))
      ))
    }
  }

  # --- scoring incompativel -------------------------------------------
  if (metadata_ok && is.null(scoring_unusable)) {
    sres <- tryCatch(
      verify_scoring_hash(active_scoring_parsed, metadata),
      error = function(e) {
        # erro inesperado (scoring passou o guard de tipo mas quebrou
        # `canonical_json`): `code` distinto de um mismatch real.
        domain_error("snapshot_scoring_erro", conditionMessage(e), list())
      }
    )
    if (is_domain_error(sres)) {
      add(snapshot_quality_finding(
        sres$code, "bloqueante", sres$message,
        if (is.list(sres$details)) sres$details else list()
      ))
    }
  }

  # --- qa-report -----------------------------------------------------
  qa <- deserialized$qa_report
  if (is.null(qa) || !is.list(qa) || is.data.frame(qa) || is.null(qa$findings)) {
    add(snapshot_quality_finding(
      "qa_report_ausente", "bloqueante",
      "qa-report ausente ou não desserializou para um objeto com findings.",
      list()
    ))
  } else {
    for (entry in snapshot_quality_qa_entries(qa$findings)) {
      if (!is.list(entry)) {
        next
      }
      sev <- snapshot_quality_scalar_chr(entry$severity, "aviso")
      qa_code <- snapshot_quality_scalar_chr(entry$code, "qa_report_sem_code")
      msg <- snapshot_quality_scalar_chr(entry$message, "Achado do qa-report sem mensagem.")
      if (identical(sev, "bloqueante")) {
        add(snapshot_quality_finding(
          "qa_report_bloqueante", "bloqueante", msg, list(qa_code = qa_code)
        ))
      } else {
        add(snapshot_quality_finding(
          "qa_report_aviso", "aviso", msg, list(qa_code = qa_code, severity = sev)
        ))
      }
    }
  }

  # --- opcionais ausentes (aviso) ------------------------------------
  optional_tables <- list(players = schema$players, metrics = schema$metrics)
  illegible_by_table <- c(players = players_illegible, metrics = metrics_illegible)
  for (tbl_name in names(optional_tables)) {
    if (isTRUE(illegible_by_table[[tbl_name]])) {
      next
    }
    spec <- optional_tables[[tbl_name]]
    df <- if (identical(tbl_name, "players")) players else metrics
    for (campo in names(spec)) {
      if (isTRUE(spec[[campo]]$required)) {
        next
      }
      if (!campo %in% names(df) || all(snapshot_quality_blank(df[[campo]]))) {
        add(snapshot_quality_finding(
          "snapshot_opcional_ausente", "aviso",
          sprintf("Campo opcional ausente no snapshot: %s.", campo),
          list(campo = campo)
        ))
      }
    }
  }

  # --- cobertura anomala (aviso) ------------------------------------
  # players ilegivel ja e um bloqueante; nao inundar com 6 avisos de cobertura.
  if (!players_illegible) {
    for (pos in positions_v1) {
      if (!pos %in% present_pos) {
        add(snapshot_quality_finding(
          "snapshot_cobertura_anomala", "aviso",
          sprintf("Nenhum jogador na posição %s.", pos),
          list(posicao = pos)
        ))
      }
    }
  }

  snapshot_quality_sort(acc$items)
}
