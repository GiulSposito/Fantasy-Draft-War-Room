---
title: 'Story 1.2 — Contrato e schema do snapshot bundle'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'a7832101310d9d38cc79fd90965948aa9a17e98c'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O runtime live e o futuro `scripts/prepare_snapshot.R` precisam interpretar os mesmos 4 arquivos do bundle exatamente da mesma forma. Sem um schema explícito e um parser único, cada lado inventa sua leitura.

**Approach:** Um schema declarado como dado (`R/domain_snapshot_schema.R`) e um doc de referência (`inst/schema/snapshot-bundle-v1.md`). Um adapter de arquivos (`R/adapter_files_snapshot.R`) faz toda a I/O e desserialização de formato (CSV, JSON); um parser puro de domínio (`parse_snapshot_bundle()` em `R/domain_snapshot.R`) recebe os dados já desserializados, valida contra o schema, normaliza posições, junta identidade + métricas por `player_id` e devolve um objeto canônico tipado ou um `domain_error`.

## Boundaries & Constraints

**Always:**
- Adapter (`adapter_files_*`) é o único que abre arquivos e chama `utils::read.csv` / `jsonlite::fromJSON`. O parser de domínio é puro: não abre arquivos, não importa `jsonlite`, `utils`, `yaml`, filesystem nem clock.
- Toda falha (arquivo ausente, JSON malformado, coluna obrigatória ausente, tipo não coercível, metadado ausente, posição não normalizável, join incompleto) retorna um `domain_error` (reusa o de 1.1): `code` estável, mensagem PT-BR acentuada, `details` machine-readable. Nenhuma exceção não tratada.
- Normalização de posição reusa `normalize_position()` da Story 1.1.
- Campos opcionais ausentes viram `NA` no objeto canônico — nunca bloqueiam.
- O objeto canônico é determinístico para a mesma entrada.

**Ask First:**
- Nenhum. A divisão de colunas players.csv (identidade) × metrics.csv (projeção/valor) é decidida aqui (ver Design Notes) e o CLI da Story 1.4 se conforma a este schema.

**Never:**
- Não calcular `snapshot_content_hash` nem `scoring_config_hash` (Story 1.3).
- Não aplicar gates de qualidade semânticos — `player_id` duplicado, nome ambíguo, ADP fora de faixa, cobertura anômala, severidade do `qa-report`, divergência de hash de scoring (Story 1.5). Aqui o `qa-report.json` só é desserializado e exposto cru.
- Não tocar SQLite, a superfície de seleção (1.7) nem o CLI (1.4).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bundle válido | 4 arquivos, todas as colunas obrigatórias | objeto canônico: `metadata`, `players` (identidade+métricas unidas, posições normalizadas, opcionais `NA` quando ausentes), `qa_report` cru | N/A |
| Arquivo ausente | `metrics.csv` não existe no diretório | `domain_error("bundle_arquivo_ausente")`, `details$arquivo = "metrics.csv"` | valor |
| JSON malformado | `metadata.json` com sintaxe inválida | `domain_error("bundle_formato_invalido")`, `details$arquivo` | valor |
| Coluna obrigatória ausente | `metrics.csv` sem `points` | `domain_error("snapshot_coluna_ausente")`, `details` nomeia arquivo e coluna | valor |
| Tipo não coercível | `tier` = `"abc"` | `domain_error("snapshot_tipo_invalido")`, `details` nomeia campo e valor | valor |
| Metadado obrigatório ausente | `metadata.json` sem `scoring_hash` | `domain_error("snapshot_metadado_ausente")`, `details$campo` | valor |
| Posição em variação | `position` = `"D/ST"` em `players.csv` | normalizada para `"DST"` no objeto canônico | N/A |
| Posição inválida | `position` = `"LB"` | `domain_error("snapshot_posicao_invalida")`, `details$player_id` | valor |
| Join incompleto | `player_id` presente em `players.csv` e ausente em `metrics.csv` (ou vice-versa) | `domain_error("snapshot_join_incompleto")`, `details` lista os `player_id` órfãos | valor |

</frozen-after-approval>

## Code Map

