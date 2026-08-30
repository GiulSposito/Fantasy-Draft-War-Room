---
title: "PRD — Fantasy Draft War Room"
status: final
created: 2026-08-28
updated: 2026-08-28
source_spec: "docs/fantasy-draft-war-room-spec.md"
---

# PRD — Fantasy Draft War Room

**Fonte técnica:** `docs/fantasy-draft-war-room-spec.md` (v0.1, 2026-08-28)  
**Escopo:** Operational MVP (V1)  
**Status:** rascunho validado parcialmente; as perguntas abertas em §9 são bloqueadores a tratar antes do planejamento de histórias que elas afetam.

## 1. Tese de produto

### Problema e oportunidade

Durante um draft snake de NFL Fantasy, rankings estáticos não respondem à decisão situada: qual jogador traz mais valor agora, qual posição é urgente, como a escolha altera o lineup e como ela se relaciona com a próxima vez que o usuário escolherá. O operador precisa registrar escolhas de uma mesa que se move rapidamente e recuperar um erro sem perder o ritmo.

### Proposta de valor

O Fantasy Draft War Room transforma um snapshot pré-preparado de projeções em recomendações contextuais, explicáveis e rápidas. Para cada pick, ele mostra os melhores candidatos, o motivo objetivo da recomendação e o impacto no roster do usuário.

### Persona e contexto primários

**Fantasy manager individual**, em notebook ou desktop, acompanhando um draft em outra plataforma ou presencialmente. É uma ferramenta de operador único: ele precisa procurar e registrar picks rapidamente, eventualmente anotar picks de outros times e continuar operando após refresh ou reinício local.

### Princípios que guiam o produto

1. **Rapidez operacional:** nenhum passo normal do live draft pode depender de rede ou de processamento demorado.
2. **Controle humano:** a recomendação ajuda, mas não impede o operador de escolher outro jogador.
3. **Explicabilidade:** uma recomendação sempre comunica seus fatores, sem alegar certeza indevida.
4. **Recuperabilidade:** picks confirmados, correções e a sessão sobrevivem a interrupções.
5. **Configuração antes de código:** a liga é configurável no limite suportado pela versão.
6. **Reprodutibilidade:** um draft usa um snapshot e uma configuração identificáveis, que não mudam silenciosamente.

## 2. Hipótese e resultado do MVP

**Hipótese V1.** Se o manager puder configurar uma liga compatível, registrar picks e ver rapidamente uma lista explicada de recomendações baseada em projeções, valor relativo, tiers, ADP e ajuste simples de roster, ele conseguirá conduzir um draft completo com mais confiança e sem interromper o fluxo quando cometer um erro.

**O MVP prova valor quando**, em um ensaio de draft completo com usuários-alvo:

- o participante conclui, retoma e exporta uma sessão sem editar código;
- entende por que o primeiro recomendado aparece (incluindo a diferença entre valor/projeção, preço de mercado e urgência) e consegue escolher conscientemente outra opção;
- registra ou corrige escolhas sem depender de rede e sem perda de dados.

Qualidade preditiva comparativa, previsão de disponibilidade e otimização pelo roster final são hipóteses posteriores; não são promessa de V1.

## 3. Escopo do V1 — Operational MVP

### Incluído

- Executar, antes do draft, um `script.R` local por linha de comando para preparar um snapshot canônico de jogadores e projeções; carregar esse artefato local, validar sua qualidade e mostrar avisos antes de iniciar o draft. A V1 não distribui dados nem acessa fontes externas durante o runtime live.
- Operar draft snake para 8 a 14 times e 15 rounds, com slots titulares, reservas, elegibilidade de FLEX e scoring definidos por configuração YAML validada. A configuração de referência — 12 times, Full PPR, 1 QB, 2 RB, 2 WR, 1 TE, 1 FLEX RB/WR, 1 K, 1 D/ST e 6 reservas — é fornecida como versão inicial dos arquivos de configuração.
- Cadastrar times, identificar o time do usuário, definir/sortear/reordenar a primeira rodada e bloquear a ordem validada antes do início.
- Iniciar, pausar, retomar e encerrar um draft; registrar, desfazer e corrigir picks; manter board, disponíveis e rosters consistentes.
- Buscar e selecionar jogadores rapidamente por teclado, com nomes normalizados, posição e time NFL visíveis.
- Calcular e apresentar o melhor lineup inicial possível de cada roster e o ganho marginal de candidatos no roster do usuário.
- Exibir pelo menos cinco recomendações rápidas, com score, fatores objetivos, alerta de tier cliff quando aplicável e políticas configuráveis; os arquivos de configuração fornecem uma estratégia inicial recomendada que adia K/DST até o fim do draft.
- Restaurar uma sessão local após reinício/refresh e exportar picks, rosters, configuração e metadados.
- Operar inteiramente sem acesso à rede depois de o snapshot ter sido selecionado.

