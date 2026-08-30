# Hash canonico do manifesto do bundle (spec Story 1.3 + review round 1).
# Requisito central: hash identico entre maquinas -> testes de locale/encoding.

valid_dir <- test_path("fixtures/snapshot-valid")

raw_and_meta <- function(dir) {
  list(
    raw = read_bundle_files_raw(dir),
    meta = read_snapshot_bundle(dir)$metadata
  )
}

copy_fixture <- function() {
  tmp <- withr::local_tempdir(.local_envir = parent.frame())
  file.copy(list.files(valid_dir, full.names = TRUE), tmp)
  tmp
}

# --- canonical_json: forma e determinismo ---------------------------------

test_that("canonical_json: golden de um input aninhado conhecido", {
  expect_identical(
    canonical_json(list(b = list(y = 2L, x = 1.5), a = c(3L, 1L, 2L), z = NULL)),
    '{"a":[3,1,2],"b":{"x":1.5000000000,"y":2},"z":null}'
  )
})

test_that("canonical_json ordena chaves em ordem de byte (radix), nao locale", {
  # ordem de byte: "B"(66) < "a"(97); ordem de colacao pt-BR poria "a" antes.
  expect_identical(canonical_json(list(a = 1L, B = 2L)), '{"B":2,"a":1}')
})

test_that("canonical_json: real com 10 casas, valor inteiro sem decimal", {
  expect_identical(canonical_json(0.1), "0.1000000000")
  expect_identical(canonical_json(1.5), "1.5000000000")
  expect_identical(canonical_json(-2L), "-2")
})

test_that("canonical_json: inteiro e double de valor inteiro sao unificados", {
  expect_identical(canonical_json(4L), "4")
  expect_identical(canonical_json(4.0), "4")
  expect_identical(canonical_json(1e6), "1000000")
  expect_identical(canonical_json(-2L), canonical_json(-2.0))
})

test_that("canonical_json: marca decimal e sempre '.', mesmo com OutDec ','", {
  withr::local_options(OutDec = ",")
  expect_identical(canonical_json(0.04), "0.0400000000")
  expect_identical(canonical_json(list(w = 0.04, x = 1.5)), '{"w":0.0400000000,"x":1.5000000000}')
})

test_that("canonical_json: NULL e NA viram null explicito", {
  expect_identical(canonical_json(list(x = NULL)), '{"x":null}')
  expect_identical(canonical_json(NA), "null")
  expect_identical(canonical_json(NA_character_), "null")
})

test_that("canonical_json: nao-finitos sao erro, NA nao", {
  expect_error(canonical_json(NaN), "NaN")
  expect_error(canonical_json(Inf), "nao-finito")
  expect_error(canonical_json(-Inf), "nao-finito")
  expect_identical(canonical_json(NA_real_), "null")
})

test_that("canonical_json: contrato de entrada", {
  expect_error(canonical_json(list(a = 1L, 2L)), "nomes")
  expect_error(canonical_json(list(a = 1L, a = 2L)), "duplicados")
  expect_error(canonical_json(c(a = 1L, b = 2L)), "ambiguo")
  expect_identical(canonical_json(list()), "[]")
  expect_identical(canonical_json(setNames(list(), character(0))), "{}")
})

test_that("canonical_json: logico, string e escapes de controle", {
  expect_identical(canonical_json(TRUE), "true")
  expect_identical(canonical_json(FALSE), "false")
  expect_identical(canonical_json(""), '""')
  expect_identical(canonical_json("a\"b\\c"), '"a\\"b\\\\c"')
  expect_identical(canonical_json("\u0001\u001f"), '"\\u0001\\u001f"')
  expect_identical(canonical_json("x\ty"), '"x\\ty"')
})

test_that("canonical_json: array de vetor atomico e lista sem nomes", {
  expect_identical(canonical_json(c(1L, 2L, 3L)), "[1,2,3]")
  expect_identical(canonical_json(list(1L, "a", TRUE)), '[1,"a",true]')
})

# --- sha256_hex: encoding ------------------------------------------------

