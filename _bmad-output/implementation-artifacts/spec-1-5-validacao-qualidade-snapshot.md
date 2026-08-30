---
title: 'Story 1.5 — Validação de qualidade do snapshot'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: '9237d52e2ab774588c6d369c4fb76e796e95dc66'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O parser (Story 1.2) é um gate *fail-fast*: devolve o primeiro `domain_error` e para. A superfície "Qualidade do snapshot" (Story 1.7) e o gate de início precisam de uma **lista completa e determinística** de todos os problemas, cada um classificado como bloqueante ou aviso — incluindo checagens semânticas que o parser não faz (nome ambíguo, ADP inválido, achados do `qa-report`, cobertura anômala).

**Approach:** Uma função de domínio pura `validate_snapshot_quality(deserialized, active_scoring_parsed)` em `R/domain_snapshot_quality.R` que roda **todas** as checagens em modo coletar-tudo sobre o bundle desserializado (retorno de `read_snapshot_bundle()`) mais o scoring ativo já parseado, e devolve uma lista ordenada de achados `list(code, severity, message, details)`. Não altera `parse_snapshot_bundle()`.

## Boundaries & Constraints

**Always:**
- Domínio puro: `R/domain_snapshot_quality.R` não abre arquivos, não importa `yaml`/`jsonlite`/`ffanalytics`, não lê clock. Recebe o bundle desserializado e o scoring ativo parseado como argumentos.
- Modo coletar-tudo: nunca aborta no primeiro problema; toda checagem roda e contribui achados.
- Lista determinística: ordenada por `severity` (`bloqueante` antes de `aviso`), depois `code` (ordem de byte, `method = "radix"`), depois uma chave estável de `details`. Duas execuções sobre a mesma entrada → lista `identical()`.
- Cada achado: `list(code = <snake_case estável>, severity = "bloqueante" | "aviso", message = <PT-BR, factual>, details = <lista machine-readable>)`.
- Reusa `normalize_position()`, `positions_v1`, `snapshot_schema()`, `scoring_config_hash()` / `verify_scoring_hash()`. Não muda a assinatura nem os `code`s de `parse_snapshot_bundle()`, `snapshot_schema()`, `verify_scoring_hash()`.
- Se `deserialized` já for um `domain_error` (o adapter falhou), devolve **um** achado bloqueante que preserva o `code` e a mensagem do erro.
- Uma entrada estruturalmente saudável (fixture `snapshot-valid`) com scoring compatível → **zero achados `bloqueante`** (avisos por opcionais ausentes são aceitáveis).

**Ask First:**
- Limiares de "cobertura anômala" além de "posição do V1 totalmente ausente" — se o review achar que precisa de mínimos numéricos por posição, parar e perguntar antes de fixar valores (as contagens nos docs são referência não-normativa).
- Faixa de ADP "válido" além de `> 0` e finito — se um `adp` implausivelmente grande deve ser bloqueante ou aviso.

