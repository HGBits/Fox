#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# install.sh — instalador do Fox.
#
# Uso via curl (baixa e instala o release publicado):
#   curl -fsSL https://SEU-HOST/fox/raw/branch/main/install.sh | sudo bash
#
# Uso local (rodando de dentro de um git clone ou tarball já extraído):
#   sudo ./install.sh
#
# Variáveis de ambiente que sobrescrevem os defaults (útil pro
# curl-pipe, já que nesse modo não dá pra passar flags depois do bash):
#   FOX_VERSION              versão a instalar (default: 1.0.0)
#   FOX_RELEASE_TARBALL       URL direta do tarball da release
#   FOX_SIGNING_FINGERPRINT   fingerprint da chave GPG do autor, pra
#                             verificação automática da assinatura
set -euo pipefail

# --- TODO: ajuste estes defaults pra URL real do seu repositório antes
# de publicar o link de curl-pipe. Deixei Codeberg como exemplo porque é
# o que você mais usa, mas troque pelo host/usuário/repo reais. ---
FOX_VERSION="${FOX_VERSION:-1.0.0}"
FOX_RELEASE_TARBALL="${FOX_RELEASE_TARBALL:-https://codeberg.org/SEU_USUARIO/fox/archive/v${FOX_VERSION}.tar.gz}"
FOX_SIGNING_FINGERPRINT="${FOX_SIGNING_FINGERPRINT:-}"

PREFIX_LIB="/usr/lib/fox"
PREFIX_BIN="/usr/bin/fox"
PREFIX_ETC="/etc/fox"
PREFIX_DOC="/usr/share/doc/fox"
PREFIX_LICENSE="/usr/share/licenses/fox"

log()  { printf '[fox-install] %s\n' "$*" >&2; }
die()  { printf '[fox-install][erro] %s\n' "$*" >&2; exit 1; }

need_root() {
  [[ $EUID -eq 0 ]] || die "Rode como root (sudo bash install.sh, ou sudo antes do curl-pipe)."
}

check_deps() {
  local missing=()
  local c
  for c in fzf yazi gpg tar; do
    command -v "$c" &>/dev/null || missing+=("$c")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Dependências faltando: ${missing[*]} — no Arch: sudo pacman -S ${missing[*]}"
  fi
}

# Instala a partir de um diretório já contendo a estrutura do projeto
# (seja um git clone local, seja um tarball já extraído em /tmp).
install_from_dir() {
  local src="$1"
  [[ -f "$src/fox" && -d "$src/lib" ]] || die "Estrutura inesperada em ${src} (esperava fox + lib/)."

  install -d -m 0755 "$PREFIX_LIB" "$PREFIX_ETC" "$PREFIX_DOC" "$PREFIX_LICENSE"
  install -m 0644 "$src"/lib/*.bash "$PREFIX_LIB"/

  if [[ ! -f "${PREFIX_ETC}/fox.conf" ]]; then
    install -m 0644 "$src/config/fox.conf.default" "${PREFIX_ETC}/fox.conf"
  else
    log "Config existente em ${PREFIX_ETC}/fox.conf preservada."
  fi

  [[ -f "$src/docs/CUSTOMIZATION.md" ]] && install -m 0644 "$src/docs/CUSTOMIZATION.md" "$PREFIX_DOC"/
  [[ -f "$src/README.md" ]] && install -m 0644 "$src/README.md" "$PREFIX_DOC"/
  [[ -f "$src/LICENSE" ]] && install -m 0644 "$src/LICENSE" "$PREFIX_LICENSE"/

  install -m 0755 "$src/fox" "$PREFIX_BIN"
  log "Fox instalado em ${PREFIX_BIN}."
}

# Verifica a assinatura destacada do tarball, se ela e o gpg estiverem
# disponíveis. Nunca bloqueia a instalação por falta de assinatura —
# só avisa — mas SEMPRE avisa quando a verificação falha de verdade.
verify_signature() {
  local tarball="$1"
  if [[ ! -f "${tarball}.asc" ]]; then
    log "Aviso: sem arquivo .asc pra verificar a assinatura — seguindo sem verificação."
    return 0
  fi
  if ! command -v gpg &>/dev/null; then
    log "Aviso: gpg não disponível pra verificar a assinatura — seguindo sem verificação."
    return 0
  fi
  if [[ -n "$FOX_SIGNING_FINGERPRINT" ]]; then
    gpg --keyserver keys.openpgp.org --recv-keys "$FOX_SIGNING_FINGERPRINT" 2>/dev/null || true
  fi
  if gpg --verify "${tarball}.asc" "$tarball" 2>&1; then
    log "Assinatura verificada com sucesso."
  else
    die "Assinatura NÃO confere — abortando instalação. Não prossiga sem entender por quê."
  fi
}

main() {
  need_root
  check_deps

  local here=""
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi

  if [[ -n "$here" && -f "$here/fox" && -d "$here/lib" ]]; then
    log "Checkout local detectado em ${here} — instalando direto, sem baixar nada."
    install_from_dir "$here"
    return
  fi

  log "Rodando via curl-pipe (ou sem checkout local) — baixando release ${FOX_VERSION}..."
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL -o "${tmp}/fox.tar.gz" "$FOX_RELEASE_TARBALL" \
    || die "Falha ao baixar ${FOX_RELEASE_TARBALL}"
  curl -fsSL -o "${tmp}/fox.tar.gz.asc" "${FOX_RELEASE_TARBALL}.asc" 2>/dev/null || true

  verify_signature "${tmp}/fox.tar.gz"

  tar xzf "${tmp}/fox.tar.gz" -C "$tmp"
  local extracted
  extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [[ -n "$extracted" ]] || die "Não encontrei o diretório extraído do tarball."

  install_from_dir "$extracted"
}

main "$@"
