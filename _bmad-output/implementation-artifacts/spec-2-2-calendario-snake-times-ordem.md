---
title: 'Story 2.2 — Calendário snake, times e ordem (núcleo puro)'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'f144bf19ad5d4984f04606a5170f16bdc3d8a64b'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O `Validate and Lock` (Story 2.3) precisa travar a sessão sobre a mesa real — times cadastrados, o time do operador identificado e o calendário snake completo — mas não existe nenhum domínio de times nem de schedule; `R/` só tem liga e snapshot.

**Approach:** Um módulo de domínio puro `R/domain_schedule.R` com quatro funções: `parse_league_teams()` (modelo canônico de times, id imutável, exatamente um time do operador), `snake_draw_order()` (sorteio reprodutível da ordem da 1ª rodada com seed registrada, sem vazar RNG), `validate_first_round_order()` (a ordem é permutação exata dos times cadastrados) e `snake_schedule()` (gera todos os slots do snake). A superfície Shiny de setup foi separada (ver `deferred-work.md`).

## Boundaries & Constraints

**Always:**
- Domínio puro (AD-1): `R/domain_schedule.R` não abre arquivos, não importa `yaml`/`jsonlite`/`shiny`/`DBI`, não lê o clock. Todo input é argumento explícito. Reusar `domain_error`/`is_domain_error` sem alterar.
- Falha → `domain_error()` (`code` estável `snake_case`, mensagem PT-BR, `details` machine-readable). Nunca exceção não tratada.
- Determinismo: mesma entrada → saída `identical()` em qualquer execução, inclusive sob `LC_COLLATE=C`.
- `snake_draw_order()` **restaura** `.Random.seed` do ambiente global (salva antes, `on.exit` depois) — nenhum efeito colateral no RNG do processo.
- Colunas do slot em `snake_case`: `overall_pick` (contínuo, `1..N*rounds`), `round` (`1..rounds`), `pick_in_round` (`1..N`), `fantasy_team_id`, `is_user_team` (lógico).
- Snake: round ímpar segue a ordem da 1ª rodada; round par é o inverso exato do ímpar anterior; exatamente um slot por time por round.
- `rounds` é parâmetro (default `15L`) — o gerador é reusado por `scripts/simulate_draft.R` (Epic 3).

**Ask First:**
- Se o review concluir que a ordem da 1ª rodada deve poder ser parcial (alguns times sem posição) em vez de uma permutação completa antes de gerar o schedule.

**Never:**
- Não persistir, não tocar SQLite, não emitir evento — `DRAFT_STARTED` e proveniência são Story 2.3.
- Não construir superfície Shiny nem `Validate and Lock` — separados para uma story própria (`deferred-work.md`, split 2026-08-31).
- Não validar o envelope numérico de times (8–14) — isso é `validate_league_envelope()` (Story 2.1). Aqui só: ≥ 2 times e forma/unicidade.
- Não cadastrar scoring nem regras de liga — Story 2.1.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Times válidos | lista de `{fantasy_team_id, display_name, is_user}`, 1 com `is_user=TRUE` | `parse_league_teams()` → `data.frame(fantasy_team_id <chr>, display_name <chr>, is_user <lgl>)` em ordem de cadastro |
| Forma inválida | não-lista / entrada sem os campos | `domain_error("league_teams_malformado")` |
| Id inválido | id vazio, não-texto ou duplicado | `domain_error("league_teams_id_invalido", details$fantasy_team_id)` |
| Time do operador ≠ 1 | 0 ou 2+ com `is_user=TRUE` | `domain_error("league_teams_usuario_invalido", details$encontrados)` |
| Sorteio reprodutível | `snake_draw_order(ids, seed=42)` duas vezes | resultado `identical()`; permutação dos `ids`; `.Random.seed` global inalterado antes/depois |
| Seed inválida | `seed` = `"x"`, `1.5`, `Inf`, `NA` | `domain_error("snake_seed_invalida", details$seed)` |
| Ordem = permutação | `order` == permutação exata de `team_ids` | `validate_first_round_order()` → `NULL` |
| Ordem incompleta / sobrando / repetida | falta id, id extra, id repetido | `domain_error("snake_ordem_invalida")` com `details$faltando` / `details$sobrando` / `details$duplicados` |
| Schedule feliz | `first_round_order` = 12 ids, `user_team_id` = ids[3], `rounds=15` | `data.frame` de 180 linhas; round 1 = ordem de entrada, round 2 = inverso, …; `overall_pick` 1..180 sem furo; `is_user_team` TRUE só nas 15 linhas de ids[3]; 1 slot por time por round |
| Schedule determinístico | mesma entrada, duas execuções | `identical()` |
| Parâmetro inválido | `first_round_order` com < 2 ids ou id duplicado; `rounds` não-inteiro ≥ 1 | `domain_error("snake_parametro_invalido", details$campo)` |
| Time do operador fora da ordem | `user_team_id` não está em `first_round_order` | `domain_error("snake_time_usuario_ausente")` |

