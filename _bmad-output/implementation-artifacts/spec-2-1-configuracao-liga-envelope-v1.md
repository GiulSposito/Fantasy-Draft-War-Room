---
title: 'Story 2.1 — Configuração da liga e envelope V1'
type: 'feature'
created: '2026-08-31'
status: 'in-review'
review_loop_iteration: 0
baseline_commit: '5f054dd7966abfd69a213fe3cf36e798d8ace3a3'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O Epic 2 precisa travar uma sessão de draft (`Validate and Lock`, Story 2.3) sobre regras de liga válidas, mas não existe nenhum objeto de configuração de liga — `config/` só tem scoring e pipeline do snapshot.

**Approach:** Um YAML versionado `config/league_rules.yml` com a configuração de referência (12 times, Full PPR, 1 QB / 2 RB / 2 WR / 1 TE / 1 FLEX RB-WR / 1 K / 1 D/ST + 6 reservas) e um módulo de domínio puro `R/domain_league_config.R` que o parseia num objeto canônico, valida o envelope V1 devolvendo achados bloqueantes por grupo afetado, e expõe um aviso não-bloqueante de compatibilidade de scoring reusando `verify_scoring_hash()`.

## Boundaries & Constraints

**Always:**
- Domínio puro: `R/domain_league_config.R` não abre arquivos, não importa `yaml`/`jsonlite`, não lê clock. Recebe o YAML já desserializado (mapa nomeado) como argumento.
- O adapter de leitura do disco é `read_scoring_config()` (leitor genérico de mapa-YAML-ou-`domain_error`, apesar do nome) — reusar.
- Falha de parsing/tipo → `domain_error` (`code` estável `snake_case`, mensagem PT-BR, `details` machine-readable). Nunca exceção não tratada.
- Achado de envelope no formato de `snapshot_quality_finding()`: `severity` sempre `"bloqueante"`; `details$grupo ∈ {"times_rounds", "slots_flex", "scoring"}`.
- Lista de achados determinística, ordenada por `snapshot_quality_sort()`; mesma entrada → `identical()`. Config viável → lista vazia.
- Composição de titulares do V1 é **exata**: `QB=1, RB=2, WR=2, TE=1, FLEX=1, K=1, DST=1` (FR7). `flex_eligibility` é subconjunto não-vazio de `{"RB","WR"}` (FR8).
- `reference_league_config()` devolve o objeto canônico idêntico ao parse de `config/league_rules.yml`.
- Reusar `positions_v1`, `domain_error`, `is_domain_error`, `verify_scoring_hash`, `snapshot_quality_finding`, `snapshot_quality_sort` sem alterar suas assinaturas nem `code`s.

**Ask First:**
- Se o review concluir que a composição de titulares deve ser configurável (contagens por posição livres desde que somem 9 e caibam nos rounds) em vez de fixa.

**Never:**
- Não persistir, não tocar SQLite, não emitir evento — `DRAFT_STARTED` e proveniência são Story 2.3.
- Não construir superfície Shiny — o formulário de setup é Story 2.2.
- Não parsear nem definir schema de `tiers` / `recommendation_policy` — a forma canônica é do `recommend_fast()` (Story 3.2). Só `league_rules` aqui.
- Não hashear a config de liga (`league_rules_hash` removido pela Sprint Change Proposal 2026-08-31).
- Não cadastrar times nem `user_team` (Story 2.2). Não re-pontuar jogadores — scoring é só identidade exibível.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Referência viável | `config/league_rules.yml` desserializado | `parse_league_config()` → objeto `identical()` a `reference_league_config()`; `validate_league_envelope()` → `list()` |
| YAML não é mapa | não-lista / sem nomes / vazio | `domain_error("league_config_malformado")` |
| Campo ausente | sem `teams` | `domain_error("league_config_campo_ausente", details$campo)` |
| Tipo inválido | `rounds: "quinze"` | `domain_error("league_config_tipo_invalido", details$campo)` |
| Times fora do envelope | `teams=7` ou `teams=15` | achado `league_times_fora_do_envelope`, `grupo="times_rounds"` |
| Rounds ≠ 15 | `rounds=16` | achado `league_rounds_invalido`, `grupo="times_rounds"` |
| Titulares ≠ composição V1 | `RB=1` (soma 8) ou `RB=3` (soma 10) | achado `league_slots_invalido` com `esperado`/`encontrado`, `grupo="slots_flex"` |
| Reservas ≠ 6 / roster não preenche os rounds | `bench_size=5` | achados `league_reservas_invalido` e `league_roster_nao_preenche_rounds`, `grupo="slots_flex"` |
| FLEX inválido | `flex_eligibility=["RB","TE"]` ou `[]` | achado `league_flex_invalido`, `grupo="slots_flex"` |
| Múltiplas violações | `teams=7` + `bench_size=5` + FLEX inválido | todas na lista, cada uma classificada, ordem estável entre execuções |
| Scoring compatível | `scoring_config_hash(ativo) == metadata$scoring_hash` | `league_scoring_compat_finding()` → `NULL` |
| Scoring divergente | hashes diferentes | achado `severity="aviso"` `league_scoring_incompativel` (`esperado`/`encontrado`), `grupo="scoring"` — não bloqueia |
| Scoring ativo indisponível | `active_scoring_parsed` = `domain_error` | achado `severity="aviso"` `league_scoring_indisponivel` preservando `code`/`message` |

</frozen-after-approval>

## Code Map

