#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------
# redsdotfiles installer
# --------------------------------------------
# Defaults:
#   - Symlink configs (kitty/, starship.toml, optional zsh/.zshrc)
#   - Install packages (kitty, starship) if possible
#   - Install user fonts from ./fonts into ~/.local/share/fonts
#
# Flags:
#   --copy           Copy instead of symlink
#   --no-packages    Skip package install step
#   --no-fonts       Skip fonts install
#   --no-zsh         Don’t touch ~/.zshrc (won’t add starship init)
#   --force          Replace existing files without asking (still backups)
#
# Environment:
#   DOTFILES=/path/to/redsdotfiles  (auto-detected if unset)
# --------------------------------------------

# ---- Parse args ----
COPY=0
INSTALL_PACKAGES=1
INSTALL_FONTS=1
TOUCH_ZSH=1
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --copy) COPY=1 ;;
    --no-packages) INSTALL_PACKAGES=0 ;;
    --no-fonts) INSTALL_FONTS=0 ;;
    --no-zsh) TOUCH_ZSH=0 ;;
    --force) FORCE=1 ;;
    -h|--help)
      echo "Usage: $0 [--copy] [--no-packages] [--no-fonts] [--no-zsh] [--force]"
      exit 0
      ;;
    *) echo "Unknown option: $arg"; exit 2 ;;
  esac
done

# ---- Paths & helpers ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-"$(cd "$SCRIPT_DIR/.." && pwd)"}"
TS="$(date +%Y%m%d-%H%M%S)"

msg() { printf "\n\033[1;36m%s\033[0m\n" "$*"; }        # cyan bold
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }          # yellow
err() { printf "\033[1;31m%s\033[0m\n" "$*"; }           # red
ok() { printf "\033[1;32m%s\033[0m\n" "$*"; }            # green

bkup() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mv -v "$target" "${target}.bak.${TS}"
  fi
}

is_link_to() {
  local link="$1" ; local dest="$2"
  [ -L "$link" ] && [ "$(readlink -f "$link")" = "$(readlink -f "$dest")" ]
}

ensure_dir() { mkdir -p "$1"; }

detect_pm() {
  if command -v pacman >/dev/null 2>&1; then echo pacman
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v apt >/dev/null 2>&1; then echo apt
  else echo none
  fi
}

link_or_copy() {
  local src="$1" dst="$2"
  if [ "$COPY" -eq 1 ]; then
    if [ -d "$src" ]; then
      cp -a "$src" "$dst"
    else
      cp -a "$src" "$dst"
    fi
  else
    ln -sfn "$src" "$dst"
  fi
}

append_once() {
  local file="$1" ; shift
  local marker="$1" ; shift
  if ! grep -Fq "$marker" "$file" 2>/dev/null; then
    {
      echo ""
      echo "$marker"
      printf "%s\n" "$@"
      echo "$marker"
    } >> "$file"
  fi
}

# ---- Actions ----

install_pkgs() {
  local pm; pm="$(detect_pm)"
  msg "Installing packages (kitty, starship) using: $pm"
  case "$pm" in
    pacman) sudo pacman -S --needed --noconfirm kitty starship || true ;;
    dnf)    sudo dnf install -y kitty starship || true ;;
    apt)    sudo apt update && sudo apt install -y kitty starship || true ;;
    none)   warn "No supported package manager detected. Skipping package install." ;;
  esac
}

install_fonts() {
  local src="$DOTFILES/fonts"
  local dst="$HOME/.local/share/fonts"
  if [ ! -d "$src" ]; then
    warn "No fonts directory found at $src — skipping."
    return 0
  fi
  msg "Installing user fonts → $dst"
  ensure_dir "$dst"
  # Copy recursively (handles directories like JetBrainsMonoNerd, VictorMono, etc.)
  cp -Rvn "$src/"* "$dst/" 2>/dev/null || true
  fc-cache -f || true
  ok "Fonts installed (fc-cache refreshed)."
}

