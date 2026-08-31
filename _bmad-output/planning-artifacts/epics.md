---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - docs/fantasy-draft-war-room-spec.md
  - _bmad-output/planning-artifacts/prds/prd-Fantasy Draft War Room-2026-08-28/prd.md
  - _bmad-output/planning-artifacts/prds/prd-Fantasy Draft War Room-2026-08-28/data-contract.md
  - _bmad-output/planning-artifacts/prds/prd-Fantasy Draft War Room-2026-08-28/decisions.md
  - _bmad-output/planning-artifacts/architecture/architecture-Fantasy Draft War Room-2026-08-28/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/ux-designs/ux-Fantasy Draft War Room-2026-08-29/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-Fantasy Draft War Room-2026-08-29/EXPERIENCE.md
---

# Fantasy Draft War Room - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Fantasy Draft War Room, decomposing the requirements from the PRD, the UX Design contract, and the Architecture Spine into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1 (DATA-001): Executar `script.R` local no pré-draft para gerar e importar um snapshot canônico; o runtime live não prepara dados nem acessa a rede.
FR2 (DATA-002): Exibir e preservar temporada, geração, fontes, método, scoring e identidade de conteúdo do snapshot.
FR3 (DATA-003): Validar campos obrigatórios, duplicidades/ambiguidades, ADP inválido e cobertura anômala dos jogadores.
FR4 (DATA-004): Exibir cobertura e avisos de qualidade antes de iniciar.
FR5 (DATA-005): Impedir troca do snapshot após o início da sessão.
FR6 (LEAGUE-001): Configurar 8–14 times e exatamente 15 rounds, bloqueando valores fora do envelope V1.
FR7 (LEAGUE-002): Validar 9 titulares (QB, 2 WR, 2 RB, FLEX, TE, K e D/ST) e 6 reservas contra os 15 rounds.
FR8 (LEAGUE-003): Restringir o FLEX a RB ou WR.
FR9 (LEAGUE-004): Ler scoring YAML compatível com `ffanalytics`, com Full PPR como padrão inicial.
FR10 (LEAGUE-005): Exigir exatamente um time do usuário por sessão.
FR11 (LEAGUE-007): Bloquear o início quando rounds e slots forem inviáveis.
FR12 (ORDER-001): Cadastrar os times da liga.
FR13 (ORDER-002): Registrar ou sortear a ordem da primeira rodada.
FR14 (ORDER-003): Permitir reordenação manual antes do início.
FR15 (ORDER-004): Gerar todos os slots do snake automaticamente.
FR16 (ORDER-005): Exibir overall pick, round, pick da rodada, time e indicador do usuário em cada slot.
FR17 (ORDER-006): Bloquear alterações normais da ordem após o início.
FR18 (DRAFT-001): Iniciar somente uma sessão pronta.
FR19 (DRAFT-002): Registrar o jogador disponível no slot atual.
FR20 (DRAFT-003): Rejeitar jogador duplicado sem alterar o estado.
FR21 (DRAFT-004): Associar o jogador automaticamente ao time do slot.
FR22 (DRAFT-005): Avançar para o próximo slot após a confirmação.
FR23 (DRAFT-006): Desfazer o último pick efetivo e restaurar o estado.
FR24 (DRAFT-007): Corrigir pick anterior e recompor todos os efeitos posteriores; rejeitar correção inválida sem apagar picks posteriores.
FR25 (DRAFT-008): Pausar e retomar a sessão.
FR26 (DRAFT-009): Listar sessões locais recentes, pré-selecionar a mais nova e restaurar somente a sessão confirmada pelo usuário.
FR27 (DRAFT-010): Completar a sessão ao preencher o último slot.
FR28 (DRAFT-011): Permitir abortar administrativamente um draft incompleto com aviso persistente.
FR29 (INPUT-001): Buscar jogadores incrementalmente por nome.
FR30 (INPUT-002): Tolerar acentos, apóstrofos, hífens e variações simples na busca.
FR31 (INPUT-003): Mostrar posição e time NFL no resultado.
FR32 (INPUT-004): Confirmar a escolha por teclado.
FR33 (INPUT-005): Ocultar jogadores já escolhidos.
FR34 (INPUT-006): Mostrar retorno imediato após registrar um pick.
FR35 (INPUT-007): Manter a ação de undo visível.
FR36 (ROSTER-001): Construir rosters de todos os times.
FR37 (ROSTER-002): Determinar o melhor lineup titular respeitando a elegibilidade.
FR38 (ROSTER-003): Tratar FLEX como slot de elegibilidade múltipla.
FR39 (ROSTER-004): Calcular o ganho marginal de um candidato no roster do usuário.
FR40 (ROSTER-005): Distinguir titular vazio, upgrade, FLEX, banco e redundância.
FR41 (ROSTER-006): Alertar ou restringir escolhas que impossibilitem completar slots obrigatórios.
FR42 (REC-001): Recalcular o ranking após cada pick.
FR43 (REC-002): Mostrar ao menos cinco candidatos disponíveis.
FR44 (REC-003): Exibir score por candidato.
FR45 (REC-004): Exibir componentes principais do score.
FR46 (REC-005): Exibir explicação curta e determinística.
FR47 (REC-006): Exibir alerta de tier cliff quando aplicável.
FR48 (REC-007): Considerar o roster atual na recomendação.
FR49 (REC-009): Aplicar política configurável que desprioriza K/DST cedo e torná-la consultável.
FR50 (REC-010): Filtrar disponíveis e recomendações por posição sem alterar o estado.
FR51 (PERSIST-001): Persistir cada comando relevante de forma atômica.
FR52 (PERSIST-002): Registrar timestamp e ordenação de eventos.
FR53 (PERSIST-003): Manter trilha de auditoria de undo e correções.
FR54 (PERSIST-004): Reconstruir estado a partir dos eventos.
FR55 (PERSIST-005): Exportar picks.
FR56 (PERSIST-006): Exportar rosters.
FR57 (PERSIST-007): Exportar configuração e metadados.
FR58 (REC-013): Configurar uma blacklist de jogadores (ex.: machucados ou suspensos) que os oculta da lista de recomendações e da smart list sem alterar o estado do draft; jogadores na blacklist continuam buscáveis e draftáveis com marcação explícita; a blacklist é editável durante o draft e sobrevive a refresh.
FR59 (SIM-001): Implementar estratégias de seleção de pick como funções puras e determinísticas — ADP, Total Points (projeção), Random (com seed), Pure VOR, Pure VONA e a estratégia de recomendação do app.
FR60 (SIM-002): Executar uma simulação de draft snake offline via `scripts/simulate_draft.R`: sortear a ordem dos times (seed registrada), atribuir uma estratégia a cada time (a do usuário em teste, as demais configuráveis) e executar todas as 15 rodadas registrando cada pick.
FR61 (SIM-003): Ao fim da simulação, calcular a pontuação projetada de cada roster — só titulares (melhor lineup), só banco e combinada — e produzir o ranking dos times.
FR62 (SIM-004): Emitir um relatório determinístico da simulação (picks por rodada, estratégias, seeds, pontuações e ranking) em formato consultável (console/CSV), reproduzível pela seed; opcionalmente repetir N execuções com seeds variadas e agregar os resultados.

### NonFunctional Requirements

NFR1 (PERF-001): Persistência de pick com p95 ≤ 100 ms.
NFR2 (PERF-002): Recomendação rápida com p95 ≤ 300 ms.
NFR3 (PERF-003): Atualização da tela com p95 ≤ 500 ms.
NFR4 (PERF-004): Busca com p95 ≤ 100 ms.
NFR5 (PERF-005): Inicialização com snapshot válido em ≤ 3 s.
NFR6 (PERF-006): Nenhuma operação síncrona do live draft acessa a rede.
NFR7 (REL-001): Refresh restaura sessão consistente após confirmação explícita.
NFR8 (REL-002): Pick confirmado não se perde após interrupção.
NFR9 (REL-003): Constraints impedem duplicidade de jogador e de pick efetivo.
NFR10 (MAINT-001): O domínio não depende de Shiny nem de I/O.
NFR11 (MAINT-002): Regras analíticas são funções puras e determinísticas.
NFR12 (MAINT-003): Domínio e casos de uso possuem testes adequados.
NFR13 (MAINT-004): Fórmulas e políticas variam por configuração versionada e validada.
NFR14 (MAINT-005): Dependências são reproduzíveis por `renv.lock`.
NFR15 (EXPL-001): Nenhuma recomendação é um número opaco.
NFR16 (EXPL-002): Cada recomendação mostra pelo menos três fatores aplicáveis.
NFR17 (EXPL-003): Pesos e políticas ativos são consultáveis.
NFR18 (EXPL-004): A interface distingue projeção, valor, preço de mercado e urgência.
NFR19 (REP-002): Cada recomendação é vinculável a snapshot, configuração e hash de estado.
NFR20 (REP-003): A recuperação local e as exportações têm informação suficiente para auditoria; reimportação portátil fica fora da V1.
NFR21 (UX-001): O fluxo principal é keyboard-first.
NFR22 (UX-002): Não há confirmação rotineira por modal; undo e correção recuperam erros.
NFR23 (UX-003): Status crítico não depende apenas de cor.
NFR24 (UX-004): Informação crítica permanece visível na tela live.
NFR25 (BENCHMARK): As metas são medidas com fixture determinística de 400 jogadores, 12 times e 168 picks, registrando configuração e ferramenta de medição.

