### Async functions template begin

function safe_echo {
    local msg="${1%%$'\n'}"
    local number_of_line_feeds=${2:-1}

    if (( number_of_line_feeds > 0 )); then
        printf "%.0s\n" {1..$(( number_of_line_feeds ))}  # Print the specified number of line feeds
    fi
    printf "%s\n" "$msg"
    if (( number_of_line_feeds > 0 )); then
        printf "%.0s\n" {1..$(( number_of_line_feeds ))}
    fi
    zle && zle reset-prompt
}

# Allows to chain consecutive asynchronous calls to set environment variables.
# Use case scenario: we need to assign multiple env vars in the background, each by a
# specific function, but the functions depend on each other and cannot be done in parallel.
#
# Usage:
#   set_env_var_async worker_name \
#           env_var_name function_name \
#           [env_var_name_n function_name_n ...]
function set_env_var_async() {
    declare -lr worker="$1"
    declare -g "set_env_async_${worker}_var_name"="$2"
    declare -g worker_var_ref="set_env_async_${worker}_var_name"
    declare -l func_name="$3"
    shift 3

    if [[ "$ASYNC_DEBUG" == true ]]; then
        function "debug_$worker"() { safe_echo $@; }
    else
        function "debug_$worker"() { true; }
    fi

    # Save remaining arguments for chained calls
    eval "declare -ag set_env_async_${worker}_args=( $@ )"

    # If function does not exist, reset to dummy variable and function
    if ! typeset -f "$func_name" &>/dev/null; then
        "debug_$worker" "  ⚠️ Function $func_name does not exist, the variable ${(P)worker_var_ref} won't be set" 0
        func_name="true"
        eval "set_env_async_${worker}_var_name=set_env_async_dummy"
    fi

    # Define a function to process the result of the job
    # See https://github.com/mafredri/zsh-async?tab=readme-ov-file#functions
    # $1: Job name
    # $2: Exit code of the job
    # $3: Stdout of the job
    #
    # shellcheck disable=2296,2317
    function "set-env-async-${worker}-callback"() {
        # dummy values for non-existent functions are ignored
        if [[ "$2" -eq 0 && "${(P)worker_var_ref}" != "set_env_async_dummy" ]]; then
            eval "typeset -gx ${(P)worker_var_ref}=\"$3\""
            "debug_$worker" "✅ ${(P)worker_var_ref} is set by $1 to ${(P)${(P)worker_var_ref}}"
        else
            if [[ "$2" -ne 0 ]]; then
                "debug_$worker" "❌ ${(P)worker_var_ref} cannot be set by $1, exit code: $2"
            fi
        fi

        unset "set_env_async_${worker}_var_name"
        async_stop_worker "$worker"

        if [[ ${#${(P)$(echo set_env_async_${worker}_args)}} -gt 0 ]]; then
            # execute the next functions in the chain
            set_env_var_async $worker "${${(P)$(echo set_env_async_${worker}_args)}[@]}"
        else
            unset "set_env_async_${worker}_args"
            unset worker_var_ref
            "debug_$worker" "🏁 all async calls completed"
        fi
    }

    async_start_worker "$worker" -n
    async_register_callback "$worker" "set-env-async-${worker}-callback"
    async_job "$worker" "$func_name"
}

### Async functions template end
