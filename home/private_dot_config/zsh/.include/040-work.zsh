### Work template begin

# TODO: replace with dynamic template
declare -rg BW_ACCOUNT_MB_ITEM=639b081e-c00d-433d-8a2c-b2da00fb3889

typeset -gA reply_assoc=()

() {
    # capture all files in functions/ dir including those starting with dot
    typeset -a function_files=( $ZDOTDIR/functions/work/*(.D) )
    typeset function_files_str=${(F)function_files}

    # Leave only basenames
    typeset -a function_names=( ${^function_files:t} )
    typeset function_names_str=${(F)function_names}

    # Remove existing functions which conflict with our function_names
    typeset -a existing_functions=( ${${(k)functions}:*function_names} )
    (( $#existing_functions )) && unfunction $existing_functions

    # Now when all conflicting functiones are removed we can autoload our functions
    builtin autoload -Uz $function_files
}

# old time: 4.24s user 1.12s system 45% cpu 11.769 total
# new time: 2.29s user 0.67s system 42% cpu 6.982 total
# shellcheck disable=SC1064,SC1073
function gerrit_api_$'ci'$'vic'() {
    bw_get_gerrit $'ci'$'vic'
    GERRIT_API_HOST="${reply[1]}" \
    GERRIT_API_USERNAME="${reply[2]}" \
    GERRIT_API_PASSWORD="${reply[3]}" \
        gerrit_api "${@}"
}

# shellcheck disable=SC1064,SC1073
function gerrit_api_$'ui'$'ci'() {
    bw_get_gerrit $'ui'$'ci'
    GERRIT_API_HOST="${reply[1]}" \
    GERRIT_API_USERNAME="${reply[2]}" \
    GERRIT_API_PASSWORD="${reply[3]}" \
        gerrit_api "${@}"
}

### Work template end
