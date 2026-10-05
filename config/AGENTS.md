# AGENTS.md — config/

- `fox.conf.default` — configuração padrão.

Encadeamento: `fox.conf.default` → `docs/CUSTOMIZATION.md` → módulo de `lib/` que consome a opção.

Ao alterar uma opção, confirme onde ela é realmente lida. Não assuma que uma variável declarada é consumida.
