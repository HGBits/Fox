#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/backup.bash — fluxo de backup do Fox.
#
# Formato do backup-list: caminhos RELATIVOS ao $HOME do usuário de origem,
# um por linha (ex: "Documentos/Markdowns/nota.md", ".bashrc", "Projetos/foo").
# Isso é diferente do formato do script manual anterior ao Fox (que tinha
# um DEST_MAP com nomes especiais tipo bash-home/FLATTEN) — aqui a
# estrutura relativa já É o destino final, sem tradução. Ver restore.bash.

fox::backup::show_list() {
  if [[ ! -s "$FOX_BACKUP_LIST" ]]; then
    fox::log "Lista de backup vazia."
  else
    fox::log "Itens marcados pra backup:"
    nl -ba "$FOX_BACKUP_LIST" >&2
  fi
}

fox::backup::add_dir() {
  local source_home="$1"
  local picked
  picked="$(fox::ui::pick_paths_yazi "$source_home")" || return 1
  [[ -z "$picked" ]] && { fox::log "Nada selecionado."; return; }

  local added=0
  while IFS= read -r abs_path; do
    [[ -z "$abs_path" ]] && continue
    if [[ "$abs_path" != "$source_home"/* ]]; then
      fox::err "Ignorando '${abs_path}' — fora do \$HOME de ${source_home}."
      continue
    fi
    local rel="${abs_path#"$source_home"/}"
    if grep -qxF "$rel" "$FOX_BACKUP_LIST" 2>/dev/null; then
      fox::log "Já estava na lista: ${rel}"
      continue
    fi
    echo "$rel" >> "$FOX_BACKUP_LIST"
    fox::log "Adicionado: ${rel}"
    added=$((added + 1))
  done <<< "$picked"
  fox::log "Total adicionado nesta rodada: ${added}"
}

fox::backup::remove_dir() {
  if [[ ! -s "$FOX_BACKUP_LIST" ]]; then
    fox::log "Lista já está vazia."
    return
  fi
  mapfile -t items < "$FOX_BACKUP_LIST"
  local selected
  selected="$(fox::ui::checklist "Remover quais itens da lista de backup?" "${items[@]}")"
  [[ -z "$selected" ]] && return

  local tmp
  tmp="$(mktemp)"
  while IFS= read -r line; do
    grep -qxF "$line" <<< "$selected" || echo "$line" >> "$tmp"
  done < "$FOX_BACKUP_LIST"
  mv "$tmp" "$FOX_BACKUP_LIST"
  fox::log "Removido(s)."
}

# Resolve os args de criptografia do GPG. Se FOX_GPG_RECIPIENT estiver
# definido no fox.conf, usa assimétrica pra essa chave direto, sem
# perguntar nada. Senão, pergunta na hora: simétrica (senha) ou assimétrica
# (informando o destinatário nesta execução).
fox::backup::resolve_gpg_args() {
  if [[ -n "${FOX_GPG_RECIPIENT:-}" ]]; then
    fox::log "Usando destinatário fixo do fox.conf: ${FOX_GPG_RECIPIENT}"
    printf '%s\n' "--encrypt" "--recipient" "${FOX_GPG_RECIPIENT}"
    return
  fi

  local mode
  mode="$(fox::ui::menu "Criptografia do backup" "Simétrica (senha)" "Assimétrica (informar destinatário agora)")"
  case "$mode" in
    "Assimétrica (informar destinatário agora)")
      local recipient
      recipient="$(fox::ui::input "ID/e-mail/fingerprint da chave destinatária")"
      [[ -n "$recipient" ]] || fox::die "Destinatário vazio."
      printf '%s\n' "--encrypt" "--recipient" "$recipient"
      ;;
    *)
      printf '%s\n' "--symmetric" "--cipher-algo" "AES256"
      ;;
  esac
}

fox::backup::generate() {
  local source_user="$1"
  local source_home
  source_home="$(fox::user_home "$source_user")"
  [[ -d "$source_home" ]] || fox::die "Home de ${source_user} não encontrado."

  if [[ ! -s "$FOX_BACKUP_LIST" ]]; then
    fox::err "Lista de backup vazia — nada pra gerar. Adicione itens primeiro."
    return 1
  fi

  local workdir
  workdir="$(mktemp -d)"
  fox::register_tempdir "$workdir"
  mkdir -p "${workdir}/fox-shared/config"

  # A montagem do pacote inteiro (cp dos itens/chaves pro workdir temporário
  # e o tar czf) roda SEMPRE de verdade — é inofensiva, fica contida no
  # mktemp e é apagada no fim via trap. Só a gravação do arquivo .gpg final
  # em disco (o efeito colateral real, visível) respeita --dry, mais abaixo.
  fox::log "Copiando itens do backup-list..."
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    local src="${source_home}/${rel}"
    if [[ ! -e "$src" ]]; then
      fox::err "Não existe mais, pulando: ${rel}"
      continue
    fi
    local dst="${workdir}/fox-shared/config/${rel}"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    fox::log "  + ${rel}"
  done < "$FOX_BACKUP_LIST"

  fox::log "Incluindo chaves GPG selecionadas..."
  while IFS='|' read -r key target_user; do
    [[ -z "$key" ]] && continue
    local kdst="${workdir}/fox-shared/keys/${target_user}/${key}"
    mkdir -p "$(dirname "$kdst")"
    cp -a "${FOX_KEYS_DIR}/${key}" "$kdst"
    fox::log "  + chave ${key} -> destino: ${target_user}"
  done < <(fox::gpgkeys::resolved_pairs)

  local out_name out_path
  out_name="fox-backup-$(date +%Y%m%d-%H%M%S).tar.gz.gpg"
  local dest_dir
  dest_dir="$(fox::ui::input "Salvar backup em qual diretório (Enter = ${FOX_BACKUP_DIR})")"
  dest_dir="${dest_dir:-$FOX_BACKUP_DIR}"
  if [[ ! -d "$dest_dir" ]]; then
    fox::run mkdir -p "$dest_dir"
    if [[ "$DRY_RUN" -eq 0 && ! -d "$dest_dir" ]]; then
      fox::die "Não foi possível criar o diretório: ${dest_dir}"
    fi
  fi
  out_path="${dest_dir}/${out_name}"

  fox::log "Compactando..."
  tar czf "${workdir}/backup.tar.gz" -C "$workdir" fox-shared

  fox::log "Criptografando..."
  local gpg_args_raw
  gpg_args_raw="$(fox::backup::resolve_gpg_args)" || fox::die "Falha ao definir criptografia do backup."
  mapfile -t gpg_args <<< "$gpg_args_raw"
  fox::run gpg "${gpg_args[@]}" --output "$out_path" "${workdir}/backup.tar.gz"

  fox::log "Backup gerado: ${out_path}"
}

fox::backup::menu() {
  fox::gpgkeys::init
  local source_user
  mapfile -t users < <(fox::list_system_users)
  source_user="$(fox::ui::menu "Backup — usuário de origem (dono dos dados)" "${users[@]}")"
  [[ -z "$source_user" ]] && return
  local source_home
  source_home="$(fox::user_home "$source_user")"

  while true; do
    local choice
    choice="$(fox::ui::menu "Backup — origem: ${source_user}" \
      "Ver lista atual" \
      "Adicionar diretório (yazi)" \
      "Remover diretório da lista" \
      "Gerenciar chaves GPG" \
      "Gerar backup agora" \
      "Voltar")"

    case "$choice" in
      "Ver lista atual")            fox::backup::show_list ;;
      "Adicionar diretório (yazi)")  fox::backup::add_dir "$source_home" ;;
      "Remover diretório da lista")  fox::backup::remove_dir ;;
      "Gerenciar chaves GPG")        fox::gpgkeys::manage_menu ;;
      "Gerar backup agora")          fox::backup::generate "$source_user" ;;
      "Voltar"|"")                   return ;;
    esac
  done
}
