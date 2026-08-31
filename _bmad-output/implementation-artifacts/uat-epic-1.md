# Roteiro de Teste de Aceite de Usuário — Épico 1

**Épico:** 1 — Preparar e validar o snapshot de dados
**Papel do testador:** operador (você, antes do draft)
**Base:** `docs/initial_vision.md` (modo "Preparation"), `docs/draft_strategy.md` (VOR / scoring / os 5 números do board), `_bmad-output/planning-artifacts/epics.md`, `_bmad-output/implementation-artifacts/epic-1-context.md`

---

## 1. O que este épico entrega (o que você está aceitando)

Da visão: *"Antes do draft: compute tudo que puder. Durante o draft: atualize estado, filtre alternativas e execute apenas cálculos marginais."* O Épico 1 é o **modo Preparation** e nada além disso:

- Um CLI (`scripts/prepare_snapshot.R`) que, **offline**, coleta projeções de múltiplas fontes via `ffanalytics`, aplica o scoring da liga e emite um **snapshot bundle canônico** com `points`, `vor`, `tier`, `tier_cliff` e metadados. Modo fallback aceita CSV manual.
- Uma **identidade de conteúdo** estável (hash SHA-256) para o bundle, idêntica entre máquinas.
- Uma **validação de qualidade** que classifica cada problema como *bloqueante* ou *aviso*, de forma determinística.
- Os **design tokens base** e o tema escuro único.
- A superfície **"Selecionar e validar snapshot"**: você abre "Preparar draft", escolhe o bundle e revê temporada, fontes, scoring, cobertura e avisos. Dados inválidos **bloqueiam o avanço** para a configuração da liga, sempre com motivo concreto e ação de recuperação.
- O runtime **nunca** acessa a rede nem enriquece dados.

**Critério de aceite global do épico:** partindo de um clone limpo, o operador consegue gerar um snapshot pelo CLI, abri-lo no app, revisar todos os metadados, e — quando os dados estão sãos — a rota para configurar a liga fica habilitada; quando não estão, o app explica exatamente o quê e oferece como recuperar. Nenhuma requisição de rede parte do app em nenhum momento.

---

## 2. Fora de escopo (NÃO testar aqui)

Estes itens da visão/estratégia pertencem a épicos posteriores e não devem reprovar o Épico 1:

| Item | Épico |
|---|---|
| Configuração da liga (times, roster, scoring, FLEX, bench, snake) | 2 |
| Ordem do snake, calendário de picks, event store SQLite | 2 |
| Draft room, registrar pick, undo/edit, board ao vivo | 3–4 |
| Motor de recomendação, VONA, `P(next)`, roster marginal, tier cliff *alert* | 3 |
| Monte Carlo, replacement level por simulação, mock draft, backtesting | 6 |
| `upside_score` / `starter_score` / `bench_score`, idade/experiência na Player Master | pós-V1 |

---

## 3. Pré-requisitos do ambiente

1. Clone limpo do repositório, R 4.6.1.
2. `Rscript -e 'renv::restore(prompt = FALSE)'` conclui sem erro (inclui `ffanalytics` no commit fixado e o fecho).
3. `cp config/config.yml.example config/config.yml` (o token da NFL **não** é usado no Épico 1, mas o clone limpo espera o arquivo).
4. Acesso à internet **apenas** para o cenário B1 (coleta `ffanalytics` real). Todos os demais cenários rodam offline.
5. Opcional (cenário C4): um segundo checkout do repositório, ou outra máquina, para conferir determinismo de hash entre máquinas.
6. Ferramenta para observar tráfego de rede do navegador (DevTools → Network, ou um proxy) para os cenários F8 / bloco de segurança.

**Ordem de execução recomendada:** os blocos A–C podem ser rodados assim que as Stories 1.1–1.4 estiverem `done`. Os blocos D, E, F dependem das Stories 1.5, 1.6, 1.7 respectivamente. O bloco G só faz sentido com o épico inteiro concluído.

---

## 4. Convenções deste roteiro

