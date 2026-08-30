# Epic 1 Context: Preparar e validar o snapshot de dados

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Este epic estabelece a fundação do produto: o pacote R local (estrutura semente, `renv`, composition root Shiny em loopback, harness de testes fora de Shiny/SQLite) e o pipeline de dados pré-draft. O operador gera um snapshot canônico de projeções com `scripts/prepare_snapshot.R` antes do draft, seleciona o bundle no app e vê temporada, fontes, método, scoring, cobertura e avisos de qualidade. Dados inválidos bloqueiam o avanço para a configuração da liga com motivo concreto e ação de recuperação. O runtime live nunca adquire nem enriquece dados e não acessa a rede. O epic também entrega os design tokens base (tema escuro único) e a superfície "Selecionar e validar snapshot".

## Stories

- Story 1.1: Scaffold do pacote R e composition root
- Story 1.2: Contrato e schema do snapshot bundle
- Story 1.3: Hash canônico do manifesto do bundle
- Story 1.4: CLI `scripts/prepare_snapshot.R`
- Story 1.5: Validação de qualidade do snapshot
- Story 1.6: Design tokens base e tema escuro
- Story 1.7: Superfície "Selecionar e validar snapshot"

## Requirements & Constraints

- App inicia por comando único (`Rscript -e "shiny::runApp(...)"`), faz bind em loopback, imprime a URL local, nunca escuta em interface pública. Colisão de porta falha com mensagem acionável em vez de escolher outra porta ou expor publicamente. Startup só habilita sessão após checar migrations, storage gravável e validação do bundle.
- Storage, logs e exports ficam em diretório de dados do usuário fora do código-fonte, permissões user-only; logs estruturados sem credenciais de fontes.
- Pipeline pré-draft e runtime live são fronteiras de confiança separadas: só `scripts/prepare_snapshot.R` adquire/enriquece dados e usa `ffanalytics`; o runtime aceita apenas bundles locais já validados e não usa rede. Inicialização com snapshot válido ≤ 3 s (p95), medida com fixture determinística registrada.
- Bundle canônico: `players.csv`, `metrics.csv`, `metadata.json`, `qa-report.json`.
- Campos mínimos por jogador: `player_id`, `display_name`, `normalized_name`, `position` normalizada (conjunto V1: `QB`, `RB`, `WR`, `TE`, `K`, `DST` — qualquer variação de `D/ST` mapeia para `DST`), `points`, `vor`, `tier`, `tier_cliff` obrigatórios; `nfl_team` obrigatório quando conhecido. Opcionais: `floor`, `ceiling`, `sd_points`, `ecr`, `adp`, `adp_sd`, `uncertainty`, `bye_week` — ausência é visível e não bloqueia.
- Metadados obrigatórios: `snapshot_id` (único), `season`, `generated_at`, `pipeline_version`, `source_list`, `scoring_hash`, `content_hash`, `qa_summary`; mais versão de schema.
- `snapshot_content_hash` = SHA-256 de um manifesto canônico: bytes UTF-8/LF normalizados, paths relativos ordenados, SHA-256 de cada arquivo; exclui o campo de hash derivado em `metadata.json`, inclui todos os demais bytes. Hex minúsculo, idêntico entre máquinas, muda com qualquer byte alterado.
- `scoring_config_hash` = serialização canônica do YAML de scoring (chaves ordenadas, `null` explícito, decimal fixo); deve bater com o `scoring_hash` do `metadata.json`.
- CLI: recebe YAML de scoring compatível com `ffanalytics`, coleta via commit fixado, calcula `points`/`vor`/`tier`/`tier_cliff`, emite bundle validado com metadados, `qa-report.json` e hashes. Modo fallback aceita CSV manual (campos obrigatórios + metadados) e produz o mesmo formato. Cada execução gera `snapshot_id` novo, não sobrescreve bundles anteriores. Falha de coleta ou config inválida termina com exit code não-zero e mensagem acionável, sem bundle parcial.
- Validação de qualidade: classifica cada achado como bloqueante ou aviso, lista determinística. Bloqueiam: campo obrigatório ou metadado ausente; `player_id` duplicado; nome ambíguo sem desambiguação; posição fora do conjunto V1; ADP inválido quando informado; `qa-report` ausente ou marcado bloqueante; hash de scoring divergente da configuração ativa. Opcionais ausentes ou cobertura anômala não crítica = aviso.
- Parser e validação de qualidade são domínio puro: sem exceção não tratada; falhas retornam domain error estruturado com `code` estável, mensagem PT-BR e detalhes machine-readable.
- Neste epic o snapshot selecionado já é o input imutável da sessão em preparação (trocar exige reiniciar o preparo); a imutabilidade pós-início da sessão é fechada no Epic 2.

## Technical Decisions

