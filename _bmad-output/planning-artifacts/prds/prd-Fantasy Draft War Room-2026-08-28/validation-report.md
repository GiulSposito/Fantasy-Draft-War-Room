# Relatório de validação — Fantasy Draft War Room

- **Documento avaliado:** `docs/fantasy-draft-war-room-spec.md`
- **Rubrica:** `.agents/skills/bmad-prd/assets/prd-validation-checklist.md`
- **Executado em:** 2026-08-28T20:08:02-0300
- **Avaliação:** Fair

## Veredito geral

O documento é uma especificação técnica excepcionalmente concreta para iniciar o MVP: a restrição operacional central — um draft rápido e offline — sustenta a arquitetura, as metas de desempenho, os invariantes e o roadmap. Contudo, ele ainda é um documento híbrido de produto, arquitetura e plano de implementação; não um PRD pronto para alimentar UX e histórias sem interpretação adicional.

É defensável iniciar o núcleo V1. Antes de comprometer a experiência completa ou planejar o backlog, é preciso fechar o contrato de preparação de dados, tornar os critérios funcionais verificáveis e separar ou traçar explicitamente o escopo V1.

## Vereditos por dimensão

- Decision-readiness — **adequate**
- Substance over theater — **strong**
- Strategic coherence — **adequate**
- Done-ness clarity — **thin**
- Scope honesty — **thin**
- Downstream usability — **thin**
- Shape fit — **thin**

## Achados por severidade

### Críticos (0)

Nenhum.

### Altos (5)

**[Decision-readiness] Contrato de preparação de dados V1 não decidido (§§3.2, 12.2–12.3, 17.2, 23.2).** Não está decidido se o operador prepara dados, importa CSV ou recebe snapshot de um fluxo mantido pelo produto. Isso altera onboarding, UI e suporte.  
**Correção:** registrar fluxo V1, formato e validação de entrada, responsável e comportamento em falha; postergar alternativas explicitamente.

**[Done-ness clarity] FRs sem critério de aceite por capacidade (§§4.2–4.8).** Títulos como configurar scoring, corrigir pick e comparar candidatos não definem consequências, estados inválidos ou resultado persistido.  
**Correção:** para cada FR V1, incluir 1–3 cenários Given/When/Then com pré-condições, exceções e resultado observável.

**[Scope honesty] Decisões postergadas não estão registradas como abertas (§§13.1–13.7, 15.3–15.6, 29.1–29.4).** Pesos, replacement ranks e políticas são descritos como iniciais, sem dono nem gatilho de revisão.  
**Correção:** criar seção de perguntas abertas/premissas com ID, owner, decisão provisória, risco e condição de revisão.

**[Downstream usability] Faltam jornadas operacionais e rastreabilidade (§§4, 17, 23–24, 31).** A tela Live War Room não substitui narrativas de operação, e não há elo entre requisitos, releases e aceite.  
**Correção:** documentar 3–5 jornadas do operador e uma tabela FR/NFR → versão → critério de aceite.

**[Shape fit] PRD mistura requisitos e solução (§§6–22, 25–28).** Arquitetura, schemas, fórmulas, árvore de arquivos e guia de agentes diluem a leitura de produto.  
**Correção:** manter no PRD visão, escopo, jornadas, FR/NFR, métricas e decisões abertas; mover detalhes para companions de arquitetura, domínio e roadmap.

### Médios (7)

**[Decision-readiness] Métricas sem alvo de decisão ou contramétrica (§30).**  
**Correção:** definir baseline, meta, fonte, owner e contramétrica para cada métrica V1.

**[Strategic coherence] Hipótese de valor do MVP não verificável (§§2.2, 23.5, 30, 31).**  
**Correção:** acrescentar teste de utilidade e compreensão das recomendações; manter qualidade preditiva comparativa para V2/V3.

**[Strategic coherence] Priorização V1 não referencia FRs (§§4.1–4.8, 23.2–23.5, 27).**  
**Correção:** mapear cada FR/NFR para V1, V2, V3 ou posterior.

**[Done-ness clarity] Limites NFR não totalmente testáveis (§§5.1, 5.3, 5.6, 22.6).**  
**Correção:** fixar perfil de benchmark, fixture, ferramenta e limiares; substituir termos subjetivos por regras verificáveis.

**[Done-ness clarity] Recuperação de sessão sem identidade/seleção (§§4.4, 5.2, 19.1–19.4).**  
**Correção:** definir chave e seletor de sessão, comportamento para conflito/corrupção e recovery drill.

**[Scope honesty] Política de dados e licenças implícita (§§6.1, 8.1, 12.1–12.2, 29.1).**  
**Correção:** declarar fontes permitidas, retenção e se dados são somente importados localmente ou distribuídos pelo produto.

**[Downstream usability] Glossário e contrato de nomenclatura ausentes (§§8–9, 12, 14–15, 18.6).**  
**Correção:** adicionar glossário e padronizar hashes/nomes canônicos.

### Baixos (0)

Nenhum.

## Notas mecânicas

- IDs de FR e NFR são contínuos e não aparentam duplicação.
- Não há glossário, IDs de jornadas nem IDs de métricas de sucesso.
- Não existem tags `[ASSUMPTION]`, `[NOTE FOR PM]` ou índice de premissas.
- A hierarquia de títulos quebra no capítulo 23: as versões usam `#` em vez de `##`.

## Arquivos do revisor

- `review-rubric.md`
