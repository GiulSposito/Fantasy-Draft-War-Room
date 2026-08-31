# Epic 1 Context: Preparar e validar o snapshot de dados

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Este epic estabelece a fundação do produto e a fronteira de dados. O operador prepara, fora do runtime live, um snapshot canônico de projeções por linha de comando; depois seleciona esse bundle no app e vê temporada, geração, fontes, método, scoring, cobertura e avisos de qualidade. Dados inválidos bloqueiam o início do draft com causa concreta e sempre uma ação de recuperação (reexecutar o script ou escolher outro bundle). Além da superfície "Qualidade do snapshot", o epic entrega o scaffold do pacote R (estrutura de pastas, `renv`, composition root Shiny em loopback, harness de testes fora de Shiny/SQLite), o CLI de preparo que usa `ffanalytics`, o adapter de arquivos/bundle, o schema e parser puro do snapshot, o hashing canônico SHA-256 do manifesto e da configuração de scoring, a validação de qualidade como domínio puro, e os design tokens base (tema escuro único).

## Stories

- Story 1.1: Scaffold do pacote R e composition root
- Story 1.2: Contrato e schema do snapshot bundle
- Story 1.3: Hash canônico do manifesto do bundle
- Story 1.4: CLI `scripts/prepare_snapshot.R`
- Story 1.5: Validação de qualidade do snapshot
- Story 1.6: Design tokens base e tema escuro
- Story 1.7: Superfície "Selecionar e validar snapshot"

## Requirements & Constraints

- A preparação pré-draft e o runtime live são fronteiras de confiança separadas: só o CLI de preparo adquire ou enriquece dados e pode usar `ffanalytics`; o runtime live não acessa a rede em nenhuma operação e só aceita bundles locais já validados.
- O bundle é `players.csv`, `metrics.csv`, `metadata.json` e `qa-report.json`. Campos obrigatórios por jogador: `player_id`, `display_name`, `normalized_name`, `position` normalizada (`QB`/`RB`/`WR`/`TE`/`K`/`DST`), `points`, `vor`, `tier`, `tier_cliff`; `nfl_team` quando conhecido; `floor/ceiling/sd_points/ecr/adp/adp_sd/uncertainty/bye_week` são opcionais e sua ausência deve ser visível mas nunca bloqueante. Metadados obrigatórios: `snapshot_id`, versão de schema, `season`, `generated_at`, `pipeline_version`, `source_list`, `scoring_hash`, `content_hash`, `qa_summary`.
- Importação CSV manual é aceita apenas quando traz todos os campos obrigatórios e os metadados necessários para gerar hashes e relatório de qualidade.
- Gates bloqueantes da validação: campo obrigatório ou metadado ausente; `player_id` duplicado ou nome ambíguo sem desambiguação; posição fora do conjunto V1 ou D/ST não normalizada; ADP inválido quando informado; `qa-report` ausente ou marcado como bloqueante. Divergência de hash de scoring é bloqueante como compatibilidade (o gate efetivo no `start` pertence ao Epic 2). Achados são classificados como bloqueante ou aviso e a lista é determinística.
- Cada snapshot tem `snapshot_id` único; execuções nunca sobrescrevem bundles anteriores. Falha de coleta ou configuração inválida termina com exit code não-zero e mensagem acionável, sem emitir bundle parcial.
- O snapshot selecionado é o input imutável da sessão em preparação; trocá-lo exige reiniciar o preparo (a imutabilidade pós-início vem no Epic 2).
- Startup do app: bind em loopback, detecção de colisão de porta com falha acionável (nunca escolher outra porta nem expor publicamente), checagem de migrations e storage gravável antes de habilitar sessão. Storage/logs/exports ficam em diretório de dados do usuário fora do código-fonte.
- Metas de performance relevantes: inicialização com snapshot válido em ≤ 3 s.

## Technical Decisions

