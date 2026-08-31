---
title: "Sprint Change Proposal — Simplificação dos Epics 2–6"
date: 2026-08-31
trigger: "Realinhar escopo de implementação: app local de uso único, não enterprise"
mode: batch
scope_classification: major
status: proposta para aprovação
inputs:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prds/prd-Fantasy Draft War Room-2026-08-28/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-Fantasy Draft War Room-2026-08-28/ARCHITECTURE-SPINE.md
  - _bmad-output/implementation-artifacts/epic-1-retro-2026-08-31.md
  - docs/draft_strategy.md
  - docs/initial_vision.md
---

# Sprint Change Proposal — Simplificação dos Epics 2–6

## Seção 1 — Resumo do problema

O planejamento atual (PRD + Architecture Spine + `epics.md`) foi dimensionado como
se o Fantasy Draft War Room fosse um sistema multiusuário, distribuído e auditável
por terceiros. Na prática é um **aplicativo R local, de operador único, um processo,
usado durante um único draft por temporada**, rodando no laptop do próprio autor ao
lado da ESPN.

Essa incompatibilidade se traduz em custo de implementação alto e token-intensivo
em áreas que não entregam valor para o caso de uso real:

- **Auditoria criptográfica de estado.** Event sourcing com `event_sequence`,
  `previous_state_hash`/`resulting_state_hash` SHA-256 por evento sobre um
  *canonical JSON v1* byte-level (AD-4, AD-12), replay que reverifica os dois
  hashes, e `expected_state_hash` em toda intenção mutante (AD-11). Isso resolve
  concorrência entre escritores e divergência entre implementações — problemas que
  não existem com um operador, uma tela, um processo.
- **Infraestrutura de banco.** Runner de migrations versionadas + tabela de
  histórico + cursor de projeção por draft (Story 2.3), para um schema que é
  fixado no release e nunca migra durante o uso.
- **Gate de performance formal.** Benchmark determinístico medindo p95 de
  PERF-001..005 com fixture, ferramenta de medição registrada e gate de CI
  (Story 3.15, NFR25, AC-V1-07) — para operações sobre ~400 jogadores em
  `data.frame` em memória, que o R resolve em milissegundos.
- **Recovery drill automatizado** restart-no-pick-80 com "0 perdas em 100% das
  execuções" (Story 4.10) — quando o `INSERT` síncrono no SQLite já garante
  durabilidade e um teste de reabertura basta.
- **Camada de acessibilidade e responsividade de produto web.** ARIA
  combobox/listbox com `aria-activedescendant`, roving tabindex, regiões
  `aria-live`, auditoria de contraste WCAG 2.2 AA como entregável, leitura linear
  a 200% de zoom, `prefers-reduced-motion`, alvos de 24×24 px, layout
  split-window com painéis alternáveis que preservam foco (Stories 3.6–3.14, 3.16;
  UX-DR1–25) — para um operador único no próprio laptop.
- **Exportações "prontas para auditor"** com proveniência canônica e hashes, mais
  `abort` administrativo (Stories 5.2–5.4) — para um draft que acontece uma vez.

### Como o problema apareceu

Revisão dos artefatos de planejamento após o fechamento do Epic 1
(`accepted-with-open-items`, 7 stories, ~5.800 linhas, 764 testes). O Epic 1 já
sinalizou o padrão: valor de engenharia concentrado em hashing canônico e
validação, com peso de teste alto em superfície Shiny. Os Epics 2–6 restantes
somam ~41 stories no mesmo registro.

### Diretriz do autor

> Não é um "enterprise app", é uma app local para ser usada uma vez. Implementação
> simples, menos token-intensiva, que respeite os objetivos do projeto.
> Despriorizar histórias acessórias e formalidade no rastreamento e auditoria.
> **Priorizar o algoritmo e a execução do processo de draft e a simulação (via
> script).**

### Decisões tomadas na abertura desta correção

1. **Event sourcing / hashing:** log de eventos simples. Mantém event log
   append-only para undo/correção/replay; corta hash de estado por evento,
   verificação dupla no replay, canonical JSON v1, `expected_state_hash` nas
   intenções, e os hashes canônicos de scoring/rules/policy.
2. **Acessibilidade:** keyboard-first + ARIA básico (roles/labels no combobox +
   uma região `aria-live`). Sem auditoria WCAG formal, sem `aria-activedescendant`,
   sem roving tabindex, sem reduced-motion.
3. **Layout:** dois estados (amplo/estreito) — painéis laterais em tela ampla,
   empilhados em estreita. Sem zoom 200% linear, sem ceremony de motion.
4. **Modo de revisão:** batch.

---

## Seção 2 — Análise de impacto

### Impacto por epic

