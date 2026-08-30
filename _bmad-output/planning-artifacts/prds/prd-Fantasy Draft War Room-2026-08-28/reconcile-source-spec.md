# Reconciliação da especificação-fonte para o PRD

**Fonte:** `docs/fantasy-draft-war-room-spec.md` (v0.1, 28-08-2026)  
**Finalidade:** extrair as decisões de produto para um PRD V1 executável, sem transportar decisões de implementação.  
**Status:** proposta de reconciliação; as premissas abertas ao fim precisam de decisão do Product Manager antes do planejamento de histórias.

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

- Carregar **um snapshot local já preparado** de jogadores e projeções, validar sua qualidade e mostrar avisos antes de iniciar o draft.
- Operar inicialmente a configuração de referência: draft snake, 12 times, 14 rounds, Full PPR, 1 QB, 2 RB, 2 WR, 1 TE, 1 FLEX RB/WR, 1 K, 1 DST e 5 reservas. A interface também aceita variar número de times, rounds, slots e FLEX quando essas alterações forem validadas pelas regras suportadas.
- Cadastrar times, identificar o time do usuário, definir/sortear/reordenar a primeira rodada e bloquear a ordem validada antes do início.
- Iniciar, pausar, retomar e encerrar um draft; registrar, desfazer e corrigir picks; manter board, disponíveis e rosters consistentes.
- Buscar e selecionar jogadores rapidamente por teclado, com nomes normalizados, posição e time NFL visíveis.
- Calcular e apresentar o melhor lineup inicial possível para os rosters e o ganho marginal de candidatos no roster do usuário.
- Exibir pelo menos cinco recomendações rápidas, com score, fatores objetivos, alerta de tier cliff quando aplicável e política padrão que adia K/DST até o fim do draft.
- Restaurar uma sessão local após reinício/refresh e exportar picks, rosters, configuração e metadados.
- Operar inteiramente sem acesso à rede depois de o snapshot ter sido selecionado.

### Não incluído no V1

- Modelar probabilidade de um jogador chegar ao próximo pick, custo de esperar, corridas adaptativas de posição ou valor esperado de disponibilidade.
- Simulações Monte Carlo, simulação de adversários, mock drafts, backtesting e avaliação do roster final esperado.
- Integrações automáticas com ESPN, Yahoo, NFL, CBS, Sleeper ou outras plataformas; atualizações/notícias ao vivo.
- Draft de leilão, dynasty/keeper, rookie-only, waivers, trades, playoffs, multiusuário, aplicativo nativo ou hospedagem pública multi-tenant.
- Comparação lado a lado de candidatos e histórico detalhado das recomendações exibidas.

### Limite de responsabilidade de dados V1 (decisão provisória)

O produto **importa localmente** um snapshot canônico produzido antes do draft; ele não promete buscar, licenciar, distribuir nem atualizar fontes externas. CSV compatível é uma alternativa de importação para contingência. O proprietário do snapshot, formato definitivo, fontes permitidas e comportamento para falha de atualização permanecem em aberto (OQ-01).

## 4. Jornadas operacionais do usuário

| ID | Jornada | Fluxo e resultado esperado | Capacidades envolvidas |
|---|---|---|---|
| J-01 | Preparar dados | Antes do draft, o manager seleciona um snapshot local. Vê temporada, data, fontes, cobertura e avisos; se a validação bloqueia o uso, ele recebe motivo acionável e não inicia a sessão. | DATA-001–005, NFR-REP-002 |
| J-02 | Configurar e travar draft | O manager define a liga, times, seu time e a ordem inicial. O sistema mostra o calendário snake e bloqueia o início até que a configuração e a ordem sejam viáveis. Após iniciar, a ordem e o snapshot não podem mudar por acidente. | LEAGUE-001–003,005,007; ORDER-001–006; DRAFT-001 |
| J-03 | Conduzir um pick | Na tela live, o manager vê o time/pick atual, seu próximo pick, roster, board e recomendações. Busca um jogador, confirma pelo teclado e recebe feedback imediato; o sistema avança, atualiza o roster e recalcula a lista. | INPUT-001–007; DRAFT-002–005; ROSTER-001–006; REC-001–007,009–010 |
| J-04 | Corrigir e recuperar | Ao registrar um jogador errado, o manager usa undo visível ou corrige um pick anterior; a sessão recompõe board, rosters e recomendação. Após refresh/reabertura, o usuário seleciona ou restaura a sessão correta, sem perder picks confirmados. | DRAFT-006–009; PERSIST-001–004; NFR-REL-001–003 |
| J-05 | Encerrar e revisar | Com todos os slots preenchidos, o draft encerra normalmente; em caso excepcional, o manager pode encerrá-lo incompleto com aviso. Ele exporta picks, rosters, configuração e metadados para consulta posterior. | DRAFT-010–011; PERSIST-005–007 |