### Additional Requirements

- O app é um pacote R local com Shiny na borda, domínio funcional puro, casos de uso e adaptadores de arquivos/SQLite; a UI só emite intenções (AD-1).
- `scripts/prepare_snapshot.R` é o único componente que pode adquirir ou enriquecer dados e pode usar `ffanalytics`; o runtime aceita somente bundles locais validados e não usa rede (AD-2).
- O bundle canônico contém `players.csv`, `metrics.csv`, `metadata.json` e `qa-report.json`, identificado por manifesto SHA-256 (bytes UTF-8/LF, paths relativos ordenados, SHA-256 por arquivo) e hash de scoring compatível; validação conclui antes da criação da sessão (AD-3).
- O estado usa eventos imutáveis e projeção materializada SQLite atualizados na mesma transação; eventos carregam `{draft_id, event_sequence, event_type, expected_overall_pick, target_overall_pick, player_id, actor, created_at}` conforme aplicável (AD-4). _Simplificado pela Sprint Change Proposal 2026-08-31: sem `expected_state_hash` no payload, sem hashes de estado anterior/resultante por evento; AD-12 removido._
- Undo e correção são eventos reproduzidos por replay, preservam histórico e recusam qualquer estado inválido sem apagar picks posteriores; o replay não verifica hash de estado (AD-5).
- No `DRAFT_STARTED` a sessão congela `snapshot_id`/`snapshot_content_hash`, os **valores** de scoring/regras/política, versões de schema, versão do engine e seed opcional; a compatibilidade de scoring entre snapshot e configuração ativa é um aviso não-bloqueante (AD-6, AD-7). _Simplificado pela Sprint Change Proposal 2026-08-31: sem `scoring_config_hash`/`league_rules_hash`/`recommendation_policy_hash` canônicos._
- SQLite é o único sistema local de registro: tabelas criadas no boot com `CREATE TABLE IF NOT EXISTS`, `event_sequence` monotônico, unicidade `(draft_id, overall_pick)` e `(draft_id, player_id)` na `effective_pick_projection`, WAL/foreign keys; exports são artefatos derivados (AD-8). _Simplificado pela Sprint Change Proposal 2026-08-31: sem runner de migrations versionadas nem histórico de migrations._
- `recommend_fast()` é função de domínio pura, síncrona, em memória, determinística sobre estado congelado + métricas do snapshot + configuração + política; retorna candidatos ordenados, componentes, ≥3 fatores estruturados, reason codes, texto determinístico, avisos e versão do engine; sem scraping, scan SQL ou simulação no caminho crítico (AD-9). _Simplificado pela Sprint Change Proposal 2026-08-31: gate de benchmark p95 substituído por smoke checks._
- O processo Shiny é iniciado por `Rscript -e "shiny::runApp(...)"`, faz bind em loopback, detecta colisão de porta e falha com mensagem acionável; storage/logs/exports ficam em diretório de dados do usuário fora do código-fonte, com permissões user-only; logs são estruturados e não expõem credenciais; startup checa storage gravável e validação do bundle antes de habilitar a sessão (AD-10).
- Uma query lista sessões locais por `updated_at DESC` e pré-seleciona a mais nova, mas restauração exige confirmação/seleção explícita; `draft_id` selecionado é o único input de restauração; intenções de pick carregam `expected_overall_pick`, rejeitando intenções obsoletas com erro estruturado e instrução de reload (AD-11). _Simplificado pela Sprint Change Proposal 2026-08-31: sem `expected_state_hash`._
- Convenções: nomes `snake_case`, funções de domínio são verbos, IDs de texto imutáveis, hashes SHA-256 hex minúsculo, timestamps UTC ISO-8601, `event_sequence` é a ordem autoritativa, event types UPPER_SNAKE_CASE, erros de domínio com `code` estável + mensagem PT-BR + detalhes machine-readable.
- Estrutura semente do pacote: `DESCRIPTION`, `renv.lock`, `app.R` (composition root), `R/domain_*.R`, `R/application_*.R`, `R/adapter_sqlite_*.R`, `R/adapter_files_*.R`, `R/ui_*.R`, `scripts/prepare_snapshot.R`, `scripts/simulate_draft.R`, `config/` (YAML versionado + schemas), `inst/schema/` (schema SQLite + schema de snapshot), `tests/` (unit, integração, smoke).
- Stack fixada: R 4.6.0, Shiny 1.14.0, DBI 1.3.0, RSQLite/SQLite 3.53.3, `renv` (lock), `ffanalytics` 3.x commit `1955daa05efb4a1f38c9a4dee609c5c4eaf84b4d` (somente pré-draft). Não há starter template obrigatório.
- Contrato de dados: campos mínimos do snapshot por jogador (`player_id`, `display_name`, `normalized_name`, `position` normalizada QB/RB/WR/TE/K/DST, `points`, `vor`, `tier`, `tier_cliff` obrigatórios; `nfl_team` quando conhecido; `floor/ceiling/sd_points/ecr/adp/adp_sd/uncertainty/bye_week` opcionais com indisponibilidade visível e não-bloqueante); metadados obrigatórios `season/generated_at/pipeline_version/source_list/scoring_hash/content_hash/qa_summary`; importação CSV manual aceita apenas com campos obrigatórios + metadados; gates de qualidade bloqueiam por campo obrigatório ausente, `player_id` duplicado/nome ambíguo, posição fora do conjunto V1, ADP inválido, hash de scoring divergente ou qa-report ausente/bloqueante.

### UX Design Requirements

Fonte: contrato de UX `DESIGN.md` (identidade visual + design tokens) e `EXPERIENCE.md` (arquitetura de informação, comportamento, estados, interação, acessibilidade, jornadas). Referência de composição: `mockups/live-war-room.html` — os spines vencem qualquer conflito com o mockup.

> **Sprint Change Proposal 2026-08-31 (app local de uso único):** os UX-DR abaixo permanecem como intenção, com implementação reduzida a keyboard-first + ARIA básico. Cortados como entregável: UX-DR3 (auditoria de contraste WCAG), UX-DR21 (zoom 200% linear, `prefers-reduced-motion`), UX-DR22 (piso de alvo 24×24 px), e a parte screen-reader de UX-DR5/7/9/12/13/14/19/20 (`aria-controls`, `aria-activedescendant`, roving tabindex, `?` como referência de atalhos, ordem de `Tab` célula a célula). Layout: dois estados (amplo/estreito). Ver §4.4 da proposta e os callouts por epic.