- `R/domain_errors.R` -- `domain_error()` já existe (Story 1.1). Reusar.
- `R/domain_snapshot.R` -- já tem `normalize_position()`, `positions_v1`, `dst_aliases` (Story 1.1). Adicionar `parse_snapshot_bundle(deserialized)`.
- `R/domain_snapshot_schema.R` -- novo: `snapshot_schema()` retorna a lista de specs (por campo: `type`, `required`) para `players`, `metrics`, `metadata`.
- `R/adapter_files_snapshot.R` -- novo: `read_snapshot_bundle(bundle_dir)` → `list(players = <data.frame>, metrics = <data.frame>, metadata = <list>, qa_report = <list>)` ou `domain_error` (arquivo ausente / formato inválido). Usa `utils::read.csv(stringsAsFactors = FALSE)` e `jsonlite::fromJSON(simplifyVector = TRUE)`.
- `DESCRIPTION` -- adicionar `Imports: jsonlite (>= 1.8.0)`, `utils`.
- `NAMESPACE` -- adicionar `export(parse_snapshot_bundle)`, `export(read_snapshot_bundle)`, `export(snapshot_schema)` (mantido à mão).
- `inst/schema/snapshot-bundle-v1.md` -- novo: doc de referência dos 4 arquivos, colunas, tipos, obrigatoriedade (fonte para o autor do CLI da 1.4).
- `tests/testthat/fixtures/snapshot-valid/` -- novo: bundle mínimo válido (4 arquivos, ~4 jogadores incluindo um DST como `"D/ST"`).
- `epic-1-context.md` -- contrato de dados destilado (campos mínimos, metadados, gates); `data-contract.md` completo em `_bmad-output/planning-artifacts/prds/.../`.

## Tasks & Acceptance

**Execution:**
- [x] `R/domain_snapshot_schema.R` -- `snapshot_schema()` como dado: `players` (`player_id`, `display_name`, `normalized_name`, `position` obrigatórios; `nfl_team`, `bye_week` opcionais), `metrics` (`player_id`, `points`, `vor`, `tier`, `tier_cliff` obrigatórios; `floor`, `ceiling`, `sd_points`, `ecr`, `adp`, `adp_sd`, `uncertainty` opcionais), `metadata` (`snapshot_id`, `season`, `generated_at`, `pipeline_version`, `source_list`, `scoring_hash`, `content_hash`, `qa_summary`, `schema_version` obrigatórios).
- [x] `R/adapter_files_snapshot.R` -- `read_snapshot_bundle(bundle_dir)`: verifica os 4 arquivos, desserializa CSV/JSON, devolve a lista crua ou `domain_error("bundle_arquivo_ausente" | "bundle_formato_invalido")`.
- [x] `R/domain_snapshot.R` -- `parse_snapshot_bundle(deserialized)` puro: valida colunas/tipos contra `snapshot_schema()`, coage tipos, valida metadados, normaliza `position` via `normalize_position()` (envolve o erro em `snapshot_posicao_invalida` com `player_id`), junta `players`+`metrics` por `player_id` (órfãos → `snapshot_join_incompleto`), opcionais ausentes → `NA`. Retorna `list(metadata, players, qa_report)` ou `domain_error`.
- [x] `DESCRIPTION` + `NAMESPACE` -- `jsonlite`/`utils` em Imports; 3 novos exports; `#' @export` nas 3 funções novas.
- [x] `inst/schema/snapshot-bundle-v1.md` -- doc de referência do bundle.
- [x] `tests/testthat/fixtures/snapshot-valid/` -- bundle mínimo válido.
- [x] `tests/testthat/test-domain_snapshot_schema.R` -- forma e completude do schema.
- [x] `tests/testthat/test-adapter_files_snapshot.R` -- leitura do fixture; arquivo ausente e JSON malformado → `domain_error`.
- [x] `tests/testthat/test-domain_snapshot.R` -- estender: cobrir toda a I/O & Edge-Case Matrix de `parse_snapshot_bundle`.

**Acceptance Criteria:**
- Given um bundle com os 4 arquivos e colunas completas, when `read_snapshot_bundle()` + `parse_snapshot_bundle()` rodam, then o resultado é o objeto canônico tipado com os campos mínimos do contrato, posições normalizadas e opcionais `NA` quando ausentes.
- Given um bundle com arquivo ausente, coluna obrigatória ausente ou valor de tipo incompatível, when o fluxo roda, then retorna um `domain_error` com `code` estável, mensagem PT-BR e `details`, sem exceção não tratada.
- Given `metadata.json`, when parseado, then `season`, `generated_at`, `pipeline_version`, `source_list`, `scoring_hash`, `content_hash`, `qa_summary` (e `schema_version`) são exigidos e expostos no objeto canônico.
- Given `position` em qualquer variação de `D/ST`, when normalizada, then vira `"DST"` no conjunto V1 (`QB`, `RB`, `WR`, `TE`, `K`, `DST`).
- Given o parser de domínio, when inspecionado, then ele não abre arquivos nem importa `jsonlite`/`utils`/`yaml` — toda a I/O e desserialização estão no adapter.

