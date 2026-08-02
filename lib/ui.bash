#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/ui.bash — camada de interface (fzf) e integração com yazi.
# Convenção de keybinds pode ser sobrescrita em fox.conf (ver docs/CUSTOMIZATION.md)
# através das variáveis FOX_KEY_*.

# Defaults de keybind — sobrescrevíveis via fox.conf
FOX_KEY_ADD="${FOX_KEY_ADD:-ctrl-a}"
FOX_KEY_DEL="${FOX_KEY_DEL:-ctrl-d}"
FOX_KEY_CONFIRM="${FOX_KEY_CONFIRM:-enter}"
FOX_KEY_BACK="${FOX_KEY_BACK:-esc}"
FOX_KEY_TOGGLE="${FOX_KEY_TOGGLE:-tab}"

FOX_FZF_COLOR="${FOX_FZF_COLOR:-}"   # string --color custom, opcional (ver CUSTOMIZATION.md)

# Menu simples de escolha única. Args: título, opção1, opção2, ...
# Retorna a opção escolhida via stdout; vazio se cancelado (esc).
fox::ui::menu() {
  local title="$1"; shift
  local footer="[${FOX_KEY_CONFIRM}] selecionar   [${FOX_KEY_BACK}] voltar/sair"
  printf '%s\n' "$@" | fzf \
    --height=~60% --layout=reverse --border \
    --header="${title}" \
    --prompt="${footer} > " \
    ${FOX_FZF_COLOR:+--color="$FOX_FZF_COLOR"} \
    --bind="${FOX_KEY_BACK}:abort"
}

# Checklist multi-seleção. Args: título, item1, item2, ...
# Usa Tab pra marcar/desmarcar (padrão do fzf --multi), Enter confirma seleção.
# Retorna itens selecionados, um por linha.
fox::ui::checklist() {
  local title="$1"; shift
  local footer="[${FOX_KEY_TOGGLE}] marcar   [${FOX_KEY_CONFIRM}] confirmar   [${FOX_KEY_BACK}] cancelar"
  printf '%s\n' "$@" | fzf \
    --multi --height=~60% --layout=reverse --border \
    --header="${title}" \
    --prompt="${footer} > " \
    ${FOX_FZF_COLOR:+--color="$FOX_FZF_COLOR"} \
    --bind="${FOX_KEY_BACK}:abort"
}

# Input de texto simples com prompt customizado (fallback pra 'read', já que
# não faz sentido usar fzf pra digitar texto livre).
fox::ui::input() {
  local prompt="$1"
  local reply
  read -rp "${prompt}: " reply
  printf '%s' "$reply"
}

# Confirmação sim/não via fzf (mantém consistência visual com o resto do TUI).
fox::ui::confirm() {
  local title="$1"
  local choice
  choice="$(fox::ui::menu "$title" "Sim" "Não")"
  [[ "$choice" == "Sim" ]]
}

# Abre o yazi em modo chooser, enraizado no diretório informado, e devolve
# os caminhos escolhidos (um por linha). O --chooser-file do yazi escreve
# TODOS os itens selecionados no momento do Enter, não importa como foram
# selecionados: Space item a item, ou v (visual/range) + y (yank) — ambos
# funcionam na mesma invocação, sem precisar reabrir o yazi por item.
fox::ui::pick_paths_yazi() {
  local root_dir="$1"
  local chooser_file
  chooser_file="$(mktemp)"
  trap 'rm -f "$chooser_file"' RETURN

  if ! command -v yazi &>/dev/null; then
    fox::err "yazi não encontrado no PATH."
    return 1
  fi

  yazi "$root_dir" --chooser-file="$chooser_file" >/dev/tty

  if [[ -s "$chooser_file" ]]; then
    cat "$chooser_file"
  fi
}
