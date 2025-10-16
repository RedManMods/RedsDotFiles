# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

# ZSH_THEME="agnosterzak"
ZSH_THEME=""

plugins=( 
    git
    dnf
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

# check the dnf plugins commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/dnf


source <(fzf --zsh)
# --- History (save & share across shells) ---
export HISTFILE=$HOME/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
setopt APPEND_HISTORY           # don't overwrite history file
setopt INC_APPEND_HISTORY       # write after each command
setopt SHARE_HISTORY            # share between sessions
setopt HIST_IGNORE_DUPS         # skip immediate duplicate
setopt HIST_IGNORE_ALL_DUPS     # remove older dupes
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

# --- Completion engine ---
autoload -Uz compinit
# rebuild cache fast if needed
if [[ ! -f ~/.zcompdump || ~/.zcompdump -ot ~/.zshrc ]]; then
  compinit -i
else
  compinit -C -i
fi

source $ZSH/oh-my-zsh.sh

# For my scripts
alias switchnand=". $HOME/Documents/Utils/scripts/switch_nand.sh"

# My FastFetch
alias fastfetch="$HOME/Documents/myfetch/fetch.sh"
alias neofetch="$HOME/Documents/myfetch/fetch.sh"

# Functions
autoload -Uz colors && colors   # Enables colors for terminal.

# --- Custom Pokemon-script fetch ---
pokefetch() {
    local artfile
    artfile="$(mktemp)"
    name_ray=(mew mewtwo charmander charmeleon charizard pikachu squirtle wartortle blastoise kakuna beedrill pidgey pidgeotto pigdeot rattata raicate spearow fearow ekans arbok sandsshrew sandslash clefairy clefable vulpix jigglypuff wigglypuff oddish gloom vileplume venonat diglett dugtrio meowth persian psyduck mankey primeape growlithe arcanine poliwag poliwhirl poliwrath abra kadabra alakazam machop machoke machamp bellsprout weepinbell  victreebel tentacool tentacruel geodude graveler golem ponyta rapidash slowpoke slowbro shellder cloyster gastly haunter gengar onix caterpie metapod butterfree weedle raichu ninetales bulbasaur ivysaur venusaur golduck snorlax eevee)
    random_name=${name_ray[$RANDOM % ${#name_ray[@]} + 1]}

#    pokemon-colorscripts --no-title --s --name "$random_name" > "$artfile"
    fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo - 
#    fastfetch --logo "$artfile" --logo-padding 2

    rm -f "$artfile"
}

# Connect to reds vps
redsvps() {
 local user="senpai"
 local ip="64.62.199.196"

 echo "🖥 Connecting to redsvps..."
 ssh "$user"@"$ip"
}

# Auto-run when a new terminal opens
clear
pokefetch

# --- Starship prompt (must stay last) ---
eval "$(starship init zsh)"