UX-DR1: Implementar o sistema de design tokens único (tema escuro, sem modo claro no V1) de `DESIGN.md` como fonte visual: `colors` (canvas, surface, surface-raised, border, ink, ink-muted, action, action-ink, focus, warning, danger), `typography` (display/data/label na pilha monoespaçada do sistema), `spacing`, `rounded` (sm 2px / md 4px / full 9999px) e os tokens por componente. Nenhuma cor ou métrica visual fora dos tokens.
UX-DR2: Aplicar a semântica de cor de forma consistente: `action` (verde) só em pick vivo, confirmação e ação a executar; `focus` (azul) em foco de teclado e resultado selecionado; `warning` (âmbar) em undo e estado que pede conferência; `danger` (vermelho) só em falha, conflito ou ação inválida. Todo estado carrega texto, ícone ou rótulo além da cor.
UX-DR3: Garantir contraste WCAG 2.2 AA conforme os pares de `DESIGN.md`: `ink` sobre canvas/surface/surface-raised ≥ 4.5:1; `ink-muted` ≥ 4.5:1 e restrito a metadados não críticos; `focus`, `action`, `warning`, `danger` como indicador não textual ≥ 3:1. Auditar e ajustar os valores iniciais em uso real no notebook.
UX-DR4: Componente Faixa de estado — cabeçalho fixo com overall pick em `typography.display`, rodada/pick da rodada, time no relógio, último jogador registrado e próximo pick do operador; pick vivo em `action`; estado pausado/alerta/concluído com texto + ícone além de cor; a faixa atualiza como uma unidade após comando aceito e nunca sai da vista.
UX-DR5: Componente Campo de busca + autocomplete — campo de largura dominante com resultados imediatamente abaixo; busca local incremental tolerante a acentos, apóstrofos, hífens e variações simples; retorna apenas jogadores disponíveis com nome, posição e time NFL; o resultado que `Enter` registrará usa `candidate-active` + contorno de foco. Combobox/listbox ARIA: label persistente, `aria-expanded`, `aria-controls`, `aria-activedescendant`; anuncia contagem, ausência de resultados e item ativo.
UX-DR6: Componente Lista inteligente — mostra ao menos cinco candidatos disponíveis ordenados pela recomendação ativa, filtráveis por posição via badges discretos; cada linha distingue score, fatores principais, alerta de tier cliff e impacto no roster; a recomendação nº 1 é destacada por ordem e peso tipográfico, nunca por card grande.
UX-DR7: Componente Linha de candidato — setas movem o destaque, `Espaço` abre/fecha inspeção, `Enter` tenta registrar no pick atual; linha ativa usa `candidate-row.active` + contorno e rótulo de foco; clique é alternativa suportada, não o fluxo principal.
UX-DR8: Componente Painel de inspeção — superfície contextual em `surface-raised` que mostra a explicação determinística (projeção, valor, preço de mercado, urgência quando aplicáveis), tier e impacto marginal no roster, sem cobrir a faixa de estado ou a busca; campo opcional ausente aparece como `Não disponível neste snapshot`; não é comparação lado a lado no V1.
UX-DR9: Componente Board de draft — grade compacta round × time com a linha/coluna do pick atual claramente marcada; jogador recém-registrado recebe realce transitório em `action` sem animação prolongada; picks do operador distinguíveis também por rótulo. Grade com roving tabindex: setas percorrem células, `Enter`/`Espaço` abre correção, cada célula anuncia overall, time, jogador e estado.
UX-DR10: Componente Roster do operador — matriz enxuta de slots com grupos visuais estáveis para titulares, FLEX e banco; torna visíveis o melhor lineup, os slots vazios e o impacto marginal do candidato em foco.
UX-DR11: Componente Undo — sempre visível, acionável por `U`, com borda/texto em `warning`; enquanto houver picks efetivos, mostra de forma compacta o próximo pick a desfazer (overall, jogador, time) e o contador de reversões consecutivas ainda disponíveis; não pode parecer ação destrutiva.
UX-DR12: Componente Histórico de eventos — lista compacta em `ink-muted` de registros, undos e correções em ordem, cada um com alvo e resultado efetivo; é auditável, nunca um feed de recomendações históricas, e não compete com o board atual.
UX-DR13: Componente Pausa/exportação — controles secundários de borda fina; pausa é sempre textual e bloqueia registro normal; exportação nunca aparece como ação destrutiva e não altera a sessão.
UX-DR14: Componente Feedback e erro — uma única região `aria-live=polite` `aria-atomic=true` anuncia comandos aceitos em frase curta (jogador, novo overall, undo disponível); confirmação de registro é breve, textual, próxima à faixa de estado e substitui a lista em menos de um ciclo de atenção; erros persistem até o operador poder agir; toasts nunca encobrem busca, pick atual ou foco de teclado; nenhum modal de confirmação rotineiro.
UX-DR15: Componente Seleção de sessão — lista curta de sessões locais ordenadas por recência com a mais nova pré-selecionada; restauração só após `Enter`/clique em Confirmar; data e status como metadados compactos; skeleton durante carregamento; nenhuma restauração silenciosa.
UX-DR16: Componente Qualidade do snapshot — resume cobertura, metadados e avisos; bloqueio usa `danger`, identifica o campo/incompatibilidade e sempre oferece ação de recuperação (executar `script.R` novamente ou selecionar outro snapshot); região usa `aria-busy` durante a leitura.
UX-DR17: Componente Configuração da liga — formulário compacto em grupos previsíveis (times/rounds, slots/FLEX, scoring, time do operador); a validade aparece junto ao grupo afetado; o início fica bloqueado até todos os grupos estarem viáveis.
UX-DR18: Componente Ordem snake — grade compacta que suporta cadastrar/sortear/reordenar antes do início; estado travado visível em `snake-order.locked` e `Validate and Lock` como a única ação de transição.
UX-DR19: Modelo de interação por teclado — dentro de entrada editável, atalhos globais não disparam (↑/↓/`Enter`/`Esc`/`Espaço` pertencem ao autocomplete); fora dela, setas movem o destaque, `Enter` registra, `Espaço` alterna inspeção, `Esc` fecha só a camada contextual superior e `U` aplica um undo por tecla (repetível). `/` foca a busca de qualquer painel da Live War Room e `?` abre a referência de atalhos [ASSUMPTION]. Todo atalho tem controle acessível equivalente com label e dica de teclado; `Tab` alcança todos os controles na ordem operacional: estado, busca, candidatos, inspeção, board, roster, controles.
UX-DR20: Gestão de foco — foco de teclado sempre visível por 2px em `focus`; após registro, undo ou correção o foco retorna à busca/lista; após conclusão vai para Exportar; a correção abre um único painel contextual (nunca pilha de modais) e devolve o foco à mesma célula do board ao cancelar, falhar ou concluir.
UX-DR21: Layout responsivo de janela dividida — alvo é uma janela estreita ao lado da ESPN em notebook/desktop; em largura ampla, board e roster são painéis laterais; em largura reduzida viram painéis alternáveis preservando estado e foco, enquanto faixa de estado, busca e lista de candidatos permanecem sempre visíveis; a 200% de zoom, estado/busca/lista seguem leitura linear e só o grid do board rola horizontalmente mantendo o pick atual identificável; movimento reduzido elimina transições não essenciais sem atrasar feedback. Sem alvo de celular/tablet no V1.
UX-DR22: Piso de alvos clicáveis — controles clicáveis com alvo mínimo de 24×24 CSS px ou espaçamento equivalente; ao navegar, a tela rola para manter o foco totalmente visível, inclusive abaixo da faixa fixa.
UX-DR23: Voz e microcopy — texto curto, factual e orientado à próxima ação (ex.: `Registrado: Ja'Marr Chase`, `Já escolhido no pick 42. Busque outro jogador.`, `Undo aplicado — pick 73 voltou a aberto.`); sem celebração, alarmismo ou confiança preditiva. Mensagens de domínio em PT-BR.
UX-DR24: Cobertura de estados de UI — implementar os estados distintos enumerados em `EXPERIENCE.md` "State Patterns" com a superfície e o tratamento especificados para cada: carregando sessões, nenhuma sessão recuperável, sessão recuperável, snapshot carregando/falhou, snapshot/configuração inválido, ordem em preparação, pronto para iniciar, live aguardando pick, consulta sem resultado, inspeção com dado opcional ausente, nome ambíguo/inválido/já escolhido, registrando (`disabled`/`aria-disabled` com motivo acessível), pick confirmado, intenção obsoleta, pausado, undo multinível, correção válida, correção inválida, draft completo, falha local de persistência, exportando/exportado/falhou, encerrado administrativamente (ABORTED com aviso persistente).
UX-DR25: Componente Blacklist — editor compacto na Live War Room para adicionar/remover jogadores da blacklist por busca; jogadores na blacklist recebem marcação explícita (texto + ícone, nunca só cor) nos resultados de busca e são omitidos da smart list e das recomendações; totalmente acessível por teclado com controle equivalente e dica de atalho; o estado da blacklist é anunciado ao adicionar/remover e não rouba foco.

### FR Coverage Map