- `R/domain_league_config.R` — **novo**, domínio puro. `parse_league_config()`, `validate_league_envelope()`, `reference_league_config()`, `league_scoring_compat_finding()` + helpers internos.
- `config/league_rules.yml` — **novo**, YAML versionado (`config_version`), comentário-cabeçalho no padrão de `config/snapshot_pipeline.yml`.
- `R/adapter_files_snapshot.R` — `read_scoring_config(path)`: leitor genérico de mapa-YAML. Reusar para `league_rules.yml`; não chamado pelo domínio puro.
- `R/domain_snapshot_hash.R` — `verify_scoring_hash()`, `scoring_config_hash()`. Reusar em `league_scoring_compat_finding()`; não alterar.
- `R/domain_snapshot_quality.R` — `snapshot_quality_finding()` e `snapshot_quality_sort()` (internos, mesmo namespace). Reusar formato de achado e ordenação canônica.
- `R/domain_snapshot.R` — `positions_v1`. Reusar para validar `flex_eligibility` e os nomes de slots.
- `R/domain_errors.R` — `domain_error()`, `is_domain_error()`. Reusar.
- `NAMESPACE` — gerado por roxygen (`devtools::document()`); exportar as 4 funções públicas.
- `tests/testthat/test-domain_league_config.R` — **novo**. Roda fora de Shiny/SQLite.
- Arquitetura: AD-7 (config é dado validado, sem hashing), AD-1 (domínio puro); PRD LEAGUE-001..004, LEAGUE-007; epic-2-context.md §"Requirements & Constraints".

## Tasks & Acceptance

**Execution:**
- [x] `config/league_rules.yml` — `config_version: "league-config-v1"`, `teams: 12`, `rounds: 15`, `scoring: full_ppr`, `starter_slots: {QB: 1, RB: 2, WR: 2, TE: 1, FLEX: 1, K: 1, DST: 1}`, `flex_eligibility: [RB, WR]`, `bench_size: 6`.
- [x] `R/domain_league_config.R` — `parse_league_config(parsed_yaml)` → objeto canônico (`config_version` chr; `teams`/`rounds`/`bench_size` int; `scoring` chr; `starter_slots` vetor int nomeado; `flex_eligibility` chr) ou `domain_error` (`league_config_malformado` / `_campo_ausente` / `_tipo_invalido`); coage numéricos de valor inteiro para `integer`.
- [x] `R/domain_league_config.R` — `validate_league_envelope(config)` → lista ordenada de achados bloqueantes (`snapshot_quality_finding` + `snapshot_quality_sort`), cada um com `details$grupo`. Checa `teams ∈ 8:14`; `rounds == 15`; `starter_slots` == composição exata do V1; `bench_size == 6`; `sum(starter_slots) + bench_size == rounds`; `flex_eligibility` subconjunto não-vazio de `{RB, WR}`.
- [x] `R/domain_league_config.R` — `reference_league_config()` (objeto idêntico ao parse do YAML de referência) e `league_scoring_compat_finding(active_scoring_parsed, snapshot_metadata)` → `NULL` ou achado `"aviso"` reusando `verify_scoring_hash()`.
- [x] `NAMESPACE` — `export()` das 4 funções públicas adicionado à mão (o `NAMESPACE` do projeto não é gerido por roxygen; convenção das Stories 1.5–1.7). Detalhe em `deferred-work.md`.
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` — anexado: parsing/schema de `tiers` e `recommendation_policy` deferido para o Epic 3 (Story 3.2) + 2 notas.
- [x] `tests/testthat/test-domain_league_config.R` — cobre a I/O & Edge-Case Matrix; teste de pureza (grep sem I/O); teste de determinismo (2 execuções → `identical`); teste que `config/league_rules.yml` parseia, é viável e bate com `reference_league_config()`.

**Acceptance Criteria:**
- Given `R/domain_league_config.R`, when inspecionado, then não abre arquivos, não importa `yaml`/`jsonlite`, não lê o clock.
- Given uma config com 8–14 times, exatamente 15 rounds, a composição exata de 9 titulares, 6 reservas que somam os 15 rounds e FLEX só RB/WR, when `validate_league_envelope()` roda, then a lista de achados é vazia.
- Given qualquer violação de envelope, when `validate_league_envelope()` roda, then há um achado bloqueante por violação com `details$grupo` apontando o grupo afetado, e a ordem é estável entre execuções.
- Given um snapshot cujo `scoring_hash` diverge do scoring ativo, when `league_scoring_compat_finding()` roda, then o achado tem `severity = "aviso"` e não bloqueia.

## Design Notes

- **Composição fixa de titulares:** FR7 fixa `QB, 2 RB, 2 WR, TE, FLEX, K, D/ST` — não é "9 titulares quaisquer". O achado reporta `esperado`/`encontrado`. Ver "Ask First".
- **Domínio recebe o desserializado, adapter só lê:** mesmo split das stories 1.2/1.5. `parse_league_config()` valida forma e tipo; testa sem disco.
- **Achado reusa o formato da 1.5** (`list(code, severity, message, details)` + `snapshot_quality_sort()`) para não criar um segundo vocabulário. `details$grupo` posiciona a mensagem na superfície da 2.2.
- **Scoring compat é aviso, não gate (AD-6):** `verify_scoring_hash()` já devolve `domain_error` no mismatch; aqui só é dobrado num achado `"aviso"`.

## Verification

**Commands:**
- `Rscript -e 'devtools::document()'` — `NAMESPACE` atualizado, sem warning.
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint_package()'` — sem lint.
- Pureza: `grep -nE "read|file\\.|yaml|jsonlite|Sys\\.|fromJSON|readBin" R/domain_league_config.R` — só nomes de variável/comentário.
- Determinismo: `validate_league_envelope()` duas vezes sobre a mesma entrada inválida → `identical()`, inclusive sob `LC_COLLATE=C`.