| Epic | Hoje | Proposto | Delta |
|---|---|---|---|
| Epic 1 — Snapshot | 7 stories, **concluído** | inalterado | — |
| Epic 2 — Configurar e travar | 6 stories | **3 stories** | funde 3 superfícies em 1; corta migrations framework e hashing de config |
| Epic 3 — Live War Room (domínio + UI) | 16 stories | **dividido** — ver abaixo | separa domínio puro de UI |
| Epic 4 — Corrigir/desfazer/recuperar | 10 stories | **fundido** em Epics 3 e 4-novo | replay sem hash; sem pause/resume; sem drill |
| Epic 5 — Encerrar e exportar | 5 stories | **1 story** | sem abort; export = CSV/JSON |
| Epic 6 — Simulação (script) | 4 stories | **preservado, puxado para o Epic 3-novo** | prioridade máxima; iteração antes da UI |

**Reestruturação:** de 5 epics restantes / ~41 stories para **4 epics / 14
stories**.

- **Epic 2-novo — Liga, calendário e sessão mínima** (3 stories)
- **Epic 3-novo — Domínio de draft, recomendação e simulação** (6 stories) — núcleo
- **Epic 4-novo — Live War Room** (4 stories)
- **Epic 5-novo — Fechar e exportar** (1 story)

### Impacto em stories concluídas

Nenhuma story do Epic 1 é revertida. A superfície 1.7 já expõe o snapshot válido
como `reactive()`; o gate de scoring pós-`start` (previsto para Story 2.6) muda de
**bloqueante** para **aviso não-bloqueante** — simplificação, sem retrabalho no
Epic 1. Os itens abertos da retro do Epic 1 (predicado de metadado duplicado,
`aria-busy` assíncrono, reconciliação do texto congelado do spec 1.7) permanecem
como estão; o `aria-busy` assíncrono (item 4) fica **cancelado** sob a decisão de
acessibilidade acima.

### Conflitos de artefato

- **Architecture Spine:** AD-4, AD-5, AD-6, AD-8, AD-9, AD-11 recebem emendas de
  regra; **AD-12 é removido**. Seções "Consistency Conventions" e
  "Capability → Architecture Map" ajustadas.
- **PRD:** §5 (DRAFT-008, DRAFT-011, REP-002, REP-003), §6 (NFR25), §7 (AC-V1-05,
  AC-V1-07), §8 (SM-01, SM-02, SM-06) reescritos ou realocados.
- **UX Design (`DESIGN.md` / `EXPERIENCE.md`):** UX-DR1–2, 4–20, 23–25 mantidos
  como intenção, com implementação reduzida; UX-DR3 (auditoria de contraste) deixa
  de ser entregável; UX-DR21 (zoom/motion) e a parte screen-reader de UX-DR5, 7, 9,
  12–14, 19 são cortadas; UX-DR22 (alvos 24px) cortada.

### Impacto técnico

- **Menos código de infraestrutura:** sem runner de migrations, sem serializador
  canônico de estado, sem cadeia de hash por evento, sem harness de benchmark.
- **Domínio puro inalterado em força:** `domain_roster`, melhor lineup, ganho
  marginal e `recommend_fast()` mantêm todo o escopo funcional. A fronteira
  hexagonal (AD-1) e a separação pré-draft/live (AD-2) permanecem — são baratas e
  já validadas.
- **Simulação vira caminho crítico de desenvolvimento**, não item final: o
  `simulate_draft.R` roda assim que o domínio puro existe, permitindo calibrar o
  algoritmo antes de qualquer tela.

---

## Seção 3 — Abordagem recomendada

**Caminho: ajuste direto do plano (replan de escopo), sem rollback.**

O Epic 1 fica como está. Os Epics 2–6 são substituídos pela estrutura de 4 epics /
14 stories abaixo. A ordem de execução prioriza o algoritmo:

1. **Epic 2-novo** (config + calendário + event store mínimo) — pré-requisito de
   dados para a simulação.
2. **Epic 3-novo** na ordem `3.1 → 3.2 → 3.3 → 3.5 → 3.6 → 3.4`: domínio puro e
   simulação **primeiro**, use cases de comando depois. Isso permite iterar o
   algoritmo via `simulate_draft.R` antes de construir a UI.
3. **Epic 4-novo** (Live War Room) — só depois de o algoritmo estar validado.
4. **Epic 5-novo** (fechar + exportar) — trivial.

**Estimativa de esforço:** redução de ~65% no número de stories restantes e
redução desproporcional em linhas de infraestrutura/teste (o Epic 1 gastou boa
parte das ~5.800 linhas em hashing canônico e testes de superfície Shiny — os dois
maiores alvos do corte).