</frozen-after-approval>

## Code Map

- `R/domain_schedule.R` — **novo**, domínio puro. As 4 funções públicas + helper interno `schedule_pos_int()` (inteiro finito no range de `integer`; espelha `league_scalar_int()` de `R/domain_league_config.R` ~L54 mas com `code` do schedule — não importar).
- `R/domain_errors.R` — `domain_error()` (classes `c(code, "fdwr_domain_error", "error", "condition")`), `is_domain_error()`. Reusar, não alterar.
- `R/domain_snapshot_quality.R` / `R/domain_snapshot.R` — `snapshot_quality_*` e `positions_v1` **não** se aplicam aqui (formato é `domain_error` único ou `data.frame`; times não têm posição).
- `NAMESPACE` — mantido à mão (convenção Stories 1.5–2.1; `deferred-work.md`). `export()` das 4 funções em ordem alfabética.
- `tests/testthat/test-domain_schedule.R` — **novo**, fora de Shiny/SQLite. Segue o padrão dos testes da 2.1 (pureza por grep, determinismo, I/O Matrix).
- Arquitetura: AD-1, AD-7; ER `FANTASY_TEAM ||--o{ DRAFT_SLOT`; epic-2-context.md §Requirements e §Cross-Story; PRD FR10, FR12–FR16.

## Tasks & Acceptance

**Execution:**
- [x] `R/domain_schedule.R` — `parse_league_teams(entries)` → `data.frame` canônico (`fantasy_team_id` chr, `display_name` chr, `is_user` lgl) em ordem de cadastro, ou `domain_error` (`league_teams_malformado` / `_id_invalido` / `_usuario_invalido`). Aceita lista de mapas nomeados já desserializados.
- [x] `R/domain_schedule.R` — `snake_draw_order(team_ids, seed)` → vetor `character` permutado (reprodutível por `(team_ids, seed)`), ou `domain_error("snake_seed_invalida")`. Salva `.Random.seed` do `globalenv()` (se existir), `set.seed(seed)`, `sample`, restaura via `on.exit`. Valida `team_ids` (≥ 2, texto, únicos) → `domain_error("snake_parametro_invalido")`.
- [x] `R/domain_schedule.R` — `validate_first_round_order(order, team_ids)` → `NULL` se `order` é permutação exata de `team_ids`; senão `domain_error("snake_ordem_invalida", details = list(faltando, sobrando, duplicados))`.
- [x] `R/domain_schedule.R` — `snake_schedule(first_round_order, user_team_id, rounds = 15L)` → `data.frame` com `overall_pick`, `round`, `pick_in_round`, `fantasy_team_id`, `is_user_team`; rounds pares invertem os ímpares; ou `domain_error` (`snake_parametro_invalido` / `snake_time_usuario_ausente`). `is_user_team <- fantasy_team_id == user_team_id`.
- [x] `NAMESPACE` — `export()` de `parse_league_teams`, `snake_draw_order`, `snake_schedule`, `validate_first_round_order` (ordem alfabética, à mão).
- [x] `tests/testthat/test-domain_schedule.R` — cobre a I/O & Edge-Case Matrix; pureza (grep sem I/O); determinismo (2 execuções → `identical`, inclusive `LC_COLLATE=C`); afirma que `.Random.seed` global fica inalterado após `snake_draw_order()`.

