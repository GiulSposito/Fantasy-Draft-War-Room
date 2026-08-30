# Revisão de acessibilidade — Fantasy Draft War Room

## Veredito

**Adequado como intenção, ainda incompleto como contrato de implementação.** Os spines assumem WCAG 2.2 AA, teclado primeiro, foco visível, alternativas a atalhos e mensagens de erro acionáveis. Porém faltam as regras semânticas e de foco que tornam autocomplete, board, atalhos globais e atualizações live utilizáveis por teclado e leitor de tela.

## Achados

- **[high] Atalhos podem disparar enquanto o operador digita.** (`EXPERIENCE.md`, *Interaction Primitives*, 1º item.) `U`, `Espaço`, setas e `Esc` são definidos sem escopo de foco. Em um campo de busca, `U` pode desfazer um pick e `Espaço` pode abrir inspeção em vez de inserir caracteres. *Correção:* declarar que atalhos de comando só funcionam fora de `input`, `textarea` e controles editáveis; dentro da busca, reservar setas/Enter para o combobox e deixar `Esc` limpar/fechar apenas a busca. Oferecer controles focáveis equivalentes para Undo e inspeção.

- **[high] O autocomplete não tem contrato semântico de combobox.** (`DESIGN.md`, *Components > Campo de busca + autocomplete*; `EXPERIENCE.md`, *Component Patterns > Campo de busca + autocomplete* e *Accessibility Floor*, 2º item.) Anunciar o conteúdo de cada candidato não define relação entre input, lista, opção ativa e resultado selecionado. *Correção:* exigir padrão ARIA combobox/listbox: `label` persistente, `aria-expanded`, `aria-controls`, `aria-activedescendant`, opções com `role=option`/estado selecionado e anúncio conciso de contagem, sem resultado e disponibilidade. O texto de cada opção deve ser o nome acessível completo, não apenas colunas visuais.

- **[high] Board e correção não têm caminho de teclado especificado.** (`EXPERIENCE.md`, *Information Architecture > Board e auditoria*; *Component Patterns > Board*; *Interaction Primitives*.) O contrato diz que um pick corrigível abre correção, mas só atribui setas à lista de candidatos. Tabular até 180 picks é impraticável e o foco ao abrir/fechar a correção não é definido. *Correção:* definir navegação de grid por setas (com roving tabindex), `Enter`/`Espaço` para abrir a correção, nome acessível que inclua overall/time/jogador/estado, foco inicial no painel de correção e retorno ao mesmo pick após cancelar, falhar ou concluir.

- **[medium] Atualizações live não definem uma única estratégia de anúncio nem a gestão do foco.** (`EXPERIENCE.md`, *State Patterns > Pick confirmado, Intenção obsoleta, Undo multinível, Correção válida*; *Accessibility Floor*, 3º item.) Há intenção de anunciar registro e novo pick, mas não região live, prioridade, atomicidade ou destino do foco. A atualização de board, roster, recomendações e status pode produzir leitura repetitiva ou silenciosa. *Correção:* requerer uma região de status `aria-live=polite` e `aria-atomic=true` para comandos aceitos; erros/bloqueios urgentes usam mensagem de alerta sem roubar foco. Após registrar/undo/corrigir, manter ou devolver foco explicitamente para busca/lista, e anunciar uma frase curta com jogador, overall atual e disponibilidade do undo.

- **[medium] Reflow/zoom em janela estreita está descrito como intenção, não como comportamento verificável.** (`DESIGN.md`, *Layout & Spacing*; `EXPERIENCE.md`, *Information Architecture*, parágrafo após tabela; *Responsive & Platform*; *Accessibility Floor*, último item.) “Abas/expansores” e “respeitar zoom” não dizem como evitar perda de conteúdo/foco ou rolagem bidimensional quando a janela divide o notebook com a ESPN. *Correção:* fixar o comportamento em zoom 200%/largura reduzida: cabeçalho, busca e lista permanecem na leitura linear; board/roster/auditoria tornam-se painéis alternáveis com rótulos e estado expandido; a troca preserva/restaura foco e não oculta o controle focado. Permitir rolagem horizontal somente na grade de board, com cabeçalhos/posição atual ainda identificáveis.

- **[medium] Contraste AA não é demonstrado para combinações operacionais.** (`DESIGN.md`, frontmatter `colors` e *Colors*.) Os tokens hex existem e a intenção declara “alto contraste”, mas não há pares/ratios normativos para texto comum, foco, erro, warning, linha ativa e estados desabilitados. Implementadores podem usar `{colors.ink-muted}`, `{colors.warning}` ou `{colors.border}` em uma superfície incompatível. *Correção:* acrescentar uma pequena tabela de pares permitidos e mínimo 4.5:1 para texto normal, 3:1 para indicador de foco/borda de componente e distinção não cromática obrigatória para cada estado; validar também foco sobre `{colors.surface-raised}`.

- **[medium] Estados de indisponibilidade e carregamento não têm semântica nem recuperação de foco suficientes.** (`EXPERIENCE.md`, *State Patterns > Carregando sessões, Registrando, Pausado, Falha local de persistência*.) Skeleton, bloqueio da repetição e pausa são visualmente descritos, sem informar `aria-busy`, quais controles ficam desabilitados, seus nomes/razões, nem onde fica o foco se o controle acionado desaparece no término do draft. *Correção:* declarar `aria-busy` nas regiões que carregam, usar `disabled`/`aria-disabled` apenas com motivo acessível, manter o controle acionado focado durante espera e mover foco para o cabeçalho/ação Exportar quando o registro normal some após conclusão.

- **[low] Controles alternativos a atalhos carecem de requisitos de tamanho e foco não obscurecido.** (`EXPERIENCE.md`, *Accessibility Floor*, 5º item; `DESIGN.md`, *Layout & Spacing* e *Components*.) O app é keyboard-first, mas clique é alternativa; o cabeçalho fixo, popovers e painéis podem ocultar o anel de foco. *Correção:* exigir alvo de pelo menos 24×24 CSS px ou espaçamento equivalente para controles clicáveis, foco com contraste mínimo 3:1 e rolagem automática que mantenha o elemento focado totalmente visível, inclusive sob a faixa fixa e em popovers.

## Pontos fortes verificados

- Teclado, Tab, foco visível, alternativa por controle e `Esc` em camada superior estão explicitamente assumidos.
- Estados não dependem somente de cor; o Design reserva texto/ícone para pausa, alertas e conclusão.
- Falhas preservam o estado confirmado e informam causa; Undo multinível mantém auditoria.
- Movimento reduzido e uso sem mouse estão no piso de acessibilidade.

## Verificação recomendada

Após incorporar os itens acima, validar com teclado apenas, zoom de navegador a 200%, modo de alto contraste quando disponível e um leitor de tela (VoiceOver no macOS) nos fluxos de busca/registro, undo sequencial, correção antiga, erro e conclusão.