**Never:**
- Não persistir nada, não tocar SQLite (Epic 2).
- Não aplicar o gate no `start` / `DRAFT_STARTED` (Story 2.6) — 1.5 só produz a lista.
- Não construir a superfície Shiny (Story 1.7 consome esta saída).
- Não reescrever o `qa-report.json` do bundle nem re-rodar a coleta.
- Não re-implementar a normalização de posição.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bundle saudável + scoring compatível | fixture `snapshot-valid` + o `scoring.yml` dele | `list()` ou só avisos de opcionais — nenhum `bloqueante` | N/A |
| Campo obrigatório de jogador ausente | `points`/`vor`/`tier`/`normalized_name`/`position` `NA` ou coluna ausente | achado `bloqueante` `snapshot_campo_obrigatorio_ausente` por `(campo, player_id)` | valor |
| Metadado obrigatório ausente | `metadata` sem `scoring_hash` | `bloqueante` `snapshot_metadado_ausente` (`campo`) | valor |
| `player_id` duplicado | dois registros `p1` | `bloqueante` `snapshot_player_id_duplicado` (`player_id`) | valor |
| Nome ambíguo sem desambiguação | 2 jogadores, mesmo `normalized_name` + `position` + `nfl_team` | `bloqueante` `snapshot_nome_ambiguo` (`normalized_name`, `player_ids`) | valor |
| Nome repetido mas desambiguável | mesmo `normalized_name`, `nfl_team`/`position` distintos | **sem** achado | N/A |
| Posição fora do V1 | `position = "FB"` | `bloqueante` `snapshot_posicao_fora_do_v1` (`player_id`, `raw`) | valor |
| ADP inválido quando informado | `adp = -1` / `0` / não finito | `bloqueante` `snapshot_adp_invalido` (`player_id`, `valor`) | valor |
| ADP ausente | coluna `adp` toda `NA` | **aviso** `snapshot_opcional_ausente` (`campo = adp`), não bloqueia | N/A |
| Scoring divergente | `scoring_config_hash(ativo) != metadata$scoring_hash` | `bloqueante` `snapshot_scoring_incompativel` (`esperado`, `encontrado`) | valor |
| `qa-report` ausente | `deserialized$qa_report` `NULL` / não-lista | `bloqueante` `qa_report_ausente` | valor |
| `qa-report` com achado bloqueante | `qa_report$findings` tem entrada `severity = "bloqueante"` | um `bloqueante` `qa_report_bloqueante` por entrada, preservando `code`/`message` | valor |
| Opcional ausente | `floor`/`ceiling`/`bye_week`/`nfl_team` ausente | **aviso** `snapshot_opcional_ausente` listando os campos, não bloqueia | N/A |
| Posição do V1 sem nenhum jogador | nenhum `K` | **aviso** `snapshot_cobertura_anomala` (`posicao`) | N/A |
| Determinismo | mesma entrada, 2 execuções | lista `identical()` (ordem incluída) | N/A |
| Adapter falhou | `deserialized` = `domain_error("bundle_arquivo_ausente")` | um `bloqueante` derivado (`code` + `message` do erro) | valor |

</frozen-after-approval>

## Code Map

- `R/domain_snapshot.R` — `normalize_position()`, `positions_v1`, `dst_aliases`, helpers internos. Reusar `normalize_position`/`positions_v1`; **não** alterar.
- `R/domain_snapshot_schema.R` — `snapshot_schema()`: campos obrigatórios/opcionais de `players`/`metrics`/`metadata`. Fonte da verdade dos campos a checar.
- `R/domain_snapshot_hash.R` — `scoring_config_hash()`, `verify_scoring_hash()`. Reusar para o achado de scoring.
- `R/domain_errors.R` — `domain_error()`, `is_domain_error()`. Reusar.
- `R/adapter_files_snapshot.R` — `read_snapshot_bundle()` produz o `deserialized` (contrato de entrada; não chamado por 1.5).
- `R/domain_snapshot_quality.R` — **novo**, domínio puro.
- `inst/schema/snapshot-bundle-v1.md` — nova seção "Validação de qualidade": checagens → `code` → severidade → ordem.
- `tests/testthat/fixtures/snapshot-valid/` — base saudável; testes derivam variantes quebradas inline (padrão das stories 1.2–1.4).
- `NAMESPACE` — export `validate_snapshot_quality`.
- Arquitetura: AD-1 (domínio puro); PRD DATA-003 / DATA-004; contrato de dados §"Validação e gates de qualidade".

## Tasks & Acceptance

**Execution:**
- [ ] `R/domain_snapshot_quality.R` — **puro**: `validate_snapshot_quality(deserialized, active_scoring_parsed)` → lista ordenada de achados. Orquestra: campos obrigatórios de jogador (`snapshot_schema()$players`/`$metrics`), metadados obrigatórios (`$metadata`), `player_id` duplicado, nome ambíguo (`normalized_name`+`position`+`nfl_team` repetidos), posição fora do V1 (`normalize_position`), ADP inválido quando informado (`> 0` e finito), scoring incompatível (`verify_scoring_hash`), `qa-report` ausente ou com achado `severity = "bloqueante"`, opcionais ausentes (aviso), cobertura anômala (posição do V1 sem jogadores → aviso). `deserialized` `domain_error` → um achado bloqueante derivado.
- [ ] `R/domain_snapshot_quality.R` — helpers `snapshot_quality_finding(code, severity, message, details)` (constrói/valida o registro) e `snapshot_quality_sort(findings)` (ordem canônica, locale-independente).
- [ ] `inst/schema/snapshot-bundle-v1.md` — seção com a tabela de checagens → `code` → severidade e a regra de ordenação.
- [ ] `NAMESPACE` — `#' @export` em `validate_snapshot_quality`.
- [ ] `tests/testthat/test-domain_snapshot_quality.R` — cobre toda a I/O & Edge-Case Matrix; um teste de pureza (grep sem I/O); um teste de determinismo (2 execuções → `identical`).

