### Work template begin

# TODO: replace with dynamic template
declare -r BW_ACCOUNT_MB_ITEM=639b081e-c00d-433d-8a2c-b2da00fb3889

# shellcheck disable=2155
function aws_set_profile() {
    local -r alias=$1
    local -r role=${2:-""}

    case $alias in
        ui$'ci'-int|ui$'ci'-prod)
            aws_set_credentials "$alias" "${role:-DhcFullAdmin}"
            export AWS_PROFILE="$alias"
            ;;
        ci$'vi'c-dev|ci$'vi'c-int|ci$'vi'c-prod)
            aws_set_credentials "$alias" "${role:-SwfDev}"
            export AWS_PROFILE="$alias"
            ;;
        *)
            echo "Invalid profile alias: $alias"
            return 1
            ;;
    esac
}

# Populate AWS credentials config with the secrets
function aws_set_credentials() {
    local -r alias="$1"
    local -r role="${2:-DhcFullAdmin}"
    local -r DEFAULT_REGION="eu-central-1"

    if ! _aws_get_idp_credentials "$alias" "$role" || [[ -z "${reply_assoc[Account]}" ]]; then
        echo "Failed to get AWS credentials for alias: $alias"
        return 1
    fi

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    aws --profile="$alias" configure set aws_access_key_id "${reply_assoc[Access Key]}"
    aws --profile="$alias" configure set aws_secret_access_key "${reply_assoc[Secret Key]}"
    aws --profile="$alias" configure set aws_session_token "${reply_assoc[Session Token]}"
    aws --profile="$alias" configure set region "$DEFAULT_REGION"
    reply_assoc=()
}

# Login to AWS ECR using the current AWS profile
function aws_ecr_login() {
    [[ -z "$AWS_PROFILE" ]] && {
        echo "❌ AWS_PROFILE is not set. Please set it before running this command."
        return 1
    }

    account_id=$(aws sts get-caller-identity --query Account --output text)
    region=$(aws configure get region)
    aws ecr get-login-password \
    |   docker login --username AWS --password-stdin "$account_id".dkr.ecr."$region".amazonaws.com
}

# Logout from IdpCli, eg. in case if accidentally wrong SSO login was used
function idp_logout() {
    token_file="$HOME/Library/Application Support/idpcli/temp"
    echo "Removing ... $token_file"
    rm "$token_file"
}

# retrieves AWS session secrets into the global variable reply_assoc
function _aws_get_idp_credentials() {
    local -r alias="$1"
    local -r role="$2"
    local -r account_id=$(_aws_get_account_id "$alias")

    # ${(f)"..."} splits text to strings by newlines
    # idp_output=( "Account: 11111111" "Role: DhcReadonly" "Access Key: EywFbKCi" ... )
    local -ra idp_output=( ${(f)"$(
        command idp get-credentials --account "$account_id" --role "$role" \
        |   command grep --perl-regexp '^[\w\s]+: '
    )"} )

    # reply_assoc=( [Account]=1111111 [Role]=DhcReadonly [Access Key]=EywFbKCi [Session Token]=2unXIg4nY6L1 )
    typeset -gA reply_assoc=()
    for item in $idp_output; do
        reply_assoc[${item%:*}]=${item#*: }
    done
}

# Get AWS account ID by its alias
function _aws_get_account_id() {
    local -r alias="$1"
    local -r bw_aws_item_name=$(bw_get_field "$BW_ACCOUNT_MB_ITEM" bw_aws_item_name)
    local -a account_aliases_raw
    local -A account_aliases

    # ${(f)"..."} splits text to strings by newlines
    # account_aliases_raw=( 'alias1 1111111' 'alias2 2222222' )
    account_aliases_raw=( ${(f)"$(
        rbw get --raw "$bw_aws_item_name" \
        |   jq --raw-output '.fields[] | (.name | ltrimstr("mb_") | rtrimstr("_account_id")) + " " + .value'
    )"} )

    # account_aliases=( [alias1]=1111111 [alias2]=2222222 )
    for item in $account_aliases_raw; do
        account_aliases[${item%% *}]=${item#* }
    done

    echo "${account_aliases[$alias]}"
}

# shellcheck disable=2155
function tfe() {
    local bw_tfe_uici_item_name=$(bw_get_field "$BW_ACCOUNT_MB_ITEM" bw_tfe_uici_item_name)
    local tfe_uici_uri=$(rbw get --raw "$bw_tfe_uici_item_name" | jq --raw-output '.data.uris[0].uri')

    # TFE_TOKEN is assigned asynchronously
    curl --silent \
        --header "Authorization: Bearer $TFE_TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        "$tfe_uici_uri/api/v2/$1"
}

# shellcheck disable=2155
function tfe_get_token() {
    # TODO: get item name indirectly instead of GUID
    local bw_tfe_uici_item_name=$(bw_get_field "$BW_ACCOUNT_MB_ITEM" bw_tfe_uici_item_name)
    bw_get_field "$bw_tfe_uici_item_name" 24-12-09-default-token
}

function gerrit_api() {
    local -r endpoint="${1?Endpoint is required}"
    local -r request="${2:-GET}"
    local -r json="$3"
    local -r gerrit_api_host=${GERRIT_API_HOST?Gerrit host is required}
    local -r gerrit_api_username=${GERRIT_API_USERNAME?Gerrit username is required}
    local -r gerrit_api_password=${GERRIT_API_PASSWORD?Gerrit password is required}

    local -a curl_args=( )
    if [[ "$request" == "POST" ]]; then
        [[ -n "$json" ]] || json=$(cat)
        [[ -z "$json" ]] && { echo "JSON data is required for POST request"; return 1; }
        curl_args+=( --json "$json" )
    fi
    command curl \
            --silent \
            --user "$gerrit_api_username:$gerrit_api_password" \
            --request "$request" \
            $curl_args \
            "https://$gerrit_api_host/a/$endpoint" \
    |   sed 1d
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

function bw_get_gerrit() {
    local -r gerrit_id_input=${1?Gerrit ID is required}
    # Split the gerrit_id into an array by "-" character
    local -ra gerrit=( ${(s:-:)gerrit_id_input})
    local -r gerrit_id=${gerrit[1]}
    local -r gerrit_suffix=${gerrit[2]:+"-${gerrit[2]}"}

    local -r gerrit_server_fields=$(rbw get --raw "$BW_ACCOUNT_MB_ITEM" | jq --compact-output '.fields[]')
    local -r gerrit_host=$(
        jq --raw-output 'select(.name == "gerrit_'$gerrit_id$gerrit_suffix'_host") | .value' \
        <<< "$gerrit_server_fields"
    )
    local -r gerrit_secret_id=$(
        jq --raw-output 'select(.name == "bw_gerrit_'$gerrit_id$gerrit_suffix'_pass_item_name") | .value' \
        <<< "$gerrit_server_fields"
    )

    local -r gerrit_account_fields=$(rbw get --raw "$gerrit_secret_id")
    local -r gerrit_username=$(jq --raw-output .data.username <<< "$gerrit_account_fields")
    local -r gerrit_password=$(jq --raw-output .data.password <<< "$gerrit_account_fields")

    [[ -z "$gerrit_host" ]] && return 1
    reply=( "$gerrit_host" "$gerrit_username" "$gerrit_password" )
}

### Work template end