- Paradigma Hexagonal — núcleo funcional puro, shell imperativo. Domínio determinístico, recebe todo input explicitamente, retorna valores ou domain errors, nunca importa `shiny`, `DBI`, `RSQLite`, `yaml`, filesystem, clock ou APIs reativas. Casos de uso da aplicação são os únicos que chamam comandos de domínio e ports; adaptadores fazem I/O.
- Estrutura semente: `DESCRIPTION`, `renv.lock`, `app.R` (só composition root), `R/domain_*.R`, `R/application_*.R`, `R/adapter_sqlite_*.R`, `R/adapter_files_*.R`, `R/ui_*.R`, `scripts/prepare_snapshot.R`, `config/` (YAML versionado + schemas), `inst/schema/` (migrations SQLite + schema de snapshot), `tests/` (unit, integração, recovery, benchmark).
- O file adapter lista bundles locais e faz a leitura crua; parsing/normalização ficam no domínio puro — o mesmo parser serve o `script.R` e o runtime.
- Configuração é dado validado, não comportamento: YAML versionado, só escalares/listas/mapas declarados; a forma canônica serializada é o que se hasheia e armazena.
- Convenções: `snake_case`; funções de domínio são verbos; IDs de texto imutáveis; hashes SHA-256 hex minúsculo; timestamps UTC ISO-8601; event types UPPER_SNAKE_CASE. Linter aplica essas convenções.
- Testes: domínio testado fora de Shiny/SQLite; `devtools::test()` roda a suíte `testthat` desde o clone limpo.
- Dependências reproduzíveis por `renv.lock`. Stack: R 4.6.0, Shiny 1.14.0, DBI 1.3.0, RSQLite/SQLite 3.53.3, `ffanalytics` 3.x commit `1955daa05efb4a1f38c9a4dee609c5c4eaf84b4d` (só pré-draft).

## UX & Interaction Patterns

- Design tokens de `DESIGN.md` são a única fonte visual — nenhuma cor ou métrica fora dos tokens. Tema escuro único, sem modo claro no V1. Tokens: `colors` (canvas, surface, surface-raised, border, ink, ink-muted, action, action-ink, focus, warning, danger), `typography` (display 18px/700, data 14px/500, label 11px/700 caixa alta, pilha monoespaçada do sistema), `spacing`, `rounded` (sm 2px / md 4px / full 9999px) e tokens por componente.
- Semântica de cor: `action` (verde) só em pick vivo/confirmação/ação a executar; `focus` (azul) em foco de teclado e resultado selecionado; `warning` (âmbar) em undo e estado que pede conferência; `danger` (vermelho) só em falha/conflito/ação inválida. Todo estado carrega texto, ícone ou rótulo além da cor.
- Contraste WCAG 2.2 AA: `ink` sobre canvas/surface/surface-raised ≥ 4.5:1; `ink-muted` ≥ 4.5:1 e só em metadados não críticos; `focus`/`action`/`warning`/`danger` como indicador não textual ≥ 3:1. Valores iniciais devem ser auditados em uso real.
- Superfície "Qualidade do snapshot": resume cobertura, metadados e avisos; a região usa `aria-busy` durante a leitura. Falha de leitura mantém a seleção e oferece reexecutar `script.R` ou escolher outro bundle.
- Bloqueio: avanço desabilitado, causa concreta em `danger` identificando campo/incompatibilidade, sempre com ação de recuperação (reexecutar `script.R` ou selecionar outro snapshot).
- Campos opcionais ausentes aparecem sinalizados explicitamente ("Não disponível neste snapshot") e não bloqueiam.
- Microcopy curto, factual, orientado à próxima ação; mensagens de domínio em PT-BR; sem celebração nem alarmismo.
- Fluxo J-01: operador roda `script.R`, abre "Preparar draft", seleciona o snapshot, revisa temporada/geração/fontes/scoring/cobertura/avisos, confirma ausência de bloqueios; quando válido, a interface libera a configuração da liga, sem acesso de rede.

## Cross-Story Dependencies

- Story 1.1 (scaffold, composition root, harness de testes) é pré-requisito de todas as demais.
- Story 1.2 (parser/schema) alimenta 1.3 (hash), 1.5 (validação) e 1.7 (superfície); 1.4 (CLI) compartilha o mesmo parser.
- Story 1.4 produz os bundles que 1.5 e 1.7 consomem.
- Story 1.6 (design tokens) é pré-requisito visual da 1.7 e de todas as superfícies dos epics seguintes.
- O gate de compatibilidade `scoring_config_hash` (achado bloqueante na validação) tem enforcement efetivo no `start`/`DRAFT_STARTED` no Epic 2 (Story 2.6).
- O snapshot selecionado aqui é o input congelado para o Epic 2 (`DRAFT_STARTED` grava `snapshot_id` e `snapshot_content_hash`) e para o motor de recomendação do Epic 3.