**Acceptance Criteria:**
- Given o fixture `snapshot-valid` com o `scoring.yml` dele como scoring ativo, when `validate_snapshot_quality()` roda, then não há nenhum achado com `severity = "bloqueante"`.
- Given um bundle com problemas distintos simultâneos (duplicata + posição inválida + ADP inválido + scoring divergente), when a validação roda, then **todos** aparecem na lista, cada um classificado, e a ordem é estável entre execuções.
- Given campos opcionais ausentes, when a validação roda, then o achado é `severity = "aviso"` e nenhuma checagem opcional produz bloqueante.
- Given `R/domain_snapshot_quality.R`, when inspecionado, then não abre arquivos, não importa `yaml`/`jsonlite`/`ffanalytics`, não lê o clock.
- Given `deserialized` sendo um `domain_error` do adapter, when a validação roda, then devolve exatamente um achado bloqueante que preserva o `code` e a mensagem.

## Spec Change Log

- **Review round 1 (3 reviewers, sem loopback de spec — só patches):**
  - **Guards de entrada degenerada:** `deserialized` não-lista/não-erro → um `snapshot_bundle_ilegivel`; `metadata` presente mas não-objeto → um `snapshot_metadado_ilegivel` (pula a cascata por campo + a checagem de scoring); `active_scoring_parsed` como `domain_error` → um `snapshot_scoring_indisponivel` (preserva `code`/`message`, pula o hash de scoring). Loops de posição/ADP/ambiguidade e de entradas do `qa-report` deixaram de assumir a presença de `player_id` / de entradas serem listas.
  - **`qa-report` objeto sem a chave `findings`** → `qa_report_ausente` (antes passava limpo). `findings: []` continua sem achado.
  - **Metadado multi-elemento todo `NA`** (`source_list = c(NA, NA)`) agora conta como ausente.
  - **ADP `NaN` numérico** é "informado mas inválido", não "ausente".
  - **Ambiguidade** agrupa pela `position` **normalizada** (`DST` = `D/ST`) e ignora linhas com `normalized_name` em branco.
  - **`tabela` nos `details`** de `snapshot_campo_obrigatorio_ausente`; `player_id` volta a ser checado em `metrics.csv` (defeito distinto do de `players.csv`).
  - **Ordenações internas** (`sort`) forçadas a `method = "radix"`; mensagens do operador em PT-BR acentuada.
  - **`adp` sem limite superior** (resolve o "Ask First"): só `<= 0` ou não-finito bloqueia.
  - **`verify_content_hash` é responsabilidade do chamador** — fora da lista coletar-tudo (só documentação).

## Design Notes

- **Por que não reusar o parser:** `parse_snapshot_bundle()` é fail-fast. 1.5 precisa de coletar-tudo + checagens semânticas que o parser não faz. Uma pequena duplicação de predicados triviais sobre `data.frame` (duplicata, posição) é mais barata que refatorar 1.2 em predicados compartilhados; extrair só se a duplicação crescer.
- **Entrada é o desserializado cru, não o parseado:** um bundle parseado já rejeitou duplicatas/posições — 1.5 não conseguiria reportá-las. Recebe `list(players, metrics, metadata, qa_report)` de `data.frame`/lista crus.
- **Nome ambíguo:** agrupa por `normalized_name`; um grupo com 2+ jogadores é ambíguo quando a tupla `(normalized_name, position normalizada, nfl_team)` também se repete (nada na busca os distingue). A `position` entra normalizada (`DST` = `D/ST`), com fallback ao valor cru se `normalize_position()` falhar. `nfl_team` `NA` em ambos conta como não-distinto. Linhas com `normalized_name` em branco/`NA` são ignoradas (já cobertas por campos obrigatórios).
- **ADP sem limite superior:** um `adp` grande é dado legítimo (jogador que sai tarde / não draftado); só `<= 0` ou não-finito (`NaN`/`Inf`) é bloqueante. `# ponytail:` marca o teto no código.
- **Content hash fora do escopo:** `verify_content_hash` precisa dos bytes crus dos arquivos e é responsabilidade do chamador (superfície / gate); `validate_snapshot_quality` recebe só o desserializado e não entra nessa checagem.
- **Achado do `qa-report`:** cada entrada de `qa_report$findings` é `{code, severity, message}`; `severity == "bloqueante"` → `qa_report_bloqueante` preservando `code`/`message`; outras severidades → aviso `qa_report_aviso`. (Story 1.4 emite `findings: []`; a população real é de story futura.)
- **Ordenação canônica:** `severity` (`bloqueante`=0, `aviso`=1), depois `code` (`order(method = "radix")`), depois `format()` estável de `details`. Sem dependência de locale.
- **Cobertura anômala:** só "posição do conjunto V1 sem nenhum jogador" → aviso. Mínimos numéricos por posição são referência não-normativa e ficam fora até haver dados de mock draft — ver "Ask First".

