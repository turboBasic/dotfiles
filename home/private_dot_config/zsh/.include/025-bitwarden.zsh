### Bitwarden template begin


## Bitwarden Public methods

function bw_unlock_short() {
    export BW_SESSION=$(
        { [[ -n "$BW_SESSION" ]] && bw unlock --check &> /dev/null; } \
        &&  echo $BW_SESSION \
        ||  {
                bw login --check &> /dev/null \
                &&  bw unlock --raw \
                ||  bw login --raw
            }
    )
}

function bw_get_field() {
    local item=$1
    local field=$2
    rbw get --field "$field" "$item"
}


## Bitwarden Private methods

function _bw_log() {
    local -r text=$1
    local -r file=$2
    printf "[%s]: %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$text" >>"$file"
}

### Bitwarden template end
