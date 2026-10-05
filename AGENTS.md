# AGENTS.md — Fox

Índice operacional do projeto. Use-o para localizar arquivos por tarefa sem varrer o repositório inteiro.

## Mapa por tarefa
- TUI, menus, teclas, prompts e mensagens → `lib/ui.bash`
- Fluxo principal e coordenação → `lib/core.bash`
- Backup → `lib/backup.bash`
- Restauração → `lib/restore.bash`
- Chaves, destinatários e GPG → `lib/gpgkeys.bash`
- Configuração padrão → `config/fox.conf.default`
- Customização → `docs/CUSTOMIZATION.md`
- Diretrizes de IA → `docs/Diretriz-de-Uso-de-IA.md`
- Instalação → `install.sh`
- Build/instalação/desinstalação → `Makefile`
- Pacote Arch → `fox-pkg/PKGBUILD`
- Entrada da CLI → `fox`
- Documentação geral → `README.md`

## Encadeamento
```text
fox
 └─ lib/core.bash
    ├─ lib/ui.bash
    ├─ lib/backup.bash
    │  └─ lib/gpgkeys.bash
    └─ lib/restore.bash
       └─ lib/gpgkeys.bash
```

## Segurança
Para backup, restauração e criptografia, priorize `backup.bash`, `restore.bash`, `gpgkeys.bash` e `core.bash`. Verifique quoting, caminhos, temporários, permissões, sobrescrita, argumentos de comandos externos e seleção de destinatários GPG.

## Regras
- Comece pelo arquivo indicado no mapa e siga apenas chamadas concretas necessárias.
- Não edite `fox` sem verificar se a mudança pertence a `lib/`.
- Mudanças de configuração devem considerar `config/fox.conf.default` e `docs/CUSTOMIZATION.md`.
- Mudanças de instalação devem considerar `install.sh`, `Makefile` e, quando aplicável, `fox-pkg/PKGBUILD`.
- Documentação deve refletir o comportamento implementado.
- Diferencie comportamento observado de inferência.
