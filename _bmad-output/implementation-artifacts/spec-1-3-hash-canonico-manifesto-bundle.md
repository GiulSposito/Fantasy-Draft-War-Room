---
title: 'Story 1.3 — Hash canônico do manifesto do bundle'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'f599ee03d98b197e9c528d563f06e5ef02424d38'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Um snapshot precisa de uma identidade de conteúdo estável para a sessão fixá-lo (Epic 2) e para toda recomendação/export ser auditável. Sem um algoritmo de hash único e determinístico, duas máquinas (ou o CLI da 1.4 e o runtime) produzem identidades diferentes para o mesmo bundle.

**Approach:** Funções puras de domínio (`R/domain_snapshot_hash.R`): um serializador JSON canônico (contrato AD-12, reusado depois no state hash), `snapshot_content_hash()` (SHA-256 sobre um manifesto canônico dos 4 arquivos) e `scoring_config_hash()` (SHA-256 sobre a forma canônica do YAML de scoring). O adapter lê os bytes crus e parseia o YAML; o domínio normaliza, serializa e hasheia.

## Boundaries & Constraints

**Always:**
- Domínio puro: `R/domain_snapshot_hash.R` não abre arquivos e não importa `yaml`. Pode usar `digest` (SHA-256 é computação pura e determinística). O adapter faz toda a I/O e o parse do YAML.
- Todos os hashes são SHA-256 em hex minúsculo.
- `canonical_json()`: UTF-8, LF, chaves de objeto ordenadas, `null` explícito, `true`/`false`, números reais em decimal fixo (10 casas), inteiros sem parte decimal, sem espaços supérfluos, sem notação científica.
- `snapshot_content_hash()` é determinístico e idêntico entre máquinas para o mesmo conteúdo.
- Falhas (arquivo ausente, YAML inválido, `metadata.json` sem `content_hash`/`scoring_hash`) retornam `domain_error` — reusa o de 1.1/1.2.

**Ask First:**
- Nenhum. As decisões de formato (10 casas decimais; `metadata.json` re-serializado canonicamente sem `content_hash`; `scoring.yml` como 5º arquivo fora do manifesto de conteúdo) estão nos Design Notes; se conflitarem com o que o CLI da 1.4 precisa emitir, o review sinaliza.

**Never:**
- Não aplicar o gate de compatibilidade `scoring_hash` no `start` (Story 2.6) — aqui só expõe `verify_scoring_hash()` e o resultado.
- Não validar qualidade semântica do snapshot (Story 1.5) nem persistir nada (SQLite = Epic 2).
- Não mudar a assinatura de `parse_snapshot_bundle()` da Story 1.2.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Hash de conteúdo | 4 arquivos do bundle (bytes crus) + `metadata` parseado | `snapshot_content_hash` — string SHA-256 hex minúsculo | N/A |
| Determinismo entre máquinas | mesmo conteúdo, quebras de linha CRLF vs LF | hash idêntico (bytes normalizados para LF antes do hash) | N/A |
| Qualquer byte alterado | 1 byte mudado em `players.csv`, `metrics.csv` ou `qa-report.json`, ou um campo (não `content_hash`) mudado em `metadata.json` | hash muda | N/A |
| `content_hash` excluído | dois bundles idênticos exceto pelo valor de `metadata.json$content_hash` | mesmo `snapshot_content_hash` (o campo derivado não entra no manifesto) | N/A |
| Hash de scoring | `scoring.yml` parseado | `scoring_config_hash` — SHA-256 da forma canônica; hex minúsculo | N/A |
| Scoring compatível | `scoring_config_hash` == `metadata$scoring_hash` | `verify_scoring_hash()` → `NULL` (ok) | N/A |
| Scoring divergente | `scoring_config_hash` != `metadata$scoring_hash` | `domain_error("snapshot_scoring_incompativel", details = list(esperado, encontrado))` | valor |
| `canonical_json` — ordem de chaves | `list(b = 1, a = 2)` | `{"a":2,"b":1}` | N/A |
| `canonical_json` — número real | `0.1` | `"0.1000000000"` (10 casas fixas) | N/A |
| `canonical_json` — nulo/ausente | `list(x = NULL)` ou `NA` | `null` explícito | N/A |
| Arquivo cru ausente | `scoring.yml` não existe | `domain_error("bundle_arquivo_ausente")` (do adapter) | valor |
| YAML inválido | `scoring.yml` malformado | `domain_error("bundle_formato_invalido")` (do adapter) | valor |

</frozen-after-approval>

## Code Map

