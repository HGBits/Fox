#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/restore.bash — restauração de backups gerados pelo Fox (formato novo).
#
# NOTA DE DESIGN: o script manual anterior ao Fox (restore-hypr-shared.sh,
# de antes do projeto existir) tinha um DEST_MAP com casos especiais
# (bash-home, FLATTEN pra henrique-personal, etc.) porque aquele backup
# tinha sido montado à mão, com nomes de pasta que não batiam 1:1 com a
# estrutura real do $HOME. Como agora é o próprio Fox quem gera o backup
# (via yazi, gravando o caminho relativo exato dentro de fox-shared/config/),
# essa tradução não é mais necessária: o caminho relativo dentro do archive
# já É o destino final relativo ao $HOME de quem recebe. Backups antigos,
# gerados por aquele script manual, precisam do script original pra
# restaurar — o Fox não tenta ler esse formato legado.

fox::restore::run() {
  local archive="$1"
  shift
  local target_users=("$@")

  [[ ${#target_users[@]} -ge 1 ]] || fox::die "Informe pelo menos um usuário destino."
  [[ -f "$archive" ]] || fox::die "Arquivo não encontrado: ${archive}"

  for u in "${target_users[@]}"; do
    id "$u" &>/dev/null || fox::die "Usuário '${u}' não existe."
  done

  local gpg_user
  gpg_user="$(fox::ui::input "Usuário dono do keyring GPG (quem descriptografa)")"
  id "$gpg_user" &>/dev/null || fox::die "Usuário inválido: ${gpg_user}"

  local workdir
  workdir="$(mktemp -d)"
  fox::register_tempdir "$workdir"
  chown "${gpg_user}:${gpg_user}" "$workdir"

  # Descriptografia/extração acontecem SEMPRE de verdade, mesmo em --dry:
  # ficam contidas no mktemp (apagado no fim via trap) e não tocam em nada
  # fora dele, então não há efeito colateral real a evitar aqui — e sem
  # isso o dry-run não teria nada pra mostrar/validar. As escritas de
  # verdade (cp/chown pro $HOME dos usuários destino) continuam abaixo,
  # essas sim guardadas por fox::run.
  fox::log "Descriptografando como ${gpg_user}..."
  # shellcheck disable=SC2024  # redirect abre no shell chamador (root) antes do fork;
  # gpg roda como gpg_user e escreve no fd já aberto — mesmo padrão do script original.
  sudo -u "$gpg_user" gpg --decrypt "$archive" > "${workdir}/backup.tar.gz"
  tar xzf "${workdir}/backup.tar.gz" -C "$workdir"

  local extracted="${workdir}/fox-shared/config"
  local keys_root="${workdir}/fox-shared/keys"

  if [[ ! -d "$extracted" ]]; then
    fox::err "Estrutura inesperada — esperava fox-shared/config dentro do archive."
    find "$workdir" -maxdepth 3 >&2
    return 1
  fi

  # Lista todos os arquivos (não diretórios), preservando a árvore de
  # subpastas relativa, pra checklist de restore item-a-item.
  mapfile -t files < <(find "$extracted" -type f -printf '%P\n')

  fox::log "Itens no backup: ${#files[@]} arquivo(s)."

  local selected
  selected="$(fox::ui::checklist "Restaurar quais arquivos? (todos os usuários destino escolhidos abaixo)" "${files[@]}")"
  [[ -z "$selected" ]] && { fox::log "Nada selecionado, abortando."; return; }

  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    for u in "${target_users[@]}"; do
      local home_dir
      home_dir="$(fox::user_home "$u")"
      [[ -d "$home_dir" ]] || { fox::err "Home de ${u} não encontrado, pulando."; continue; }
      local dst="${home_dir}/${rel}"
      fox::run mkdir -p "$(dirname "$dst")"
      fox::run cp -a "${extracted}/${rel}" "$dst"
      fox::run chown "${u}:${u}" "$dst"
      fox::log "[OK] ${rel} -> ${u}:${dst}"
    done
  done <<< "$selected"

  if [[ -d "$keys_root" ]]; then
    fox::log "Chaves GPG encontradas no backup — copiando pra revisão manual (NÃO importa automaticamente)."
    for u in "${target_users[@]}"; do
      local key_src="${keys_root}/${u}"
      [[ -d "$key_src" ]] || continue
      local home_dir
      home_dir="$(fox::user_home "$u")"
      local key_dst="${home_dir}/Documentos/GPG-Import"
      fox::run mkdir -p "$key_dst"
      fox::run cp -a "${key_src}/." "$key_dst/"
      fox::run chown -R "${u}:${u}" "$key_dst"
      fox::log "[OK] chaves -> ${u}:${key_dst} (rode 'gpg --import' manualmente)"
    done
  fi

  fox::log "Restore concluído. Lembre-se dos passos fora do escopo do fox:"
  fox::log "  - scripts de restrição de grupo (pentest-tools / henrique-apps)"
  fox::log "  - reinstalação de pacotes (pacman/AUR/Flatpak/AppImage)"
  fox::log "  - hook de restauração de permissões"
}

fox::restore::menu() {
  local archive
  archive="$(fox::ui::input "Caminho do arquivo .tar.gz.gpg")"
  [[ -f "$archive" ]] || { fox::err "Arquivo não encontrado."; return; }

  mapfile -t users < <(fox::list_system_users)
  local selected
  selected="$(fox::ui::checklist "Restaurar para quais usuários?" "${users[@]}")"
  [[ -z "$selected" ]] && return

  mapfile -t target_users <<< "$selected"
  fox::restore::run "$archive" "${target_users[@]}"
}
