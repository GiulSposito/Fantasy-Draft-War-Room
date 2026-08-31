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

## Identidade de conteúdo (`snapshot_content_hash`)

`snapshot_content_hash(raw_files, metadata)` (`R/domain_snapshot_hash.R`,
domínio puro) é o SHA-256 (hex minúsculo) de um **manifesto canônico** dos 4
arquivos:

1. Para `players.csv`, `metrics.csv`, `qa-report.json`: o conteúdo cru com
   quebras de linha normalizadas para LF (`\r\n` **e** `\r` isolado → `\n`),
   bytes tratados como UTF-8.
2. Para `metadata.json`: **não** os bytes crus, mas
   `canonical_json(metadata)` com o campo derivado **`content_hash` removido** —
   assim o hash não depende da formatação do JSON em disco (indentação, ordem
   das chaves), mas depende de todo campo de conteúdo (inclusive `scoring_hash`).
3. SHA-256 de cada um dos 4 payloads acima (texto normalizado para bytes UTF-8).
4. Manifesto = mapa `{ "<path>": "<sha256>" }` com as chaves (paths relativos)
   em ordem de byte, serializado por `canonical_json()`.
5. Resultado = SHA-256 desse manifesto.

Consequências: idêntico entre máquinas para o mesmo conteúdo (independe de
locale — marca decimal, colação, encoding); muda com qualquer byte alterado
nos **4 arquivos do manifesto**; **não** muda quando só o valor de
`metadata.json$content_hash` difere, quando `metadata.json` é reindentado /
reordenado em disco, ou quando `scoring.yml` muda (fora do manifesto).
`verify_content_hash(raw_files, metadata)` compara o hash calculado com
`metadata$content_hash` e retorna `NULL` ou
`domain_error("snapshot_content_incompativel")`.

`scoring.yml` é um 5º arquivo do diretório do bundle e fica **fora** do
manifesto de conteúdo (o manifesto lista exatamente os 4 arquivos acima). Sua
identidade é o `scoring_config_hash` = `SHA-256(canonical_json(yaml_parseado))`,
comparado a `metadata.json$scoring_hash` por `verify_scoring_hash()`.

### Forma canônica (`canonical_json`, contrato AD-12)

UTF-8, LF. Objetos: `{` + pares `"chave":valor` **ordenados por byte**
(`order(method = "radix")`, independe de `LC_COLLATE`) + `}`, sem espaços.
Arrays: `[...]`. Strings JSON-escapadas (formas curtas `\n \r \t \b \f \" \\`,
demais controles < 0x20 como `\u00xx`). `NULL`/`NA` → `null` explícito.
Lógico → `true`/`false`. Número de **valor inteiro** (seja `integer` ou
`double` como `4.0`, `|x| < 2^53`) → sem parte decimal. Demais reais →
`formatC(x, format = "f", digits = 10, decimal.mark = ".")` (10 casas fixas,
marca decimal sempre `.` independente de `OutDec`, sem notação científica).
`NaN`/`Inf`/`-Inf`, nomes de objeto parciais/duplicados e vetores atômicos
nomeados com `length > 1` são erro (`stop()`). Reusado pelo `draft_state_hash`
do Epic 4 (revisar se 10 casas servem para VOR/points).

## Geração pelo CLI (`scripts/prepare_snapshot.R`, Story 1.4)

`scripts/prepare_snapshot.R` é o **único** componente do produto com rede e o
único que importa `ffanalytics` (AD-2). Emite os 5 arquivos do diretório do
bundle (`players.csv`, `metrics.csv`, `metadata.json`, `qa-report.json`,
`scoring.yml`) de forma atômica: monta num diretório temporário, calcula o
`content_hash`, relê do disco e roda `parse_snapshot_bundle()` +
`verify_content_hash()` + `verify_scoring_hash()`, e só então move para
`<root>/<snapshot_id>/`. Falha em qualquer etapa → exit ≠ 0, mensagem PT-BR em
stderr, nenhum diretório parcial.

### Modo coleta (`--scoring <yaml> --season <ano> [--sources CBS,ESPN,…]`)

Fluxo `ffanalytics` (commit `1955daa05efb4a1f38c9a4dee609c5c4eaf84b4d`):

```r
s <- scrape_data(src = sources, pos = c("QB","RB","WR","TE","K","DST"),
                 season = season, week = 0)          # week 0: VOR de temporada
p <- projections_table(s, scoring_rules = scoring_parsed,
                       vor_baseline = cfg$vor_baseline,
                       tier_thresholds = cfg$tier_thresholds)
p <- add_player_info(p)                              # + first_name/last_name/team
p <- add_adp(p); p <- add_ecr(p); p <- add_uncertainty(p)   # best-effort
```

`add_adp`/`add_ecr`/`add_uncertainty` são aplicados best-effort: um erro numa
fonte secundária degrada a coluna opcional correspondente, não a coleta.

Mapeamento cru→canônico (`projections_table` + `add_player_info` → forma crua
comum → `build_snapshot_tables()`):