### Não incluído no V1

- Modelar probabilidade de um jogador chegar ao próximo pick, custo de esperar, corridas adaptativas de posição ou valor esperado de disponibilidade.
- Simulações Monte Carlo, simulação de adversários, mock drafts, backtesting e avaliação do roster final esperado.
- Integrações automáticas com ESPN, Yahoo, NFL, CBS, Sleeper ou outras plataformas; atualizações/notícias ao vivo.
- Draft de leilão, dynasty/keeper, rookie-only, waivers, trades, playoffs, multiusuário, aplicativo nativo ou hospedagem pública multi-tenant.
- Comparação lado a lado de candidatos e histórico detalhado das recomendações exibidas.

### Detalhes em companions

O contrato de entrada/saída e o tratamento de falhas do `script.R` estão no [companion de dados](data-contract.md). Arquitetura, schemas, fórmulas, testes, roadmap de engenharia e o [registro de decisões](decisions.md) permanecem em companions para manter este PRD focado em escopo e resultados.

### Envelope de configuração V1

- O draft snake aceita de 8 a 14 times e exatamente 15 rounds por time.
- O roster contém 9 titulares — QB, WR, WR, RB, RB, FLEX, TE, K e D/ST — e 6 reservas; os 15 rounds devem preencher exatamente esses slots.
- FLEX aceita somente RB ou WR. QB, TE, K e D/ST não são elegíveis para FLEX na V1.
- A configuração é viável quando há 8–14 times, 15 rounds e a definição de slots respeita as posições e a elegibilidade acima; caso contrário, o início do draft é bloqueado com motivo acionável.

## 4. Jornadas operacionais do usuário

| ID | Jornada | Fluxo e resultado esperado | Capacidades envolvidas |
|---|---|---|---|
| J-01 | Preparar dados | Antes do draft, o manager executa o `script.R` local para preparar o snapshot e então o seleciona. Vê temporada, data, fontes, cobertura e avisos; se a preparação ou validação falha, recebe motivo acionável e não inicia a sessão. | DATA-001–005, REP-002 |
| J-02 | Configurar e travar draft | O manager define a liga, times, seu time e a ordem inicial. O sistema mostra o calendário snake e bloqueia o início até que a configuração e a ordem sejam viáveis. Após iniciar, a ordem e o snapshot não podem mudar por acidente. | LEAGUE-001–003,005,007; ORDER-001–006; DRAFT-001 |
| J-03 | Conduzir um pick | Na tela live, o manager vê o time e o pick atuais, seu próximo pick, roster, board e recomendações. Busca um jogador, confirma-o pelo teclado e recebe feedback imediato; o sistema avança para o próximo slot, atualiza o roster e recalcula a lista. | INPUT-001–007; DRAFT-002–005; ROSTER-001–006; REC-001–007,009–010 |
| J-04 | Corrigir e recuperar | Ao registrar um jogador errado, o manager usa undo visível ou corrige um pick anterior; a sessão recompõe automaticamente board, rosters, disponíveis e recomendação a partir do ponto corrigido. Se a mudança produzir duplicidade ou outro estado impossível, a correção é rejeitada com motivo claro, sem apagar picks posteriores. Ao abrir ou recarregar o app, ele vê sessões ordenadas da mais recente à mais antiga, com a mais recente pré-selecionada, e confirma ou escolhe outra antes da restauração. Nenhum pick confirmado é perdido. | DRAFT-006–009; PERSIST-001–004; REL-001–003 |
| J-05 | Encerrar e revisar | Com todos os slots preenchidos, o draft encerra normalmente; em caso excepcional, o manager pode encerrá-lo incompleto com aviso. Ele exporta picks, rosters, configuração e metadados para consulta posterior. | DRAFT-010–011; PERSIST-005–007 |

## 5. Requisitos funcionais e alocação por versão

