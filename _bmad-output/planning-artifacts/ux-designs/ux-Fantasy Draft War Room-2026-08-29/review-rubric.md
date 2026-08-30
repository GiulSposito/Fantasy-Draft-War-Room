# Spine Pair Review — Fantasy Draft War Room

## Overall verdict

**Adequado para orientar a Live War Room, mas ainda fino como contrato completo do V1.** A dupla captura bem a superfície keyboard-first de operação, registro, undo e correção; referências de tokens e o formato dos spines estão íntegros. Porém as jornadas de preparo/configuração não chegam aos Key Flows, e sessões, preparo e exportação não têm estados e componentes suficientes para uma implementação consistente.

## 1. Flow coverage — thin

Foram verificadas as jornadas J-01 a J-05 do PRD contra os quatro Key Flows. Todos os fluxos existentes têm Giu como protagonista, passos numerados, clímax e caminho de falha.

### Findings

- **[high]** J-01 (*Preparar dados*) e J-02 (*Configurar e travar draft*) não possuem Key Flow; o fluxo de J-05 só cobre a conclusão normal, sem encerramento administrativo incompleto nem a ação de exportar. (EXPERIENCE.md, *Key Flows*; PRD, §4). *Fix:* acrescentar fluxos nomeados com os termos do PRD para preparação/validação do snapshot, configuração/lock da ordem e encerramento/exportação, incluindo suas falhas acionáveis.

## 2. Token completeness — adequate

Todos os tokens YAML usados por referências `{path.to.token}` nos dois spines resolvem no frontmatter de DESIGN.md; as cores são hexadecimais e as escalas de tipografia, espaçamento, raio e componentes são legíveis para consumo.

### Findings

- **[medium]** Não há pares de contraste normativos nem metas para texto, foco, erro, warning e linha ativa nas superfícies operacionais. (DESIGN.md, frontmatter *colors* e § *Colors*). *Fix:* declarar combinações permitidas e mínimos de contraste para texto e indicadores não textuais, incluindo foco sobre `{colors.surface-raised}`.

## 3. Component coverage — thin

Os principais componentes live (faixa de estado, busca, lista inteligente, board, roster, undo, inspeção, histórico e feedback) têm descrição visual em DESIGN.md e comportamento em EXPERIENCE.md.

### Findings

- **[high]** Sessões e Preparar draft são superfícies de IA sem componentes contratuais para seleção/confirmação de sessão, resumo de qualidade, configuração de liga, ordem snake e `Validate and Lock`; a *Linha de candidato* também não tem o mesmo componente nomeado na seção visual. (EXPERIENCE.md, *Information Architecture* e *Component Patterns*; DESIGN.md, *Components*). *Fix:* nomear esses componentes de forma idêntica nos dois spines e fornecer uma regra visual e uma comportamental para cada um.

## 4. State coverage — thin

Foram percorridas as superfícies de IA. A Live War Room cobre registro, intenção obsoleta, pausa, undo, correção, conclusão e falha de persistência; busca cobre vazio e validações de entrada.

### Findings

- **[medium]** Faltam estados verificáveis para nenhuma sessão recuperável, carregamento/erro de snapshot e configuração, preparação da ordem, inspeção com campos opcionais ausentes, exportação concluída/falha e encerramento administrativo incompleto. (EXPERIENCE.md, *State Patterns*; *Information Architecture*). *Fix:* acrescentar uma linha de estado por caso, com controle disponível, destino de foco e recuperação, onde aplicável.

## 5. Visual reference coverage — strong

Não há arquivos em `mockups/`, `wireframes/` ou `imports/`; portanto não existem referências órfãs. EXPERIENCE.md afirma que os spines vencem sobre mockups futuros. Não há achados.

## 6. Bloat & overspecification — strong

Os spines são focados em decisões downstream: DESIGN.md concentra identidade e especificação visual; EXPERIENCE.md concentra comportamento em tabelas e fluxos. Não há achados.

## 7. Inheritance discipline — adequate

Os cinco caminhos em `sources` resolvem a partir dos dois spines. A terminologia central (pick, roster, board, recomendação, snapshot e correção) é consistente, e todas as referências de token resolvem.

### Findings

- **[medium]** As jornadas fonte são identificadas como J-01–J-05, mas os Key Flows usam títulos novos e deixam J-01/J-02 sem equivalente; assim um consumidor não consegue rastrear todas as jornadas do PRD pelo nome. (PRD, §4; EXPERIENCE.md, *Key Flows*). *Fix:* usar os nomes/IDs J-01–J-05 nos títulos ou acrescentar o mapeamento explícito em cada fluxo.

## 8. Shape fit — strong

DESIGN.md segue a ordem canônica e inclui todos os blocos relevantes. EXPERIENCE.md contém Foundation, Information Architecture, Voice and Tone, Component Patterns, State Patterns, Interaction Primitives, Accessibility Floor, Key Flows, Responsive & Platform e Inspiration & Anti-patterns; os dois últimos são justificados pelo contexto de notebook e pelas referências/rejeições registradas.

## Mechanical notes

- Frontmatter dos dois spines está completo para o formato adotado; os caminhos em `sources` resolvem.
- Não há Mermaid, mockups, wireframes ou imports para validar nesta rodada.
- O uso de `{components.focus-ring}` em EXPERIENCE.md resolve para um objeto de componente; consumidores que só aceitem valores escalares devem usar seus campos (`.color` e `.width`).