**Acceptance Criteria:**
- Given `R/domain_schedule.R`, when inspecionado, then não abre arquivos, não importa `yaml`/`jsonlite`/`shiny`, não lê o clock.
- Given a ordem da 1ª rodada e `rounds`, when `snake_schedule()` roda, then há exatamente um slot por time por round, `overall_pick` é contínuo de 1 a `N*rounds`, cada round par é o inverso exato do ímpar anterior e `is_user_team` marca só os slots do time do operador.
- Given a mesma entrada, when `snake_schedule()` ou `snake_draw_order()` roda duas vezes, then a saída é `identical()`.
- Given `snake_draw_order()` executado, when se compara `.Random.seed` do ambiente global antes e depois, then é o mesmo (nenhum efeito colateral no RNG).
- Given qualquer forma inválida de times, ordem ou parâmetro, when a função roda, then retorna um `domain_error` com `code` estável e `details` acionável, nunca uma exceção.

## Design Notes

- **Sorteio puro sem vazar RNG:** salvar `get(".Random.seed", globalenv())` (ou `NULL`), `set.seed(seed)`, sortear, e no `on.exit` restaurar (ou `rm` se não existia). `scripts/simulate_draft.R` (Epic 3) reusa o mesmo padrão para sortear ordem e estratégias.
- **Snake — golden:** 4 times `[A,B,C,D]`, 2 rounds → `fantasy_team_id` por `overall_pick` 1..8 = `A,B,C,D, D,C,B,A`; `pick_in_round` = `1,2,3,4, 1,2,3,4`; `round` = `1,1,1,1, 2,2,2,2`.

## Verification

**Commands:**
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint("R/domain_schedule.R"); lintr::lint("tests/testthat/test-domain_schedule.R")'` — sem lint.
- Pureza: `grep -nE "read|file\\.|yaml|jsonlite|Sys\\.|fromJSON|readBin|shiny|DBI" R/domain_schedule.R` — só nomes de variável/comentário.
- Determinismo: `snake_schedule()` e `snake_draw_order()` duas vezes sobre a mesma entrada → `identical()`, inclusive sob `LC_COLLATE=C`.

## Suggested Review Order

**Gerador do calendário snake (o coração da story)**

- Ponto de entrada: monta os slots com round par = inverso exato do ímpar; guarda de `rounds` contra overflow de `integer`.
  [`domain_schedule.R:259`](../../R/domain_schedule.R#L259)
- Golden do snake `[A,B,C,D]×2` e o caso 12 times / 15 rounds (1 slot por time por round).
  [`test-domain_schedule.R:140`](../../tests/testthat/test-domain_schedule.R#L140)

**Modelo canônico de times**

- Valida forma, id único (sobre o valor aparado), exatamente um time do operador; `domain_error` na entrada passa direto.
  [`domain_schedule.R:65`](../../R/domain_schedule.R#L65)
- Unicidade sobre o id aparado — `"t1"` e `" t1"` colidem.
  [`domain_schedule.R:37`](../../R/domain_schedule.R#L37)

**Ordem da primeira rodada**

- Sorteio reprodutível: RNG fixado (`Mersenne-Twister`/`Rejection`) e `.Random.seed` global salvo/restaurado via `on.exit`.
  [`domain_schedule.R:160`](../../R/domain_schedule.R#L160)
- Permutação exata: rejeita `team_ids` com duplicata, comprimento divergente e ordem vazia.
  [`domain_schedule.R:208`](../../R/domain_schedule.R#L208)
- Golden do RNG fixo (vetor permutado exato para seed 42) e RNG global intacto antes/depois.
  [`test-domain_schedule.R:86`](../../tests/testthat/test-domain_schedule.R#L86)

**Periféricos**

- 4 exports adicionados à mão, em ordem alfabética.
  [`NAMESPACE:17`](../../NAMESPACE#L17)
- Nota de defer: unicidade de `display_name` fica com a story da superfície de setup.
  [`deferred-work.md:115`](./deferred-work.md#L115)