**Risco:** baixo. Nenhum objetivo de produto do §3 do PRD ("Incluído") é perdido,
exceto `abort` administrativo (caso excepcional) e o rigor formal de
auditoria/benchmark. Ver checklist na Seção 4.

**Decisão em aberto (requer confirmação):** incorporar um fator de **urgência /
valor sobre o próximo disponível** ao `recommend_fast()` no V1, reusando o cálculo
determinístico de Pure VONA (distância até o próximo pick no calendário snake +
ADP, sem modelo de mercado probabilístico). Hoje o PRD adia isso (REC-008) para o
V2. Recomendação: **incluir** — `EXPL-004` já exige que a UI distinga "urgência"
como fator, `draft_strategy.md` trata "distância até seu próximo pick" como coluna
fundamental, e o cálculo puro não fere AD-9. Não é o modelo de mercado do V2, é
uma heurística determinística.

---

## Seção 4 — Propostas de mudança detalhadas

### 4.1 — Epics e stories (`_bmad-output/planning-artifacts/epics.md`)

#### Epic 2-novo — Liga, calendário e sessão mínima

> O operador configura a liga dentro do envelope V1, cadastra times, define/sorteia
> a ordem da primeira rodada, revisa o calendário snake completo e trava tudo,
> criando uma sessão pronta. Estabelece o domínio puro de liga/schedule e o event
> store SQLite mínimo.
> **FRs:** FR6–FR18, FR51, FR52

**Story 2.1 — Configuração da liga e envelope V1**
Absorve as antigas 2.1 (parcial) e 2.6 (gate de scoring).
- Parser YAML lê regras de liga, tiers e política de recomendação em objetos de
  configuração; a config de referência (12 times, Full PPR, 1 QB / 2 RB / 2 WR /
  1 TE / 1 FLEX RB-WR / 1 K / 1 D-ST + 6 reservas) é o default fornecido.
- Validação de envelope: 8–14 times, exatamente 15 rounds, 9 titulares + 6 reservas
  preenchendo os 15 rounds, FLEX só RB/WR. Fora disso → bloqueio com motivo
  acionável apontando o grupo.
- O runtime **não** re-pontua jogadores; usa o YAML de scoring só para exibir a
  identidade do scoring.
- Se o `scoring_hash` do snapshot (já calculado no Epic 1) diverge do scoring da
  config ativa → **aviso não-bloqueante** no `start`.
- **Removido:** guard "rejeita lógica arbitrária"; serialização canônica e
  `league_rules_hash` / `scoring_config_hash` / `recommendation_policy_hash`.

**Story 2.2 — Calendário snake, times e ordem (superfície única de setup)**
Absorve as antigas 2.2, 2.4, 2.5.
- Gerador puro do calendário: todos os slots com overall pick contínuo, round,
  pick da rodada, time e indicador do time do usuário; rounds pares invertem a
  ordem dos ímpares; um slot por time por round; determinístico.
- Cadastro de times com identificador imutável; exatamente um time do operador.
- Sortear a ordem com seed registrada (reproduzível) ou reordenar manualmente
  antes do início.
- **Uma** superfície de setup agrupando times/rounds, slots/FLEX, scoring, time do
  operador e a grade de ordem; validade aparece junto ao grupo afetado;
  `Validate and Lock` habilita só com tudo viável.

**Story 2.3 — Event store SQLite mínimo e `start`**
Absorve a antiga 2.3 e a parte de `DRAFT_STARTED` da 2.6.
- No boot: `CREATE TABLE IF NOT EXISTS` para sessões, eventos e
  `effective_pick_projection`; `PRAGMA journal_mode=WAL` e `foreign_keys=ON`.
- Log de eventos append-only; `event_sequence` monotônico por draft.
- `effective_pick_projection` com unicidade `(draft_id, overall_pick)` e
  `(draft_id, player_id)`; evento + projeção + estado derivado gravados na mesma
  transação; falha não commita nada.
- `start` grava `DRAFT_STARTED` congelando `snapshot_id`, `snapshot_content_hash`
  (do Epic 1), os **valores** de scoring/regras/política, a versão do engine e a
  seed opcional. Após o `start`, trocar snapshot ou reordenar pelo fluxo normal
  fica indisponível.
- **Removido:** runner de migrations versionadas, tabela de histórico de
  migrations, cursor de projeção como conceito separado.

#### Epic 3-novo — Domínio de draft, recomendação e simulação `[NÚCLEO]`

> Fora de Shiny e SQLite, o domínio puro constrói rosters e o melhor lineup,
> calcula ganho marginal, produz recomendações rápidas e explicáveis, e roda uma
> simulação de draft snake completa comparando estratégias. Habilita a calibração
> do algoritmo antes da UI.
> **FRs:** FR19–FR25, FR29–FR50, FR53, FR54, FR58–FR62
> **Ordem de execução:** 3.1 → 3.2 → 3.3 → 3.5 → 3.6 → 3.4

