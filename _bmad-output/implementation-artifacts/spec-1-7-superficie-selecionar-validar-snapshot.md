---
title: 'Story 1.7 — Superfície "Selecionar e validar snapshot"'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: '46c91f114732bbeb2395f5ee8aa55b23d5d9b8fe'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O domínio de qualidade (1.5), o parser (1.2), os hashes (1.3) e os tokens visuais (1.6) existem, mas não há superfície: o operador não escolhe um bundle local nem vê se é válido antes de configurar a liga.

**Approach:** Um caso de uso puro `load_snapshot_for_preparation()` orquestra os leitores + `parse_snapshot_bundle()` + `verify_content_hash()` + `verify_scoring_hash()` + `validate_snapshot_quality()` em modo coletar-tudo e devolve um *view-model* determinístico (metadados, cobertura, avisos, bloqueios, `advance_allowed`), sem nunca lançar. Um adapter `list_snapshot_bundles()` enumera `resolve_snapshot_root()`. O módulo Shiny `ui_snapshot_quality.R` lista, exige seleção explícita, renderiza o view-model com `aria-busy` na leitura, bloqueia o avanço em `danger` com ação de recuperação, e expõe o snapshot válido como input imutável do preparo.

## Boundaries & Constraints

**Always:**
- Hexagonal: `load_snapshot_for_preparation()` é shell de aplicação — recebe os leitores como argumentos injetáveis (default = adapters reais), retorna o view-model, nunca `stop()`. Domínio inalterado: reusa `validate_snapshot_quality`, `parse_snapshot_bundle`, `verify_content_hash`, `verify_scoring_hash` sem mudar assinatura nem `code`s.
- `bloqueios` = achados `bloqueante` de `validate_snapshot_quality` ∪ falha de `verify_content_hash` ∪ falha de `verify_scoring_hash` ∪ falha de leitura do bundle. `advance_allowed <- length(bloqueios) == 0L`. Ordem estável (reusa a ordenação canônica da 1.5; o content hash entra com `code` fixo).
- Todo bloqueio/falha traz causa concreta (campo ou incompatibilidade) e **sempre** uma ação de recuperação: reexecutar `scripts/prepare_snapshot.R` ou selecionar outro snapshot. Falha de leitura mantém a seleção atual.
- Seleção explícita: nunca pré-carrega; o operador escolhe e confirma antes da leitura.
- Opcional ausente → linha visível `Não disponível neste snapshot`, classificada `aviso`, nunca bloqueia.
- Região de resultado com `aria-busy="true"` durante a leitura, `false` ao renderizar.
- Trocar o snapshot já selecionado exige reiniciar o preparo (limpa view-model + seleção); o snapshot válido é o input imutável da sessão em preparo.
- `app.R` continua só compondo (boot inalterado). `ui_snapshot_quality.R` é domínio-neutro: só apresentação e emissão de intenção. Valores visuais só via tokens de `www/theme.css`.

**Ask First:**
- Se o `fluidPage`/Bootstrap conflitar com os tokens a ponto de exigir container sem Bootstrap (débito adiado da 1.6).
- Se a superfície precisar emitir intenção de `start`/`DRAFT_STARTED` — isso é Epic 2 (Story 2.6); 1.7 só expõe o snapshot válido.

