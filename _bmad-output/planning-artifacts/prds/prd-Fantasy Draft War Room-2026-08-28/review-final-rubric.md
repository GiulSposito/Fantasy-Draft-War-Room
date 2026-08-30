# PRD Quality Review — Fantasy Draft War Room

## Overall verdict

**Good — pronto para arquitetura e decomposição em histórias, com duas lacunas delimitáveis antes de transformar a configuração e a validação em histórias finais.** O PRD tem uma tese operacional nítida, decisões V1 registradas, limites de escopo honestos e critérios de release que exercitam o caminho que importa: registrar, explicar, corrigir, recuperar e exportar um draft local. O risco remanescente não é de direção de produto, mas de contrato: ainda falta fechar o envelope suportado de configuração e tornar inequívoco onde o contrato canônico de snapshot/configuração é consumido.

## Decision-readiness — strong

As decisões que podiam deslocar o MVP estão explícitas no escopo e nas jornadas: preparação local por `script.R`, operação sem rede, configuração versionada, recuperação por seleção de sessão e correção determinística estão materializadas em §3–§5. As exclusões de modelos de mercado, integrações, notícias ao vivo e distribuição de dados em §3 tornam claro o que foi deliberadamente sacrificado para preservar o caminho crítico.

Não há perguntas retóricas nem escolhas fundamentais escondidas como preferências. O benchmark Intel em §6 é corretamente descrito como referência de medição, e não como promessa de compatibilidade.

## Substance over theater — strong

A persona única em §1 tem função operacional concreta (notebook/desktop, draft externo, registro rápido e recuperação); não há personas decorativas. A proposta de valor e a hipótese em §1–§2 são específicas à decisão situada de um draft snake, e não uma visão intercambiável de “dashboard de fantasy”.

Os NFRs de §6 evitam boilerplate: p95, inicialização, ausência de rede, integridade e recuperação estão vinculados a limites e a um benchmark. Métricas e contramétricas em §8 medem o benefício alegado sem confundir velocidade com menor erro ou explicabilidade com confiança indevida.

## Strategic coherence — strong

A tese é coerente: transformar um snapshot imutável em uma recomendação explicável e veloz durante um draft local. O corte V1 privilegia o fluxo operacional e adia explicitamente os mecanismos que alegariam melhor qualidade preditiva (probabilidade de disponibilidade, Monte Carlo, mocks e backtesting), em vez de apresentá-los como capacidade incompleta do MVP (§2–§3).

As métricas de integridade, recuperação, tempo por pick, compreensão e conclusão autônoma (§8) verificam a hipótese do MVP; as contramétricas explicitam os efeitos indesejados relevantes.

## Done-ness clarity — adequate

Os critérios AC-V1-01–09 em §7 tornam o fluxo principal verificável, inclusive duplicidade, correção antiga, recuperação com 80 picks, p95 e operação offline. O comportamento de erro de correção em J-04 e DRAFT-007 também é preciso o suficiente para orientar testes de integração.

O contrato de aceite de usabilidade, porém, não define um roteiro único. §2 fala em “ensaio de draft completo”; AC-V1-09 manda executar J-02 a J-05; já SM-05 mede um “draft curto”. Esses três recortes podem produzir resultados de esforço, erro e conclusão materialmente diferentes.

### Findings

- **medium** Roteiro de validação de usabilidade inconsistente (§2, AC-V1-09 e SM-05) — O release não tem uma definição única de sessão avaliada: draft completo, fluxo J-02–J-05 ou draft curto. Assim, “4 de 5 concluem” pode ser aprovado em um exercício que não prova o resultado declarado para o MVP. *Fix:* definir um único roteiro de teste (por exemplo, setup + N picks representativos + correção + restart + exportação), declarar se ele substitui ou complementa um draft completo, e referenciá-lo de AC-V1-09 e SM-03–05.

## Scope honesty — adequate