- `R/domain_errors.R` -- `domain_error()` (Story 1.1). Reusar.
- `R/domain_snapshot.R` / `R/domain_snapshot_schema.R` -- Story 1.2. Não alterar assinaturas; `snapshot_schema()$metadata` já exige `content_hash` e `scoring_hash`.
- `R/domain_snapshot_hash.R` -- novo: `canonical_json(x)`, `sha256_hex(text)`, `snapshot_content_hash(raw_files, metadata)`, `scoring_config_hash(parsed_scoring)`, `verify_scoring_hash(parsed_scoring, metadata)`.
- `R/adapter_files_snapshot.R` -- estender: `read_bundle_files_raw(bundle_dir)` → `list("players.csv" = <raw string>, ...)` para os 4 arquivos, ou `domain_error`; `read_scoring_config(scoring_path)` → lista parseada (`yaml::read_yaml`) ou `domain_error`.
- `DESCRIPTION` -- `Imports`: `digest (>= 0.6.0)`, `yaml (>= 2.3.0)`.
- `NAMESPACE` -- exports: `canonical_json`, `snapshot_content_hash`, `scoring_config_hash`, `verify_scoring_hash`.
- `inst/schema/snapshot-bundle-v1.md` -- documentar o algoritmo do manifesto e a forma canônica.
- `tests/testthat/fixtures/snapshot-valid/` -- adicionar `scoring.yml` (Full PPR mínimo) e alinhar `metadata.json$scoring_hash`/`content_hash` aos valores reais calculados.
- Arquitetura: AD-3 (manifesto), AD-12 (`canonical_json`), convenções (hash hex minúsculo).

## Tasks & Acceptance

**Execution:**
- [ ] `R/domain_snapshot_hash.R` -- `canonical_json(x)` recursivo: objetos → `{` + `"chave":valor` ordenados por chave + `}`; arrays → `[...]`; strings JSON-escapadas; `NULL`/`NA` → `null`; lógico → `true`/`false`; real → `formatC(x, format = "f", digits = 10)`; inteiro exato → sem decimal.
- [ ] `R/domain_snapshot_hash.R` -- `sha256_hex(text)` = `digest::digest(text, algo = "sha256", serialize = FALSE)`; `snapshot_content_hash(raw_files, metadata)`: normaliza CRLF→LF em cada arquivo, SHA-256 por arquivo, para `metadata.json` usa `canonical_json(metadata sem content_hash)` no lugar dos bytes crus; manifesto = pares `(path, sha256)` ordenados por path, serializado deterministicamente; retorna `sha256_hex(manifesto)`.
- [ ] `R/domain_snapshot_hash.R` -- `scoring_config_hash(parsed_scoring)` = `sha256_hex(canonical_json(parsed_scoring))`; `verify_scoring_hash(parsed_scoring, metadata)` → `NULL` se bate com `metadata$scoring_hash`, senão `domain_error("snapshot_scoring_incompativel")`.
- [ ] `R/adapter_files_snapshot.R` -- `read_bundle_files_raw(bundle_dir)` (4 arquivos como bytes cros via `readBin`+`rawToChar` ou `readChar`) e `read_scoring_config(scoring_path)` (`yaml::read_yaml`, erro → `bundle_formato_invalido`).
- [ ] `DESCRIPTION` + `NAMESPACE` -- `digest`, `yaml` em Imports; 4 novos exports; `#' @export`.
- [ ] `inst/schema/snapshot-bundle-v1.md` -- seção "Identidade de conteúdo": algoritmo do manifesto, exclusão de `content_hash`, forma canônica (10 casas), `scoring.yml` fora do manifesto.
- [ ] `tests/testthat/fixtures/snapshot-valid/` -- `scoring.yml` + `metadata.json` com hashes reais.
- [ ] `tests/testthat/test-domain_snapshot_hash.R` -- cobrir toda a I/O & Edge-Case Matrix.

**Acceptance Criteria:**
- Given um diretório de bundle, when `snapshot_content_hash()` roda, then o resultado é o SHA-256 (hex minúsculo) de um manifesto canônico dos 4 arquivos (bytes UTF-8/LF, paths ordenados, SHA-256 por arquivo), excluindo o campo `content_hash` de `metadata.json` e incluindo todo o resto.
- Given o mesmo conteúdo com quebras de linha diferentes, when o hash é recalculado, then o valor é idêntico.
- Given qualquer byte alterado em qualquer um dos 4 arquivos (exceto o próprio `content_hash`), when recalculado, then o hash muda.
- Given `scoring.yml`, when `scoring_config_hash()` roda, then usa a serialização canônica (chaves ordenadas, `null` explícito, numérico fixo) e `verify_scoring_hash()` confirma a igualdade com `metadata$scoring_hash` (ou retorna `domain_error` na divergência).
- Given `R/domain_snapshot_hash.R`, when inspecionado, then não abre arquivos nem importa `yaml`.