**Never:**
- SQLite, event store, migrations, `DRAFT_STARTED` (Epic 2). Rede, re-coleta, reescrita do bundle.
- Seleção por caminho arbitrário ou importação CSV manual (CLI da 1.4).
- Nova checagem de qualidade (reusar `validate_snapshot_quality` / `verify_*_hash`). Dependência nova sem "Ask First".

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Root vazia/ausente | sem subdiretórios de bundle | `list_snapshot_bundles()` → `character(0)`; "nenhum bundle preparado" + ação reexecutar script |
| Listagem | 2+ diretórios com os 4 arquivos canônicos | vetor ordenado por `snapshot_id` desc; dir ilegível → `domain_error("snapshot_root_ilegivel")` |
| Bundle saudável | bundle válido confirmado | view-model `ok=TRUE`, `advance_allowed=TRUE`, metadados (temporada, geração, fontes, método, scoring, identidade de conteúdo), cobertura, avisos de opcionais; libera avanço |
| Achado bloqueante | posição fora do V1 | `advance_allowed=FALSE`; bloqueio com causa concreta em `danger` + ações de recuperação |
| Content hash divergente | bytes ≠ `metadata$content_hash` | bloqueio `snapshot_content_hash_invalido` (`esperado`, `encontrado`); avanço bloqueado |
| Scoring divergente/indisponível | `verify_scoring_hash` falha / `scoring.yml` ausente | bloqueio preservando `code`/`message`; avanço bloqueado |
| Falha de leitura | arquivo sumiu entre listar e ler | view-model `ok=FALSE` com o `domain_error`; seleção mantida; ações de recuperação |
| Opcionais ausentes | `floor`/`bye_week`/... `NA` | linhas `Não disponível neste snapshot` classificadas `aviso`; `advance_allowed` inalterado |
| Troca de snapshot | outro item escolhido | exige reiniciar o preparo: limpa view-model + seleção antes de aceitar o novo |
| Determinismo | mesmo bundle, 2 leituras | view-model `identical()` |

</frozen-after-approval>

## Code Map

- `R/adapter_files_snapshot.R` — **editar**: novo `list_snapshot_bundles(root = resolve_snapshot_root())` → subdiretórios com `snapshot_bundle_files`, ordenados desc; `domain_error("snapshot_root_ilegivel")` se `root` não for diretório legível. Leitores injetados: `read_snapshot_bundle()` (`:22`), `read_bundle_files_raw()` (`:101`), `read_scoring_config()` (`:133`).
- `R/application_prepare_snapshot.R` `prepare_snapshot_verify()` (`:87`) — modelo do pipeline parse → content hash → scoring hash; 1.7 faz o mesmo em coletar-tudo + view-model.
- `R/application_load_snapshot.R` — **novo**: `load_snapshot_for_preparation(bundle_dir, read_bundle = read_snapshot_bundle, read_raw = read_bundle_files_raw, read_scoring = read_scoring_config)` → `list(ok, metadata, coverage, avisos, bloqueios, advance_allowed)`.
- `R/domain_snapshot_quality.R` `validate_snapshot_quality()` (`:136`) — lista `bloqueante`/`aviso`, reusar como está.
- `R/domain_snapshot_hash.R` `verify_content_hash()` (`:186`), `verify_scoring_hash()` (`:240`) — reusar.
- `R/domain_snapshot.R` `parse_snapshot_bundle()` (`:79`) → `list(players, metrics, metadata)` limpo para os campos exibidos.
- `R/ui_theme.R` `fdwr_theme_head()`; classes `.t-*` e tokens `--color-danger`/`--color-warning` de `www/theme.css`.
- `R/ui_snapshot_quality.R` — **novo**: `snapshot_quality_ui(id)`, `snapshot_quality_server(id, list_fn = list_snapshot_bundles, load_fn = load_snapshot_for_preparation)`.
- `app.R` (ui `:41`, server `:48`) — **editar**: inserir o módulo; remover o `<p>` placeholder.
- `NAMESPACE` — export das 4 funções novas.
- `tests/testthat/`: `test-adapter_files_snapshot.R` (editar), `test-application_load_snapshot.R` (**novo**), `test-ui_snapshot_quality.R` (**novo**, `shiny::testServer`).
- Arquitetura: AD-1, hexagonal (UI só emite intenção); `epic-1-context.md` §UX; `EXPERIENCE.md` linhas 60/81/82.

## Tasks & Acceptance