**Story 3.1 — Roster, melhor lineup e ganho marginal (puro)**
Absorve as antigas 3.3, 3.4. Escopo funcional **inalterado**.
- Constrói o roster de todos os times a partir das picks efetivas.
- Melhor lineup maximiza pontos projetados dos titulares respeitando elegibilidade,
  FLEX como slot de elegibilidade múltipla (RB/WR).
- Classifica cada slot: titular vazio, upgrade, FLEX, banco, redundância.
- Ganho marginal = melhor lineup com o candidato − melhor lineup sem.
- Sinaliza alerta/restrição quando uma escolha tornaria impossível completar slots
  obrigatórios nos rounds restantes.
- Determinístico.

**Story 3.2 — Motor `recommend_fast()` (puro)**
Absorve a antiga 3.5. Escopo funcional **inalterado**, mais a decisão em aberto.
- Função pura sobre estado congelado + métricas do snapshot em memória + config +
  política; retorna candidatos ordenados com score, componentes, ≥3 fatores
  estruturados, reason codes, texto determinístico, avisos e versão do engine.
- VOR / tier / ADP-como-preço; alerta de tier cliff; política que desprioriza
  K/DST cedo e é consultável; roster-aware (usa 3.1); recalcula a cada mudança de
  estado; ≥5 candidatos disponíveis; distingue projeção / valor / preço / urgência;
  nenhuma recomendação é número opaco.
- Sem scraping, scan SQL ou simulação no caminho crítico.
- **[Aberto]** fator de urgência = cálculo determinístico de valor sobre o próximo
  disponível (distância até o próximo pick + ADP), reusado da estratégia Pure VONA.
- **Removido:** `state hash` no retorno como contrato (mantém identificação por
  `snapshot_id` + valores de config).

**Story 3.3 — Busca incremental de jogadores (puro)**
Absorve a antiga 3.1.
- Match incremental em `normalized_name`, tolerante a acento, apóstrofo, hífen e
  variação simples; retorna nome de exibição, posição e time NFL.
- Oculta jogadores já escolhidos em qualquer time.
- Busca sem correspondência → vazio, estado intacto.
- **Removido:** afirmação de p95 ≤ 100 ms como AC (ver Story 3.4 para o smoke
  check).

**Story 3.5 — Estratégias de seleção (puras)**
Absorve a antiga 6.1.
- Assinatura única: `(disponíveis, roster_do_time, contexto_do_pick) → player_id`,
  determinística por entrada + seed.
- Conjunto V1: ADP, Total Points (projeção), Random (com seed), Pure VOR,
  Pure VONA, estratégia-app (reusa `recommend_fast()` → candidato nº 1).
- Pure VONA usa distância até o próximo pick do time no calendário + ADP, sem
  modelo de mercado externo.
- Sem Shiny, SQLite ou rede.

**Story 3.6 — Runner de simulação, avaliação e relatório**
Absorve as antigas 6.2, 6.3, 6.4. Escopo **inalterado**.
- `Rscript scripts/simulate_draft.R` com seed: sorteia a ordem dos times
  (seed registrada), atribui estratégia por time (a do operador em teste, as
  demais configuráveis), roda as 15 rodadas reusando o gerador de calendário e o
  domínio de roster, registra cada pick (round, overall, time, estratégia,
  jogador).
- Avaliação: pontos projetados por time — só titulares (melhor lineup), só banco,
  combinado — ranking dos times, posição do operador destacada.
- Relatório determinístico em console + CSV, reproduzível pela seed; opção de N
  execuções com seeds variadas, agregando por estratégia (média e distribuição da
  pontuação combinada e do rank do operador).
- Não abre o banco de sessões, não anexa eventos, sem rede.

**Story 3.4 — Use cases `record_pick`, `undo_last_pick`, `correct_pick` e replay**
Absorve as antigas 3.2, 4.1 (replay sem hash), 4.2, 4.3, 5.1 (transição
`complete`).
- Cada use case entra por um único ponto de aplicação, valida contra o estado
  reconstruído, anexa exatamente um evento ordenado e substitui a projeção na
  mesma transação.
- `record_pick`: valida disponibilidade + `expected_overall_pick` (checagem
  barata contra tela obsoleta — **sem `expected_state_hash`**); associa ao time do
  slot; avança o pick; rejeita jogador já efetivo sem anexar evento; ao preencher
  o último slot, transiciona para `COMPLETED` na mesma transação.
- `undo_last_pick`: evento `UNDO`; o replay passa a remover o pick efetivo mais
  recente; repetível; auditoria mantém todos os eventos de undo.