FR1: Epic 1 — executar `script.R` e importar snapshot canônico; runtime live sem preparo nem rede
FR2: Epic 1 — exibir e preservar temporada, geração, fontes, método, scoring e identidade de conteúdo
FR3: Epic 1 — validar campos obrigatórios, duplicidades/ambiguidades, ADP inválido e cobertura anômala
FR4: Epic 1 — exibir cobertura e avisos de qualidade antes de iniciar
FR5: Epic 1 — impedir troca do snapshot após o início da sessão
FR6: Epic 2 (2.1) — configurar 8–14 times e exatamente 15 rounds dentro do envelope V1
FR7: Epic 2 (2.1) — validar 9 titulares e 6 reservas contra os 15 rounds
FR8: Epic 2 (2.1) — restringir o FLEX a RB ou WR
FR9: Epic 2 (2.1) — ler scoring YAML compatível com `ffanalytics` apenas para identidade; Full PPR como padrão
FR10: Epic 2 (2.2) — exigir exatamente um time do usuário por sessão
FR11: Epic 2 (2.1) — bloquear o início quando rounds e slots forem inviáveis
FR12: Epic 2 (2.2) — cadastrar os times da liga
FR13: Epic 2 (2.2) — registrar ou sortear a ordem da primeira rodada
FR14: Epic 2 (2.2) — permitir reordenação manual antes do início
FR15: Epic 2 (2.2) — gerar todos os slots do snake automaticamente
FR16: Epic 2 (2.2) — gerar overall pick, round, pick da rodada, time e indicador do usuário · UI em Epic 4 (4.1)
FR17: Epic 2 (2.3) — bloquear alterações normais da ordem após o início
FR18: Epic 2 (2.3) — iniciar somente uma sessão pronta (evento `DRAFT_STARTED`)
FR19: Epic 3 (3.4) — registrar o jogador disponível no slot atual · UI em Epic 4 (4.2)
FR20: Epic 3 (3.4) — rejeitar jogador duplicado sem alterar o estado
FR21: Epic 3 (3.4) — associar o jogador automaticamente ao time do slot
FR22: Epic 3 (3.4) — avançar para o próximo slot após a confirmação
FR23: Epic 3 (3.4) — desfazer o último pick efetivo e restaurar o estado · controle Undo em Epic 4 (4.4)
FR24: Epic 3 (3.4) — corrigir pick anterior e recompor efeitos posteriores; rejeitar correção inválida · UI em Epic 4 (4.4)
FR25: Epic 4 (4.4) — sessão retomável do banco via flag de status; sem par de eventos pause/resume (downgrade — Sprint Change Proposal 2026-08-31)
FR26: Epic 4 (4.4) — listar sessões locais, pré-selecionar a mais nova e restaurar só a confirmada
FR27: Epic 5 (5.1) — completar a sessão ao preencher o último slot
FR28: REMOVIDO — abort administrativo cortado (Sprint Change Proposal 2026-08-31); `complete` é a única transição terminal
FR29: Epic 3 (3.3) — buscar jogadores incrementalmente por nome · UI em Epic 4 (4.2)
FR30: Epic 3 (3.3) — tolerar acentos, apóstrofos, hífens e variações simples na busca
FR31: Epic 3 (3.3) — mostrar posição e time NFL no resultado
FR32: Epic 4 (4.2) — confirmar a escolha por teclado
FR33: Epic 3 (3.3) — ocultar jogadores já escolhidos
FR34: Epic 4 (4.3) — mostrar retorno imediato após registrar um pick
FR35: Epic 4 (4.4) — manter a ação de undo visível
FR36: Epic 3 (3.1) — construir rosters de todos os times
FR37: Epic 3 (3.1) — determinar o melhor lineup titular respeitando a elegibilidade
FR38: Epic 3 (3.1) — tratar FLEX como slot de elegibilidade múltipla
FR39: Epic 3 (3.1) — calcular o ganho marginal de um candidato no roster do usuário
FR40: Epic 3 (3.1) — distinguir titular vazio, upgrade, FLEX, banco e redundância
FR41: Epic 3 (3.1) — alertar ou restringir escolhas que impossibilitem completar slots obrigatórios
FR42: Epic 3 (3.2) — recalcular o ranking após cada pick
FR43: Epic 3 (3.2) — mostrar ao menos cinco candidatos disponíveis
FR44: Epic 3 (3.2) — exibir score por candidato
FR45: Epic 3 (3.2) — exibir componentes principais do score
FR46: Epic 3 (3.2) — exibir explicação curta e determinística
FR47: Epic 3 (3.2) — exibir alerta de tier cliff quando aplicável
FR48: Epic 3 (3.2) — considerar o roster atual na recomendação
FR49: Epic 3 (3.2) — aplicar política configurável que desprioriza K/DST cedo e torná-la consultável
FR50: Epic 3 (3.2) — filtrar disponíveis e recomendações por posição · badges de filtro em Epic 4 (4.2)
FR51: Epic 2 (2.3) — persistir cada comando relevante de forma atômica (event store)
FR52: Epic 2 (2.3) — registrar timestamp e ordenação de eventos
FR53: Epic 3 (3.4) — manter trilha de auditoria de undo e correções · histórico de eventos em Epic 4 (4.4)
FR54: Epic 3 (3.4) — reconstruir estado a partir dos eventos (replay, sem verificação de hash)
FR55: Epic 5 (5.1) — exportar picks
FR56: Epic 5 (5.1) — exportar rosters
FR57: Epic 5 (5.1) — exportar configuração e metadados
FR58: Epic 3 (3.2) — blacklist oculta jogadores das recomendações sem alterar o estado · editor em Epic 4 (4.3)
FR59: Epic 3 (3.5) — estratégias de seleção como funções puras (ADP, Total Points, Random, Pure VOR, Pure VONA, app)
FR60: Epic 3 (3.6) — runner de simulação de draft snake offline com sorteio de ordem e estratégia por time
FR61: Epic 3 (3.6) — pontuação projetada por roster (titulares/banco/combinado) e ranking dos times
FR62: Epic 3 (3.6) — relatório determinístico da simulação, reproduzível pela seed, com repetição opcional

## Epic List

### Epic 1: Preparar e validar o snapshot de dados
O operador prepara um snapshot canônico de projeções com `scripts/prepare_snapshot.R`, seleciona o bundle no app e vê temporada, fontes, scoring, cobertura e avisos de qualidade; dados inválidos bloqueiam o início com motivo acionável e uma ação de recuperação. Estabelece a fundação do pacote R (estrutura, `renv`, composition root, suíte de testes), o CLI de preparo com `ffanalytics`, o adapter de arquivos/bundle, o hashing canônico SHA-256 do manifesto, o schema de snapshot e a validação de qualidade como domínio puro, além dos design tokens base e da superfície "Qualidade do snapshot".
**FRs covered:** FR1, FR2, FR3, FR4, FR5

### Epic 2: Liga, calendário e sessão mínima
O operador configura a liga dentro do envelope V1, cadastra os times, define/sorteia/reordena a ordem da primeira rodada, revisa o calendário snake completo e trava tudo, criando uma sessão pronta. Estabelece o domínio puro de liga e schedule, o parser de configuração YAML com validação de envelope (sem serialização canônica nem hashing de config) e o event store SQLite mínimo (`CREATE TABLE IF NOT EXISTS` no boot, log append-only, `event_sequence` monotônico, projeção materializada) com o evento `DRAFT_STARTED` congelando os valores de proveniência.
**FRs covered:** FR6, FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR51, FR52

### Epic 3: Domínio de draft, recomendação e simulação
Fora de Shiny e SQLite, o domínio puro constrói rosters e o melhor lineup, calcula ganho marginal, produz recomendações rápidas e explicáveis (`recommend_fast()`), executa busca incremental de jogadores, aplica undo/correção/replay por eventos e roda uma simulação de draft snake completa comparando estratégias via `scripts/simulate_draft.R`. É o núcleo do produto: a ordem de execução (`3.1 → 3.2 → 3.3 → 3.5 → 3.6 → 3.4`) coloca o algoritmo e a simulação antes dos use cases de comando, permitindo calibrar a recomendação por script antes de qualquer tela.
**FRs covered:** FR19, FR20, FR21, FR22, FR23, FR24, FR29, FR30, FR31, FR33, FR36, FR37, FR38, FR39, FR40, FR41, FR42, FR43, FR44, FR45, FR46, FR47, FR48, FR49, FR50, FR53, FR54, FR58, FR59, FR60, FR61, FR62

### Epic 4: Live War Room
Na tela live o operador vê o estado global, busca um jogador por teclado, registra o pick com feedback imediato e vê board, roster, disponíveis e recomendações recomporem; desfaz, corrige um pick pelo board, mantém uma blacklist e restaura sessões locais. Tema escuro único com os design tokens do Epic 1, fluxo keyboard-first com ARIA básico (roles/labels no combobox e uma região `aria-live`) e dois estados de layout (painéis laterais em tela ampla, empilhados em tela estreita).
**FRs covered:** FR16, FR19, FR24, FR25, FR26, FR29, FR32, FR34, FR35, FR50, FR53, FR58

### Epic 5: Fechar e exportar
Ao preencher o último slot a sessão encerra; o operador exporta picks, rosters, configuração e metadados do snapshot em CSV/JSON no diretório de dados do usuário. Não há abort administrativo — `complete` é a única transição terminal.
**FRs covered:** FR27, FR55, FR56, FR57

