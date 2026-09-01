# Epic 3 Context: Domínio de draft, recomendação e simulação

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Este é o núcleo do produto. Fora de Shiny e de SQLite, o domínio puro constrói os rosters de todos os times e o melhor lineup titular, calcula o ganho marginal de um candidato, produz recomendações rápidas e explicáveis via `recommend_fast()`, executa busca incremental de jogadores e aplica `record_pick` / `undo_last_pick` / `correct_pick` por eventos com replay. O epic também entrega as estratégias de seleção como funções puras comparáveis e o runner `scripts/simulate_draft.R`, que roda um draft snake completo comparando a estratégia do app contra baselines de forma reproduzível. A ordem de execução `3.1 → 3.2 → 3.3 → 3.5 → 3.6 → 3.4` coloca o algoritmo e a simulação antes dos use cases de comando, permitindo calibrar a recomendação por script antes de qualquer tela. A UI de tudo isso é do Epic 4.

## Stories

- Story 3.1: Roster, melhor lineup e ganho marginal (puro)
- Story 3.2: Motor de recomendação `recommend_fast()` (puro)
- Story 3.3: Busca incremental de jogadores (puro)
- Story 3.5: Estratégias de seleção como funções puras
- Story 3.6: Runner de simulação, avaliação e relatório
- Story 3.4: Use cases `record_pick`, `undo_last_pick`, `correct_pick` e replay

## Requirements & Constraints

- **Melhor lineup:** maximiza os pontos projetados dos titulares respeitando a elegibilidade de posição, com o FLEX como slot de elegibilidade múltipla (RB ou WR). Cada slot do roster é classificado como titular vazio, upgrade, FLEX, banco ou redundância.
- **Ganho marginal** de um candidato = melhor lineup do roster do operador com o candidato menos o melhor lineup sem ele.
- **Viabilidade de roster:** quando uma escolha candidata tornaria impossível completar os slots obrigatórios nos rounds restantes, o domínio sinaliza alerta ou restrição com a condição específica.
- **`recommend_fast()`** retorna candidatos ordenados com score, componentes do score, ao menos três fatores estruturados aplicáveis, reason codes, texto determinístico, avisos e versão do engine. Ao menos cinco candidatos disponíveis por pick. Nenhuma recomendação é um número opaco; os fatores distinguem projeção, valor, preço de mercado e urgência.
- **Score** usa VOR / tier / ADP-como-preço (ADP é preço de mercado, não previsão de valor) e é roster-aware (usa 3.1). Alerta de tier cliff quando o candidato está próximo de um limite de tier. Política configurável desprioriza K/DST cedo e é consultável. Ranking recalcula a cada pick registrado, desfeito ou corrigido.
- **[DECISÃO EM ABERTO — resolver ao entrar no epic]** inclusão de um fator de urgência no V1: se incluído, é o cálculo determinístico de valor sobre o próximo disponível (distância até o próximo pick do operador no calendário snake + ADP), reusado da estratégia Pure VONA — sem modelo de mercado probabilístico. O PRD adia isso (REC-008), mas EXPL-004 já exige que a UI distinga "urgência". Recomendação da Sprint Change Proposal: incluir.
- **Busca:** match incremental em `normalized_name`, tolerante a acentos, apóstrofos, hífens e variações simples de grafia; retorna nome de exibição, posição e time NFL; oculta jogadores já escolhidos em qualquer time; sem correspondência ⇒ vazio, estado do draft intacto.
- **Estratégias (assinatura única):** `(disponíveis, roster_do_time, contexto_do_pick) → player_id`, determinística por entrada + seed. Conjunto V1: ADP, Total Points (projeção), Random (com seed), Pure VOR, Pure VONA e a estratégia do app (reusa `recommend_fast()` e escolhe o candidato nº 1). Pure VONA usa distância até o próximo pick do time no calendário + ADP, sem modelo de mercado externo.
- **Runner de simulação (`scripts/simulate_draft.R`):** recebe seed, sorteia a ordem dos times (seed registrada na saída), atribui estratégia por time (a do operador em teste, as demais configuráveis com default), roda as 15 rodadas reusando o gerador de calendário do Epic 2 e o domínio de roster, e registra cada pick (round, overall, time, estratégia, jogador). Não abre o banco de sessões, não anexa eventos, não acessa a rede.
- **Avaliação da simulação:** por time, pontos projetados só dos titulares (melhor lineup), só do banco e a soma combinada; ranking por pontuação combinada com a posição do operador destacada. Usa o mesmo domínio de roster do runtime live.
- **Relatório:** ordem sorteada, seeds, estratégia de cada time, picks por rodada, pontuações e ranking, em console + CSV, reproduzível pela seed. Opção de N execuções com seeds variadas, agregando por estratégia (média e distribuição da pontuação combinada e do rank do operador).
- **Use cases de comando:** cada um entra por um único ponto de aplicação, valida contra o estado reconstruído, anexa exatamente um evento ordenado e substitui a projeção na mesma transação SQLite; falha ou validação obsoleta não commita nada.
  - `record_pick`: valida disponibilidade + `expected_overall_pick` (checagem barata contra tela obsoleta), associa o jogador ao time do slot, avança o pick; jogador já efetivo ⇒ rejeitado sem anexar evento; ao preencher o último slot, transiciona para `COMPLETED` na mesma transação.
  - `undo_last_pick`: evento `UNDO`; o replay passa a remover o pick efetivo mais recente; repetível; a auditoria mantém todos os eventos de undo.
  - `correct_pick`: evento `CORRECTION` nomeando o `overall_pick` alvo e o `player_id` substituto; o replay aplica na sequência preservando os picks posteriores; rejeitado (sem anexar evento) se resultaria em jogador duplicado, violação de slot ou invalidação de qualquer pick efetivo posterior.