setup_kitty() {
  local src="$DOTFILES/kitty"
  local dst="$HOME/.config/kitty"
  if [ ! -d "$src" ]; then
    warn "No kitty/ directory in dotfiles — skipping Kitty."
    return 0
  fi
  msg "Setting up Kitty config"
  ensure_dir "$HOME/.config"

  if [ "$FORCE" -eq 1 ] || ! is_link_to "$dst" "$src"; then
    bkup "$dst"
    link_or_copy "$src" "$dst"
    ok "Kitty config ready at: $dst"
  else
    ok "Kitty already linked → $(readlink -f "$dst")"
  fi
}

setup_starship() {
  local src="$DOTFILES/starship/starship.toml"
  local dst="$HOME/.config/starship.toml"
  if [ ! -f "$src" ]; then
    warn "No starship/starship.toml in dotfiles — skipping Starship."
    return 0
  fi
  msg "Setting up Starship config"
  ensure_dir "$HOME/.config"

  if [ "$FORCE" -eq 1 ] || ! is_link_to "$dst" "$src"; then
    bkup "$dst"
    link_or_copy "$src" "$dst"
    ok "Starship config ready at: $dst"
  else
    ok "Starship already linked → $(readlink -f "$dst")"
  fi

  if [ "$TOUCH_ZSH" -eq 1 ]; then
    local zrc="$HOME/.zshrc"
    touch "$zrc"

    # Ensure STARSHIP_CONFIG + init is present
    append_once "$zrc" "# >>> redsdotfiles starship >>>" \
      'export STARSHIP_CONFIG="$HOME/.config/starship.toml"' \
      'eval "$(starship init zsh)"' \
      "# <<< redsdotfiles starship <<<"
    ok "Ensured Starship is initialized in ~/.zshrc"
  fi
}

setup_zshrc_from_repo() {
  # Optional: if you keep a repo version at zsh/.zshrc, symlink/copy it.
  local src="$DOTFILES/zsh/.zshrc"
  local dst="$HOME/.zshrc"
  if [ -f "$src" ]; then
    msg "Installing zsh/.zshrc from repo"
    if [ "$FORCE" -eq 1 ] || ! is_link_to "$dst" "$src"; then
      bkup "$dst"
      link_or_copy "$src" "$dst"
      ok "~/.zshrc replaced from repo"
    else
      ok "~/.zshrc already linked → $(readlink -f "$dst")"
    fi
  fi
}

ensure_ohmyzsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "oh-my-zsh already installed."
    return 0
  fi
  msg "Installing oh-my-zsh (non-interactive)..."
  # Non-interactive install; keeps your current shell and zshrc
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
      warn "oh-my-zsh install failed (no internet?) — skipping."
      return 0
    }
  ok "oh-my-zsh installed."
}

install_zsh_theme() {
  local src="$DOTFILES/zsh/themes/agnosterzak.zsh-theme"
  local dst_dir="$HOME/.oh-my-zsh/themes"
  local dst="$dst_dir/agnosterzak.zsh-theme"

  if [ ! -f "$src" ]; then
    warn "Theme not found in repo: $src — skipping."
    return 0
  fi
  ensure_dir "$dst_dir"
  cp -v "$src" "$dst"
  ok "Theme installed to $dst"
}

ensure_zsh_theme_selected() {
  local zrc="$HOME/.zshrc"
  touch "$zrc"
  # If ZSH_THEME exists, replace its value; otherwise append a line.
  if grep -q '^ZSH_THEME=' "$zrc"; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnosterzak"/' "$zrc"
  else
    printf '\nZSH_THEME="agnosterzak"\n' >> "$zrc"
  fi
  ok 'ZSH_THEME set to "agnosterzak" in ~/.zshrc'
}

main() {
  msg "Using DOTFILES at: $DOTFILES"

  if [ "$INSTALL_PACKAGES" -eq 1 ]; then
    install_pkgs
  else
    warn "Skipping package install (--no-packages)"
  fi

  setup_kitty
  setup_starship
  setup_zshrc_from_repo

  if [ "$INSTALL_FONTS" -eq 1 ]; then
    install_fonts
  else
    warn "Skipping fonts install (--no-fonts)"
  fi

  ensure_ohmyzsh
  install_zsh_theme
  ensure_zsh_theme_selected

  msg "✅ Done."
  echo "👉 Reload shell:  exec zsh"
  echo "👉 Reload Kitty:  kitty @ reload  (or restart Kitty)"
}

main "$@"
