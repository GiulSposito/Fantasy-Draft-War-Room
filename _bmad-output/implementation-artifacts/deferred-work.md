# Trabalho adiado

Itens reais levantados durante o build, fora do escopo da story que os expôs. Cada um espera atenção focada depois.

- source_spec: `spec-1-1-scaffold-pacote-r-composition-root.md`
  summary: O `renv.lock` usa snapshot tipo `"all"` (171 pacotes, inclui a árvore de `devtools`) em vez de `"explicit"`.
  evidence: Reprodutível e funcional (`renv::status()` limpo, `renv::restore()` no-op), mas o lock é grande e sensível a churn. Trocar para `"explicit"` exigiu incluir `Suggests` no fecho transitivo, o que não resolveu. Revisitar quando a superfície de dependências estabilizar (pós-Epic 2), possivelmente movendo `devtools`/`lintr` para fora do lock.

- source_spec: `spec-1-1-scaffold-pacote-r-composition-root.md`
  summary: `normalize_position()` não remove espaço em branco não-ASCII (NBSP, espaços unicode) antes de normalizar.
  evidence: `trimws()` padrão só trata `[ \t\r\n]`; uma posição como `" QB"` seria rejeitada como `posicao_fora_do_v1`. A normalização real de dados de fontes externas pertence ao parser do bundle (Story 1.2), com estratégia unicode consistente.

- source_spec: `spec-1-1-scaffold-pacote-r-composition-root.md`
  summary: Nenhum guard automatizado (teste, CI ou pre-commit hook) garante que `config/config.yml` permaneça git-ignored.
  evidence: O arquivo carrega um Bearer token da NFL e hoje está corretamente ignorado (verificado com `git check-ignore`), mas um erro de digitação futuro no `.gitignore` que re-exponha o arquivo não seria detectado por `devtools::test()` nem `lintr`. É uma fronteira de vazamento de credencial. A mitigação estrutural (mover o token para variável de ambiente) já está anotada como decisão de story futura.

- source_spec: `spec-1-2-contrato-schema-snapshot-bundle.md`
  summary: `validate_metadata()` só checa presença dos metadados — não valida formato (hash SHA-256 hex minúsculo, timestamp ISO-8601 UTC).
  evidence: Um `scoring_hash`/`content_hash` malformado ou um `generated_at` fora do padrão passa direto para o objeto canônico. Os critérios de aceite da 1.2 pedem só "exigidos e expostos"; a validação de formato dos hashes é candidata natural da Story 1.3 (hashing) e a de outros campos, da Story 1.5.

- source_spec: `spec-1-2-contrato-schema-snapshot-bundle.md`
  summary: A validação estrutural de CSV além de "parseia" (linhas irregulares, delimitador errado, conteúdo não-tabular) é fina.
  evidence: `utils::read.csv` quase nunca lança em CSV estruturalmente quebrado, então o caminho `bundle_formato_invalido` para CSV é quase inalcançável (só o de JSON é exercitado). Revisitar com validação de shape pós-leitura se bundles reais baterem nisso.

- source_spec: `spec-1-2-contrato-schema-snapshot-bundle.md`
  summary: Tokens de nulo em texto ("null", "none") em células numéricas opcionais são rejeitados como `snapshot_tipo_invalido`.
  evidence: `read.csv` já converte `NA` sem aspas para `NA`, mas `"null"`/`"none"` de CSV escrito à mão viram erro em vez de `NA`. A normalização de dados de fontes reais pertence ao CLI (1.4) ou a um passo de limpeza (1.5).

- source_spec: `spec-1-3-hash-canonico-manifesto-bundle.md`
  summary: `canonical_json()` usa decimal fixo de 10 casas; a precisão suficiente para o `draft_state_hash` do Epic 4 (VOR, points) ainda não foi decidida.
  evidence: 10 casas são exatas para os pesos de scoring (`0.04`, `-2.0`). Um reviewer sugeriu 15–17 casas para round-trip completo de `double`. A decisão final de precisão pertence ao Epic 4, quando os tipos numéricos do subconjunto de estado (AD-12) forem fixados; até lá 10 casas cobrem tudo que 1.3 hasheia.

- source_spec: `spec-1-3-hash-canonico-manifesto-bundle.md`
  summary: `snapshot_content_hash()` hasheia o conteúdo dos arquivos via `character` (com `enc2utf8` + guarda de NUL), não os bytes `raw` diretamente.
  evidence: Para uma feature de "identidade de conteúdo sobre bytes crus", hashear o vetor `raw` do `readBin` sem passar por `rawToChar` seria mais robusto (sem risco de encoding/NUL). O caminho atual funciona com as guardas adicionadas; revisitar se algum bundle real bater em problema de encoding.