## Design Notes

- **Divisão dos CSVs:** `players.csv` = identidade e elegibilidade (`player_id`, `display_name`, `normalized_name`, `position`, `nfl_team`, `bye_week`); `metrics.csv` = projeção e valor (`player_id` + `points`, `vor`, `tier`, `tier_cliff` e os opcionais numéricos). Chave de join: `player_id`. Um jogador tem exatamente uma linha em cada arquivo.
- **Fronteira pura vs. adapter:** o AC do epic diz "o parser de domínio lê o bundle" — leia-se *interpreta*. `epic-1-context.md` reconcilia: adapter faz a leitura crua e a desserialização de formato; o domínio valida/normaliza/junta. Assim o mesmo `parse_snapshot_bundle()` serve o runtime e o CLI da 1.4, e AD-1 (domínio sem I/O) fica intacto.
- **`qa-report.json`:** aqui só é desserializado e devolvido em `qa_report`. A classificação bloqueante/aviso é a Story 1.5.
- **Coerção de tipo:** numéricos → `as.numeric`; `tier`/`bye_week` → inteiro (valor não-inteiro numa coluna inteira → `snapshot_tipo_invalido`, sem arredondar); `tier_cliff` → lógico. Célula **vazia numa coluna obrigatória** → `snapshot_tipo_invalido` (`details$motivo = "vazio"`); célula vazia numa coluna **opcional** → `NA` tipado. Valor não-vazio que não coage → `snapshot_tipo_invalido` (`details$motivo = "nao_coercivel"`).
- **Falhas estruturais (rejeitadas por 1.2, não são o gate de qualidade de 1.5):** `player_id` duplicado em qualquer um dos CSVs (`snapshot_player_id_duplicado`), bundle sem linhas de dados (`snapshot_bundle_vazio`), órfãos do join (`snapshot_join_incompleto`, com `apenas_em_players`/`apenas_em_metrics`), nomes de coluna duplicados num CSV, `schema_version` diferente de `"snapshot-bundle-v1"` (`snapshot_schema_incompativel`). São impossibilidades para um objeto canônico 1:1 — distintas dos gates semânticos (nome ambíguo, ADP fora de faixa, cobertura anômala) que ficam em 1.5.
- **Colunas extras** nos CSVs são descartadas — o objeto canônico tem exatamente as colunas do schema.
- **Objeto de sucesso** é classificado `fdwr_snapshot_bundle` (lista com `metadata`, `players`, `qa_report`).
- **`details` dos erros:** `arquivo` para o nome do arquivo, `campo` para qualquer coluna/chave. Metadados são checados só por presença (formato de hash/timestamp fica adiado — ver `deferred-work.md`).

## Verification

**Commands:**
- `Rscript -e 'pkgload::load_all(quiet = TRUE); testthat::test_local(reporter = "summary")'` -- 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint_package()'` -- nenhum lint.
- `Rscript -e 'renv::status()'` -- consistente (jsonlite já está na lib).
- `Rscript -e 'pkgload::load_all(quiet=TRUE); b <- read_snapshot_bundle("tests/testthat/fixtures/snapshot-valid"); str(parse_snapshot_bundle(b), max.level = 2)'` -- objeto canônico, sem erro.
- Pureza: `grep -nE "read\\.csv|fromJSON|readLines|file\\.exists|readChar" R/domain_snapshot.R R/domain_snapshot_schema.R` -- sem correspondência.

## Spec Change Log