| ffanalytics | canônico | Notas |
|---|---|---|
| `id` | `player_id` | |
| `first_name` + `last_name` (ou `player`) | `display_name` | `normalized_name` é derivado (minúsculo, sem acento) |
| `pos` | `position` | normalizada para o conjunto V1 |
| `team` | `nfl_team` | |
| `bye` | `bye_week` | quando presente |
| `points` | `points` | |
| `points_vor` | `vor` | |
| `tier` | `tier` | |
| `pos_rank` | — | usado só para derivar `tier_cliff` |
| `floor`, `ceiling`, `sd_pts` | `floor`, `ceiling`, `sd_points` | |
| `ecr`, `adp`, `uncertainty` | `ecr`, `adp`, `uncertainty` | opcionais |

`tier_cliff` (booleano) é **derivado**: `ffanalytics` fornece `tier` (inteiro) e
`pos_rank`; o jogador de maior `pos_rank` de um `tier` que tem um tier pior
depois dele na mesma posição recebe `tier_cliff = TRUE` — "pegue antes do
degrau". O último jogador do tier final de cada posição é `FALSE` (não há
próximo tier).

### Config de pipeline versionada (`config/snapshot_pipeline.yml`)

`vor_baseline` e `tier_thresholds` (por posição, padrão liga de 12 times) e
`pipeline_version` vêm desse arquivo, passados explicitamente ao `ffanalytics`.
O caminho padrão é `config/snapshot_pipeline.yml`; `--pipeline-config <yaml>`
sobrescreve. `pipeline_version` ausente/vazio aborta o CLI; `vor_baseline` ou
`tier_thresholds` não-numérico aborta a coleta (`coleta_ffanalytics_falhou`).
O `pipeline_version` no `metadata.json` **deve ser incrementado quando esse
arquivo mudar** (o schema v1 ainda não pina o hash dele — reprodutibilidade de
`vor`/`tier` depende do bump).

### Modo fallback CSV (`--from-csv <csv> --metadata <json> [--season <ano>]`)

Aceita um CSV manual na forma crua comum (com as colunas obrigatórias, incluindo
`tier_cliff` — ausência → `snapshot_coluna_ausente` na releitura). Não exige
`ffanalytics`. `source_list = ["manual-csv"]`. A temporada vem de `--season` ou
do campo `season` do JSON de `--metadata`.

### `snapshot_id` e diretório de saída

Cada execução gera `snapshot_id = "snap-<season>-<AAAAMMDDTHHMMSSZ em UTC>"`. O
diretório raiz é `tools::R_user_dir("fantasydraftwarroom", "data")/snapshots` ou
`--out <dir>`. Se `<root>/<snapshot_id>/` já existir, aborta com
`bundle_ja_existe` sem sobrescrever. Raiz não gravável →
`bundle_saida_nao_gravavel`.

### Erros de domínio adicionais (Story 1.4)

| `code` | Quando |
|---|---|
| `coleta_ffanalytics_falhou` | `scrape_data`/`projections_table` lançou ou voltou vazio; contrato de colunas mudou; `pos_rank` ausente para derivar `tier_cliff` |
| `ffanalytics_ausente` | Modo coleta com o pacote `ffanalytics` não instalado |
| `bundle_saida_nao_gravavel` | Diretório raiz de saída sem permissão de escrita ou falha ao gravar/mover |
| `bundle_ja_existe` | `<root>/<snapshot_id>/` já existe — nada é sobrescrito |

## Validação de qualidade (Story 1.5)

`validate_snapshot_quality(deserialized, active_scoring_parsed)`
(`R/domain_snapshot_quality.R`, domínio puro) roda **todas** as checagens abaixo
sobre o bundle **desserializado cru** (`read_snapshot_bundle()`) mais o
`scoring.yml` ativo já parseado, em modo **coletar-tudo** (nunca aborta no
primeiro problema), e devolve uma lista ordenada de achados
`list(code, severity, message, details)`. Não altera `parse_snapshot_bundle()`
nem re-roda a coleta. É a fonte da lista consumida pelo gate de início
(Epic 2, Story 2.6) e pela superfície "Qualidade do snapshot" (Story 1.7).

**Pré-condição:** `parse_snapshot_bundle()` (fail-fast) roda antes no pipeline.
Ele cobre `snapshot_bundle_vazio` (`players`/`metrics` sem linhas),
`snapshot_join_incompleto` e a validação do *valor* de `schema_version` —
checagens que esta lista coletar-tudo **não** replica. A lista é complemento do
parser (checagens semânticas + modo coletar-tudo), não substituto.

Se `deserialized` já for um `domain_error` (o adapter falhou), a saída é
**um** único achado bloqueante que preserva o `code`, a mensagem e os detalhes
do erro. Se `deserialized` não for lista nem `domain_error`, a saída é um único
`snapshot_bundle_ilegivel`. Se `active_scoring_parsed` for um `domain_error`
(o `read_scoring_config` falhou) ou um tipo degenerado (não-lista / `data.frame`),
a saída inclui um `snapshot_scoring_indisponivel` (preserva `code`/`message` do
erro, ou `code = "scoring_tipo_invalido"`) e a checagem de hash de scoring é pulada.

