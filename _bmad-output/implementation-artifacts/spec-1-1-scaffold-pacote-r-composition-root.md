---
title: 'Story 1.1 — Scaffold do pacote R e composition root'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: '1d13118b028e1eb213cc52ef8ba4160a4a47ef5b'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O repositório não tem código de aplicação. Nenhuma story do Epic 1 avança sem um pacote R reproduzível, um composition root Shiny que sobe local com segurança e um harness de testes que roda fora de Shiny/SQLite.

**Approach:** Criar a estrutura semente do pacote conforme a arquitetura hexagonal (DESCRIPTION, renv, `app.R`, `R/`, `scripts/`, `config/`, `inst/schema/`, `tests/`). `app.R` é só composition root: bind em loopback, guarda de colisão de porta. Uma função de domínio pura mínima (`normalize_position()`) e seu teste estabelecem o harness `testthat`. `.lintr` impõe `snake_case`.

## Boundaries & Constraints

**Always:**
- `app.R` só compõe: sem regra de negócio, sem I/O de dados. Bind exclusivo em `127.0.0.1`, URL impressa no console.
- Colisão de porta → mensagem acionável + exit não-zero. Nunca outra porta, nunca interface pública.
- Domínio puro e determinístico: não importa `shiny`, `DBI`, `RSQLite`, `yaml`, filesystem, clock nem APIs reativas. Erros de domínio são estruturados (`code` estável + mensagem PT-BR + details), sem exceção não tratada.
- `renv::restore()` num clone limpo deixa o projeto executável.

**Ask First:**
- Se `shiny@1.14.0` não instalar no R 4.6.1 disponível, parar e perguntar antes de usar outra versão.

**Never:**
- Não criar arquivos vazios de camadas não usadas (`adapter_sqlite_*`, `application_*`, `ui_*`) — as pastas bastam.
- Não implementar parser, hashing, CLI, validação de qualidade nem design tokens (Stories 1.2–1.7).
- Não adicionar `ffanalytics`/`DBI`/`RSQLite` ao `renv.lock` agora (entram em 1.4, 2.3).
- Não commitar `config/config.yml` (contém Bearer token da NFL).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Boot normal | porta livre | Shiny sobe em `127.0.0.1:<porta>`, URL no console | N/A |
| Colisão de porta | porta ocupada | encerra com exit não-zero, mensagem cita a porta e a saída | acionável, sem fallback de porta |
| `normalize_position` variação D/ST | `"D/ST"`, `"dst"`, `"DEF"` | retorna `"DST"` | N/A |
| `normalize_position` canônica | `"QB"` | retorna `"QB"` | N/A |
| `normalize_position` fora do V1 | `"LB"` | erro de domínio (`code` + mensagem PT-BR) | condição de erro, sem exceção |

</frozen-after-approval>

## Code Map

Greenfield — nada de código de aplicação existe. Referência: estrutura semente e convenções em `epic-1-context.md` (seções Technical Decisions e Requirements).

- `config/config.yml` -- existe, ignorado, carrega segredo NFL. Não versionar.
- `config/score_settings.yml` -- existe: scoring Full PPR de referência. Deve passar a ser versionado.
- `.gitignore` -- hoje `config/` (esconde o segredo mas também o `score_settings.yml`); estreitar para `config/config.yml`.
- Stack disponível: R 4.6.1, renv 1.2.3. Arquitetura fixa Shiny 1.14.0.

## Tasks & Acceptance