- **Replay** reconstrói o estado aplicando eventos por `event_sequence`, sem verificação de hash de estado.
- **Determinismo:** todo cálculo de domínio (roster, lineup, ganho marginal, `recommend_fast()`, estratégias) roda duas vezes com a mesma entrada e produz resultado idêntico.
- **Smoke checks (no lugar de gates formais):** um teste reabre o banco após um pick commitado e confere que o pick está presente e o estado consistente; um teste roda um draft completo simulado de 168 picks e afirma que conclui em tempo folgado num laptop de referência e que nenhuma operação síncrona do fluxo live acessa a rede.

## Technical Decisions

- **Arquitetura hexagonal (AD-1).** Todo o domínio deste epic é puro: determinístico, todo input explícito, retorna valores ou erros de domínio estruturados, nunca importa `shiny`, `DBI`, `RSQLite`, `yaml`, filesystem, relógio ou APIs reativas. Os use cases da aplicação são os únicos chamadores de comandos de domínio e de ports.
- **`recommend_fast()` é função de domínio pura (AD-9)** sobre estado congelado + métricas do snapshot em memória + configuração da liga + política. O caminho de leitura live usa métricas em memória e lookup indexado de disponíveis; sem scraping, scan SQL ou simulação profunda no caminho crítico. Market forecasting e Monte Carlo não executam no caminho live (ficam para o V2/V3).
- **Comandos anexam eventos atomicamente; estado é projeção determinística (AD-4).** Payload do evento com `{draft_id, event_sequence, event_type, expected_overall_pick, target_overall_pick, player_id, actor, created_at}` conforme aplicável. `complete` é a única transição terminal. **Sem** `expected_state_hash` / `previous_state_hash` / `resulting_state_hash` (Sprint Change Proposal 2026-08-31; AD-12 removido). Só `expected_overall_pick` nos picks. Event types em UPPER_SNAKE_CASE.
- **Correções preservam história e picks posteriores (AD-5).** Undo e correção são eventos; o replay não verifica hashes de estado — a consistência é verificada por testes, não por hashes reproduzíveis entre implementações.
- **Simulação por script entra no V1 (AD-9, mapa de capacidades).** Simulação snake determinística e backtesting de estratégias via `simulate_draft.R` são domínio puro, offline, sem command handling. Monte Carlo, jobs assíncronos e modelagem probabilística de adversários continuam diferidos.
- **Erros de domínio:** `code` estável + mensagem PT-BR + detalhes machine-readable; nunca exceção não tratada.
- **Convenções:** `snake_case`; funções de domínio são verbos (`record_pick`, `build_roster`, `recommend_fast`); IDs de texto imutáveis; `event_sequence` é a ordem autoritativa, nunca a ordem de timestamp; timestamps UTC ISO-8601.
- **Contrato de dados do snapshot (do Epic 1):** por jogador, obrigatórios `player_id`, `display_name`, `normalized_name`, `position` (QB/RB/WR/TE/K/DST), `points`, `vor`, `tier`, `tier_cliff`; `nfl_team` quando conhecido; opcionais `floor/ceiling/sd_points/ecr/adp/adp_sd/uncertainty/bye_week` — ausência é visível e não-bloqueante. As projeções, VOR e tiers já vieram computados; o runtime não re-pontua.
- **Estrutura:** `R/domain_*.R` (roster, estado, recomendação, estratégia, busca), `R/application_*.R` (use cases `record_pick` / `undo_last_pick` / `correct_pick` / replay + ports), `R/adapter_sqlite_*.R` (event store, read model do Epic 2), `scripts/simulate_draft.R`, `config/` (YAML de tiers e política de recomendação).
- **Testes:** domínio testado fora de Shiny/SQLite; use cases testados contra um banco SQLite temporário; fixtures de aceitação usam a base de 12 times.

## Cross-Story Dependencies

- **Depende do Epic 2:** gerador de calendário snake (reusado por 3.1, 3.5, 3.6); event store SQLite mínimo, `effective_pick_projection` e log de eventos append-only (base de 3.4); `DRAFT_STARTED` que congela snapshot + valores de config + política + seed; parser de configuração YAML.
- **Depende do Epic 1:** métricas do snapshot em memória (`points`, `vor`, `tier`, `tier_cliff`, ADP e campos opcionais), `normalized_name` para a busca, `snapshot_id` / `snapshot_content_hash` para proveniência.
- **Ordem interna:** `3.1 → 3.2 → 3.3 → 3.5 → 3.6 → 3.4`. 3.1 alimenta 3.2 (roster-aware) e 3.6 (avaliação). 3.2 é reusada por 3.5 (estratégia do app) e 3.5 por 3.6. 3.4 (use cases de comando) vem por último, após o algoritmo estar calibrado pela simulação.
- **Primeiro artefato executável de valor:** `simulate_draft.R` rodando um draft completo comparando a estratégia do app contra as baselines — antes de qualquer tela da Live War Room.
- **Habilita o Epic 4:** a UI da Live War Room consome `recommend_fast()`, a busca incremental, o domínio de roster/lineup/ganho marginal e os use cases `record_pick` / `undo_last_pick` / `correct_pick`; o histórico de eventos e o controle Undo são apresentações do log e do replay entregues aqui.
- **Habilita o Epic 5:** o domínio de roster e melhor lineup alimenta a exportação de rosters; a transição `COMPLETED` de `record_pick` é o gatilho do fechamento.