---

## Epic 1: Preparar e validar o snapshot de dados

O operador prepara um snapshot canônico de projeções, seleciona o bundle no app e vê metadados, cobertura e avisos de qualidade; dados inválidos bloqueiam o início com motivo acionável e ação de recuperação. Este epic também estabelece a fundação do pacote R e os design tokens base.

### Story 1.1: Scaffold do pacote R e composition root

As a operador,
I want iniciar o aplicativo localmente por um comando único,
So that eu tenha um ambiente reproduzível para todas as funcionalidades seguintes.

**Acceptance Criteria:**

**Given** um clone limpo do repositório
**When** executo `renv::restore()` e `Rscript -e "shiny::runApp('app.R')"`
**Then** o app Shiny sobe em loopback, imprime a URL local e não escuta em interface pública
**And** `DESCRIPTION`, `renv.lock`, e as pastas `R/`, `scripts/`, `config/`, `inst/schema/` e `tests/` existem conforme a semente estrutural da arquitetura

**Given** a porta padrão já ocupada
**When** inicio o app
**Then** ele falha com mensagem acionável em vez de escolher outra porta silenciosamente ou expor publicamente

**Given** o projeto recém-clonado
**When** executo `devtools::test()`
**Then** a suíte `testthat` roda e passa, ainda que com poucos testes, estabelecendo o harness de teste fora de Shiny/SQLite

**Given** o código-fonte
**When** rodo o linter/estilo configurado
**Then** ele aplica `snake_case`, verbos para funções de domínio e as convenções de nome da arquitetura

### Story 1.2: Contrato e schema do snapshot bundle

As a desenvolvedor do pipeline de dados,
I want um schema explícito e um parser puro para o bundle de snapshot,
So that o runtime e o `script.R` interpretem os mesmos arquivos da mesma forma.

**Acceptance Criteria:**

**Given** um bundle com `players.csv`, `metrics.csv`, `metadata.json` e `qa-report.json`
**When** o parser de domínio lê o bundle
**Then** ele retorna objetos canônicos tipados com os campos mínimos do contrato de dados (`player_id`, `display_name`, `normalized_name`, `position` normalizada, `points`, `vor`, `tier`, `tier_cliff` obrigatórios; `nfl_team` quando conhecido; `floor/ceiling/sd_points/ecr/adp/adp_sd/uncertainty/bye_week` opcionais)

**Given** um bundle com arquivo ausente, coluna obrigatória ausente ou tipo incompatível
**When** o parser processa o bundle
**Then** ele retorna um erro de domínio estruturado com `code` estável, mensagem PT-BR e detalhes machine-readable, sem lançar exceção não tratada

**Given** `metadata.json`
**When** o parser o lê
**Then** os metadados obrigatórios `season`, `generated_at`, `pipeline_version`, `source_list`, `scoring_hash`, `content_hash` e `qa_summary` são exigidos e expostos

**Given** posição `DST` ou `D/ST` em qualquer variação
**When** o parser normaliza
**Then** ela é mapeada para o valor canônico único do conjunto V1 (`QB`, `RB`, `WR`, `TE`, `K`, `DST`)

### Story 1.3: Hash canônico do manifesto do bundle

As a operador,
I want que cada snapshot tenha uma identidade de conteúdo estável,
So that a sessão possa fixá-lo e a recomendação seja auditável.

**Acceptance Criteria:**

**Given** um diretório de bundle
**When** o `snapshot_content_hash` é calculado
**Then** ele é o SHA-256 de um manifesto canônico: bytes normalizados UTF-8/LF, paths relativos ordenados e o SHA-256 de cada arquivo, excluindo o campo de hash derivado em `metadata.json` e incluindo todos os demais bytes

**Given** o mesmo bundle em duas máquinas
**When** o hash é recalculado
**Then** o valor é idêntico (hex minúsculo)

**Given** a configuração YAML de scoring usada na geração
**When** o `scoring_config_hash` é calculado
**Then** ele usa a serialização canônica (chaves ordenadas, `null` explícito, numérico fixo) e bate com o `scoring_hash` gravado em `metadata.json`

**Given** qualquer byte alterado em qualquer arquivo do bundle
**When** o hash é recalculado
**Then** ele muda

### Story 1.4: CLI `scripts/prepare_snapshot.R`

As a operador,
I want gerar um snapshot canônico por linha de comando antes do draft,
So that o runtime live nunca precise adquirir ou enriquecer dados.

**Acceptance Criteria:**

**Given** uma configuração YAML de scoring compatível com `ffanalytics`
**When** executo `Rscript scripts/prepare_snapshot.R` apontando para essa configuração
**Then** o script coleta projeções via `ffanalytics` (commit fixado), calcula `points`, `vor`, `tier` e `tier_cliff`, e emite um bundle validado com `metadata.json`, `qa-report.json` e os hashes

**Given** um CSV manual com os campos obrigatórios e metadados necessários
**When** executo o script no modo de fallback CSV
**Then** ele produz o mesmo formato de bundle canônico

**Given** duas execuções em momentos diferentes
**When** o script roda
**Then** cada bundle recebe um `snapshot_id` único e nenhum bundle anterior é sobrescrito

**Given** falha de coleta ou configuração inválida
**When** o script roda
**Then** ele termina com código de saída não-zero e uma mensagem acionável, sem emitir um bundle parcial

### Story 1.5: Validação de qualidade do snapshot

As a operador,
I want que o app detecte problemas nos dados antes de eu iniciar um draft,
So that eu não conduza um draft sobre um snapshot quebrado.

**Acceptance Criteria:**

**Given** um bundle parseado
**When** a validação de qualidade (domínio puro) roda
**Then** ela classifica cada achado como bloqueante ou aviso e retorna a lista determinística

**Given** `player_id`, nome normalizado, posição, `points`, `vor`, `tier` ou metadado obrigatório ausente
**When** a validação roda
**Then** o achado é bloqueante

**Given** `player_id` duplicado, nome ambíguo sem desambiguação, posição fora do conjunto V1, ADP inválido quando informado, ou `qa-report` ausente/marcado como bloqueante
**When** a validação roda
**Then** cada um é um achado bloqueante

**Given** campos opcionais ausentes ou cobertura anômala não crítica
**When** a validação roda
**Then** o achado é um aviso e não impede o início

### Story 1.6: Design tokens base e tema escuro

As a operador,
I want uma interface de terminal sóbria e legível em varredura,
So that eu capte o estado e aja sem tirar os olhos do draft.

**Acceptance Criteria:**

**Given** o app Shiny
**When** qualquer superfície é renderizada
**Then** cores, tipografia, espaçamento, raio e anel de foco vêm do conjunto de tokens de `DESIGN.md`, sem valores visuais fora dos tokens

**Given** o tema
**When** o app carrega
**Then** ele é escuro único, sem alternância de modo claro no V1

**Given** os pares de cor permitidos
**When** o contraste é medido
**Then** `ink` sobre canvas/surface/surface-raised atinge ≥ 4.5:1, `ink-muted` atinge ≥ 4.5:1 e é usado só em metadados não críticos, e `focus`/`action`/`warning`/`danger` como indicador não textual atingem ≥ 3:1

**Given** qualquer estado sinalizado por cor
**When** ele é exibido
**Then** há também texto, ícone ou rótulo, nunca cor sozinha

### Story 1.7: Superfície "Selecionar e validar snapshot"

As a operador,
I want selecionar um bundle local e ver sua qualidade,
So that eu só avance para a configuração da liga com dados válidos.

**Acceptance Criteria:**

**Given** bundles locais preparados
**When** abro a superfície de preparação
**Then** o adapter de arquivos lista os bundles disponíveis e eu seleciono um explicitamente

**Given** um bundle selecionado
**When** ele é carregado
**Then** a superfície mostra temporada, geração, fontes, método, scoring e identidade de conteúdo, além da cobertura e dos avisos, com a região usando `aria-busy` durante a leitura

**Given** a validação retorna um achado bloqueante
**When** a superfície renderiza o resultado
**Then** o início fica bloqueado, a causa concreta é exibida em `danger` e sempre acompanha uma ação de recuperação (executar `script.R` novamente ou selecionar outro snapshot)

**Given** um snapshot já selecionado para uma sessão em preparação
**When** tento trocá-lo
**Then** a troca exige reiniciar o preparo; o snapshot selecionado é o input imutável da sessão (a imutabilidade pós-início é completada no Epic 2)

**Given** campos opcionais ausentes no snapshot
**When** a qualidade é exibida
**Then** cada ausência é sinalizada explicitamente e não bloqueia o avanço