## Design Notes

- **`metadata.json` no manifesto:** parseado, `content_hash` removido, re-serializado por `canonical_json()` — assim o hash não depende da formatação do JSON mas depende de todo campo de conteúdo. Os outros 3 arquivos entram como bytes crus normalizados (LF).
- **`scoring.yml`:** 5º arquivo do diretório do bundle, **fora** do manifesto de conteúdo (AD-3 lista exatamente 4 arquivos). Sua identidade é o `scoring_config_hash`, comparado a `metadata$scoring_hash`. Swap de scoring é pego pelo gate da Story 2.6.
- **Decimal fixo (10 casas):** `formatC(x, format = "f", digits = 10, decimal.mark = ".")`. Suficiente para os pesos de scoring; a precisão para o `draft_state_hash` do Epic 4 fica adiada (`deferred-work.md`).
- **Determinismo é o requisito central — o serializador não pode depender de locale nem de encoding:**
  - `decimal.mark = "."` explícito (senão `getOption("OutDec")` vira `","` num locale pt-BR).
  - Ordenação de chaves com `order(nms, method = "radix")` (ordem de byte, não `LC_COLLATE`).
  - `sha256_hex()` faz `enc2utf8()` antes do `digest` (nome acentuado marcado `latin1` vs `UTF-8` hasheia bytes diferentes).
  - Normalização de fim de linha cobre CRLF **e** CR solto: `gsub("\r\n?", "\n", x, perl = TRUE)`.
  - `canonical_json()` unifica `4L` e `4.0` → `"4"` (double de valor inteiro renderiza sem decimal), então a inferência de tipo do `yaml`/`jsonlite` não muda o hash.
  - Testes rodam sob `withr::local_options(OutDec = ",")` e `withr::local_locale(c(LC_COLLATE = "C"))` e com conteúdo UTF-8 acentuado.
- **Guarda de `domain_error`:** `snapshot_content_hash()`, `scoring_config_hash()` e `verify_scoring_hash()` retornam/propagam o `domain_error` de entrada em vez de hasheá-lo (mesmo padrão de `parse_snapshot_bundle()`).
- **`verify_content_hash(raw_files, metadata)`** — simétrico a `verify_scoring_hash()`: `NULL` se o hash recomputado bate com `metadata$content_hash`, senão `domain_error("snapshot_content_incompativel")`. Não aplica gate (isso é 1.5/1.7).
- **`canonical_json` vs `jsonlite`:** hand-rolled — `jsonlite::toJSON` não garante ordem de chave nem representação decimal fixa. Contrato de entrada aceito: lista nomeada (objeto), lista/vetor sem nomes (array), escalar; nomes parciais/duplicados, `Inf`/`NaN` e vetor atômico nomeado → `stop()` explícito.
- **Lista de arquivos do manifesto:** uma constante única (`snapshot_bundle_files`, os 4 arquivos), referenciada pelo adapter e pelo domínio; `scoring.yml` nunca entra nessa lista.

## Verification

**Commands:**
- `Rscript -e 'pkgload::load_all(quiet = TRUE); testthat::test_local(reporter = "summary")'` -- 0 falhas, 0 warnings.
- `R CMD INSTALL --no-docs --no-help . && Rscript -e 'lintr::lint_package()'` -- nenhum lint.
- `Rscript -e 'renv::status()'` -- consistente (`digest`, `yaml` já na lib).
- Determinismo sob locale: `Rscript -e 'pkgload::load_all(quiet=TRUE); f <- read_bundle_files_raw("tests/testthat/fixtures/snapshot-valid"); m <- read_snapshot_bundle("tests/testthat/fixtures/snapshot-valid")$metadata; h <- snapshot_content_hash(f, m); withr::with_options(list(OutDec=","), stopifnot(identical(h, snapshot_content_hash(f, m))))'` -- hash estável.
- Pureza: `grep -nE "read|file\\.|yaml|readBin|readChar|connection|scan\\(|readRDS|url\\(|Sys\\." R/domain_snapshot_hash.R` -- só nomes de variável/comentário, nada de I/O.

## Spec Change Log

