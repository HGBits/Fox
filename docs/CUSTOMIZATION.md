# Customização do fox

Todo o visual e os keybinds do fox vêm do `fzf` por baixo — o
fox só monta os argumentos `--bind`, `--color` e `--prompt` a partir
do seu `~/.config/fox/fox.conf`. Não precisa mexer no código
do próprio fox pra mudar cor ou tecla.

## Onde editar

`~/.config/fox/fox.conf` — criado automaticamente na primeira
execução (copiado do template do sistema em `/etc/fox/fox.conf`
ou do `config/fox.conf.default` do projeto, se rodando sem instalar).

## Keybinds

Variáveis reconhecidas (valores default entre parênteses):

| Variável         | Função                                   | Default   |
|------------------|-------------------------------------------|-----------|
| `FOX_KEY_ADD`     | Reservada pra atalho direto de "adicionar" em telas futuras | `ctrl-a`  |
| `FOX_KEY_DEL`     | Reservada pra atalho direto de "remover"  | `ctrl-d`  |
| `FOX_KEY_CONFIRM` | Confirmar seleção                         | `enter`   |
| `FOX_KEY_BACK`    | Voltar / cancelar (aborta o fzf)          | `esc`     |
| `FOX_KEY_TOGGLE`  | Marcar/desmarcar item em checklists       | `tab`     |

A sintaxe segue o formato de tecla do próprio fzf — qualquer coisa aceita
por `fzf --bind=TECLA:ação` funciona aqui (`ctrl-x`, `alt-a`, `f5`, etc.).
Veja `man fzf` ou `fzf --help` pra lista completa de nomes de tecla.

Exemplo, no seu `fox.conf`:

```bash
FOX_KEY_BACK="ctrl-q"
FOX_KEY_TOGGLE="space"
```

## Cores

`FOX_FZF_COLOR` recebe exatamente a string que você passaria em
`fzf --color="..."`. Formato: pares `elemento:cor` separados por vírgula.
Exemplo (tema escuro simples):

```bash
FOX_FZF_COLOR="fg:#d0d0d0,bg:#121212,hl:#5f87af,fg+:#ffffff,bg+:#262626,hl+:#5fafd7,border:#444444"
```

Lista de elementos disponíveis: `fg`, `bg`, `hl`, `fg+`, `bg+`, `hl+`,
`border`, `header`, `prompt`, `pointer`, `marker`, `spinner` — veja
`fzf --help` seção `--color` pra descrição de cada um.

## Semântica do `--dry`

`--dry` não pausa o fox inteiro — ele distingue entre operações
inofensivas (contidas num `mktemp`, apagadas no fim: descriptografar,
extrair, montar o `.tar.gz` temporário) e operações com efeito real fora
do temp (copiar/`chown` pro `$HOME` de um usuário destino, gravar o
arquivo `.gpg` final em disco). Só o segundo grupo é pulado em `--dry` —
o primeiro roda de verdade, porque sem isso não haveria nada real pra
validar durante o teste.

## Exportação de chave secreta pro projeto

O submenu "Gerenciar chaves GPG" → "Exportar nova chave secreta pro
projeto" roda `gpg --armor --export-secret-keys <fingerprint>` direto do
keyring do `/home/` que você escolher, salvando o `.asc` resultante em
`~/.config/fox/keys/`. Isso **requer rodar o fox como
root/sudo** sempre que o `/home/` escolhido não for o seu próprio — sem
isso o `sudo -u <usuário> gpg ...` interno falha por permissão.

## Criptografia do backup

Por padrão, toda vez que você gera um backup o fox pergunta se quer
GPG simétrico (senha digitada na hora) ou assimétrico (informando o
destinatário naquele momento). Se você sempre criptografa pra uma chave
fixa, defina em `fox.conf`:

```bash
FOX_GPG_RECIPIENT="seu-email-ou-fingerprint@exemplo.com"
```

Com isso, o menu de escolha nem aparece — vai direto de `gpg --encrypt
--recipient "$FOX_GPG_RECIPIENT"`. O restore não precisa de configuração
equivalente: `gpg --decrypt` detecta sozinho se o arquivo é simétrico ou
assimétrico.

## Rodapé de teclas

O rodapé com as teclas ativas (ex: `[tab] marcar   [enter] confirmar   [esc]
cancelar`) é montado dinamicamente a partir das variáveis `FOX_KEY_*` acima e
injetado no `--prompt` do fzf — que por padrão já fica fixo na parte
inferior da tela. Se você mudar um `FOX_KEY_*`, o texto do rodapé
correspondente muda junto, automaticamente.

## Adicionando uma tela nova (pra quem for mexer no código)

Toda tela de menu do fox passa por `fox::ui::menu` ou
`fox::ui::checklist` (em `lib/ui.bash`). Se você quiser um comportamento de
tecla diferente numa tela específica, adicione o `--bind` extra direto na
chamada daquela tela, sem alterar os defaults globais dos outros menus.
