---
title: 'Story 1.4 — CLI `scripts/prepare_snapshot.R`'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: '9c89aa1a325db8214a116f62387e568f4e868735'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O runtime live nunca pode adquirir nem enriquecer dados (AD-2), mas ainda não existe forma de produzir um snapshot bundle. Sem um CLI de preparo, não há input para as Stories 1.5/1.7 nem para o Epic 2.

**Approach:** `scripts/prepare_snapshot.R` é o único componente com rede: coleta projeções via `ffanalytics` (commit fixado) aplicando o YAML de scoring, ou aceita um CSV manual no modo fallback, e emite um bundle canônico (`players.csv`, `metrics.csv`, `metadata.json`, `qa-report.json`, `scoring.yml`) com hashes. O mapeamento cru→canônico é domínio puro; um caso de uso orquestra domínio + ports; adapters fazem I/O e a chamada ao `ffanalytics`.

## Boundaries & Constraints

**Always:**
- `scripts/prepare_snapshot.R` é o único ponto que usa rede ou `ffanalytics` (AD-2). Domínio puro e runtime nunca importam `ffanalytics`.
- `ffanalytics` entra em `Suggests` + `Remotes` no commit `1955daa05efb4a1f38c9a4dee609c5c4eaf84b4d`; `renv.lock` registra o pacote e o fecho. `devtools::test()` num lib sem `ffanalytics` continua passando — a coleta é a única parte que o exige e não é testada contra a rede.
- O mapeamento cru→canônico (`R/domain_snapshot_build.R`) é domínio puro: sem I/O, sem clock, sem rede; recebe clock e config como argumentos; retorna valor ou `domain_error`.
- O caso de uso (`R/application_prepare_snapshot.R`) é o único que orquestra comandos de domínio + ports; os adapters fazem toda a I/O.
- Cada execução gera `snapshot_id` novo (`snap-<season>-<timestamp UTC compacto>`); se o diretório do bundle já existir, aborta sem sobrescrever.
- Falha em qualquer etapa → exit code ≠ 0, mensagem PT-BR acionável em stderr, e nenhum bundle parcial em disco (montar em diretório temporário e mover só no sucesso).
- Antes de reportar sucesso, o bundle emitido é relido do disco e passa por `parse_snapshot_bundle()`, `verify_content_hash()` e `verify_scoring_hash()`.
- `scoring_hash` = `scoring_config_hash(yaml parseado)`; `content_hash` = `snapshot_content_hash()`; `scoring.yml` gravado é cópia byte-a-byte do YAML de scoring usado.
- `vor_baseline` e limiares de tier vêm de `config/snapshot_pipeline.yml` versionado (padrão 12 times), passados explicitamente ao `ffanalytics`; `pipeline_version` no `metadata.json` deve ser incrementado quando esse arquivo mudar.

**Ask First:**
- Se o commit fixado de `ffanalytics` não instalar no R 4.6.1 (deps `httr2`/`rrapply`/`readxl`/`readr`) — parar antes de usar outra ref.
- Se `projections_table()` do commit fixado não expuser as colunas `points`/`points_vor`/`tier`/`dropoff`/`pos_rank` (contrato mudou) — parar antes de recalcular VOR/tier no domínio.