**Legenda:** V1 = compromisso do Operational MVP; V2/V3 = planejado, mas não promessa do MVP; Posterior = fora do roadmap atual ou depende de decisão; `*` = V1 com corte/decisão provisória explicitados abaixo.

### Dados, liga e ordem

| Requisito | Alocação | Definição de produto / corte |
|---|---|---|
| DATA-001 Importar snapshot | V1 | Executar `script.R` local no pré-draft para preparar um snapshot canônico e importá-lo no runtime; o live draft não realiza preparação nem acesso de rede. |
| DATA-002 Metadados do snapshot | V1 | Exibir e conservar temporada, geração, fontes, método, scoring e identidade do conteúdo. |
| DATA-003 Validar jogadores | V1 | Detectar identificadores/posição/projeção ausentes, ambiguidades/duplicatas, ADP inválido e cobertura anômala. |
| DATA-004 Qualidade do snapshot | V1 | Mostrar cobertura e avisos antes de iniciar. |
| DATA-005 Imutabilidade ativa | V1 | Bloquear troca do snapshot de uma sessão iniciada. |
| LEAGUE-001 Times e rounds | V1 | Configurar de 8 a 14 times e 15 rounds; bloquear valores fora do envelope V1. |
| LEAGUE-002 Slots e reservas | V1 | Usar 9 titulares (QB, WR, WR, RB, RB, FLEX, TE, K e D/ST) e 6 reservas; bloquear configuração incompatível com 15 rounds. |
| LEAGUE-003 FLEX | V1 | FLEX aceita somente RB ou WR. |
| LEAGUE-004 Scoring | V1 | Configurar scoring por YAML compatível com `ffanalytics`; Full PPR é o default inicial dos arquivos de configuração. |
| LEAGUE-005 Time do usuário | V1 | Exatamente um time do usuário por sessão. |
| LEAGUE-006 Salvar/reutilizar configuração | V2 | V1 preserva a configuração da sessão/exportação, mas não promete biblioteca de presets. |
| LEAGUE-007 Viabilidade do roster | V1 | Impedir início quando rounds/slots são incompatíveis. |
| ORDER-001–006 Times, ordem e snake | V1 | Cadastrar, sortear ou reordenar antes do início; gerar e exibir todos os slots; bloquear alterações normais depois do início. |

### Ciclo, entrada e roster

| Requisito | Alocação | Definição de produto / corte |
|---|---|---|
| DRAFT-001–005 Iniciar e registrar | V1 | Iniciar somente sessão pronta; registrar no slot atual, rejeitar duplicata, atribuir ao time correto e avançar. |
| DRAFT-006 Undo | V1 | Desfazer o último pick efetivo, restaurando o estado anterior. |
| DRAFT-007 Correção | V1 | Corrigir pick anterior e recompor automaticamente, de forma determinística, todos os efeitos posteriores. Se a correção gerar duplicidade ou outro estado inválido, rejeitá-la com motivo claro sem remover picks posteriores. |
| DRAFT-008 Pausar/retomar | V1 | Pausa impede novos picks normais; retomada reabre a mesma sessão. |
| DRAFT-009 Restaurar | V1 | Ao abrir ou recarregar, listar sessões locais da mais recente à mais antiga, pré-selecionar a mais recente e permitir que o usuário confirme ou escolha outra para restaurar. |
| DRAFT-010–011 Finalizar/abortar | V1 | Finalizar quando completo; permitir encerramento administrativo incompleto com aviso persistente. |
| INPUT-001–007 Busca e feedback | V1 | Busca incremental e tolerante a variações simples; mostra posição e time, oculta jogadores já escolhidos, aceita entrada por teclado, confirma o resultado e mantém undo visível. |
| ROSTER-001–005 Roster, lineup e marginal | V1 | Construir rosters; atribuir melhor lineup conforme elegibilidade; diferenciar titular, upgrade, FLEX, banco e redundância. |
| ROSTER-006 Completar obrigatórios | V1 | Alertar/aplicar restrição quando escolhas restantes não permitem completar slots obrigatórios. |

### Recomendações, persistência e exportação