| Checagem | `code` | Severidade | `details` |
|---|---|---|---|
| `deserialized` não é lista nem `domain_error` | `snapshot_bundle_ilegivel` | bloqueante | — |
| `players`/`metrics` presente mas não é `data.frame` (uma por tabela; suprime a cascata de campos/opcionais/cobertura daquela tabela) | `snapshot_tabela_ilegivel` | bloqueante | `tabela` |
| Campo obrigatório de jogador `NA` ou coluna ausente (todos os obrigatórios de `players`/`metrics`, `player_id` incluso, por tabela) | `snapshot_campo_obrigatorio_ausente` | bloqueante | `campo`, `player_id`, `tabela` |
| `metadata` presente mas não é objeto JSON (array / escalar) | `snapshot_metadado_ilegivel` | bloqueante | — |
| Metadado obrigatório ausente/nulo/vazio ou todo `NA` (inclui multi-elemento) | `snapshot_metadado_ausente` | bloqueante | `campo` |
| `player_id` repetido em `players.csv` ou `metrics.csv` | `snapshot_player_id_duplicado` | bloqueante | `player_id` |
| Nome ambíguo: `(normalized_name, position normalizada, nfl_team)` repetida em 2+ `player_id` (`nfl_team` `NA` em ambos não distingue; linhas com `normalized_name` em branco são ignoradas) | `snapshot_nome_ambiguo` | bloqueante | `normalized_name`, `player_ids` |
| `position` fora do conjunto V1 após `normalize_position()` | `snapshot_posicao_fora_do_v1` | bloqueante | `player_id`, `raw` |
| `adp` informado (inclui `NaN` numérico) mas não `> 0` e finito | `snapshot_adp_invalido` | bloqueante | `player_id`, `valor` |
| `active_scoring_parsed` é um `domain_error` ou tipo degenerado (não-lista / `data.frame`) | `snapshot_scoring_indisponivel` | bloqueante | `code` |
| `scoring_config_hash(ativo)` ≠ `metadata$scoring_hash` (via `verify_scoring_hash()`) | `snapshot_scoring_incompativel` | bloqueante | `esperado`, `encontrado` |
| `verify_scoring_hash()` lança erro inesperado (scoring passou o guard de tipo mas quebrou `canonical_json`) | `snapshot_scoring_erro` | bloqueante | — |
| `qa-report` ausente, não é objeto, ou objeto sem a chave `findings` | `qa_report_ausente` | bloqueante | — |
| Entrada de `qa_report$findings` com `severity = "bloqueante"` (uma por entrada, preserva `code`/`message`) | `qa_report_bloqueante` | bloqueante | `qa_code` |
| Entrada de `qa_report$findings` com outra severidade | `qa_report_aviso` | aviso | `qa_code`, `severity` |
| Campo opcional ausente ou todo `NA` (`floor`/`ceiling`/`sd_points`/`ecr`/`adp`/`adp_sd`/`uncertainty`/`nfl_team`/`bye_week`) | `snapshot_opcional_ausente` | aviso | `campo` |
| Posição do conjunto V1 sem nenhum jogador | `snapshot_cobertura_anomala` | aviso | `posicao` |

`qa_report$findings: []` (o que a Story 1.4 emite) **não** é um achado — só a
ausência da chave `findings` é.

Mínimos numéricos de cobertura por posição são referência **não-normativa** e
ficam fora do V1 (só "posição totalmente ausente" é aviso). `adp` **não tem
limite superior**: um ADP alto é um jogador que sai tarde ou não é draftado —
dado legítimo; apenas `<= 0` ou não-finito bloqueia.

`verify_content_hash` precisa dos bytes crus dos arquivos e é responsabilidade
do chamador (superfície / gate), **não** de `validate_snapshot_quality` (que
recebe só o desserializado) — content hash não entra na lista coletar-tudo.

**Ordenação canônica** (determinística, independente de locale): `severity`
(`bloqueante` = 0, `aviso` = 1), depois `code` em ordem de byte
(`order(method = "radix")`), depois uma chave estável derivada de `details`
(pares `nome=valor` ordenados). Duas execuções sobre a mesma entrada produzem
uma lista `identical()`.

Uma entrada estruturalmente saudável (fixture `snapshot-valid`) com scoring
compatível produz **zero achados `bloqueante`** — avisos por opcionais ausentes
ou cobertura anômala são aceitáveis.

## Erros de domínio

| `code` | Quando |
|---|---|
| `bundle_arquivo_ausente` | Um dos 4 arquivos não existe no diretório |
| `bundle_formato_invalido` | CSV, JSON ou YAML de scoring com sintaxe inválida; `scoring.yml` que não é um mapa; bytes NUL em arquivo do manifesto |
| `snapshot_scoring_incompativel` | `scoring_config_hash(scoring.yml)` ≠ `metadata$scoring_hash` (`details$esperado`, `details$encontrado`) |
| `snapshot_content_incompativel` | `snapshot_content_hash(bundle)` ≠ `metadata$content_hash` (`details$esperado`, `details$encontrado`) |
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