**Never:**
- Não implementar a classificação bloqueante/aviso do `qa-report.json` (Story 1.5) — 1.4 emite um `qa-report.json` estruturalmente válido (`schema_version`, `generated_at`, `findings: []`, `coverage` por posição).
- Não persistir em SQLite nem event store (Epic 2); não aplicar o gate de `scoring_hash` no start (Story 2.6); não adicionar superfície Shiny (Story 1.7).
- Não mudar as assinaturas de `parse_snapshot_bundle()`, `snapshot_schema()`, `snapshot_content_hash()`, `scoring_config_hash()` nem o schema de `metadata.json`.
- Não usar o `authToken` de `config/config.yml` — `ffanalytics` não precisa dele; importação de liga NFL é Epic 2.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Coleta ffanalytics OK | `--scoring <yaml> --season 2025`, rede disponível | bundle de 5 arquivos em `<root>/<snapshot_id>/`; `points/vor/tier/tier_cliff` preenchidos; parser + verify de hash passam | N/A |
| Fallback CSV | `--from-csv <path> --metadata <json>` com colunas obrigatórias | mesmo formato canônico; `source_list = ["manual-csv"]`; não exige `ffanalytics` | N/A |
| Duas execuções | rodar 2× | dois `snapshot_id` distintos, diretórios distintos, nenhum tocado | dir do id já existe → `bundle_ja_existe`, sem sobrescrever |
| Falha de coleta | `scrape_data`/`projections_table` lança ou volta vazio | exit ≠ 0, mensagem cita a causa; nenhum bundle parcial | `domain_error("coleta_ffanalytics_falhou")` |
| `ffanalytics` ausente | pacote não instalado, modo coleta | exit ≠ 0, mensagem manda instalar via `renv`; nenhum diretório criado | `domain_error("ffanalytics_ausente")` |
| Scoring YAML inválido | `--scoring` → YAML malformado ou não-mapa | exit ≠ 0, sem bundle | `domain_error("bundle_formato_invalido")` (adapter) |
| CSV fallback sem campo obrigatório | CSV sem `tier_cliff` | exit ≠ 0, sem bundle | `snapshot_coluna_ausente` (parser) |
| Posição fora do V1 na coleta | fonte traz `pos = "FB"` | exit ≠ 0, nenhum bundle parcial | `snapshot_posicao_invalida` |
| Saída não gravável | `--out` sem permissão de escrita | exit ≠ 0, mensagem acionável, sem bundle | `domain_error("bundle_saida_nao_gravavel")` |
| `tier_cliff` derivado | linhas com `tier`/`pos_rank` por posição | último jogador de cada `tier` por posição → `tier_cliff = TRUE` | N/A |

</frozen-after-approval>

## Code Map

- `R/domain_snapshot.R` — `parse_snapshot_bundle()`, `normalize_position()` (Story 1.2). Reusar; não alterar.
- `R/domain_snapshot_schema.R` — `snapshot_schema()` (colunas/tipos/obrigatoriedade). Fonte da verdade do mapeamento.
- `R/domain_snapshot_hash.R` — `canonical_json()`, `snapshot_content_hash()`, `scoring_config_hash()`, `verify_content_hash()`, `verify_scoring_hash()`, constante `snapshot_bundle_files` (Story 1.3). Reusar.
- `R/domain_errors.R` — `domain_error()`, `is_domain_error()`. Reusar; novos `code`s: `coleta_ffanalytics_falhou`, `ffanalytics_ausente`, `bundle_saida_nao_gravavel`, `bundle_ja_existe`.
- `R/adapter_files_snapshot.R` — `read_snapshot_bundle()`, `read_bundle_files_raw()`, `read_scoring_config()`, `read_bundle_csv()`. Estender com leitura de CSV manual + escrita do bundle.
- `R/domain_snapshot_build.R` — **novo**, domínio puro.
- `R/adapter_ffanalytics.R` — **novo**, shell de rede; único importador de `ffanalytics`.
- `R/application_prepare_snapshot.R` — **novo**, primeiro caso de uso do pacote.
- `scripts/prepare_snapshot.R` — **novo**, CLI (hoje só `.gitkeep`).
- `config/score_settings.yml` — já no formato do objeto `scoring` do `ffanalytics` (`pass/rush/rec/misc/kick/ret/idp/dst/pts_bracket`); default de `--scoring`.
- `config/snapshot_pipeline.yml` — **novo**, versionado: `vor_baseline`, `tier_thresholds`, `pipeline_version`.
- `tests/testthat/fixtures/regenerate-snapshot-valid.R` — mostra a dança `content_hash` (grava metadata sem o campo → hash → reescreve). Reusar o padrão em `write_snapshot_bundle()`.
- `tests/testthat/fixtures/snapshot-valid/` — formato-alvo de referência dos 5 arquivos.
- `DESCRIPTION` / `NAMESPACE` / `renv.lock` — deps + exports.
- `inst/schema/snapshot-bundle-v1.md` — doc de referência; adicionar seção de geração pelo CLI.
- Arquitetura: AD-2 (fronteira de rede), AD-3 (bundle), convenções (`snake_case`, hash hex minúsculo, timestamp UTC ISO-8601).

## Tasks & Acceptance

