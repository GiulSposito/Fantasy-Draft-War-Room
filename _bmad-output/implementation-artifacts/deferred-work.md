# Trabalho adiado

Itens reais levantados durante o build, fora do escopo da story que os expôs. Cada um espera atenção focada depois.

- source_spec: `spec-1-1-scaffold-pacote-r-composition-root.md`
  summary: O `renv.lock` usa snapshot tipo `"all"` (171 pacotes, inclui a árvore de `devtools`) em vez de `"explicit"`.
  evidence: Reprodutível e funcional (`renv::status()` limpo, `renv::restore()` no-op), mas o lock é grande e sensível a churn. Trocar para `"explicit"` exigiu incluir `Suggests` no fecho transitivo, o que não resolveu. Revisitar quando a superfície de dependências estabilizar (pós-Epic 2), possivelmente movendo `devtools`/`lintr` para fora do lock.

- source_spec: `spec-1-1-scaffold-pacote-r-composition-root.md`
  summary: `normalize_position()` não remove espaço em branco não-ASCII (NBSP, espaços unicode) antes de normalizar.
  evidence: `trimws()` padrão só trata `[ \t\r\n]`; uma posição como `" QB"` seria rejeitada como `posicao_fora_do_v1`. A normalização real de dados de fontes externas pertence ao parser do bundle (Story 1.2), com estratégia unicode consistente.

- source_spec: `spec-1-1-scaffold-pacote-r-composition-root.md`
  summary: Nenhum guard automatizado (teste, CI ou pre-commit hook) garante que `config/config.yml` permaneça git-ignored.
  evidence: O arquivo carrega um Bearer token da NFL e hoje está corretamente ignorado (verificado com `git check-ignore`), mas um erro de digitação futuro no `.gitignore` que re-exponha o arquivo não seria detectado por `devtools::test()` nem `lintr`. É uma fronteira de vazamento de credencial. A mitigação estrutural (mover o token para variável de ambiente) já está anotada como decisão de story futura.

- source_spec: `spec-1-2-contrato-schema-snapshot-bundle.md`
  summary: `validate_metadata()` só checa presença dos metadados — não valida formato (hash SHA-256 hex minúsculo, timestamp ISO-8601 UTC).
  evidence: Um `scoring_hash`/`content_hash` malformado ou um `generated_at` fora do padrão passa direto para o objeto canônico. Os critérios de aceite da 1.2 pedem só "exigidos e expostos"; a validação de formato dos hashes é candidata natural da Story 1.3 (hashing) e a de outros campos, da Story 1.5.

- source_spec: `spec-1-2-contrato-schema-snapshot-bundle.md`
  summary: A validação estrutural de CSV além de "parseia" (linhas irregulares, delimitador errado, conteúdo não-tabular) é fina.
  evidence: `utils::read.csv` quase nunca lança em CSV estruturalmente quebrado, então o caminho `bundle_formato_invalido` para CSV é quase inalcançável (só o de JSON é exercitado). Revisitar com validação de shape pós-leitura se bundles reais baterem nisso.

- source_spec: `spec-1-2-contrato-schema-snapshot-bundle.md`
  summary: Tokens de nulo em texto ("null", "none") em células numéricas opcionais são rejeitados como `snapshot_tipo_invalido`.
  evidence: `read.csv` já converte `NA` sem aspas para `NA`, mas `"null"`/`"none"` de CSV escrito à mão viram erro em vez de `NA`. A normalização de dados de fontes reais pertence ao CLI (1.4) ou a um passo de limpeza (1.5).