- Cada cenário tem **ID**, **pré-condição**, **passos**, **resultado esperado**.
- Marque **PASS** / **FAIL** / **BLOCKED** (não deu para testar) na tabela da seção 6.
- Em qualquer FAIL, capture: comando exato, saída completa (stdout+stderr), `snapshot_id` envolvido, e um print quando for a UI.
- "Bundle de referência" = um bundle válido conhecido; use o fixture `tests/testthat/fixtures/snapshot-valid/` como semente quando um cenário pedir um bundle bom de partida.

---

## 5. Cenários

### Bloco A — Fundação e boot seguro (Story 1.1)

**A1 — App sobe em loopback por comando único**
Pré: ambiente pronto, porta 3939 livre.
Passos: `Rscript -e 'shiny::runApp("app.R")'`.
Esperado: o app sobe, imprime no console uma URL `http://127.0.0.1:<porta>`, e responde a `curl -sI http://127.0.0.1:3939`.

**A2 — Não escuta em interface pública**
Pré: app no ar (A1).
Passos: descobrir um IP não-loopback da máquina (`ipconfig getifaddr en0` / `hostname -I`) e fazer `curl -sI http://<esse-ip>:3939`.
Esperado: conexão recusada / sem resposta. Só `127.0.0.1` responde.

**A3 — Colisão de porta falha de forma acionável**
Pré: ocupar a 3939 (`Rscript -e 'httpuv::startServer("127.0.0.1", 3939, list()); Sys.sleep(120)'` num terminal).
Passos: noutro terminal, `Rscript -e 'shiny::runApp("app.R")'`.
Esperado: o processo encerra com **exit code ≠ 0**; a mensagem cita a porta 3939 e a ação ("Libere-a ou defina `options(fdwr.port=)` e reinicie"); **não** tenta outra porta; **não** expõe publicamente.

**A4 — Gate de inicialização**
Pré: tornar o diretório de storage não gravável (ex.: `chmod -w` no diretório de dados do usuário) **ou** apontar o app para um bundle inválido.
Passos: subir o app e tentar usar a sessão.
Esperado: a sessão **não** é habilitada até que migrations, storage gravável e validação do bundle estejam OK; a causa é informada.

**A5 — Suíte de testes roda de clone limpo**
Passos: `Rscript -e 'devtools::test()'`.
Esperado: **0 falhas, 0 warnings**; a suíte roda fora de Shiny e de SQLite; nenhum teste acessa a rede.

**A6 — Núcleo testável fora do Shiny** (visão: *"`engine/` não deve depender de Shiny"*)
Passos: no console R, `pkgload::load_all()`, então chamar funções puras de domínio diretamente (ex.: `normalize_position("D/ST")`, `parse_snapshot_bundle(...)`, `snapshot_content_hash(...)`).
Esperado: retornam valores ou `domain_error` estruturado sem exigir uma sessão Shiny.

---

### Bloco B — Geração do snapshot pelo CLI (Story 1.4)

**B1 — Coleta `ffanalytics` com scoring da liga**
Pré: internet disponível; `config/score_settings.yml` (Full PPR) presente.
Passos: `Rscript scripts/prepare_snapshot.R --scoring config/score_settings.yml --season 2025 --sources CBS,ESPN,FantasyPros --out <tmp>`.
Esperado: cria um diretório `<tmp>/<snapshot_id>/` com `players.csv`, `metrics.csv`, `metadata.json`, `qa-report.json`, `scoring.yml`; toda linha tem `points`, `vor`, `tier`, `tier_cliff` sem `NA`; o script imprime o caminho e o `snapshot_id` e sai com código 0.

**B2 — Modo fallback CSV**
Pré: um CSV manual com as colunas obrigatórias (`player_id, display_name, normalized_name, position, points, vor, tier, tier_cliff`) e um JSON de metadados.
Passos: `Rscript scripts/prepare_snapshot.R --from-csv <csv> --metadata <json> --out <tmp>` (sem `ffanalytics` no caminho).
Esperado: produz **o mesmo formato** de bundle canônico; `source_list` = `["manual-csv"]`.

**B3 — Cada execução é imutável**
Passos: rodar B2 duas vezes seguidas para o mesmo `--out`.
Esperado: dois `snapshot_id` distintos, dois diretórios; o primeiro bundle permanece **byte-a-byte intacto** (compare com `diff -r` ou hash). Nenhuma sobrescrita.