---

## Epic 2: Liga, calendário e sessão mínima

O operador configura a liga dentro do envelope V1, cadastra os times, define a ordem da primeira rodada, revisa o calendário snake e trava tudo, criando uma sessão pronta. Este epic estabelece o domínio puro de liga/schedule e o event store SQLite mínimo.

> **Simplificações desta correção de curso (Sprint Change Proposal 2026-08-31):** sem runner de migrations versionadas nem histórico de migrations (`CREATE TABLE IF NOT EXISTS` no boot); sem serialização canônica nem `league_rules_hash`/`scoring_config_hash`/`recommendation_policy_hash`; o gate de compatibilidade de scoring é um aviso não-bloqueante; três superfícies de setup fundidas em uma.

### Story 2.1: Configuração da liga e envelope V1

As a operador,
I want definir as regras da liga em configuração validada,
So that o draft só comece com um roster viável dentro do envelope V1.

**Acceptance Criteria:**

**Given** arquivos YAML versionados de regras de liga, tiers e política de recomendação
**When** o parser de configuração os lê
**Then** ele produz objetos de configuração canônicos e a configuração de referência (12 times, Full PPR, 1 QB, 2 RB, 2 WR, 1 TE, 1 FLEX RB/WR, 1 K, 1 D/ST e 6 reservas) é o default fornecido

**Given** uma configuração com 8–14 times, exatamente 15 rounds, 9 titulares (QB, WR, WR, RB, RB, FLEX, TE, K, D/ST) e 6 reservas que preenchem exatamente os 15 rounds, com FLEX aceitando somente RB ou WR
**When** o validador roda
**Then** a configuração é marcada como viável

**Given** número de times fora de 8–14, rounds diferente de 15, definição de slots incompatível com 15 rounds, ou FLEX que aceite posição diferente de RB/WR
**When** o validador roda
**Then** a configuração é bloqueada com motivo acionável apontando o grupo afetado

**Given** o YAML de scoring compatível com `ffanalytics`
**When** o runtime o lê
**Then** ele o usa apenas para exibir a identidade do scoring; o runtime não aplica regras de scoring nem re-pontua jogadores — projeções, VOR e tiers já vieram computados no snapshot do Epic 1

**Given** um snapshot cujo `scoring_hash` diverge do scoring da configuração ativa
**When** a compatibilidade é verificada
**Then** o achado é um aviso não-bloqueante exibido antes do `start` (a decisão de prosseguir é do operador)

### Story 2.2: Calendário snake, times e ordem

As a operador,
I want cadastrar os times, definir a ordem da primeira rodada e ver todos os slots do draft antes de começar,
So that o calendário reflita a mesa real e eu confirme quem escolhe em cada pick.

**Acceptance Criteria:**

**Given** a contagem de times, 15 rounds e a ordem da primeira rodada
**When** o gerador de schedule (função pura) roda
**Then** ele produz todos os slots com overall pick contínuo, round, pick da rodada, time e indicador do time do usuário, com a ordem de cada round par sendo o inverso do round ímpar anterior e exatamente um slot por time por round

**Given** a mesma entrada
**When** o gerador roda duas vezes
**Then** o schedule é idêntico

**Given** a superfície de setup
**When** eu cadastro os times da liga
**Then** cada time recebe um identificador imutável e exatamente um time do operador é exigido por sessão

**Given** os times cadastrados
**When** eu escolho sortear a ordem
**Then** o sorteio usa uma seed registrada e o resultado é reproduzível; eu também posso reordenar manualmente antes do início e a grade snake completa é atualizada

**Given** uma superfície única agrupando times/rounds, slots/FLEX, scoring, time do operador e a grade de ordem
**When** um grupo tem valor inválido
**Then** a validade aparece junto ao grupo afetado e `Validate and Lock` permanece desabilitado até todos os grupos estarem viáveis

### Story 2.3: Event store SQLite mínimo e `start`

As a operador,
I want que cada comando aceito seja durável e que travar a sessão congele a proveniência,
So that nenhum pick confirmado se perca e nada mude por acidente durante o draft.

**Acceptance Criteria:**

**Given** um banco novo
**When** o app inicia
**Then** o boot cria as tabelas de sessões, eventos e `effective_pick_projection` com `CREATE TABLE IF NOT EXISTS` e habilita `PRAGMA journal_mode=WAL` e `foreign_keys=ON`

**Given** o event log
**When** eventos são anexados
**Then** o log é append-only e `event_sequence` é monotônico por draft

**Given** a `effective_pick_projection`
**When** ela é materializada
**Then** o banco impõe `(draft_id, overall_pick)` único e `(draft_id, player_id)` único

**Given** um comando aceito
**When** ele é persistido
**Then** o evento, as effective picks e o estado derivado são substituídos na mesma transação; uma falha não commita nada

**Given** configuração viável e ordem completa
**When** eu aciono `Validate and Lock`
**Then** o use case `start` anexa um evento `DRAFT_STARTED` que congela `snapshot_id`, `snapshot_content_hash` (do Epic 1), os valores de scoring/regras/política, a versão do engine e a seed opcional, e materializa o estado inicial na mesma transação

**Given** uma sessão iniciada
**When** tento trocar o snapshot ou reordenar por fluxo normal
**Then** a ação é indisponível

**Given** configuração fora do envelope ou ordem incompleta
**When** eu aciono `Validate and Lock`
**Then** nenhum evento é anexado e a interface explica a correção necessária

---

## Epic 3: Domínio de draft, recomendação e simulação

Fora de Shiny e SQLite, o domínio puro constrói rosters e o melhor lineup, calcula ganho marginal, produz recomendações rápidas e explicáveis, executa busca incremental, aplica undo/correção/replay por eventos e roda a simulação de draft snake. Este é o núcleo do produto.

> **Ordem de execução:** `3.1 → 3.2 → 3.3 → 3.5 → 3.6 → 3.4`. O domínio puro e a simulação (`simulate_draft.R`) vêm antes dos use cases de comando, permitindo calibrar o algoritmo por script antes da UI.
>
> **Simplificações desta correção de curso (Sprint Change Proposal 2026-08-31):** replay sem verificação de `previous_state_hash`/`resulting_state_hash`; sem `expected_state_hash` nas intenções (só `expected_overall_pick` nos picks); sem contrato de canonical JSON de estado (AD-12 removido); gate de benchmark p95 substituído por smoke checks; recovery drill parametrizado substituído por um teste de reabertura do banco.

### Story 3.1: Roster, melhor lineup e ganho marginal (puro)

As a operador,
I want ver o melhor lineup titular possível de um roster e quanto um candidato agrega ao meu,
So that eu entenda o valor real das escolhas e decida com o impacto em vista.

**Acceptance Criteria:**

**Given** as picks efetivas de uma sessão
**When** o domínio de roster (função pura) roda
**Then** ele constrói o roster de todos os times a partir das picks efetivas

**Given** um roster e a definição de slots da liga
**When** o melhor lineup é calculado
**Then** ele maximiza os pontos projetados dos titulares respeitando a elegibilidade de posição, tratando o FLEX como slot de elegibilidade múltipla (RB ou WR)

**Given** um roster parcialmente preenchido
**When** o lineup é calculado
**Then** cada slot é classificado como titular vazio, upgrade, FLEX, banco ou redundância

**Given** um candidato e o roster atual do operador
**When** o ganho marginal (função pura) é calculado
**Then** ele retorna a diferença entre o melhor lineup com e sem o candidato

**Given** os rounds restantes e os slots obrigatórios ainda não preenchidos
**When** uma escolha candidata tornaria impossível completar os slots obrigatórios
**Then** o domínio sinaliza um alerta ou restrição com a condição específica

**Given** a mesma entrada
**When** o cálculo roda duas vezes
**Then** o resultado é idêntico e determinístico

### Story 3.2: Motor de recomendação `recommend_fast()` (puro)

As a operador,
I want uma lista curta de candidatos com o motivo objetivo de cada um,
So that eu confie na recomendação sem tratá-la como certeza.

**Acceptance Criteria:**

**Given** o estado congelado do draft, as métricas do snapshot em memória, a configuração da liga e a política
**When** `recommend_fast()` roda
**Then** ela é pura e determinística e retorna candidatos ordenados com score, componentes do score, ao menos três fatores estruturados aplicáveis, reason codes, texto determinístico, avisos e versão do engine

**Given** qualquer pick do operador
**When** a lista é renderizada
**Then** há ao menos cinco candidatos disponíveis, o score usa VOR/tier/ADP-como-preço, e os fatores distinguem projeção, valor, preço de mercado e urgência — nenhuma recomendação é um número opaco