test_that("sha256_hex normaliza para UTF-8 antes de hashear", {
  utf8 <- enc2utf8("café época")
  latin1 <- iconv(utf8, "UTF-8", "latin1")
  expect_identical(Encoding(latin1), "latin1")
  expect_identical(sha256_hex(utf8), sha256_hex(latin1))
})

# --- snapshot_content_hash ---------------------------------------------------

test_that("snapshot_content_hash e SHA-256 hex minusculo e bate com o golden", {
  rm <- raw_and_meta(valid_dir)
  h <- snapshot_content_hash(rm$raw, rm$meta)
  expect_match(h, "^[0-9a-f]{64}$")
  expect_identical(h, rm$meta$content_hash)
})

test_that("determinismo: CRLF e CR sozinho produzem o mesmo hash que LF", {
  rm <- raw_and_meta(valid_dir)
  h_lf <- snapshot_content_hash(rm$raw, rm$meta)
  crlf <- lapply(rm$raw, function(x) gsub("\n", "\r\n", x, fixed = TRUE))
  cr <- lapply(rm$raw, function(x) gsub("\n", "\r", x, fixed = TRUE))
  expect_identical(snapshot_content_hash(crlf, rm$meta), h_lf)
  expect_identical(snapshot_content_hash(cr, rm$meta), h_lf)
})

test_that("determinismo: hash estavel sob OutDec ',' e LC_COLLATE 'C'", {
  rm <- raw_and_meta(valid_dir)
  base <- snapshot_content_hash(rm$raw, rm$meta)
  withr::with_options(list(OutDec = ","), {
    withr::with_locale(c(LC_COLLATE = "C"), {
      expect_identical(snapshot_content_hash(rm$raw, rm$meta), base)
      scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
      expect_identical(scoring_config_hash(scoring), rm$meta$scoring_hash)
    })
  })
})

test_that("determinismo: CRLF e CR reais lidos do disco produzem o mesmo hash", {
  files <- list.files(valid_dir)
  src <- lapply(files, function(f) {
    p <- file.path(valid_dir, f)
    rawToChar(readBin(p, "raw", n = file.size(p)))
  })
  names(src) <- files

  # metadata parseado do proprio raw -> nao aciona read.csv (e seus warnings de
  # "incomplete final line" sob quebras \r).
  hash_with_newline <- function(nl) {
    d <- withr::local_tempdir()
    for (f in files) {
      con <- file(file.path(d, f), open = "wb")
      writeBin(charToRaw(gsub("\n", nl, src[[f]], fixed = TRUE)), con)
      close(con)
    }
    raw <- read_bundle_files_raw(d)
    snapshot_content_hash(raw, jsonlite::fromJSON(raw[["metadata.json"]], simplifyVector = TRUE))
  }

  lf <- hash_with_newline("\n")
  expect_identical(hash_with_newline("\r\n"), lf)
  expect_identical(hash_with_newline("\r"), lf)
  expect_identical(lf, jsonlite::fromJSON(file.path(valid_dir, "metadata.json"))$content_hash)
})

test_that("qualquer byte alterado em players/metrics/qa muda o hash", {
  rm <- raw_and_meta(valid_dir)
  base <- snapshot_content_hash(rm$raw, rm$meta)
  for (arquivo in c("players.csv", "metrics.csv", "qa-report.json")) {
    mutated <- rm$raw
    mutated[[arquivo]] <- paste0(mutated[[arquivo]], " ")
    expect_false(identical(snapshot_content_hash(mutated, rm$meta), base))
  }
})

test_that("campo de conteudo alterado em metadata (inclusive scoring_hash) muda o hash", {
  rm <- raw_and_meta(valid_dir)
  base <- snapshot_content_hash(rm$raw, rm$meta)
  m1 <- rm$meta
  m1$pipeline_version <- "9.9.9"
  expect_false(identical(snapshot_content_hash(rm$raw, m1), base))
  m2 <- rm$meta
  m2$scoring_hash <- strrep("0", 64L)
  expect_false(identical(snapshot_content_hash(rm$raw, m2), base))
})

test_that("mudar apenas metadata$content_hash nao muda o hash", {
  rm <- raw_and_meta(valid_dir)
  base <- snapshot_content_hash(rm$raw, rm$meta)
  m <- rm$meta
  m$content_hash <- strrep("a", 64L)
  expect_identical(snapshot_content_hash(rm$raw, m), base)
})