- `correct_pick`: evento `CORRECTION` nomeando `overall_pick` alvo e `player_id`
  substituto; o replay aplica na sequência preservando os picks posteriores;
  rejeita (sem anexar evento) se resultaria em jogador duplicado, violação de slot
  ou invalidação de pick posterior.
- Replay reconstrói o estado aplicando eventos por `event_sequence`. **Sem**
  verificação de `previous_state_hash` / `resulting_state_hash`.
- **Smoke check de recuperação:** um teste reabre o banco após um pick commitado e
  confere que o pick está presente e o estado é consistente. **Sem** drill de
  restart parametrizado nem métrica de "100% das execuções".
- **Smoke check de latência:** um teste roda um draft completo simulado (168
  picks) e afirma que conclui em < N s (N folgado, ex. 10 s). **Sem** fixture de
  medição, p95 ou gate de CI.

#### Epic 4-novo — Live War Room

> Na tela live o operador vê o estado global, busca por teclado, registra o pick
> com feedback imediato e vê board, roster, disponíveis e recomendações
> recomporem; desfaz, corrige no board e restaura sessões locais.
> Tema escuro único (tokens do Epic 1). Keyboard-first + ARIA básico. Dois estados
> de layout.
> **FRs:** cobertura de UI de FR16, FR19–FR35, FR40, FR42–FR50, FR58, FR23–FR26,
> FR53

**Story 4.1 — Casca da Live War Room (estado + board + roster)**
Absorve as antigas 3.6, 3.10 (visual), 3.11, parte da 3.16.
- Faixa de estado fixa: overall pick em `typography.display`, rodada e pick da
  rodada, time no relógio, último jogador registrado, próximo pick do operador;
  pick vivo em `action`; pausado/alerta/concluído com texto + ícone além de cor;
  atualiza como uma unidade; nunca sai da vista.
- Board round × time com a linha/coluna do pick atual marcada; pick recém-
  registrado com realce transitório em `action` sem animação prolongada; picks do
  operador distinguíveis por rótulo.
- Painel de roster do operador: grupos estáveis de titulares, FLEX e banco;
  melhor lineup e slots vazios visíveis; impacto marginal do candidato em foco.
- **Dois estados de layout:** board e roster como painéis laterais em tela ampla,
  empilhados em tela estreita, preservando estado. Faixa de estado, busca e lista
  sempre visíveis. Board rola horizontal se necessário.
- **Removido:** roving tabindex e anúncio por célula; `prefers-reduced-motion`;
  leitura linear a 200%.

**Story 4.2 — Busca, lista inteligente, inspeção e teclado**
Absorve as antigas 3.7, 3.8, 3.9, 3.13.
- Campo de busca de largura dominante, resultados imediatamente abaixo com nome,
  posição e time NFL; o resultado que `Enter` registra usa `candidate-active` +
  contorno de foco.
- **ARIA básico:** o autocomplete é um combobox com `role`, label persistente e
  `aria-expanded`; **uma** região `aria-live=polite` anuncia comando aceito em
  frase curta. Sem `aria-controls` / `aria-activedescendant`.
- Lista inteligente: ≥5 candidatos disponíveis ordenados pela recomendação, cada
  linha distinguindo score, fatores, alerta de tier cliff e impacto no roster;
  nº 1 destacado por ordem + peso tipográfico, nunca card grande; filtro de
  posição por badges sem alterar o estado.
- Fora de entrada editável: setas movem o destaque, `Espaço` abre/fecha inspeção,
  `Enter` tenta registrar no pick atual, `U` aplica um undo por tecla, `/` foca a
  busca. Dentro de entrada editável, os atalhos globais não disparam. Clique é
  alternativa suportada.
- Painel de inspeção em `surface-raised` sem cobrir a faixa ou a busca: explicação
  determinística (projeção, valor, preço de mercado, urgência quando aplicáveis),
  tier, impacto marginal; campo opcional ausente → `Não disponível neste
  snapshot`; `Esc` fecha e devolve o foco à lista.
- **Removido:** `?` como referência de atalhos; ordem de `Tab` especificada
  célula a célula; contorno de foco de 2px como AC formal (fica no token).

**Story 4.3 — Feedback, erros e blacklist**
Absorve as antigas 3.12, 3.14.
- Confirmação de pick breve, textual, próxima à faixa de estado, substitui a lista
  em menos de um ciclo de atenção e devolve o fluxo à busca.
- Jogador já escolhido / nome ambíguo / inválido → nada é persistido, a mensagem
  identifica o motivo (e o pick efetivo quando existir), o foco volta à
  busca/lista.
- Erro ou bloqueio persiste até o operador poder agir e não rouba o foco; toasts
  não encobrem busca, pick atual nem foco; sem modal de confirmação rotineiro.