## 5. Requisitos funcionais e alocação por versão

**Legenda:** V1 = compromisso do Operational MVP; V2/V3 = planejado, mas não promessa do MVP; Posterior = fora do roadmap atual ou depende de decisão; `*` = V1 com corte/decisão provisória explicitados abaixo.

### Dados, liga e ordem

| Requisito | Alocação | Definição de produto / corte |
|---|---|---|
| DATA-001 Importar snapshot | V1* | Importar snapshot local canônico; CSV compatível é contingência. A geração/scraping não é uma promessa de V1. |
| DATA-002 Metadados do snapshot | V1 | Exibir e conservar temporada, geração, fontes, método, scoring e identidade do conteúdo. |
| DATA-003 Validar jogadores | V1 | Detectar identificadores/posição/projeção ausentes, ambiguidades/duplicatas, ADP inválido e cobertura anômala. |
| DATA-004 Qualidade do snapshot | V1 | Mostrar cobertura e avisos antes de iniciar. |
| DATA-005 Imutabilidade ativa | V1 | Bloquear troca do snapshot de uma sessão iniciada. |
| LEAGUE-001 Times e rounds | V1 | Configurar dentro de limites suportados e validados. |
| LEAGUE-002 Slots e reservas | V1 | Configurar slots titulares e banco dentro da regra suportada. |
| LEAGUE-003 FLEX | V1 | Configurar elegibilidade de FLEX; V1 suporta o caso RB/WR de referência. |
| LEAGUE-004 Scoring | V2 | V1 usa Full PPR de referência; suportar customização geral requer contrato de cálculo fechado. |
| LEAGUE-005 Time do usuário | V1 | Exatamente um time do usuário por sessão. |
| LEAGUE-006 Salvar/reutilizar configuração | V2 | V1 preserva a configuração da sessão/exportação, mas não promete biblioteca de presets. |
| LEAGUE-007 Viabilidade do roster | V1 | Impedir início quando rounds/slots são incompatíveis. |
| ORDER-001–006 Times, ordem e snake | V1 | Cadastrar, sortear ou reordenar antes do início; gerar e exibir todos os slots; bloquear alterações normais depois do início. |

### Ciclo, entrada e roster

| Requisito | Alocação | Definição de produto / corte |
|---|---|---|
| DRAFT-001–005 Iniciar e registrar | V1 | Iniciar somente sessão pronta; registrar no slot atual, rejeitar duplicata, atribuir ao time correto e avançar. |
| DRAFT-006 Undo | V1 | Desfazer o último pick efetivo, restaurando o estado anterior. |
| DRAFT-007 Correção | V1 | Corrigir pick anterior com recomposição determinística dos efeitos posteriores; regras de substituição/remoção precisam ser detalhadas em aceite. |
| DRAFT-008 Pausar/retomar | V1 | Pausa impede novos picks normais; retomada reabre a mesma sessão. |
| DRAFT-009 Restaurar | V1 | Recuperar sessão selecionada após reinício; escolha de identidade/selector é OQ-02. |
| DRAFT-010–011 Finalizar/abortar | V1 | Finalizar quando completo; permitir encerramento administrativo incompleto com aviso persistente. |
| INPUT-001–007 Busca e feedback | V1 | Busca incremental e tolerante a variações simples; mostra posição/time, esconde escolhidos, aceita teclado, confirma resultado e mantém undo visível. |
| ROSTER-001–005 Roster, lineup e marginal | V1 | Construir rosters; atribuir melhor lineup conforme elegibilidade; diferenciar titular, upgrade, FLEX, banco e redundância. |
| ROSTER-006 Completar obrigatórios | V1 | Alertar/aplicar restrição quando escolhas restantes não permitem completar slots obrigatórios. |

### Recomendações, persistência e exportação