**B4 — Config de scoring inválida**
Passos: `--scoring` apontando para um YAML malformado (ou que não é um mapa).
Esperado: **exit ≠ 0**, mensagem em PT-BR indicando o arquivo e a causa; **nenhum** diretório de bundle criado (nem parcial).

**B5 — Falha de coleta**
Passos: rodar B1 **sem** internet (ou com uma fonte inexistente em `--sources`).
Esperado: **exit ≠ 0**, mensagem cita a causa/fonte; **nenhum bundle parcial** em disco.

**B6 — `ffanalytics` ausente**
Pré: uma biblioteca R onde `ffanalytics` não está instalado.
Passos: rodar B1 no modo coleta.
Esperado: **exit ≠ 0** com instrução explícita de instalar via `renv::install("FantasyFootballAnalytics/ffanalytics@1955daa0…")`.

**B7 — Metadados completos**
Passos: abrir o `metadata.json` de um bundle gerado (B1 ou B2).
Esperado: contém `snapshot_id` (único), `season`, `generated_at` (UTC ISO-8601), `pipeline_version`, `source_list`, `scoring_hash`, `content_hash`, `qa_summary`, `schema_version = "snapshot-bundle-v1"`.

---

### Bloco C — Contrato e identidade do bundle (Stories 1.2, 1.3)

**C1 — Estrutura canônica**
Passos: listar o diretório de um bundle.
Esperado: exatamente `players.csv`, `metrics.csv`, `metadata.json`, `qa-report.json` (+ `scoring.yml`). Nada a mais no manifesto de conteúdo.

**C2 — Campos mínimos e normalização de posição**
Passos: abrir `players.csv` / `metrics.csv`.
Esperado: por jogador — `player_id`, `display_name`, `normalized_name`, `position` (do conjunto `QB/RB/WR/TE/K/DST`; qualquer `D/ST`, `DEF`, `D-ST` aparece como `DST`), `points`, `vor`, `tier`, `tier_cliff`; `nfl_team` presente quando conhecido. Opcionais (`floor`, `ceiling`, `sd_points`, `ecr`, `adp`, `adp_sd`, `uncertainty`, `bye_week`) podem faltar sem quebrar nada.

**C3 — Hash muda com qualquer byte / estável ao reformatar**
Passos: recomputar `snapshot_content_hash` do bundle; depois (a) alterar 1 caractere em `players.csv` e recomputar; (b) reindentar/reordenar as chaves do `metadata.json` sem mudar valores e recomputar.
Esperado: (a) o hash **muda**; (b) o hash **não muda**.

**C4 — Determinismo entre máquinas**
Pré: dois checkouts / duas máquinas, locale diferente se possível (ex.: um em `pt_BR`, outro em `C`).
Passos: copiar o mesmo bundle para os dois e recomputar `snapshot_content_hash` em cada.
Esperado: **hash idêntico**, hex minúsculo.

**C5 — Compatibilidade de scoring**
Passos: (a) num bundle são, conferir que `scoring_config_hash(scoring.yml)` == `metadata$scoring_hash`; (b) editar um peso no `scoring.yml` do bundle sem atualizar o metadado e revalidar.
Esperado: (a) batem; (b) a divergência é **detectada** (erro `snapshot_scoring_incompativel` com esperado/encontrado).

---

### Bloco D — Validação de qualidade (Story 1.5)

Para cada cenário, partir do bundle de referência e introduzir **um** defeito.

| ID | Defeito introduzido | Classificação esperada |
|---|---|---|
| D1 | nenhum (bundle são) | 0 bloqueios; avanço liberado |
| D2 | remover `points` de uma linha (campo obrigatório) | **bloqueante** |
| D3 | duplicar um `player_id` | **bloqueante** |
| D4 | dois jogadores com o mesmo `normalized_name` sem desambiguação | **bloqueante** |
| D5 | `position = "FB"` numa linha | **bloqueante** (`posicao_fora_do_v1`) |
| D6 | `adp = -3` numa linha que informa ADP | **bloqueante** |
| D7 | apagar `qa-report.json` (ou marcá-lo como bloqueante) | **bloqueante** |
| D8 | `metadata$scoring_hash` divergente da config ativa | **bloqueante** |
| D9 | remover a coluna `ceiling` inteira (opcional) | **aviso**, não bloqueia |
| D10 | cobertura anômala não crítica (ex.: só 6 TEs) | **aviso**, não bloqueia |

