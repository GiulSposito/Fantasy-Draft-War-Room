# Fantasy Draft War Room

Aplicativo Shiny local para conduzir drafts de fantasy football a partir de um
snapshot canonico de projecoes, validado offline antes do draft. Arquitetura
hexagonal: nucleo de dominio puro e deterministico, shell imperativo
(composition root + adaptadores de I/O).

## Estrutura

| Caminho | Papel |
|---|---|
| `app.R` | Composition root. So compoe: bind em `127.0.0.1`, guarda de colisao de porta, `runApp`. |
| `R/domain_*.R` | Nucleo puro: sem `shiny`, `DBI`, `RSQLite`, `yaml`, filesystem, clock ou APIs reativas. |
| `R/application_*.R` | Casos de uso (ainda nao criados). |
| `R/adapter_*.R` | Adaptadores de I/O: SQLite, filesystem (ainda nao criados). |
| `R/ui_*.R` | Superficies Shiny (ainda nao criadas). |
| `scripts/` | CLI pre-draft (`prepare_snapshot.R`, Story 1.4). |
| `config/` | YAML versionado (`score_settings.yml`) + schemas. `config/config.yml` NAO e versionado (contem token). |
| `inst/schema/` | Migrations SQLite + schema do snapshot bundle. |
| `tests/` | Suite `testthat`; o dominio e testado fora de Shiny/SQLite. |

## Setup a partir de um clone limpo

Requer R 4.6.x.

```sh
# 1. Restaura as dependencias fixadas no renv.lock
Rscript -e 'renv::restore(prompt = FALSE)'

# 2. Copie o exemplo para config/config.yml (nao versionado) e preencha os
#    segredos das fontes:
cp config/config.yml.example config/config.yml

# 3. Instala o proprio pacote no library do renv (necessario para o
#    object_usage_linter enxergar funcoes entre arquivos de R/).
R CMD INSTALL --no-docs --no-help .

# 4. Sobe o app em loopback (imprime a URL local no console)
Rscript -e 'shiny::runApp("app.R")'
```

O app faz bind exclusivo em `127.0.0.1`. Se a porta padrao (`3939`) estiver
ocupada, ele encerra com mensagem acionavel e exit nao-zero -- nunca troca de
porta nem escuta em interface publica. Para usar outra porta:

```sh
Rscript -e 'options(fdwr.port = 4000L); shiny::runApp("app.R")'
```

## Testes e lint

```sh
Rscript -e 'devtools::test()'
# Precisa do pacote instalado (passo 3 do setup) ou de um
# pkgload::load_all() antes, senao o object_usage_linter reporta
# falsos positivos em R/.
Rscript -e 'lintr::lint_package()'
```
