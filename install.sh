#!/usr/bin/env bash
set -euo pipefail

# ───────────────────────────────────────────────────────────────────────────────
# Reds Dotfiles Installer (Nobara/Fedora/Debian)
# Installs: fonts, kitty config, starship.toml, zshrc, fastfetch script + config
# Ensures: oh-my-zsh + plugins, required packages
# ───────────────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# repo layout (from your tree)
FONTS_DIR="$REPO_ROOT/fonts"
KITTY_DIR="$REPO_ROOT/kitty"
STARSHIP_FILE="$REPO_ROOT/starship/starship.toml"
ZSHRC_REPO_A="$REPO_ROOT/.zshrc"
ZSHRC_REPO_B="$REPO_ROOT/zsh/.zshrc"

MYFETCH_SCRIPT_REPO="$REPO_ROOT/myfetch/fetch.sh"
MYFETCH_CFG_REPO="$REPO_ROOT/myfetch/config-pokemon.jsonc"

# targets
TARGET_FONTS="$HOME/.local/share/fonts"
TARGET_KITTY="$HOME/.config/kitty"
TARGET_STARSHIP="$HOME/.config/starship.toml"
TARGET_ZSHRC="$HOME/.zshrc"

TARGET_MYFETCH_SCRIPT="$HOME/Documents/myfetch/fetch.sh"
TARGET_MYFETCH_DIR="$(dirname "$TARGET_MYFETCH_SCRIPT")"
TARGET_FASTFETCH_CFG_DIR="$HOME/.config/fastfetch"
TARGET_FASTFETCH_CFG="$TARGET_FASTFETCH_CFG_DIR/config-pokemon.jsonc"