**D11 — Lista determinística**
Passos: rodar a validação sobre o mesmo bundle defeituoso (vários defeitos) duas vezes.
Esperado: a **mesma lista de achados na mesma ordem**.

**D12 — Formato das mensagens**
Esperado: todo achado tem um `code` estável, mensagem em **PT-BR**, e `details` machine-readable (campo, valor, player_id conforme o caso). Nenhuma exceção R não tratada — falhas são valores.

---

### Bloco E — Camada visual (Story 1.6)

**E1 — Tema escuro único**
Esperado: não há alternância de tema; nenhuma superfície renderiza em modo claro.

**E2 — Só tokens**
Passos: inspecionar o CSS/estilos das telas.
Esperado: cores, tipografia, espaçamento e raios vêm dos tokens de `DESIGN.md` — nenhum valor hard-coded fora deles.

**E3 — Semântica de cor + redundância**
Esperado: `action` (verde) só em ação a executar/confirmação; `focus` (azul) em foco de teclado e item selecionado; `warning` (âmbar) em conferência/undo; `danger` (vermelho) só em falha/conflito/ação inválida. **Todo estado** carrega também texto, ícone ou rótulo — nunca só cor.

**E4 — Contraste WCAG 2.2 AA**
Passos: medir com um verificador de contraste `ink` sobre `canvas`/`surface`/`surface-raised` e `ink-muted` sobre os mesmos; medir `focus`/`action`/`warning`/`danger` como indicador não textual.
Esperado: texto ≥ 4.5:1; indicadores não textuais ≥ 3:1. `ink-muted` só aparece em metadado não crítico.

---

### Bloco F — Superfície "Selecionar e validar snapshot" (Story 1.7) — Fluxo J-01

**F1 — Lista de bundles locais**
Pré: 2+ bundles gerados no diretório de dados.
Passos: abrir "Preparar draft".
Esperado: os bundles locais aparecem para seleção; nenhuma chamada de rede para listá-los.

**F2 — Painel de revisão**
Passos: selecionar um bundle são.
Esperado: a tela mostra **temporada**, **data/hora de geração**, **fontes agregadas**, **método/scoring** (com o hash ou um resumo), **cobertura por posição** e a **lista de avisos**.

**F3 — Estado de carregamento**
Passos: observar a região de resumo enquanto o bundle é lido.
Esperado: a região expõe `aria-busy` durante a leitura.

**F4 — Falha de leitura preserva a seleção**
Pré: um bundle corrompido (ex.: `players.csv` truncado).
Passos: selecioná-lo.
Esperado: a seleção **é mantida**; a tela oferece **reexecutar `scripts/prepare_snapshot.R`** ou **escolher outro bundle**; não trava.

**F5 — Bloqueio explica e oferece recuperação**
Passos: selecionar um bundle com um achado bloqueante (qualquer de D2–D8).
Esperado: o botão/rota de avançar fica **desabilitado**; aparece a causa concreta em `danger`, identificando o campo ou a incompatibilidade; sempre acompanhada de uma **ação de recuperação** (reexecutar o script ou selecionar outro snapshot).

**F6 — Opcionais ausentes são visíveis, não bloqueiam**
Passos: selecionar um bundle sem `adp`/`ceiling`/`bye_week`.
Esperado: cada campo ausente aparece marcado como **"Não disponível neste snapshot"**; o avanço **não** é bloqueado por isso.

**F7 — Bundle válido libera o próximo passo**
Passos: selecionar um bundle são, confirmar 0 bloqueios.
Esperado: a ação/rota para **configurar a liga** fica habilitada. (Não é preciso testar a tela de configuração — é Épico 2. Basta que o gate abra.)

**F8 — Zero rede no runtime**
Passos: com o DevTools/Network aberto (ou um proxy registrando), percorrer F1→F7 inteiro.
Esperado: **nenhuma** requisição HTTP externa parte do app. Só o servidor Shiny local.

