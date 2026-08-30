---
title: 'Story 1.6 — Design tokens base e tema escuro'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: '340233f6f1d953ad41d3c4a0765d004fd205d12c'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Não há camada visual. Cada superfície (a partir da Story 1.7) inventaria suas próprias cores e medidas. Os tokens de `DESIGN.md` precisam ser materializados uma vez, com o tema escuro único aplicado no composition root, para que nenhuma superfície use valor visual fora dos tokens.

**Approach:** `www/theme.css` reproduz os tokens do frontmatter de `DESIGN.md` como CSS custom properties (`--color-*`, `--space-*`, `--rounded-*`, `--type-*`) e aplica um reset mínimo de estética de terminal (fundo `canvas`, pilha monoespaçada do sistema, `ink`, escala tipográfica, anel de foco). Um helper fino `R/ui_theme.R` injeta o stylesheet no `fluidPage` do `app.R`. Testes puros calculam os contrastes WCAG dos valores e casam cada token de `DESIGN.md` com a custom property correspondente.

## Boundaries & Constraints

**Always:**
- O frontmatter YAML de `DESIGN.md` é a **única fonte** dos valores. `www/theme.css` os reproduz 1:1 como custom properties em `:root`; nenhum valor de cor/tipografia/espaçamento/raio hard-coded fora das custom properties.
- Tema escuro único: sem toggle, sem `@media (prefers-color-scheme)`, sem paleta clara.
- Contraste WCAG 2.2 AA nas combinações permitidas: `ink` sobre `canvas`/`surface`/`surface-raised` ≥ 4.5:1; `ink-muted` sobre as mesmas ≥ 4.5:1; `focus`/`action`/`warning`/`danger` como indicador não textual ≥ 3:1; `action-ink` sobre `action` ≥ 4.5:1.
- `app.R` continua "só compõe": a chamada de tema é uma linha declarativa, sem lógica; o boot (porta, loopback) não muda.
- `R/ui_theme.R` é domínio-neutro: sem regra de negócio, sem I/O além de referenciar o asset estático.
- O R **não** recadastra os valores dos tokens (hex, px) — referencia o CSS / `DESIGN.md`.

**Ask First:**
- Se algum par de contraste não atingir o limiar AA ao ser medido — parar e perguntar antes de ajustar um valor de `DESIGN.md` (os valores são `[ASSUMPTION]` no doc; mudá-los é decisão de UX).
- Se `bslib`/Bootstrap for necessário para o Shiny renderizar de forma aceitável — decidir com o usuário (a intenção é CSS custom puro, sem Bootstrap).

**Never:**
- Não construir nenhuma superfície (Story 1.7+). 1.6 entrega só os tokens, o reset e a fiação.
- Não adicionar `bslib`/`sass`/`thematic` ao `renv.lock` sem "Ask First".
- Não introduzir dependência de fonte web (a pilha é monoespaçada do sistema).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tema carregado | `app.R` sobe | o `<head>` linka `theme.css`; `:root` define todas as custom properties; `body` usa `var(--color-canvas)` / `var(--color-ink)` / pilha mono | N/A |
| Contraste medido | valores de `DESIGN.md` | todo par permitido atinge o limiar AA (teste calcula a razão) | falha do teste se algum par < limiar |
| Completude de token | frontmatter de `DESIGN.md` × `theme.css` | todo token `colors` / `spacing` / `rounded` → `--<nome>` no CSS com valor idêntico | falha do teste se faltar/divergir |
| Sem modo claro | `theme.css` | nenhum `prefers-color-scheme`, nenhuma classe/atributo de tema alternativo | falha do teste se presente |
| Helper de tema | `fdwr_theme_head()` | devolve uma `shiny.tag` / `htmltools` com o `<link>` de `theme.css` | N/A |

</frozen-after-approval>

## Code Map

- `_bmad-output/planning-artifacts/ux-designs/ux-Fantasy Draft War Room-2026-08-29/DESIGN.md` — frontmatter YAML: `colors`, `typography`, `rounded`, `spacing`, `components`. **Fonte única** dos valores.
- `app.R` — composition root; hoje um `fluidPage` mínimo (`shiny::tags$h1(...)`). Recebe a chamada de tema.
- `R/app_bootstrap.R` — padrão dos helpers puros do composition root; `R/ui_theme.R` segue o mesmo estilo (roxygen, `#' @export`).
- `.lintr` / `.Rbuildignore` — `.Rbuildignore` já exclui `_bmad-output`; garantir que `www/` não seja excluído (asset de runtime).
- `R/ui_theme.R` — **novo**: `fdwr_theme_head()`.
- `www/theme.css` — **novo**: custom properties + reset de terminal.
- `tests/testthat/helper-contrast.R` — **novo**: `wcag_relative_luminance()`, `wcag_contrast_ratio()` puros.
- `tests/testthat/test-ui_theme.R` — **novo**.
- Arquitetura: convenções ("tokens de `DESIGN.md` são a única fonte visual"); UX `DESIGN.md` (Colors, Typography, Layout & Spacing, Shapes, Elevation).

