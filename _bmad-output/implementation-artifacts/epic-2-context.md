# Epic 2 Context: Liga, calendário e sessão mínima

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Com um snapshot válido selecionado no Epic 1, o operador agora monta a sessão: define as regras da liga dentro do envelope V1, cadastra os times da mesa, identifica o próprio time, define/sorteia/reordena a ordem da primeira rodada, revisa o calendário snake completo e aciona `Validate and Lock` para congelar tudo. O epic entrega três blocos: o domínio puro de liga e de geração de calendário snake; o parser de configuração YAML com validação de envelope (sem serialização canônica nem hashing de config); e o event store SQLite mínimo — tabelas criadas no boot com `CREATE TABLE IF NOT EXISTS`, log append-only com `event_sequence` monotônico, `effective_pick_projection` materializada e o evento `DRAFT_STARTED` que congela a proveniência da sessão. É o pré-requisito de dados e de persistência para o núcleo de draft/simulação do Epic 3.

## Stories

- Story 2.1: Configuração da liga e envelope V1
- Story 2.2: Calendário snake, times e ordem
- Story 2.3: Event store SQLite mínimo e `start`

## Requirements & Constraints

- **Envelope da liga V1:** 8–14 times, exatamente 15 rounds, 9 titulares (QB, 2 WR, 2 RB, FLEX, TE, K, D/ST) e 6 reservas que preenchem exatamente os 15 rounds. FLEX aceita somente RB ou WR. Valores fora disso bloqueiam o início com motivo acionável apontando o grupo afetado; nada é congelado enquanto qualquer grupo estiver inviável.
- **Configuração de referência (default fornecido):** 12 times, Full PPR, 1 QB / 2 RB / 2 WR / 1 TE / 1 FLEX RB-WR / 1 K / 1 D/ST + 6 reservas. As contagens numéricas de liga em docs são referências não-normativas — o envelope 8–14 é a regra.
- **Exatamente um time do operador por sessão.** Cada time recebe um identificador de texto imutável no cadastro.
- **Scoring é só identidade.** O runtime lê o YAML de scoring apenas para exibir a identidade do scoring; não re-pontua jogadores nem aplica regras de scoring — `points`, `vor`, `tier` e `tier_cliff` já vieram computados no snapshot do Epic 1.
- **Compatibilidade de scoring é aviso não-bloqueante.** Se o `scoring_hash` do snapshot diverge do scoring da configuração ativa, exibir o aviso antes do `start`; a decisão de prosseguir é do operador.
- **Ordem da primeira rodada:** registrável manualmente, sorteável com seed registrada (resultado reproduzível) e reordenável antes do início. Rounds pares invertem a ordem dos ímpares; exatamente um slot por time por round; overall pick contínuo.
- **Geração de calendário é função pura e determinística:** mesma entrada (contagem de times, 15 rounds, ordem da primeira rodada) produz calendário idêntico em qualquer execução. Cada slot expõe overall pick, round, pick da rodada, time e indicador do time do operador. (A UI/board desses slots é do Epic 4; aqui é só o gerador de domínio.)
- **Durabilidade transacional:** evento + effective picks + estado derivado são substituídos na mesma transação SQLite; uma falha não commita nada.
- **`DRAFT_STARTED` congela:** `snapshot_id`, `snapshot_content_hash` (do Epic 1), os **valores** resolvidos de scoring/regras/política, versões de schema, versão do engine e seed opcional; materializa o estado inicial na mesma transação. Após o `start`, trocar o snapshot ou reordenar pelo fluxo normal fica indisponível.
- **Bloqueio do `start`:** configuração fora do envelope ou ordem incompleta ⇒ nenhum evento é anexado e a interface explica a correção necessária.
- Cobre os comandos de persistência de base (`start`), a persistência atômica de comando e o registro de timestamp/ordenação de eventos que o Epic 3 usará para picks/undo/correção.

## Technical Decisions

