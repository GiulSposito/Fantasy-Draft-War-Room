# Snapshot bundle — schema V1

Referência normativa dos 4 arquivos que compõem um snapshot bundle. Fonte para
o autor do CLI `scripts/prepare_snapshot.R` (Story 1.4) e para o runtime live.
A forma executável deste documento é `snapshot_schema()` em
`R/domain_snapshot_schema.R` — os dois devem concordar.

O bundle é um diretório com exatamente estes arquivos:

| Arquivo | Formato | Conteúdo |
|---|---|---|
| `players.csv` | CSV (cabeçalho, UTF-8, LF) | Identidade e elegibilidade do jogador |
| `metrics.csv` | CSV (cabeçalho, UTF-8, LF) | Projeção e valor do jogador |
| `metadata.json` | JSON (objeto) | Metadados do snapshot |
| `qa-report.json` | JSON | Relatório de qualidade cru (classificação é a Story 1.5) |

Leitura e desserialização são feitas pelo adapter `read_snapshot_bundle()`
(`utils::read.csv(stringsAsFactors = FALSE)`, `jsonlite::fromJSON(simplifyVector
= TRUE)`). Validação, coerção de tipo, normalização de posição e join ficam no
parser puro `parse_snapshot_bundle()`.

## `players.csv`

Uma linha por jogador. Chave: `player_id` (também presente em `metrics.csv`).

| Coluna | Tipo | Obrigatória | Notas |
|---|---|---|---|
| `player_id` | texto | sim | Chave canônica; casa 1:1 com `metrics.csv` |
| `display_name` | texto | sim | Nome para apresentação |
| `normalized_name` | texto | sim | Nome para busca/desambiguação |
| `position` | texto | sim | Normalizada para o conjunto V1 (`QB`, `RB`, `WR`, `TE`, `K`, `DST`); qualquer variação de `D/ST` mapeia para `DST` |
| `nfl_team` | texto | não | Ausente = free agent; ausência vira `NA` |
| `bye_week` | inteiro | não | Ausência vira `NA` |

## `metrics.csv`

Uma linha por jogador. Chave: `player_id`.

| Coluna | Tipo | Obrigatória | Notas |
|---|---|---|---|
| `player_id` | texto | sim | Chave de join com `players.csv` |
| `points` | numérico | sim | Projeção usada pela V1 |
| `vor` | numérico | sim | Value over replacement |
| `tier` | inteiro | sim | Coagido para inteiro |
| `tier_cliff` | lógico | sim | `true`/`false` (aceita `t`/`f`/`1`/`0`/`yes`/`no`) |
| `floor` | numérico | não | Ausência vira `NA` |
| `ceiling` | numérico | não | Ausência vira `NA` |
| `sd_points` | numérico | não | Ausência vira `NA` |
| `ecr` | numérico | não | Ausência vira `NA` |
| `adp` | numérico | não | Ausência vira `NA` |
| `adp_sd` | numérico | não | Ausência vira `NA` |
| `uncertainty` | numérico | não | Ausência vira `NA` |

Célula vazia numa coluna opcional vira `NA` tipado. Célula vazia numa coluna
obrigatória (`motivo = "vazio"`), valor não coercível para o tipo
(`motivo = "nao_coercivel"`) ou valor numérico não inteiro numa coluna inteira
como `tier`/`bye_week` (`motivo = "nao_inteiro"`, sem arredondamento silencioso)
é `domain_error("snapshot_tipo_invalido")` com `details$campo` e `details$valor`.

Colunas fora do schema são descartadas — não chegam ao objeto canônico. Nomes
de coluna duplicados num CSV são `domain_error("snapshot_formato_invalido")`.

## `metadata.json`

Objeto JSON. Todos os campos abaixo são obrigatórios (ausente, `null` ou string
vazia → `domain_error("snapshot_metadado_ausente")`). Expostos crus no objeto
canônico; `parse_snapshot_bundle()` não os coage.

| Campo | Tipo | Notas |
|---|---|---|
| `snapshot_id` | texto | Único por execução do CLI |
| `season` | inteiro | Temporada |
| `generated_at` | texto | Timestamp UTC ISO-8601 |
| `pipeline_version` | texto | Versão do `prepare_snapshot.R` |
| `source_list` | lista de texto | Fontes de projeção agregadas |
| `scoring_hash` | texto | SHA-256 hex minúsculo do YAML de scoring canônico |
| `content_hash` | texto | `snapshot_content_hash` (calculado na Story 1.3) |
| `qa_summary` | texto | Resumo curto do `qa-report.json` |
| `schema_version` | texto | Deve ser exatamente `"snapshot-bundle-v1"`, senão `domain_error("snapshot_schema_incompativel")` |

`metadata.json` deve desserializar para um objeto JSON (um array/`data.frame` é
`domain_error("snapshot_formato_invalido")`).

## `qa-report.json`

Desserializado e exposto cru em `qa_report`. A classificação bloqueante/aviso
dos achados é a Story 1.5 — este parser não a aplica.

## Erros de domínio

| `code` | Quando |
|---|---|
| `bundle_arquivo_ausente` | Um dos 4 arquivos não existe no diretório |
| `bundle_formato_invalido` | CSV ou JSON com sintaxe inválida |
| `snapshot_formato_invalido` | Tabela/objeto na forma errada: CSV não é tabela, nomes de coluna duplicados, `metadata.json` não é objeto JSON |
| `snapshot_schema_incompativel` | `metadata$schema_version` ≠ `"snapshot-bundle-v1"` (`details$encontrado`) |
| `snapshot_coluna_ausente` | Coluna obrigatória ausente em `players.csv`/`metrics.csv` (`details$campo`) |
| `snapshot_tipo_invalido` | Célula vazia em coluna obrigatória, valor não coercível, ou não inteiro em coluna inteira (`details$motivo`) |
| `snapshot_metadado_ausente` | Metadado obrigatório ausente/nulo/vazio |
| `snapshot_bundle_vazio` | `players.csv` ou `metrics.csv` sem nenhuma linha |
| `snapshot_player_id_duplicado` | `player_id` repetido dentro de `players.csv` ou `metrics.csv` (`details$arquivo`, `details$player_id`) |
| `snapshot_posicao_invalida` | `position` fora do conjunto V1 (após normalização) |
| `snapshot_join_incompleto` | `player_id` presente em só um dos dois CSVs (`details$apenas_em_players`, `details$apenas_em_metrics`) |

Se `deserialized` já for um `domain_error` (o adapter falhou), `parse_snapshot_bundle()`
o devolve inalterado. Sucesso retorna uma lista de classe `"fdwr_snapshot_bundle"`.
