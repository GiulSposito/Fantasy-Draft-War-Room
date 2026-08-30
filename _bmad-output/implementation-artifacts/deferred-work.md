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
