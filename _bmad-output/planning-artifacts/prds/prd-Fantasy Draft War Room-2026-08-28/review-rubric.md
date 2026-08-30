# PRD Quality Review — Fantasy Draft War Room

## Overall verdict

O documento é uma especificação técnica excepcionalmente concreta para iniciar o MVP: a restrição operacional central (draft rápido e offline) sustenta a arquitetura, as metas de desempenho, os invariantes e o roadmap. Contudo, ainda é um documento híbrido de produto, arquitetura e plano de implementação — não um PRD pronto para alimentar UX e histórias sem interpretação adicional. A aprovação para iniciar o núcleo V1 é defensável; antes de comprometer a experiência completa ou planejar o backlog, é preciso fechar o contrato de preparação de dados, tornar os critérios funcionais testáveis e separar/traçar o escopo V1.

## Decision-readiness — adequate

As decisões que protegem o momento crítico estão explícitas e coerentes: o snapshot imutável, a operação offline, o núcleo independente de Shiny e a separação entre recomendação rápida e simulação aparecem como princípios em §2.4, são traduzidos em NFRs em §§5.1–5.5 e voltam como ADRs em §28. O roadmap também toma uma posição clara ao adiar scraper e Monte Carlo até que o fluxo vertical esteja comprovado (§24 e §32), em vez de tratar tudo como prioritário.

Ainda faltam decisões de produto que alteram quem consegue usar a V1 e como o lançamento será avaliado. O texto nomeia riscos, mas não registra perguntas abertas, responsáveis, premissas ou condições para decidir; assim, itens como geração/importação de snapshot e o padrão de qualidade aceitável ficam implícitos na implementação.

### Findings

- **high** Contrato de preparação de dados não decidido para V1 (§§3.2, 12.2–12.3, 17.2, 23.2) — O documento diz que a V1 constrói/valida snapshots, oferece “ação para gerar ou importar novo snapshot” e inclui um adaptador, mas não decide se o operador final prepara dados sozinho, importa um CSV, ou recebe um snapshot produzido por um fluxo de desenvolvedor. Essa decisão muda onboarding, UI, suporte e Definition of Done. *Fix:* registrar uma decisão V1 com fluxo suportado, formato/validação de entrada, responsável e comportamento quando a atualização falha; deixar as alternativas explicitamente fora de escopo ou em V2.

- **medium** Métricas sem alvo de decisão ou contramétrica (§30) — “frequência em que recomendação top 5 contém a escolha humana” e “valor de roster titular projetado” são sinais interessantes, mas não têm baseline, janela, alvo, dono, instrumentação nem uma contramétrica de confiança/tempo de operação. *Fix:* para cada métrica de V1, definir baseline, meta, fonte de coleta e contramétrica (por exemplo, taxa de correção/undo e tempo humano por pick); declarar quais métricas analíticas só entram quando V2/V3 existirem.

## Substance over theater — strong

O conteúdo é específico ao problema: “o draft é rápido” leva a limites mensuráveis (§5.1), ao caminho crítico de um pick (§18.3), à separação de contextos (§6.1) e aos riscos de latência/erro humano (§29.5 e §29.7). Não há personas decorativas, alegações vagas de inovação, nem NFRs genéricos copiados; os princípios em §2.4 têm consequências concretas nas regras, contratos e testes.

O volume técnico é alto, mas em geral é justificável pela natureza de uma ferramenta de operação em tempo real. O problema é de forma e rastreabilidade downstream, tratado em “Shape fit” e “Downstream usability”, não de conteúdo-fachada.

## Strategic coherence — adequate

A tese está nítida: transformar projeções estáticas em decisão contextual, preservando velocidade, explicabilidade e recuperação durante o draft (§§2.1–2.4). O corte V1 segue a tese de forma disciplinada — draft confiável e FastScore primeiro; disponibilidade probabilística e simulação depois (§§23.2–23.3, §24 e §32). Isso evita que o roadmap vire apenas uma lista de algoritmos desejáveis.

O risco estratégico remanescente é a falta de uma cadeia explícita entre essa tese, os resultados a provar no MVP e os requisitos entregues. Os critérios de aceite medem segurança e latência, mas não estabelecem a menor evidência de que as recomendações são úteis, compreensíveis ou calibradas o suficiente para o caso de uso inicial.

### Findings

- **medium** Hipótese de valor do MVP não é verificável (§§2.2, 23.5, 30, 31) — A proposta promete responder “quais são as melhores decisões agora, qual é a urgência ... e por quê”, mas os critérios V1 só verificam que uma recomendação aparece e é rápida. Não existe teste de compreensão, utilidade percebida ou qualidade mínima das explicações. *Fix:* acrescentar uma hipótese V1 mensurável, como um roteiro de draft com usuário-teste que mede entendimento da justificativa e capacidade de concluir/corrigir picks; declarar que a qualidade preditiva comparativa é objetivo de V2/V3.