**Execution:**
- [x] `R/adapter_files_snapshot.R` — `list_snapshot_bundles()`: enumera subdiretórios de `root` com os 4 arquivos canônicos, ordena por nome desc, `character(0)` se nenhum, `domain_error("snapshot_root_ilegivel")` se `root` inválido.
- [x] `R/application_load_snapshot.R` — `load_snapshot_for_preparation()`: coletar-tudo `read_bundle` → `parse_snapshot_bundle` → `read_raw`+`verify_content_hash` → `read_scoring`+`verify_scoring_hash` → `validate_snapshot_quality`; monta view-model; nunca `stop()`; falha de leitura → `ok=FALSE`.
- [x] `R/ui_snapshot_quality.R` — módulo: lista, seleção explícita + confirmar, `aria-busy` na leitura, renderiza metadados/cobertura/avisos (opcional ausente = `Não disponível neste snapshot`), bloqueios em `danger` com ações de recuperação, expõe `reactive()` do snapshot válido, troca exige reiniciar o preparo.
- [x] `app.R` — compor o módulo; remover o parágrafo placeholder; boot inalterado.
- [x] `NAMESPACE` — `#' @export` nas 4 funções novas (via `devtools::document()`).
- [x] `tests/testthat/test-adapter_files_snapshot.R` — listagem: ordem, vazio, root ilegível.
- [x] `tests/testthat/test-application_load_snapshot.R` — toda a I/O & Edge-Case Matrix + determinismo.
- [x] `tests/testthat/test-ui_snapshot_quality.R` — `shiny::testServer`: seleção explícita obrigatória, bloqueio trava avanço, bundle válido libera avanço, troca exige reiniciar.

**Acceptance Criteria:**
- Given bundles preparados, when o operador abre a superfície, then a lista aparece e nada carrega até uma seleção explícita confirmada.
- Given um bundle válido, when é lido, then a superfície exibe temporada, geração, fontes, método, scoring e identidade de conteúdo, mais cobertura e avisos, com `aria-busy` durante a leitura, e libera o avanço.
- Given um bloqueio (qualidade, content hash ou scoring), when a superfície renderiza, then o avanço fica bloqueado, a causa concreta aparece em `danger` e há sempre ação de recuperação.
- Given opcionais ausentes, when a qualidade é exibida, then cada ausência é sinalizada e não bloqueia.
- Given um snapshot já selecionado, when o operador tenta trocá-lo, then a troca exige reiniciar o preparo e o snapshot selecionado é o input imutável da sessão.
- Given `devtools::test()` num clone limpo, then a suíte passa sem navegador.

## Spec Change Log

- **Review round 1 (2026-08-31) — sem loopback de spec; 2 esclarecimentos de leitura + 10 patches.**
  - **G1 — falha do `parse_snapshot_bundle()` bloqueia o avanço.** A enumeração congelada de `bloqueios` (Boundaries) lista 4 fontes e omite o parser, mas o Approach congelado põe `parse_snapshot_bundle()` na cadeia coletar-tudo e o Design Note diz "junta tudo". Leitura fixada: a falha do parser (`snapshot_bundle_vazio`, `snapshot_join_incompleto`, valor de `schema_version`) entra em `bloqueios` — a 1.7 é o gate pré-Epic-2 e nada roda o parser antes. Conhecido-ruim evitado: bundle vazio/órfão reportando `advance_allowed = TRUE`. Ao renegociar o bloco congelado, o 5º item da união de `bloqueios` deve ser "falha de `parse_snapshot_bundle`".
  - **G2 — o bloqueio de content hash preserva o `code` de domínio.** A I/O Matrix congelada nomeia `snapshot_content_hash_invalido`, mas `verify_content_hash()` já devolve `snapshot_content_incompativel` com exatamente `details = list(esperado, encontrado)`. Leitura fixada: preservar `snapshot_content_incompativel` (precedente 1.5/1.6: nunca renomear `code` de domínio). Ao renegociar o bloco congelado, a linha da matrix deve citar `snapshot_content_incompativel`.
  - **KEEP:** o view-model puro + módulo fino de `testServer`, o `list_snapshot_bundles()` como adapter, os leitores injetáveis, e a separação "lógica do que bloqueia fora do Shiny" sobreviveram bem — manter na re-derivação.
  - Patches P1–P10: guards de `bundle_dir`/leitura/`load_fn` (nunca lança), `list_snapshot_bundles` filtra ao padrão `snap-*` e trata `root` não-diretório, acentos PT-BR nas strings de operador, testes dos helpers de render + fiação do `app.R` + ramos do picker.

## Design Notes