- **Arquitetura hexagonal (AD-1).** Domínio de liga e de schedule é puro: determinístico, todo input explícito, retorna valores ou erros de domínio estruturados, nunca importa `shiny`, `DBI`, `RSQLite`, `yaml`, filesystem ou relógio. Casos de uso da aplicação são os únicos chamadores de comandos de domínio e de ports. A UI só emite intenções.
- **Erros de domínio:** `code` estável + mensagem PT-BR + detalhes machine-readable; nunca exceção não tratada.
- **Configuração é dado validado, não comportamento (AD-7).** YAML versionado em `config/` parseado em objetos de configuração canônicos; o validador impõe o envelope V1 antes do `start`; os **valores** parseados são o que se persiste com a sessão. Sem serialização canônica, sem `league_rules_hash` / `scoring_config_hash` / `recommendation_policy_hash`, sem guard formal de "rejeita lógica arbitrária".
- **Event store SQLite (AD-8).** Tabelas de sessões, eventos e `effective_pick_projection` criadas no boot com `CREATE TABLE IF NOT EXISTS`; `PRAGMA journal_mode=WAL` e `foreign_keys=ON`. Log append-only, sem constraint de unicidade no histórico de jogador. O banco impõe `event_sequence` monotônico por draft, `(draft_id, overall_pick)` único e `(draft_id, player_id)` único na `effective_pick_projection`. **Sem** runner de migrations versionadas, **sem** tabela de histórico de migrations, **sem** cursor de projeção como conceito separado. Exports são artefatos derivados.
- **Eventos (AD-4).** Um use case por comando; um evento ordenado imutável; projeção materializada substituída na mesma transação; validação/falha obsoleta não commita nada. Payload com `{draft_id, event_sequence, event_type, ...}` conforme aplicável. **Sem** `expected_state_hash` / `previous_state_hash` / `resulting_state_hash`. Event types em UPPER_SNAKE_CASE.
- **Proveniência congelada (AD-6):** no `DRAFT_STARTED`, defaults do YAML resolvidos e tipos coeridos antes do uso; proveniência = snapshot id/hash + valores de config + versão do engine + `event_sequence`. `complete` é a única transição terminal (sem `abort`).
- **Convenções:** `snake_case`; funções de domínio são verbos; IDs de texto imutáveis (`draft_id`, `fantasy_team_id`, `event_id`); timestamps UTC ISO-8601; `event_sequence` é a ordem autoritativa, nunca a ordem de timestamp.
- **Storage:** banco, logs e exports ficam em diretório de dados do usuário fora do código-fonte; startup checa storage gravável e validação do bundle antes de habilitar a sessão.
- **Estrutura:** `R/domain_*.R` (liga, schedule, estado), `R/application_*.R` (use cases + ports), `R/adapter_sqlite_*.R` (event store, read model), `R/adapter_files_*.R` (YAML), `config/` (YAML + schemas), `inst/schema/` (schema SQLite).
- **Testes:** domínio de liga/schedule testado fora de Shiny/SQLite; use cases testados contra um banco SQLite temporário; fixtures de aceitação usam a base de 12 times.

## UX & Interaction Patterns

- **Superfície única de setup** (três superfícies do plano original fundidas em uma), agrupando times/rounds, slots/FLEX, scoring, time do operador e a grade de ordem snake. A validade aparece junto ao grupo afetado; o foco vai à primeira inconsistência.
- **`Validate and Lock` é a única ação de transição** e permanece desabilitado até todos os grupos estarem viáveis e a ordem completa. Estado travado é visível; alterações normais de ordem terminam após o início.
- **Grade snake compacta** suporta cadastrar / sortear / reordenar antes do início e é atualizada a cada mudança.
- Tema escuro único com os design tokens do Epic 1 (`DESIGN.md`); nenhum valor visual fora dos tokens. Bloqueio usa `danger` com texto/rótulo além da cor; `warning` para o aviso de compatibilidade de scoring. Microcopy curta, factual, em PT-BR, sem celebração nem alarmismo.
- Keyboard-first + ARIA básico apenas; sem auditoria de contraste WCAG como entregável, sem roving tabindex, sem `aria-activedescendant`, sem zoom 200% linear / `prefers-reduced-motion` / piso de alvo 24×24 px.

## Cross-Story Dependencies

- **Depende do Epic 1:** snapshot válido exposto como `reactive()` pela superfície 1.7; `snapshot_id` e `snapshot_content_hash`; `scoring_hash` do `metadata.json` (para o aviso de compatibilidade); design tokens (1.6); scaffold, composition root e harness de testes (1.1); adapter de arquivos e padrão de parser/erro de domínio (1.2/1.3).
- **Ordem interna:** 2.1 (parser + envelope) e 2.2 (schedule + times + ordem) alimentam 2.3; o `DRAFT_STARTED` de 2.3 congela os valores de configuração validados por 2.1 e a ordem travada por 2.2.
- **Habilita o Epic 3:** o gerador de calendário snake é reusado pelo domínio de roster e pelo runner de simulação (`simulate_draft.R`); a `effective_pick_projection` e o log de eventos são a base de `record_pick` / `undo_last_pick` / `correct_pick` / replay (Story 3.4).
- **Habilita o Epic 4:** a UI do board consome os slots do calendário; a seleção/restauração de sessão (`updated_at DESC`, `draft_id` como único input) opera sobre as tabelas criadas aqui.