| Requisito | Alocação | Definição de produto / corte |
|---|---|---|
| REC-001–007 Ranking, explicação e roster | V1 | Recalcular ranking após pick; mostrar no mínimo top 5, score, componentes, explicação curta e determinística, tier cliffs e efeito do roster. |
| REC-008 Próximo pick do usuário | V2 | V1 exibe o próximo pick, mas não estima custo de esperar; incorporar essa informação ao score exige o modelo de mercado V2. |
| REC-009 K/DST cedo | V1 | Política padrão desprioriza K/DST cedo, com comportamento consultável. |
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
| EXPL-001–004 Explicabilidade | V1 | Nenhuma recomendação é só número; quando existirem, mostra ≥3 fatores, políticas/pesos consultáveis e separa projeção, valor, preço e urgência. |
| REP-001 Seed de simulação | V3 | Simulações repetíveis com seed registrada. |
| REP-002 Vínculo de recomendação | V1 | Cada recomendação é associável ao snapshot, configuração e estado que a produziram. |
| REP-003 Reabrir/reproduzir export | V1* | V1 recupera sessão local e exporta dados suficientes para auditoria; reimportação completa de pacote portátil é V2. |
| UX-001–004 Fluxo rápido e acessível | V1 | Keyboard-first, sem confirmação rotineira por modal, status não apenas por cor e informação crítica visível na tela live. |

### Base de medição V1 (a fechar antes do aceite)

Todos os percentis serão medidos no mesmo benchmark: snapshot de 400 jogadores, liga de 12 times e 14 rounds (168 picks), fixture determinística, execução local em máquina de referência definida no plano de qualidade. O método, ferramenta e especificação da máquina são **OQ-03**. Sem isso, os limites de performance não têm aceite repetível.

## 7. Critérios de aceite mensuráveis do release V1

| ID | Cenário de aceite |
|---|---|
| AC-V1-01 | **Dado** um snapshot válido, **quando** o manager conclui J-02, **então** cada time possui um slot por round, os overall picks são contínuos e a ordem só pode ser alterada por ação administrativa explícita após o início. |
| AC-V1-02 | **Dado** draft pronto e jogador disponível, **quando** o manager confirma o nome no pick atual, **então** o jogador aparece uma única vez no time do slot, deixa a lista de disponíveis, o board avança e a recomendação é atualizada. |
| AC-V1-03 | **Dado** um jogador já escolhido ou um nome ambíguo/inválido, **quando** o manager tenta confirmá-lo, **então** o pick não muda e a interface mostra motivo claro e ação de recuperação. |
| AC-V1-04 | **Dado** qualquer sequência válida de picks, **quando** o manager desfaz o último ou corrige um pick anterior, **então** board, rosters, disponíveis e recomendações correspondem ao estado recomposto e a trilha mostra a alteração. |
| AC-V1-05 | **Dado** uma sessão com 80 picks confirmados, **quando** a aplicação é reiniciada/atualizada, **então** o manager restaura a sessão correta sem perda ou duplicação, inclusive em um drill de recuperação automatizado. |
| AC-V1-06 | **Dado** um pick do usuário, **quando** a lista é renderizada, **então** há ao menos cinco candidatos disponíveis e cada um tem score, explicação determinística e fatores suficientes para distinguir valor, preço de mercado e ajuste de roster; tier cliff aparece quando aplicável. |
| AC-V1-07 | **Dado** o benchmark V1, **quando** são executados 168 picks e 100 buscas, **então** PERF-001 a PERF-005 atendem seus limites p95 e não há acesso à rede no fluxo live. |
| AC-V1-08 | **Dado** draft completo de 168 picks, **quando** o último slot é preenchido, **então** a sessão encerra, nenhum jogador/pick é duplicado e picks, rosters, configuração e metadados podem ser exportados. |
| AC-V1-09 | **Dado** pelo menos 5 participantes do público-alvo em roteiro assistido, **quando** cada um realiza J-02 a J-05, **então** pelo menos 4 concluem o fluxo sem editar código e pelo menos 4 explicam corretamente o motivo principal da recomendação top 1. Meta provisória; validar em OQ-04. |

## 8. Métricas de sucesso e contramétricas