**Execution:**
- [ ] `DESCRIPTION` — `ffanalytics` em `Suggests`; novo campo `Remotes: FantasyFootballAnalytics/ffanalytics@1955daa05efb4a1f38c9a4dee609c5c4eaf84b4d`.
- [ ] `renv.lock` — instalar `ffanalytics` no commit fixado e `renv::snapshot()`; `renv::status()` consistente com o fecho (`httr2`, `rrapply`, `readxl`, `readr`, `data.table`, `tidyr`, …).
- [ ] `config/snapshot_pipeline.yml` — versionado: `vor_baseline` (`QB:13, RB:35, WR:36, TE:13, K:8, DST:3`), `tier_thresholds` por posição, `pipeline_version`; comentário com a racional 12 times.
- [ ] `R/domain_snapshot_build.R` — **puro**, funções: `snapshot_normalized_name()` (minúsculo, sem acento, locale-independente); `derive_tier_cliff(position, pos_rank, tier)`; `new_snapshot_id(season, clock_value)`; `build_snapshot_tables(raw_df)` → `list(players, metrics)` conforme `snapshot_schema()` (normaliza posição, deriva `normalized_name`/`tier_cliff`, coage tipos, opcionais → `NA` tipado, erros → `domain_error`); `build_snapshot_metadata(...)` (sem `content_hash`); `build_qa_report(players, generated_at)`.
- [ ] `R/adapter_ffanalytics.R` — `collect_ffanalytics_projections(scoring_parsed, pipeline_config, season, sources)`: guarda `requireNamespace("ffanalytics")`; roda o fluxo `scrape_data`→`projections_table`→`add_*` (ver Design Notes); achata e renomeia as colunas para o shape cru comum; erro → `domain_error`. Único importador de `ffanalytics`; não testado contra a rede.
- [ ] `R/adapter_files_snapshot.R` — estender: `read_manual_projection_csv()` (shape cru comum); `read_metadata_overrides()`; `resolve_snapshot_root(out_override)` (`tools::R_user_dir(...)/snapshots` ou `--out`); `write_snapshot_bundle(...)` — grava os 5 arquivos num tmp dir, calcula `content_hash` (dança do `regenerate-snapshot-valid.R`), `file.rename` no sucesso; recusa diretório existente / root não gravável.
- [ ] `R/application_prepare_snapshot.R` — `prepare_snapshot(collect_fn, write_fn, clock, scoring_raw_text, scoring_parsed, pipeline_config, season, source_list)`: orquestra domínio + ports; após `write_fn`, relê o bundle e roda `parse_snapshot_bundle` + `verify_content_hash` + `verify_scoring_hash`; `domain_error` aborta e remove o diretório.
- [ ] `scripts/prepare_snapshot.R` — CLI (`pkgload::load_all`): args `--scoring` (default `config/score_settings.yml`), `--pipeline-config`, `--season`, `--sources`, `--from-csv`, `--metadata`, `--out`; monta `collect_fn`; injeta `clock = function() Sys.time()`; `domain_error` → mensagem + `quit(status = 1L)`; sucesso → imprime `bundle_dir` e `snapshot_id`, `quit(status = 0L)`.
- [ ] `NAMESPACE` — `#' @export` + `devtools::document()` nas funções públicas novas.
- [ ] `inst/schema/snapshot-bundle-v1.md` — seção "Geração pelo CLI": fluxo `ffanalytics`, mapeamento de colunas, config de pipeline versionada, `tier_cliff` = último de cada tier por posição, modo fallback CSV, `snapshot_id`.
- [ ] `tests/testthat/fixtures/` — `manual-projection.csv` (colunas obrigatórias) e `ffanalytics-flat.csv` (`data.frame` cru simulando a saída achatada do adapter, para testar domínio + orquestração sem rede).
- [ ] `tests/testthat/test-domain_snapshot_build.R` — cobre a Matrix no nível de domínio; locale forçado.
- [ ] `tests/testthat/test-application_prepare_snapshot.R` — orquestração com `collect_fn`/`write_fn` fakes e clock fixo (sucesso, falha de coleta, duas execuções, posição inválida).
- [ ] `tests/testthat/test-adapter_files_snapshot.R` — estender: `read_manual_projection_csv`; `write_snapshot_bundle` round-trip; recusa de diretório existente / saída não gravável.

**Acceptance Criteria:**
- Given um CSV manual com as colunas obrigatórias e `--metadata`, when `Rscript scripts/prepare_snapshot.R --from-csv … --metadata … --out <tmp>`, then é gravado um diretório com `players.csv`, `metrics.csv`, `metadata.json`, `qa-report.json`, `scoring.yml` e `parse_snapshot_bundle()` + `verify_content_hash()` + `verify_scoring_hash()` passam — sem `ffanalytics` instalado.
- Given a coleta `ffanalytics` com o commit fixado (smoke manual), when `--scoring config/score_settings.yml --season 2025`, then o bundle sai com `points`, `vor`, `tier` e `tier_cliff` preenchidos e o mesmo conjunto de verificações passa.
- Given duas execuções, when o script roda, then cada bundle recebe um `snapshot_id` único e nenhum diretório anterior é modificado.
- Given falha de coleta, scoring inválido ou `ffanalytics` ausente, when o script roda, then ele termina com exit code ≠ 0 e mensagem acionável, sem emitir bundle nem diretório parcial.
- Given `R/domain_snapshot_build.R`, when inspecionado, then não abre arquivos, não importa `ffanalytics`/`yaml` e não lê o clock.
- Given um clone limpo, when `renv::restore()` e `devtools::test()`, then a suíte passa sem acessar a rede, inclusive num lib onde `ffanalytics` não está instalado.