- Microcopy curta, factual, orientada à próxima ação, em PT-BR; sem celebração
  nem alarmismo.
- Blacklist: editor compacto (add/remove por busca, efeito imediato); jogador na
  blacklist sai da smart list e das recomendações mas continua buscável e
  draftável com marcação explícita (texto + ícone); sobrevive a refresh; não entra
  no estado do draft nem gera evento.

**Story 4.4 — Undo visível, histórico, correção no board e seleção de sessão**
Absorve as antigas 3.10 (modo correção), 4.6, 4.7, 4.8, 4.9.
- Controle Undo sempre visível, acionável por `U`, borda/texto em `warning`,
  mostra o próximo pick a desfazer (overall, jogador, time) e o contador de
  reversões disponíveis; não parece ação destrutiva.
- Histórico de eventos: lista compacta em `ink-muted` de registros, undos e
  correções em ordem, cada um com alvo e resultado; auditável; não compete com o
  board.
- Correção pelo board: uma célula corrigível abre **um** painel contextual (nunca
  pilha de modais), recebe o foco, e o devolve à mesma célula ao cancelar, falhar
  ou concluir; picks posteriores nunca somem.
- Seleção de sessão: lista por `updated_at DESC`, mais recente pré-selecionada,
  skeleton no carregamento, cada linha com data e status; restauração só após
  `Enter` / Confirmar, usando o `draft_id` selecionado como único input; nada
  restaurado silenciosamente; sem sessão recuperável → texto explicando e foco
  para Preparar draft.
- Intenção obsoleta: uma ação cujo `expected_overall_pick` não bate é recusada com
  erro estruturado e instrução de recarga, sem alterar o estado.
- **Removido:** `pause` / `resume` como par de eventos (a sessão é sempre
  retomável do banco; um flag `status` cobre "não registrar por engano");
  `expected_state_hash`.

#### Epic 5-novo — Fechar e exportar

> Ao preencher o último slot a sessão encerra; o operador exporta picks, rosters,
> configuração e metadados.
> **FRs:** FR27, FR55, FR56, FR57

**Story 5.1 — Completar e exportar**
Absorve as antigas 5.1, 5.3, 5.4, 5.5.
- `record_pick` no último slot → `COMPLETED` (já na Story 3.4); registro normal
  fica indisponível, o estado "draft completo" é explícito por texto + ícone, o
  foco vai para Exportar.
- Exportar em CSV/JSON no diretório de dados do usuário, fora do código-fonte:
  - **picks:** overall pick, round, time, jogador;
  - **rosters:** roster de cada time + melhor lineup do operador;
  - **config + metadados:** regras de liga, scoring e política em texto legível +
    metadados do snapshot (temporada, geração, fontes, método) + `snapshot_id` +
    `snapshot_content_hash` + versão do engine + timestamp.
- Exportações são artefatos derivados, não estado autoritativo.
- **Removido:** Story 5.2 (`abort` administrativo) — `complete` é a única
  transição terminal; se o operador erra, usa undo ou recomeça. Framing de
  "suficiente para um auditor" e proveniência canônica com hashes.

### 4.2 — Architecture Spine (`ARCHITECTURE-SPINE.md`)

| Invariante | Mudança |
|---|---|
| **AD-4** | Mantém "um use case por comando; um evento ordenado; projeção na mesma transação; falha não commita". **Remove** do payload obrigatório `expected_state_hash`, `previous_state_hash`, `resulting_state_hash`. Mantém `expected_overall_pick` nos picks. |
| **AD-5** | Inalterado em intenção (undo/correção por replay, história preservada, picks posteriores intactos, rejeição de estado inválido). **Remove** a verificação de hash no replay. |
| **AD-6** | Proveniência congelada = `snapshot_id` + `snapshot_content_hash` + **valores** de scoring/regras/política + versão do engine + seed. **Remove** `scoring_config_hash` / `league_rules_hash` / `recommendation_policy_hash` canônicos. Gate de scoring no `start` vira **aviso não-bloqueante**. |
| **AD-7** | Mantém "configuração é dado validado". **Remove** "só valores escalares/listas/mapas declarados são aceitos" como guard formal e a serialização canônica hasheada. |
| **AD-8** | Mantém SQLite como registro único, append-only, `event_sequence` monotônico, unicidade na projeção, WAL + FK. **Remove** runner de migrations versionadas + histórico (vira `CREATE TABLE IF NOT EXISTS` no boot). |
| **AD-9** | **Inalterado** na regra funcional (`recommend_fast()` puro, rápido, explicável, sem scraping/SQL/simulação no caminho crítico). **Remove** o gate de benchmark p95 como cláusula; a rapidez é verificada por um smoke check. |
| **AD-11** | Mantém "restauração de sessão é explícita, `draft_id` é o único input". Reduz "toda intenção carrega `expected_state_hash`" para "picks carregam `expected_overall_pick`". |
| **AD-12** | **Removido inteiro.** Não há contrato de hash de estado byte-level. O replay usa a serialização interna que for conveniente. |
| Consistency Conventions | Remove as linhas de canonicalização de estado e a menção a `expected_state_hash`. Mantém nomes, IDs, ordenação por `event_sequence`, erros de domínio com `code` + PT-BR. |
| Deferred | "V3 simulation engine" deixa de listar "backtesting" como diferido — a simulação por script entra no V1 (Epic 3-novo). Monte Carlo e jobs assíncronos continuam diferidos. |