| ID | Métrica V1 | Meta/decisão | Fonte e janela | Contramétrica |
|---|---|---|---|---|
| SM-01 | Integridade do draft: perdas/duplicidades | 0 em 100% dos drills de 168 picks antes de liberar V1 | testes de integração e recovery drill | taxa de falha técnica; não mascarar falha removendo validações |
| SM-02 | Recuperação | 100% de restauração consistente nos drills definidos | teste de restart no pick 80 e no fim | tempo de recuperação e necessidade de intervenção manual |
| SM-03 | Tempo humano por pick | mediana < 3 s em ensaios com usuários | roteiro de uso V1 | taxa de undo/correção; rapidez não pode aumentar erro |
| SM-04 | Compreensão da recomendação | ≥80% dos participantes explicam o principal motivo do top 1 | pelo menos 5 testes assistidos | confiança indevida; coletar relato de discordância/ambiguidade |
| SM-05 | Conclusão autônoma | ≥80% concluem setup, draft curto, correção e exportação sem editar código | pelo menos 5 testes assistidos | tempo até conclusão e pedidos de ajuda |
| SM-06 | Latência do caminho crítico | cumprir PERF-001 a PERF-005 em benchmark | relatório do benchmark a cada release candidato | consumo de recursos e regressões na recuperação |

**Métricas postergadas:** presença da escolha humana no top 5, calibração de disponibilidade, estabilidade/calibração de pesos e desempenho comparativo de estratégias só serão avaliáveis quando V2/V3 introduzirem os respectivos modelos e histórico (REC-012, PNext/VONA, simulação/backtesting).

## 9. Perguntas abertas e premissas

| ID | Decisão provisória | Dono | Risco se ficar aberta | Gatilho para decidir/revisar |
|---|---|---|---|---|
| OQ-01 | V1 importa localmente snapshot canônico/CSV; não executa nem distribui scraper. | Produto + Dados | onboarding, licenças e suporte imprevisíveis | antes da UX de Data Snapshot e da primeira história de importação |
| OQ-02 | Ao reabrir, a aplicação oferece seletor de sessões locais e uma sessão é identificada de forma estável; corrupção gera aviso e não sobrescreve dados. | Produto + UX | restauração ambígua ou perda percebida | antes de detalhar DRAFT-009/REL-001 |
| OQ-03 | Benchmark usa fixture fixa, 400 jogadores, 168 picks e máquina/ferramenta documentadas. | Engenharia | metas p95 não verificáveis | antes do primeiro gate de performance |
| OQ-04 | Critérios de usabilidade acima são metas iniciais para n≥5, não validação estatística. | Produto + UX | confundir sinal inicial com prova de mercado | após o primeiro ensaio de usabilidade |
| OQ-05 | Full PPR e o roster de referência são a única combinação garantida em V1; variabilidade de liga só é exposta se passar testes de viabilidade. | Produto | promessa de customização maior que a cobertura real | antes de desenhar League Setup |
| OQ-06 | Pesos de recomendação, ranks de replacement, thresholds de tier e políticas de roster são defaults versionados, não verdades de produto. | Produto + Dados | defaults arbitrários viram comportamento permanente | antes do aceite de REC-001–007 e após os primeiros ensaios |
| OQ-07 | "Correção de pick anterior" recompõe o estado e só é permitida quando o resultado não viola integridade; UX de conflitos/remoções precisa de regra explícita. | Produto + UX | surpresa e perda de confiança no live draft | antes de implementar DRAFT-007 |
| OQ-08 | A V1 não promete ingerir notícias/lesões durante o draft; novo snapshot só pode ser escolhido antes de iniciar. | Produto | expectativa de dado em tempo real incompatível com offline | antes de materiais de lançamento |
| OQ-09 | A política de privacidade/retenção e as fontes de dados permitidas serão documentadas antes de distribuir snapshots de exemplo ou produto. | Produto + Legal/Dados | uso/licença indevidos | antes de qualquer distribuição externa |

## 10. Material deliberadamente mantido em documentos companions

Esta reconciliação não incorpora detalhes de solução. Eles continuam valiosos, mas devem ser mantidos e referenciados por artefatos companions:

- **Arquitetura e qualidade:** separação de camadas, escolhas de runtime/persistência, reatividade, cache, observabilidade, migrations, estrutura de repositório, CI e estratégia de testes.
- **Domínio e dados:** schema de entidades, contrato tabular detalhado do snapshot, identidade canônica de jogador, máquina de estados, invariantes, hashes e regras de integridade.
- **Analítica:** fórmulas de VOR, tiers, tier cliffs, probabilidade de disponibilidade, VONA, pesos do score, shortlist, políticas e métodos de otimização de lineup.
- **Roadmap de engenharia:** marcos, estimativas, issues, prompts de agentes, ADRs e sequência concreta de implementação.

Esses documentos devem preservar links para os IDs deste PRD; escolhas técnicas futuras não devem modificar escopo, jornada ou critérios de aceite sem uma decisão de produto registrada.
