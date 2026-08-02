#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/core.bash — variáveis comuns, dry-run, logging, caminhos padrão.
# Sourced pelo entrypoint 'fox'. Não execute diretamente.

# shellcheck disable=SC2034  # usada no entrypoint 'fox' e no --help
FOX_VERSION="1.0.0"

# Diretórios de sistema (instalação) — padrão FHS do Arch: pacotes
# gerenciados pelo pacman vivem em /usr, não /usr/local (isso é reservado
# pra software instalado manualmente, fora do gerenciador de pacotes).
FOX_LIB_DIR="${FOX_LIB_DIR:-/usr/lib/fox}"
FOX_SYSTEM_CONF="${FOX_SYSTEM_CONF:-/etc/fox/fox.conf}"
FOX_DOC_DIR="${FOX_DOC_DIR:-/usr/share/doc/fox}"

# Diretórios por usuário (do usuário que está RODANDO o fox, não do
# usuário alvo do backup/restore — esses são escolhidos dentro do fluxo)
FOX_USER_CONF_DIR="${HOME}/.config/fox"
FOX_USER_CONF="${FOX_USER_CONF_DIR}/fox.conf"
FOX_BACKUP_LIST="${FOX_USER_CONF_DIR}/backup-list"
FOX_KEYS_DIR="${FOX_USER_CONF_DIR}/keys"

# Destino padrão dos backups gerados (sobrescrevível em fox.conf via
# FOX_BACKUP_DIR, e editável na hora mesmo assim quando o script perguntar).
FOX_BACKUP_DIR="${FOX_BACKUP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fox/backups}"

DRY_RUN=0

# Registro de diretórios temporários criados durante a execução (mktemp -d
# de backup/restore). Limpos de uma vez só no EXIT do programa (ver
# fox::cleanup_tempdirs, armado uma única vez em main()) — em vez de um
# 'trap ... RETURN' por função, que é frágil em shells interativas com
# hooks próprios de trap (ex: ble.sh).
FOX_TEMP_DIRS=()

fox::register_tempdir() {
  FOX_TEMP_DIRS+=("$1")
}

fox::cleanup_tempdirs() {
  local d
  for d in "${FOX_TEMP_DIRS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}

fox::init_dirs() {
  mkdir -p "$FOX_USER_CONF_DIR" "$FOX_KEYS_DIR"
  [[ -f "$FOX_BACKUP_LIST" ]] || : > "$FOX_BACKUP_LIST"
  if [[ ! -f "$FOX_USER_CONF" ]]; then
    if [[ -f "$FOX_SYSTEM_CONF" ]]; then
      cp "$FOX_SYSTEM_CONF" "$FOX_USER_CONF"
    else
      cp "${FOX_LIB_DIR}/../config/fox.conf.default" "$FOX_USER_CONF" 2>/dev/null || true
    fi
  fi
  # shellcheck source=/dev/null
  [[ -f "$FOX_USER_CONF" ]] && source "$FOX_USER_CONF"
}

fox::log()  { printf '[fox] %s\n' "$*" >&2; }
fox::err()  { printf '[fox][erro] %s\n' "$*" >&2; }
fox::die()  { fox::err "$*"; exit 1; }

# Wrapper de execução: em --dry, só imprime o comando; senão, executa.
# Uso: fox::run cp -a "$src" "$dst"
fox::run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run]' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

# Lista usuários "reais" do sistema (UID >= 1000, com home válido e shell
# interativo), pra popular menus de seleção de usuário.
fox::list_system_users() {
  local min_uid
  min_uid="$(awk -F: '/^UID_MIN/{print $2}' /etc/login.defs 2>/dev/null || echo 1000)"
  getent passwd | awk -F: -v min="$min_uid" '
    $3 >= min && $3 < 65534 && $7 !~ /(nologin|false)$/ { print $1 }
  '
}

fox::user_home() {
  getent passwd "$1" 2>/dev/null | cut -d: -f6 || true
}