test_that("reformatar metadata.json em disco nao muda o content_hash", {
  tmp <- copy_fixture()
  meta <- jsonlite::fromJSON(file.path(tmp, "metadata.json"), simplifyVector = TRUE)
  meta <- meta[rev(seq_along(meta))] # reordena as chaves em disco
  writeLines(
    jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = 8),
    file.path(tmp, "metadata.json")
  )
  got <- snapshot_content_hash(read_bundle_files_raw(tmp), read_snapshot_bundle(tmp)$metadata)
  expect_identical(got, jsonlite::fromJSON(file.path(valid_dir, "metadata.json"))$content_hash)
})

test_that("determinismo: conteudo acentuado (UTF-8) e estavel entre leituras", {
  tmp <- copy_fixture()
  players <- readLines(file.path(tmp, "players.csv"), warn = FALSE)
  players[2] <- sub("Josh Allen", "José Allén", players[2], fixed = TRUE)
  con <- file(file.path(tmp, "players.csv"), open = "wb", encoding = "UTF-8")
  writeBin(charToRaw(paste0(paste(players, collapse = "\n"), "\n")), con)
  close(con)

  h1 <- snapshot_content_hash(read_bundle_files_raw(tmp), read_snapshot_bundle(tmp)$metadata)
  h2 <- snapshot_content_hash(read_bundle_files_raw(tmp), read_snapshot_bundle(tmp)$metadata)
  expect_match(h1, "^[0-9a-f]{64}$")
  expect_identical(h1, h2)
})

test_that("snapshot_content_hash exige exatamente os 4 arquivos", {
  rm <- raw_and_meta(valid_dir)
  expect_error(snapshot_content_hash(rm$raw[1:3], rm$meta))
})

test_that("snapshot_content_hash: domain_error em qualquer argumento passa direto", {
  rm <- raw_and_meta(valid_dir)
  err <- domain_error("bundle_arquivo_ausente", "x")
  expect_identical(snapshot_content_hash(err, rm$meta), err)
  expect_identical(snapshot_content_hash(rm$raw, err), err)
})

# --- verify_content_hash ---------------------------------------------------

test_that("verify_content_hash: NULL no match, domain_error na divergencia", {
  rm <- raw_and_meta(valid_dir)
  expect_null(verify_content_hash(rm$raw, rm$meta))

  m <- rm$meta
  m$content_hash <- strrep("0", 64L)
  err <- verify_content_hash(rm$raw, m)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_content_incompativel")
  expect_identical(err$details$esperado, strrep("0", 64L))
  expect_match(err$details$encontrado, "^[0-9a-f]{64}$")
})

test_that("verify_content_hash: content_hash ausente -> esperado NA, sem erro de recycling", {
  rm <- raw_and_meta(valid_dir)
  m <- rm$meta
  m$content_hash <- NULL
  err <- verify_content_hash(rm$raw, m)
  expect_true(is_domain_error(err))
  expect_true(is.na(err$details$esperado))
})

test_that("verify_content_hash: domain_error em argumento passa direto", {
  err <- domain_error("bundle_arquivo_ausente", "x")
  expect_identical(verify_content_hash(err, list()), err)
})

# --- scoring_config_hash / verify_scoring_hash ---------------------------

test_that("scoring_config_hash e SHA-256 hex minusculo e deterministico", {
  scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
  h <- scoring_config_hash(scoring)
  expect_match(h, "^[0-9a-f]{64}$")
  expect_identical(scoring_config_hash(scoring), h)
})

test_that("scoring_config_hash independe da ordem de chaves e da inferencia de tipo", {
  scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
  shuffled <- scoring[rev(seq_along(scoring))]
  shuffled$passing <- shuffled$passing[rev(seq_along(shuffled$passing))]
  expect_identical(scoring_config_hash(shuffled), scoring_config_hash(scoring))

  # 4 (int) vs 4.0 (double) devem hashear igual
  a <- list(x = 4L)
  b <- list(x = 4.0)
  expect_identical(scoring_config_hash(a), scoring_config_hash(b))
})