| Requisito | Alocação | Definição de produto / corte |
|---|---|---|
| REC-001–007 Ranking, explicação e roster | V1 | Recalcular ranking após pick; mostrar no mínimo top 5, score, componentes, explicação curta e determinística, tier cliffs e efeito do roster. Pesos e políticas são lidos de configuração versionada. |
| REC-008 Próximo pick do usuário | V2 | V1 exibe o próximo pick, mas não estima custo de esperar; incorporar essa informação ao score exige o modelo de mercado V2. |
| REC-009 K/DST cedo | V1 | Política configurável desprioriza K/DST cedo no conjunto inicial recomendado; o comportamento ativo é consultável. |
| REC-010 Filtro de posição | V1 | Usuário filtra a lista de disponíveis/recomendação por posição, sem alterar o estado. |
| REC-011 Comparar candidatos | V2 | Comparação lado a lado entra com explicabilidade estruturada V2. |
| REC-012 Histórico de recomendações | V2 | Registrar a lista exibida em cada pick do usuário para avaliação/calibração. |
| PERSIST-001–004 Eventos, auditoria e reconstrução | V1 | Uma confirmação de pick é durável ou não ocorre; undo/correção deixam trilha e a sessão é reconstruível. |
| PERSIST-005–007 Exportar resultado | V1 | Exportar picks, rosters, configuração e metadados. |
| PERSIST-008 Backup portátil | V2 | V1 exige recuperação local e exportações; pacote de backup/reimportação independente é extensão. |

## 6. Requisitos não funcionais e alocação por versão

| Requisito | Alocação | Critério de produto |
|---|---|---|
| PERF-001 Registrar/persistir pick | V1 | p95 ≤ 100 ms. |
| PERF-002 Recomendação rápida | V1 | p95 ≤ 300 ms. |
| PERF-003 Atualização da tela | V1 | p95 ≤ 500 ms. |
| PERF-004 Busca | V1 | p95 ≤ 100 ms. |
| PERF-005 Inicialização | V1 | Snapshot válido utilizável em ≤ 3 s. |
| PERF-006 Sem rede no live draft | V1 | Operações síncronas do draft não fazem acesso de rede. |
| PERF-007 Simulação fora do crítico | V3 | A simulação extensa não bloqueia o fluxo live. |
| REL-001 Refresh recupera sessão | V1 | Sessão ativa/selecionada volta a um estado consistente. |
| REL-002 Sem perda pós-confirmação | V1 | Interrupção após uma confirmação não perde o pick. |
| REL-003 Sem duplicidade | V1 | Regras de integridade impedem jogador/pick duplicados. |
| REL-004 Falha profunda preserva rápido | V3 | Falha de análise profunda não tira a recomendação rápida. |
| REL-005 Resultado antigo descartado | V3 | Resultado assíncrono de estado antigo nunca substitui o atual. |
| MAINT-001–005 Isolamento, testes, configuração e dependências | V1 (qualidade) | Gates de engenharia para proteger o produto: regra de negócio testável, módulos isolados, fórmulas/políticas alteráveis de forma controlada e dependências reproduzíveis. Detalhes pertencem ao companion de arquitetura/qualidade. |
| EXPL-001–004 Explicabilidade | V1 | Nenhuma recomendação é apenas um número: ela mostra pelo menos três fatores e políticas/pesos consultáveis, e separa projeção, valor, preço e urgência. |
| REP-001 Seed de simulação | V3 | Simulações repetíveis com seed registrada. |
| REP-002 Vínculo de recomendação | V1 | Cada recomendação é associável ao snapshot, configuração e estado que a produziram. |
| REP-003 Reabrir/reproduzir export | V1* | V1 recupera sessão local e exporta dados suficientes para auditoria; reimportação completa de pacote portátil é V2. |
| UX-001–004 Fluxo rápido e acessível | V1 | Keyboard-first, sem confirmação rotineira por modal, status não apenas por cor e informação crítica visível na tela live. |

### Base de medição V1

Todos os percentis serão medidos no mesmo benchmark: snapshot de 400 jogadores, liga de 12 times e 14 rounds (168 picks), fixture determinística e execução local em um MacBook Pro com processador Intel como baseline de referência. O hardware não é requisito de produto nem gate de compatibilidade; cada execução deve registrar a configuração efetiva e a ferramenta de medição usada.

## 7. Critérios de aceite mensuráveis do release V1