§3 distingue claramente o compromisso V1 das capacidades posteriores e não sugere que snapshots locais, explicabilidade simples ou políticas configuráveis equivalham a previsão de mercado. As decisões sobre scoring, recuperação, correção, benchmark, configuração e notícias ao vivo aparecem tanto no PRD quanto em `decisions.md`/`.memlog.md`; não restam perguntas abertas que escondam um bloqueio de produto.

O termo “configurável, sujeito à validação de viabilidade” em LEAGUE-001–003 e LEAGUE-007 delimita uma intenção, mas não o conjunto suportado. Sem uma fronteira, uma configuração de referência pode ser interpretada como exemplo, mínimo garantido ou apenas uma entre quaisquer estruturas de roster.

### Findings

- **medium** Envelope de configuração V1 ainda não é finito (§3; LEAGUE-001–003, LEAGUE-007; ROSTER-006) — Times, rounds, slots, banco e FLEX são configuráveis, mas o PRD não declara quais formas de slot/FLEX e quais faixas são suportadas, nem a regra de viabilidade além de “compatíveis”. Isso permite escopo acidental para formatos que alteram o otimizador de lineup e a prevenção de dead-end. *Fix:* declarar o envelope V1 (tipos de posição e FLEX aceitos, multiplicidade de slots/FLEX, intervalos de times/rounds e a regra de viabilidade) ou apontar para uma especificação de configuração versionada que seja parte do release.

## Downstream usability — adequate

Para um PRD chain-top, o material é majoritariamente extraível: os requisitos são estáveis por família, jornadas e critérios usam IDs, e `decisions.md` preserva as escolhas de produto. A fonte técnica está identificada no frontmatter e no cabeçalho, o que permite separar resultado de produto de fórmulas e schemas.

Há, no entanto, uma referência que não se resolve no workspace: §3 diz que o contrato de entrada/saída e falhas de `script.R` “pertencem ao companion de dados”, sem nomear ou fornecer esse companion. Esse contrato é precisamente a fronteira que une `script.R`, o YAML de scoring, o snapshot e a validação no runtime; delegá-lo sem artefato torna a criação de histórias dependente de redescoberta.

### Findings

- **medium** Companion de dados prometido, mas não localizável (§3, DATA-001–004, LEAGUE-004) — Não há caminho/artefato para o contrato canônico de snapshot e configuração citado pelo PRD. A fonte técnica contém material relacionado, mas não substitui uma referência explícita e versionada para o fluxo V1. *Fix:* criar ou nomear o companion e vinculá-lo aqui; ele deve fixar schema e versão, identidade/hashes, compatibilidade snapshot–scoring/configuração, regras de normalização, gates/limiares de qualidade e mensagens/ações para falhas.

## Shape fit — strong

Este é corretamente tratado como um capability spec de operador único, não como produto social ou multi-persona. As cinco jornadas de §4 são poucas e descrevem checkpoints operacionais que ajudam o teste sem simular uma pesquisa de UX extensa. Para o encadeamento em arquitetura e histórias, §5–§7 fornecem mais valor que aumentar a densidade de jornadas.

## Mechanical notes

- IDs de jornadas (J-01–05), aceites (AC-V1-01–09) e métricas (SM-01–06) são contínuos e as referências observadas resolvem. As famílias de requisitos são apresentadas por intervalos para compactação; o companion de dados recomendado acima deve manter IDs individuais se passar a conter contratos testáveis por requisito.
- Não há tags inline `[ASSUMPTION]` nem `[NOTE FOR PM]`; as decisões relevantes foram registradas, portanto não há índice de premissas pendente.
- Não existe glossário formal. A terminologia central está suficientemente estável para este domínio, mas um glossary enxuto de *snapshot*, *sessão*, *pick*, *board*, *roster*, *slot*, *configuração* e *recomendação* reduziria ambiguidade para UX/arquitetura.
- As jornadas usam o papel consistente “manager”, sem protagonista nominal. Para ferramenta de operador único isso não afeta a decisão de produto; se UX exigir personas, introduzir uma apenas com contexto observável.