## Tasks & Acceptance

**Execution:**
- [ ] `www/theme.css` — `:root` com `--color-canvas … --color-danger` + `--color-action-ink`; `--space-1..5`, `--space-gutter`; `--rounded-sm/md/full`; `--type-display/data/label` (family, size, weight, line-height, letter-spacing); `--focus-ring-width`, `--focus-ring-color` — valores exatos de `DESIGN.md`. Reset: `*{box-sizing:border-box}`, `body{margin:0;background:var(--color-canvas);color:var(--color-ink);font-family/size/weight/line-height de --type-data}`, classes `.t-display/.t-data/.t-label`, `:focus-visible{outline:var(--focus-ring-width) solid var(--focus-ring-color)}`. Sem `@media (prefers-color-scheme)`; nenhuma cor fora de `var(--…)`.
- [ ] `R/ui_theme.R` — `fdwr_theme_head()` → `htmltools::tags$head(htmltools::tags$link(rel = "stylesheet", href = "theme.css"))`; `#' @export`. Sem estado, sem I/O.
- [ ] `app.R` — `source("R/ui_theme.R")` (padrão do composition root) e inserir `fdwr_theme_head()` no `fluidPage`; nada mais muda no boot.
- [ ] `tests/testthat/helper-contrast.R` — `wcag_relative_luminance(hex)` e `wcag_contrast_ratio(a, b)` puros (fórmula WCAG 2.x).
- [ ] `tests/testthat/test-ui_theme.R` — (a) todo token `colors`/`spacing`/`rounded` de `DESIGN.md` (lido do frontmatter via `yaml`) aparece em `www/theme.css` como `--<nome>` com valor idêntico; (b) contraste: `ink`×{canvas,surface,surface-raised} ≥ 4.5, `ink-muted`×{mesmas} ≥ 4.5, `focus`/`action`/`warning`/`danger`×canvas ≥ 3, `action-ink`×`action` ≥ 4.5; (c) `theme.css` sem `prefers-color-scheme` e sem segundo bloco de tema; (d) `fdwr_theme_head()` devolve uma tag com o `<link>` de `theme.css`.
- [ ] `R/ui_theme.R` roxygen — nota curta: `DESIGN.md` é a fonte, `theme.css` a materialização, o teste (a) é o guarda de consistência.

**Acceptance Criteria:**
- Given o `app.R`, when ele sobe, then o `<head>` linka `theme.css` e `:root` expõe todas as custom properties de cor/espaçamento/raio/tipografia de `DESIGN.md`.
- Given os pares de cor permitidos, when o contraste é medido pelo teste, then `ink`/`ink-muted` sobre as surfaces atingem ≥ 4.5:1 e `focus`/`action`/`warning`/`danger` como indicador não textual atingem ≥ 3:1.
- Given `www/theme.css`, when inspecionado, then não há `@media (prefers-color-scheme)`, nenhum toggle de tema, nenhum valor de cor fora de `var(--…)` / da definição em `:root`.
- Given o frontmatter de `DESIGN.md`, when comparado ao CSS, then todo token declarado tem uma custom property com o mesmo valor (o teste falha se divergir).
- Given `devtools::test()` num clone limpo, then a suíte passa — o teste de tema lê o arquivo CSS e calcula, sem navegador.

## Spec Change Log

- **Review round 1 (2026-08-30) — sem loopback de spec.** Intent congelado atingido (tema escuro carrega, `<head>` linka um `theme.css`, tokens em `:root`, contraste AA). Ajustes de implementação e correção de documento:
  - **Serving via `addResourcePath`.** A nota "www/ na raiz" assumia que `shiny::runApp("app.R")` monta `./www/` automaticamente. Falso: o `app.R` compõe um **objeto `shinyApp`** (não um diretório de app), e o Shiny só serve `./www` ao carregar um diretório/arquivo de app. Como o boot do `app.R` não pode mudar, `fdwr_theme_head()` registra `shiny::addResourcePath("fdwr-theme", "www")` (efeito global idempotente) e linka `href = "fdwr-theme/theme.css"`. `"www"` é relativo ao working directory do processo (a raiz do repo) — a mesma premissa das chamadas `source()` relativas do `app.R`. `www/theme.css` permanece na raiz do repo (path congelado).
  - `htmltools` fica em `Suggests` (não `Imports`): `shiny` já reexporta `tags` e provê `addResourcePath`; `htmltools::doRenderTags` só é usado por um teste.
  - `theme.css` reset endurecido: `html { background }`, `color-scheme: dark`, `box-sizing` em `::before/::after`, `outline-offset` no anel de foco.
  - Testes ampliados: completude cobre `typography` e `components.focus-ring.width`; contraste cobre os pares sobre `surface`/`surface-raised`; novos testes para as regras de reset, ausência de literal de cor fora de `:root`, âncoras do `wcag_contrast_ratio`, e um teste de integração (`callr`) que sobe o `app.R` e faz `GET` no stylesheet.