- source_spec: `spec-1-4-cli-prepare-snapshot.md`
  summary: O `metadata.json` e o `qa-report.json` do bundle são gravados com `jsonlite::write_json(pretty = TRUE)`, não com `canonical_json()`.
  evidence: Inofensivo hoje — o `content_hash` re-serializa o `metadata` via `canonical_json()` antes de hashear, e o `qa-report.json` é determinístico dentro do `renv` fixado. Mas a reprodutibilidade do `content_hash` de um bundle entre versões diferentes do `jsonlite` não está garantida. Revisitar se os bytes de um bundle precisarem ser reproduzíveis entre ambientes (mesma classe do item "pinar o hash do pipeline config no metadata").

- source_spec: `spec-1-4-cli-prepare-snapshot.md`
  summary: `snapshot_write_bundle_json()` só coage `source_list` para array JSON; um `findings` de um único elemento (Story 1.5) viraria objeto sob `auto_unbox`.
  evidence: Em 1.4 `findings` é sempre `list()` → `[]`, então não há bug. Quando a Story 1.5 popular achados, estender a coerção de array para cobrir `findings` (ou o `qa-report.json` de um bundle com exatamente um achado quebra o schema).

- source_spec: `spec-1-4-cli-prepare-snapshot.md`
  summary: `write_snapshot_bundle()` move o diretório temporário para o caminho final *antes* de `prepare_snapshot()` rodar o parser + a verificação de hash.
  evidence: Um bundle formado mas ainda não verificado existe brevemente no caminho final (`<root>/<snapshot_id>/`), removido por `unlink` na falha. A intenção da spec ("mover só no sucesso") é substancialmente honrada (tmp dir durante toda a montagem); só a verificação final acontece pós-rename. Considerar verificar o tmp dir antes do rename.

- source_spec: `spec-1-4-cli-prepare-snapshot.md`
  summary: `.lintr` teve o `object_length_linter` alargado de 30 para 40 para acomodar o nome `collect_ffanalytics_projections` (31 caracteres), mandado pela spec.
  evidence: Config foi afrouxada para caber no código em vez de encurtar o nome. Decidir: manter o limite relaxado (vários style guides de R permitem nomes mais longos) ou encurtar o nome e restaurar o default.

- source_spec: `spec-1-5-validacao-qualidade-snapshot.md`
  summary: A lista coletar-tudo de `validate_snapshot_quality()` não inclui a completude do join (`player_id` em só um dos CSVs) nem a validação do *valor* de `schema_version`.
  evidence: O parser (`parse_snapshot_bundle`, fail-fast) cobre os dois (`snapshot_join_incompleto`, `snapshot_schema_incompativel`) e também é rodado pela superfície da Story 1.7. O I/O Matrix congelado da 1.5 não lista essas checagens. Se a superfície precisar delas na lista unificada de achados, adicionar em `domain_snapshot_quality.R` numa story futura.

- source_spec: `spec-1-6-design-tokens-tema-escuro.md`
  summary: `app.R` ainda envolve a UI em `shiny::fluidPage`, que carrega o CSS do Bootstrap; a robustez do `theme.css` em vencer essa cascata não é testada.
  evidence: A "Ask First" da spec era "se Bootstrap for necessário, decidir com o usuário". O `fluidPage` vem da Story 1.1, não foi introduzido pela 1.6. A ordem de carregamento do `<head>` içado (`tags$head`) vs. as dependências do template não é garantida. A decisão real — trocar `fluidPage` por um container sem Bootstrap, ou manter o Bootstrap como reset e apoiar na especificidade do `theme.css` — pertence à Story 1.7, quando a primeira superfície tornar o conflito de cascata observável.

- source_spec: `spec-1-6-design-tokens-tema-escuro.md`
  summary: `fdwr_theme_head()` resolve `www/` relativo ao working directory do processo (a raiz do repo).
  evidence: Assunção pré-existente do projeto inteiro — `app.R` faz `source("R/...")` relativo, o CLI usa `pkgload::load_all`, o script de regeneração roda da raiz. Se algum dia o app precisar rodar de outro cwd (empacotamento, instalação), `app.R` (sources), o CLI, e o resource-path de `fdwr_theme_head` precisam ser revisitados juntos — mover os assets para `inst/` e usar `system.file()`.

## Deferred from: code review of spec-1-5 (2026-08-31)

- source_spec: `spec-1-5-validacao-qualidade-snapshot.md`
  summary: Achado `snapshot_nome_ambiguo` some quando o grupo ambíguo inteiro não tem `player_id`.
  evidence: `sort(unique(ids[grp]))` com `ids` todos `NA` → `length(pids) >= 2L` falha e o achado não é emitido. As linhas já pegam `snapshot_campo_obrigatorio_ausente` (player_id), então o bundle ainda é bloqueado. Trocar o gate por `length(grp) >= 2L` e reportar `player_ids` como o subconjunto não-`NA` (ou `NA`).

- source_spec: `spec-1-5-validacao-qualidade-snapshot.md`
  summary: A regex de pureza em `test-domain_snapshot_quality.R` é mais estreita que a prosa ("não lê o clock").
  evidence: `forbidden` bloqueia só `Sys.(time|getenv)`; `Sys.Date`, `date()`, `proc.time`, `Sys.setlocale` passariam. Existem três regexes de pureza distintas (spec Verification, teste, deferred-work). O código não chama nenhuma dessas funções; alinhar as três e ampliar a do teste.