## Design Notes

- **Fluxo `ffanalytics` (commit fixado, do README):**
  ```r
  s <- scrape_data(src = sources, pos = c("QB","RB","WR","TE","K","DST"),
                   season = season, week = 0)              # week=0: VOR só sai com dados de temporada
  p <- projections_table(s, scoring_rules = scoring_parsed,
                         vor_baseline = cfg$vor_baseline,
                         tier_thresholds = cfg$tier_thresholds)
  p <- p |> add_adp() |> add_ecr() |> add_uncertainty() |> add_player_info()
  ```
  Colunas consumidas: `id, pos, points, points_vor, tier, dropoff, pos_rank, floor, ceiling, sd_pts` + `player, team, bye` + `adp, ecr, uncertainty`.
- **`config/score_settings.yml` já é o objeto `scoring`** do `ffanalytics` — passa direto como `scoring_rules`. O `scoring.yml` do bundle é cópia byte-a-byte; `scoring_config_hash(yaml parseado) == metadata$scoring_hash`.
- **`tier_cliff`:** `ffanalytics` fornece `tier` (inteiro) e `dropoff` (Δ pontos ao próximo), não um booleano. V1: `tier_cliff = TRUE` para o jogador de menor `pos_rank` antes de uma mudança de `tier` dentro da posição (o último de cada tier) — "pegue antes do degrau".
- **Escrita atômica:** monta no tmp dir, calcula `content_hash` (grava metadata sem o campo → `snapshot_content_hash()` → reescreve), relê e valida, e só então `file.rename` para `<root>/<snapshot_id>/`. Falha → remove o tmp; nada parcial.
- **Clock injetado:** `prepare_snapshot(clock = function() Sys.time())`; testes passam clock fixo → `generated_at` e `snapshot_id` determinísticos.
- **`ffanalytics` em `Suggests` + `Remotes`, não `Imports`:** runtime e `devtools::test()` não podem depender dele (AD-2). O adapter faz `requireNamespace("ffanalytics", quietly = TRUE)`; na falta → `domain_error("ffanalytics_ausente", "Instale com renv::install('FantasyFootballAnalytics/ffanalytics@1955daa0…')")`.
- **Lacuna conhecida:** `metadata.json` (schema v1) não tem campo para o hash de `config/snapshot_pipeline.yml`; a reprodutibilidade do `vor`/`tier` depende de bumpar `pipeline_version`. Adiar: pinar esse hash no metadata (schema v2).

## Verification

**Commands:**
- `Rscript -e 'renv::restore(prompt = FALSE)'` — restaura incl. `ffanalytics` e fecho, sem erro.
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings; a suíte não toca a rede.
- `R CMD INSTALL --no-docs --no-help . && Rscript -e 'lintr::lint_package()'` — sem lint.
- `Rscript -e 'renv::status()'` — consistente.
- Pureza: `grep -nE "read|file\\.|yaml|ffanalytics|Sys\\.|scrape|readRDS|url\\(" R/domain_snapshot_build.R` — só nomes de variável/comentário.
- Fallback E2E: `Rscript scripts/prepare_snapshot.R --from-csv tests/testthat/fixtures/manual-projection.csv --metadata <json> --out <tmp>` → bundle criado; `read_snapshot_bundle()` + `parse_snapshot_bundle()` ok; rodar de novo → segundo `snapshot_id`, primeiro intacto.

**Manual checks (rede):**
- Smoke `ffanalytics`: `Rscript scripts/prepare_snapshot.R --scoring config/score_settings.yml --season 2025 --sources CBS,ESPN,FantasyPros --out <tmp>` → bundle válido, `verify_content_hash()` / `verify_scoring_hash()` retornam `NULL`, `points/vor/tier/tier_cliff` sem `NA`.

## Suggested Review Order

**Ponto de entrada — intenção do design**