- **View-model, não widgets no domínio:** o caso de uso devolve `list(...)`, o módulo só mapeia para tags + tokens. Toda a lógica de "o que bloqueia" fica testável fora do Shiny; o módulo leva um teste fino de `testServer`.
- **Content hash entra aqui:** a 1.5 deixou `verify_content_hash` para o chamador (precisa dos bytes crus). 1.7 é esse chamador — `read_bundle_files_raw()` + `verify_content_hash()` viram um bloqueio (preservando o `code` de domínio `snapshot_content_incompativel`, ver Spec Change Log G2) unido à lista da qualidade.
- **Coletar-tudo na aplicação:** diferente de `prepare_snapshot_verify()` (fail-fast), o caso de uso roda parse, os dois hashes e a qualidade e junta tudo — o operador vê todos os problemas de uma vez. A falha do `parse_snapshot_bundle()` (bundle vazio, join órfão, `schema_version` inválido) entra em `bloqueios` (Spec Change Log G1).

## Verification

**Commands:**
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint_package()'` — sem lint.
- `Rscript -e 'devtools::document()'` — NAMESPACE com as 4 exports novas.
- `Rscript -e 'shiny::runApp("app.R", launch.browser = FALSE, port = 4611)'` background + `curl -s http://127.0.0.1:4611 | grep -i snapshot` — a superfície entra no corpo.

**Manual checks:**
- Abrir o app com ≥ 1 bundle em `resolve_snapshot_root()`: a lista aparece, nada carrega sozinho; ao confirmar um bundle válido os metadados e a cobertura aparecem e o avanço libera; um bundle quebrado mostra o bloqueio em `danger` com ação de recuperação.

## Suggested Review Order

**O caso de uso — a lógica de "o que bloqueia" (comece aqui)**

- Ponto de entrada: orquestra leitura → parse → content hash → scoring → qualidade em coletar-tudo e devolve o view-model; nunca `stop()`.
  [`application_load_snapshot.R:60`](../../R/application_load_snapshot.R#L60)
- G1: a falha do `parse_snapshot_bundle()` (bundle vazio, join órfão, `schema_version`) entra em `bloqueios` — a 1.7 é o gate pré-Epic-2 e nada roda o parser antes.
  [`application_load_snapshot.R:94`](../../R/application_load_snapshot.R#L94)
- G2: o bloqueio de content hash preserva o `code` de domínio `snapshot_content_incompativel`; só o erro inesperado vira `snapshot_content_hash_erro`.
  [`application_load_snapshot.R:100`](../../R/application_load_snapshot.R#L100)
- Contrato "nunca lança": guard de `bundle_dir` inválido + `snapshot_safe_read()` em cada leitor (race listar↔ler).
  [`application_load_snapshot.R:44`](../../R/application_load_snapshot.R#L44)

**O adapter de listagem**

- `list_snapshot_bundles()`: só subdiretórios no formato `snap-<season>-<stamp>` com os 4 arquivos (ignora `tmp-snapshot-*`); `root` não-diretório → `snapshot_root_ilegivel`.
  [`adapter_files_snapshot.R:214`](../../R/adapter_files_snapshot.R#L214)

**O módulo Shiny — apresentação pura**

- `moduleServer`: seleção explícita + confirmar, `tryCatch` no `load_fn`, `rv$busy` sempre volta, troca exige `Reiniciar preparo`.
  [`ui_snapshot_quality.R:49`](../../R/ui_snapshot_quality.R#L49)
- Mapeamento view-model → tags: bloqueios em `--color-danger` + recuperação, opcional ausente = "Não disponível neste snapshot", nunca em branco.
  [`ui_snapshot_quality.R:143`](../../R/ui_snapshot_quality.R#L143)
- Fiação no composition root (uma linha no `ui`, uma no `server`; boot inalterado).
  [`app.R:52`](../../app.R#L52)

**Testes**

- View-model: toda a I/O Matrix + G1 (bundle vazio), G2 (code de domínio), determinismo, `bundle_dir` inválido.
  [`test-application_load_snapshot.R:83`](../../tests/testthat/test-application_load_snapshot.R#L83)
- Módulo: `testServer` (seleção, bloqueio, erro, troca, ramos do picker) + helpers de render puros.
  [`test-ui_snapshot_quality.R:139`](../../tests/testthat/test-ui_snapshot_quality.R#L139)
- Boot: o teste de integração do `app.R` agora afirma `fdwr-snapshot-quality` no HTML servido.
  [`test-ui_theme.R:191`](../../tests/testthat/test-ui_theme.R#L191)
