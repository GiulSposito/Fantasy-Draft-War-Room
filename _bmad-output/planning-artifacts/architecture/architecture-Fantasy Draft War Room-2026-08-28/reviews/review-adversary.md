# Revisão adversarial — seams da espinha

**Veredito: REVISAR antes de aceitar a espinha.** A separação de responsabilidades é boa, mas ainda faltam contratos que fazem duas unidades corretas em isolamento convergirem no mesmo estado, hash e artefato. Os itens abaixo são falhas de compatibilidade, não escolhas de implementação.

## 1. Crítico — a identidade do bundle não é calculável de forma única

**Seam:** pipeline pré-draft ↔ validador/runtime (AD-3, linhas 51–55).

`metadata.json` deve conter o `content_hash`, mas também integra o bundle cuja identidade ele declara; a regra não diz se o hash cobre `metadata.json`, se o campo é removido antes de hashear, nem a ordem/encoding/newlines dos CSV/JSON e o papel de `qa-report.json`.

Duas unidades compatíveis com o texto podem produzir hashes distintos para os mesmos dados: o pipeline A hasheia `players.csv + metrics.csv`; o B hasheia os quatro arquivos, normalizando `metadata.json` sem o próprio hash. Ambas emitem SHA-256 e um bundle com os quatro arquivos; o runtime de uma rejeita o bundle da outra.

**Correção exigida:** declarar um `snapshot_id` e um `snapshot_content_hash` canônicos, incluindo algoritmo de manifesto: lista ordenada de caminhos, hash de cada payload, encoding e normalização; excluir o campo derivado do próprio manifesto. Dizer precisamente quais arquivos e campos são imutáveis, e persistir tanto `snapshot_id` quanto o hash na sessão. Alinhar estes nomes ao contrato de dados.

## 2. Crítico — redução de eventos, correção/undo e fim normal não têm semântica total

**Seam:** domínio reducer ↔ use case/event store (AD-4/AD-5, linhas 57–67).

O spine fixa que cada comando anexa exatamente um evento, mas não fornece o schema mínimo de payload nem uma tabela de transições. Em particular, após `PICK_RECORDED(1,A)`, `PICK_RECORDED(2,B)`, `PICK_CORRECTED(1,C)`, “undo do último pick efetivo” pode significar remover B (maior `overall_pick`) ou desfazer a última mutação efetiva, restaurando A. Ambos os reducers preservam eventos e picks posteriores, mas produzem board/roster distintos. Também não está definido se o último `record_pick` muda o estado a `COMPLETED` por projeção, exige um `complete` posterior, ou anexa `PICK_RECORDED` e `DRAFT_COMPLETED` — a última alternativa contradiz “exatamente um evento”.

**Correção exigida:** adicionar contratos versionados para cada evento (`event_type`, campos obrigatórios, payload, pré-condições e erro), uma máquina de estados permitida e pseudocódigo/fixture de replay. Definir o alvo de undo e de uma correção sobre um slot previamente corrigido ou desfeito, e definir a transição de conclusão automática/administrativa sem ambiguidade.

## 3. Alto — “um jogador efetivo” não identifica a projeção que é dona da constraint

**Seam:** adaptador SQLite ↔ materializador/exportador (AD-4/AD-8, linhas 61 e 81–85).

Há eventos imutáveis e há “uma pessoa efetiva por draft”, mas a espinha não identifica a tabela/projeção que guarda os picks efetivos nem suas chaves. Um adaptador pode aplicar `UNIQUE(draft_id, player_id)` no log de eventos; outro aplica a mesma constraint em uma tabela de picks atuais. O primeiro bloqueia uma correção ou um undo que referenciem jogador já presente no histórico; o segundo os aceita e ambos afirmam obedecer à unicidade *efetiva*. Além disso, “replaces the materialized read model” não diz se `current_overall_pick`, status, picks, rosters e disponíveis são uma projeção transacional única ou recomputados separadamente.

**Correção exigida:** tornar o event log append-only e sem unicidade de jogador/slot; especificar uma `effective_pick_projection` (ao menos `draft_id`, `overall_pick`, `fantasy_team_id`, `player_id`, `state_hash`, `projection_sequence`) com `UNIQUE(draft_id, overall_pick)` e `UNIQUE(draft_id, player_id)`. Declarar as demais projeções derivadas, seu dono e que evento, projeção e cursor/hash são substituídos na mesma transação.

## 4. Alto — `state_hash` é prometido entre camadas, mas não possui contrato canônico

**Seam:** reducer ↔ recomendação/UI/cache/export (AD-6/AD-9 e convenções, linhas 69–73, 87–91, 101–109).

O hash aparece como prova de proveniência e chave de resultados, mas não há definição de bytes: quais campos do estado entram, ordenação de picks/listas, tratamento de `NA`, números, status/proveniência, ou exclusão de timestamps/latência. Um reducer pode hashear eventos inteiros e outro apenas picks efetivos; ambos são determinísticos e SHA-256, porém uma recomendação persistida não bate com o estado que a UI/exportador calcula. A restauração pode então rejeitar uma recomendação válida ou aceitar uma stale.

**Correção exigida:** definir `draft_state_hash = SHA-256(canonical_json(v1_state_subset))`, enumerar o subset e a serialização canônica, e exigir `previous_state_hash`/`resulting_state_hash` em todo evento. Para comandos vindos da UI, acrescentar `expected_state_hash` e `expected_overall_pick`, rejeitando intenção stale antes do append.

## 5. Médio — configuração e compatibilidade scoring–snapshot podem divergir apesar de hashes válidos

**Seam:** parser YAML/configuração ↔ pipeline/validador (AD-3/AD-6/AD-7, linhas 53–55, 71–79).

O PRD exige que o `scoring_hash` do snapshot coincida com o scoring ativo. A espinha, porém, persiste um único “league/scoring config hash”, separa um hash de política, e diz apenas que objetos YAML são canônicos. Um implementador pode incluir nome, defaults de roster e políticas no hash de liga; outro pode hashear só o bloco de scoring passado ao `ffanalytics`. Ambos validam o envelope e congelam a configuração, mas discordam sobre a compatibilidade de um snapshot.

**Correção exigida:** separar e nomear `scoring_config_hash`, `league_rules_hash`, `recommendation_policy_hash` e suas versões de schema; definir defaults antes do hash, ordenação, coerção de tipos e quais deles devem ser comparados para selecionar um snapshot. A sessão deve armazenar os objetos/artefatos canônicos, não só hashes.

## Gate de retorno

Aceitar após a espinha incorporar esses cinco contratos e testes de integração para: bundle produzido/validado por implementações separadas; replay de correção + undo; rollback transacional; reabertura com verificação de hash; e rejeição de comando stale.