- source_spec: `spec-1-5-validacao-qualidade-snapshot.md`
  summary: Dois predicados independentes de "metadado ausente" (`R/domain_snapshot.R` vs `R/domain_snapshot_quality.R`).
  evidence: `snapshot_validate_metadata()` usa `length(value)==1 && is.na(value)`; a validação de qualidade usa `all(is.na(value))`. Discordam em valores multi-elemento/mistos e vão derivar. Extrair um predicado compartilhado se a duplicação crescer.

## Deferred from: code review of spec-1-6 (2026-08-31)

- source_spec: `spec-1-6-design-tokens-tema-escuro.md`
  summary: Guarda token↔CSS `(a)` e contraste WCAG `(b)` pulam silenciosamente sob `R CMD check`.
  evidence: Ambos fazem `skip_if_not(file.exists(design_path))` e `DESIGN.md` está sob `_bmad-output/` (Rbuildignored). São os únicos guardas ligando `www/theme.css` a `DESIGN.md` e as únicas checagens WCAG. Rodam sob `devtools::test()` do source tree (a verificação declarada da spec). Copiar o frontmatter YAML pra `tests/testthat/fixtures/` fecharia o gap do check empacotado.

- source_spec: `spec-1-6-design-tokens-tema-escuro.md`
  summary: Sem checagem reversa token↔CSS; `--focus-ring-color` nunca é afirmado contra `var(--color-focus)`.
  evidence: Teste `(a)` só cobre `DESIGN.md` → CSS. Uma custom property a mais ou com valor errado em `theme.css` que `DESIGN.md` não nomeia só é pega pelo teste "sem hex fora do `:root`". Adicionar uma afirmação reversa e uma pro `--focus-ring-color`.

## Deferred from: code review of spec-1-7 (2026-08-31)

- source_spec: `spec-1-7-superficie-selecionar-validar-snapshot.md`
  summary: `aria-busy` da região de resultado nunca fica observável como `"true"` durante a leitura do bundle.
  evidence: O carregamento em `snapshot_quality_server()` é R síncrono e bloqueia o processo; `rv$busy` alterna `TRUE` → `FALSE` dentro de um único flush reativo, então o cliente só vê `aria-busy="false"`. O atributo está no markup e o estado alterna, mas a semântica AA de "ocupado durante a leitura" só é real com carregamento assíncrono (`shiny::ExtendedTask` / promises), uma mudança maior fora do escopo da primeira superfície. Revisitar quando a 1.7 (ou uma story de a11y) adotar carga assíncrona.

## Deferred from: spec-2-1 (2026-08-31)

- source_spec: `spec-2-1-configuracao-liga-envelope-v1.md`
  summary: Parsing e schema de `tiers` e `recommendation_policy` não são feitos aqui — adiados para o Epic 3 (Story 3.2).
  evidence: A Story 2.1 só parseia e valida `league_rules` (`config/league_rules.yml`). A forma canônica de `tiers` (thresholds de agrupamento) e `recommendation_policy` (pesos de VOR, política K/DST, tier cliffs, roster-aware) pertence ao `recommend_fast()`, que é construído na Story 3.2. Quando o Epic 3 começar, definir onde essas configs moram (YAML versionado em `config/` + objeto canônico + validador) seguindo o mesmo split adapter-lê / domínio-valida de `parse_league_config()`.

- source_spec: `spec-2-1-configuracao-liga-envelope-v1.md`
  summary: `league_roster_nao_preenche_rounds` é redundante com `league_reservas_invalido` quando `starter_slots` e `rounds` estão no envelope.
  evidence: Com a composição V1 (`sum == 9`) e `rounds == 15`, `sum(starter_slots) + bench_size == rounds` é verdadeiro se e somente se `bench_size == 6` — exatamente a condição de `league_reservas_invalido`. A I/O Matrix da spec pede os dois achados quando `bench_size` diverge, então ambos são emitidos (com um comentário `ponytail:` no código). Se a composição de titulares virar configurável (o "Ask First" da spec), a checagem de roster passa a ter valor independente; até lá é uma duplicata deliberada.

- source_spec: `spec-2-1-configuracao-liga-envelope-v1.md`
  summary: `NAMESPACE` continua mantido à mão — a spec pede "gerado por roxygen (`devtools::document()`)".
  evidence: O `NAMESPACE` do projeto não tem o marcador `# Generated by roxygen2`, então `roxygenise()` se recusa a tocá-lo e as Stories 1.5–1.7 adicionaram as exports à mão; a 2.1 seguiu a mesma convenção (4 linhas `export(...)` adicionadas manualmente). Ativar a gestão por roxygen exige adicionar o marcador **e** lidar com o bump de `RoxygenNote`/`Config/roxygen2/version` que a versão instalada do roxygen2 (8.1.0 local vs. 7.3.2 no `renv.lock`) provoca no `DESCRIPTION`. Fazer isso numa story dedicada, alinhado com o pin do renv.