- **medium** Priorização V1 não referencia os requisitos (§§4.1–4.8, 23.2–23.5, 27) — O escopo e as issues usam nomes de capacidades, enquanto os FRs têm IDs globais; não há mapeamento que diga quais dos 62 FRs são V1, V2 ou V3. Isso permite que requisitos como comparação lado a lado (FR-REC-011) ou backup portátil (FR-PERSIST-008) sejam interpretados de forma inconsistente. *Fix:* adicionar uma matriz curta “versão → FR/NFR → critério de aceite”, com cada requisito atribuído a uma versão ou marcado como postergado.

## Done-ness clarity — thin

Há boa base para verificação: as regras de snake têm invariantes (§8.3), o estado possui uma máquina explícita (§10), as regras de domínio são funções testáveis (§11), e os testes cobrem invariantes, integração e desempenho (§22). As metas de p95 dos NFRs também dão limites relevantes ao caminho crítico (§5.1).

Mas a maioria dos FRs é apenas um título (“Configurar regras de scoring”, “Registrar pick atual”, “Permitir comparar candidatos”) sem consequência observável, exceção, autorização de estado ou dados de saída. O conjunto de critérios de aceite em §23.5/§31 é do produto V1 como um todo, não substitui critérios por capacidade. Alguns NFRs ainda contêm qualificadores não mensuráveis, o que impede testes estáveis e aceitação repetível.

### Findings

- **high** Requisitos funcionais sem critérios de aceitação por capacidade (§§4.2–4.8) — Por exemplo, FR-LEAGUE-004 não define quais regras de scoring são suportadas; FR-DRAFT-007 não define como uma correção anterior revalida/reproduz picks posteriores; e FR-REC-011 não define campos, limites ou estado de comparação. Uma história pode “implementar” cada título com comportamentos incompatíveis. *Fix:* para cada FR V1, acrescentar 1–3 cenários Given/When/Then ou consequências verificáveis, incluindo pré-condições, transições inválidas e resultado persistido.

- **medium** Limites não testáveis em requisitos não funcionais (§§5.1, 5.3, 5.6, 22.6) — “hardware desktop comum”, “perceptualmente instantânea”, “sempre que possível”, “cobertura adequada” e “baseline tolerado” não têm ambiente, método ou limiar. *Fix:* fixar o perfil de benchmark, tamanho/fixture e ferramenta de medição; substituir cada qualificativo por uma regra ou por um item explicitamente sujeito a revisão humana.

- **medium** Recuperação de sessão não especifica a identidade/seleção da sessão (§§4.4, 5.2, 19.1–19.4) — FR-DRAFT-009 e NFR-REL-001 exigem restaurar após reinicialização, mas não dizem como o app escolhe a sessão correta, como lida com múltiplas sessões locais, ou como avisa sobre banco/snapshot indisponível. *Fix:* definir a chave de restauração, o seletor de sessão, o comportamento para corrupção/conflito e os cenários de aceitação de recovery drill.

## Scope honesty — thin

O documento é honesto sobre grandes exclusões: integrações com plataformas, leilão, multiusuário, mobile e notícias em tempo real estão claramente fora do escopo (§3.3); V1 também exclui PNext, VONA, adaptação e Monte Carlo (§23.3). Os riscos conhecidos são nomeados com mitigação (§29), o que reduz omissões silenciosas.

Entretanto, não há seção de perguntas abertas, nem marcações `[ASSUMPTION]`, `[NOTE FOR PM]` ou `[NON-GOAL]`. Para uma cadeia que seguirá a UX, arquitetura e histórias, a ausência de um registro de incertezas mistura escolhas estabelecidas (SQLite, draft snake) com hipóteses que ainda precisam de validação (pesos, fonte de dados, método de operação e qualidade da recomendação).

### Findings

- **high** Decisões postergadas não estão registradas como abertas (§§13.1–13.7, 15.3–15.6, 29.1–29.4) — Os ranks de replacement, os pesos do score e políticas de composição são descritos como “configuração inicial sugerida” ou “hipótese inicial”, mas não há dono, critério de calibração nem gatilho para revisar. Isso pode transformar defaults provisórios em regra de produto por acidente. *Fix:* criar uma seção “Open questions and assumptions” com ID, owner, decisão provisória, risco e condição/data de reavaliação; indexar todos os `[ASSUMPTION]` inline.

- **medium** Limite de responsabilidade de dados/licenças está implícito (§§6.1, 8.1, 12.1–12.2, 29.1) — Scraping via `ffanalytics`, fontes, cache e CSV manual são previstos, mas não se decide quais fontes a V1 pode distribuir, armazenar ou apenas importar localmente. *Fix:* declarar a política V1 de fontes/dados (somente usuário importa vs. pipeline mantido pelo produto), retenção e aviso de falha/licenciamento; deixar integrações de fonte não aprovadas como non-goal.