### 4.3 — PRD (`prd.md`)

| Seção | Mudança |
|---|---|
| §3 "Não incluído no V1" | Acrescentar: `abort` administrativo de draft incompleto. |
| §5 DRAFT-008 | "Pausar/retomar" → downgrade: a sessão é sempre retomável do banco local; sem par de eventos `PAUSE`/`RESUME` dedicado; um flag de status impede registro acidental. |
| §5 DRAFT-011 | "Finalizar/abortar" → só "Finalizar quando completo". Abortar administrativo sai para "Não incluído". |
| §5 REP-002 | "Cada recomendação é associável ao snapshot, configuração e estado" → por `snapshot_id` + valores de config + `event_sequence`, não por hashes canônicos. |
| §5 REP-003 | Mantém "recupera sessão local e exporta dados suficientes para consulta"; remove a expectativa de reprodutibilidade por hash de estado. |
| §5 PERSIST-001–004 | Mantém "pick durável ou não ocorre; undo/correção deixam trilha; sessão reconstruível". Remove a exigência de auditoria criptográfica. |
| §6 NFR25 (BENCHMARK) | Substituir o gate de fixture + ferramenta de medição + p95 por: "um smoke check verifica que um draft completo simulado (168 picks) conclui em tempo folgado num laptop de referência". |
| §6 MAINT-001–005 | Inalterado — a fronteira hexagonal e a reprodutibilidade por `renv.lock` continuam. |
| §7 AC-V1-05 | Remover "inclusive em um drill de recuperação automatizado"; manter "restaura a opção confirmada sem perda ou duplicação". |
| §7 AC-V1-07 | Reescrever: "o smoke check confirma que o fluxo live não acessa a rede e que o draft completo simulado roda em tempo folgado". Remover p95 de PERF-001..005 como critério de release. |
| §8 SM-01 | "0 perdas/duplicidades em 100% dos drills de 168 picks" → "0 perdas/duplicidades no smoke check de recuperação e nos testes de integração". |
| §8 SM-02 | "100% de restauração nos drills" → "restauração consistente verificada por teste de reabertura do banco". |
| §8 SM-06 | "cumprir PERF-001..005 em benchmark a cada release" → "o smoke check de latência passa". |
| §2, §3 (Simulação) | A frase "Simulações... backtesting... não são promessa de V1" passa a excluir explicitamente a **simulação determinística por script** (que entra no V1); Monte Carlo e simulação de adversários probabilística continuam fora. |

### 4.4 — UX Design (`DESIGN.md` / `EXPERIENCE.md`)

| UX-DR | Mudança |
|---|---|
| UX-DR1, UX-DR2 | Mantidos — os tokens do Epic 1 já são a fonte visual. |
| UX-DR3 | **Cortado como entregável** — auditoria de contraste WCAG não é uma story; os pares de token do Epic 1 são aceitos como estão. |
| UX-DR4, 6, 8, 10, 11, 15–18, 23, 24, 25 | Mantidos com implementação reduzida (sem parte screen-reader). |
| UX-DR5, 7, 9, 12, 13, 14, 19, 20 | Manter o comportamento visual e de teclado; **cortar** `aria-controls`, `aria-activedescendant`, roving tabindex, ordem de `Tab` especificada, `?` como referência de atalhos. Manter `role`/label no combobox e **uma** região `aria-live`. |
| UX-DR21 | **Cortado** — sem zoom 200% linear, sem `prefers-reduced-motion`. Fica "dois estados de layout (amplo/estreito) preservando estado". |
| UX-DR22 | **Cortado** — sem piso de alvo de 24×24 px como AC. |
| UX-DR24 | Manter a enumeração de estados de UI, **menos** os que dependem de recursos cortados (`aria-disabled` com motivo acessível vira `disabled` simples; "correção inválida" e "intenção obsoleta" permanecem). |

---

## Seção 5 — Checklist: objetivos do projeto preservados

