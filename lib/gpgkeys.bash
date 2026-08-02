#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/gpgkeys.bash — gerência de chaves .asc dentro de ~/.config/fox/keys/
# e o mapeamento de qual chave vai pra qual usuário destino no backup final.

FOX_KEY_TARGETS_FILE="${FOX_USER_CONF_DIR}/key-targets"

fox::gpgkeys::init() {
  [[ -f "$FOX_KEY_TARGETS_FILE" ]] || : > "$FOX_KEY_TARGETS_FILE"
}

# Lista os .asc presentes em FOX_KEYS_DIR (nomes de arquivo, não caminho completo)
fox::gpgkeys::list() {
  find "$FOX_KEYS_DIR" -maxdepth 1 -type f -name '*.asc' -printf '%f\n' 2>/dev/null | sort
}

# Retorna a lista de usuários-destino já configurada pra uma chave (csv), ou vazio.
fox::gpgkeys::targets_of() {
  local key="$1"
  awk -F'|' -v k="$key" '$1==k{print $2}' "$FOX_KEY_TARGETS_FILE" | tail -n1
}

fox::gpgkeys::set_targets() {
  local key="$1" targets_csv="$2"
  local tmp
  tmp="$(mktemp)"
  grep -v -F "${key}|" "$FOX_KEY_TARGETS_FILE" > "$tmp" 2>/dev/null || true
  printf '%s|%s\n' "$key" "$targets_csv" >> "$tmp"
  mv "$tmp" "$FOX_KEY_TARGETS_FILE"
}

# Exporta uma chave secreta (gpg --export-secret-keys) direto do keyring de
# um /home/ escolhido, gravando o .asc dentro do projeto (FOX_KEYS_DIR). O
# usuário aponta de qual /home/ (keyring) a chave sai — precisa de sudo pra
# ler o keyring de outro usuário que não o que está rodando o fox.
fox::gpgkeys::export_secret_key() {
  local users
  mapfile -t users < <(fox::list_system_users)
  local source_user
  source_user="$(fox::ui::menu "Exportar chave secreta — de qual /home/ (keyring GPG)?" "${users[@]}")"
  [[ -z "$source_user" ]] && return

  local fingerprint
  fingerprint="$(fox::ui::input "Fingerprint (ou ID) da chave secreta")"
  [[ -n "$fingerprint" ]] || { fox::err "Fingerprint vazio."; return; }

  local default_name="${fingerprint}.asc"
  local filename
  filename="$(fox::ui::input "Nome do arquivo dentro do projeto (Enter = ${default_name})")"
  filename="${filename:-$default_name}"
  [[ "$filename" == *.asc ]] || filename="${filename}.asc"
  local dest="${FOX_KEYS_DIR}/${filename}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    fox::log "[dry-run] sudo -u ${source_user} gpg --armor --export-secret-keys ${fingerprint} > ${dest}"
    return
  fi

  # shellcheck disable=SC2024  # redirect abre no shell chamador (precisa
  # rodar como root/sudo) antes do fork; gpg roda como source_user e
  # escreve no fd já aberto — mesmo padrão usado no decrypt do restore.
  sudo -u "$source_user" gpg --armor --export-secret-keys "$fingerprint" > "$dest"
  chmod 600 "$dest"
  fox::log "Exportado: ${dest} (do keyring de ${source_user})"
}

# Menu de gerência de chaves: exportar uma nova chave secreta pro projeto,
# ou escolher entre as .asc já presentes quais entram no backup e pra quais
# usuários cada uma deve ser copiada na hora do restore.
fox::gpgkeys::manage_menu() {
  fox::gpgkeys::init

  local action
  action="$(fox::ui::menu "Gerência de chaves GPG" \
    "Exportar nova chave secreta pro projeto" \
    "Selecionar chaves existentes pro backup" \
    "Voltar")"

  case "$action" in
    "Exportar nova chave secreta pro projeto") fox::gpgkeys::export_secret_key; return ;;
    "Selecionar chaves existentes pro backup") ;;
    *) return ;;
  esac

  mapfile -t keys < <(fox::gpgkeys::list)

  if [[ ${#keys[@]} -eq 0 ]]; then
    fox::log "Nenhum .asc encontrado em ${FOX_KEYS_DIR} — coloque as chaves exportadas lá primeiro."
    fox::ui::input "Enter pra voltar" >/dev/null
    return
  fi

  local selected
  selected="$(fox::ui::checklist "Chaves .asc disponíveis — marque as que entram neste backup" "${keys[@]}")"
  [[ -z "$selected" ]] && return

  local users
  mapfile -t users < <(fox::list_system_users)

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    local current
    current="$(fox::gpgkeys::targets_of "$key")"
    fox::log "Chave: ${key} — destino atual: ${current:-nenhum}"
    local chosen
    chosen="$(fox::ui::checklist "Exportar '${key}' para quais usuários?" "${users[@]}")"
    [[ -z "$chosen" ]] && continue
    local csv
    csv="$(printf '%s' "$chosen" | paste -sd, -)"
    fox::gpgkeys::set_targets "$key" "$csv"
    fox::log "'${key}' -> ${csv}"
  done <<< "$selected"
}

# Retorna, uma por linha, "keyfile|user" pra cada combinação selecionada —
# usado pelo backup.bash na hora de montar o arquivo.
fox::gpgkeys::resolved_pairs() {
  while IFS='|' read -r key targets; do
    [[ -z "$key" ]] && continue
    IFS=',' read -ra tlist <<< "$targets"
    for u in "${tlist[@]}"; do
      printf '%s|%s\n' "$key" "$u"
    done
  done < "$FOX_KEY_TARGETS_FILE"
}