## Design Notes

- **CSS custom puro, sem `bslib`/Bootstrap:** a estética é "terminal, não dashboard"; brigar com a cascata do Bootstrap custaria mais que um `theme.css` de ~60 linhas. `bslib` fica anotado como alternativa se o Shiny exigir (Ask First).
- **`www/` na raiz, servido por `addResourcePath`:** o `app.R` sobe um objeto `shinyApp`, então `./www/` **não** é montado automaticamente. `fdwr_theme_head()` registra `shiny::addResourcePath("fdwr-theme", "www")` (idempotente, efeito global) e linka `href = "fdwr-theme/theme.css"` — o boot do `app.R` (porta, loopback) não muda. `"www"` resolve relativo ao working directory do processo (raiz do repo).
- **Contraste no teste, não à mão:** `wcag_contrast_ratio()` puro em `helper-contrast.R`; o teste pina os limiares de AD-3 / `DESIGN.md`. Par que falha → renegociar o valor em `DESIGN.md` (Ask First), nunca afrouxar o teste.
- **Guarda token↔CSS:** o teste (a) lê o frontmatter YAML de `DESIGN.md` e casa cada token com uma custom property — é o que dá dente ao "nenhum valor fora dos tokens" na camada de definição. A conformidade das superfícies é responsabilidade de cada story de superfície.
- **`components.*` de `DESIGN.md`** são referências a outros tokens (`{colors.surface}`), não valores novos; classes por componente entram com cada superfície. Emitir as custom properties de componente já resolvidas é opcional (pode ajudar a 1.7).
- Valores já conferidos manualmente: todos os pares AA passam com folga — `ink`/`canvas` ≈ 16:1, `ink-muted`/`surface` ≈ 6:1, `focus`/`canvas` ≈ 9:1, `danger`/`canvas` ≈ 7:1, `action-ink`/`action` ≈ 10:1.

## Verification

**Commands:**
- `Rscript -e 'devtools::test()'` — 0 falhas, 0 warnings; o teste de tema não abre navegador.
- `Rscript -e 'lintr::lint_package()'` — sem lint.
- `Rscript -e 'shiny::runApp("app.R")'` em background + `curl -s http://127.0.0.1:3939 | grep 'fdwr-theme/theme.css'` — `<head>` linka o stylesheet; `curl -sI http://127.0.0.1:3939/fdwr-theme/theme.css` → 200.

**Manual checks:**
- Abrir o app: fundo `#0B0F14`, texto `#E7EDF3`, pilha monoespaçada, anel de foco azul ao tabular.

## Suggested Review Order

**A fiação — como o CSS chega no `<head>`**

- `fdwr_theme_head()` — registra o prefixo de resource-path (`addResourcePath`, idempotente) e devolve o `<head>` com o `<link>`. O desvio da spec original (sem auto-serve de `./www`) está documentado aqui e no Spec Change Log.
  [`ui_theme.R:26`](../../R/ui_theme.R#L26)
- `app.R` — uma linha (`fdwr_theme_head()`) no `fluidPage`; o boot (porta, loopback) não muda.
  [`app.R:43`](../../app.R#L43)

**Os tokens — `DESIGN.md` 1:1**

- `:root` com todas as custom properties (`--color-*`, `--space-*`, `--rounded-*`, `--type-*`, `--focus-ring-*`) + `color-scheme: dark`.
  [`theme.css:19`](../../www/theme.css#L19)
- Reset de terminal: `html`/`body` no canvas, pilha mono, `:focus-visible` com `outline-offset`.
  [`theme.css:81`](../../www/theme.css#L81)

**Os guardas de teste — o que mantém `DESIGN.md` como fonte única**

- `wcag_contrast_ratio()` / `wcag_relative_luminance()` puros (com âncoras `#000`/`#fff` ≈ 21).
  [`helper-contrast.R:1`](../../tests/testthat/helper-contrast.R#L1)
- Teste (a): todo token de `colors`/`spacing`/`rounded`/`typography`/`focus-ring` do frontmatter ↔ CSS.
  [`test-ui_theme.R:45`](../../tests/testthat/test-ui_theme.R#L45)
- Teste (b): contrastes AA de todos os pares que `DESIGN.md` exige (incl. `warning` como texto ≥ 4.5).
  [`test-ui_theme.R:80`](../../tests/testthat/test-ui_theme.R#L80)
- Teste (literais) + (reset): nenhuma cor fora do `:root`; `body`/`:focus-visible` usam os tokens.
  [`test-ui_theme.R:137`](../../tests/testthat/test-ui_theme.R#L137)
- Teste (integration) via `callr`: sobe o `app.R`, faz GET do href renderizado, confere o corpo do CSS.
  [`test-ui_theme.R:150`](../../tests/testthat/test-ui_theme.R#L150)