- **2026-08-30 — review round 1 (patches, sem loopback de spec).** Blind-hunter, edge-case-hunter e verification-gap convergiram em bugs de determinismo que violavam a intenção frozen ("idêntico entre máquinas"). Patches:
  - **Locale/encoding:** `decimal.mark = "."` explícito no `formatC` (locale pt-BR → `OutDec = ","` produziria `"0,04"`); `order(nms, method = "radix")` (não `LC_COLLATE`); `enc2utf8()` antes do `digest`; CR solto normalizado além de CRLF.
  - **`canonical_json`:** unifica `4L`/`4.0` → `"4"`; `stop()` explícito em `Inf`/`NaN`, nomes parciais/duplicados, vetor atômico nomeado; escapa pontos de código < 0x20 como `\uXXXX`.
  - **Guarda de `domain_error`** nas 3 funções de hash (não hasheia o erro).
  - **`verify_content_hash()`** novo, simétrico a `verify_scoring_hash()`; `verify_scoring_hash()` com `scoring_hash` ausente → `domain_error` em vez de erro de `sprintf`.
  - **Constante única** `snapshot_bundle_files` para a lista do manifesto (antes: hard-coded no domínio + constante no adapter).
  - **Adapter:** `rawToChar`/`readBin` com guarda (NUL, `file.size`, diretório, sem permissão) → `domain_error`; `scoring.yml` vazio/escalar/sequência → erro.
  - **Testes:** locale (`OutDec = ","`, `LC_COLLATE = "C"`), conteúdo UTF-8 acentuado, CRLF/CR em disco, insensibilidade à formatação do `metadata.json`, `scoring_hash` mutado muda `content_hash`, `domain_error` passado às funções de hash. Script regenerador do fixture + uma golden assertion sobre uma string `canonical_json` conhecida (não só o SHA).
  - **Doc:** `snapshot-bundle-v1.md` qualifica "muda com qualquer byte" (scoring.yml fora do manifesto; reformatação de JSON não muda).
  - **KEEP:** fronteira adapter × domínio puro; `metadata.json` re-serializado sem `content_hash`; `scoring.yml` fora do manifesto de conteúdo; reuso de `domain_error`.
  - **Adiados** (`deferred-work.md`): precisão decimal para o Epic 4; hashear `raw` direto em vez de `character`.

## Suggested Review Order

**Serializador canônico (o coração do determinismo)**

- `canonical_json()` — entrada e despacho por tipo; onde a ordem de chave e a forma do número são decididas.
  [`domain_snapshot_hash.R:33`](../../R/domain_snapshot_hash.R#L33)
- Ordem de byte (`method = "radix"`), não `LC_COLLATE`.
  [`domain_snapshot_hash.R:47`](../../R/domain_snapshot_hash.R#L47)
- `4L`/`4.0` → `"4"` via `sprintf("%.0f")`; reais → `formatC(..., decimal.mark = ".")` imune a `OutDec`.
  [`domain_snapshot_hash.R:87`](../../R/domain_snapshot_hash.R#L87)
- `sha256_hex()` com `enc2utf8()` — mesma string acentuada, mesmos bytes.
  [`domain_snapshot_hash.R:127`](../../R/domain_snapshot_hash.R#L127)

**Hashes do bundle**

- `snapshot_content_hash()` — manifesto dos 4 arquivos; `metadata.json` re-serializado sem `content_hash`; guarda de `domain_error`.
  [`domain_snapshot_hash.R:149`](../../R/domain_snapshot_hash.R#L149)
- `snapshot_bundle_files` — constante única para a lista do manifesto (adapter + domínio).
  [`domain_snapshot_hash.R:15`](../../R/domain_snapshot_hash.R#L15)
- `verify_content_hash()` / `verify_scoring_hash()` — simétricos; `NULL` ou `domain_error`; campo de hash ausente → `NA`, sem erro de `sprintf`.
  [`domain_snapshot_hash.R:186`](../../R/domain_snapshot_hash.R#L186)

**Adapter (I/O + parse YAML)**

- `read_bundle_files_raw()` — bytes crus; guardas de diretório/permissão/NUL → `domain_error`.
  [`adapter_files_snapshot.R:101`](../../R/adapter_files_snapshot.R#L101)
- `read_scoring_config()` — `yaml::read_yaml`; não-mapa → `bundle_formato_invalido`.
  [`adapter_files_snapshot.R:133`](../../R/adapter_files_snapshot.R#L133)

**Testes e fixture**

- Determinismo sob locale forçado, UTF-8 acentuado, CRLF/CR em disco, golden `canonical_json`.
  [`test-domain_snapshot_hash.R:1`](../../tests/testthat/test-domain_snapshot_hash.R#L1)
- Script regenerador dos hashes golden do fixture.
  [`regenerate-snapshot-valid.R`](../../tests/testthat/fixtures/regenerate-snapshot-valid.R)