- Caso de uso: orquestra domínio + ports, releitura de verificação, `unlink` na falha. Comece aqui.
  [`application_prepare_snapshot.R:28`](../../R/application_prepare_snapshot.R#L28)
- A releitura relê `scoring.yml` do disco (não o objeto em memória) — evita o self-check virar tautologia.
  [`application_prepare_snapshot.R:87`](../../R/application_prepare_snapshot.R#L87)

**Domínio puro — mapeamento cru → canônico**

- Monta `players`/`metrics` na forma do `snapshot_schema()`; falha cedo só no que o parser não diagnostica bem.
  [`domain_snapshot_build.R:107`](../../R/domain_snapshot_build.R#L107)
- `tier_cliff` derivado: último `pos_rank` de cada tier por posição. Guarda de comprimento/`NA`.
  [`domain_snapshot_build.R:46`](../../R/domain_snapshot_build.R#L46)
- `normalized_name` locale-independente (`chartr` de diacríticos Latin-1 antes de `tolower`).
  [`domain_snapshot_build.R:23`](../../R/domain_snapshot_build.R#L23)
- `snapshot_id` = `snap-<season>-<AAAAMMDDTHHMMSSZ UTC>`; `stop()` em `season`/instante `NA`.
  [`domain_snapshot_build.R:79`](../../R/domain_snapshot_build.R#L79)
- `metadata` sem `content_hash` (o adapter de escrita o acrescenta); `qa-report` estruturalmente válido.
  [`domain_snapshot_build.R:229`](../../R/domain_snapshot_build.R#L229)

**Fronteira de rede — único importador de `ffanalytics`**

- `requireNamespace` → `ffanalytics_ausente`; `scrape_data → projections_table → add_player_info` no `tryCatch`; `add_adp/ecr/uncertainty` best-effort.
  [`adapter_ffanalytics.R:34`](../../R/adapter_ffanalytics.R#L34)
- Achata para a forma crua comum; guardas contra saída silenciosamente errada (`id` `NA`, sem coluna de nome, `avg_type` sem `average`, drift de contrato).
  [`adapter_ffanalytics.R:102`](../../R/adapter_ffanalytics.R#L102)

**Escrita atômica do bundle**

- Monta no tmp dir → calcula `content_hash` (dança da 1.3) → `file.rename` no sucesso; recusa destino existente / raiz não gravável; guarda a releitura do tmp.
  [`adapter_files_snapshot.R:247`](../../R/adapter_files_snapshot.R#L247)
- CSV manual + overrides de metadata: leitura crua, validação fica no domínio/parser.
  [`adapter_files_snapshot.R:164`](../../R/adapter_files_snapshot.R#L164)

**CLI**

- `run()` no `tryCatch` do topo → toda falha vira mensagem PT-BR + exit 1; despacho coleta vs `--from-csv`.
  [`prepare_snapshot.R:89`](../../scripts/prepare_snapshot.R#L89)
- Parser de args com allowlist: rejeita flag desconhecida, repetida, ou valor que parece flag.
  [`prepare_snapshot.R:38`](../../scripts/prepare_snapshot.R#L38)

**Periféricos — config, schema, deps, testes**

- Config de pipeline versionada (baseline 12 times); bump de `pipeline_version` ao alterar.
  [`snapshot_pipeline.yml:14`](../../config/snapshot_pipeline.yml#L14)
- Seção "Geração pelo CLI": fluxo, mapa de colunas, regra do `tier_cliff`, modo fallback.
  [`snapshot-bundle-v1.md:135`](../../inst/schema/snapshot-bundle-v1.md#L135)
- `ffanalytics` + `pkgload` + `callr` em Suggests; `Remotes` no commit fixado.
  [`DESCRIPTION:22`](../../DESCRIPTION#L22)
- Teste do adapter de rede (puro): `ffanalytics_flatten` + `ffanalytics_ausente`.
  [`test-adapter_ffanalytics.R:1`](../../tests/testthat/test-adapter_ffanalytics.R#L1)
- Teste do CLI via `callr::rscript`: exit codes, stderr PT-BR, dois `snapshot_id`.
  [`test-cli_prepare_snapshot.R:1`](../../tests/testthat/test-cli_prepare_snapshot.R#L1)
- Orquestração com `collect_fn`/`write_fn` fakes e clock fixo.
  [`test-application_prepare_snapshot.R:1`](../../tests/testthat/test-application_prepare_snapshot.R#L1)
- Domínio: mapeamento, `derive_tier_cliff`, coerção, pureza sob locale forçado.
  [`test-domain_snapshot_build.R:1`](../../tests/testthat/test-domain_snapshot_build.R#L1)