| Objetivo (§3 PRD "Incluído") | Status na proposta |
|---|---|
| `script.R` pré-draft + validação de qualidade + avisos | ✅ Epic 1 (concluído) |
| Draft snake 8–14 times, 15 rounds, slots/FLEX/scoring por YAML validado | ✅ Epic 2-novo (2.1, 2.2) |
| Cadastrar times, identificar o do usuário, ordem, travar antes do início | ✅ Epic 2-novo (2.2, 2.3) |
| Iniciar / pausar / retomar / encerrar; registrar / desfazer / corrigir | ✅ parcial — `complete` + `record_pick` + `undo` + `correct` (3.4); pausa reduzida a flag de status |
| Board, disponíveis e rosters consistentes | ✅ Epic 3-novo (3.1, 3.4) + Epic 4-novo (4.1) |
| Busca rápida por teclado, nomes normalizados, posição/time visíveis | ✅ Epic 3-novo (3.3) + Epic 4-novo (4.2) |
| Melhor lineup inicial + ganho marginal | ✅ Epic 3-novo (3.1) — força integral |
| ≥5 recomendações com score, fatores, tier cliff, política K/DST | ✅ Epic 3-novo (3.2) — força integral |
| Restaurar sessão local após reinício/refresh | ✅ Epic 4-novo (4.4) |
| Exportar picks, rosters, configuração e metadados | ✅ Epic 5-novo (5.1) |
| Operar sem rede depois de selecionar o snapshot | ✅ AD-2 inalterado + smoke check |
| **Simulação / backtesting via script** | ✅ Epic 3-novo (3.5, 3.6) — **priorizado** |

**Conscientemente removido/reduzido:**

| Item | Antes | Depois | Justificativa |
|---|---|---|---|
| Auditoria criptográfica de estado | hash SHA-256 por evento + replay verificado + canonical JSON | log de eventos simples + replay | operador único, um processo |
| `abort` administrativo | Story 5.2 | cortado | draft de uso único; undo ou recomeço cobre |
| `pause` / `resume` | Story 4.4, par de eventos | flag de status | fechar o laptop = pausar |
| Gate de benchmark p95 | Story 3.15 + NFR25 + AC-V1-07 | 1 smoke check | ~400 jogadores em memória, custo trivial |
| Recovery drill automatizado | Story 4.10 | 1 teste de reabertura | SQLite síncrono já garante durabilidade |
| Migrations framework | Story 2.3 | `CREATE TABLE IF NOT EXISTS` | schema fixado no release |
| Acessibilidade screen-reader | UX-DR5–25 completo | keyboard-first + ARIA básico | operador único no próprio laptop |
| Responsivo zoom/motion | UX-DR21, Story 3.16 | dois estados de layout | janela estreita ao lado da ESPN |
| Exportação "para auditor" | Stories 5.3, 5.4 | CSV/JSON com `snapshot_id` + valores | consulta pessoal pós-draft |

---

## Seção 6 — Handoff de implementação

**Classificação de escopo:** **Major** — replan de estrutura de epics e emenda de
invariantes de arquitetura.

**Rota:**

1. **Autor (Giu) / PM:** aprovar esta proposta. Decidir o item em aberto da
   Seção 3 (fator de urgência / VONA-lite no `recommend_fast()` do V1).
2. **Architect:** aplicar as emendas da Seção 4.2 ao `ARCHITECTURE-SPINE.md`
   (bump de `updated`, remover AD-12, editar AD-4/5/6/7/8/9/11 e as tabelas).
3. **PM:** aplicar as edições da Seção 4.3 ao `prd.md` e da Seção 4.4 aos
   artefatos de UX.
4. **PO / dev:** reescrever `epics.md` — Epics 1 inalterado; substituir Epics 2–6
   pela estrutura de 4 epics / 14 stories da Seção 4.1; regenerar o FR Coverage
   Map e o sprint status.
5. **Dev:** executar na ordem Epic 2-novo → Epic 3-novo (`3.1 → 3.2 → 3.3 → 3.5 →
   3.6 → 3.4`) → Epic 4-novo → Epic 5-novo, com iteração do algoritmo via
   `simulate_draft.R` assim que 3.1/3.2/3.5 existirem.

**Critérios de sucesso do replan:**

- `epics.md` tem 4 epics / 14 stories restantes, FR Coverage Map cobrindo
  FR1–FR62.
- Nenhum objetivo do checklist da Seção 5 fica sem story (exceto os removidos
  conscientemente).
- O Spine não contém mais AD-12 nem referências a `expected_state_hash` /
  `draft_state_hash`.
- O primeiro artefato executável de valor é `simulate_draft.R` rodando um draft
  completo comparando a estratégia-app contra as baselines — antes de qualquer
  tela da Live War Room.
