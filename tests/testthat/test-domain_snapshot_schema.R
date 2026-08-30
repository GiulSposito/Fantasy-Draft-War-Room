# Forma e completude de snapshot_schema() (spec Story 1.2).

test_that("schema tem as tres secoes do bundle", {
  schema <- snapshot_schema()
  expect_identical(names(schema), c("players", "metrics", "metadata"))
})

test_that("todo campo declara type e required", {
  for (section in snapshot_schema()) {
    for (field in section) {
      expect_true(is.character(field$type) && length(field$type) == 1L)
      expect_true(is.logical(field$required) && length(field$required) == 1L)
      expect_true(field$type %in% c("character", "numeric", "integer", "logical"))
    }
  }
})

test_that("campos minimos do contrato estao no schema como obrigatorios", {
  schema <- snapshot_schema()
  required <- function(section) {
    names(Filter(function(f) isTRUE(f$required), section))
  }
  expect_setequal(
    required(schema$players),
    c("player_id", "display_name", "normalized_name", "position")
  )
  expect_setequal(
    required(schema$metrics),
    c("player_id", "points", "vor", "tier", "tier_cliff")
  )
  expect_setequal(
    required(schema$metadata),
    c(
      "snapshot_id", "season", "generated_at", "pipeline_version",
      "source_list", "scoring_hash", "content_hash", "qa_summary",
      "schema_version"
    )
  )
})

test_that("opcionais do contrato estao no schema como nao-obrigatorios", {
  schema <- snapshot_schema()
  optional <- function(section) {
    names(Filter(function(f) isFALSE(f$required), section))
  }
  expect_setequal(optional(schema$players), c("nfl_team", "bye_week"))
  expect_setequal(
    optional(schema$metrics),
    c("floor", "ceiling", "sd_points", "ecr", "adp", "adp_sd", "uncertainty")
  )
})