| ID | Cenário de aceite |
|---|---|
| AC-V1-01 | **Dado** um snapshot válido e uma liga de 8–14 times com 15 rounds, **quando** o manager conclui J-02, **então** cada time possui um slot por round, os overall picks são contínuos e a ordem só pode ser alterada por ação administrativa explícita após o início. **Dada** uma configuração fora do envelope V1, **então** o início é bloqueado com motivo acionável. |
| AC-V1-02 | **Dado** draft pronto e jogador disponível, **quando** o manager confirma o nome no pick atual, **então** o jogador aparece uma única vez no time do slot, deixa a lista de disponíveis, o board avança e a recomendação é atualizada. |
| AC-V1-03 | **Dado** um jogador já escolhido ou um nome ambíguo/inválido, **quando** o manager tenta confirmá-lo, **então** o pick não muda e a interface mostra motivo claro e ação de recuperação. |
| AC-V1-04 | **Dada** qualquer sequência válida de picks, **quando** o manager desfaz o último ou corrige um pick anterior que preserva a integridade, **então** board, rosters, disponíveis e recomendações são recompostos automaticamente e a trilha mostra a alteração. **Quando** a correção geraria duplicidade ou outro estado inválido, **então** nenhuma mudança é persistida e a interface explica o motivo. |
| AC-V1-05 | **Dadas** sessões locais existentes, incluindo uma com 80 picks confirmados, **quando** a aplicação é reiniciada/atualizada, **então** ela lista as sessões da mais recente à mais antiga, pré-seleciona a mais recente, permite escolher outra e restaura a opção confirmada sem perda ou duplicação, inclusive em um drill de recuperação automatizado. |
| AC-V1-06 | **Dado** um pick do usuário, **quando** a lista é renderizada, **então** há ao menos cinco candidatos disponíveis e cada um tem score, explicação determinística e fatores suficientes para distinguir valor, preço de mercado e ajuste de roster; tier cliff aparece quando aplicável. |
| AC-V1-07 | **Dado** o benchmark V1, **quando** são executados 168 picks e 100 buscas, **então** as medições de PERF-001 a PERF-005 atendem a seus respectivos limites de p95 e não há acesso à rede no fluxo live. |
| AC-V1-08 | **Dado** draft completo de 168 picks, **quando** o último slot é preenchido, **então** a sessão encerra, nenhum jogador/pick é duplicado e picks, rosters, configuração e metadados podem ser exportados. |
| AC-V1-09 | **Dado** pelo menos 5 participantes do público-alvo em roteiro assistido, **quando** cada um configura e conclui um draft completo de 15 rounds, incluindo ao menos uma correção, uma recarga e uma exportação, **então** pelo menos 4 concluem o fluxo sem editar código e pelo menos 4 explicam corretamente o motivo principal da recomendação top 1. É um sinal inicial de usabilidade, não validação estatística. |

## 8. Métricas de sucesso e contramétricas

| ID | Métrica V1 | Meta/decisão | Fonte e janela | Contramétrica |
|---|---|---|---|---|
| SM-01 | Integridade do draft: perdas/duplicidades | 0 perdas ou duplicidades em 100% dos drills de 168 picks antes de liberar V1 | testes de integração e recovery drill | taxa de falha técnica; não mascarar falha removendo validações |
| SM-02 | Recuperação | 100% de restauração consistente nos drills definidos | teste de restart no pick 80 e no fim | tempo de recuperação e necessidade de intervenção manual |
| SM-03 | Tempo humano por pick | mediana < 3 s em drafts completos de 15 rounds | pelo menos 5 testes assistidos | taxa de undo/correção; rapidez não pode aumentar erro |
| SM-04 | Compreensão da recomendação | ≥80% dos participantes explicam o principal motivo do top 1 | pelo menos 5 testes assistidos | confiança indevida; coletar relato de discordância/ambiguidade |
| SM-05 | Conclusão autônoma | ≥80% dos participantes concluem setup, draft completo de 15 rounds, correção, recarga e exportação sem editar código | pelo menos 5 testes assistidos | tempo até conclusão e pedidos de ajuda |
| SM-06 | Latência do caminho crítico | cumprir PERF-001 a PERF-005 em benchmark | relatório do benchmark a cada release candidato | consumo de recursos e regressões na recuperação |

**Métricas postergadas:** presença da escolha humana no top 5, calibração de disponibilidade, estabilidade/calibração de pesos e desempenho comparativo de estratégias só serão avaliáveis quando V2/V3 introduzirem os respectivos modelos e histórico (REC-012, PNext/VONA, simulação/backtesting).