test_that("scoring_config_hash: domain_error passa direto", {
  err <- domain_error("bundle_formato_invalido", "x")
  expect_identical(scoring_config_hash(err), err)
})

test_that("verify_scoring_hash: NULL quando bate com metadata$scoring_hash", {
  scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
  meta <- read_snapshot_bundle(valid_dir)$metadata
  expect_null(verify_scoring_hash(scoring, meta))
})

test_that("verify_scoring_hash: domain_error na divergencia com esperado/encontrado", {
  scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
  meta <- read_snapshot_bundle(valid_dir)$metadata
  meta$scoring_hash <- strrep("0", 64L)
  err <- verify_scoring_hash(scoring, meta)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "snapshot_scoring_incompativel")
  expect_identical(err$details$esperado, strrep("0", 64L))
  expect_match(err$details$encontrado, "^[0-9a-f]{64}$")
})

test_that("verify_scoring_hash: scoring_hash ausente -> esperado NA, sem recycling", {
  scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
  meta <- read_snapshot_bundle(valid_dir)$metadata
  meta$scoring_hash <- NULL
  err <- verify_scoring_hash(scoring, meta)
  expect_true(is_domain_error(err))
  expect_true(is.na(err$details$esperado))
})

test_that("verify_scoring_hash: domain_error em argumento passa direto", {
  err <- domain_error("bundle_formato_invalido", "x")
  expect_identical(verify_scoring_hash(err, list()), err)
  scoring <- read_scoring_config(file.path(valid_dir, "scoring.yml"))
  expect_identical(verify_scoring_hash(scoring, err), err)
})

# --- adapter (I/O + parse do YAML) -------------------------------------

test_that("read_scoring_config: arquivo ausente vira bundle_arquivo_ausente", {
  err <- read_scoring_config(file.path(valid_dir, "nao-existe.yml"))
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_arquivo_ausente")
  expect_identical(err$details$arquivo, "nao-existe.yml")
})

test_that("read_scoring_config: YAML malformado vira bundle_formato_invalido", {
  tmp <- copy_fixture()
  writeLines("a: [1, 2\n  b: :", file.path(tmp, "scoring.yml"))
  err <- read_scoring_config(file.path(tmp, "scoring.yml"))
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_formato_invalido")
})

test_that("read_scoring_config: YAML que nao e um mapa vira bundle_formato_invalido", {
  tmp <- copy_fixture()
  writeLines("- a\n- b\n", file.path(tmp, "scoring.yml"))
  err <- read_scoring_config(file.path(tmp, "scoring.yml"))
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_formato_invalido")
})

test_that("read_bundle_files_raw: arquivo ausente / diretorio vira bundle_arquivo_ausente", {
  tmp <- copy_fixture()
  file.remove(file.path(tmp, "metrics.csv"))
  err <- read_bundle_files_raw(tmp)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_arquivo_ausente")
  expect_identical(err$details$arquivo, "metrics.csv")

  tmp2 <- copy_fixture()
  file.remove(file.path(tmp2, "players.csv"))
  dir.create(file.path(tmp2, "players.csv"))
  err2 <- read_bundle_files_raw(tmp2)
  expect_true(is_domain_error(err2))
  expect_identical(err2$code, "bundle_arquivo_ausente")
})

test_that("read_bundle_files_raw: bytes NUL viram bundle_formato_invalido", {
  tmp <- copy_fixture()
  con <- file(file.path(tmp, "qa-report.json"), open = "wb")
  writeBin(as.raw(c(0x7b, 0x00, 0x7d)), con)
  close(con)
  err <- read_bundle_files_raw(tmp)
  expect_true(is_domain_error(err))
  expect_identical(err$code, "bundle_formato_invalido")
})

# --- pureza do dominio -------------------------------------------------

test_that("R/domain_snapshot_hash.R nao faz I/O nem importa yaml", {
  src <- readLines(test_path("..", "..", "R", "domain_snapshot_hash.R"))
  code <- src[!grepl("^\\s*#", src) & !grepl("^#'", src)]
  expect_false(any(grepl(
    "readLines|read\\.csv|read_yaml|yaml::|readBin|readChar|jsonlite|file\\(",
    code
  )))
})