**Execution:**
- [x] `.gitignore` -- estreitar para `config/config.yml` + artefatos R padrão (`.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `config/*.local.yml`) -- versionar `score_settings.yml`/schemas sem vazar o token.
- [x] `DESCRIPTION` -- pacote com `Depends: R (>= 4.6)`, `Imports: shiny (>= 1.14.0)`, `Suggests: testthat, devtools, lintr, config, roxygen2`.
- [x] `renv` (`renv.lock`, `.Rprofile`, `renv/`) -- `renv::init(bare = TRUE)` + `renv::install("shiny@1.14.0")` + `renv::snapshot()`.
- [x] `R/domain_errors.R` -- `domain_error(code, message, details = list())` retornando condição classificada; `#' @export`.
- [x] `R/domain_snapshot.R` -- `normalize_position(raw)` pura: canônico `c("QB","RB","WR","TE","K","DST")`, aliases D/ST `c("DST","D/ST","D-ST","DEF","DEFENSE")` → `"DST"`, vazio/whitespace → `domain_error("posicao_invalida")`, fora do conjunto → `domain_error("posicao_fora_do_v1")`; mensagens PT-BR acentuadas; `#' @export`.
- [x] `R/app_bootstrap.R` -- `resolve_bind_port(raw)` pura (inteiro 1–65535 ou `domain_error("porta_invalida")`) e `bind_host()` = `"127.0.0.1"`; `#' @export`.
- [x] `app.R` -- composition root: `resolve_bind_port(getOption("fdwr.port", 3939L))`, probe `httpuv` em `bind_host()`, erro do probe discriminado (`address already in use` → mensagem acionável + `quit(status = 1L)`; outro erro → propaga verbatim), `shiny::runApp(host = bind_host(), port = <porta>, launch.browser = FALSE)`.
- [x] `tests/testthat.R` + `tests/testthat/test-domain_snapshot.R` + `test-domain_errors.R` + `test-app_bootstrap.R` -- cobrir a matriz e os helpers puros; roda fora de Shiny/SQLite.
- [x] `.lintr` -- `object_name_linter("snake_case")`, `line_length_linter(120L)`, `assignment_linter()`; `object_usage_linter` ativo em `R/`, desligado só para `app.R`.
- [x] `.Rbuildignore` -- excluir `_bmad`, `_bmad-output`, `docs`, `.claude`, `.agents`, `config`.
- [x] `config/config.yml.example` -- esqueleto das chaves (`leagueId`, `teamId`, `week`, `season`, `authToken`) com placeholders, sem credencial real; versionado.
- [x] `scripts/.gitkeep`, `inst/schema/.gitkeep`, `README.md` -- pastas semente vazias + passos de clone limpo (copiar `config/config.yml.example`).

**Acceptance Criteria:**
- Given um clone limpo, when `renv::restore()` e `Rscript -e 'shiny::runApp("app.R")'`, then o app sobe em loopback, imprime a URL e não escuta em interface pública.
- Given o repositório, when inspecionado, then `DESCRIPTION`, `renv.lock` e as pastas `R/`, `scripts/`, `config/`, `inst/schema/`, `tests/` existem conforme a semente estrutural.
- Given a porta padrão ocupada, when o app inicia, then falha com mensagem acionável e exit não-zero, sem trocar de porta nem expor publicamente.
- Given o projeto recém-clonado, when `devtools::test()`, then a suíte `testthat` roda e passa, fora de Shiny/SQLite.
- Given o código-fonte, when `lintr::lint_package()`, then não há violações de `snake_case` nem das convenções configuradas.

## Design Notes

- **`config/` no git:** estreitar o ignore para `config/config.yml` versiona `score_settings.yml` e os schemas YAML que AD-7 exige, sem vazar o token. `config/config.yml.example` documenta o esquema para o clone limpo. Migrar o token para variável de ambiente fica para story futura.
- **Guarda de porta:** `resolve_bind_port()` (puro) valida o inteiro 1–65535. `app.R` então faz um probe `httpuv::startServer(bind_host(), port, list())`; sucesso → `stopServer()` e segue. Erro do probe: só emite "Porta %d em uso. Libere-a ou defina options(fdwr.port=) e reinicie." + `quit(status = 1L, save = "no")` quando `conditionMessage()` casa `address already in use`; qualquer outro erro é propagado verbatim para não mascarar a causa real. `# ponytail:` a janela TOCTOU entre o probe e o `runApp` é irrelevante num app local de usuário único.
- **`bind_host()`** devolve a constante `"127.0.0.1"` e é usada no probe e em `runApp(host=)`; o teste pina o invariante loopback-only (AD-10).
- `normalize_position` é a menor função de domínio real e alimenta 1.2/1.5 — mapa + passthrough + erro, sem tocar em parsing de arquivo. Entrada vazia/whitespace → `posicao_invalida`; fora do V1 → `posicao_fora_do_v1`.

## Spec Change Log

- **2026-08-30 — review round 1 (patches, sem loopback de spec).** Blind-hunter, edge-case-hunter e verification-gap revisaram o diff. Todos os 5 critérios de aceite passaram na verificação independente; os achados foram melhorias de robustez com correção inequívoca, aplicadas como patches:
  - `app.R`: probe de porta passou a discriminar `address already in use` de outros erros de bind (antes: todo erro virava "Porta em uso"); `quit(status = 1L)` explícito; validação de porta 1–65535 e a constante de host extraídas para `R/app_bootstrap.R` (`resolve_bind_port`, `bind_host`) com testes — fecha o gap de verificação do bind loopback-only.
  - `R/domain_snapshot.R`: entrada vazia/whitespace → `posicao_invalida`; `dst_aliases` reduzido a `c("DST","D/ST","D-ST","DEF","DEFENSE")` (`"D"` isolado era amplo demais).
  - Mensagens PT-BR voltadas ao operador com acentuação correta.
  - Novo `test-domain_errors.R` (vetor de classes, `details`, `is_domain_error`).
  - `DESCRIPTION`: `Depends: R (>= 4.6)`, `Imports: shiny (>= 1.14.0)`, `#' @export` nas funções de domínio (`devtools::document()` idempotente sobre o `NAMESPACE` mantido à mão).
  - `.gitignore`: artefatos R padrão. `config/config.yml.example` versionado sem credencial. `.lintr`: `object_usage_linter` ativo em `R/`, desligado só para `app.R`.
  - **KEEP:** estrutura de `domain_error()` (condição S3 `c(code,"fdwr_domain_error","error","condition")`, erro-como-valor); `.Rprofile` com `options(shiny.autoload.r = FALSE)`; setup `renv`; harness fora de Shiny/SQLite.
  - **Adiados** (`deferred-work.md`): snapshot `renv` tipo `"all"`; trim de whitespace unicode; guard automatizado do git-ignore de `config/config.yml`.

## Verification

**Commands:**
- `Rscript -e 'renv::restore(prompt = FALSE)'` -- restaura sem erro.
- `Rscript -e 'devtools::test()'` -- 0 falhas, 0 warnings.
- `Rscript -e 'lintr::lint_package()'` -- nenhum lint.
- Colisão de porta: ocupar 3939 com `httpuv::startServer`, rodar `Rscript -e 'shiny::runApp("app.R")'`, conferir saída com "Porta 3939 em uso" e status ≠ 0.
- Boot manual: `Rscript -e 'shiny::runApp("app.R")'` em background; `curl -sI http://127.0.0.1:3939` responde; requisição a IP não-loopback recusa.

## Suggested Review Order

**Composition root e boot seguro**

- Ponto de entrada: lê a porta, valida, e só então tenta subir — nada de regra de negócio aqui.
  [`app.R:11`](../../app.R#L11)
- Discriminação do erro de bind: "Porta em uso" só quando a mensagem casa; qualquer outro erro é propagado verbatim.
  [`app.R:25`](../../app.R#L25)
- `runApp` sempre em `bind_host()` (loopback), `launch.browser = FALSE`, porta fixa.
  [`app.R:49`](../../app.R#L49)

**Helpers puros e testáveis do bootstrap**

- `resolve_bind_port()` — validação pura (inteiro 1–65535) devolvendo valor ou `domain_error`; tira I/O e checagem do `app.R`.
  [`app_bootstrap.R:12`](../../R/app_bootstrap.R#L12)
- `bind_host()` — constante `"127.0.0.1"` isolada num ponto único, pinada por teste (invariante AD-10).
  [`app_bootstrap.R:36`](../../R/app_bootstrap.R#L36)

**Núcleo de domínio semente**

- `domain_error()` — falha de domínio é um valor (condição S3 `c(code, "fdwr_domain_error", "error", "condition")`), nunca exceção.
  [`domain_errors.R:17`](../../R/domain_errors.R#L17)
- `normalize_position()` — mapa + passthrough + erro; vazio → `posicao_invalida`, fora do V1 → `posicao_fora_do_v1`.
  [`domain_snapshot.R:20`](../../R/domain_snapshot.R#L20)
- Lista de aliases D/ST enxuta e defensável (sem `"D"` isolado).
  [`domain_snapshot.R:11`](../../R/domain_snapshot.R#L11)

**Contrato de pacote e estilo**

- `DESCRIPTION` — floors de versão (`R >= 4.6`, `shiny >= 1.14.0`) e `Suggests` mínimos.
  [`DESCRIPTION:14`](../../DESCRIPTION#L14)
- `.lintr` — `snake_case` global; `object_usage_linter` ativo em `R/`, desligado só para `app.R`.
  [`.lintr:1`](../../.lintr#L1)
- `.gitignore` — estreitado para `config/config.yml` (o Bearer token) + artefatos R padrão.
  [`.gitignore:1`](../../.gitignore#L1)

**Testes e periféricos**

- `test-app_bootstrap.R` — portas inválidas e o pin do host loopback.
  [`test-app_bootstrap.R:1`](../../tests/testthat/test-app_bootstrap.R#L1)
- `test-domain_snapshot.R` — matriz completa de `normalize_position` (aliases novos, vazio, fora do V1).
  [`test-domain_snapshot.R:1`](../../tests/testthat/test-domain_snapshot.R#L1)
- `test-domain_errors.R` — vetor de classes, `details`, `is_domain_error()`.
  [`test-domain_errors.R:1`](../../tests/testthat/test-domain_errors.R#L1)
- `config/config.yml.example` — esquema versionado, sem credencial; README manda copiar para `config/config.yml`.
  [`config.yml.example:1`](../../config/config.yml.example#L1)