- **2026-08-30 — review round 1 (patches, sem loopback de spec).** Blind-hunter, edge-case-hunter e verification-gap revisaram o diff. A matriz frozen ("Tipo não coercível") já cobria o caso da célula vazia; os Design Notes tinham narrado errado ("valor não vazio") e foram corrigidos. Patches aplicados:
  - `parse_snapshot_bundle()`: short-circuit quando `deserialized` é um `domain_error` do adapter (antes: mascarava com `snapshot_metadado_ausente`); rejeita `player_id` duplicado (`snapshot_player_id_duplicado`) e bundle vazio (`snapshot_bundle_vazio`) como falhas estruturais antes do `merge()`; sucesso agora classificado `fdwr_snapshot_bundle`; `snapshot_join_incompleto` separa `apenas_em_players`/`apenas_em_metrics`.
  - Coerção: célula vazia em coluna obrigatória → `snapshot_tipo_invalido`; valor não-inteiro em coluna inteira → erro (sem arredondar); colunas extras descartadas; nomes de coluna duplicados num CSV → erro.
  - `validate_metadata`: rejeita array JSON (data.frame); exige `schema_version == "snapshot-bundle-v1"` (`snapshot_schema_incompativel`).
  - Adapter: `stopifnot` em `bundle_dir`; `read.csv(fileEncoding = "UTF-8-BOM")` para tolerar BOM.
  - `details` padronizado (`arquivo`/`campo`); helpers internos prefixados `snapshot_*`; `withr` em `Suggests`; `snapshot-bundle-v1.md` e roxygen `@return` atualizados com os códigos de erro e a classe de sucesso.
  - **KEEP:** fronteira adapter puro × domínio (sem I/O no domínio); schema como dado em `snapshot_schema()`; fixture `snapshot-valid`; reuso de `normalize_position()` e `domain_error()`.
  - **Adiados** (`deferred-work.md`): validação de formato de hash/timestamp nos metadados; validação estrutural de CSV além de "parseia"; tokens de nulo textual em células opcionais.
  - **Interpretação de fronteira:** o "Never" do spec adia `player_id` duplicado para a Story 1.5. Aplicada a leitura de que 1.5 é dona do *julgamento de qualidade* (nome ambíguo, ADP, cobertura), enquanto uma chave primária duplicada é uma *impossibilidade estrutural* para o objeto canônico 1:1 — mesma categoria da linha "Join incompleto" da matriz frozen. Confirmar com o autor do spec.

## Suggested Review Order

**Fronteira adapter × domínio puro**

- Entrada: adapter é o único que abre arquivo e chama `read.csv`/`fromJSON`; devolve lista crua ou `domain_error`.
  [`adapter_files_snapshot.R:26`](../../R/adapter_files_snapshot.R#L26)
- `fileEncoding = "UTF-8-BOM"` tolera BOM de export de Excel sem renomear a primeira coluna.
  [`adapter_files_snapshot.R:69`](../../R/adapter_files_snapshot.R#L69)

**Parser puro: contrato e integridade estrutural**

- `parse_snapshot_bundle()` — short-circuit em `domain_error` upstream, depois valida/coage/normaliza/junta.
  [`domain_snapshot.R:79`](../../R/domain_snapshot.R#L79)
- Rejeições estruturais antes do `merge()`: bundle vazio, `player_id` duplicado (não é o gate de qualidade da 1.5).
  [`domain_snapshot.R:100`](../../R/domain_snapshot.R#L100)
- Sucesso classificado `fdwr_snapshot_bundle`, colunas restritas ao schema.
  [`domain_snapshot.R:158`](../../R/domain_snapshot.R#L158)

**Coerção de tipo**

- `snapshot_coerce_column(x, type, required)` — vazio em obrigatória → erro (`motivo = "vazio"`); não-inteiro em coluna inteira → erro, sem arredondar.
  [`domain_snapshot.R:256`](../../R/domain_snapshot.R#L256)

**Schema e metadados**

- `snapshot_schema()` — schema como dado (por campo: `type`, `required`), fonte única do parser e do doc.
  [`domain_snapshot_schema.R:15`](../../R/domain_snapshot_schema.R#L15)
- `snapshot_validate_metadata()` — presença dos 9 metadados + `schema_version == "snapshot-bundle-v1"`; rejeita array JSON.
  [`domain_snapshot.R:178`](../../R/domain_snapshot.R#L178)
- Doc de referência do bundle (fonte para o CLI da Story 1.4).
  [`snapshot-bundle-v1.md:1`](../../inst/schema/snapshot-bundle-v1.md#L1)

**Testes e fixture**

- Bundle mínimo válido (4 jogadores, um DST como `"D/ST"`, só `adp` entre os opcionais).
  [`fixtures/snapshot-valid/`](../../tests/testthat/fixtures/snapshot-valid/)
- Matriz de I/O + falhas estruturais + coerção.
  [`test-domain_snapshot.R:1`](../../tests/testthat/test-domain_snapshot.R#L1)
- Adapter: arquivo ausente, JSON malformado, BOM, `bundle_dir` inválido.
  [`test-adapter_files_snapshot.R:1`](../../tests/testthat/test-adapter_files_snapshot.R#L1)
