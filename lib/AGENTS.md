# AGENTS.md — lib/

Implementação principal do Fox.

- `core.bash` — fluxo principal e coordenação.
- `ui.bash` — TUI, menus, prompts e mensagens.
- `backup.bash` — criação de backups.
- `restore.bash` — restauração.
- `gpgkeys.bash` — chaves, destinatários e GPG.

### Encadeamento
Backup: `backup.bash` → `core.bash` → `gpgkeys.bash` quando houver GPG → `ui.bash` quando necessário.
Restore: `restore.bash` → `core.bash` → `gpgkeys.bash` quando houver GPG → `ui.bash` quando necessário.
GPG: `gpgkeys.bash` → contexto de `core.bash` → somente os chamadores relevantes.

Não leia todos os módulos para uma alteração localizada. Siga as chamadas concretas.