## Verification

**Commands:**
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint_package()'` — sem lint.
- Pureza: `grep -nE "read|file\\.|yaml|jsonlite|ffanalytics|Sys\\.|readRDS|url\\(|fromJSON|readBin" R/domain_snapshot_quality.R` — só nomes de variável/comentário.
- Determinismo: `validate_snapshot_quality()` duas vezes sobre a mesma entrada quebrada → `identical()`, inclusive sob `LC_COLLATE=C` forçado.

## Suggested Review Order

**Ponto de entrada — o orquestrador coletar-tudo**

- `validate_snapshot_quality()` — despacha para cada checagem, acumula achados, ordena no fim. Comece aqui.
  [`domain_snapshot_quality.R:120`](../../R/domain_snapshot_quality.R#L120)
- Guardas de entrada degenerada: `domain_error` → um achado; não-lista → `snapshot_bundle_ilegivel`; `active_scoring_parsed` `domain_error` → `snapshot_scoring_indisponivel`.
  [`domain_snapshot_quality.R:121`](../../R/domain_snapshot_quality.R#L121)

**Determinismo — o contrato de ordem**

- `snapshot_quality_sort()` — `severity` → `code` (radix) → chave de `details`; independente de locale.
  [`domain_snapshot_quality.R:56`](../../R/domain_snapshot_quality.R#L56)
- `snapshot_quality_detail_key()` — serialização estável de `details` para o desempate.
  [`domain_snapshot_quality.R:32`](../../R/domain_snapshot_quality.R#L32)
- `snapshot_quality_finding()` — a forma `list(code, severity, message, details)` validada na origem.
  [`domain_snapshot_quality.R:21`](../../R/domain_snapshot_quality.R#L21)

**As checagens que fazem escolhas não óbvias**

- Nome ambíguo: agrupa pela posição **normalizada** (`DST`≡`D/ST`), ignora nome vazio.
  [`domain_snapshot_quality.R:252`](../../R/domain_snapshot_quality.R#L252)
- ADP: `NaN` numérico conta como informado-inválido; sem limite superior no V1 (`# ponytail:`).
  [`domain_snapshot_quality.R:300`](../../R/domain_snapshot_quality.R#L300)
- Metadado ilegível vs ausente: objeto inválido → um achado + pula o cascade; NULL → cascade por campo.
  [`domain_snapshot_quality.R:192`](../../R/domain_snapshot_quality.R#L192)
- `qa-report`: ausente / sem chave `findings` / entradas não-lista → tratados; `findings: []` continua limpo.
  [`domain_snapshot_quality.R:334`](../../R/domain_snapshot_quality.R#L334)
- `snapshot_quality_id_col()` — `player_id` ausente não derruba os loops de posição/ADP/ambiguidade.
  [`domain_snapshot_quality.R:76`](../../R/domain_snapshot_quality.R#L76)

**Periféricos**

- Seção "Validação de qualidade": tabela checagem → `code` → severidade → ordem.
  [`snapshot-bundle-v1.md`](../../inst/schema/snapshot-bundle-v1.md)
- 92 testes: matriz completa, ordem canônica exata, determinismo sob locale forçado, pureza.
  [`test-domain_snapshot_quality.R:1`](../../tests/testthat/test-domain_snapshot_quality.R#L1)
