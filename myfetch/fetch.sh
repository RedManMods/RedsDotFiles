export ZSH="$HOME/.oh-my-zsh"

# --- Custom Pokemon-script fetch ---
pokefetch() {
    local artfile
    artfile="$(mktemp)"
    name_ray=(mew mewtwo charmander charmeleon charizard pikachu squirtle wartortle blastoise kakuna beedrill pidgey pidgeotto pigdeot rattata raicate spearow fearow ekans arbok sandsshrew sandslash clefairy clefable vulpix jigglypuff wigglypuff oddish gloom vileplume venonat diglett dugtrio meowth persian psyduck mankey primeape growlithe arcanine poliwag poliwhirl poliwrath abra kadabra alakazam machop machoke machamp bellsprout weepinbell  victreebel tentacool tentacruel geodude graveler golem ponyta rapidash slowpoke slowbro shellder cloyster gastly haunter gengar onix caterpie metapod butterfree weedle raichu ninetales bulbasaur ivysaur venusaur golduck snorlax eevee)
    random_name=${name_ray[$RANDOM % ${#name_ray[@]} + 1]}

    pokemon-colorscripts --no-title --name "$random_name" > "$artfile"
#    fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
    fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo "$artfile" --logo-padding 2

    rm -f "$artfile"
}

pokefetch

# pokemon-colorscripts --no-title -s -r | fastfetch -c $HOME/.config/fastfetch/config-v2.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