**Given** um candidato próximo de um limite de tier
**When** a recomendação é calculada
**Then** o alerta de tier cliff aparece quando aplicável

**Given** a política que desprioriza K/DST cedo
**When** a recomendação é calculada no início do draft
**Then** K e DST são despriorizados no conjunto inicial e a política ativa é consultável

**Given** um pick registrado, desfeito ou corrigido
**When** o estado muda
**Then** o ranking é recalculado, sem scraping, scan SQL ou simulação no caminho crítico

**Given** [ABERTO — decidir ao entrar no Epic 3] a inclusão de um fator de urgência no V1
**When** a decisão for incluir
**Then** o fator de urgência é o cálculo determinístico de valor sobre o próximo disponível (distância até o próximo pick do operador no calendário snake + ADP), reusado da estratégia Pure VONA, sem modelo de mercado probabilístico

### Story 3.3: Busca incremental de jogadores (puro)

As a operador,
I want encontrar um jogador disponível digitando parte do nome,
So that eu registre o pick sem tirar os olhos do draft.

**Acceptance Criteria:**

**Given** o snapshot carregado e uma sessão ativa
**When** digito caracteres no campo de busca
**Then** a query retorna incrementalmente os jogadores disponíveis cujo `normalized_name` casa, cada um com nome de exibição, posição e time NFL

**Given** uma busca com acentos, apóstrofos, hífens ou variação simples de grafia
**When** a query roda
**Then** ela tolera essas variações via `normalized_name` e ainda casa o jogador

**Given** um jogador já escolhido em qualquer time
**When** a busca roda
**Then** ele não aparece nos resultados

**Given** uma busca sem correspondência
**When** a query roda
**Then** ela retorna vazio e o estado do draft permanece intacto

### Story 3.5: Estratégias de seleção como funções puras

As a analista,
I want cada estratégia de draft como uma função pura comparável,
So that a simulação troque de estratégia sem mudar o runner.

**Acceptance Criteria:**

**Given** os jogadores disponíveis, o roster do time e o contexto do pick (round, overall, slots restantes)
**When** uma função de estratégia é chamada
**Then** ela retorna o `player_id` escolhido de forma determinística para uma mesma entrada e seed

**Given** o conjunto V1 de estratégias
**When** o pacote é carregado
**Then** existem ADP, Total Points (projeção), Random (com seed), Pure VOR, Pure VONA e a estratégia de recomendação do app, todas com a mesma assinatura

**Given** a estratégia do app
**When** ela roda na simulação
**Then** ela reusa `recommend_fast()` e escolhe o candidato nº 1, sem depender de Shiny, SQLite ou rede

**Given** a estratégia Pure VONA
**When** ela roda
**Then** ela usa a distância até o próximo pick do time no calendário snake e o ADP para estimar o valor sobre o próximo disponível, sem modelo de mercado externo

### Story 3.6: Runner de simulação, avaliação e relatório

As a analista,
I want simular um draft snake completo via script e ver como cada estratégia se comporta,
So that eu compare a estratégia do app contra as baselines de forma objetiva e reproduzível.

**Acceptance Criteria:**

**Given** um snapshot preparado e uma configuração de liga válida
**When** executo `Rscript scripts/simulate_draft.R` com uma seed
**Then** o runner sorteia a ordem dos times a partir da seed e a registra na saída

**Given** a atribuição de estratégias
**When** o runner inicia
**Then** o time do operador usa a estratégia em teste e os demais times usam as estratégias configuradas (default configurável)

**Given** a simulação em execução
**When** o runner processa as rodadas
**Then** ele executa todas as 15 rodadas do snake reusando o gerador de calendário e o domínio de roster, registrando cada pick com round, overall, time, estratégia e jogador

**Given** os rosters finais da simulação
**When** a avaliação roda
**Then** ela calcula, para cada time, os pontos projetados só dos titulares (melhor lineup), só do banco e a soma combinada, produz o ranking por pontuação combinada e destaca a posição do time do operador, usando o mesmo domínio de roster do runtime live

**Given** uma simulação concluída
**When** o relatório é emitido
**Then** ele contém a ordem sorteada, as seeds, a estratégia de cada time, os picks por rodada, as pontuações (titulares/banco/combinada) e o ranking, em console e CSV

**Given** a mesma seed, snapshot e atribuição de estratégias
**When** o runner roda duas vezes
**Then** o resultado é idêntico

**Given** a opção de repetição
**When** executo N simulações com seeds variadas
**Then** o relatório agrega os resultados por estratégia (ex.: média e distribuição da pontuação combinada e do rank do operador)

**Given** o runner
**When** ele executa
**Then** ele não abre o banco de sessões do runtime, não anexa eventos de draft e não acessa a rede

### Story 3.4: Use cases `record_pick`, `undo_last_pick`, `correct_pick` e replay

As a operador,
I want confirmar, desfazer e corrigir picks com o estado sempre consistente,
So that eu conduza o draft e recupere erros sem perder o ritmo nem a trilha.

**Acceptance Criteria:**

**Given** um jogador disponível e o pick atual
**When** o use case `record_pick` roda com `expected_overall_pick` correto
**Then** ele anexa exatamente um evento `RECORD_PICK` ordenado, associa o jogador ao time do slot, avança o pick atual e substitui o read model na mesma transação

**Given** um jogador já registrado como pick efetivo, ou `expected_overall_pick` obsoleto
**When** `record_pick` roda
**Then** o comando é rejeitado com erro estruturado e instrução de recarga, nenhum evento é anexado e o estado não muda

**Given** ao menos um pick efetivo
**When** aplico `undo_last_pick`
**Then** um evento `UNDO` é anexado, o replay passa a remover o pick efetivo mais recente, a operação é repetível e a auditoria mantém todos os eventos de undo

**Given** um pick alvo no board e um jogador ainda disponível
**When** aplico `correct_pick` nomeando o `overall_pick` alvo e o `player_id` substituto
**Then** um evento `CORRECTION` é anexado, o replay aplica a correção na sequência e todos os picks posteriores são preservados

**Given** uma correção que resultaria em jogador duplicado, violação de slot ou invalidação de qualquer pick efetivo posterior
**When** aplico `correct_pick`
**Then** a correção é rejeitada, nenhum evento é anexado e a interface explica qual condição falhou

**Given** o log de eventos ordenado por `event_sequence`
**When** o replay roda
**Then** ele reconstrói o estado aplicando cada evento em ordem, sem verificação de hash de estado

**Given** o último slot do draft aberto
**When** `record_pick` registra esse pick
**Then** a projeção resultante transiciona para `COMPLETED` na mesma transação

**Given** uma interrupção do processo imediatamente após o commit de um pick
**When** o app reinicia e a sessão é restaurada
**Then** um teste de reabertura do banco confere que o pick confirmado está presente e o estado é consistente

**Given** um draft completo simulado de 168 picks
**When** o smoke check de latência roda
**Then** ele conclui em tempo folgado num laptop de referência e nenhuma operação síncrona do fluxo live acessa a rede

---

## Epic 4: Live War Room

Na tela live o operador vê o estado global, busca um jogador por teclado, registra o pick com feedback imediato e vê board, roster, disponíveis e recomendações recomporem; desfaz, corrige um pick pelo board, mantém uma blacklist e restaura sessões locais.

> **Simplificações desta correção de curso (Sprint Change Proposal 2026-08-31):** tema escuro único com os design tokens do Epic 1; keyboard-first com ARIA básico (roles/labels no combobox e uma região `aria-live`) — sem `aria-controls`/`aria-activedescendant`, roving tabindex, auditoria de contraste como entregável, `prefers-reduced-motion`, leitura linear a 200% ou piso de alvo de 24 px; dois estados de layout (amplo/estreito); sem `pause`/`resume` como par de eventos.

### Story 4.1: Casca da Live War Room — estado, board e roster

As a operador,
I want o pick atual, o board e o meu roster sempre à vista,
So that eu acompanhe o estado sem procurar num dashboard.

**Acceptance Criteria:**

**Given** a Live War Room
**When** ela é renderizada
**Then** a faixa de estado fixa mostra o overall pick em `typography.display`, a rodada e o pick da rodada, o time no relógio, o último jogador registrado e o próximo pick do operador, e nunca sai da vista

**Given** um comando aceito
**When** o estado muda
**Then** a faixa atualiza como uma unidade; o pick vivo usa `action` e os estados pausado, alerta e concluído usam texto e ícone além de cor

**Given** a sessão ativa
**When** o board é renderizado
**Then** ele é uma grade compacta por round e time com a linha ou coluna do pick atual claramente marcada; um pick recém-registrado recebe realce transitório em `action` sem animação prolongada; os picks do operador são distinguíveis por rótulo

