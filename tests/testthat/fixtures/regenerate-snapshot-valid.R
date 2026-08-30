#!/usr/bin/env Rscript
# Recompute os hashes golden do fixture `snapshot-valid/` a partir dos
# arquivos do bundle e reescreve `metadata.json`. Torna os valores
# `scoring_hash` / `content_hash` do fixture reproduziveis.
#
# Uso (da raiz do pacote):
#   Rscript tests/testthat/fixtures/regenerate-snapshot-valid.R

suppressMessages(pkgload::load_all(quiet = TRUE))

dir <- file.path("tests", "testthat", "fixtures", "snapshot-valid")

scoring <- read_scoring_config(file.path(dir, "scoring.yml"))
stopifnot(!is_domain_error(scoring))
scoring_hash <- scoring_config_hash(scoring)

meta <- jsonlite::fromJSON(file.path(dir, "metadata.json"), simplifyVector = TRUE)
meta$scoring_hash <- scoring_hash
meta$content_hash <- "0"  # placeholder; excluido do manifesto
jsonlite::write_json(
  meta, file.path(dir, "metadata.json"),
  auto_unbox = TRUE, pretty = TRUE
)

raw <- read_bundle_files_raw(dir)
stopifnot(!is_domain_error(raw))
meta_parsed <- read_snapshot_bundle(dir)$metadata
content_hash <- snapshot_content_hash(raw, meta_parsed)

meta$content_hash <- content_hash
jsonlite::write_json(
  meta, file.path(dir, "metadata.json"),
  auto_unbox = TRUE, pretty = TRUE
)

cat("scoring_hash:", scoring_hash, "\n")
cat("content_hash:", content_hash, "\n")