- Arquitetura hexagonal, núcleo funcional / casca imperativa. O domínio é determinístico, recebe todo input explicitamente, retorna valores ou erros de domínio estruturados, e nunca importa `shiny`, `DBI`, `RSQLite`, `yaml`, filesystem, relógio ou APIs reativas. Casos de uso da aplicação são os únicos chamadores de comandos de domínio e de ports. A UI só emite intenções.
- Erros de domínio: `code` estável + mensagem PT-BR + detalhes machine-readable; nunca exceção não tratada. Parser e validação retornam esse formato.
- Manifesto canônico do `snapshot_content_hash`: SHA-256 sobre bytes normalizados UTF-8/LF, paths relativos ordenados e o SHA-256 de cada arquivo; exclui o campo de hash derivado dentro de `metadata.json` e inclui todos os demais bytes. Resultado em hex minúsculo, idêntico entre máquinas; qualquer byte alterado muda o hash.
- `scoring_config_hash`: serialização canônica do YAML de scoring (chaves ordenadas, `null` explícito, numérico fixo) e deve bater com o `scoring_hash` gravado em `metadata.json`.
- Configuração é dado validado, não comportamento: YAML versionado, parseado em objetos canônicos, aceitando apenas escalares, listas e mapas declarados; a forma canônica é o que se hasheia.
- Convenções: nomes `snake_case`; funções de domínio são verbos; IDs de texto imutáveis; hashes SHA-256 hex minúsculo; timestamps UTC ISO-8601; event types UPPER_SNAKE_CASE.
- Estrutura semente: `DESCRIPTION`, `renv.lock`, `app.R` (composition root), `R/domain_*.R`, `R/application_*.R`, `R/adapter_sqlite_*.R`, `R/adapter_files_*.R`, `R/ui_*.R`, `scripts/prepare_snapshot.R`, `config/` (YAML + schemas), `inst/schema/` (migrations SQLite + schema de snapshot), `tests/` (unit, integração, recovery, benchmark).
- Stack fixada: R 4.6.0, Shiny 1.14.0, DBI 1.3.0, RSQLite/SQLite 3.53.3, `renv` (lock), `ffanalytics` 3.x commit `1955daa05efb4a1f38c9a4dee609c5c4eaf84b4d` (somente pré-draft). Sem starter template. Testes de domínio rodam fora de Shiny/SQLite; fixtures de aceitação usam a base de 400 jogadores / 12 times.
- Design tokens (`DESIGN.md`) são a única fonte visual: `colors` (canvas, surface, surface-raised, border, ink, ink-muted, action, focus, warning, danger, action-ink), `typography` (display/data/label em pilha monoespaçada do sistema), `spacing`, `rounded` (sm 2px / md 4px / full 9999px) e tokens por componente. Nenhum valor visual fora dos tokens. Tema escuro único, sem modo claro no V1.
- Semântica de cor: `action` só em pick vivo/confirmação/ação a executar; `focus` só em foco de teclado e resultado selecionado; `warning` em undo e estado que pede conferência; `danger` só em falha/conflito/ação inválida. Todo estado carrega texto, ícone ou rótulo além da cor.
- Contraste WCAG 2.2 AA: `ink` sobre canvas/surface/surface-raised ≥ 4.5:1; `ink-muted` ≥ 4.5:1 e restrito a metadados não críticos; `focus`/`action`/`warning`/`danger` como indicador não textual ≥ 3:1. Os valores iniciais dos tokens são assunções a auditar em uso real.

## UX & Interaction Patterns

- Superfície "Qualidade do snapshot": resume cobertura, metadados e avisos; a região usa `aria-busy` durante a leitura do bundle. Bloqueio usa `danger`, identifica o campo/incompatibilidade e sempre oferece ação de recuperação (reexecutar o script ou selecionar outro snapshot). Falha de leitura mantém a seleção atual e oferece as mesmas ações.
- O adapter de arquivos lista os bundles locais disponíveis e o operador seleciona um explicitamente — nenhuma seleção silenciosa.
- Após um bundle válido, a superfície exibe temporada, geração, fontes, método, scoring e identidade de conteúdo, e libera o avanço para a configuração da liga.
- Campos opcionais ausentes aparecem sinalizados explicitamente (ex.: `Não disponível neste snapshot`) e não bloqueiam o avanço.
- Microcopy: texto curto, factual, orientado à próxima ação; mensagens de domínio em PT-BR; sem celebração nem alarmismo.

## Cross-Story Dependencies

- Story 1.1 (scaffold, composition root, harness de testes, convenções de nome) é pré-requisito de todas as demais.
- Story 1.2 (parser/schema do bundle) alimenta 1.3 (hash do manifesto), 1.5 (validação de qualidade) e 1.7 (superfície).
- Story 1.3 produz `snapshot_content_hash` e `scoring_config_hash` consumidos pela superfície 1.7 e, adiante, pelo gate de `start` e pela proveniência congelada no Epic 2.
- Story 1.4 (CLI de preparo) produz os bundles que 1.7 lista e valida; compartilha schema e regras de hash com 1.2/1.3.
- Story 1.6 (design tokens) é pré-requisito visual de 1.7 e de toda superfície dos epics seguintes.
- A imutabilidade do snapshot após o início da sessão e o gate efetivo de compatibilidade de scoring no `start` são completados no Epic 2 (`DRAFT_STARTED`).