**Given** o roster do operador
**When** o painel é renderizado
**Then** ele agrupa titulares, FLEX e banco em grupos visuais estáveis, torna visíveis o melhor lineup e os slots vazios, e mostra o impacto marginal do candidato em foco

**Given** largura de janela ampla ou reduzida
**When** a Live War Room é exibida
**Then** board e roster são painéis laterais em tela ampla e painéis empilhados em tela estreita, preservando o estado, enquanto faixa de estado, busca e lista de candidatos permanecem sempre visíveis; o grid do board rola horizontalmente quando necessário

### Story 4.2: Busca, lista inteligente, inspeção e teclado

As a operador,
I want um campo de busca dominante e uma lista de candidatos navegável por teclado,
So that eu compare e registre o pick certo sem ambiguidade e sem o mouse.

**Acceptance Criteria:**

**Given** a Live War Room
**When** ela é renderizada
**Then** o campo de busca tem largura dominante, os resultados aparecem imediatamente abaixo com nome, posição e time NFL, e o resultado que `Enter` registrará usa `candidate-active` e contorno de foco

**Given** o autocomplete
**When** ele é inspecionado
**Then** ele é um combobox com `role`, label persistente e `aria-expanded`, e uma única região `aria-live=polite` anuncia o comando aceito em frase curta

**Given** a recomendação ativa
**When** a lista inteligente é renderizada
**Then** ela mostra ao menos cinco candidatos disponíveis ordenados pela recomendação, cada linha distinguindo score, fatores, alerta de tier cliff e impacto no roster, com a nº 1 destacada por ordem e peso tipográfico, nunca por card grande

**Given** os badges de filtro de posição
**When** eu ativo um filtro
**Then** a lista de disponíveis e de recomendações é filtrada sem alterar o estado do draft

**Given** o foco fora de uma entrada editável
**When** uso setas, `Espaço`, `Enter`, `U` ou `/`
**Then** as setas movem o destaque, `Espaço` abre/fecha a inspeção, `Enter` tenta registrar no pick atual, `U` aplica um undo por tecla e `/` foca a busca; dentro de uma entrada editável esses atalhos globais não disparam

**Given** um candidato focado
**When** pressiono `Espaço`
**Then** o painel de inspeção abre numa superfície `surface-raised` sem cobrir a faixa de estado ou a busca, mostrando a explicação determinística (projeção, valor, preço de mercado, urgência quando aplicáveis), tier e impacto marginal no roster; um campo opcional ausente aparece como `Não disponível neste snapshot`; `Esc` fecha e devolve o foco à lista

### Story 4.3: Feedback, erros e blacklist

As a operador,
I want confirmação breve dos picks, erros que não somem antes de eu agir e uma blacklist de jogadores,
So that eu opere rápido sem perder informação e sem sugestões poluídas.

**Acceptance Criteria:**

**Given** um pick confirmado
**When** o feedback aparece
**Then** ele é breve, textual, próximo à faixa de estado, substitui a lista em menos de um ciclo de atenção e devolve o fluxo à busca

**Given** um jogador já escolhido, nome ambíguo ou inválido
**When** tento registrar
**Then** nada é persistido, a mensagem identifica o motivo (e o pick efetivo quando existir) e o foco volta à busca/lista

**Given** um erro ou bloqueio
**When** ele é exibido
**Then** ele persiste até o operador poder agir, não rouba o foco e não encobre a busca, o pick atual nem o foco de teclado; não há modal de confirmação rotineiro

**Given** qualquer microcopy de confirmação, erro ou estado
**When** ela é redigida
**Then** ela é curta, factual e orientada à próxima ação (ex.: `Registrado: Ja'Marr Chase`, `Já escolhido no pick 42. Busque outro jogador.`), sem celebração, alarmismo ou confiança preditiva, e mensagens de domínio ficam em PT-BR

**Given** o editor de blacklist na Live War Room
**When** adiciono ou removo um jogador por busca
**Then** a mudança tem efeito imediato, é anunciada sem roubar o foco e sobrevive a refresh sem entrar no estado do draft nem gerar evento

**Given** um jogador na blacklist
**When** a lista inteligente e as recomendações são renderizadas
**Then** ele é omitido de ambas, mas ainda aparece na busca com marcação explícita (texto e ícone, nunca só cor) e continua draftável

### Story 4.4: Undo visível, histórico, correção no board e seleção de sessão

As a operador,
I want undo sempre visível, histórico auditável, correção pelo board e restauração explícita de sessão,
So that eu conserte erros no lugar e nunca restaure a sessão errada por acidente.

**Acceptance Criteria:**

**Given** a Live War Room
**When** ela é exibida
**Then** o controle Undo está sempre visível, acionável por `U`, com borda e texto em `warning`, mostrando o próximo pick a desfazer (overall, jogador, time) e o contador de reversões disponíveis, e não é apresentado como ação destrutiva

**Given** a sessão
**When** o histórico de eventos é renderizado
**Then** ele lista registros, undos e correções em ordem, em `ink-muted`, cada um com alvo e resultado efetivo, sem competir com o board e sem apagar nenhum pick da auditoria

**Given** uma célula de pick corrigível no board
**When** pressiono `Enter` ou `Espaço`
**Then** um único painel contextual de correção abre (nunca uma pilha de modais), recebe o foco e o devolve à mesma célula ao cancelar, falhar ou concluir, sem esconder os picks posteriores

**Given** sessões locais existentes
**When** abro ou recarrego o app
**Then** uma superfície lista as sessões por `updated_at DESC`, pré-seleciona a mais nova, mostra skeleton durante o carregamento e não restaura nada silenciosamente

**Given** a linha pré-selecionada ou outra escolhida
**When** pressiono `Enter` ou clico em Confirmar
**Then** só então a sessão é restaurada, usando o `draft_id` selecionado como único input, sem perda nem duplicação de picks

**Given** nenhuma sessão recuperável
**When** a superfície é exibida
**Then** ela explica que ainda não há sessão local e leva o foco para iniciar Preparar draft

**Given** uma sessão retomada
**When** o operador a reabre
**Then** um flag de status impede o registro acidental de picks até o operador retomar explicitamente (sem par de eventos `PAUSE`/`RESUME` dedicado)

**Given** uma intenção mutante cujo `expected_overall_pick` não bate com o estado atual
**When** o use case a processa
**Then** ela é rejeitada com erro estruturado e instrução de recarga, sem alterar o estado

---

## Epic 5: Fechar e exportar

Ao preencher o último slot a sessão encerra normalmente; o operador exporta picks, rosters, configuração e metadados do snapshot para consulta posterior.

> **Simplificações desta correção de curso (Sprint Change Proposal 2026-08-31):** sem abort administrativo (`complete` é a única transição terminal); exportações em CSV/JSON simples, sem framing de proveniência "para auditor" nem hashes canônicos; quatro stories fundidas em uma.

### Story 5.1: Completar e exportar

As a operador,
I want que o draft encerre ao preencher o último slot e eu possa exportar o resultado,
So that eu não registre picks fora do envelope e consulte o draft depois.

**Acceptance Criteria:**

**Given** o último slot do draft aberto
**When** `record_pick` registra esse pick
**Then** a projeção resultante transiciona para `COMPLETED` na mesma transação (comportamento já entregue na Story 3.4)

**Given** uma sessão `COMPLETED`
**When** a Live War Room é exibida
**Then** o registro normal de pick deixa de estar disponível, o estado "draft completo" é explícito por texto e ícone e o foco vai para Exportar

**Given** uma sessão `COMPLETED`
**When** eu exporto picks
**Then** o artefato derivado (CSV/JSON) contém todos os picks efetivos com overall pick, round, time e jogador

**Given** a mesma sessão
**When** eu exporto rosters
**Then** o artefato contém o roster de cada time e o melhor lineup do operador

**Given** a mesma sessão
**When** eu exporto configuração e metadados
**Then** o artefato contém as regras de liga, o scoring e a política em forma legível, os metadados do snapshot (temporada, geração, fontes, método), o `snapshot_id`, o `snapshot_content_hash`, a versão do engine e um timestamp

**Given** qualquer exportação
**When** o artefato é gravado
**Then** ele fica no diretório de dados do usuário fora do código-fonte e não é estado autoritativo

**Given** uma exportação em andamento ou concluída
**When** a região de exportação é exibida
**Then** ao concluir ela anuncia o artefato disponível e, ao falhar, mantém a sessão e oferece nova tentativa; a exportação nunca aparece como ação destrutiva