# helpers
ts() { date +"%Y%m%d-%H%M%S"; }
msg() { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[✗]\033[0m %s\n" "$*"; }
have(){ command -v "$1" &>/dev/null; }

backup_if_exists() {
  local p="$1"
  [[ -e "$p" || -L "$p" ]] || return 0
  local bak="${p}.bak.$(ts)"
  msg "Backup: $p -> $bak"
  mv -f -- "$p" "$bak"
}

ensure_dir() { install -d -m 755 -- "$1"; }

copy_into() {
  local src="$1" dest="$2"
  ensure_dir "$dest"
  cp -a -- "$src"/. "$dest"/
}

install_file() {
  local src="$1" dest="$2"
  ensure_dir "$(dirname -- "$dest")"
  backup_if_exists "$dest"
  cp -a -- "$src" "$dest"
}

# ── package mgr ────────────────────────────────────────────────────────────────
pm_install() {
  # $@ = packages
  if have dnf5; then
    sudo dnf5 install -y "$@"
  elif have dnf; then
    sudo dnf install -y "$@"
  elif have apt-get; then
    sudo apt-get update
    sudo apt-get install -y "$@"
  elif have pacman; then
    sudo pacman -Sy --noconfirm
    sudo pacman -S --needed --noconfirm "$@"
  else
    err "No supported package manager (dnf5/dnf/apt-get/pacman). Install manually: $*"
    return 1
  fi
}

ensure_pkg() {
  # $1 = binary to check, $2 = package name to install
  local bin="$1" pkg="$2"
  if have "$bin"; then
    msg "Already installed: $pkg"
  else
    msg "Installing: $pkg"
    pm_install "$pkg"
  fi
}

install_required_packages() {
  # base
  ensure_pkg zsh        zsh
  ensure_pkg kitty      kitty
  ensure_pkg starship   starship
  ensure_pkg git        git

  # font cache tool
  if ! have fc-cache; then
    msg "Installing: fontconfig"
    pm_install fontconfig
  else
    msg "Already installed: fontconfig"
  fi
  # used by .zshrc aliases
  ensure_pkg lsd        lsd || true
  ensure_pkg fastfetch  fastfetch || true
  ensure_pkg fzf	fzf || true
  ensure_pkg curl curl || true
}

# ── fonts ──────────────────────────────────────────────────────────────────────
install_fonts() {
  if [[ -d "$FONTS_DIR" ]]; then
    msg "Installing fonts → $TARGET_FONTS"
    ensure_dir "$TARGET_FONTS"
    cp -a -- "$FONTS_DIR"/. "$TARGET_FONTS"/
    msg "Refreshing font cache"
    fc-cache -f "$TARGET_FONTS" || fc-cache -f
  else
    warn "No fonts/ directory at $FONTS_DIR (skipping)"
  fi
}

# ── kitty ──────────────────────────────────────────────────────────────────────
install_kitty() {
  if [[ -d "$KITTY_DIR" ]]; then
    msg "Installing Kitty config → $TARGET_KITTY"
    ensure_dir "$TARGET_KITTY"
    copy_into "$KITTY_DIR" "$TARGET_KITTY"
  else
    warn "No kitty/ at $KITTY_DIR (skipping)"
  fi
}

# ── starship ───────────────────────────────────────────────────────────────────
install_starship() {
  if [[ -f "$STARSHIP_FILE" ]]; then
    msg "Installing Starship → $TARGET_STARSHIP"
    install_file "$STARSHIP_FILE" "$TARGET_STARSHIP"
  else
    warn "Missing starship.toml at $STARSHIP_FILE (skipping)"
  fi
}

# ── zshrc ──────────────────────────────────────────────────────────────────────
install_zshrc() {
  local src=""
  if [[ -f "$ZSHRC_REPO_A" ]]; then
    src="$ZSHRC_REPO_A"
  elif [[ -f "$ZSHRC_REPO_B" ]]; then
    src="$ZSHRC_REPO_B"
  fi
  if [[ -n "$src" ]]; then
    msg "Installing .zshrc → $TARGET_ZSHRC"
    install_file "$src" "$TARGET_ZSHRC"
  else
    warn "No .zshrc found in repo (skipping)"
  fi
}

# ── custom fastfetch ───────────────────────────────────────────────────────────
install_myfetch() {
  local ok=0
  if [[ -f "$MYFETCH_SCRIPT_REPO" ]]; then
    msg "Installing myfetch script → $TARGET_MYFETCH_SCRIPT"
    ensure_dir "$TARGET_MYFETCH_DIR"
    backup_if_exists "$TARGET_MYFETCH_SCRIPT"
    cp -a -- "$MYFETCH_SCRIPT_REPO" "$TARGET_MYFETCH_SCRIPT"
    chmod +x "$TARGET_MYFETCH_SCRIPT"
    ok=1
  else
    warn "Missing myfetch script at $MYFETCH_SCRIPT_REPO"
  fi

  if [[ -f "$MYFETCH_CFG_REPO" ]]; then
    msg "Installing fastfetch config → $TARGET_FASTFETCH_CFG"
    ensure_dir "$TARGET_FASTFETCH_CFG_DIR"
    install_file "$MYFETCH_CFG_REPO" "$TARGET_FASTFETCH_CFG"
  else
    warn "Missing myfetch config at $MYFETCH_CFG_REPO"
  fi

  if (( ok == 1 )); then
    msg "Note: your .zshrc aliases point fastfetch/neofetch → $TARGET_MYFETCH_SCRIPT"
  fi
}

# ── oh-my-zsh + plugins ───────────────────────────────────────────────────────
ensure_ohmyzsh() {
  local omz="$HOME/.oh-my-zsh"
  if [[ -d "$omz" ]]; then
    msg "oh-my-zsh already present"
    return 0
  fi
  msg "Installing oh-my-zsh → $omz"
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"
}

update_or_clone() {
  # $1 = dir, $2 = git url
  local dir="$1" url="$2"
  if [[ -d "$dir/.git" ]]; then
    msg "Updating $(basename "$dir")"
    git -C "$dir" pull --ff-only || git -C "$dir" fetch --all --prune
  else
    ensure_dir "$(dirname "$dir")"
    msg "Cloning $(basename "$dir")"
    git clone --depth=1 "$url" "$dir"
  fi
}

ensure_omz_plugins() {
  local ZSH_CUSTOM_DEFAULT="$HOME/.oh-my-zsh/custom"
  local ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_CUSTOM_DEFAULT}"

  # plugin → repo
  update_or_clone "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
    https://github.com/zsh-users/zsh-autosuggestions.git
  update_or_clone "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
    https://github.com/zsh-users/zsh-syntax-highlighting.git
  update_or_clone "$ZSH_CUSTOM/plugins/zsh-history-substring-search" \
    https://github.com/zsh-users/zsh-history-substring-search.git

  msg "oh-my-zsh plugins ensured. (Your .zshrc already lists them.)"
}

# ── main ───────────────────────────────────────────────────────────────────────
main() {
  msg "Starting Reds Dotfiles install…"
  install_required_packages
  install_fonts
  install_kitty
  install_starship
  install_zshrc
  ensure_ohmyzsh
  ensure_omz_plugins
  install_myfetch
  msg "Done ✅"
  echo "• Reload shell:  exec zsh"
  echo "• Reload Kitty:  kitty @ reload"
}
main "$@"
