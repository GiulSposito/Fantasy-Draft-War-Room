# Contrato de dados V1 — Fantasy Draft War Room

Este companion define a fronteira entre a preparação pré-draft por `script.R` e o runtime live. Ele complementa o [PRD](prd.md); não altera seu escopo.

## Fluxo

1. O operador executa `script.R` localmente antes do draft.
2. O script recebe a configuração de scoring em YAML compatível com `ffanalytics` e produz um snapshot canônico imutável.
3. O runtime live carrega somente esse snapshot, valida o contrato e inicia uma sessão apenas quando o hash de scoring do snapshot corresponde ao hash da configuração ativa.
4. Depois do início, snapshot e configuração não podem ser trocados. Um novo snapshot exige nova preparação e deve ser selecionado antes de iniciar uma sessão.

O runtime live não acessa rede e não distribui snapshots ou projeções.

## Artefatos e identidade

O `script.R` produz:

- um arquivo de snapshot canônico (formato de persistência a definir pela implementação);
- a configuração YAML de scoring usada na geração;
- metadados e relatório de qualidade;
- hash de conteúdo do snapshot e hash da configuração de scoring.

Cada snapshot tem `snapshot_id` único. Snapshots antigos não são sobrescritos. A sessão registra `snapshot_id`, `snapshot_content_hash` e `scoring_hash` para permitir auditoria e reprodução.

## Campos mínimos do snapshot

| Campo | Regra V1 |
|---|---|
| `snapshot_id` | Obrigatório e único. |
| `player_id` | Obrigatório; chave canônica do jogador. |
| `display_name`, `normalized_name` | Obrigatórios; usados para apresentação e busca. |
| `position` | Obrigatório; `QB`, `RB`, `WR`, `TE`, `K` ou `DST`/`D/ST` normalizado. |
| `nfl_team` | Obrigatório quando conhecido; pode ser ausente para free agent. |
| `bye_week` | Opcional. |
| `points` | Obrigatório; projeção usada pela V1. |
| `floor`, `ceiling`, `sd_points`, `ecr`, `adp`, `adp_sd`, `uncertainty` | Opcionais; a indisponibilidade é visível e não pode interromper o draft. |
| `vor`, `tier`, `tier_cliff` | Obrigatórios para recomendação V1; podem ser calculados pelo `script.R`. |
| `season`, `generated_at`, `pipeline_version`, `source_list`, `scoring_hash`, `content_hash`, `qa_summary` | Metadados obrigatórios do snapshot. |

O contrato aceita uma importação CSV manual somente quando ela contém os campos obrigatórios e os metadados necessários para gerar os hashes e o relatório de qualidade.

## Validação e gates de qualidade

Antes de criar uma sessão, a validação bloqueia o uso do snapshot quando houver:

- `snapshot_id`, `player_id`, nome normalizado, posição, `points`, `vor`, `tier` ou metadado obrigatório ausente;
- `player_id` duplicado ou nome ambíguo sem desambiguação;
- posição fora do conjunto V1 ou D/ST sem normalização;
- ADP inválido quando informado;
- hash de scoring diferente da configuração ativa;
- relatório de qualidade ausente ou marcado como bloqueante.

O runtime mostra a causa do bloqueio e orienta o operador a executar novamente o `script.R` ou selecionar outro snapshot. Campos opcionais ausentes geram aviso, não bloqueio.

## Compatibilidade snapshot–configuração

O YAML de scoring é a fonte usada por `ffanalytics` no pré-draft. Seu conteúdo canônico é hasheado como `scoring_hash`. A configuração de liga da sessão registra o mesmo hash; uma divergência bloqueia o início porque projeções, VOR, tiers e recomendações precisam ter sido calculados para o scoring selecionado.

O envelope de roster V1 fica no PRD: 8–14 times, 15 rounds, 9 titulares, 6 reservas e FLEX RB/WR. A validação do snapshot não altera esse envelope; ela garante apenas a integridade e compatibilidade dos dados usados nele.