**F9 — Microcopy**
Esperado: textos curtos, factuais, orientados à próxima ação; mensagens de domínio em PT-BR; sem celebração ("Tudo certo! 🎉") nem alarmismo.

---

### Bloco G — Fim a fim (o cenário da visão)

**G1 — Preparation completo, cronometrado**
Passos: do zero — (1) `Rscript scripts/prepare_snapshot.R …`; (2) subir o app; (3) abrir "Preparar draft"; (4) selecionar o snapshot; (5) revisar temporada/geração/fontes/scoring/cobertura/avisos; (6) confirmar ausência de bloqueios; (7) verificar que o avanço para a configuração da liga está liberado.
Esperado: o fluxo inteiro conclui sem acesso de rede pelo app; anote o tempo total e qualquer fricção (passos confusos, informação faltando na tela).

**G2 — Trocar o snapshot antes de iniciar a sessão**
Passos: reexecutar o CLI gerando um segundo snapshot; voltar ao app e trocar a seleção para o novo bundle.
Esperado: o preparo aceita o novo bundle e revalida. (A imutabilidade *pós-início de sessão* é Épico 2 e não é testada aqui.)

---

## 6. Registro de resultados

| ID | Resultado | Evidência (arquivo / print / log) | Observações | Data |
|----|-----------|-----------------------------------|-------------|------|
| A1 | | | | |
| A2 | | | | |
| A3 | | | | |
| A4 | | | | |
| A5 | | | | |
| A6 | | | | |
| B1 | | | | |
| B2 | | | | |
| B3 | | | | |
| B4 | | | | |
| B5 | | | | |
| B6 | | | | |
| B7 | | | | |
| C1 | | | | |
| C2 | | | | |
| C3 | | | | |
| C4 | | | | |
| C5 | | | | |
| D1 | | | | |
| D2 | | | | |
| D3 | | | | |
| D4 | | | | |
| D5 | | | | |
| D6 | | | | |
| D7 | | | | |
| D8 | | | | |
| D9 | | | | |
| D10 | | | | |
| D11 | | | | |
| D12 | | | | |
| E1 | | | | |
| E2 | | | | |
| E3 | | | | |
| E4 | | | | |
| F1 | | | | |
| F2 | | | | |
| F3 | | | | |
| F4 | | | | |
| F5 | | | | |
| F6 | | | | |
| F7 | | | | |
| F8 | | | | |
| F9 | | | | |
| G1 | | | | |
| G2 | | | | |

**Veredito do épico:** ACEITO / ACEITO COM RESSALVAS / REPROVADO — _______________

---

## 7. Notas de alinhamento com a visão e a estratégia

Observações a levar ao retrospectivo do Épico 1 — **não** são critérios de reprovação:

- **Projeções por fonte.** A visão sugere *"conservar as projeções individuais por fonte, em vez de guardar apenas o agregado"* (para mostrar dispersão CBS/ESPN/NFL/… na tela do jogador). O Épico 1 grava só o agregado (`points`, `sd_points`). Confirmar se a granularidade por fonte entra numa story futura (painel de inspeção do jogador é Story 3.9).
- **Replacement level da liga.** A estratégia recomenda calcular o replacement por Monte Carlo específico da liga, não usar os defaults do `ffanalytics`. O Épico 1 usa um baseline fixo de 12 times em `config/snapshot_pipeline.yml` (`QB 13, RB 35, WR 36, TE 13, K 8, DST 3`), passado explicitamente. O cálculo por simulação é Épico 6.
- **Os 5 números do board** (`Proj`, `VOR`, `Tier`, `ADP`, `P(next)`). O Épico 1 entrega os quatro primeiros dentro do snapshot; `P(next)` depende do calendário de picks (Épico 2) e do motor (Épico 3).
- **Reprodutibilidade do `vor`/`tier`.** `metadata.json` (schema v1) fixa `scoring_hash` mas não o hash de `config/snapshot_pipeline.yml`; a reprodutibilidade do VOR depende de incrementar `pipeline_version` quando esse arquivo mudar. Item já anotado em `deferred-work.md` (candidato a schema v2).
- **"Tier Cliff Alert"** da visão é um alerta *ao vivo* (Épico 3). O Épico 1 só entrega o dado `tier_cliff` por jogador dentro do snapshot.