## Downstream usability — thin

Os IDs de FR e NFR são únicos e contínuos dentro de cada grupo (§§4–5), e as funções/invariantes dão bons pontos de partida para arquitetura e testes (§§8–11 e §22). O documento também descreve um fluxo vertical que uma equipe pode usar para fatiar a implementação (§24).

Mesmo assim, faltam os artefatos que permitem extração confiável sem reler 2.421 linhas: não há glossário, journeys com protagonista nomeado, IDs de métricas de sucesso ou ligações requisito→milestone→teste. Conceitos similares usam identificadores distintos — por exemplo, `content_hash`, `snapshot_hash`, `league_config_hash`/`config_hash` e `draft_state_hash`/`state_hash` (§§9.2, 9.4, 18.6) — sem definição de equivalência.

### Findings

- **high** Não há journeys operacionais nem rastreabilidade entre FR, release e aceite (§§4, 17, 23–24, 31) — Para UX e criação de histórias, “Live War Room” é uma lista de telas/controles, não uma narrativa de sessão com o operador, exceções e resultado. Também não é possível extrair automaticamente quais FRs sustentam cada marco ou critério V1. *Fix:* adicionar 3–5 jornadas nomeadas do operador (preparar snapshot, configurar/retomar, registrar/corrigir pick, encerrar/exportar), e uma tabela que ligue cada uma a FR/NFR, release e critérios de aceite.

- **medium** Glossário e contrato de nomenclatura ausentes (§§8–9, 12, 14–15, 18.6) — Termos de domínio relevantes (snapshot, disponibilidade, VOR, tier cliff, FastScore, state hash, “urgência”) estão explicados em vários pontos, mas não como uma fonte canônica. A diferença entre hashes pode gerar schemas e caches incompatíveis. *Fix:* adicionar um glossário curto e declarar campos canônicos; padronizar `snapshot_content_hash`/`league_config_hash`/`draft_state_hash` ou documentar precisamente quando cada alias é usado.

## Shape fit — thin

Para uma ferramenta de operador único que também servirá de base para construção, o nível de detalhe técnico, o roadmap incremental e os contratos de domínio são úteis. O documento não precisa de uma seção extensa de personas; o “fantasy manager” e a interface desktop (§§2.3 e §17) são uma forma apropriada de escopo inicial.

O arquivo, porém, combina PRD, arquitetura, modelo de dados, fórmulas, estrutura de repositório, guia de agentes e backlog de issues (§§6–29). Essa forma torna o documento uma ótima especificação de solução, mas dilui a leitura de decisão de produto e convida UX/epics a confundir escolhas de implementação com requisitos. Como o próprio roadmap prevê handoffs para outras disciplinas (§25), a forma deve separar o núcleo de produto do detalhamento que o acompanha.

### Findings

- **high** O PRD contém detalhes de solução que deveriam ser artefatos companions (§§6–22, 25–28) — Camadas, SQLite, schemas, assinaturas R, fórmulas, árvore de arquivos e prompt para agentes são úteis, mas não são requisitos de produto; eles obscurecem visão, escopo, jornadas e resultados. *Fix:* manter um PRD conciso com visão, escopo V1, journeys, FR/NFR, métricas e decisões abertas; mover arquitetura/modelo/fórmulas para `ARCHITECTURE.md` e `DOMAIN.md`, e issues/guia de agentes para roadmap/contexto do repositório, preservando links bidirecionais.

## Mechanical notes

- Não há Glossário. Isso impede uma verificação formal de sinônimos e deixa a deriva de hashes citada acima sem resolução.
- Os IDs de FR (DATA 001–005, LEAGUE 001–007, ORDER 001–006, DRAFT 001–011, INPUT 001–007, ROSTER 001–006, REC 001–012 e PERSIST 001–008) e NFR (PERF 001–007, REL 001–005, MAINT 001–005, EXPL 001–004, REP 001–003 e UX 001–004) são contínuos e não aparentam duplicação.
- Não existem IDs de jornadas de usuário ou métricas de sucesso; por isso não há cross-references formais entre requisitos, métricas, releases e testes.
- Não há tags inline `[ASSUMPTION]`, `[NOTE FOR PM]` ou `[NON-GOAL]`, nem índice de premissas. As exclusões em §3.3 e §23.3 estão em prosa/listas, mas não permitem roundtrip de decisões pendentes.
- A hierarquia de títulos quebra em §23: “Versão 1”, “Versão 2” e “Versão 3” usam `#` em vez de `##`, embora estejam dentro do capítulo 23. Isso afeta sumários e extração automática.
