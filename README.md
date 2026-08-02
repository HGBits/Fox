# Fox

TUI unificado de backup/restore de configs compartilhadas entre usuários
de um mesmo sistema Linux, com seleção de diretórios via `yazi` e
gerência de chaves GPG por chave/usuário-destino.

## Licença

GNU General Public License v3.0 (ou, à sua escolha, qualquer versão
posterior) — veja [`LICENSE`](./LICENSE). Texto integral:
<https://www.gnu.org/licenses/gpl-3.0.txt>

## Assinatura GPG

Os releases são assinados com a chave GPG do autor. Pra verificar um
tarball baixado:

```bash
gpg --verify fox-<versao>.tar.gz.asc fox-<versao>.tar.gz
sha256sum -c fox-<versao>.tar.gz.sha256
```

Se você ainda não tem a chave pública importada, busque pelo fingerprint
publicado na página de releases do projeto.

## Publicando o repositório (primeira vez)

```bash
cd fox
git init
git add .
git commit -S -m "Fox 1.0.0 — versão inicial"
git remote add origin https://SEU-HOST/SEU_USUARIO/fox.git
git push -u origin main
```

O `-S` no commit assina com sua chave GPG padrão (configure antes com
`git config --global user.signingkey SEU_FINGERPRINT` e
`git config --global commit.gpgsign true` se quiser assinatura
automática em todo commit). Pra assinar a tag do release:

```bash
git tag -s v1.0.0 -m "Fox 1.0.0"
git push --tags
```

Pra assinar o tarball da release em si (o que o `install.sh` verifica):

```bash
tar czf fox-1.0.0.tar.gz fox/
./fox/scripts/sign-release.sh fox-1.0.0.tar.gz
# gera fox-1.0.0.tar.gz.asc e fox-1.0.0.tar.gz.sha256 — suba os três
# junto com a release no Codeberg/Forgejo/GitHub.
```

## Instalação

Dependências: `fzf`, `yazi`, `gpg`, `tar` (`sudo pacman -S fzf yazi gpg tar` no Arch).

### Via git clone

```bash
git clone https://SEU-HOST/SEU_USUARIO/fox.git
cd fox
sudo make install
```

Pra desinstalar: `sudo make uninstall` (a config em `~/.config/fox/`
de cada usuário não é tocada — remova à mão se quiser).

### Via curl (uma linha, baixa e instala a release publicada)

```bash
curl -fsSL https://SEU-HOST/SEU_USUARIO/fox/raw/branch/main/install.sh | sudo bash
```

O `install.sh` verifica a assinatura GPG da release automaticamente se
`FOX_SIGNING_FINGERPRINT` estiver definido no ambiente:

```bash
curl -fsSL https://SEU-HOST/SEU_USUARIO/fox/raw/branch/main/install.sh \
  | sudo FOX_SIGNING_FINGERPRINT="SEU_FINGERPRINT_AQUI" bash
```

> **Nota pra quem for publicar o repositório**: as URLs acima e os
> defaults de `FOX_RELEASE_TARBALL` dentro de `install.sh` têm
> placeholders (`SEU-HOST`, `SEU_USUARIO`) — ajuste pro host real
> (Codeberg/Forgejo/GitHub) antes de divulgar o link de instalação.

## Uso

```
fox             abre o menu principal
fox --dry       modo dry-run (nada de efeito real fora de pastas temporárias)
fox --version   mostra a versão
fox --help      mostra teclas e explica as funções do TUI
```

Customização de cores/keybinds/criptografia: veja
[`docs/CUSTOMIZATION.md`](./docs/CUSTOMIZATION.md).
